class_name CotcSaveService
extends Node

signal saves_changed
signal save_completed(save_id: String, save_name: String)
signal load_completed(save_id: String, save_name: String)
signal save_deleted(save_id: String)

const ITEM_CATALOG = preload("res://rebuild_v3/app/inventory/item_catalog.gd")
const GAME_STATE_SCRIPT = preload("res://rebuild_v3/app/services/game_state.gd")

const SAVE_DIRECTORY: String = "user://saves"
const SAVE_FORMAT_VERSION: int = 1
const MAX_SAVE_NAME_LENGTH: int = 48
const ADMIN_SAVE_ID: String = "admin"
const ADMIN_SAVE_NAME: String = "admin"
const ADMIN_CONSUMABLE_QUANTITY: int = 999

var last_error_message: String = ""
var _game_state: CotcGameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_directory()


func bind_game_state(game_state: CotcGameState) -> void:
	_game_state = game_state
	ensure_admin_save()


func has_saves() -> bool:
	return not list_saves().is_empty()


func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	_ensure_save_directory()
	var directory: DirAccess = DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		last_error_message = "The save directory could not be opened."
		return saves

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			var payload: Dictionary = _read_payload("%s/%s" % [SAVE_DIRECTORY, file_name])
			if not payload.is_empty():
				saves.append(payload)
		file_name = directory.get_next()
	directory.list_dir_end()
	saves.sort_custom(_sort_saves_newest_first)
	return saves


func save_named(requested_name: String) -> Dictionary:
	last_error_message = ""
	if _game_state == null:
		last_error_message = "The game state is not available."
		return {}

	var save_name: String = _clean_save_name(requested_name)
	if save_name.is_empty():
		last_error_message = "Enter a name for the saved game."
		return {}

	var existing: Dictionary = find_save_by_name(save_name)
	var save_id: String = str(existing.get("save_id", ""))
	if save_id.is_empty():
		save_id = _create_save_id()

	var unix_time: float = Time.get_unix_time_from_system()
	var payload: Dictionary = {
		"format_version": SAVE_FORMAT_VERSION,
		"save_id": save_id,
		"name": save_name,
		"saved_at_unix": unix_time,
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"metadata": _build_metadata_for_state(_game_state),
		"state": _game_state.to_save_dictionary(),
	}
	if save_id == ADMIN_SAVE_ID:
		payload["admin"] = true
	if not _write_payload(_save_path(save_id), payload):
		return {}

	_game_state.active_save_id = save_id
	_game_state.active_save_name = save_name
	save_completed.emit(save_id, save_name)
	saves_changed.emit()
	return payload


func load_save(save_id: String) -> bool:
	last_error_message = ""
	if _game_state == null:
		last_error_message = "The game state is not available."
		return false
	var clean_id: String = save_id.strip_edges()
	if clean_id.is_empty():
		last_error_message = "No saved game was selected."
		return false
	var payload: Dictionary = _read_payload(_save_path(clean_id))
	if payload.is_empty():
		if last_error_message.is_empty():
			last_error_message = "The selected save could not be read."
		return false
	var state_value: Variant = payload.get("state", {})
	if typeof(state_value) != TYPE_DICTIONARY:
		last_error_message = "The selected save does not contain valid game data."
		return false
	_game_state.load_from_save_dictionary(state_value as Dictionary)
	_game_state.active_save_id = str(payload.get("save_id", clean_id))
	_game_state.active_save_name = str(payload.get("name", "Saved Game"))
	load_completed.emit(_game_state.active_save_id, _game_state.active_save_name)
	return true


func delete_save(save_id: String) -> bool:
	last_error_message = ""
	var clean_id: String = save_id.strip_edges()
	if clean_id.is_empty():
		last_error_message = "No saved game was selected."
		return false
	var file_path: String = _save_path(clean_id)
	if not FileAccess.file_exists(file_path):
		last_error_message = "The selected save no longer exists."
		return false
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	if remove_error != OK:
		last_error_message = "The selected save could not be deleted."
		return false
	if _game_state != null and _game_state.active_save_id == clean_id:
		_game_state.active_save_id = ""
		_game_state.active_save_name = ""
	save_deleted.emit(clean_id)
	saves_changed.emit()
	return true


func find_save_by_name(requested_name: String) -> Dictionary:
	var clean_name: String = _clean_save_name(requested_name)
	if clean_name.is_empty():
		return {}
	for save_data: Dictionary in list_saves():
		if str(save_data.get("name", "")).to_lower() == clean_name.to_lower():
			return save_data
	return {}


func has_save_named(requested_name: String) -> bool:
	return not find_save_by_name(requested_name).is_empty()


func get_suggested_save_name() -> String:
	if _game_state == null:
		return "Saved Game"
	if not _game_state.active_save_name.is_empty():
		return _game_state.active_save_name
	return _game_state.get_location_display_name()


func ensure_admin_save() -> bool:
	# The admin file is a normal save that preserves any progress already made in
	# it, while replenishing every catalogue consumable and granting new catalogue
	# entries whenever the build grows.
	_ensure_save_directory()
	var admin_state: CotcGameState = GAME_STATE_SCRIPT.new() as CotcGameState
	var existing_payload: Dictionary = _read_payload(_save_path(ADMIN_SAVE_ID))
	var existing_state: Variant = existing_payload.get("state", {})
	if typeof(existing_state) == TYPE_DICTIONARY:
		admin_state.load_from_save_dictionary(existing_state as Dictionary)
	else:
		admin_state.start_new_game()

	_grant_admin_catalogue(admin_state)
	var unix_time: float = Time.get_unix_time_from_system()
	var payload: Dictionary = {
		"format_version": SAVE_FORMAT_VERSION,
		"save_id": ADMIN_SAVE_ID,
		"name": ADMIN_SAVE_NAME,
		"admin": true,
		"saved_at_unix": unix_time,
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"metadata": _build_metadata_for_state(admin_state),
		"state": admin_state.to_save_dictionary(),
	}
	var wrote_save: bool = _write_payload(_save_path(ADMIN_SAVE_ID), payload)
	admin_state.free()
	if wrote_save:
		saves_changed.emit()
	return wrote_save


func _grant_admin_catalogue(admin_state: CotcGameState) -> void:
	for item_id: StringName in ITEM_CATALOG.get_all_item_ids():
		var ownership_source: StringName = ITEM_CATALOG.get_ownership_source(item_id)
		match ownership_source:
			ITEM_CATALOG.OWNERSHIP_SHELLS:
				admin_state.unlock_shell(item_id)
			ITEM_CATALOG.OWNERSHIP_INVENTORY:
				admin_state.set_inventory_item(item_id, ADMIN_CONSUMABLE_QUANTITY)
			ITEM_CATALOG.OWNERSHIP_PERMANENT:
				admin_state.grant_permanent_inventory_item(item_id)
			ITEM_CATALOG.OWNERSHIP_STAR_PIECES:
				admin_state.add_star_piece(item_id)
	admin_state.validate_equipped_items(false)


func _build_metadata_for_state(state: CotcGameState) -> Dictionary:
	return {
		"location": state.get_location_display_name(),
		"level_id": String(state.current_level_id),
		"spawn_point_id": String(state.current_spawn_point_id),
		"playtime_seconds": state.playtime_seconds,
		"playtime_text": state.get_playtime_display(),
		"onos": state.onos,
		"current_fins": state.current_fins,
		"max_fins": state.max_fins,
		"star_piece_count": state.star_pieces.size(),
		"inventory_item_types": state.inventory.size(),
		"owned_shell_count": state.owned_shells.size(),
	}


func _write_payload(file_path: String, payload: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		last_error_message = "The save file could not be written."
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _read_payload(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		last_error_message = "A save file could not be opened."
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error_message = "A save file contains invalid JSON data."
		return {}
	var payload: Dictionary = parsed as Dictionary
	if int(payload.get("format_version", 0)) > SAVE_FORMAT_VERSION:
		last_error_message = "This save was created by a newer version of the game."
		return {}
	return payload


func _ensure_save_directory() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(SAVE_DIRECTORY)
	if DirAccess.dir_exists_absolute(absolute_path):
		return
	var create_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if create_error != OK:
		last_error_message = "The save directory could not be created."


func _save_path(save_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIRECTORY, save_id]


func _create_save_id() -> String:
	var unix_seconds: int = floori(Time.get_unix_time_from_system())
	var micro_suffix: int = int(Time.get_ticks_usec() % 1000000)
	return "save_%d_%06d" % [unix_seconds, micro_suffix]


func _clean_save_name(value: String) -> String:
	var result: String = value.strip_edges()
	result = result.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if result.length() > MAX_SAVE_NAME_LENGTH:
		result = result.substr(0, MAX_SAVE_NAME_LENGTH)
	return result


func _sort_saves_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("saved_at_unix", 0.0)) > float(b.get("saved_at_unix", 0.0))
