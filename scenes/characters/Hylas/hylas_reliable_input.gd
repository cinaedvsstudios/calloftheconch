extends "res://scenes/characters/Hylas/hylas_land_controller.gd"

## Owns the timing-sensitive Space input rules. A single Space press uses the
## nearby interaction, while a second press inside the short window ignores the
## interaction and fires the conch. Shift+Space remains reserved for Tail Flip.
## This top-level Hylas controller also owns the animation-driven death state so
## normal swimming code cannot interfere while the body drifts to the seabed.

const DEATH_INTRO_ANIMATION: StringName = &"death_intro"
const DEATH_DRIFT_ANIMATION: StringName = &"death_drift"
const DIE_01: Texture2D = preload("res://assets/characters/die01.webp")
const DIE_02: Texture2D = preload("res://assets/characters/die02.webp")
const DIE_03: Texture2D = preload("res://assets/characters/die03.webp")
const DIE_04: Texture2D = preload("res://assets/characters/die04.webp")
const DIE_05: Texture2D = preload("res://assets/characters/die05.webp")
const DIE_06: Texture2D = preload("res://assets/characters/die06.webp")
const DIE_07: Texture2D = preload("res://assets/characters/die07.webp")
const DIE_08: Texture2D = preload("res://assets/characters/die08.webp")

signal interaction_requested
signal interaction_availability_changed(is_available: bool)
signal death_drift_started
signal death_landed

@export_range(0.0, 200.0, 1.0) var brake_minimum_speed: float = 5.0
@export_range(0.05, 0.5, 0.01) var interaction_double_tap_window: float = 0.20

@export_category("Death Sequence")
@export_range(1.0, 30.0, 0.5) var death_intro_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var death_drift_fps: float = 3.0
@export_range(1.0, 500.0, 1.0) var death_drift_speed: float = 85.0
@export_range(-400.0, 0.0, 1.0) var death_camera_vertical_offset: float = -130.0
@export_range(0.05, 5.0, 0.05) var death_camera_recenter_seconds: float = 1.20

var _shift_space_tail_flip_requested: bool = false
var _tail_flip_chord_active: bool = false
var _space_action_pressed_this_frame: bool = false
var _interaction_available: bool = false
var _pending_interaction_remaining: float = 0.0
var _death_sequence_active: bool = false
var _death_drift_active: bool = false
var _death_body_landed: bool = false
var _normal_camera_rest_offset: Vector2 = Vector2.ZERO
var _death_camera_start_offset: Vector2 = Vector2.ZERO
var _death_camera_elapsed: float = 0.0


func _ready() -> void:
	super._ready()
	_normal_camera_rest_offset = _camera_rest_offset
	_configure_death_animations()
	if not _animated_sprite.animation_finished.is_connected(_on_animation_finished):
		_animated_sprite.animation_finished.connect(_on_animation_finished)


func _input(event: InputEvent) -> void:
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var is_space: bool = (
		key_event.keycode == KEY_SPACE
		or key_event.physical_keycode == KEY_SPACE
		or key_event.unicode == 32
	)
	if not is_space:
		return

	var shift_is_held: bool = (
		key_event.shift_pressed
		or Input.is_action_pressed(&"action_a")
		or Input.is_key_pressed(KEY_SHIFT)
	)
	if shift_is_held:
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	_space_action_pressed_this_frame = true


func _physics_process(delta: float) -> void:
	if _death_sequence_active:
		_update_death_sequence(delta)
		return

	_tail_flip_chord_active = _shift_space_tail_flip_requested
	_shift_space_tail_flip_requested = false

	if _tail_flip_chord_active:
		_brake_active = false
		_pending_conch_remaining = 0.0
		_pending_interaction_remaining = 0.0
		if (
			not _burst_active
			and _tail_flip_remaining <= 0.0
			and _conch_remaining <= 0.0
			and _jump_elapsed <= 0.0
			and _tail_flip_cooldown_remaining <= 0.0
		):
			_start_tail_flip()

	super._physics_process(delta)
	_update_pending_interaction(delta)
	_space_action_pressed_this_frame = false
	_tail_flip_chord_active = false


func reset_to_start(start_position: Vector2) -> void:
	_clear_death_state(false)
	super.reset_to_start(start_position)


func start_death_sequence() -> void:
	if _death_sequence_active:
		return
	_death_sequence_active = true
	_death_drift_active = false
	_death_body_landed = false
	_death_camera_elapsed = 0.0
	_death_camera_start_offset = _camera_rest_offset
	_play_enabled = false
	crawl_active = false
	airborne_active = false
	left_water = false
	entry_splash_done = false
	_pending_interaction_remaining = 0.0
	_space_action_pressed_this_frame = false
	_shift_space_tail_flip_requested = false
	_tail_flip_chord_active = false
	_reset_motion_state()
	velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	_stop_movement_audio()
	_set_animation(DEATH_INTRO_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.play()
	set_physics_process(true)


func cancel_death_sequence() -> void:
	_clear_death_state(true)


func is_death_sequence_active() -> bool:
	return _death_sequence_active


func has_death_body_landed() -> bool:
	return _death_body_landed


func set_interaction_available(is_available: bool) -> void:
	if _interaction_available == is_available:
		return
	_interaction_available = is_available
	if not _interaction_available:
		_pending_interaction_remaining = 0.0
	interaction_availability_changed.emit(_interaction_available)


func is_interaction_available() -> bool:
	return _interaction_available


func cancel_pending_interaction() -> void:
	_pending_interaction_remaining = 0.0


func _is_braking(input_direction: Vector2) -> bool:
	if _tail_flip_chord_active or _tail_flip_remaining > 0.0:
		return false
	if not _has_brakeable_motion():
		return false
	return super._is_braking(input_direction)


func _has_brakeable_motion() -> bool:
	if _burst_active:
		return true
	var controlled_motion: Vector2 = _swim_velocity + _burst_coast_velocity + _special_velocity
	return controlled_motion.length() >= brake_minimum_speed


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active:
		return

	# J and other direct conch bindings bypass interaction routing. Only the raw
	# Space press recorded in _input() participates in this single/double rule.
	if not _space_action_pressed_this_frame or not _interaction_available:
		super._handle_conch_pressed(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		super._handle_conch_pressed(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window


func _update_pending_interaction(delta: float) -> void:
	if _pending_interaction_remaining <= 0.0:
		return
	_pending_interaction_remaining = maxf(0.0, _pending_interaction_remaining - delta)
	if _pending_interaction_remaining <= 0.0 and _interaction_available:
		interaction_requested.emit()


func _configure_death_animations() -> void:
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames
	if sprite_frames.has_animation(DEATH_INTRO_ANIMATION):
		sprite_frames.remove_animation(DEATH_INTRO_ANIMATION)
	if sprite_frames.has_animation(DEATH_DRIFT_ANIMATION):
		sprite_frames.remove_animation(DEATH_DRIFT_ANIMATION)

	sprite_frames.add_animation(DEATH_INTRO_ANIMATION)
	for texture: Texture2D in [DIE_01, DIE_02, DIE_03, DIE_04, DIE_05, DIE_06]:
		sprite_frames.add_frame(DEATH_INTRO_ANIMATION, texture)
	sprite_frames.set_animation_speed(DEATH_INTRO_ANIMATION, death_intro_fps)
	sprite_frames.set_animation_loop(DEATH_INTRO_ANIMATION, false)

	sprite_frames.add_animation(DEATH_DRIFT_ANIMATION)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_07)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_08)
	sprite_frames.set_animation_speed(DEATH_DRIFT_ANIMATION, death_drift_fps)
	sprite_frames.set_animation_loop(DEATH_DRIFT_ANIMATION, true)


func _update_death_sequence(delta: float) -> void:
	_current_time += delta
	_update_death_camera(delta)
	_update_camera_shake(delta)
	_update_shadow()
	if not _death_drift_active or _death_body_landed:
		velocity = Vector2.ZERO
		return

	velocity = Vector2.DOWN * death_drift_speed
	move_and_slide()
	global_position = _clamp_to_world(global_position)
	if _has_death_floor_collision() or global_position.y >= _world_bounds.end.y - player_edge_padding:
		_death_body_landed = true
		velocity = Vector2.ZERO
		death_landed.emit()


func _update_death_camera(delta: float) -> void:
	_death_camera_elapsed = minf(
		death_camera_recenter_seconds,
		_death_camera_elapsed + delta,
	)
	var progress: float = clampf(
		_death_camera_elapsed / maxf(0.05, death_camera_recenter_seconds),
		0.0,
		1.0,
	)
	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var target_offset: Vector2 = _normal_camera_rest_offset + Vector2(
		0.0,
		death_camera_vertical_offset,
	)
	_camera_rest_offset = _death_camera_start_offset.lerp(target_offset, eased_progress)


func _has_death_floor_collision() -> bool:
	for collision_index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision != null and collision.get_normal().y < -0.2:
			return true
	return false


func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_set_animation(DEATH_DRIFT_ANIMATION)
	death_drift_started.emit()


func _clear_death_state(reset_visual: bool) -> void:
	_death_sequence_active = false
	_death_drift_active = false
	_death_body_landed = false
	_death_camera_elapsed = 0.0
	velocity = Vector2.ZERO
	_camera_rest_offset = _normal_camera_rest_offset
	if is_instance_valid(_camera):
		_camera.offset = _normal_camera_rest_offset
	if reset_visual and is_instance_valid(_animated_sprite):
		_set_visual_rotation(0.0)
		_set_animation(&"idle")
	set_physics_process(_play_enabled)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("tail_flip_remaining=%.2f" % _tail_flip_remaining)
	lines.append("tail_flip_chord_active=%s" % str(_tail_flip_chord_active))
	lines.append("brakeable_motion=%s" % str(_has_brakeable_motion()))
	lines.append("interaction_available=%s" % str(_interaction_available))
	lines.append("pending_interaction=%.2f" % _pending_interaction_remaining)
	lines.append("death_sequence_active=%s" % str(_death_sequence_active))
	lines.append("death_drift_active=%s" % str(_death_drift_active))
	lines.append("death_body_landed=%s" % str(_death_body_landed))
	lines.append("death_camera_offset=%s" % str(_camera_rest_offset))
	return lines
