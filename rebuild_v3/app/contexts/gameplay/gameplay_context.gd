class_name CotcGameplayContext
extends Node

signal settings_requested
signal menu_requested
signal close_game_requested
signal death_sequence_requested
signal whale_travel_requested

const CITY_GATE_RUNTIME_RADIUS: float = 560.0
const PAUSED_SHADER_NODE_PATHS: Array[NodePath] = [
	^"SeaEnvironment/AtmosphereEffects/WaterMottle",
	^"SeaOfPillars/ParallaxLayer/waterlines",
]
const MANUAL_TIME_PARAMETER: StringName = &"mati_manual_time"
const USE_MANUAL_TIME_PARAMETER: StringName = &"mati_use_manual_time"

@onready var _level: CotcSeaOfPillars = %SeaOfPillars
@onready var _city: CotcPillarsCity = %PillarsCity
@onready var _sea_environment: Node2D = $SeaEnvironment
@onready var _item_effects_root: Node = $ItemEffectController
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _hud: CotcGameplayHud = %GameplayHud
@onready var _hint: Label = $GameplayUI/Hint
@onready var _pause_overlay: CotcPauseOverlay = %PauseOverlay
@onready var _inventory_overlay: CotcInventoryOverlay = %InventoryOverlay
@onready var _death_overlay: CotcDeathOverlay = %DeathOverlay

var _active: bool = false
var _in_city: bool = false
var _inventory_candidate: bool = false
var _game_state: CotcGameState
var _paused_shader_states: Array[Dictionary] = []


func _ready() -> void:
	if not child_entered_tree.is_connected(_on_context_child_entered_tree):
		child_entered_tree.connect(_on_context_child_entered_tree)
	_configure_pause_process_modes()
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


func _exit_tree() -> void:
	_restore_animated_shader_time()


func bind_game_state(game_state: CotcGameState) -> void:
	_game_state = game_state
	_level.bind_game_state(game_state)
	_hud.bind_game_state(game_state)
	_inventory_overlay.bind_game_state(game_state)


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


func deactivate() -> void:
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
	if (
			not _active
			or get_tree().paused
			or _death_overlay.is_open()
			or _pause_overlay.visible
		):
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


func apply_accessibility_settings(_show_control_hints: bool, screen_shake_scale: float) -> void:
	_hint.hide()
	_level.set_screen_shake_scale(screen_shake_scale)


func _configure_pause_process_modes() -> void:
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	_item_effects_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	_sea_environment.process_mode = Node.PROCESS_MODE_PAUSABLE
	_city.process_mode = Node.PROCESS_MODE_PAUSABLE
	_configure_level_pause_mode(_level)


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
		var previous_use_manual: Variant = material.get_shader_parameter(
			USE_MANUAL_TIME_PARAMETER
		)
		var previous_manual_time: Variant = material.get_shader_parameter(
			MANUAL_TIME_PARAMETER
		)
		if typeof(previous_use_manual) != TYPE_BOOL:
			continue
		if typeof(previous_manual_time) != TYPE_FLOAT and typeof(previous_manual_time) != TYPE_INT:
			continue
		var use_manual_time: bool = previous_use_manual
		var manual_time: float = float(previous_manual_time)
		var frozen_time: float = manual_time if use_manual_time else current_time
		_paused_shader_states.append({
			"material": material,
			"use_manual_time": use_manual_time,
			"manual_time": manual_time,
		})
		material.set_shader_parameter(MANUAL_TIME_PARAMETER, frozen_time)
		material.set_shader_parameter(USE_MANUAL_TIME_PARAMETER, true)


func _restore_animated_shader_time() -> void:
	for state: Dictionary in _paused_shader_states:
		var material: ShaderMaterial = state.get("material") as ShaderMaterial
		if not is_instance_valid(material):
			continue
		material.set_shader_parameter(
			MANUAL_TIME_PARAMETER,
			state.get("manual_time", 0.0),
		)
		material.set_shader_parameter(
			USE_MANUAL_TIME_PARAMETER,
			state.get("use_manual_time", false),
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
	var collision_shape: CollisionShape2D = gate_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
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

	# Phase 2 only owns the inventory-open candidate. Phase 3 will dispatch the
	# utility item itself, but the chord already cancels inventory opening.
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
	if not _active:
		return
	_inventory_candidate = false
	_inventory_overlay.close_inventory()
	_pause_overlay.close_overlay()
	_death_overlay.open_overlay()
	death_sequence_requested.emit()


func _on_level_whale_travel_requested() -> void:
	whale_travel_requested.emit()


func _on_level_city_entry_requested() -> void:
	if not _active or _in_city:
		return
	_in_city = true
	_level.activate_checkpoint(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
	_level.deactivate()
	_sea_environment.hide()
	_city.activate()
	_hud.set_location("Neresithoppos")


func _on_city_exit_requested() -> void:
	if not _active or not _in_city:
		return
	_in_city = false
	_city.deactivate()
	_sea_environment.show()
	_level.activate(CotcSeaOfPillars.CITY_GATE_SPAWN_POINT_ID)
	_hud.set_location("The Sea of Pillars")


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
	return lines