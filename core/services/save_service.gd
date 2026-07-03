class_name SaveService
extends Node
## JSON persistence only. It does not know the meaning of the data it writes.

const SAVE_DIRECTORY: String = "user://saves"
const SAVE_EXTENSION: String = ".json"

signal save_completed(slot_name: StringName)
signal save_failed(slot_name: StringName, error_code: Error)


func _ready() -> void:
	_ensure_save_directory()


func save(slot_name: StringName, data: Dictionary) -> Error:
	if slot_name.is_empty():
		return _fail(slot_name, ERR_INVALID_PARAMETER)

	var directory_error: Error = _ensure_save_directory()
	if directory_error != OK:
		return _fail(slot_name, directory_error)

	var file: FileAccess = FileAccess.open(get_slot_path(slot_name), FileAccess.WRITE)
	if file == null:
		return _fail(slot_name, FileAccess.get_open_error())

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit(slot_name)
	return OK


func load(slot_name: StringName, fallback: Dictionary = {}) -> Dictionary:
	if not has_save(slot_name):
		return fallback.duplicate(true)

	var file: FileAccess = FileAccess.open(get_slot_path(slot_name), FileAccess.READ)
	if file == null:
		return fallback.duplicate(true)

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not json.data is Dictionary:
		return fallback.duplicate(true)

	return (json.data as Dictionary).duplicate(true)


func has_save(slot_name: StringName) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_name))


func delete_save(slot_name: StringName) -> Error:
	var path: String = get_slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return ERR_DOES_NOT_EXIST

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func get_available_slots() -> Array[StringName]:
	var results: Array[StringName] = []
	var directory: DirAccess = DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return results

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			results.append(StringName(file_name.trim_suffix(SAVE_EXTENSION)))
		file_name = directory.get_next()
	directory.list_dir_end()
	results.sort()
	return results


func get_slot_path(slot_name: StringName) -> String:
	return "%s/%s%s" % [SAVE_DIRECTORY, _normalise_slot_name(slot_name), SAVE_EXTENSION]


func _ensure_save_directory() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func _normalise_slot_name(slot_name: StringName) -> String:
	var cleaned: String = str(slot_name).strip_edges().to_snake_case()
	cleaned = cleaned.replace("/", "_").replace("\\", "_")
	return cleaned if not cleaned.is_empty() else "default"


func _fail(slot_name: StringName, error_code: Error) -> Error:
	push_warning("SaveService could not complete operation for slot '%s'. Error: %s" % [slot_name, error_code])
	save_failed.emit(slot_name, error_code)
	return error_code
