class_name CotcBoulder
extends CharacterBody2D

@export_category("Tail Flip Response")
@export var tail_flip_reach: float = 330.0
@export var tail_flip_lateral_tolerance: float = 155.0
@export var tail_flip_active_window: float = 0.55
@export var tail_flip_hit_cooldown: float = 0.18
@export var kick_speed: float = 620.0

@export_category("Heavy Drift")
@export var drift_gravity: float = 180.0
@export var water_drag: float = 0.985
@export var terrain_bounce: float = 0.16
@export var max_drift_speed: float = 900.0
@export var stop_speed: float = 6.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _solid_collision: CollisionShape2D = $SolidCollision

var _hylas: CotcHylas
var _instance_scale: Vector2 = Vector2.ONE
var _tail_flip_active_until: float = 0.0
var _active_tail_flip_direction: Vector2 = Vector2.RIGHT
var _last_hit_time: float = -999.0
var _is_drifting: bool = false


func _ready() -> void:
	_transfer_instance_scale_to_children()
	call_deferred("_connect_to_hylas")


func _physics_process(delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 <= _tail_flip_active_until:
		_try_tail_flip_hit()
	if _is_drifting:
		_update_heavy_drift(delta)


func _transfer_instance_scale_to_children() -> void:
	_instance_scale = scale
	if _instance_scale == Vector2.ZERO:
		_instance_scale = Vector2.ONE
	_sprite.scale *= _instance_scale
	_solid_collision.scale *= _instance_scale
	scale = Vector2.ONE


func _connect_to_hylas() -> void:
	_hylas = get_tree().get_first_node_in_group(&"hylas") as CotcHylas
	if _hylas == null:
		return
	if not _hylas.tail_flip_started.is_connected(_on_hylas_tail_flip_started):
		_hylas.tail_flip_started.connect(_on_hylas_tail_flip_started)


func _on_hylas_tail_flip_started(_origin: Vector2, direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return
	_active_tail_flip_direction = direction.normalized()
	_tail_flip_active_until = Time.get_ticks_msec() / 1000.0 + tail_flip_active_window
	_try_tail_flip_hit()


func _try_tail_flip_hit() -> void:
	if _hylas == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < tail_flip_hit_cooldown:
		return
	var effective_radius: float = _get_effective_collision_radius()
	var to_boulder: Vector2 = global_position - _hylas.global_position
	var forward_distance: float = to_boulder.dot(_active_tail_flip_direction)
	var lateral_distance: float = absf(to_boulder.cross(_active_tail_flip_direction))
	if forward_distance < -effective_radius or forward_distance > tail_flip_reach + effective_radius:
		return
	if lateral_distance > tail_flip_lateral_tolerance + effective_radius:
		return
	_apply_tail_flip_hit()


func _get_effective_collision_radius() -> float:
	var circle_shape: CircleShape2D = _solid_collision.shape as CircleShape2D
	if circle_shape == null:
		return 0.0
	return circle_shape.radius * maxf(absf(_solid_collision.scale.x), absf(_solid_collision.scale.y))


func _apply_tail_flip_hit() -> void:
	_last_hit_time = Time.get_ticks_msec() / 1000.0
	_tail_flip_active_until = 0.0
	_is_drifting = true
	velocity += _active_tail_flip_direction * kick_speed
	velocity = velocity.limit_length(max_drift_speed)
	_request_tail_flip_impact_vfx()
	if _hylas != null and _hylas.has_method(&"play_land_impact_sound"):
		_hylas.call(&"play_land_impact_sound")


func _request_tail_flip_impact_vfx() -> void:
	if _hylas == null:
		return
	var hylas_sprite: AnimatedSprite2D = _hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if hylas_sprite == null or hylas_sprite.animation != &"tail_flip":
		return
	var refinement: Node = _hylas.get_node_or_null("ActionVFX/Refinement")
	if refinement == null or not refinement.has_method(&"play_impact_sparks"):
		return

	var contact_direction: Vector2 = global_position - _hylas.global_position
	if contact_direction.length_squared() <= 0.0001:
		contact_direction = _active_tail_flip_direction
	else:
		contact_direction = contact_direction.normalized()
	var contact_position: Vector2 = (
		global_position
		- contact_direction * _get_effective_collision_radius()
	)
	refinement.call(&"play_impact_sparks", contact_position, -contact_direction)


func _update_heavy_drift(delta: float) -> void:
	velocity.y += drift_gravity * delta
	velocity *= pow(water_drag, delta * 60.0)
	velocity = velocity.limit_length(max_drift_speed)

	var remaining_motion: Vector2 = velocity * delta
	var bounce_index: int = 0
	while bounce_index < 4:
		bounce_index += 1
		var collision: KinematicCollision2D = move_and_collide(remaining_motion)
		if collision == null:
			break
		var normal: Vector2 = collision.get_normal()
		velocity = velocity.bounce(normal) * terrain_bounce
		remaining_motion = collision.get_remainder().bounce(normal) * terrain_bounce
		if velocity.length() <= stop_speed:
			velocity = Vector2.ZERO
			_is_drifting = false
			break
