@tool
class_name CotcAlphaCollisionLandscape
extends StaticBody2D

@export_category("Landscape")
@export var source_texture: Texture2D:
	set(value):
		source_texture = value
		_queue_rebuild()

@export var landscape_id: StringName = &""

@export_category("Alpha Collision")
@export_range(0.01, 1.0, 0.01) var alpha_threshold: float = 0.12:
	set(value):
		alpha_threshold = clampf(value, 0.01, 1.0)
		_queue_rebuild()

@export_range(0.5, 32.0, 0.5) var polygon_simplification: float = 4.0:
	set(value):
		polygon_simplification = maxf(0.5, value)
		_queue_rebuild()

@export_range(0.0, 65536.0, 1.0) var minimum_component_area: float = 64.0:
	set(value):
		minimum_component_area = maxf(0.0, value)
		_queue_rebuild()

@export_range(256, 4096, 64) var trace_max_dimension: int = 2048:
	set(value):
		trace_max_dimension = maxi(256, value)
		_queue_rebuild()

@onready var _sprite: Sprite2D = %Sprite
static var _polygon_cache: Dictionary = {}

var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild_from_texture()


func _queue_rebuild() -> void:
	update_configuration_warnings()
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred(&"_rebuild_from_texture")


func _rebuild_from_texture() -> void:
	_rebuild_queued = false
	if not is_node_ready():
		return
	_sprite.texture = source_texture
	_clear_collision_nodes()
	if source_texture == null:
		return

	var source_image: Image = source_texture.get_image()
	if source_image == null or source_image.is_empty():
		push_warning("Landscape '%s' could not read its source texture image." % String(landscape_id))
		return

	var original_size: Vector2i = source_image.get_size()
	if original_size.x <= 0 or original_size.y <= 0:
		return

	var trace_image: Image = source_image.duplicate()
	var trace_scale: float = 1.0
	var largest_dimension: int = maxi(original_size.x, original_size.y)
	if largest_dimension > trace_max_dimension:
		trace_scale = float(trace_max_dimension) / float(largest_dimension)
		var resized_size := Vector2i(
			maxi(1, roundi(float(original_size.x) * trace_scale)),
			maxi(1, roundi(float(original_size.y) * trace_scale)),
		)
		trace_image.resize(
			resized_size.x,
			resized_size.y,
			Image.INTERPOLATE_BILINEAR,
		)

	var texture_key: String = source_texture.resource_path
	if texture_key.is_empty():
		texture_key = "texture"
	texture_key = "%s#%d" % [texture_key, source_texture.get_instance_id()]
	var cache_key := "%s|%.3f|%.2f|%.2f|%d" % [
		texture_key,
		alpha_threshold,
		polygon_simplification,
		minimum_component_area,
		trace_max_dimension,
	]

	var polygons: Array[PackedVector2Array] = []
	if _polygon_cache.has(cache_key):
		var cached_polygons: Array = _polygon_cache[cache_key]
		for cached_polygon: PackedVector2Array in cached_polygons:
			polygons.append(cached_polygon.duplicate())
	else:
		polygons = _trace_polygons(trace_image, original_size, trace_scale)
		_polygon_cache[cache_key] = polygons.duplicate(true)

	for polygon_index: int in range(polygons.size()):
		var collision_polygon := CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon%02d" % (polygon_index + 1)
		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		collision_polygon.polygon = polygons[polygon_index]
		collision_polygon.set_meta(&"generated_alpha_collision", true)
		add_child(collision_polygon)

	set_meta(&"generated_collision_count", polygons.size())


func _trace_polygons(
		trace_image: Image,
		original_size: Vector2i,
		trace_scale: float,
	) -> Array[PackedVector2Array]:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(trace_image, alpha_threshold)
	var traced_polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, trace_image.get_size()),
		polygon_simplification,
	)
	var polygons: Array[PackedVector2Array] = []
	var scale_back: float = 1.0 / trace_scale
	var centre_offset: Vector2 = Vector2(original_size) * 0.5
	for traced_polygon: PackedVector2Array in traced_polygons:
		var local_polygon := PackedVector2Array()
		for point: Vector2 in traced_polygon:
			local_polygon.append(point * scale_back - centre_offset)
		if local_polygon.size() < 3:
			continue
		if absf(_signed_area(local_polygon)) < minimum_component_area:
			continue
		polygons.append(local_polygon)
	return polygons


func _signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for point_index: int in range(points.size()):
		var next_index: int = (point_index + 1) % points.size()
		area += (
			points[point_index].x * points[next_index].y
			- points[next_index].x * points[point_index].y
		)
	return area * 0.5


func _clear_collision_nodes() -> void:
	for child: Node in get_children():
		if not child.has_meta(&"generated_alpha_collision"):
			continue
		remove_child(child)
		child.free()
	set_meta(&"generated_collision_count", 0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if source_texture == null:
		warnings.append("Assign a source texture so alpha collision can be generated.")
	return warnings
