extends "res://scenes/characters/Hylas/hylas_reliable_input.gd"

## Equipment-aware action layer for Hylas.
##
## Input is matched through InputMap actions so remapped controls retain the
## same conflict rules. The first Item A binding shares the nearby interaction
## timing, while alternate Item A bindings continue to activate directly.

signal item_a_requested(item_id: StringName, origin: Vector2, direction: Vector2)

const NORMAL_CONCH_ID: StringName = &"normal_conch"
const TRIDACNA_SURFACE_LAUNCH_VELOCITY_SCALE: float = 1.41421356237

@onready var _item_visuals: CotcHylasItemVisuals = %ItemVisuals

var _equipped_item_a: StringName = NORMAL_CONCH_ID
var _utility_item_pressed_this_frame: bool = false
var _item_surge_remaining: float = 0.0
var _purple_shield_active: bool = false
var _camouflage_active: bool = false
var _normal_collision_layer: int = 1


func _ready() -> void:
	super._ready()
	_normal_collision_layer = collision_layer
	_item_visuals.set_equipped_item_a(_equipped_item_a)


func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id if not String(item_id).is_empty() else NORMAL_CONCH_ID
	if is_instance_valid(_item_visuals):
		_item_visuals.set_equipped_item_a(_equipped_item_a)


func get_equipped_item_a() -> StringName:
	return _equipped_item_a


func activate_normal_conch(direction: Vector2) -> bool:
	if not _can_begin_item_pose():
		return false
	if _conch_cooldown_remaining > 0.0:
		return false

	var resolved_direction: Vector2 = _resolve_item_direction(direction)
	_pending_conch_remaining = 0.0
	_start_conch(resolved_direction)
	return true


func activate_item_a_pose(direction: Vector2) -> bool:
	if not _can_begin_item_pose() or _conch_cooldown_remaining > 0.0:
		return false
	var resolved_direction: Vector2 = _resolve_item_direction(direction)
	_pending_conch_remaining = 0.0
	_start_item_a_pose(resolved_direction)
	return true


func activate_item_surge(duration_seconds: float = 0.90) -> bool:
	if (
			_death_sequence_active
			or not _play_enabled
			or crawl_active
			or airborne_active
			or _tail_flip_remaining > 0.0
			or _jump_elapsed > 0.0
			or _conch_remaining > 0.0
			or _burst_active
		):
		return false

	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	if input_direction.length_squared() <= 0.0001:
		input_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT

	var previous_charges: int = _burst_charges
	var previous_charge_timer: float = _burst_charge_timer
	_burst_charges = maxi(1, _burst_charges)
	_item_surge_remaining = maxf(0.05, duration_seconds)
	_start_burst(input_direction)
	_burst_charges = previous_charges
	_burst_charge_timer = previous_charge_timer
	if not _burst_active:
		_item_surge_remaining = 0.0
		return false
	return true


func is_item_surge_active() -> bool:
	return _item_surge_remaining > 0.0 and _burst_active


func _begin_surface_jump() -> void:
	var use_tridacna_launch: bool = _item_surge_remaining > 0.0
	super._begin_surface_jump()
	if use_tridacna_launch and airborne_active:
		velocity *= TRIDACNA_SURFACE_LAUNCH_VELOCITY_SCALE


func set_purple_shield_active(is_active: bool) -> void:
	_purple_shield_active = is_active


func is_purple_shield_active() -> bool:
	return _purple_shield_active


func set_camouflage_active(is_active: bool) -> void:
	_camouflage_active = is_active
	collision_layer = 0 if is_active else _normal_collision_layer
	if is_instance_valid(_item_visuals):
		_item_visuals.set_camouflage_active(is_active)


func is_camouflage_active() -> bool:
	return _camouflage_active


func is_contact_immune() -> bool:
	return _purple_shield_active or _camouflage_active


func set_surge_glow_active(is_active: bool) -> void:
	if is_instance_valid(_item_visuals):
		_item_visuals.set_surge_glow_active(is_active)


func clear_item_effect_state() -> void:
	_item_surge_remaining = 0.0
	_purple_shield_active = false
	_camouflage_active = false
	collision_layer = _normal_collision_layer
	if is_instance_valid(_item_visuals):
		_item_visuals.clear_item_visuals()


func set_play_enabled(enabled: bool) -> void:
	super.set_play_enabled(enabled)
	if not enabled:
		clear_item_effect_state()


func _input(event: InputEvent) -> void:
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return

	# Exact matching is essential because Item A, Item B and Tail Flip can share
	# the same base key while differing only by their modifiers.
	if event.is_action_pressed(&"utility_item", false, true):
		_utility_item_pressed_this_frame = true
		_space_action_pressed_this_frame = false
		_pending_interaction_remaining = 0.0
		_pending_conch_remaining = 0.0
		return

	if event.is_action_pressed(&"tail_flip", false, true):
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"conch", false, true):
		_space_action_pressed_this_frame = _is_primary_item_a_binding(event)


func _physics_process(delta: float) -> void:
	_item_surge_remaining = maxf(0.0, _item_surge_remaining - delta)
	super._physics_process(delta)
	_utility_item_pressed_this_frame = false


func _is_burst_input_held(input_direction: Vector2) -> bool:
	if _item_surge_remaining > 0.0:
		return true
	return super._is_burst_input_held(input_direction)


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active or _utility_item_pressed_this_frame:
		return

	if not _space_action_pressed_this_frame or not _interaction_available:
		_request_equipped_item_a(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		_request_equipped_item_a(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window


func _is_primary_item_a_binding(event: InputEvent) -> bool:
	var bindings: Array[InputEvent] = InputMap.action_get_events(&"conch")
	if bindings.is_empty():
		return true
	return event.is_match(bindings[0], true)


func _request_equipped_item_a(input_direction: Vector2) -> bool:
	if not _can_begin_item_pose():
		return false

	var direction: Vector2 = _conch_direction(input_direction)
	if _equipped_item_a == NORMAL_CONCH_ID:
		return activate_normal_conch(direction)

	if String(_equipped_item_a).is_empty():
		return false

	_pending_conch_remaining = 0.0
	item_a_requested.emit(_equipped_item_a, global_position, direction)
	return true


func _can_begin_item_pose() -> bool:
	return not (
		_death_sequence_active
		or not _play_enabled
		or crawl_active
		or airborne_active
		or _burst_active
		or _tail_flip_remaining > 0.0
		or _jump_elapsed > 0.0
	)


func _resolve_item_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return _conch_direction(Vector2.ZERO)
	return direction.normalized()


func _start_item_a_pose(direction: Vector2) -> void:
	_conch_remaining = conch_duration
	_conch_cooldown_remaining = conch_cooldown
	_special_velocity = (_swim_velocity + _burst_coast_velocity).move_toward(
		Vector2.ZERO,
		brake_deceleration * 0.08,
	)
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_set_visual_rotation(_direction_rotation(direction, conch_direction_angle_degrees))
	_set_animation(&"conch")
	_stop_movement_audio()
	_play_one_shot_audio(_conch_audio)
	_trigger_camera_shake()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("equipped_item_a=%s" % String(_equipped_item_a))
	lines.append("utility_item_pressed_this_frame=%s" % str(_utility_item_pressed_this_frame))
	lines.append("item_surge_remaining=%.2f" % _item_surge_remaining)
	lines.append("purple_shield_active=%s" % str(_purple_shield_active))
	lines.append("camouflage_active=%s" % str(_camouflage_active))
	if is_instance_valid(_item_visuals):
		lines.append_array(_item_visuals.get_debug_lines())
	return lines
