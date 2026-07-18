class_name CotcFishSchool
extends Area2D

## Decorative fish school that wanders mainly left/right around its placed
## position. The path includes changing vertical targets and a gentle sine
## sway so it never travels in one perfectly straight line.

@export_category("Animation")
@export_range(40.0, 800.0, 1.0) var display_height: float = 260.0
@export_range(0.10, 4.0, 0.01) var display_scale_multiplier: float = 1.20
@export var source_faces_left: bool = false

@export_category("Patrol Area")
@export var patrol_half_extents: Vector2 = Vector2(850.0, 220.0)
@export_range(1.0, 500.0, 1.0) var minimum_drift_speed: float = 38.0
@export_range(1.0, 500.0, 1.0) var maximum_drift_speed: float = 64.0
@export_range(1.0, 1000.0, 1.0) var steering_acceleration: float = 95.0
@export_range(10.0, 300.0, 1.0) var waypoint_reached_distance: float = 65.0
@export_range(0.0, 1.0, 0.01) var vertical_wander_strength: float = 0.28
@export_range(0.01, 3.0, 0.01) var vertical_wander_frequency: float = 0.24
@export var random_seed: int = 0

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.32
@export_range(0.0, 1000.0, 1.0) var conch_push_speed: float = 180.0
@export_range(1.0, 2000.0, 1.0) var conch_push_decay: float = 180.0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite

var _home_position: Vector2
var _patrol_target: Vector2
var _travel_sign: float = 1.0
var _cruise_speed: float = 50.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _conch_impulse: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _distance_active: bool = true
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
	_sprite.play(&"idle")
	set_physics_process(true)
	monitorable = true


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitorable = _distance_active
	if _distance_active:
		_sprite.play()
		return
	_sprite.pause()
	_external_currents.clear()
	_conch_impulse = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= waypoint_reached_distance or _has_passed_patrol_target():
		_choose_next_patrol_target(false)
		to_target = _patrol_target - global_position

	if to_target.length_squared() > 0.001:
		var desired_direction: Vector2 = to_target.normalized()
		desired_direction.y += sin(
			_elapsed * TAU * vertical_wander_frequency + _wander_phase
		) * vertical_wander_strength
		desired_direction = desired_direction.normalized()
		_movement_velocity = _movement_velocity.move_toward(
			desired_direction * _cruise_speed,
			steering_acceleration * delta,
		)

	_conch_impulse = _conch_impulse.move_toward(
		Vector2.ZERO,
		conch_push_decay * delta,
	)
	var total_velocity: Vector2 = (
		_movement_velocity
		+ _get_external_current_velocity() * current_influence
		+ _conch_impulse
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
		origin: Vector2,
		pulse_direction: Vector2,
		_distance: float,
		strength: float,
	) -> void:
	var away_direction: Vector2 = global_position - origin
	if away_direction.length_squared() <= 0.001:
		away_direction = pulse_direction
	if away_direction.length_squared() <= 0.001:
		return
	var applied_strength: float = clampf(strength, 0.55, 1.35)
	_conch_impulse += away_direction.normalized() * conch_push_speed * applied_strength


func _choose_next_patrol_target(initial_target: bool) -> void:
	if not initial_target:
		_travel_sign *= -1.0
	var horizontal_distance: float = patrol_half_extents.x * _rng.randf_range(0.68, 1.0)
	_patrol_target = _home_position + Vector2(
		_travel_sign * horizontal_distance,
		_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
	)
	_cruise_speed = _rng.randf_range(
		minf(minimum_drift_speed, maximum_drift_speed),
		maxf(minimum_drift_speed, maximum_drift_speed),
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
		var source_velocity: Vector2 = _external_currents[source]
		total_velocity += source_velocity
	return total_velocity


func _update_facing(motion_velocity: Vector2) -> void:
	if absf(motion_velocity.x) < 2.0:
		return
	var moving_left: bool = motion_velocity.x < 0.0
	_sprite.flip_h = moving_left != source_faces_left


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture == null:
		return
	var scale_factor: float = (
		display_height
		* display_scale_multiplier
		/ maxf(1.0, float(first_texture.get_height()))
	)
	_sprite.scale = Vector2.ONE * scale_factor