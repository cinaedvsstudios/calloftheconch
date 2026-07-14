extends "res://rebuild_v3/app/contexts/gameplay/gameplay_context.gd"

signal equipped_item_used(slot_id: StringName, item_id: StringName, behavior_id: StringName)
signal equipped_item_use_failed(slot_id: StringName, item_id: StringName, behavior_id: StringName)

const ITEM_CATALOG = preload("res://rebuild_v3/app/inventory/item_catalog.gd")
const SLOT_A: StringName = &"item_a"
const SLOT_B: StringName = &"item_b"
const NORMAL_CONCH_BEHAVIOR: StringName = &"normal_conch"

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

@export_range(0.15, 0.8, 0.01) var inventory_double_tap_window: float = 0.36

@onready var _item_effect_controller: Node = %ItemEffectController

var _hylas: CotcHylas
var _item_behavior_handlers: Array[Callable] = []
var _warned_missing_behaviors: Dictionary = {}
var _last_item_use_slot: StringName = &""
var _last_item_use_id: StringName = &""
var _last_item_use_succeeded: bool = false
var _last_inventory_tap_msec: int = -100000

var _item_click_audio: AudioStreamPlayer
var _item_equip_audio: AudioStreamPlayer
var _inventory_open_audio: AudioStreamPlayer
var _selected_level_variant: StringName = LEVEL_VARIANT_PROTOTYPE


func _ready() -> void:
	super._ready()
	_resolve_hylas()
	_connect_hylas_item_request()
	_sync_equipped_item_a()
	_item_effect_controller.call(&"configure", self, _level, _hylas)
	register_item_behavior_handler(Callable(_item_effect_controller, "handle_item_behavior"))

	_item_click_audio = _create_ui_audio_player(&"InventoryItemClickAudio", ITEM_CLICK_STREAM, -5.0)
	_item_equip_audio = _create_ui_audio_player(&"InventoryItemEquipAudio", ITEM_EQUIP_STREAM, -4.0)
	_inventory_open_audio = _create_ui_audio_player(&"InventoryOpenAudio", INVENTORY_OPEN_STREAM, -5.0)
	if not _inventory_overlay.inventory_opened.is_connected(_on_inventory_opened_audio):
		_inventory_overlay.inventory_opened.connect(_on_inventory_opened_audio)
	if not _inventory_overlay.item_equipped.is_connected(_on_inventory_item_equipped_audio):
		_inventory_overlay.item_equipped.connect(_on_inventory_item_equipped_audio)

	_selected_level_variant = _read_level_variant(_level)


func bind_game_state(game_state: CotcGameState) -> void:
	if _game_state != null and _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)

	super.bind_game_state(game_state)
	_item_effect_controller.call(&"bind_game_state", game_state)

	if _game_state != null and not _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed):
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
	_sync_equipped_item_a()


func activate() -> void:
	super.activate()
	_item_effect_controller.call(&"set_active", true)


func deactivate() -> void:
	_item_effect_controller.call(&"set_active", false)
	super.deactivate()


func register_item_behavior_handler(handler: Callable) -> void:
	if not handler.is_valid() or _item_behavior_handlers.has(handler):
		return
	_item_behavior_handlers.append(handler)


func unregister_item_behavior_handler(handler: Callable) -> void:
	_item_behavior_handlers.erase(handler)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed(&"utility_item", false, true):
		_last_inventory_tap_msec = -100000
		_inventory_candidate = false
		_cancel_hylas_pending_interaction()
		if _can_use_equipped_items():
			_use_equipped_item_b()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"inventory", false, true):
		_inventory_candidate = false
		var now_msec: int = Time.get_ticks_msec()
		var elapsed: float = float(now_msec - _last_inventory_tap_msec) / 1000.0
		if elapsed <= inventory_double_tap_window:
			_last_inventory_tap_msec = -100000
			if _can_use_equipped_items():
				open_inventory()
		else:
			_last_inventory_tap_msec = now_msec
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released(&"inventory", false, true):
		_inventory_candidate = false
		get_viewport().set_input_as_handled()
		return

	super._unhandled_input(event)


func _can_use_equipped_items() -> bool:
	return (
		_active
		and not _in_city
		and not get_tree().paused
		and not _inventory_overlay.is_open()
		and not _pause_overlay.visible
		and not _death_overlay.is_open()
	)


func _use_equipped_item_b() -> bool:
	if _game_state == null:
		return false
	var item_id: StringName = _game_state.get_equipped_item(SLOT_B)
	if String(item_id).is_empty():
		_record_item_use(SLOT_B, item_id, false)
		return false
	var origin: Vector2 = _hylas.global_position if is_instance_valid(_hylas) else Vector2.ZERO
	return _activate_catalog_item(SLOT_B, item_id, origin, Vector2.ZERO)


func _on_hylas_item_a_requested(
		item_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> void:
	if not _can_use_equipped_items() or _game_state == null:
		return
	if _game_state.get_equipped_item(SLOT_A) != item_id:
		return
	_activate_catalog_item(SLOT_A, item_id, origin, direction)


func _activate_catalog_item(
		slot_id: StringName,
		item_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	if _game_state == null or String(item_id).is_empty():
		_record_item_use(slot_id, item_id, false)
		return false
	if not _game_state.is_item_valid_for_slot(item_id, slot_id, true):
		_record_item_use(slot_id, item_id, false)
		return false
	if not ITEM_CATALOG.activates_on_use(item_id):
		_record_item_use(slot_id, item_id, false)
		return false

	var behavior_id: StringName = ITEM_CATALOG.get_behavior_id(item_id)
	if String(behavior_id).is_empty():
		_record_item_use(slot_id, item_id, false)
		return false

	var consumes_quantity: bool = (
		ITEM_CATALOG.item_has_quantity(item_id)
		and ITEM_CATALOG.get_ownership_source(item_id) == ITEM_CATALOG.OWNERSHIP_INVENTORY
	)
	if consumes_quantity and _game_state.get_inventory_quantity(item_id) <= 0:
		_record_item_use(slot_id, item_id, false)
		return false

	var activated: bool = false
	if behavior_id == NORMAL_CONCH_BEHAVIOR and slot_id == SLOT_A:
		if is_instance_valid(_hylas) and _hylas.has_method(&"activate_normal_conch"):
			activated = bool(_hylas.call(&"activate_normal_conch", direction))
	else:
		activated = _dispatch_item_behavior(behavior_id, item_id, slot_id, origin, direction)

	if not activated:
		_warn_for_missing_behavior(behavior_id)
		_record_item_use(slot_id, item_id, false)
		equipped_item_use_failed.emit(slot_id, item_id, behavior_id)
		return false

	if consumes_quantity and not _game_state.remove_inventory_item(item_id, 1):
		push_error("Activated item '%s' but could not consume its quantity." % String(item_id))

	_record_item_use(slot_id, item_id, true)
	if is_instance_valid(_hud):
		_hud.pulse_equipment_slot(slot_id)
	equipped_item_used.emit(slot_id, item_id, behavior_id)
	return true


func _dispatch_item_behavior(
		behavior_id: StringName,
		item_id: StringName,
		slot_id: StringName,
		origin: Vector2,
		direction: Vector2,
	) -> bool:
	var invalid_handlers: Array[Callable] = []
	for handler: Callable in _item_behavior_handlers:
		if not handler.is_valid():
			invalid_handlers.append(handler)
			continue
		var result: Variant = handler.call(behavior_id, item_id, slot_id, origin, direction)
		if bool(result):
			for invalid_handler: Callable in invalid_handlers:
				_item_behavior_handlers.erase(invalid_handler)
			return true
	for invalid_handler: Callable in invalid_handlers:
		_item_behavior_handlers.erase(invalid_handler)
	return false


func _warn_for_missing_behavior(behavior_id: StringName) -> void:
	if String(behavior_id).is_empty() or _warned_missing_behaviors.has(String(behavior_id)):
		return
	_warned_missing_behaviors[String(behavior_id)] = true
	push_warning("No active gameplay handler accepted item behavior '%s'." % String(behavior_id))


func _on_equipped_item_changed(slot_id: StringName, _item_id: StringName) -> void:
	if slot_id == SLOT_A:
		_sync_equipped_item_a()


func _sync_equipped_item_a() -> void:
	_resolve_hylas()
	if not is_instance_valid(_hylas) or not _hylas.has_method(&"set_equipped_item_a"):
		return
	var item_id: StringName = NORMAL_CONCH_BEHAVIOR
	if _game_state != null:
		item_id = _game_state.get_equipped_item(SLOT_A)
	_hylas.call(&"set_equipped_item_a", item_id)


func _resolve_hylas() -> void:
	if is_instance_valid(_hylas):
		return
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		if not _level.is_ancestor_of(candidate):
			continue
		_hylas = candidate as CotcHylas
		if is_instance_valid(_hylas):
			return


func _connect_hylas_item_request() -> void:
	_resolve_hylas()
	if not is_instance_valid(_hylas) or not _hylas.has_signal(&"item_a_requested"):
		push_warning("Hylas is missing the Item A request signal.")
		return
	var callback: Callable = Callable(self, "_on_hylas_item_a_requested")
	if not _hylas.is_connected(&"item_a_requested", callback):
		_hylas.connect(&"item_a_requested", callback)


func _cancel_hylas_pending_interaction() -> void:
	_resolve_hylas()
	if is_instance_valid(_hylas) and _hylas.has_method(&"cancel_pending_interaction"):
		_hylas.call(&"cancel_pending_interaction")


func _record_item_use(slot_id: StringName, item_id: StringName, succeeded: bool) -> void:
	_last_item_use_slot = slot_id
	_last_item_use_id = item_id
	_last_item_use_succeeded = succeeded


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
	_item_effect_controller.call(&"configure", self, _level, _hylas)


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
	_connect_inventory_item_click_sounds()


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
	lines.append("item_behavior_handlers=%d" % _item_behavior_handlers.size())
	lines.append("last_item_use_slot=%s" % String(_last_item_use_slot))
	lines.append("last_item_use_id=%s" % String(_last_item_use_id))
	lines.append("last_item_use_succeeded=%s" % str(_last_item_use_succeeded))
	lines.append("level_variant=%s" % String(_selected_level_variant))
	if is_instance_valid(_item_effect_controller):
		var effect_lines: Variant = _item_effect_controller.call(&"get_debug_lines")
		if effect_lines is Array:
			for effect_line: Variant in effect_lines:
				lines.append(str(effect_line))
	return lines
