extends "res://scenes/characters/Hylas/hylas_reliable_input.gd"

## Equipment-aware action layer for Hylas.
##
## Input is matched through InputMap actions so remapped controls retain the
## same conflict rules. The first Item A binding shares the nearby interaction
## timing, while alternate Item A bindings continue to activate directly.

signal item_a_requested(item_id: StringName, origin: Vector2, direction: Vector2)

const NORMAL_CONCH_ID: StringName = &"normal_conch"
const SUPER_CONCH_ID: StringName = &"charonia_tritonis"
const CONUS_TEXTILE_ID: StringName = &"conus_textile"
const CONUS_CLIMB_ANIMATION: StringName = &"climb"
const TRIDACNA_SURFACE_LAUNCH_VELOCITY_SCALE: float = 1.41421356237
const NORMAL_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Conch_noise.mp3")
const SUPER_CONCH_AUDIO_STREAM: AudioStream = preload("res://assets/audio/Super Conch_noise.mp3")

@export_category("Conus Wall Climb")
@export_range(40.0, 900.0, 5.0) var conus_climb_speed: float = 260.0
@export_range(40.0, 240.0, 1.0) var conus_climb_minimum_distance: float = 100.0
@export_range(0.01, 0.90, 0.01) var conus_climb_input_deadzone: float = 0.16
@export_range(0.0, 180.0, 1.0) var conus_rope_hand_offset: float = 62.0
@export_range(-120.0, 120.0, 1.0) var normal_conus_climb_sprite_perpendicular_offset: float = -24.0

@onready var _item_visuals: CotcHylasItemVisuals = %ItemVisuals

var _equipped_item_a: StringName = NORMAL_CONCH_ID
var _utility_item_pressed_this_frame: bool = false
var _item_surge_remaining: float = 0.0
var _purple_shield_active: bool = false
var _camouflage_active: bool = false
var _normal_collision_layer: int = 1
var _conus_climb_active: bool = false
var _conus_climb_anchor: Vector2 = Vector2.ZERO
var _conus_climb_maximum_distance: float = 0.0
var _conus_climb_tether: Node
var _conus_climb_previous_facing_left: bool = false
var _conus_climb_wait_for_conch_release: bool = false
var _conus_climb_sprite_base_position: Vector2 = Vector2.ZERO
var _conus_climb_normal_sprite_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	super._ready()
	_normal_collision_layer = collision_layer
	_conus_climb_sprite_base_position = _animated_sprite.position
	_conus_climb_normal_sprite_scale = _animated_sprite.scale
	_item_visuals.set_equipped_item_a(_equipped_item_a)
	_sync_equipped_conch_audio()


func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id if not String(item_id).is_empty() else NORMAL_CONCH_ID
	if is_instance_valid(_item_visuals):
		_item_visuals.set_equipped_item_a(_equipped_item_a)
	_sync_equipped_conch_audio()


func get_equipped_item_a() -> StringName:
	return _equipped_item_a


func _sync_equipped_conch_audio() -> void:
	if not is_instance_valid(_conch_audio):
		return
	_conch_audio.stop()
	match _equipped_item_a:
		NORMAL_CONCH_ID:
			_conch_audio.stream = NORMAL_CONCH_AUDIO_STREAM
		SUPER_CONCH_ID:
			_conch_audio.stream = SUPER_CONCH_AUDIO_STREAM
		_:
			# Terebridae and Conus play their dedicated audio from the item controller.
			_conch_audio.stream = null


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


func begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if _death_sequence_active or not _play_enabled or not is_instance_valid(tether):
		return
	_conus_climb_active = true
	_conus_climb_anchor = anchor_position
	_conus_climb_tether = tether
	_conus_climb_wait_for_conch_release = Input.is_action_pressed(&"conch")
	_conus_climb_maximum_distance = maxf(
		conus_climb_minimum_distance,
		global_position.distance_to(anchor_position),
	)
	_conus_climb_previous_facing_left = _facing_left
	_facing_left = false
	_brake_active = false
	_burst_active = false
	_burst_remaining = 0.0
	_tail_flip_remaining = 0.0
	_conch_remaining = 0.0
	_pending_conch_remaining = 0.0
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_stop_movement_audio()
	_animated_sprite.speed_scale = 1.0
	_set_animation(CONUS_CLIMB_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.pause()
	_align_to_conus_rope()


func end_conus_wall_climb(tether: Node = null) -> void:
	if not _conus_climb_active:
		return
	if tether != null and is_instance_valid(_conus_climb_tether) and tether != _conus_climb_tether:
		return
	_conus_climb_active = false
	_conus_climb_tether = null
	_conus_climb_wait_for_conch_release = false
	_conus_climb_maximum_distance = 0.0
	_facing_left = _conus_climb_previous_facing_left
	_animated_sprite.speed_scale = 1.0
	velocity = Vector2.ZERO
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_animated_sprite.position = _conus_climb_sprite_base_position
	_set_visual_rotation(0.0)
	if _play_enabled and not _death_sequence_active:
		_set_animation(&"idle")


func is_conus_wall_climbing() -> bool:
	return _conus_climb_active


func get_conus_rope_origin() -> Vector2:
	if _conus_climb_active:
		var rope_vector: Vector2 = _conus_climb_anchor - global_position
		if rope_vector.length_squared() > 0.0001:
			return global_position + rope_vector.normalized() * conus_rope_hand_offset
	var marker: Node2D = get_node_or_null("ConchPulseOrigin") as Node2D
	return marker.global_position if marker != null else global_position


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
	end_conus_wall_climb()
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

	if _conus_climb_active:
		# Climb retraction is owned by _physics_process so firing and retraction
		# read the same Input action state.
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
	if _conus_climb_active:
		if _conus_climb_wait_for_conch_release:
			if not Input.is_action_pressed(&"conch"):
				_conus_climb_wait_for_conch_release = false
		elif Input.is_action_just_pressed(&"conch"):
			_space_action_pressed_this_frame = false
			_pending_conch_remaining = 0.0
			_pending_interaction_remaining = 0.0
			_utility_item_pressed_this_frame = false
			if is_instance_valid(_conus_climb_tether) and _conus_climb_tether.has_method(&"retract"):
				_conus_climb_tether.call(&"retract")
			else:
				end_conus_wall_climb()
			return
		_update_conus_wall_climb(delta)
		_utility_item_pressed_this_frame = false
		return
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
		or _conus_climb_active
		or _burst_active
		or _tail_flip_remaining > 0.0
		or _jump_elapsed > 0.0
	)


func _update_conus_wall_climb(delta: float) -> void:
	if (
			not is_instance_valid(_conus_climb_tether)
			or not _conus_climb_tether.has_method(&"is_wall_tethered")
			or not bool(_conus_climb_tether.call(&"is_wall_tethered"))
		):
		end_conus_wall_climb()
		return
	if _conus_climb_tether.has_method(&"get_anchor_position"):
		var anchor_value: Variant = _conus_climb_tether.call(&"get_anchor_position")
		if anchor_value is Vector2:
			_conus_climb_anchor = anchor_value

	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()

	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		end_conus_wall_climb(_conus_climb_tether)
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	var rope_distance: float = rope_vector.length()
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down",
	)
	var climb_axis: float = input_direction.dot(rope_direction)
	if absf(climb_axis) < conus_climb_input_deadzone:
		climb_axis = 0.0
	if climb_axis > 0.0 and rope_distance <= conus_climb_minimum_distance:
		climb_axis = 0.0
	elif climb_axis < 0.0 and rope_distance >= _conus_climb_maximum_distance:
		climb_axis = 0.0

	velocity = rope_direction * climb_axis * conus_climb_speed
	if climb_axis != 0.0:
		move_and_slide()
		global_position = _clamp_to_world(global_position)

	var corrected_vector: Vector2 = _conus_climb_anchor - global_position
	var corrected_distance: float = corrected_vector.length()
	if corrected_distance > 0.0001:
		var corrected_direction: Vector2 = corrected_vector / corrected_distance
		if corrected_distance > _conus_climb_maximum_distance:
			global_position = _conus_climb_anchor - corrected_direction * _conus_climb_maximum_distance
		elif corrected_distance < conus_climb_minimum_distance:
			global_position = _conus_climb_anchor - corrected_direction * conus_climb_minimum_distance

	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_align_to_conus_rope()
	_update_conus_climb_animation(climb_axis)


func _align_to_conus_rope() -> void:
	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	_set_visual_rotation(rope_direction.angle() + PI * 0.5)
	var normal_scale_x: float = maxf(absf(_conus_climb_normal_sprite_scale.x), 0.001)
	var greatfin_active: bool = absf(_animated_sprite.scale.x) > normal_scale_x * 1.15
	if greatfin_active:
		_animated_sprite.position = _conus_climb_sprite_base_position
	else:
		var rope_perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
		_animated_sprite.position = (
			_conus_climb_sprite_base_position
			+ rope_perpendicular * normal_conus_climb_sprite_perpendicular_offset
		)


func _update_conus_climb_animation(climb_axis: float) -> void:
	if _animated_sprite.animation != CONUS_CLIMB_ANIMATION:
		_set_animation(CONUS_CLIMB_ANIMATION)
	if climb_axis == 0.0:
		_animated_sprite.speed_scale = 1.0
		_animated_sprite.frame = 0
		_animated_sprite.pause()
		return
	var desired_speed: float = 1.0 if climb_axis > 0.0 else -1.0
	if not _animated_sprite.is_playing() or not is_equal_approx(_animated_sprite.speed_scale, desired_speed):
		_animated_sprite.speed_scale = desired_speed
		if desired_speed < 0.0 and _animated_sprite.frame == 0:
			_animated_sprite.frame = _animated_sprite.sprite_frames.get_frame_count(CONUS_CLIMB_ANIMATION) - 1
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)


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
	lines.append("conus_climb_active=%s" % str(_conus_climb_active))
	lines.append("conus_climb_anchor=%s" % str(_conus_climb_anchor))
	if is_instance_valid(_item_visuals):
		lines.append_array(_item_visuals.get_debug_lines())
	return lines
