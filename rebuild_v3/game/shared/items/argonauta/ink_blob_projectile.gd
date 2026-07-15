class_name CotcInkBlobProjectile
extends Area2D

signal impacted(world_position: Vector2)

@export_range(100.0, 4000.0, 10.0) var travel_speed: float = 1050.0
@export_range(100.0, 4000.0, 10.0) var maximum_distance: float = 1150.0
@export_range(8.0, 120.0, 1.0) var blob_radius: float = 22.0
@export_range(20.0, 160.0, 1.0) var impact_radius: float = 70.0

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
		var hit_position: Variant = hit.get("position", next_position)
		global_position = hit_position if hit_position is Vector2 else next_position
		_finish_impact()
		return
	global_position = next_position
	_travelled_distance += step_distance
	rotation += sin(_elapsed * 9.0) * delta * 1.5
	queue_redraw()
	if _travelled_distance >= maximum_distance:
		_finish_impact()


func _intersect_blob_path(from: Vector2, to: Vector2) -> Dictionary:
	var closest_hit: Dictionary = _intersect_physics_sweep(from, to)
	var closest_distance_squared: float = INF
	if not closest_hit.is_empty():
		var physics_position: Variant = closest_hit.get("position", to)
		if physics_position is Vector2:
			closest_distance_squared = from.distance_squared_to(physics_position)

	for group_name: StringName in [&"enemy", &"hazard", &"conch_target"]:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			var direct_hit: Dictionary = _intersect_direct_target(from, to, candidate)
			if direct_hit.is_empty():
				continue
			var direct_position: Vector2 = direct_hit.get("position", to) as Vector2
			var direct_distance_squared: float = from.distance_squared_to(direct_position)
			if direct_distance_squared < closest_distance_squared:
				closest_hit = direct_hit
				closest_distance_squared = direct_distance_squared

	return closest_hit


func _intersect_physics_sweep(from: Vector2, to: Vector2) -> Dictionary:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = impact_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, from)
	query.motion = to - from
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _source is CollisionObject2D:
		query.exclude = [(_source as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.get_rest_info(query)


func _intersect_direct_target(from: Vector2, to: Vector2, candidate: Node) -> Dictionary:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return {}
	if candidate == _source or candidate.is_ancestor_of(_source) or _source.is_ancestor_of(candidate):
		return {}
	var candidate_2d: Node2D = candidate as Node2D
	if candidate_2d == null:
		return {}

	var closest_point: Vector2 = _closest_point_on_segment(candidate_2d.global_position, from, to)
	if closest_point.distance_squared_to(candidate_2d.global_position) > impact_radius * impact_radius:
		return {}
	return {
		"position": closest_point,
		"collider": candidate,
	}


func _closest_point_on_segment(point: Vector2, from: Vector2, to: Vector2) -> Vector2:
	var segment: Vector2 = to - from
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.0001:
		return from
	var amount: float = clampf((point - from).dot(segment) / segment_length_squared, 0.0, 1.0)
	return from + segment * amount


func _finish_impact() -> void:
	set_physics_process(false)
	impacted.emit(global_position)
	queue_free()


func _draw() -> void:
	var wobble: float = sin(_elapsed * 13.0) * 2.5
	var core: Color = Color(0.005, 0.002, 0.012, 0.98)
	var edge: Color = Color(0.12, 0.01, 0.17, 0.42)
	var blob: PackedVector2Array = PackedVector2Array([
		Vector2(-blob_radius * 1.55, -blob_radius * 0.20),
		Vector2(-blob_radius * 0.92, -blob_radius * 0.78 - wobble),
		Vector2(-blob_radius * 0.18, -blob_radius * 1.06),
		Vector2(blob_radius * 0.72, -blob_radius * 0.70 + wobble),
		Vector2(blob_radius * 1.42, -blob_radius * 0.12),
		Vector2(blob_radius * 0.88, blob_radius * 0.72),
		Vector2(blob_radius * 0.10, blob_radius * 1.02),
		Vector2(-blob_radius * 0.70, blob_radius * 0.66 - wobble),
	])
	var outer: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in blob:
		outer.append(point * 1.24)
	draw_colored_polygon(outer, edge)
	draw_colored_polygon(blob, core)
	draw_circle(Vector2(-blob_radius * 1.35, blob_radius * 0.18), blob_radius * 0.28, edge)
	draw_circle(Vector2(-blob_radius * 1.72, -blob_radius * 0.08), blob_radius * 0.16, edge)
