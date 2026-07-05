class_name HylasV2
extends CharacterBody2D

signal normal_conch_used(origin: Vector2, direction: Vector2)
signal surface_splash_requested(origin: Vector2)
signal burst_started(origin: Vector2, direction: Vector2)
signal tail_flip_started(origin: Vector2, direction: Vector2)

@export_category("World")
@export var world_bounds: Rect2 = Rect2(0.0, 0.0, 7680.0, 4320.0)
@export var swim_ceiling_y: float = 2060.0
@export var player_edge_padding: float = 105.0

@export_category("Swimming")
@export var swim_speed: float = 320.0
@export var swim_acceleration: float = 1600.0
@export var idle_momentum_deceleration: float = 300.0
@export var brake_deceleration: float = 2800.0
@export var idle_sink_speed: float = 14.0
@export var current_base_velocity: Vector2 = Vector2(10.0, 0.0)
@export var current_sway_horizontal: float = 7.0
@export var current_sway_vertical: float = 2.0
@export var current_sway_frequency: float = 0.24

@export_category("Burst")
@export var burst_speed: float = 1120.0
@export var burst_duration: float = 0.36
@export var burst_cooldown: float = 0.0
@export_range(1, 5, 1) var burst_max_charges: int = 3
@export var burst_charge_recovery: float = 1.20
@export_range(10.0, 89.0, 1.0) var vertical_burst_angle_degrees: float = 75.0

@export_category("Tail Flip")
@export var tail_flip_speed: float = 860.0
@export var tail_flip_duration: float = 0.46
@export var tail_flip_cooldown: float = 0.30
@export var double_conch_tap_window: float = 0.20

@export_category("Conch")
@export var conch_cooldown: float = 0.80
@export var conch_duration: float = 0.34
@export_range(10.0, 89.0, 1.0) var conch_direction_angle_degrees: float = 45.0

@export_category("Surface Jump")
@export var jump_trigger_depth: float = 300.0
@export var jump_forward_distance: float = 430.0
@export var jump_arc_height: float = 240.0
@export var jump_duration: float = 0.60

@export_category("Presentation")
@export var display_height: float = 205.0
@export var shadow_offset: Vector2 = Vector2(8.0, 17.0)
@export var shadow_scale_multiplier: float = 1.18
@export var camera_shake_strength: float = 10.0
@export var camera_shake_duration: float = 0.13

@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _shadow_sprite: Sprite2D = %ShadowSprite
@onready var _collision_shape: CollisionShape2D = %CollisionShape
@onready var _camera: Camera2D = %Camera2D
@onready var _tail_bubble_burst: VideoStreamPlayer = %TailBubbleBurst
@onready var _tail_bubble_anchor: Marker2D = %TailBubbleAnchor
@onready var _swim_audio: AudioStreamPlayer = %SwimAudio
@onready var _burst_audio: AudioStreamPlayer = %BurstAudio
@onready var _conch_audio: AudioStreamPlayer = %ConchAudio

var _play_enabled: bool = false
var _facing_left: bool = false
var _visual_rotation: float = 0.0
var _current_time: float = 0.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _burst_direction: Vector2 = Vector2.RIGHT
var _burst_remaining: float = 0.0
var _burst_cooldown_remaining: float = 0.0
var _burst_charges: int = 0
var _burst_charge_timer: float = 0.0
var _tail_flip_direction: Vector2 = Vector2.RIGHT
var _tail_flip_remaining: float = 0.0
var _tail_flip_cooldown_remaining: float = 0.0
var _conch_remaining: float = 0.0
var _conch_cooldown_remaining: float = 0.0
var _pending_conch_remaining: float = 0.0
var _pending_conch_direction: Vector2 = Vector2.RIGHT
var _pending_surface_jump: bool = false
var _jump_elapsed: float = 0.0
var _jump_start: Vector2 = Vector2.ZERO
var _jump_end: Vector2 = Vector2.ZERO
var _camera_rest_offset: Vector2 = Vector2.ZERO
var _camera_shake_remaining: float = 0.0


func _ready() -> void:
	_camera_rest_offset = _camera.offset
	_burst_charges = burst_max_charges
	_swim_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_burst_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_conch_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_display_scale()
	_set_animation(&"idle")
	set_physics_process(false)


func configure_world(bounds: Rect2, waterline_y: float, start_position: Vector2) -> void:
	world_bounds = bounds
	swim_ceiling_y = waterline_y
	global_position = _clamp_to_world(start_position)
	_camera.limit_left = floori(bounds.position.x)
	_camera.limit_top = floori(bounds.position.y)
	_camera.limit_right = ceili(bounds.end.x)
	_camera.limit_bottom = ceili(bounds.end.y)


func set_play_enabled(enabled: bool) -> void:
	_play_enabled = enabled
	set_physics_process(enabled)
	if not enabled:
		_movement_velocity = Vector2.ZERO
		_stop_movement_audio()


func reset_to_start(start_position: Vector2) -> void:
	global_position = _clamp_to_world(start_position)
	_movement_velocity = Vector2.ZERO
	_burst_remaining = 0.0
	_tail_flip_remaining = 0.0
	_conch_remaining = 0.0
	_pending_conch_remaining = 0.0
	_pending_surface_jump = false
	_jump_elapsed = 0.0
	_burst_charges = burst_max_charges
	_stop_movement_audio()
	_set_animation(&"idle")


func _physics_process(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()

	if _jump_elapsed > 0.0:
		_update_surface_jump(delta)
		return

	var input_direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if Input.is_action_just_pressed(&"conch"):
		_handle_conch_pressed(input_direction)
	_update_pending_conch(delta)

	if _tail_flip_remaining > 0.0:
		_update_tail_flip(delta)
		_apply_motion(delta, false)
		return
	if _conch_remaining > 0.0:
		_update_conch(delta)
		_apply_motion(delta, true)
		return
	if _burst_remaining > 0.0:
		_update_burst(delta)
		_apply_motion(delta, false)
		if _pending_surface_jump and global_position.y <= swim_ceiling_y:
			_begin_surface_jump()
		return

	if _can_start_burst(input_direction):
		_start_burst(input_direction)
	elif _is_braking(input_direction):
		_update_brake(delta)
	elif input_direction != Vector2.ZERO:
		_update_swim(input_direction, delta)
	else:
		_update_idle(delta)
	_apply_motion(delta, input_direction == Vector2.ZERO)


func _update_cooldowns(delta: float) -> void:
	_burst_cooldown_remaining = maxf(0.0, _burst_cooldown_remaining - delta)
	_tail_flip_cooldown_remaining = maxf(0.0, _tail_flip_cooldown_remaining - delta)
	_conch_cooldown_remaining = maxf(0.0, _conch_cooldown_remaining - delta)
	if _burst_charges < burst_max_charges:
		_burst_charge_timer = maxf(0.0, _burst_charge_timer - delta)
		if _burst_charge_timer <= 0.0:
			_burst_charges += 1
			_burst_charge_timer = burst_charge_recovery if _burst_charges < burst_max_charges else 0.0


func _can_start_burst(input_direction: Vector2) -> bool:
	return _pending_conch_remaining <= 0.0 and Input.is_action_pressed(&"action_a") and input_direction != Vector2.ZERO and _burst_charges > 0 and _burst_cooldown_remaining <= 0.0


func _start_burst(input_direction: Vector2) -> void:
	var vertical_axis: float = _vertical_axis(input_direction)
	if vertical_axis == 0.0 and _is_backward_input(input_direction):
		return
	if vertical_axis != 0.0:
		_burst_direction = _facing_tilted_direction(vertical_axis, vertical_burst_angle_degrees)
	else:
		_facing_left = input_direction.x < 0.0
		_burst_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_burst_remaining = burst_duration
	_burst_cooldown_remaining = burst_cooldown
	_burst_charges -= 1
	_burst_charge_timer = burst_charge_recovery
	_pending_surface_jump = vertical_axis < 0.0 and global_position.y <= swim_ceiling_y + jump_trigger_depth
	_movement_velocity = _burst_direction * burst_speed
	_set_visual_rotation(_direction_rotation(_burst_direction, vertical_burst_angle_degrees))
	_set_animation(&"burst")
	_play_burst_audio()
	_play_tail_bubble_burst()
	_trigger_camera_shake()
	burst_started.emit(global_position, _burst_direction)


func _update_burst(delta: float) -> void:
	_burst_remaining = maxf(0.0, _burst_remaining - delta)
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, brake_deceleration * delta)
	if _burst_remaining <= 0.0:
		_pending_surface_jump = false
		_set_visual_rotation(0.0)
		_stop_burst_audio()
		_set_animation(&"idle")


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _burst_remaining > 0.0 or _tail_flip_remaining > 0.0 or _jump_elapsed > 0.0:
		return
	if _pending_conch_remaining > 0.0 and _tail_flip_cooldown_remaining <= 0.0:
		_pending_conch_remaining = 0.0
		_start_tail_flip()
		return
	if _conch_cooldown_remaining <= 0.0:
		_pending_conch_direction = _conch_direction(input_direction)
		_pending_conch_remaining = double_conch_tap_window


func _update_pending_conch(delta: float) -> void:
	if _pending_conch_remaining <= 0.0:
		return
	_pending_conch_remaining = maxf(0.0, _pending_conch_remaining - delta)
	if _pending_conch_remaining <= 0.0 and _conch_cooldown_remaining <= 0.0:
		_start_conch(_pending_conch_direction)


func _start_tail_flip() -> void:
	_tail_flip_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_tail_flip_remaining = tail_flip_duration
	_tail_flip_cooldown_remaining = tail_flip_cooldown
	_movement_velocity = _tail_flip_direction * tail_flip_speed
	_set_visual_rotation(0.0)
	_set_animation(&"tail_flip")
	_play_burst_audio()
	_play_tail_bubble_burst()
	_trigger_camera_shake()
	tail_flip_started.emit(global_position, _tail_flip_direction)


func _update_tail_flip(delta: float) -> void:
	_tail_flip_remaining = maxf(0.0, _tail_flip_remaining - delta)
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, brake_deceleration * delta)
	if _tail_flip_remaining <= 0.0:
		_stop_burst_audio()
		_set_animation(&"idle")


func _start_conch(direction: Vector2) -> void:
	_conch_remaining = conch_duration
	_conch_cooldown_remaining = conch_cooldown
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, brake_deceleration * 0.08)
	_set_visual_rotation(_direction_rotation(direction, conch_direction_angle_degrees))
	_set_animation(&"conch")
	_stop_movement_audio()
	_play_one_shot_audio(_conch_audio)
	_trigger_camera_shake()
	normal_conch_used.emit(global_position, direction)


func _update_conch(delta: float) -> void:
	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, idle_momentum_deceleration * delta)
	if _conch_remaining <= 0.0:
		_set_visual_rotation(0.0)
		_set_animation(&"idle")


func _update_swim(input_direction: Vector2, delta: float) -> void:
	_movement_velocity = _movement_velocity.move_toward(input_direction * swim_speed, swim_acceleration * delta)
	if absf(input_direction.x) > 0.01:
		_facing_left = input_direction.x < 0.0
	_set_visual_rotation(0.0)
	_set_animation(&"swim")
	_play_swim_audio()


func _update_brake(delta: float) -> void:
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, brake_deceleration * delta)
	_set_visual_rotation(0.0)
	_set_animation(&"stop")
	_stop_movement_audio()


func _update_idle(delta: float) -> void:
	_movement_velocity = _movement_velocity.move_toward(Vector2.ZERO, idle_momentum_deceleration * delta)
	_set_visual_rotation(0.0)
	_set_animation(&"idle")
	_stop_movement_audio()


func _apply_motion(delta: float, idle: bool) -> void:
	var current_velocity: Vector2 = Vector2(
		current_base_velocity.x + sin(_current_time * current_sway_frequency * TAU) * current_sway_horizontal,
		current_base_velocity.y + cos(_current_time * current_sway_frequency * TAU * 0.67) * current_sway_vertical,
	)
	if idle:
		current_velocity.y += idle_sink_speed
	velocity = _movement_velocity + current_velocity
	move_and_slide()
	global_position = _clamp_to_world(global_position)


func _begin_surface_jump() -> void:
	_pending_surface_jump = false
	_burst_remaining = 0.0
	_movement_velocity = Vector2.ZERO
	_jump_elapsed = 0.0001
	_jump_start = Vector2(global_position.x, swim_ceiling_y)
	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end = Vector2(_jump_start.x + facing_sign * jump_forward_distance, swim_ceiling_y + 40.0)
	global_position = _jump_start
	_set_visual_rotation(0.0)
	_set_animation(&"jump")
	_stop_movement_audio()
	surface_splash_requested.emit(_jump_start)


func _update_surface_jump(delta: float) -> void:
	_jump_elapsed += delta
	var progress: float = clampf(_jump_elapsed / maxf(0.01, jump_duration), 0.0, 1.0)
	var base_position: Vector2 = _jump_start.lerp(_jump_end, progress)
	global_position = Vector2(base_position.x, base_position.y - sin(progress * PI) * jump_arc_height)
	if progress >= 0.80 and _jump_elapsed - delta < jump_duration * 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, swim_ceiling_y))
	if progress >= 1.0:
		_jump_elapsed = 0.0
		global_position = _clamp_to_world(_jump_end)
		_set_animation(&"idle")


func _set_animation(animation_name: StringName) -> void:
	if _animated_sprite.animation == animation_name and _animated_sprite.is_playing():
		return
	_animated_sprite.animation = animation_name
	_animated_sprite.play()
	_animated_sprite.flip_h = _facing_left
	_update_shadow()


func _set_visual_rotation(rotation_value: float) -> void:
	_visual_rotation = rotation_value
	_animated_sprite.rotation = rotation_value
	_collision_shape.rotation = rotation_value
	_shadow_sprite.rotation = rotation_value


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_animated_sprite.scale = Vector2.ONE * scale_factor
	_shadow_sprite.scale = Vector2.ONE * scale_factor * shadow_scale_multiplier
	var rectangle: RectangleShape2D = _collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(maxf(70.0, display_height * 0.60), maxf(30.0, display_height * 0.24))


func _update_shadow() -> void:
	var texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(_animated_sprite.animation, _animated_sprite.frame)
	_shadow_sprite.texture = texture
	_shadow_sprite.flip_h = _facing_left
	_shadow_sprite.position = shadow_offset


func _play_tail_bubble_burst() -> void:
	_tail_bubble_burst.global_position = _tail_bubble_anchor.global_position
	_tail_bubble_burst.stop()
	_tail_bubble_burst.show()
	_tail_bubble_burst.play()


func _play_swim_audio() -> void:
	_stop_burst_audio()
	if _swim_audio.stream != null and not _swim_audio.playing:
		_swim_audio.play()


func _play_burst_audio() -> void:
	if _swim_audio.playing:
		_swim_audio.stop()
	if _burst_audio.stream != null and not _burst_audio.playing:
		_burst_audio.play()


func _play_one_shot_audio(player: AudioStreamPlayer) -> void:
	if player.stream == null:
		return
	player.stop()
	player.play()


func _stop_burst_audio() -> void:
	if _burst_audio.playing:
		_burst_audio.stop()


func _stop_movement_audio() -> void:
	if _swim_audio.playing:
		_swim_audio.stop()
	_stop_burst_audio()


func _trigger_camera_shake() -> void:
	_camera_shake_remaining = camera_shake_duration


func _update_camera_shake(delta: float) -> void:
	if _camera_shake_remaining <= 0.0:
		_camera.offset = _camera_rest_offset
		return
	_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
	var ratio: float = _camera_shake_remaining / maxf(0.01, camera_shake_duration)
	var amplitude: float = camera_shake_strength * ratio
	_camera.offset = _camera_rest_offset + Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))


func _is_braking(input_direction: Vector2) -> bool:
	return Input.is_action_pressed(&"action_a") and (input_direction == Vector2.ZERO or _is_backward_input(input_direction))


func _is_backward_input(input_direction: Vector2) -> bool:
	if absf(input_direction.x) < 0.15:
		return false
	var facing_direction: Vector2 = Vector2.LEFT if _facing_left else Vector2.RIGHT
	return input_direction.dot(facing_direction) < -0.15


func _vertical_axis(input_direction: Vector2) -> float:
	if input_direction.y < -0.15:
		return -1.0
	if input_direction.y > 0.15:
		return 1.0
	return 0.0


func _facing_tilted_direction(vertical_axis: float, degrees: float) -> Vector2:
	var facing_axis: float = -1.0 if _facing_left else 1.0
	var radians: float = deg_to_rad(degrees)
	return Vector2(facing_axis * cos(radians), vertical_axis * sin(radians)).normalized()


func _conch_direction(input_direction: Vector2) -> Vector2:
	var vertical_axis: float = _vertical_axis(input_direction)
	if vertical_axis == 0.0:
		return Vector2.LEFT if _facing_left else Vector2.RIGHT
	return _facing_tilted_direction(vertical_axis, conch_direction_angle_degrees)


func _direction_rotation(direction: Vector2, degrees: float) -> float:
	if absf(direction.y) < 0.01:
		return 0.0
	var vertical_axis: float = -1.0 if direction.y < 0.0 else 1.0
	var facing_axis: float = -1.0 if _facing_left else 1.0
	return vertical_axis * facing_axis * deg_to_rad(degrees)


func _clamp_to_world(position_value: Vector2) -> Vector2:
	var minimum_y: float = world_bounds.position.y + player_edge_padding
	if _jump_elapsed <= 0.0:
		minimum_y = maxf(minimum_y, swim_ceiling_y)
	return Vector2(
		clampf(position_value.x, world_bounds.position.x + player_edge_padding, world_bounds.end.x - player_edge_padding),
		clampf(position_value.y, minimum_y, world_bounds.end.y - player_edge_padding),
	)
