class_name CotcGameplayContext
extends Node

signal settings_requested
signal menu_requested
signal close_game_requested
signal death_sequence_requested
signal whale_travel_requested
signal equipped_item_used(slot_id: StringName, item_id: StringName, behavior_id: StringName)
signal equipped_item_use_failed(slot_id: StringName, item_id: StringName, behavior_id: StringName)

const CITY_GATE_RUNTIME_RADIUS: float = 560.0
const PAUSED_SHADER_NODE_PATHS: Array[NodePath] = [
	^"SeaEnvironment/AtmosphereEffects/WaterMottle",
	^"SeaOfPillars/ParallaxLayer/waterlines",
]
const MANUAL_TIME_PARAMETER: StringName = &"mati_manual_time"
const USE_MANUAL_TIME_PARAMETER: StringName = &"mati_use_manual_time"

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

@export_range(0.15, 0.8, 0.01) var inventory_double_tap_window: float = 0.36

@onready var _level: CotcSeaOfPillars = %SeaOfPillars
@onready var _city: CotcPillarsCity = %PillarsCity
@onready var _sea_environment: Node2D = $SeaEnvironment
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _hud: CotcGameplayHud = %GameplayHud
@onready var _hint: Label = $GameplayUI/Hint
@onready var _pause_overlay: CotcPauseOverlay = %PauseOverlay
@onready var _inventory_overlay: CotcInventoryOverlay = %InventoryOverlay
@onready var _death_overlay: CotcDeathOverlay = %DeathOverlay
@onready var _item_effect_controller: CotcItemEffectController = %ItemEffectController
@onready var _cuttlefish_tutorial: CotcCuttlefishTutorialController = %CuttlefishTutorial
@onready var _item_click_audio: AudioStreamPlayer = %InventoryItemClickAudio
@onready var _item_equip_audio: AudioStreamPlayer = %InventoryItemEquipAudio
@onready var _inventory_open_audio: AudioStreamPlayer = %InventoryOpenAudio

var _active: bool = false
var _in_city: bool = false
var _inventory_candidate: bool = false
var _game_state: CotcGameState
var _paused_shader_states: Array[Dictionary] = []

var _hylas: CotcHylas
var _item_behavior_handlers: Array[Callable] = []
var _warned_missing_behaviors: Dictionary = {}
var _last_item_use_slot: StringName = &""
var _last_item_use_id: StringName = &""
var _last_item_use_succeeded: bool = false
var _last_inventory_tap_msec: int = -100000
var _selected_level_variant: StringName = LEVEL_VARIANT_PROTOTYPE


func _ready() -> void:
	if not child_entered_tree.is_connected(_on_context_child_entered_tree):
		child_entered_tree.connect(_on_context_child_entered_tree)
	_configure_level_pause_mode(_level)
	_city.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hint.hide()
	_pause_overlay.resume_requested.connect(_on_pause_resume_requested)
	_pause_overlay.settings_requested.connect(_on_pause_settings_requested)
	_pause_overlay.menu_requested.connect(_on_pause_menu_requested)
	_inventory_overlay.inventory_opened.connect(_on_inventory_opened)
	_inventory_overlay.inventory_closed.connect(_on_inventory_closed)
	_death_overlay.continue_requested.connect(_on_death_continue_requested)
	_death_overlay.menu_requested.connect(_on_death_menu_requested)
	_death_overlay.exit_requested.connect(_on_death_exit_requested)
	_level.death_sequence_requested.connect(_on_level_death_sequence_requested)
	_level.whale_travel_requested.connect(_on_level_whale_travel_requested)
	_level.city_entry_requested.connect(_on_level_city_entry_requested)
	_level.conch_used.connect(_on_level_conch_used)
	_city.exit_requested.connect(_on_city_exit_requested)
	_city.menu_requested.connect(_on_city_menu_requested)
	_city.location_changed.connect(_on_city_location_changed)
	_configure_city_gate_interaction()
	_city.deactivate()
	_sea_environment.hide()

	_resolve_hylas()
	_connect_hylas_item_request()
	_sync_equipped_item_a()
	_item_effect_controller.configure(self, _level, _hylas)
	register_item_behavior_handler(Callable(_item_effect_controller, "handle_item_behavior"))
	if not _inventory_overlay.inventory_opened.is_connected(_on_inventory_opened_audio):
		_inventory_overlay.inventory_opened.connect(_on_inventory_opened_audio)
	if not _inventory_overlay.item_equipped.is_connected(_on_inventory_item_equipped_audio):
		_inventory_overlay.item_equipped.connect(_on_inventory_item_equipped_audio)
	_selected_level_variant = _read_level_variant(_level)

	_cuttlefish_tutorial.bind_level(_level)


func _exit_tree() -> void:
	_restore_animated_shader_time()


func bind_game_state(game_state: CotcGameState) -> void:
	if (
		_game_state != null
		and _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed)
	):
		_game_state.equipped_item_changed.disconnect(_on_equipped_item_changed)

	_game_state = game_state
	_level.bind_game_state(game_state)
	_hud.bind_game_state(game_state)
	_inventory_overlay.bind_game_state(game_state)
	_item_effect_controller.bind_game_state(game_state)

	if (
		_game_state != null
		and not _game_state.equipped_item_changed.is_connected(_on_equipped_item_changed)
	):
		_game_state.equipped_item_changed.connect(_on_equipped_item_changed)
	_sync_equipped_item_a()
	_cuttlefish_tutorial.bind_game_state(game_state)


func activate() -> void:
	_active = true
	_in_city = false
	_inventory_candidate = false
	_set_gameplay_paused(false)
	_inventory_overlay.close_inventory()
	_city.deactivate()
	_sea_environment.show()
	_gameplay_ui.visible = true
	_hint.hide()
	_hud.show()
	_hud.set_location("The Sea of Pillars")
	_pause_overlay.close_overlay()
	_death_overlay.close_overlay()
	if _game_state != null:
		_game_state.set_gameplay_active(true)
		_level.activate(_game_state.current_spawn_point_id)
	else:
		_level.activate()
	_play_gameplay_music()
	_item_effect_controller.set_active(true)
	_cuttlefish_tutorial.activate()
	_set_leaf_sheep_gameplay_active(true)


func deactivate() -> void:
	_force_deactivate_leaf_sheep(&"context_deactivated")
	_set_leaf_sheep_gameplay_active(false)
	_cuttlefish_tutorial.deactivate()
	_item_effect_controller.set_active(false)

	_active = false
	_in_city = false
	_inventory_candidate = false
	_inventory_overlay.close_inventory()
	_set_gameplay_paused(false)
	_pause_overlay.close_overlay()
	_death_overlay.close_overlay()
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_city.deactivate()
	_sea_environment.hide()
	_level.deactivate()
	if _game_state != null:
		_game_state.set_gameplay_active(false)


func return_to_pause_menu() -> void:
	if not _active or _death_overlay.is_open():
		return
	_inventory_candidate = false
	_inventory_overlay.close_inventory()
	_set_gameplay_paused(true)
	_pause_overlay.open_overlay()


func open_inventory() -> void:
	if not _active or get_tree().paused or _death_overlay.is_open() or _pause_overlay.visible:
		return
	_inventory_overlay.open_inventory()


func close_inventory() -> void:
	_inventory_overlay.close_inventory()


func is_game_active() -> bool:
	return _active


func is_death_sequence_pending() -> bool:
	return _level.is_death_sequence_pending()


func complete_death_respawn() -> void:
	_death_overlay.close_overlay()
	_level.complete_death_respawn()
	_cuttlefish_tutorial.activate()
	_set_leaf_sheep_gameplay_active(true)


func apply_accessibility_settings(show_control_hints: bool, screen_shake_scale: float) -> void:
	_hint.hide()
	_level.set_screen_shake_scale(screen_shake_scale)
	_cuttlefish_tutorial.call(&"set_tooltips_enabled", show_control_hints)


func _configure_level_pause_mode(level: Node) -> void:
	if level == null:
		return
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	var underwater_ambience: Node = level.get_node_or_null("%UnderwaterAmbience")
	if underwater_ambience != null:
		underwater_ambience.process_mode = Node.PROCESS_MODE_PAUSABLE


func _on_context_child_entered_tree(child: Node) -> void:
	if child == null or child.name != &"SeaOfPillars":
		return
	call_deferred(&"_configure_level_pause_mode", child)


func _set_gameplay_paused(is_paused: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if is_paused:
		if not tree.paused or _paused_shader_states.is_empty():
			_freeze_animated_shader_time()
		tree.paused = true
		return
	tree.paused = false
	_restore_animated_shader_time()


func _freeze_animated_shader_time() -> void:
	_restore_animated_shader_time()
	var current_time: float = float(Time.get_ticks_msec()) / 1000.0
	for node_path: NodePath in PAUSED_SHADER_NODE_PATHS:
		var canvas_item: CanvasItem = get_node_or_null(node_path) as CanvasItem
		if canvas_item == null or not (canvas_item.material is ShaderMaterial):
			continue
		var material: ShaderMaterial = canvas_item.material as ShaderMaterial
		var previous_use_manual: Variant = material.get_shader_parameter(USE_MANUAL_TIME_PARAMETER)
		var previous_manual_time: Variant = material.get_shader_parameter(MANUAL_TIME_PARAMETER)
		if typeof(previous_use_manual) != TYPE_BOOL:
			continue
		if typeof(previous_manual_time) != TYPE_FLOAT and typeof(previous_manual_time) != TYPE_INT:
			continue
		var use_manual_time: bool = previous_use_manual
		var manual_time: float = float(previous_manual_time)
		var frozen_time: float = manual_time if use_manual_time else current_time
		(
			_paused_shader_states
			. append(
				{
					"material": material,
					"use_manual_time": use_manual_time,
					"manual_time": manual_time,
				}
			)
		)
		material.set_shader_parameter(MANUAL_TIME_PARAMETER, frozen_time)
		material.set_shader_parameter(USE_MANUAL_TIME_PARAMETER, true)


func _restore_animated_shader_time() -> void:
	for state: Dictionary in _paused_shader_states:
		var material: ShaderMaterial = state.get("material") as ShaderMaterial
		if not is_instance_valid(material):
			continue
		(
			material
			. set_shader_parameter(
				MANUAL_TIME_PARAMETER,
				state.get("manual_time", 0.0),
			)
		)
		(
			material
			. set_shader_parameter(
				USE_MANUAL_TIME_PARAMETER,
				state.get("use_manual_time", false),
			)
		)
	_paused_shader_states.clear()


func _configure_city_gate_interaction() -> void:
	# The exterior return point sits farther from the gate centre than the old
	# 300-pixel trigger. Enlarge the existing level-owned Area2D rather than
	# introducing a second Space listener or a competing interaction route.
	_level.city_gate_interaction_radius = CITY_GATE_RUNTIME_RADIUS
	var gate_area: Area2D = _level.get_node_or_null("CityGateInteraction") as Area2D
	if gate_area == null:
		push_warning("City gate interaction area was not created before GameplayContext setup.")
		return
	var collision_shape: CollisionShape2D = (
		gate_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	)
	if collision_shape == null:
		push_warning("City gate interaction area is missing its CollisionShape2D.")
		return
	var circle: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle == null:
		push_warning("City gate interaction requires a CircleShape2D.")
		return
	circle.radius = CITY_GATE_RUNTIME_RADIUS


func _play_gameplay_music() -> void:
	if _gameplay_music.stream == null:
		return
	_gameplay_music.stream_paused = false
	if not _gameplay_music.playing:
		_gameplay_music.play()


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

	if event.is_action_released(&"inventory"):
		_inventory_candidate = false
		get_viewport().set_input_as_handled()
		return

	if _death_overlay.is_open():
		_inventory_candidate = false
		if event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
		return

	if _inventory_overlay.is_open():
		if event.is_action_pressed(&"pause"):
			_inventory_overlay.close_inventory()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"inventory"):
		_inventory_candidate = not get_tree().paused and not _pause_overlay.visible
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"utility_item"):
		_inventory_candidate = false
		return

	if event.is_action_released(&"inventory"):
		var should_open: bool = (
			_inventory_candidate
			and not get_tree().paused
			and not _pause_overlay.visible
			and not _death_overlay.is_open()
		)
		_inventory_candidate = false
		if should_open:
			_inventory_overlay.open_inventory()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"pause"):
		_inventory_candidate = false
		if get_tree().paused:
			_set_gameplay_paused(false)
			_pause_overlay.close_overlay()
		else:
			_set_gameplay_paused(true)
			_pause_overlay.open_overlay()
		get_viewport().set_input_as_handled()


func _on_inventory_opened() -> void:
	if not _active:
		_inventory_overlay.close_inventory()
		return
	_inventory_candidate = false
	_pause_overlay.close_overlay()
	_set_gameplay_paused(true)


func _on_inventory_closed() -> void:
	_inventory_candidate = false
	if _active and not _death_overlay.is_open():
		_set_gameplay_paused(false)


func _on_pause_resume_requested() -> void:
	if not _active:
		return
	_inventory_candidate = false
	_set_gameplay_paused(false)


func _on_pause_settings_requested() -> void:
	if not _active:
		return
	_inventory_candidate = false
	_set_gameplay_paused(true)
	settings_requested.emit()


func _on_pause_menu_requested() -> void:
	_inventory_candidate = false
	_set_gameplay_paused(false)
	menu_requested.emit()


func _on_death_continue_requested() -> void:
	if not _active or not _level.is_death_sequence_pending():
		return
	complete_death_respawn()


func _on_death_menu_requested() -> void:
	if not _active:
		return
	_death_overlay.close_overlay()
	_set_gameplay_paused(false)
	menu_requested.emit()


func _on_death_exit_requested() -> void:
	close_game_requested.emit()


func _on_level_death_sequence_requested() -> void:
	_force_deactivate_leaf_sheep(&"death")
	_set_leaf_sheep_gameplay_active(false)
	_cuttlefish_tutorial.deactivate()
	if not _active:
		return
	_inventory_candidate = false
	_inventory_overlay.close_inventory()
	_pause_overlay.close_overlay()
	_death_overlay.open_overlay()
	death_sequence_requested.emit()


func _on_level_whale_travel_requested() -> void:
	_force_deactivate_leaf_sheep(&"whale_travel")
	_set_leaf_sheep_gameplay_active(false)
	whale_travel_requested.emit()


func _on_level_city_entry_requested() -> void:
	_force_deactivate_leaf_sheep(&"city")
	_set_leaf_sheep_gameplay_active(false)
	if _active and not _in_city:
		_in_city = true
		_level.activate_checkpoint(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
		_level.deactivate()
		_sea_environment.hide()
		_city.activate()
		_hud.set_location("Neresithoppos")
	if _in_city:
		_cuttlefish_tutorial.deactivate()


func _on_city_exit_requested() -> void:
	if _active and _in_city:
		_in_city = false
		_city.deactivate()
		_sea_environment.show()
		_level.activate(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
		_hud.set_location("The Sea of Pillars")
	if _active and not _in_city:
		_cuttlefish_tutorial.activate()
		_set_leaf_sheep_gameplay_active(true)


func _on_city_menu_requested() -> void:
	if not _active or not _in_city:
		return
	_inventory_candidate = false
	_set_gameplay_paused(true)
	_pause_overlay.open_overlay()


func _on_city_location_changed(location_name: String) -> void:
	if not _active or not _in_city:
		return
	_hud.set_location(location_name)


func _on_level_conch_used() -> void:
	_hud.pulse_conch()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[GameplayContext]",
		"active=%s" % str(_active),
		"in_city=%s" % str(_in_city),
		"environment_visible=%s" % str(_sea_environment.visible),
		"ui_visible=%s" % str(_gameplay_ui.visible),
		"control_hint_visible=false",
		"music_playing=%s" % str(_gameplay_music.playing),
		"paused=%s" % str(get_tree().paused),
		"inventory_candidate=%s" % str(_inventory_candidate),
		"inventory_open=%s" % str(_inventory_overlay.is_open()),
		"inventory_selected=%s" % String(_inventory_overlay.get_selected_item_id()),
		"death_sequence_pending=%s" % str(_level.is_death_sequence_pending()),
		"death_overlay_open=%s" % str(_death_overlay.is_open()),
		"city_gate_interaction_radius=%.1f" % CITY_GATE_RUNTIME_RADIUS,
	]
	if _game_state != null:
		lines.append("level_id=%s" % String(_game_state.current_level_id))
		lines.append("spawn_point_id=%s" % String(_game_state.current_spawn_point_id))
		lines.append("onos=%d" % _game_state.onos)
		lines.append("limited_use_inventory_items=%d" % _game_state.inventory.size())
		lines.append("permanent_inventory_items=%d" % _game_state.permanent_inventory_items.size())
	lines.append_array(_inventory_overlay.get_debug_lines())
	lines.append_array(_hud.get_debug_lines())
	lines.append_array(_city.get_debug_lines())
	lines.append_array(_level.get_debug_lines())
	lines.append("item_behavior_handlers=%d" % _item_behavior_handlers.size())
	lines.append("last_item_use_slot=%s" % String(_last_item_use_slot))
	lines.append("last_item_use_id=%s" % String(_last_item_use_id))
	lines.append("last_item_use_succeeded=%s" % str(_last_item_use_succeeded))
	lines.append("level_variant=%s" % String(_selected_level_variant))
	if is_instance_valid(_item_effect_controller):
		lines.append_array(_item_effect_controller.get_debug_lines())
	lines.append_array(_cuttlefish_tutorial.get_debug_lines())
	return lines


func register_item_behavior_handler(handler: Callable) -> void:
	if not handler.is_valid() or _item_behavior_handlers.has(handler):
		return
	_item_behavior_handlers.append(handler)


func unregister_item_behavior_handler(handler: Callable) -> void:
	_item_behavior_handlers.erase(handler)


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
		push_error(
			"Could not instantiate Sea of Pillars level version '%s'." % String(resolved_variant)
		)
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
	_cuttlefish_tutorial.bind_level(_level)


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


func _force_deactivate_leaf_sheep(reason: StringName) -> void:
	if is_instance_valid(_item_effect_controller):
		_item_effect_controller.force_deactivate_leaf_sheep(reason)


func _set_leaf_sheep_gameplay_active(is_active: bool) -> void:
	if is_instance_valid(_item_effect_controller):
		_item_effect_controller.set_leaf_sheep_gameplay_active(is_active)
