class_name CotcConusTetherProjectile
extends Node2D

signal tether_finished

@export_category("Dart Travel")
@export_range(100.0, 4000.0, 10.0) var travel_speed: float = 1450.0
@export_range(100.0, 4000.0, 10.0) var maximum_distance: float = 1500.0
@export_range(0.1, 5.0, 0.05) var anchored_seconds: float = 1.25
@export_range(10.0, 150.0, 1.0) var dart_display_height: float = 44.0

@export_category("Rope Motion")
@export_range(0.0, 100.0, 1.0) var rope_wave_height: float = 7.0
@export_range(0.0, 10.0, 0.05) var rope_wave_speed: float = 1.8

@onready var _rope_glow: Line2D = %RopeGlow
@onready var _rope: Line2D = %Rope
@onready var _dart_glow: Sprite2D = %DartGlow
@onready var _dart: Sprite2D = %Dart

var _source: Node2D
var _direction: Vector2 = Vector2.RIGHT
var _dart_world_position: Vector2 = Vector2.ZERO
var _travelled_distance: float = 0.0
var _anchored_remaining: float = 0.0
var _anchored: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	_apply_dart_scale()


func launch(origin: Vector2, direction: Vector2, source: Node2D) -> void:
	_source = source
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_dart_world_position = _get_rope_origin(origin) + _direction * 18.0
	_travelled_distance = 0.0
	_anchored_remaining = anchored_seconds
	_anchored = false
	_elapsed = 0.0
	_dart.rotation = _direction.angle()
	_dart_glow.rotation = _direction.angle()
	_update_visuals()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _anchored:
		_anchored_remaining = maxf(0.0, _anchored_remaining - delta)
		_update_visuals()
		if _anchored_remaining <= 0.0:
			tether_finished.emit()
			queue_free()
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
	_anchored = true
	_anchored_remaining = anchored_seconds
	if collider != null and collider.has_method(&"receive_conus_dart"):
		collider.call(&"receive_conus_dart", _source)


func _get_rope_origin(fallback: Vector2) -> Vector2:
	if not is_instance_valid(_source):
		return fallback
	var marker: Node2D = _source.get_node_or_null("ConchPulseOrigin") as Node2D
	if marker != null:
		return marker.global_position
	return _source.global_position + _direction * 100.0


func _update_visuals() -> void:
	var source_position: Vector2 = _get_rope_origin(_dart_world_position - _direction * 20.0)
	var local_start: Vector2 = to_local(source_position)
	var local_end: Vector2 = to_local(_dart_world_position)
	var perpendicular: Vector2 = Vector2(-_direction.y, _direction.x)
	var wave: float = sin(_elapsed * rope_wave_speed * TAU) * rope_wave_height
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = 10
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var envelope: float = sin(t * PI)
		var offset: Vector2 = perpendicular * sin(t * PI * 2.0 + _elapsed * rope_wave_speed) * wave * envelope
		points.append(local_start.lerp(local_end, t) + offset)
	_rope.points = points
	_rope_glow.points = points
	_dart.global_position = _dart_world_position
	_dart_glow.global_position = _dart_world_position


func _apply_dart_scale() -> void:
	if _dart.texture == null:
		return
	var texture_height: float = float(_dart.texture.get_height())
	if texture_height <= 0.0:
		return
	var scale_factor: float = dart_display_height / texture_height
	_dart.scale = Vector2.ONE * scale_factor
	_dart_glow.scale = Vector2.ONE * scale_factor * 1.10
