class_name HylasController
extends CharacterBody2D
## Owns Hylas movement, presentation actions, local action audio and camera feedback.

signal normal_conch_used(origin: Vector2, direction: Vector2)
signal surface_splash_requested(origin: Vector2)

const PLAYER_EDGE_PADDING: float = 105.0
const BURST_PREPARATION_FRAME_COUNT: int = 2
const TAIL_FLIP_PREPARATION_FRAME_COUNT: int = 2
const DOUBLE_CONCH_TAP_WINDOW: float = 0.20
const CONCH_DIRECTION_ANGLE_DEGREES: float = 45.0
const JUMP_FRAME_SEQUENCE: Array = [0, 1, 1, 2, 2, 3]
const SHADOW_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 shadow_tint : source_color = vec4(0.005, 0.04, 0.12, 0.16);
uniform float blur_radius = 10.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * max(0.5, blur_radius);
	float alpha = texture(TEXTURE, UV).a * 0.20;
	alpha += texture(TEXTURE, clamp(UV + vec2(-1.0, 0.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(1.0, 0.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(0.0, -1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(0.0, 1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(-1.0, -1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(1.0, -1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(-1.0, 1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	alpha += texture(TEXTURE, clamp(UV + vec2(1.0, 1.0) * step_size, vec2(0.0), vec2(1.0))).a * 0.10;
	COLOR = vec4(shadow_tint.rgb, clamp(alpha, 0.0, 1.0) * shadow_tint.a);
}
"""

@export var start_position: Vector2 = Vector2(640.0, 360.0)

@onready var _sprite: Sprite2D = %Sprite
@onready var _shadow: Sprite2D = %HylasShadow
@onready var _collision_shape: CollisionShape2D = %HylasCollision
@onready var _camera: Camera2D = %Camera2D
@onready var _tail_bubble_burst: TailBubbleBurst = %TailBubbleBurst
@onready var _swim_audio: AudioStreamPlayer = %SwimAudio
@onready var _speed_audio: AudioStreamPlayer = %SpeedAudio
@onready var _conch_audio: AudioStreamPlayer = %ConchAudio

var _tuning: PrototypeTuning = PrototypeTuning.new()
var _swim_frames: Array[Texture2D] = []
var _speed_frames: Array[Texture2D] = []
var _conch_frames: Array[Texture2D] = []
var _jump_frames: Array[Texture2D] = []
var _tail_flip_frames: Array[Texture2D] = []
var _stop_frames: Array[Texture2D] = []
var _player_velocity: Vector2 = Vector2.ZERO
var _world_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
var _swim_ceiling_y: float = 105.0
var _surface_waterline_y: float = 105.0
var _frame_time: float = 0.0
var _frame_index: int = 0
var _current_time: float = 0.0
var _tail_burst_remaining: float = 0.0
var _burst_elapsed: float = 0.0
var _burst_total_duration: float = 0.0
var _burst_cooldown_remaining: float = 0.0
var _burst_charge_recovery_remaining: float = 0.0
var _burst_charges: int = 0
var _burst_direction: Vector2 = Vector2.RIGHT
var _burst_tail_has_played: bool = false
var _tail_flip_elapsed: float = 0.0
var _tail_flip_total_duration: float = 0.0
var _tail_flip_cooldown_remaining: float = 0.0
var _tail_flip_direction: Vector2 = Vector2.RIGHT
var _tail_flip_tail_has_played: bool = false
var _conch_cooldown_remaining: float = 0.0
var _is_using_conch: bool = false
var _facing_left: bool = false
var _play_enabled: bool = false
var _animation_mode: StringName = &"idle"
var _visual_rotation: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _shadow_material: ShaderMaterial
var _pending_surface_jump: bool = false
var _jump_elapsed: float = 0.0
var _jump_total_duration: float = 0.0
var _jump_start_position: Vector2 = Vector2.ZERO
var _jump_end_position: Vector2 = Vector2.ZERO
var _jump_reentry_splash_played: bool = false
var _pending_conch_timer: float = 0.0
var _pending_conch_direction: Vector2 = Vector2.RIGHT
var _camera_rest_offset: Vector2 = Vector2.ZERO
var _camera_shake_remaining: float = 0.0
var _camera_shake_duration: float = 0.0
var _camera_shake_strength: float = 0.0


func _ready() -> void:
	_random.randomize()
	_swim_frames = PrototypeAssets.load_hylas_frames("hylas-swim")
	_speed_frames = PrototypeAssets.load_hylas_frames("hylas-speed")
	_conch_frames = PrototypeAssets.load_hylas_frames("hylas-conch1")
	_jump_frames = PrototypeAssets.load_hylas_frames("hylas-jump")
	_tail_flip_frames = PrototypeAssets.load_hylas_frames("hylas-flip")
	_stop_frames = PrototypeAssets.load_hylas_frames("hylas-stop")
	_shadow_material = _create_shadow_material()
	_shadow.material = _shadow_material
	_camera_rest_offset = _camera.offset
	_configure_audio()
	_burst_charges = _get_max_burst_charges()
	refresh_tuning()
	_reset_tail_burst_timer()
	_show_idle_frame()
	set_physics_process(false)


func bind_tuning(tuning: PrototypeTuning) -> void:
	_tuning = tuning
	_burst_charges = clampi(_burst_charges, 1, _get_max_burst_charges())
	refresh_tuning()


func refresh_tuning() -> void:
	_camera.position_smoothing_speed = _tuning.camera_smoothing_speed
	_tail_bubble_burst.configure(_tuning)
	_apply_collision_shape()
	_apply_shadow_style()
	_set_frame(_get_active_frames(), _frame_index)


func configure_world(world_size: Vector2, desired_start_position: Vector2, swim_ceiling_y: float) -> void:
	_world_bounds = Rect2(Vector2.ZERO, Vector2(maxf(1280.0, world_size.x), maxf(720.0, world_size.y)))
	_surface_waterline_y = swim_ceiling_y
	_swim_ceiling_y = swim_ceiling_y
	start_position = desired_start_position
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = ceili(_world_bounds.size.x)
	_camera.limit_bottom = ceili(_world_bounds.size.y)


func set_play_enabled(enabled: bool) -> void:
	_play_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		_player_velocity = Vector2.ZERO
		_burst_total_duration = 0.0
		_tail_flip_total_duration = 0.0
		_jump_total_duration = 0.0
		_pending_conch_timer = 0.0
		_pending_surface_jump = false
		_stop_movement_audio()
		_tail_bubble_burst.hide()
		_camera.offset = _camera_rest_offset


func reset_to_start() -> void:
	global_position = _clamp_to_world(start_position)
	_player_velocity = Vector2.ZERO
	_frame_time = 0.0
	_frame_index = 0
	_burst_elapsed = 0.0
	_burst_total_duration = 0.0
	_burst_cooldown_remaining = 0.0
	_burst_charge_recovery_remaining = 0.0
	_burst_charges = _get_max_burst_charges()
	_tail_flip_elapsed = 0.0
	_tail_flip_total_duration = 0.0
	_tail_flip_cooldown_remaining = 0.0
	_conch_cooldown_remaining = 0.0
	_is_using_conch = false
	_pending_conch_timer = 0.0
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_jump_total_duration = 0.0
	_jump_reentry_splash_played = false
	_camera.offset = _camera_rest_offset
	_stop_movement_audio()
	_reset_tail_burst_timer()
	_show_idle_frame()


func get_diagnostic_summary() -> String:
	return "Hylas: (%.0f, %.0f) | Burst: %d/%d | Flip: %s | Jump: %s" % [
		global_position.x,
		global_position.y,
		_burst_charges,
		_get_max_burst_charges(),
		"yes" if _tail_flip_total_duration > 0.0 else "no",
		"yes" if _jump_total_duration > 0.0 else "no",
	]


func _physics_process(delta: float) -> void:
	if not _play_enabled:
		return

	_current_time += delta
	_burst_cooldown_remaining = maxf(0.0, _burst_cooldown_remaining - delta)
	_tail_flip_cooldown_remaining = maxf(0.0, _tail_flip_cooldown_remaining - delta)
	_conch_cooldown_remaining = maxf(0.0, _conch_cooldown_remaining - delta)
	_update_burst_charge_recovery(delta)
	_update_camera_shake(delta)

	if _jump_total_duration > 0.0:
		_update_jump(delta)
		return

	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if Input.is_action_just_pressed(&"conch"):
		_handle_conch_pressed(input_direction)
	_update_pending_conch(delta)

	if _tail_flip_total_duration > 0.0:
		_update_tail_flip(delta)
		_apply_current_and_position(delta, false)
		return
	if _is_using_conch:
		_update_conch(delta)
		_apply_current_and_position(delta, true)
		return

	if _should_begin_action_a_burst(input_direction):
		_try_begin_action_a(input_direction)
	if _burst_total_duration > 0.0:
		_update_burst(delta)
	elif _is_braking(input_direction):
		_update_brake(delta)
	elif input_direction != Vector2.ZERO:
		_update_swim(input_direction, delta)
	else:
		_update_idle(delta)

	_apply_current_and_position(delta, input_direction == Vector2.ZERO)
	if _pending_surface_jump and _burst_total_duration > 0.0 and global_position.y <= _surface_waterline_y:
		_begin_surface_jump()


func _should_begin_action_a_burst(input_direction: Vector2) -> bool:
	return _pending_conch_timer <= 0.0 and _burst_total_duration <= 0.0 and _burst_cooldown_remaining <= 0.0 and _burst_charges > 0 and Input.is_action_pressed(&"action_a") and input_direction != Vector2.ZERO and (Input.is_action_just_pressed(&"action_a") or _is_movement_action_just_pressed())


func _try_begin_action_a(input_direction: Vector2) -> void:
	var vertical_axis: float = _get_vertical_axis(input_direction)
	if vertical_axis == 0.0 and _is_backward_input(input_direction):
		return
	_pending_conch_timer = 0.0
	_pending_surface_jump = vertical_axis < 0.0 and _can_attempt_surface_jump()
	if vertical_axis != 0.0:
		_burst_direction = _get_facing_tilted_direction(vertical_axis, _tuning.vertical_burst_angle_degrees)
	else:
		_facing_left = input_direction.x < 0.0
		_burst_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_burst_charges -= 1
	_burst_charge_recovery_remaining = maxf(_burst_charge_recovery_remaining, _tuning.burst_charge_recovery)
	_burst_total_duration = _get_burst_total_duration()
	_burst_elapsed = 0.0
	_burst_cooldown_remaining = _tuning.burst_cooldown
	_burst_tail_has_played = false
	_animation_mode = &"speed"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(_get_burst_sprite_rotation())
	_set_frame(_get_burst_frames(), 0)
	_stop_swim_audio()


func _update_burst(delta: float) -> void:
	var frames: Array[Texture2D] = _get_burst_frames()
	_burst_elapsed = minf(_burst_total_duration, _burst_elapsed + delta)
	_frame_index = _get_timed_frame_index(_burst_elapsed, _tuning.speed_frame_duration, frames.size())
	_set_frame(frames, _frame_index)
	if _frame_index >= mini(BURST_PREPARATION_FRAME_COUNT, maxi(0, frames.size() - 1)):
		_player_velocity = _burst_direction * _tuning.burst_speed
		if not _burst_tail_has_played:
			_tail_bubble_burst.play_at_tail(_facing_left, _visual_rotation, _tuning.tail_burst_action_size_multiplier)
			_play_speed_audio()
			_trigger_camera_shake(_tuning.burst_camera_shake_strength, _tuning.burst_camera_shake_duration)
			_burst_tail_has_played = true
	else:
		_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * delta)
	if _burst_elapsed >= _burst_total_duration:
		_burst_total_duration = 0.0
		_pending_surface_jump = false
		_stop_speed_audio()
		_reset_tail_burst_timer()
		_set_visual_rotation(0.0)


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _is_using_conch or _burst_total_duration > 0.0 or _jump_total_duration > 0.0:
		return
	if _pending_conch_timer > 0.0 and _can_begin_tail_flip():
		_pending_conch_timer = 0.0
		_begin_tail_flip()
		return
	if _conch_cooldown_remaining <= 0.0:
		_pending_conch_direction = _get_conch_direction(input_direction)
		_pending_conch_timer = DOUBLE_CONCH_TAP_WINDOW


func _update_pending_conch(delta: float) -> void:
	if _pending_conch_timer <= 0.0:
		return
	_pending_conch_timer = maxf(0.0, _pending_conch_timer - delta)
	if _pending_conch_timer <= 0.0 and _conch_cooldown_remaining <= 0.0 and not _is_using_conch and _tail_flip_total_duration <= 0.0:
		_begin_conch(_pending_conch_direction)


func _can_begin_tail_flip() -> bool:
	return _tail_flip_cooldown_remaining <= 0.0 and _tail_flip_total_duration <= 0.0


func _begin_tail_flip() -> void:
	_tail_flip_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_tail_flip_total_duration = _get_tail_flip_total_duration()
	_tail_flip_elapsed = 0.0
	_tail_flip_cooldown_remaining = _tuning.tail_flip_cooldown
	_tail_flip_tail_has_played = false
	_player_velocity = Vector2.ZERO
	_animation_mode = &"tail_flip"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	_set_frame(_get_tail_flip_frames(), 0)
	_stop_swim_audio()


func _update_tail_flip(delta: float) -> void:
	var frames: Array[Texture2D] = _get_tail_flip_frames()
	_tail_flip_elapsed = minf(_tail_flip_total_duration, _tail_flip_elapsed + delta)
	_frame_index = _get_timed_frame_index(_tail_flip_elapsed, _tuning.tail_flip_frame_duration, frames.size())
	_set_frame(frames, _frame_index)
	if _frame_index >= mini(TAIL_FLIP_PREPARATION_FRAME_COUNT, maxi(0, frames.size() - 1)):
		_player_velocity = _tail_flip_direction * _tuning.tail_flip_speed
		if not _tail_flip_tail_has_played:
			_tail_bubble_burst.play_at_tail(_facing_left, 0.0, _tuning.tail_burst_action_size_multiplier)
			_play_speed_audio()
			_trigger_camera_shake(_tuning.tail_flip_camera_shake_strength, _tuning.tail_flip_camera_shake_duration)
			_tail_flip_tail_has_played = true
	else:
		_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * delta)
	if _tail_flip_elapsed >= _tail_flip_total_duration:
		_tail_flip_total_duration = 0.0
		_stop_speed_audio()
		_reset_tail_burst_timer()
		_show_idle_frame()


func _begin_conch(direction: Vector2) -> void:
	_is_using_conch = true
	_conch_cooldown_remaining = _tuning.normal_conch_cooldown
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * 0.08)
	_animation_mode = &"conch"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(_get_direction_rotation(direction, CONCH_DIRECTION_ANGLE_DEGREES))
	_set_frame(_conch_frames, 0)
	_stop_movement_audio()
	_play_conch_audio()
	_trigger_camera_shake(_tuning.conch_camera_shake_strength, _tuning.conch_camera_shake_duration)
	normal_conch_used.emit(global_position, direction)


func _update_conch(delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.idle_momentum_deceleration * delta)
	_frame_time += delta
	if _frame_time < _tuning.conch_frame_duration:
		return
	_frame_time = 0.0
	_frame_index += 1
	if _frame_index >= _conch_frames.size():
		_is_using_conch = false
		_show_idle_frame()
		return
	_set_frame(_conch_frames, _frame_index)


func _update_brake(delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * delta)
	_stop_movement_audio()
	_update_stop_animation(delta)


func _update_stop_animation(delta: float) -> void:
	if _stop_frames.is_empty():
		_show_idle_frame()
		return
	if _animation_mode != &"stop":
		_animation_mode = &"stop"
		_frame_index = 0
		_frame_time = 0.0
		_set_visual_rotation(0.0)
		_set_frame(_stop_frames, 0)
		return
	if _frame_index >= _stop_frames.size() - 1:
		return
	_frame_time += delta
	if _frame_time >= _tuning.conch_frame_duration:
		_frame_time = 0.0
		_frame_index += 1
		_set_frame(_stop_frames, _frame_index)


func _update_swim(input_direction: Vector2, delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(input_direction * _tuning.swim_speed, _tuning.swim_acceleration * delta)
	if absf(input_direction.x) > 0.01:
		_facing_left = input_direction.x < 0.0
	_set_visual_rotation(0.0)
	_update_loop_animation(_swim_frames, _tuning.swim_frame_duration, &"swim", delta)
	_update_tail_burst(delta)
	_play_swim_audio()


func _update_idle(delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.idle_momentum_deceleration * delta)
	_stop_movement_audio()
	_show_idle_frame()


func _apply_current_and_position(delta: float, is_idle: bool) -> void:
	var water_velocity: Vector2 = _get_current_velocity()
	if is_idle:
		water_velocity.y += _tuning.idle_sink_speed
	move_and_collide((_player_velocity + water_velocity) * delta)
	global_position = _clamp_to_world(global_position)


func _get_current_velocity() -> Vector2:
	return Vector2(
		_tuning.current_base_x + sin(_current_time * _tuning.current_sway_frequency * TAU) * _tuning.current_sway_horizontal,
		_tuning.current_base_y + cos(_current_time * _tuning.current_sway_frequency * TAU * 0.67) * _tuning.current_sway_vertical,
	)


func _is_braking(input_direction: Vector2) -> bool:
	return Input.is_action_pressed(&"action_a") and (input_direction == Vector2.ZERO or _is_backward_input(input_direction))


func _is_backward_input(input_direction: Vector2) -> bool:
	if absf(input_direction.x) < 0.15:
		return false
	var facing_direction: Vector2 = Vector2.LEFT if _facing_left else Vector2.RIGHT
	return input_direction.dot(facing_direction) < -0.15


func _is_movement_action_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right") or Input.is_action_just_pressed(&"move_up") or Input.is_action_just_pressed(&"move_down")


func _get_vertical_axis(input_direction: Vector2) -> float:
	if input_direction.y < -0.15:
		return -1.0
	if input_direction.y > 0.15:
		return 1.0
	return 0.0


func _get_facing_tilted_direction(vertical_axis: float, degrees: float) -> Vector2:
	var facing_axis: float = -1.0 if _facing_left else 1.0
	var radians: float = deg_to_rad(degrees)
	return Vector2(facing_axis * cos(radians), vertical_axis * sin(radians)).normalized()


func _get_conch_direction(input_direction: Vector2) -> Vector2:
	var vertical_axis: float = _get_vertical_axis(input_direction)
	if vertical_axis == 0.0:
		return Vector2.LEFT if _facing_left else Vector2.RIGHT
	return _get_facing_tilted_direction(vertical_axis, CONCH_DIRECTION_ANGLE_DEGREES)


func _get_burst_sprite_rotation() -> float:
	return _get_direction_rotation(_burst_direction, _tuning.vertical_burst_angle_degrees)


func _get_direction_rotation(direction: Vector2, degrees: float) -> float:
	if absf(direction.y) < 0.01:
		return 0.0
	var vertical_axis: float = -1.0 if direction.y < 0.0 else 1.0
	var facing_axis: float = -1.0 if _facing_left else 1.0
	return vertical_axis * facing_axis * deg_to_rad(degrees)


func _get_burst_frames() -> Array[Texture2D]:
	return _speed_frames if not _speed_frames.is_empty() else _swim_frames


func _get_tail_flip_frames() -> Array[Texture2D]:
	return _tail_flip_frames if not _tail_flip_frames.is_empty() else _get_burst_frames()


func _get_burst_total_duration() -> float:
	return maxf(_tuning.burst_duration, float(maxi(1, _get_burst_frames().size())) * _tuning.speed_frame_duration)


func _get_tail_flip_total_duration() -> float:
	return maxf(_tuning.tail_flip_duration, float(maxi(1, _get_tail_flip_frames().size())) * _tuning.tail_flip_frame_duration)


func _get_timed_frame_index(elapsed: float, frame_duration: float, frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	return clampi(floori(elapsed / maxf(0.02, frame_duration)), 0, frame_count - 1)


func _get_max_burst_charges() -> int:
	return maxi(1, roundi(_tuning.burst_max_charges))


func _update_burst_charge_recovery(delta: float) -> void:
	if _burst_charges >= _get_max_burst_charges():
		_burst_charge_recovery_remaining = 0.0
		return
	_burst_charge_recovery_remaining = maxf(0.0, _burst_charge_recovery_remaining - delta)
	if _burst_charge_recovery_remaining <= 0.0:
		_burst_charges += 1
		if _burst_charges < _get_max_burst_charges():
			_burst_charge_recovery_remaining = _tuning.burst_charge_recovery


func _update_tail_burst(delta: float) -> void:
	_tail_burst_remaining -= delta
	if _tail_burst_remaining > 0.0:
		return
	_tail_bubble_burst.play_at_tail(_facing_left, _visual_rotation)
	_reset_tail_burst_timer()


func _reset_tail_burst_timer() -> void:
	_tail_burst_remaining = _random.randf_range(_tuning.tail_burst_interval_min, _tuning.tail_burst_interval_max)


func _update_loop_animation(frames: Array[Texture2D], frame_duration: float, mode: StringName, delta: float) -> void:
	if frames.is_empty():
		return
	if _animation_mode != mode:
		_animation_mode = mode
		_frame_index = 0
		_frame_time = 0.0
		_set_frame(frames, 0)
	_frame_time += delta
	if _frame_time >= frame_duration:
		_frame_time = 0.0
		_frame_index = (_frame_index + 1) % frames.size()
		_set_frame(frames, _frame_index)


func _show_idle_frame() -> void:
	_animation_mode = &"idle"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	_set_frame(_swim_frames, 0)


func _get_active_frames() -> Array[Texture2D]:
	match _animation_mode:
		&"conch": return _conch_frames
		&"speed": return _get_burst_frames()
		&"tail_flip": return _get_tail_flip_frames()
		&"stop": return _stop_frames if not _stop_frames.is_empty() else _swim_frames
		&"jump": return _jump_frames if not _jump_frames.is_empty() else _get_burst_frames()
		_: return _swim_frames


func _set_frame(frames: Array[Texture2D], index: int) -> void:
	if frames.is_empty():
		return
	var texture: Texture2D = frames[clampi(index, 0, frames.size() - 1)]
	var scale_factor: float = _tuning.hylas_display_height / maxf(1.0, float(texture.get_height()))
	_sprite.texture = texture
	_sprite.flip_h = _facing_left
	_sprite.rotation = _visual_rotation
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_shadow.texture = texture
	_shadow.flip_h = _facing_left
	_shadow.rotation = _visual_rotation
	_shadow.scale = Vector2(scale_factor * _tuning.hylas_shadow_scale, scale_factor * _tuning.hylas_shadow_scale)
	_apply_shadow_style()


func _set_visual_rotation(rotation_radians: float) -> void:
	_visual_rotation = rotation_radians
	_sprite.rotation = rotation_radians
	_shadow.rotation = rotation_radians
	_collision_shape.rotation = rotation_radians


func _apply_collision_shape() -> void:
	var rectangle_shape: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		rectangle_shape.size = Vector2(maxf(70.0, _tuning.hylas_display_height * 0.60), maxf(30.0, _tuning.hylas_display_height * 0.24))


func _apply_shadow_style() -> void:
	_shadow.position = Vector2(_tuning.hylas_shadow_offset_x, _tuning.hylas_shadow_offset_y)
	_shadow.visible = _tuning.hylas_shadow_opacity > 0.0
	if _shadow_material != null:
		_shadow_material.set_shader_parameter(&"shadow_tint", Color(0.005, 0.04, 0.12, _tuning.hylas_shadow_opacity))
		_shadow_material.set_shader_parameter(&"blur_radius", _tuning.hylas_shadow_blur_radius)


func _create_shadow_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SHADOW_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _trigger_camera_shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	_camera_shake_strength = maxf(_camera_shake_strength, strength)
	_camera_shake_duration = maxf(_camera_shake_duration, duration)
	_camera_shake_remaining = maxf(_camera_shake_remaining, duration)


func _update_camera_shake(delta: float) -> void:
	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_rest_offset
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	var ratio: float = _camera_shake_remaining / maxf(0.001, _camera_shake_duration)
	var amplitude: float = _camera_shake_strength * ratio
	_camera.offset = _camera_rest_offset + Vector2(_random.randf_range(-amplitude, amplitude), _random.randf_range(-amplitude, amplitude))
	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_rest_offset
		_camera_shake_strength = 0.0
		_camera_shake_duration = 0.0


func _configure_audio() -> void:
	_swim_audio.stream = PrototypeAssets.load_audio(PrototypeAssets.SWIM_SOUND_CANDIDATES)
	_speed_audio.stream = PrototypeAssets.load_audio(PrototypeAssets.SPEED_SOUND_CANDIDATES)
	_conch_audio.stream = PrototypeAssets.load_audio(PrototypeAssets.CONCH_SOUND_CANDIDATES)
	PrototypeAssets.set_audio_looping(_swim_audio.stream)
	PrototypeAssets.set_audio_looping(_speed_audio.stream)


func _play_swim_audio() -> void:
	_stop_speed_audio()
	if _swim_audio.stream != null and not _swim_audio.playing:
		_swim_audio.play()


func _play_speed_audio() -> void:
	_stop_swim_audio()
	if _speed_audio.stream != null and not _speed_audio.playing:
		_speed_audio.play()


func _play_conch_audio() -> void:
	if _conch_audio.stream != null:
		_conch_audio.stop()
		_conch_audio.play()


func _stop_swim_audio() -> void:
	if _swim_audio.playing:
		_swim_audio.stop()


func _stop_speed_audio() -> void:
	if _speed_audio.playing:
		_speed_audio.stop()


func _stop_movement_audio() -> void:
	_stop_swim_audio()
	_stop_speed_audio()


func _can_attempt_surface_jump() -> bool:
	return global_position.y <= _surface_waterline_y + _tuning.jump_trigger_depth


func _begin_surface_jump() -> void:
	_pending_surface_jump = false
	_burst_total_duration = 0.0
	_player_velocity = Vector2.ZERO
	_jump_elapsed = 0.0
	_jump_total_duration = maxf(0.20, _tuning.jump_frame_duration * float(JUMP_FRAME_SEQUENCE.size()))
	_jump_start_position = Vector2(global_position.x, _surface_waterline_y)
	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end_position = Vector2(_jump_start_position.x + facing_sign * _tuning.jump_forward_distance, _surface_waterline_y + 40.0)
	_jump_reentry_splash_played = false
	_animation_mode = &"jump"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	global_position = _jump_start_position
	_stop_movement_audio()
	surface_splash_requested.emit(_jump_start_position)
	_set_frame(_get_active_frames(), 0)


func _update_jump(delta: float) -> void:
	var frames: Array[Texture2D] = _jump_frames if not _jump_frames.is_empty() else _get_burst_frames()
	_jump_elapsed = minf(_jump_total_duration, _jump_elapsed + delta)
	var progress: float = _jump_elapsed / maxf(0.001, _jump_total_duration)
	var base_position: Vector2 = _jump_start_position.lerp(_jump_end_position, progress)
	global_position = Vector2(base_position.x, base_position.y - sin(progress * PI) * _tuning.jump_arc_height)
	var held_index: int = clampi(floori(progress * float(JUMP_FRAME_SEQUENCE.size())), 0, JUMP_FRAME_SEQUENCE.size() - 1)
	_frame_index = clampi(int(JUMP_FRAME_SEQUENCE[held_index]), 0, frames.size() - 1)
	_set_frame(frames, _frame_index)
	if not _jump_reentry_splash_played and progress >= 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, _surface_waterline_y))
		_jump_reentry_splash_played = true
	if _jump_elapsed >= _jump_total_duration:
		global_position = _jump_end_position
		_jump_total_duration = 0.0
		_show_idle_frame()
		global_position = _clamp_to_world(global_position)


func _clamp_to_world(position_to_clamp: Vector2) -> Vector2:
	var minimum_y: float = _world_bounds.position.y + PLAYER_EDGE_PADDING
	if _jump_total_duration <= 0.0:
		minimum_y = maxf(minimum_y, _swim_ceiling_y)
	return Vector2(
		clampf(position_to_clamp.x, _world_bounds.position.x + PLAYER_EDGE_PADDING, _world_bounds.end.x - PLAYER_EDGE_PADDING),
		clampf(position_to_clamp.y, minimum_y, _world_bounds.end.y - PLAYER_EDGE_PADDING),
	)
