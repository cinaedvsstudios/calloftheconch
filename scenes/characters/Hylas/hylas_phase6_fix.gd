extends "res://scenes/characters/Hylas/hylas_equipment_input.gd"

signal surge_ram_started(origin: Vector2, direction: Vector2, duration: float)

const NORMAL_TEREBRIDAE_HOLD_FRAME_INDEX: int = 6
const NORMAL_TEREBRIDAE_RELEASE_FRAME_INDEX: int = 7
const CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER: float = 1.15

@export_category("Death Menu Timing")
@export_range(0.5, 10.0, 0.1) var death_menu_drift_seconds: float = 3.0

var _death_menu_notification_sent: bool = false
var _death_menu_drift_elapsed: float = 0.0
var _terebridae_pose_active: bool = false
var _terebridae_release_active: bool = false
var _terebridae_stream_remaining: float = 0.0
var _terebridae_release_remaining: float = 0.0
var _conus_climb_previous_visual_scale: Vector2 = Vector2.ONE
var _conus_climb_previous_animation: StringName = &"idle"
var _conus_climb_previous_frame: int = 0


func activate_item_surge(duration_seconds: float = 30.0) -> bool:
	var activated: bool = super.activate_item_surge(duration_seconds)
	if not activated:
		return false
	var direction: Vector2 = _burst_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	surge_ram_started.emit(global_position, direction.normalized(), duration_seconds)
	return true


func hold_current_item_pose_for_duration(duration_seconds: float) -> void:
	if duration_seconds <= 0.0 or not is_instance_valid(_animated_sprite):
		return
	if _animated_sprite.animation != &"conch":
		return
	_terebridae_pose_active = true
	_terebridae_release_active = false
	_terebridae_stream_remaining = duration_seconds
	_terebridae_release_remaining = 0.0
	var release_duration: float = 1.0 / maxf(0.1, conch_animation_fps)
	_conch_remaining = maxf(_conch_remaining, duration_seconds + release_duration)
	if not _animated_sprite.is_playing():
		_animated_sprite.play(&"conch")


func _update_conch(delta: float) -> void:
	if not _terebridae_pose_active:
		super._update_conch(delta)
		return

	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_special_velocity = _special_velocity.move_toward(
		Vector2.ZERO,
		idle_momentum_deceleration * delta,
	)
	_update_held_conch_steering(delta)

	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"conch")
	var hold_frame: int = _get_terebridae_hold_frame(frame_count)
	var release_frame: int = _get_terebridae_release_frame(frame_count)

	if _terebridae_stream_remaining > 0.0:
		_terebridae_stream_remaining = maxf(0.0, _terebridae_stream_remaining - delta)
		if _animated_sprite.animation != &"conch":
			_set_animation(&"conch")
		if _animated_sprite.frame >= hold_frame:
			_animated_sprite.frame = hold_frame
			_animated_sprite.pause()
		return

	if not _terebridae_release_active:
		_terebridae_release_active = true
		_terebridae_release_remaining = 1.0 / maxf(0.1, conch_animation_fps)
		_animated_sprite.animation = &"conch"
		_animated_sprite.frame = release_frame
		_animated_sprite.pause()
		return

	_terebridae_release_remaining = maxf(0.0, _terebridae_release_remaining - delta)
	_animated_sprite.animation = &"conch"
	_animated_sprite.frame = release_frame
	_animated_sprite.pause()
	if _terebridae_release_remaining <= 0.0:
		_finish_terebridae_pose()


func _get_terebridae_hold_frame(frame_count: int) -> int:
	if frame_count >= 10:
		return NORMAL_TEREBRIDAE_HOLD_FRAME_INDEX
	return maxi(0, frame_count - 2)


func _get_terebridae_release_frame(frame_count: int) -> int:
	if frame_count >= 10:
		return NORMAL_TEREBRIDAE_RELEASE_FRAME_INDEX
	return maxi(0, frame_count - 1)


func _update_held_conch_steering(delta: float) -> void:
	var vertical_input: float = Input.get_axis(&"move_up", &"move_down")
	if absf(vertical_input) <= 0.01:
		return
	var vertical_axis: float = -1.0 if vertical_input < 0.0 else 1.0
	var facing_axis: float = -1.0 if _facing_left else 1.0
	var target_rotation: float = (
		vertical_axis
		* facing_axis
		* deg_to_rad(conch_direction_angle_degrees)
	)
	var rotation_step: float = deg_to_rad(conch_steer_speed_degrees) * delta
	_set_visual_rotation(move_toward(_visual_rotation, target_rotation, rotation_step))


func _finish_terebridae_pose() -> void:
	_clear_terebridae_pose_state()
	_conch_remaining = 0.0
	_set_visual_rotation(0.0)
	if _play_enabled and not _death_sequence_active:
		_set_animation(&"idle")


func _clear_terebridae_pose_state() -> void:
	_terebridae_pose_active = false
	_terebridae_release_active = false
	_terebridae_stream_remaining = 0.0
	_terebridae_release_remaining = 0.0


func begin_conus_wall_climb(anchor_position: Vector2, tether: Node) -> void:
	if is_instance_valid(_animated_sprite):
		_conus_climb_previous_visual_scale = _animated_sprite.scale
		_conus_climb_previous_animation = _animated_sprite.animation
		_conus_climb_previous_frame = _animated_sprite.frame
	super.begin_conus_wall_climb(anchor_position, tether)
	if not _conus_climb_active or not is_instance_valid(_animated_sprite):
		return
	_animated_sprite.scale = (
		_conus_climb_previous_visual_scale
		* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
	)
	if _animated_sprite.sprite_frames.has_animation(_conus_climb_previous_animation):
		_animated_sprite.animation = _conus_climb_previous_animation
		_animated_sprite.frame = mini(
			_conus_climb_previous_frame,
			_animated_sprite.sprite_frames.get_frame_count(
				_conus_climb_previous_animation
			) - 1,
		)
		_animated_sprite.pause()
	_align_to_conus_rope()


func end_conus_wall_climb(tether: Node = null) -> void:
	var was_climbing: bool = _conus_climb_active
	var restore_scale: Vector2 = _conus_climb_previous_visual_scale
	super.end_conus_wall_climb(tether)
	if was_climbing and not _conus_climb_active and is_instance_valid(_animated_sprite):
		_animated_sprite.scale = restore_scale


func get_conus_rope_origin() -> Vector2:
	if (
			not _conus_climb_active
			and is_instance_valid(_animated_sprite)
			and _animated_sprite.animation == &"conch"
			and is_instance_valid(_item_visuals)
		):
		return _item_visuals.get_shell_rope_origin()
	if _conus_climb_active:
		var rope_vector: Vector2 = _conus_climb_anchor - global_position
		if rope_vector.length_squared() > 0.0001:
			return (
				global_position
				+ rope_vector.normalized()
				* conus_rope_hand_offset
				* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
			)
	return super.get_conus_rope_origin()


func _align_to_conus_rope() -> void:
	var rope_vector: Vector2 = _conus_climb_anchor - global_position
	if rope_vector.length_squared() <= 0.0001:
		return
	var rope_direction: Vector2 = rope_vector.normalized()
	_set_visual_rotation(rope_direction.angle() + PI * 0.5)
	var normal_scale_x: float = maxf(absf(_conus_climb_normal_sprite_scale.x), 0.001)
	var greatfin_active: bool = (
		absf(_conus_climb_previous_visual_scale.x)
		> normal_scale_x * 1.15
	)
	if greatfin_active:
		_animated_sprite.position = _conus_climb_sprite_base_position
	else:
		var rope_perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
		_animated_sprite.position = (
			_conus_climb_sprite_base_position
			+ rope_perpendicular
			* normal_conus_climb_sprite_perpendicular_offset
			* CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER
		)


func _update_conus_climb_animation(climb_axis: float) -> void:
	if climb_axis == 0.0:
		_animated_sprite.speed_scale = 1.0
		_animated_sprite.pause()
		return

	var desired_speed: float = 1.0 if climb_axis > 0.0 else -1.0
	if _animated_sprite.animation != CONUS_CLIMB_ANIMATION:
		_set_animation(CONUS_CLIMB_ANIMATION)
		_animated_sprite.frame = (
			0
			if desired_speed > 0.0
			else _animated_sprite.sprite_frames.get_frame_count(
				CONUS_CLIMB_ANIMATION
			) - 1
		)
		_animated_sprite.speed_scale = desired_speed
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)
		return

	if (
			not _animated_sprite.is_playing()
			or not is_equal_approx(_animated_sprite.speed_scale, desired_speed)
		):
		_animated_sprite.speed_scale = desired_speed
		if desired_speed < 0.0 and _animated_sprite.frame == 0:
			_animated_sprite.frame = (
				_animated_sprite.sprite_frames.get_frame_count(
					CONUS_CLIMB_ANIMATION
				) - 1
			)
		_animated_sprite.play(CONUS_CLIMB_ANIMATION)


func clear_item_effect_state() -> void:
	_clear_terebridae_pose_state()
	super.clear_item_effect_state()


func start_death_sequence() -> void:
	if is_death_sequence_active():
		return
	_clear_terebridae_pose_state()

	# Greatfin and equipment visuals can replace SpriteFrames at runtime. Build the
	# death animations into a local copy of the currently active frame set.
	if is_instance_valid(_animated_sprite) and _animated_sprite.sprite_frames != null:
		var local_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
		_animated_sprite.sprite_frames = local_frames
		_configure_death_animations()

	var item_visuals: Node = get_node_or_null("ItemVisuals")
	if item_visuals != null and item_visuals.has_method(&"clear_item_visuals"):
		item_visuals.call(&"clear_item_visuals")

	_death_menu_notification_sent = false
	_death_menu_drift_elapsed = 0.0
	super.start_death_sequence()


func cancel_death_sequence() -> void:
	_death_menu_notification_sent = false
	_death_menu_drift_elapsed = 0.0
	super.cancel_death_sequence()


func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_death_menu_drift_elapsed = 0.0
	_set_animation(DEATH_DRIFT_ANIMATION)


func _update_death_sequence(delta: float) -> void:
	super._update_death_sequence(delta)
	if not _death_drift_active or _death_menu_notification_sent:
		return
	_death_menu_drift_elapsed += maxf(delta, 0.0)
	if _death_menu_drift_elapsed < death_menu_drift_seconds:
		return
	_death_menu_notification_sent = true
	death_drift_started.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("death_menu_notified=%s" % str(_death_menu_notification_sent))
	lines.append("death_menu_drift_elapsed=%.2f" % _death_menu_drift_elapsed)
	lines.append("death_menu_drift_seconds=%.2f" % death_menu_drift_seconds)
	lines.append("terebridae_pose_active=%s" % str(_terebridae_pose_active))
	lines.append("terebridae_stream_remaining=%.2f" % _terebridae_stream_remaining)
	lines.append("conus_climb_visual_scale=%.2f" % CONUS_CLIMB_VISUAL_SCALE_MULTIPLIER)
	return lines