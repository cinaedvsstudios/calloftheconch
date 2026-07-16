class_name CotcConusTetherProjectile
extends Node2D

signal tether_finished

@export_category("Dart Travel")
@export_range(100.0, 4000.0, 10.0) var travel_speed: float = 1450.0
@export_range(100.0, 4000.0, 10.0) var maximum_distance: float = 1500.0
@export_range(0.1, 5.0, 0.05) var anchored_seconds: float = 1.25
@export_range(10.0, 150.0, 1.0) var dart_display_height: float = 24.0

@export_category("Rope Motion")
@export_range(0.0, 100.0, 1.0) var rope_wave_height: float = 4.0
@export_range(0.0, 10.0, 0.05) var rope_wave_speed: float = 2.6

@export_category("Dart Glow")
@export var dart_glow_color: Color = Color(1.0, 0.34, 0.08, 1.0)
@export_range(0.0, 1.0, 0.01) var dart_glow_min_alpha: float = 0.16
@export_range(0.0, 1.0, 0.01) var dart_glow_max_alpha: float = 0.34
@export_range(0.1, 12.0, 0.1) var dart_glow_pulse_speed: float = 3.2
@export_range(1.0, 30.0, 0.5) var dart_point_glow_radius: float = 8.0

@onready var _rope_bloom: Line2D = $RopeBloom
@onready var _rope_glow: Line2D = %RopeGlow
@onready var _rope: Line2D = %Rope
@onready var _dart_glow: Sprite2D = %DartGlow
@onready var _dart: Sprite2D = %Dart

var _source: Node2D
var _direction: Vector2 = Vector2.RIGHT
var _dart_world_position: Vector2 = Vector2.ZERO
var _travelled_distance: float = 0.0
var _wall_tethered: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	_apply_dart_scale()
	queue_redraw()


func launch(origin: Vector2, direction: Vector2, source: Node2D) -> void:
	_source = source
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_dart_world_position = _get_rope_origin(origin) + _direction * 18.0
	_travelled_distance = 0.0
	_wall_tethered = false
	_elapsed = 0.0
	_dart.rotation = _direction.angle()
	_dart_glow.rotation = _direction.angle()
	_update_visuals()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _wall_tethered:
		_update_visuals()
		return

	var step_distance: float = travel_speed * delta
	var next_position: Vector2 = _dart_world_position + _direction * step_distance
	var hit: Dictionary = _intersect_dart_path(_dart_world_position, next_position)
	if not hit.is_empty():
		var hit_position: Variant = hit.get("position", next_position)
		_dart_world_position = hit_position if hit_position is Vector2 else next_position
		var collider_value: Variant = hit.get("collider", null)
		var collider: Object = collider_value if collider_value is Object else null
		_anchor_tether(collider)
	else:
		_dart_world_position = next_position
		_travelled_distance += step_distance
		if _travelled_distance >= maximum_distance:
			_anchor_tether(null)
	_update_visuals()


func _intersect_dart_path(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _source is CollisionObject2D:
		query.exclude = [(_source as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


func _anchor_tether(collider: Object) -> void:
	var resolved_target: Node = _resolve_dart_target(collider)
	if resolved_target != null:
		_apply_conus_stun(resolved_target)
		retract()
		return
	if collider == null:
		retract()
		return
	_wall_tethered = true
	if is_instance_valid(_source) and _source.has_method(&"begin_conus_wall_climb"):
		_source.call(&"begin_conus_wall_climb", _dart_world_position, self)
	_update_visuals()


func retract() -> void:
	if is_queued_for_deletion():
		return
	if _wall_tethered and is_instance_valid(_source) and _source.has_method(&"end_conus_wall_climb"):
		_source.call(&"end_conus_wall_climb", self)
	_wall_tethered = false
	tether_finished.emit()
	queue_free()


func is_wall_tethered() -> bool:
	return _wall_tethered


func get_anchor_position() -> Vector2:
	return _dart_world_position


func _resolve_dart_target(collider: Object) -> Node:
	var current: Node = collider as Node
	var parent_checks: int = 0
	while current != null and parent_checks < 12:
		if current.has_method(&"receive_conus_dart") or current.has_method(&"receive_conch_hit"):
			return current
		current = current.get_parent()
		parent_checks += 1
	return null


func _apply_conus_stun(target: Node) -> void:
	if target.has_method(&"receive_conus_dart"):
		target.call(&"receive_conus_dart", _source)
		return
	if target.has_method(&"receive_conch_hit"):
		var source_position: Vector2 = _source.global_position if is_instance_valid(_source) else _dart_world_position
		target.call(
			&"receive_conch_hit",
			source_position,
			_direction,
			source_position.distance_to(_dart_world_position),
			1.0,
		)


func _get_rope_origin(fallback: Vector2) -> Vector2:
	if not is_instance_valid(_source):
		return fallback
	if _source.has_method(&"get_conus_rope_origin"):
		var resolved_origin: Variant = _source.call(&"get_conus_rope_origin")
		if resolved_origin is Vector2:
			return resolved_origin
	var marker: Node2D = _source.get_node_or_null("ConchPulseOrigin") as Node2D
	if marker != null:
		return marker.global_position
	return _source.global_position + _direction * 100.0


func _update_visuals() -> void:
	var source_position: Vector2 = _get_rope_origin(_dart_world_position - _direction * 20.0)
	var local_start: Vector2 = to_local(source_position)
	var local_end: Vector2 = to_local(_dart_world_position)
	var rope_direction: Vector2 = _dart_world_position - source_position
	if rope_direction.length_squared() <= 0.0001:
		rope_direction = _direction
	else:
		rope_direction = rope_direction.normalized()
	var perpendicular: Vector2 = Vector2(-rope_direction.y, rope_direction.x)
	var wave: float = sin(_elapsed * rope_wave_speed * TAU) * rope_wave_height
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = 16
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var envelope: float = sin(t * PI)
		var offset: Vector2 = (
			perpendicular
			* sin(t * PI * 2.0 + _elapsed * rope_wave_speed)
			* wave
			* envelope
		)
		points.append(local_start.lerp(local_end, t) + offset)
	_rope.points = points
	_rope_glow.points = points
	_rope_bloom.points = points
	_dart.global_position = _dart_world_position
	_dart_glow.global_position = _dart_world_position

	var pulse: float = 0.5 + 0.5 * sin(_elapsed * dart_glow_pulse_speed)
	var rope_glow_color: Color = _rope_glow.default_color
	rope_glow_color = Color(1.0, 0.24, 0.03, lerpf(0.48, 0.78, pulse))
	_rope_glow.default_color = rope_glow_color
	_rope_bloom.default_color = Color(1.0, 0.18, 0.01, lerpf(0.05, 0.12, pulse))
	_dart_glow.modulate = Color(
		dart_glow_color.r,
		dart_glow_color.g,
		dart_glow_color.b,
		lerpf(0.10, 0.24, pulse),
	)
	queue_redraw()


func _apply_dart_scale() -> void:
	if _dart.texture == null:
		return
	var texture_height: float = float(_dart.texture.get_height())
	if texture_height <= 0.0:
		return
	var scale_factor: float = dart_display_height / texture_height
	_dart.scale = Vector2.ONE * scale_factor
	_dart_glow.scale = Vector2.ONE * scale_factor * 1.10


func _draw() -> void:
	if _dart.texture == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * dart_glow_pulse_speed)
	var texture_width: float = float(_dart.texture.get_width()) * absf(_dart.scale.x)
	var point_world_position: Vector2 = _dart_world_position + _direction * texture_width * 0.46
	var point_local_position: Vector2 = to_local(point_world_position)
	var outer_color: Color = Color(
		dart_glow_color.r,
		dart_glow_color.g,
		dart_glow_color.b,
		lerpf(0.05, 0.13, pulse),
	)
	var core_color: Color = Color(
		1.0,
		0.52,
		0.16,
		lerpf(0.16, 0.34, pulse),
	)
	draw_circle(point_local_position, dart_point_glow_radius * 1.7, outer_color)
	draw_circle(point_local_position, dart_point_glow_radius * 0.55, core_color)
