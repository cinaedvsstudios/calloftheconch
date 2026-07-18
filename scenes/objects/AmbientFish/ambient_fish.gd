class_name CotcAmbientFish
extends CharacterBody2D

## Reusable two-frame ambient fish. Each fish swims in short animation bursts,
## coasts for a varied pause, stays inside a broad patrol area, receives vent
## currents, avoids terrain, and flees from actual shark enemies.

@export_category("Animation")
@export_range(30.0, 500.0, 1.0) var display_height: float = 145.0
@export_range(0.10, 4.0, 0.01) var display_scale_multiplier: float = 1.0
@export var source_faces_left: bool = false
@export_range(2, 8, 1) var minimum_swim_loops: int = 3
@export_range(2, 8, 1) var maximum_swim_loops: int = 4
@export_range(0.05, 3.0, 0.05) var minimum_coast_seconds: float = 0.35
@export_range(0.05, 3.0, 0.05) var maximum_coast_seconds: float = 1.10
@export_range(0.0, 1.0, 0.01) var coast_speed_multiplier: float = 0.48

@export_category("Patrol Area")
@export var patrol_half_extents: Vector2 = Vector2(1550.0, 440.0)
@export_range(1.0, 500.0, 1.0) var minimum_swim_speed: float = 62.0
@export_range(1.0, 500.0, 1.0) var maximum_swim_speed: float = 92.0
@export_range(1.0, 1000.0, 1.0) var swimming_steering_acceleration: float = 170.0
@export_range(1.0, 1000.0, 1.0) var coast_steering_acceleration: float = 38.0
@export_range(10.0, 300.0, 1.0) var waypoint_reached_distance: float = 85.0
@export_range(0.0, 1.0, 0.01) var vertical_wander_strength: float = 0.22
@export_range(0.01, 3.0, 0.01) var vertical_wander_frequency: float = 0.20
@export var random_seed: int = 0

@export_category("Terrain Avoidance")
@export_range(20.0, 600.0, 5.0) var wall_lookahead_distance: float = 210.0
@export_range(0.0, 4.0, 0.05) var wall_avoidance_strength: float = 1.65
@export_range(0.0, 2.0, 0.05) var wall_retarget_cooldown: float = 0.35

@export_category("Shark Avoidance")
@export_range(100.0, 3000.0, 10.0) var shark_flee_radius: float = 1050.0
@export_range(1.0, 1000.0, 1.0) var shark_flee_speed: float = 185.0
@export_range(0.02, 1.0, 0.01) var shark_scan_interval: float = 0.12

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.55
@export_range(0.0, 1000.0, 1.0) var conch_push_speed: float = 130.0
@export_range(1.0, 2000.0, 1.0) var conch_push_decay: float = 275.0

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _body_shape: CollisionShape2D = %BodyShape
@onready var _current_receiver_shape: CollisionShape2D = %CurrentReceiverShape
@onready var _wall_ray: RayCast2D = %WallRay

var _home_position: Vector2
var _patrol_target: Vector2
var _cruise_speed: float = 76.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _conch_impulse: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _coast_remaining: float = 0.0
var _swim_loops_remaining: int = 3
var _wall_retarget_remaining: float = 0.0
var _shark_scan_remaining: float = 0.0
var _cached_shark_flee_direction: Vector2 = Vector2.ZERO
var _distance_active: bool = true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home_position = global_position
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_wander_phase = _rng.randf_range(0.0, TAU)
	_choose_next_patrol_target(true)
	_apply_display_scale_and_collision()
	if not _sprite.animation_looped.is_connected(_on_animation_looped):
		_sprite.animation_looped.connect(_on_animation_looped)
	_begin_swim_burst()
	_wall_ray.enabled = true
	set_physics_process(true)
	_connect_to_level_conch_signal()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	if _distance_active:
		if _coast_remaining > 0.0:
			_sprite.pause()
		else:
			_sprite.play(&"swim")
		return
	_sprite.pause()
	_external_currents.clear()
	_cached_shark_flee_direction = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_wall_retarget_remaining = maxf(0.0, _wall_retarget_remaining - delta)
	_update_animation_cycle(delta)
	_update_cached_shark_direction(delta)

	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= waypoint_reached_distance:
		_choose_next_patrol_target(false)
		to_target = _patrol_target - global_position

	var fleeing_shark: bool = _cached_shark_flee_direction.length_squared() > 0.0001
	if fleeing_shark and _coast_remaining > 0.0:
		_begin_swim_burst()

	var desired_direction: Vector2 = _cached_shark_flee_direction
	var desired_speed: float = shark_flee_speed
	var steering_acceleration: float = swimming_steering_acceleration
	if not fleeing_shark:
		desired_direction = _get_patrol_direction(to_target)
		desired_speed = _cruise_speed
		if _coast_remaining > 0.0:
			desired_speed *= coast_speed_multiplier
			steering_acceleration = coast_steering_acceleration

	desired_direction = _apply_wall_avoidance(desired_direction, to_target)
	_movement_velocity = _movement_velocity.move_toward(
		desired_direction * desired_speed,
		steering_acceleration * delta,
	)
	_conch_impulse = _conch_impulse.move_toward(
		Vector2.ZERO,
		conch_push_decay * delta,
	)
	velocity = (
		_movement_velocity
		+ _get_external_current_velocity() * current_influence
		+ _conch_impulse
	)
	move_and_slide()
	_resolve_wall_contacts()
	_update_facing(velocity)


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
	var applied_strength: float = clampf(strength, 0.18, 1.0)
	_conch_impulse += away_direction.normalized() * conch_push_speed * applied_strength


func _update_animation_cycle(delta: float) -> void:
	if _coast_remaining <= 0.0:
		return
	_coast_remaining = maxf(0.0, _coast_remaining - delta)
	if _coast_remaining <= 0.0:
		_begin_swim_burst()


func _on_animation_looped() -> void:
	if _coast_remaining > 0.0:
		return
	_swim_loops_remaining -= 1
	if _swim_loops_remaining <= 0:
		_begin_coast()


func _begin_swim_burst() -> void:
	_coast_remaining = 0.0
	_swim_loops_remaining = _rng.randi_range(
		mini(minimum_swim_loops, maximum_swim_loops),
		maxi(minimum_swim_loops, maximum_swim_loops),
	)
	_sprite.frame = 0
	_sprite.play(&"swim")


func _begin_coast() -> void:
	_coast_remaining = _rng.randf_range(
		minf(minimum_coast_seconds, maximum_coast_seconds),
		maxf(minimum_coast_seconds, maximum_coast_seconds),
	)
	_sprite.pause()
	_sprite.frame = 0


func _get_patrol_direction(to_target: Vector2) -> Vector2:
	if to_target.length_squared() <= 0.001:
		return Vector2.RIGHT
	var desired_direction: Vector2 = to_target.normalized()
	desired_direction.y += sin(
		_elapsed * TAU * vertical_wander_frequency + _wander_phase
	) * vertical_wander_strength
	return desired_direction.normalized()


func _apply_wall_avoidance(desired_direction: Vector2, to_target: Vector2) -> Vector2:
	if desired_direction.length_squared() <= 0.001:
		desired_direction = Vector2.RIGHT
	_wall_ray.target_position = desired_direction.normalized() * wall_lookahead_distance
	_wall_ray.force_raycast_update()
	if not _wall_ray.is_colliding():
		return desired_direction.normalized()
	var wall_normal: Vector2 = _wall_ray.get_collision_normal().normalized()
	var tangent: Vector2 = desired_direction.slide(wall_normal).normalized()
	if tangent.length_squared() <= 0.001:
		tangent = wall_normal.orthogonal()
		if tangent.dot(to_target) < 0.0:
			tangent = -tangent
	return (tangent + wall_normal * wall_avoidance_strength).normalized()


func _resolve_wall_contacts() -> void:
	if get_slide_collision_count() <= 0:
		return
	var combined_normal: Vector2 = Vector2.ZERO
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		combined_normal += collision.get_normal()
	if combined_normal.length_squared() <= 0.001:
		return
	combined_normal = combined_normal.normalized()
	_movement_velocity = _movement_velocity.slide(combined_normal)
	_conch_impulse = _conch_impulse.slide(combined_normal)
	if _wall_retarget_remaining <= 0.0:
		_choose_target_away_from_wall(combined_normal)
		_wall_retarget_remaining = wall_retarget_cooldown


func _choose_target_away_from_wall(wall_normal: Vector2) -> void:
	var tangent: Vector2 = wall_normal.orthogonal()
	if _rng.randf() < 0.5:
		tangent = -tangent
	var escape_direction: Vector2 = (
		wall_normal * 0.85 + tangent * _rng.randf_range(0.35, 0.75)
	).normalized()
	var escape_distance: float = minf(
		patrol_half_extents.x * 0.65,
		_rng.randf_range(420.0, 760.0),
	)
	_patrol_target = _clamp_to_patrol_area(global_position + escape_direction * escape_distance)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _choose_next_patrol_target(initial_target: bool) -> void:
	var candidate: Vector2 = _home_position
	for attempt: int in range(8):
		candidate = _home_position + Vector2(
			_rng.randf_range(-patrol_half_extents.x, patrol_half_extents.x),
			_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
		)
		if initial_target or candidate.distance_to(global_position) >= patrol_half_extents.x * 0.35:
			break
	_patrol_target = candidate
	_cruise_speed = _rng.randf_range(
		minf(minimum_swim_speed, maximum_swim_speed),
		maxf(minimum_swim_speed, maximum_swim_speed),
	)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _clamp_to_patrol_area(candidate: Vector2) -> Vector2:
	return Vector2(
		clampf(
			candidate.x,
			_home_position.x - patrol_half_extents.x,
			_home_position.x + patrol_half_extents.x,
		),
		clampf(
			candidate.y,
			_home_position.y - patrol_half_extents.y,
			_home_position.y + patrol_half_extents.y,
		),
	)


func _update_cached_shark_direction(delta: float) -> void:
	_shark_scan_remaining -= delta
	if _shark_scan_remaining > 0.0:
		return
	_shark_scan_remaining = shark_scan_interval
	_cached_shark_flee_direction = _find_shark_flee_direction()


func _find_shark_flee_direction() -> Vector2:
	var flee_vector: Vector2 = Vector2.ZERO
	for candidate: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not (candidate is CotcSharkEnemy):
			continue
		var shark: Node2D = candidate as Node2D
		if not is_instance_valid(shark):
			continue
		var away: Vector2 = global_position - shark.global_position
		var distance: float = away.length()
		if distance <= 0.001 or distance > shark_flee_radius:
			continue
		var danger_weight: float = 1.0 - distance / shark_flee_radius
		flee_vector += away.normalized() * maxf(0.20, danger_weight * danger_weight * 2.5)
	if flee_vector.length_squared() <= 0.001:
		return Vector2.ZERO
	return flee_vector.normalized()


func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	var invalid_sources: Array[Node] = []
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			invalid_sources.append(source)
			continue
		var source_velocity: Vector2 = _external_currents[source]
		total_velocity += source_velocity
	for invalid_source: Node in invalid_sources:
		_external_currents.erase(invalid_source)
	return total_velocity


func _update_facing(motion_velocity: Vector2) -> void:
	if absf(motion_velocity.x) < 2.0:
		return
	var moving_left: bool = motion_velocity.x < 0.0
	_sprite.flip_h = moving_left != source_faces_left


func _apply_display_scale_and_collision() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"swim", 0)
	if first_texture == null:
		return
	var scale_factor: float = (
		display_height
		* display_scale_multiplier
		/ maxf(1.0, float(first_texture.get_height()))
	)
	_sprite.scale = Vector2.ONE * scale_factor
	var displayed_size: Vector2 = first_texture.get_size() * scale_factor
	_resize_rectangle_shape(_body_shape, displayed_size * Vector2(0.64, 0.48))
	_resize_rectangle_shape(_current_receiver_shape, displayed_size * Vector2(0.82, 0.68))


func _resize_rectangle_shape(collision_shape: CollisionShape2D, requested_size: Vector2) -> void:
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle
	rectangle.size = Vector2(
		maxf(20.0, requested_size.x),
		maxf(14.0, requested_size.y),
	)


func _connect_to_level_conch_signal() -> void:
	var ancestor: Node = get_parent()
	var callback := Callable(self, "_on_level_conch_target_hit")
	while ancestor != null:
		if ancestor.has_signal(&"conch_target_hit"):
			if not ancestor.is_connected(&"conch_target_hit", callback):
				ancestor.connect(&"conch_target_hit", callback)
			return
		ancestor = ancestor.get_parent()


func _on_level_conch_target_hit(
		target: Node2D,
		hit_position: Vector2,
		_pulse_index: int,
	) -> void:
	if target != self:
		return
	var origin: Vector2 = hit_position
	var pulse_direction: Vector2 = Vector2.RIGHT
	var hylas: Node2D = get_tree().get_first_node_in_group(&"hylas") as Node2D
	if hylas != null:
		origin = hylas.global_position
		var target_offset: Vector2 = hit_position - origin
		if target_offset.length_squared() > 0.001:
			pulse_direction = target_offset.normalized()
		var visible_width: float = get_viewport_rect().size.x
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera != null:
			visible_width /= maxf(0.01, absf(camera.zoom.x))
		var hit_strength: float = clampf(
			1.0 - target_offset.length() / maxf(1.0, visible_width),
			0.18,
			1.0,
		)
		receive_conch_hit(origin, pulse_direction, target_offset.length(), hit_strength)
		return
	receive_conch_hit(origin, pulse_direction, 0.0, 0.5)
