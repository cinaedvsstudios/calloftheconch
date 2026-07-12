class_name CotcSharkEnemy
extends Area2D

## Patrol enemy with a Pac-Man-style intercept rule: when Hylas is close, the
## shark aims at a point ahead of Hylas instead of steering directly at him.
## Contact currently emits a signal only; the heart system will connect later.

signal hylas_contacted(hylas: Node2D)
signal frozen_started()
signal frozen_finished()

@export_category("Animation")
@export_range(40.0, 900.0, 1.0) var display_height: float = 300.0
@export var source_faces_left: bool = false

@export_category("Patrol")
@export var patrol_half_extents: Vector2 = Vector2(1200.0, 360.0)
@export_range(1.0, 1000.0, 1.0) var patrol_speed: float = 135.0
@export_range(1.0, 2000.0, 1.0) var pursuit_speed: float = 245.0
@export_range(1.0, 3000.0, 1.0) var steering_acceleration: float = 420.0
@export_range(10.0, 400.0, 1.0) var waypoint_reached_distance: float = 90.0
@export_range(0.0, 1.0, 0.01) var patrol_vertical_wander_strength: float = 0.18
@export_range(0.01, 3.0, 0.01) var patrol_vertical_wander_frequency: float = 0.18
@export var random_seed: int = 0

@export_category("Hylas Intercept")
@export_range(0.1, 1.0, 0.05) var detection_screen_fraction: float = 0.5
@export_range(0.0, 1200.0, 10.0) var intercept_lead_distance: float = 320.0

@export_category("Conch Freeze")
@export_range(0.1, 20.0, 0.1) var freeze_duration: float = 2.5

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.22

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite

var _home_position: Vector2
var _patrol_target: Vector2
var _travel_sign: float = 1.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _hylas: Node2D
var _frozen_remaining: float = 0.0
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home_position = global_position
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_travel_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_wander_phase = _rng.randf_range(0.0, TAU)
	_choose_next_patrol_target(true)
	_apply_display_scale()
	_sprite.play(&"normal")
	body_entered.connect(_on_body_entered)
	_find_hylas()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(_hylas):
		_find_hylas()

	if _frozen_remaining > 0.0:
		_update_frozen(delta)
		return

	var pursuing_hylas: bool = _is_hylas_in_detection_range()
	var movement_target: Vector2
	var movement_speed: float
	if pursuing_hylas:
		movement_target = _get_hylas_intercept_point()
		movement_speed = pursuit_speed
	else:
		if (
			global_position.distance_to(_patrol_target) <= waypoint_reached_distance
			or _has_passed_patrol_target()
		):
			_choose_next_patrol_target(false)
		movement_target = _patrol_target
		movement_speed = patrol_speed

	var to_target: Vector2 = movement_target - global_position
	if to_target.length_squared() > 0.001:
		var desired_direction: Vector2 = to_target.normalized()
		if not pursuing_hylas:
			desired_direction.y += sin(
				_elapsed * TAU * patrol_vertical_wander_frequency + _wander_phase
			) * patrol_vertical_wander_strength
			desired_direction = desired_direction.normalized()
		_movement_velocity = _movement_velocity.move_toward(
			desired_direction * movement_speed,
			steering_acceleration * delta,
		)

	var total_velocity: Vector2 = (
		_movement_velocity
		+ _get_external_current_velocity() * current_influence
	)
	global_position += total_velocity * delta
	_update_facing(total_velocity)


func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if not is_instance_valid(source):
		return
	_external_currents[source] = current_velocity


func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)


func receive_conch_hit(
		_origin: Vector2,
		_pulse_direction: Vector2,
		_distance: float,
		_strength: float,
	) -> void:
	_frozen_remaining = freeze_duration
	_movement_velocity = Vector2.ZERO
	_sprite.play(&"frozen")
	frozen_started.emit()


func is_frozen() -> bool:
	return _frozen_remaining > 0.0


func _update_frozen(delta: float) -> void:
	_frozen_remaining = maxf(0.0, _frozen_remaining - delta)
	var current_velocity: Vector2 = _get_external_current_velocity() * current_influence
	global_position += current_velocity * delta
	if _frozen_remaining <= 0.0:
		_sprite.play(&"normal")
		_choose_next_patrol_target(true)
		frozen_finished.emit()


func _find_hylas() -> void:
	_hylas = get_tree().get_first_node_in_group(&"hylas") as Node2D


func _is_hylas_in_detection_range() -> bool:
	if not is_instance_valid(_hylas):
		return false
	return global_position.distance_to(_hylas.global_position) <= _get_detection_distance()


func _get_detection_distance() -> float:
	var visible_width: float = get_viewport_rect().size.x
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		visible_width /= maxf(0.01, absf(camera.zoom.x))
	return visible_width * detection_screen_fraction


func _get_hylas_intercept_point() -> Vector2:
	if not is_instance_valid(_hylas):
		return _patrol_target
	var facing_direction: Vector2 = Vector2.RIGHT
	var hylas_body: CharacterBody2D = _hylas as CharacterBody2D
	if hylas_body != null and hylas_body.velocity.length_squared() > 25.0:
		facing_direction = hylas_body.velocity.normalized()
	else:
		var hylas_sprite: AnimatedSprite2D = _hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
		if hylas_sprite != null and hylas_sprite.flip_h:
			facing_direction = Vector2.LEFT
	return _hylas.global_position + facing_direction * intercept_lead_distance


func _choose_next_patrol_target(initial_target: bool) -> void:
	if not initial_target:
		_travel_sign *= -1.0
	var horizontal_distance: float = patrol_half_extents.x * _rng.randf_range(0.62, 1.0)
	_patrol_target = _home_position + Vector2(
		_travel_sign * horizontal_distance,
		_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
	)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _has_passed_patrol_target() -> bool:
	if _travel_sign > 0.0:
		return global_position.x >= _patrol_target.x
	return global_position.x <= _patrol_target.x


func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			_external_currents.erase(source)
			continue
		total_velocity += _external_currents[source] as Vector2
	return total_velocity


func _update_facing(motion_velocity: Vector2) -> void:
	if absf(motion_velocity.x) < 2.0:
		return
	var moving_left: bool = motion_velocity.x < 0.0
	_sprite.flip_h = moving_left != source_faces_left


func _on_body_entered(body: Node2D) -> void:
	if _frozen_remaining > 0.0:
		return
	if body.is_in_group(&"hylas"):
		hylas_contacted.emit(body)


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"normal", 0)
	if first_texture == null:
		return
	var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
	_sprite.scale = Vector2.ONE * scale_factor
