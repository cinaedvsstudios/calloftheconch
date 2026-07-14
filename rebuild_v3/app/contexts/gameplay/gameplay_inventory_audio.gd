extends "res://rebuild_v3/app/contexts/gameplay/gameplay_double_tap_inventory.gd"

const LEVEL_VARIANT_PROTOTYPE: StringName = &"prototype"
const LEVEL_VARIANT_MAIN: StringName = &"main"
const PROTOTYPE_LEVEL_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_prototype.tscn"
)
const MAIN_LEVEL_SCENE: PackedScene = preload(
	"res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_main.tscn"
)

const ITEM_CLICK_STREAM: AudioStream = preload("res://assets/audio/pickup6.mp3")
const ITEM_EQUIP_STREAM: AudioStream = preload("res://assets/audio/pickup1.mp3")
const INVENTORY_OPEN_STREAM: AudioStream = preload("res://assets/audio/pickup4.mp3")

var _item_click_audio: AudioStreamPlayer
var _item_equip_audio: AudioStreamPlayer
var _inventory_open_audio: AudioStreamPlayer
var _selected_level_variant: StringName = LEVEL_VARIANT_PROTOTYPE


func _ready() -> void:
	super._ready()
	_item_click_audio = _create_ui_audio_player(&"InventoryItemClickAudio", ITEM_CLICK_STREAM, -5.0)
	_item_equip_audio = _create_ui_audio_player(&"InventoryItemEquipAudio", ITEM_EQUIP_STREAM, -4.0)
	_inventory_open_audio = _create_ui_audio_player(&"InventoryOpenAudio", INVENTORY_OPEN_STREAM, -5.0)

	if not _inventory_overlay.inventory_opened.is_connected(_on_inventory_opened_audio):
		_inventory_overlay.inventory_opened.connect(_on_inventory_opened_audio)
	if not _inventory_overlay.item_equipped.is_connected(_on_inventory_item_equipped_audio):
		_inventory_overlay.item_equipped.connect(_on_inventory_item_equipped_audio)

	_selected_level_variant = _read_level_variant(_level)


func set_level_variant(variant_id: StringName) -> bool:
	var resolved_variant: StringName = (
		LEVEL_VARIANT_MAIN if variant_id == LEVEL_VARIANT_MAIN else LEVEL_VARIANT_PROTOTYPE
	)
	if resolved_variant == _selected_level_variant and is_instance_valid(_level):
		return true
	if _active:
		push_warning("Level version can only be changed while gameplay is inactive.")
		return false

	var level_scene: PackedScene = (
		MAIN_LEVEL_SCENE if resolved_variant == LEVEL_VARIANT_MAIN else PROTOTYPE_LEVEL_SCENE
	)
	var replacement: CotcSeaOfPillars = level_scene.instantiate() as CotcSeaOfPillars
	if replacement == null:
		push_error("Could not instantiate Sea of Pillars level version '%s'." % String(resolved_variant))
		return false

	_replace_level(replacement)
	_selected_level_variant = resolved_variant
	return true


func get_level_variant() -> StringName:
	return _selected_level_variant


func _replace_level(replacement: CotcSeaOfPillars) -> void:
	var old_level: CotcSeaOfPillars = _level
	if is_instance_valid(old_level):
		_disconnect_level_signals(old_level)
		old_level.deactivate()
		remove_child(old_level)
		old_level.queue_free()

	replacement.name = "SeaOfPillars"
	replacement.unique_name_in_owner = true
	add_child(replacement)
	move_child(replacement, 0)
	_level = replacement
	_connect_level_signals(_level)
	if _game_state != null:
		_level.bind_game_state(_game_state)
	_configure_city_gate_interaction()

	_hylas = null
	_resolve_hylas()
	_connect_hylas_item_request()
	_sync_equipped_item_a()
	_item_effect_controller.configure(self, _level, _hylas)


func _connect_level_signals(level: CotcSeaOfPillars) -> void:
	if not level.death_sequence_requested.is_connected(_on_level_death_sequence_requested):
		level.death_sequence_requested.connect(_on_level_death_sequence_requested)
	if not level.whale_travel_requested.is_connected(_on_level_whale_travel_requested):
		level.whale_travel_requested.connect(_on_level_whale_travel_requested)
	if not level.city_entry_requested.is_connected(_on_level_city_entry_requested):
		level.city_entry_requested.connect(_on_level_city_entry_requested)
	if not level.conch_used.is_connected(_on_level_conch_used):
		level.conch_used.connect(_on_level_conch_used)


func _disconnect_level_signals(level: CotcSeaOfPillars) -> void:
	if level.death_sequence_requested.is_connected(_on_level_death_sequence_requested):
		level.death_sequence_requested.disconnect(_on_level_death_sequence_requested)
	if level.whale_travel_requested.is_connected(_on_level_whale_travel_requested):
		level.whale_travel_requested.disconnect(_on_level_whale_travel_requested)
	if level.city_entry_requested.is_connected(_on_level_city_entry_requested):
		level.city_entry_requested.disconnect(_on_level_city_entry_requested)
	if level.conch_used.is_connected(_on_level_conch_used):
		level.conch_used.disconnect(_on_level_conch_used)


func _read_level_variant(level: Node) -> StringName:
	if level != null and level.has_meta(&"level_variant"):
		var stored_variant: StringName = StringName(str(level.get_meta(&"level_variant")))
		if stored_variant == LEVEL_VARIANT_MAIN:
			return LEVEL_VARIANT_MAIN
	return LEVEL_VARIANT_PROTOTYPE


func _create_ui_audio_player(
		player_name: StringName,
		stream: AudioStream,
		volume_db: float,
	) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = String(player_name)
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _on_inventory_opened_audio() -> void:
	_play_ui_audio(_inventory_open_audio)
	call_deferred(&"_connect_inventory_item_click_sounds")


func _connect_inventory_item_click_sounds() -> void:
	var item_grid: Node = _inventory_overlay.get_node_or_null("%ItemGrid")
	if item_grid == null:
		return
	_connect_item_button_tree(item_grid)


func _connect_item_button_tree(parent: Node) -> void:
	for child: Node in parent.get_children():
		var button := child as Button
		if button != null:
			var callback := Callable(self, "_on_inventory_item_gui_input")
			if not button.gui_input.is_connected(callback):
				button.gui_input.connect(callback)
		_connect_item_button_tree(child)


func _on_inventory_item_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_play_ui_audio(_item_click_audio)


func _on_inventory_item_equipped_audio(
		_slot_id: StringName,
		_item_id: StringName,
	) -> void:
	_play_ui_audio(_item_equip_audio)


func _play_ui_audio(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("level_variant=%s" % String(_selected_level_variant))
	return lines
