class_name CotcPufferFish
extends CharacterBody2D

## Passive puffer fish that patrols around its placed position. A Tail Flip bash
## triggers a quick inflation sequence, a thirty-second puffed hold, then the
## same frames in reverse before normal swimming resumes.

enum PufferState {
	NORMAL,
	INFLATING,
	PUFFED,
	DEFLATING,
}

@export_category("Presentation")
@export_range(20.0, 240.0, 1.0) var display_height: float = 95.0
@export_range(1.0, 30.0, 0.5) var transition_fps: float = 12.0
@export var source_faces_left: bool = false

@export_category("Puff Behaviour")
@export_range(1.0, 120.0, 0.5) var puffed_duration: float = 30.0
@export_range(0.0, 600.0, 1.0) var tail_kick_impulse_speed: float = 150.0
@export_range(1.0, 1200.0, 1.0) var tail_kick_impulse_decay: float = 240.0
@export_range(0.0, 100.0, 1.0) var puffed_bob_speed: float = 12.0
@export_range(0.01, 3.0, 0.01) var puffed_bob_frequency: float = 0.42

@export_category("Collision Profiles")
@export var normal_collision_shape: Shape2D
@export var puffed_collision_shape: Shape2D
@export var use_puffed_collision_during_transition: bool = true

@export_category("Patrol")
@export var patrol_half_extents: Vector2 = Vector2(620.0, 190.0)
@export_range(1.0, 400.0, 1.0) var minimum_swim_speed: float = 38.0
@export_range(1.0, 400.0, 1.0) var maximum_swim_speed: float = 62.0
@export_range(1.0, 1000.0, 1.0) var steering_acceleration: float = 95.0
@export_range(10.0, 250.0, 1.0) var waypoint_reached_distance: float = 55.0
@export_range(0.0, 1.0, 0.01) var vertical_wander_strength: float = 0.22
@export_range(0.01, 3.0, 0.01) var vertical_wander_frequency: float = 0.20
@export var random_seed: int = 0

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.32

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _collision_shape: CollisionShape2D = %CollisionShape

var _state: PufferState = PufferState.NORMAL
var _home_position: Vector2
var _patrol_target: Vector2
var _swim_velocity: Vector2 = Vector2.ZERO
var _kick_impulse: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _puffed_remaining: float = 0.0
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _travel_sign: float = 1.0
var _cruise_speed: float = 48.0
var _distance_active: bool = true
var _collision_profile: StringName = &"normal"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home_position = global_position
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_wander_phase = _rng.randf_range(0.0, TAU)
	_travel_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_configure_collision_profiles()
	_configure_animation_speeds()
	_apply_display_scale()
	_apply_collision_profile(&"normal")
	_choose_next_patrol_target(true)
	if not _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"normal")
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_update_puff_timer(delta)
	if _state == PufferState.NORMAL:
		_update_normal_swim(delta)
	else:
		_swim_velocity = _swim_velocity.move_toward(Vector2.ZERO, steering_acceleration * delta)

	_kick_impulse = _kick_impulse.move_toward(
		Vector2.ZERO,
		tail_kick_impulse_decay * delta,
	)
	var total_velocity: Vector2 = (
		_swim_velocity
		+ _get_external_current_velocity() * current_influence
		+ _kick_impulse
	)
	if _state == PufferState.PUFFED:
		total_velocity.y += sin(_elapsed * TAU * puffed_bob_frequency) * puffed_bob_speed

	velocity = total_velocity
	move_and_slide()
	_handle_collisions()
	_clamp_to_patrol_area()
	_update_facing(total_velocity)


func receive_tail_flip_bash(
		_contact_position: Vector2,
		normal: Vector2,
		source: Node,
	) -> void:
	var away_direction: Vector2 = Vector2.ZERO
	var source_2d: Node2D = source as Node2D
	if is_instance_valid(source_2d):
		away_direction = global_position - source_2d.global_position
	if away_direction.length_squared() <= 0.001:
		away_direction = -normal
	if away_direction.length_squared() <= 0.001:
		away_direction = Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT
	_kick_impulse = away_direction.normalized() * tail_kick_impulse_speed

	match _state:
		PufferState.PUFFED:
			_puffed_remaining = puffed_duration
		PufferState.INFLATING:
			pass
		_:
			_begin_inflating()


func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if is_instance_valid(source):
		_external_currents[source] = current_velocity


func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	if is_instance_valid(_collision_shape):
		_collision_shape.disabled = not _distance_active
	_sprite.visible = _distance_active
	if _distance_active:
		_apply_collision_for_current_state()
		if _state == PufferState.INFLATING:
			_sprite.play(&"inflate")
		elif _state == PufferState.DEFLATING:
			_sprite.play(&"deflate")
		else:
			_sprite.play()
		return
	_sprite.pause()
	_external_currents.clear()


func is_puffed() -> bool:
	return _state == PufferState.PUFFED


func get_puffed_time_remaining() -> float:
	return _puffed_remaining


func _begin_inflating() -> void:
	_state = PufferState.INFLATING
	_puffed_remaining = 0.0
	_swim_velocity = Vector2.ZERO
	if use_puffed_collision_during_transition:
		_apply_collision_profile(&"puffed")
	else:
		_apply_collision_profile(&"normal")
	_sprite.animation = &"inflate"
	_sprite.frame = 0
	_sprite.play()


func _begin_puffed_hold() -> void:
	_state = PufferState.PUFFED
	_puffed_remaining = puffed_duration
	_swim_velocity = Vector2.ZERO
	_apply_collision_profile(&"puffed")
	_sprite.play(&"puffed")


func _begin_deflating() -> void:
	if _state == PufferState.DEFLATING:
		return
	_state = PufferState.DEFLATING
	_puffed_remaining = 0.0
	_swim_velocity = Vector2.ZERO
	if use_puffed_collision_during_transition:
		_apply_collision_profile(&"puffed")
	else:
		_apply_collision_profile(&"normal")
	_sprite.animation = &"deflate"
	_sprite.frame = 0
	_sprite.play()


func _return_to_normal() -> void:
	_state = PufferState.NORMAL
	_puffed_remaining = 0.0
	_apply_collision_profile(&"normal")
	_sprite.play(&"normal")
	_choose_next_patrol_target(true)


func _on_animation_finished() -> void:
	if _state == PufferState.INFLATING and _sprite.animation == &"inflate":
		_begin_puffed_hold()
	elif _state == PufferState.DEFLATING and _sprite.animation == &"deflate":
		_return_to_normal()


func _update_puff_timer(delta: float) -> void:
	if _state != PufferState.PUFFED:
		return
	_puffed_remaining = maxf(0.0, _puffed_remaining - delta)
	if _puffed_remaining <= 0.0:
		_begin_deflating()


func _update_normal_swim(delta: float) -> void:
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= waypoint_reached_distance or _has_passed_patrol_target():
		_choose_next_patrol_target(false)
		to_target = _patrol_target - global_position
	if to_target.length_squared() <= 0.001:
		return

	var desired_direction: Vector2 = to_target.normalized()
	desired_direction.y += sin(
		_elapsed * TAU * vertical_wander_frequency + _wander_phase
	) * vertical_wander_strength
	desired_direction = desired_direction.normalized()
	_swim_velocity = _swim_velocity.move_toward(
		desired_direction * _cruise_speed,
		steering_acceleration * delta,
	)


func _choose_next_patrol_target(initial_target: bool) -> void:
	if not initial_target:
		_travel_sign *= -1.0
	var horizontal_distance: float = patrol_half_extents.x * _rng.randf_range(0.68, 1.0)
	_patrol_target = _home_position + Vector2(
		_travel_sign * horizontal_distance,
		_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
	)
	_cruise_speed = _rng.randf_range(
		minf(minimum_swim_speed, maximum_swim_speed),
		maxf(minimum_swim_speed, maximum_swim_speed),
	)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _has_passed_patrol_target() -> bool:
	if _travel_sign > 0.0:
		return global_position.x >= _patrol_target.x
	return global_position.x <= _patrol_target.x


func _handle_collisions() -> void:
	if get_slide_collision_count() <= 0:
		return
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector2 = collision.get_normal()
		if normal.length_squared() > 0.001:
			_swim_velocity = _swim_velocity.slide(normal)
			_kick_impulse = _kick_impulse.slide(normal)
	if _state == PufferState.NORMAL:
		_choose_next_patrol_target(false)


func _clamp_to_patrol_area() -> void:
	var clamped_position := Vector2(
		clampf(
			global_position.x,
			_home_position.x - patrol_half_extents.x,
			_home_position.x + patrol_half_extents.x,
		),
		clampf(
			global_position.y,
			_home_position.y - patrol_half_extents.y,
			_home_position.y + patrol_half_extents.y,
		),
	)
	if clamped_position != global_position:
		global_position = clamped_position
		if _state == PufferState.NORMAL:
			_choose_next_patrol_target(false)


func _update_facing(motion_velocity: Vector2) -> void:
	if absf(motion_velocity.x) < 2.0:
		return
	var moving_left: bool = motion_velocity.x < 0.0
	_sprite.flip_h = moving_left != source_faces_left


func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	var invalid_sources: Array[Node] = []
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			invalid_sources.append(source)
			continue
		total_velocity += _external_currents[source] as Vector2
	for invalid_source: Node in invalid_sources:
		_external_currents.erase(invalid_source)
	return total_velocity


func _configure_collision_profiles() -> void:
	if normal_collision_shape == null and is_instance_valid(_collision_shape):
		normal_collision_shape = _collision_shape.shape
	if puffed_collision_shape == null:
		puffed_collision_shape = normal_collision_shape


func _apply_collision_for_current_state() -> void:
	if _state == PufferState.PUFFED:
		_apply_collision_profile(&"puffed")
	elif (_state == PufferState.INFLATING or _state == PufferState.DEFLATING) and use_puffed_collision_during_transition:
		_apply_collision_profile(&"puffed")
	else:
		_apply_collision_profile(&"normal")


func _apply_collision_profile(profile_name: StringName) -> void:
	if not is_instance_valid(_collision_shape):
		return
	var target_shape: Shape2D = normal_collision_shape
	if profile_name == &"puffed" and puffed_collision_shape != null:
		target_shape = puffed_collision_shape
	if target_shape == null:
		return
	_collision_shape.position = Vector2.ZERO
	_collision_shape.scale = Vector2.ONE
	_collision_shape.shape = target_shape
	_collision_shape.disabled = not _distance_active
	_collision_profile = profile_name


func _configure_animation_speeds() -> void:
	if _sprite.sprite_frames == null:
		return
	_sprite.sprite_frames.set_animation_speed(&"inflate", transition_fps)
	_sprite.sprite_frames.set_animation_speed(&"deflate", transition_fps)


func _apply_display_scale() -> void:
	if _sprite.sprite_frames == null:
		return
	var normal_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"normal", 0)
	if normal_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(normal_texture.get_height()))
	_sprite.scale = Vector2.ONE * scale_factor


func get_debug_lines() -> Array[String]:
	return [
		"[PufferFish]",
		"state=%s" % PufferState.keys()[_state],
		"puffed_remaining=%.2f" % _puffed_remaining,
		"collision_profile=%s" % String(_collision_profile),
		"collision_disabled=%s" % str(_collision_shape.disabled if is_instance_valid(_collision_shape) else true),
		"position=%s" % str(global_position),
		"target=%s" % str(_patrol_target),
		"distance_active=%s" % str(_distance_active),
	]
