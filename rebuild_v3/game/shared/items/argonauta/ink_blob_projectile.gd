class_name CotcInkBlobProjectile
extends Area2D

signal impacted(world_position: Vector2)

@export_range(100.0, 4000.0, 10.0) var travel_speed: float = 1050.0
@export_range(100.0, 4000.0, 10.0) var maximum_distance: float = 1150.0
@export_range(8.0, 120.0, 1.0) var blob_radius: float = 22.0
@export_range(8.0, 180.0, 1.0) var impact_radius: float = 72.0

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
	var best_hit: Dictionary = _intersect_physics_path(from, to)
	var best_distance: float = INF
	if not best_hit.is_empty():
		var physics_position: Variant = best_hit.get("position", to)
		if physics_position is Vector2:
			best_distance = from.distance_to(physics_position)

	# Jellyfish can become non-monitorable at distance and Black Bloom exposes a
	# Node2D conch target rather than a layer-1 collider. Sweep a real circular
	# interaction radius through the canonical gameplay groups so the visible
	# ink blob stops on both without relying on a one-pixel ray.
	for group_name: StringName in [&"enemy", &"hazard", &"conch_target"]:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			if not _is_valid_impact_candidate(candidate):
				continue
			var candidate_2d: Node2D = candidate as Node2D
			if candidate_2d == null:
				continue
			var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(
				candidate_2d.global_position,
				from,
				to,
			)
			if candidate_2d.global_position.distance_to(closest_point) > impact_radius:
				continue
			var candidate_distance: float = from.distance_to(closest_point)
			if candidate_distance >= best_distance:
				continue
			best_distance = candidate_distance
			best_hit = {
				"position": closest_point,
				"collider": candidate,
			}
	return best_hit


func _intersect_physics_path(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _source is CollisionObject2D:
		query.exclude = [(_source as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


func _is_valid_impact_candidate(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	if is_instance_valid(_source):
		if candidate == _source or _source.is_ancestor_of(candidate) or candidate.is_ancestor_of(_source):
			return false
	return candidate is Node2D


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
