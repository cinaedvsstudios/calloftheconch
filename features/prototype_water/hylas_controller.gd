class_name HylasController
extends CharacterBody2D
## Movement-feel controller for Prototype 0.1.
## Player momentum and current stay separate, so braking never cancels the sea itself.

signal normal_conch_used(origin: Vector2, facing_left: bool)
signal surface_splash_requested(origin: Vector2)

const PLAYER_EDGE_PADDING: float = 105.0
const BURST_PREPARATION_FRAME_COUNT: int = 2
const SHADOW_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.01, 0.06, 0.11, 0.07);
uniform float blur_radius = 60.0;

void fragment() {
	vec2 blur_step = TEXTURE_PIXEL_SIZE * blur_radius;
	float alpha_sum = 0.0;
	alpha_sum += texture(TEXTURE, UV + vec2(-2.0, 0.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(2.0, 0.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(0.0, -2.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(0.0, 2.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(-1.0, -1.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(1.0, -1.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(-1.0, 1.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(1.0, 1.0) * blur_step).a;
	alpha_sum += texture(TEXTURE, UV + vec2(-1.0, 0.0) * blur_step).a * 0.75;
	alpha_sum += texture(TEXTURE, UV + vec2(1.0, 0.0) * blur_step).a * 0.75;
	alpha_sum += texture(TEXTURE, UV + vec2(0.0, -1.0) * blur_step).a * 0.75;
	alpha_sum += texture(TEXTURE, UV + vec2(0.0, 1.0) * blur_step).a * 0.75;
	float blurred_alpha = alpha_sum / 11.0;
	COLOR = vec4(shadow_tint.rgb, blurred_alpha * shadow_tint.a);
}
"""

@export var start_position: Vector2 = Vector2(640.0, 360.0)

@onready var _sprite: Sprite2D = %Sprite
@onready var _shadow: Sprite2D = %HylasShadow
@onready var _collision_shape: CollisionShape2D = %HylasCollision
@onready var _camera: Camera2D = %Camera2D
@onready var _tail_bubble_burst: TailBubbleBurst = %TailBubbleBurst

var _tuning: PrototypeTuning = PrototypeTuning.new()
var _swim_frames: Array[Texture2D] = []
var _speed_frames: Array[Texture2D] = []
var _conch_frames: Array[Texture2D] = []
var _jump_frames: Array[Texture2D] = []
var _player_velocity: Vector2 = Vector2.ZERO
var _world_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
var _swim_ceiling_y: float = 105.0
var _surface_waterline_y: float = 105.0
var _frame_time: float = 0.0
var _frame_index: int = 0
var _current_time: float = 0.0
var _burst_elapsed: float = 0.0
var _burst_total_duration: float = 0.0
var _burst_cooldown_remaining: float = 0.0
var _burst_charge_recovery_remaining: float = 0.0
var _burst_charges: int = 0
var _burst_direction: Vector2 = Vector2.RIGHT
var _burst_tail_has_played: bool = false
var _conch_cooldown_remaining: float = 0.0
var _tail_burst_remaining: float = 0.0
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


func _ready() -> void:
	_random.randomize()
	_swim_frames = PrototypeAssets.load_hylas_frames("hylas-swim")
	_speed_frames = PrototypeAssets.load_hylas_frames("hylas-speed")
	_conch_frames = PrototypeAssets.load_hylas_frames("hylas-conch1")
	_jump_frames = PrototypeAssets.load_hylas_frames("hylas-jump")
	_shadow_material = _create_shadow_material()
	_shadow.material = _shadow_material
	_burst_charges = _get_max_burst_charges()
	global_position = start_position
	refresh_tuning()
	_show_idle_frame()
	_reset_tail_burst_timer()
	set_physics_process(false)


func bind_tuning(tuning: PrototypeTuning) -> void:
	_tuning = tuning
	_burst_charges = mini(_burst_charges, _get_max_burst_charges())
	if _burst_charges <= 0 and _burst_elapsed <= 0.0:
		_burst_charges = _get_max_burst_charges()
	refresh_tuning()


func refresh_tuning() -> void:
	_camera.position_smoothing_speed = _tuning.camera_smoothing_speed
	_tail_bubble_burst.configure(_tuning)
	_apply_collision_shape()
	_apply_shadow_style()
	var active_frames: Array[Texture2D] = _get_active_frames()
	if not active_frames.is_empty():
		_set_frame(active_frames, _frame_index)


func configure_world(world_size: Vector2, desired_start_position: Vector2, swim_ceiling_y: float) -> void:
	var safe_width: float = maxf(world_size.x, 1280.0)
	var safe_height: float = maxf(world_size.y, 720.0)
	_world_bounds = Rect2(Vector2.ZERO, Vector2(safe_width, safe_height))
	_surface_waterline_y = swim_ceiling_y
	_swim_ceiling_y = swim_ceiling_y
	start_position = desired_start_position
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = ceili(safe_width)
	_camera.limit_bottom = ceili(safe_height)
	global_position = _clamp_to_world(global_position)


func set_play_enabled(enabled: bool) -> void:
	_play_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		_player_velocity = Vector2.ZERO
		_burst_elapsed = 0.0
		_burst_total_duration = 0.0
		_jump_elapsed = 0.0
		_jump_total_duration = 0.0
		_pending_surface_jump = false
		_set_visual_rotation(0.0)
		_tail_bubble_burst.hide()


func reset_to_start() -> void:
	global_position = _clamp_to_world(start_position)
	_player_velocity = Vector2.ZERO
	_frame_index = 0
	_frame_time = 0.0
	_burst_elapsed = 0.0
	_burst_total_duration = 0.0
	_burst_cooldown_remaining = 0.0
	_burst_charge_recovery_remaining = 0.0
	_burst_charges = _get_max_burst_charges()
	_conch_cooldown_remaining = 0.0
	_is_using_conch = false
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_jump_total_duration = 0.0
	_jump_reentry_splash_played = false
	_animation_mode = &"idle"
	_set_visual_rotation(0.0)
	_reset_tail_burst_timer()
	_tail_bubble_burst.hide()
	_show_idle_frame()


func get_diagnostic_summary() -> String:
	var current_velocity: Vector2 = _get_current_velocity()
	return "Hylas: (%.0f, %.0f) | Own velocity: (%.0f, %.0f) | Current: (%.0f, %.0f) | Burst charges: %d/%d | Burst launch: %.0f | Jump: %s" % [
		global_position.x,
		global_position.y,
		_player_velocity.x,
		_player_velocity.y,
		current_velocity.x,
		current_velocity.y,
		_burst_charges,
		_get_max_burst_charges(),
		_tuning.burst_speed,
		"yes" if _jump_total_duration > 0.0 else "no",
	]


func _physics_process(delta: float) -> void:
	if not _play_enabled:
		return

	_current_time += delta
	_burst_cooldown_remaining = maxf(0.0, _burst_cooldown_remaining - delta)
	_conch_cooldown_remaining = maxf(0.0, _conch_cooldown_remaining - delta)
	_update_burst_charge_recovery(delta)

	if _jump_total_duration > 0.0:
		_update_jump(delta)
		return

	if _is_using_conch:
		_update_conch(delta)
		_apply_current_and_position(delta, true)
		return

	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
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

	if Input.is_action_just_pressed(&"conch") and _conch_cooldown_remaining <= 0.0 and not _conch_frames.is_empty():
		_begin_conch()
		return

	_apply_current_and_position(delta, input_direction == Vector2.ZERO)
	if _pending_surface_jump and _burst_total_duration > 0.0 and global_position.y <= _surface_waterline_y + 0.1:
		_begin_surface_jump()


func _should_begin_action_a_burst(input_direction: Vector2) -> bool:
	if _burst_total_duration > 0.0 or _burst_cooldown_remaining > 0.0:
		return false
	if _burst_charges <= 0:
		return false
	if not Input.is_action_pressed(&"action_a") or input_direction == Vector2.ZERO:
		return false
	return Input.is_action_just_pressed(&"action_a") or _is_movement_action_just_pressed()


func _try_begin_action_a(input_direction: Vector2) -> void:
	var vertical_burst_axis: float = _get_vertical_burst_axis(input_direction)
	if vertical_burst_axis == 0.0 and _is_backward_input(input_direction):
		return

	_pending_surface_jump = false
	if vertical_burst_axis != 0.0:
		_burst_direction = _get_facing_vertical_burst_direction(vertical_burst_axis)
		if vertical_burst_axis < 0.0 and _can_attempt_surface_jump():
			_pending_surface_jump = true
	else:
		if absf(input_direction.x) < 0.01:
			return
		_facing_left = input_direction.x < 0.0
		_burst_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT

	_burst_charges -= 1
	if _burst_charge_recovery_remaining <= 0.0:
		_burst_charge_recovery_remaining = _tuning.burst_charge_recovery
	_burst_total_duration = _get_burst_total_duration()
	_burst_elapsed = 0.0
	_burst_cooldown_remaining = _tuning.burst_cooldown
	_burst_tail_has_played = false
	_animation_mode = &"speed"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(_get_burst_sprite_rotation())
	_set_frame(_get_burst_frames(), _frame_index)


func _update_burst(delta: float) -> void:
	var burst_frames: Array[Texture2D] = _get_burst_frames()
	_burst_elapsed = minf(_burst_total_duration, _burst_elapsed + delta)
	var frame_index: int = _get_burst_frame_index(burst_frames.size())
	_frame_index = frame_index
	_set_visual_rotation(_get_burst_sprite_rotation())
	_set_frame(burst_frames, frame_index)

	if _is_burst_launch_frame(frame_index, burst_frames.size()):
		_player_velocity = _burst_direction * _tuning.burst_speed
		if not _burst_tail_has_played:
			_tail_bubble_burst.play_at_tail(_facing_left, _visual_rotation)
			_burst_tail_has_played = true
	else:
		_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * delta)

	_update_tail_burst(delta, true)
	if _burst_elapsed >= _burst_total_duration:
		_burst_total_duration = 0.0
		_burst_elapsed = 0.0
		_pending_surface_jump = false
		_set_visual_rotation(0.0)


func _update_burst_charge_recovery(delta: float) -> void:
	if _burst_charges >= _get_max_burst_charges():
		_burst_charge_recovery_remaining = 0.0
		return
	_burst_charge_recovery_remaining = maxf(0.0, _burst_charge_recovery_remaining - delta)
	if _burst_charge_recovery_remaining > 0.0:
		return
	_burst_charges += 1
	if _burst_charges < _get_max_burst_charges():
		_burst_charge_recovery_remaining = _tuning.burst_charge_recovery


func _update_brake(delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * delta)
	_show_idle_frame()


func _update_swim(input_direction: Vector2, delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(input_direction * _tuning.swim_speed, _tuning.swim_acceleration * delta)
	if absf(input_direction.x) > 0.01:
		_facing_left = input_direction.x < 0.0
	_set_visual_rotation(0.0)
	_update_animation(_swim_frames, _tuning.swim_frame_duration, &"swim", delta)
	_update_tail_burst(delta, true)


func _update_idle(delta: float) -> void:
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.idle_momentum_deceleration * delta)
	_show_idle_frame()


func _begin_conch() -> void:
	_is_using_conch = true
	_conch_cooldown_remaining = _tuning.normal_conch_cooldown
	_player_velocity = _player_velocity.move_toward(Vector2.ZERO, _tuning.brake_deceleration * 0.08)
	_animation_mode = &"conch"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	_set_frame(_conch_frames, _frame_index)
	normal_conch_used.emit(global_position, _facing_left)


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


func _apply_current_and_position(delta: float, is_idle: bool) -> void:
	var water_velocity: Vector2 = _get_current_velocity()
	if is_idle:
		water_velocity.y += _tuning.idle_sink_speed
	var requested_motion: Vector2 = (_player_velocity + water_velocity) * delta
	move_and_collide(requested_motion)
	global_position = _clamp_to_world(global_position)


func _get_current_velocity() -> Vector2:
	var horizontal_sway: float = sin(_current_time * _tuning.current_sway_frequency * TAU) * _tuning.current_sway_horizontal
	var vertical_sway: float = cos(_current_time * _tuning.current_sway_frequency * TAU * 0.67) * _tuning.current_sway_vertical
	return Vector2(_tuning.current_base_x + horizontal_sway, _tuning.current_base_y + vertical_sway)


func _is_braking(input_direction: Vector2) -> bool:
	return Input.is_action_pressed(&"action_a") and (input_direction == Vector2.ZERO or _is_backward_input(input_direction))


func _is_backward_input(input_direction: Vector2) -> bool:
	if absf(input_direction.x) < 0.15:
		return false
	var facing_direction: Vector2 = Vector2.LEFT if _facing_left else Vector2.RIGHT
	return input_direction.dot(facing_direction) < -0.15


func _is_movement_action_just_pressed() -> bool:
	return (
		Input.is_action_just_pressed(&"move_left")
		or Input.is_action_just_pressed(&"move_right")
		or Input.is_action_just_pressed(&"move_up")
		or Input.is_action_just_pressed(&"move_down")
	)


func _get_vertical_burst_axis(input_direction: Vector2) -> float:
	if input_direction.y < -0.15:
		return -1.0
	if input_direction.y > 0.15:
		return 1.0
	return 0.0


func _get_facing_vertical_burst_direction(vertical_axis: float) -> Vector2:
	var angle_radians: float = deg_to_rad(_tuning.vertical_burst_angle_degrees)
	var facing_axis: float = -1.0 if _facing_left else 1.0
	return Vector2(facing_axis * cos(angle_radians), vertical_axis * sin(angle_radians)).normalized()


func _get_burst_sprite_rotation() -> float:
	if absf(_burst_direction.y) < 0.01:
		return 0.0
	var vertical_axis: float = -1.0 if _burst_direction.y < 0.0 else 1.0
	var facing_axis: float = -1.0 if _facing_left else 1.0
	return vertical_axis * facing_axis * deg_to_rad(_tuning.vertical_burst_angle_degrees)


func _get_burst_frames() -> Array[Texture2D]:
	return _speed_frames if not _speed_frames.is_empty() else _swim_frames


func _get_burst_total_duration() -> float:
	var frame_duration: float = maxf(0.02, _tuning.speed_frame_duration)
	var animation_duration: float = float(maxi(1, _get_burst_frames().size())) * frame_duration
	return maxf(_tuning.burst_duration, animation_duration)


func _get_burst_frame_index(frame_count: int) -> int:
	if frame_count <= 1:
		return 0
	var frame_duration: float = maxf(0.02, _tuning.speed_frame_duration)
	return clampi(floori(_burst_elapsed / frame_duration), 0, frame_count - 1)


func _is_burst_launch_frame(frame_index: int, frame_count: int) -> bool:
	var preparation_frame_count: int = mini(BURST_PREPARATION_FRAME_COUNT, maxi(0, frame_count - 1))
	return frame_index >= preparation_frame_count


func _get_max_burst_charges() -> int:
	return maxi(1, roundi(_tuning.burst_max_charges))


func _update_tail_burst(delta: float, is_swimming: bool) -> void:
	if not is_swimming:
		return
	_tail_burst_remaining -= delta
	if _tail_burst_remaining > 0.0:
		return
	_tail_bubble_burst.play_at_tail(_facing_left, _visual_rotation)
	_reset_tail_burst_timer()


func _reset_tail_burst_timer() -> void:
	_tail_burst_remaining = _random.randf_range(_tuning.tail_burst_interval_min, _tuning.tail_burst_interval_max)


func _update_animation(frames: Array[Texture2D], frame_duration: float, mode: StringName, delta: float) -> void:
	if frames.is_empty():
		return
	if _animation_mode != mode:
		_animation_mode = mode
		_frame_index = 0
		_frame_time = 0.0
		_set_frame(frames, _frame_index)

	_frame_time += delta
	if _frame_time < frame_duration:
		return
	_frame_time = 0.0
	_frame_index = (_frame_index + 1) % frames.size()
	_set_frame(frames, _frame_index)


func _show_idle_frame() -> void:
	_animation_mode = &"idle"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	_set_frame(_swim_frames, _frame_index)


func _get_active_frames() -> Array[Texture2D]:
	match _animation_mode:
		&"conch":
			return _conch_frames
		&"speed":
			return _get_burst_frames()
		&"jump":
			return _jump_frames if not _jump_frames.is_empty() else _get_burst_frames()
		_:
			return _swim_frames


func _set_frame(frames: Array[Texture2D], index: int) -> void:
	if frames.is_empty():
		return
	var safe_index: int = clampi(index, 0, frames.size() - 1)
	var texture: Texture2D = frames[safe_index]
	var texture_height: float = maxf(1.0, float(texture.get_height()))
	var display_scale: float = _tuning.hylas_display_height / texture_height

	_sprite.texture = texture
	_sprite.flip_h = _facing_left
	_sprite.rotation = _visual_rotation
	_sprite.scale = Vector2(display_scale, display_scale)

	_shadow.texture = texture
	_shadow.flip_h = _facing_left
	_shadow.rotation = _visual_rotation
	_shadow.scale = Vector2(display_scale * _tuning.hylas_shadow_scale, display_scale * _tuning.hylas_shadow_scale)
	_apply_shadow_style()


func _set_visual_rotation(rotation_radians: float) -> void:
	_visual_rotation = rotation_radians
	_sprite.rotation = _visual_rotation
	_shadow.rotation = _visual_rotation
	_collision_shape.rotation = _visual_rotation


func _apply_collision_shape() -> void:
	var rectangle_shape: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return
	rectangle_shape.size = Vector2(
		maxf(70.0, _tuning.hylas_display_height * 0.60),
		maxf(30.0, _tuning.hylas_display_height * 0.24),
	)


func _apply_shadow_style() -> void:
	_shadow.position = Vector2(_tuning.hylas_shadow_offset_x, _tuning.hylas_shadow_offset_y)
	_shadow.modulate = Color.WHITE
	_shadow.visible = _tuning.hylas_shadow_opacity > 0.0
	if _shadow_material == null:
		return
	_shadow_material.set_shader_parameter(&"shadow_tint", Color(0.01, 0.06, 0.11, _tuning.hylas_shadow_opacity))
	_shadow_material.set_shader_parameter(&"blur_radius", _tuning.hylas_shadow_blur_radius)


func _create_shadow_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SHADOW_SHADER_CODE
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	return shader_material


func _clamp_to_world(position_to_clamp: Vector2) -> Vector2:
	var minimum_x: float = _world_bounds.position.x + PLAYER_EDGE_PADDING
	var maximum_x: float = _world_bounds.end.x - PLAYER_EDGE_PADDING
	var minimum_y: float = _world_bounds.position.y + PLAYER_EDGE_PADDING
	if _jump_total_duration <= 0.0:
		minimum_y = maxf(minimum_y, _swim_ceiling_y)
	var maximum_y: float = _world_bounds.end.y - PLAYER_EDGE_PADDING
	return Vector2(
		clampf(position_to_clamp.x, minimum_x, maximum_x),
		clampf(position_to_clamp.y, minimum_y, maximum_y),
	)


func _can_attempt_surface_jump() -> bool:
	return global_position.y <= (_surface_waterline_y + _tuning.jump_trigger_depth)


func _begin_surface_jump() -> void:
	_pending_surface_jump = false
	_burst_total_duration = 0.0
	_burst_elapsed = 0.0
	_is_using_conch = false
	_player_velocity = Vector2.ZERO
	_jump_elapsed = 0.0
	_jump_total_duration = maxf(0.20, _tuning.jump_frame_duration * float(maxi(1, _jump_frames.size())))
	_jump_start_position = Vector2(global_position.x, _surface_waterline_y)
	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end_position = Vector2(
		_jump_start_position.x + (facing_sign * _tuning.jump_forward_distance),
		_surface_waterline_y + 40.0,
	)
	_jump_reentry_splash_played = false
	_animation_mode = &"jump"
	_frame_index = 0
	_frame_time = 0.0
	_set_visual_rotation(0.0)
	global_position = _jump_start_position
	surface_splash_requested.emit(_jump_start_position)
	_set_frame(_get_active_frames(), _frame_index)


func _update_jump(delta: float) -> void:
	var frames: Array[Texture2D] = _jump_frames if not _jump_frames.is_empty() else _get_burst_frames()
	_jump_elapsed = minf(_jump_total_duration, _jump_elapsed + delta)
	var safe_duration: float = maxf(0.001, _jump_total_duration)
	var t: float = clampf(_jump_elapsed / safe_duration, 0.0, 1.0)
	var base_position: Vector2 = _jump_start_position.lerp(_jump_end_position, t)
	var arc_offset: float = sin(t * PI) * _tuning.jump_arc_height
	global_position = Vector2(base_position.x, base_position.y - arc_offset)
	var frame_index: int = 0
	if frames.size() > 1:
		frame_index = clampi(floori(t * float(frames.size())), 0, frames.size() - 1)
	_frame_index = frame_index
	_set_frame(frames, frame_index)

	if not _jump_reentry_splash_played and t >= 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, _surface_waterline_y))
		_jump_reentry_splash_played = true

	if _jump_elapsed >= _jump_total_duration:
		global_position = Vector2(_jump_end_position.x, _jump_end_position.y)
		_jump_elapsed = 0.0
		_jump_total_duration = 0.0
		_show_idle_frame()
		global_position = _clamp_to_world(global_position)
