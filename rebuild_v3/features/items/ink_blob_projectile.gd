class_name CotcInkBlobProjectile
extends Area2D

signal impacted(position: Vector2)

@export_range(100.0, 4000.0, 10.0) var travel_speed: float = 1050.0
@export_range(100.0, 4000.0, 10.0) var maximum_distance: float = 1150.0
@export_range(8.0, 120.0, 1.0) var blob_radius: float = 34.0

var _source: Node2D
var _direction: Vector2 = Vector2.RIGHT
var _travelled_distance: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	queue_redraw()


func launch(origin: Vector2, direction: Vector2, source: Node2D) -> void:
	_source = source
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	global_position = origin
	_travelled_distance = 0.0
	_elapsed = 0.0
	rotation = _direction.angle()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var step_distance: float = travel_speed * delta
	var next_position: Vector2 = global_position + _direction * step_distance
	var hit: Dictionary = _intersect_blob_path(global_position, next_position)
	if not hit.is_empty():
		global_position = hit.get("position", next_position) as Vector2
		_finish_impact()
		return
	global_position = next_position
	_travelled_distance += step_distance
	rotation += delta * 4.0
	if _travelled_distance >= maximum_distance:
		_finish_impact()


func _intersect_blob_path(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _source is CollisionObject2D:
		query.exclude = [(_source as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


func _finish_impact() -> void:
	set_physics_process(false)
	impacted.emit(global_position)
	queue_free()


func _draw() -> void:
	var core: Color = Color(0.005, 0.002, 0.012, 0.98)
	var edge: Color = Color(0.13, 0.02, 0.19, 0.50)
	draw_circle(Vector2.ZERO, blob_radius * 1.34, edge)
	draw_circle(Vector2.ZERO, blob_radius, core)
	draw_circle(Vector2(blob_radius * 0.52, -blob_radius * 0.24), blob_radius * 0.56, core)
	draw_circle(Vector2(-blob_radius * 0.47, blob_radius * 0.27), blob_radius * 0.61, core)
	draw_circle(Vector2(blob_radius * 0.16, blob_radius * 0.58), blob_radius * 0.44, core)
