class_name CotcSharkEnemy
extends Area2D

## Patrol enemy with a Pac-Man-style intercept rule: when Hylas is close, the
## shark aims at a point ahead of Hylas instead of steering directly at him.
## Contact currently emits a signal only; the heart system will connect later.

signal hylas_contacted(hylas: Node2D)
signal frozen_started()
signal frozen_finished()

@export_category("Animation")
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
@export_range(0.1, 20.0, 0.1) var freeze_duration: float = 10.0
@export_range(0.0, 1.0, 0.01) var frozen_drift_retention: float = 0.28
@export_range(0.0, 100.0, 0.5) var frozen_drift_drag: float = 2.0
@export_range(0.0, 100.0, 1.0) var frozen_vertical_bob_speed: float = 10.0
@export_range(0.01, 2.0, 0.01) var frozen_vertical_bob_frequency: float = 0.32

@export_category("Stun Glow")
@export var stun_glow_color: Color = Color(0.0, 0.82, 1.0, 1.0)
@export_range(0.1, 12.0, 0.1) var stun_glow_pulse_speed: float = 4.5
@export_range(0.0, 3.0, 0.05) var stun_glow_strength: float = 1.25
@export_range(0.0, 12.0, 0.5) var stun_glow_radius: float = 5.0

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.22

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _stun_material: ShaderMaterial = %AnimatedSprite.material as ShaderMaterial

var _home_position: Vector2
var _patrol_target: Vector2
var _travel_sign: float = 1.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _frozen_drift_velocity: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _hylas: Node2D
var _freeze_ends_at_msec: int = 0
var _frozen_visual_active: bool = false
var _frozen_elapsed: float = 0.0
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
	_configure_stun_material()
	_sprite.play(&"normal")
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true
	set_physics_process(true)
	_find_hylas()
	_connect_to_level_conch_signal()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitoring = _distance_active
	monitorable = _distance_active
	if _distance_active:
		_refresh_frozen_state_after_wake()
		return
	_sprite.pause()
	_external_currents.clear()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(_hylas):
		_find_hylas()

	if is_frozen():
		if not _frozen_visual_active:
			_begin_frozen_state()
		_update_frozen(delta)
		return
	if _frozen_visual_active:
		_finish_frozen_state()

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
	var was_already_frozen: bool = is_frozen()
	_freeze_ends_at_msec = Time.get_ticks_msec() + int(round(freeze_duration * 1000.0))

	if not was_already_frozen or not _frozen_visual_active:
		_begin_frozen_state()
	else:
		_sprite.play(&"frozen")
		_set_stun_glow_enabled(true)


func is_frozen() -> bool:
	return Time.get_ticks_msec() < _freeze_ends_at_msec


func get_frozen_time_remaining() -> float:
	return maxf(
		0.0,
		float(_freeze_ends_at_msec - Time.get_ticks_msec()) / 1000.0,
	)


func _begin_frozen_state() -> void:
	_frozen_visual_active = true
	_frozen_elapsed = 0.0
	var source_velocity: Vector2 = _movement_velocity
	if source_velocity.length_squared() <= 4.0:
		var moving_left: bool = _sprite.flip_h != source_faces_left
		var drift_sign: float = -1.0 if moving_left else 1.0
		source_velocity = Vector2(drift_sign * patrol_speed, 0.0)
	_frozen_drift_velocity = source_velocity * frozen_drift_retention
	_movement_velocity = Vector2.ZERO
	_sprite.play(&"frozen")
	_set_stun_glow_enabled(true)
	frozen_started.emit()


func _update_frozen(delta: float) -> void:
	_frozen_elapsed += delta
	_frozen_drift_velocity = _frozen_drift_velocity.move_toward(
		Vector2.ZERO,
		frozen_drift_drag * delta,
	)

	var vertical_bob: Vector2 = Vector2(
		0.0,
		sin(_frozen_elapsed * TAU * frozen_vertical_bob_frequency + _wander_phase)
			* frozen_vertical_bob_speed,
	)
	var total_frozen_velocity: Vector2 = (
		_frozen_drift_velocity
		+ _get_external_current_velocity() * current_influence
		+ vertical_bob
	)
	global_position += total_frozen_velocity * delta


func _finish_frozen_state() -> void:
	if not _frozen_visual_active:
		return
	_freeze_ends_at_msec = 0
	_frozen_visual_active = false
	_set_stun_glow_enabled(false)
	_sprite.play(&"normal")
	_movement_velocity = _frozen_drift_velocity
	_frozen_drift_velocity = Vector2.ZERO
	_choose_next_patrol_target(true)
	frozen_finished.emit()


func _refresh_frozen_state_after_wake() -> void:
	if is_frozen():
		_frozen_visual_active = true
		_sprite.play(&"frozen")
		_set_stun_glow_enabled(true)
		return
	if _frozen_visual_active:
		_finish_frozen_state()
		return
	_sprite.play(&"normal")
	_set_stun_glow_enabled(false)


func _configure_stun_material() -> void:
	if _stun_material == null:
		return
	_stun_material.set_shader_parameter(&"glow_color", stun_glow_color)
	_stun_material.set_shader_parameter(&"pulse_speed", stun_glow_pulse_speed)
	_stun_material.set_shader_parameter(&"glow_strength", stun_glow_strength)
	_stun_material.set_shader_parameter(&"glow_radius", stun_glow_radius)
	_stun_material.set_shader_parameter(&"stunned_amount", 0.0)


func _set_stun_glow_enabled(enabled: bool) -> void:
	if _stun_material == null:
		return
	_stun_material.set_shader_parameter(&"stunned_amount", 1.0 if enabled else 0.0)


func _find_hylas() -> void:
	_hylas = get_tree().get_first_node_in_group(&"hylas") as Node2D


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
	var hit_distance: float = 0.0
	if is_instance_valid(_hylas):
		origin = _hylas.global_position
		var target_offset: Vector2 = hit_position - origin
		hit_distance = target_offset.length()
		if target_offset.length_squared() > 0.001:
			pulse_direction = target_offset.normalized()
	receive_conch_hit(origin, pulse_direction, hit_distance, 1.0)


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
	if hylas_body != null and hylas_body.velocity.length_squared() > 1.0:
		facing_direction = Vector2.LEFT if hylas_body.velocity.x < 0.0 else Vector2.RIGHT
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
		var source_velocity: Vector2 = _external_currents[source]
		total_velocity += source_velocity
	return total_velocity


func _update_facing(motion_velocity: Vector2) -> void:
	if absf(motion_velocity.x) < 2.0:
		return
	var moving_left: bool = motion_velocity.x < 0.0
	_sprite.flip_h = moving_left != source_faces_left


func _on_body_entered(body: Node2D) -> void:
	if is_frozen():
		return
	if body.is_in_group(&"hylas"):
		hylas_contacted.emit(body)
