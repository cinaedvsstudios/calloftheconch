extends SceneTree

const OUTPUT_DIR: String = "res://rebuild_v3/game/shared/background_scenery/landscape"
const ALPHA_THRESHOLD: float = 0.12
const POLYGON_SIMPLIFICATION: float = 4.0
const MINIMUM_COMPONENT_AREA: float = 64.0
const TRACE_MAX_DIMENSION: int = 2048

const MANIFEST: Array[Dictionary] = [
	{"id": "rock02", "node": "Rock02", "source": "res://assets/backgrounds/rock2.webp"},
	{"id": "rock03", "node": "Rock03", "source": "res://assets/backgrounds/rock3.webp"},
	{"id": "rock04", "node": "Rock04", "source": "res://assets/backgrounds/rock4.webp"},
	{"id": "rock05", "node": "Rock05", "source": "res://assets/backgrounds/rock5.webp"},
	{"id": "rock06", "node": "Rock06", "source": "res://assets/backgrounds/rock6.webp"},
	{"id": "rock07", "node": "Rock07", "source": "res://assets/backgrounds/rock7.webp"},
	{"id": "rock08", "node": "Rock08", "source": "res://assets/backgrounds/rock8.webp"},
	{"id": "rock09", "node": "Rock09", "source": "res://assets/backgrounds/rock9.webp"},
	{"id": "rock10", "node": "Rock10", "source": "res://assets/backgrounds/rock10.webp"},
	{"id": "rock11", "node": "Rock11", "source": "res://assets/backgrounds/rock11.webp"},
	{"id": "rock12", "node": "Rock12", "source": "res://assets/backgrounds/rock12.webp"},
	{"id": "rock13", "node": "Rock13", "source": "res://assets/backgrounds/rock13.webp"},
	{"id": "rock14", "node": "Rock14", "source": "res://assets/backgrounds/rock14.webp"},
	{"id": "rock15", "node": "Rock15", "source": "res://assets/backgrounds/rock15.webp"},
	{"id": "rock_corner", "node": "RockCorner", "source": "res://assets/backgrounds/rockcorner.png"},
	{"id": "island00", "node": "Island00", "source": "res://assets/backgrounds/island00.webp"},
	{"id": "island01", "node": "Island01", "source": "res://assets/backgrounds/island01.webp"},
	{"id": "island02", "node": "Island02", "source": "res://assets/backgrounds/lsland02.webp"},
	{"id": "island03", "node": "Island03", "source": "res://assets/backgrounds/island03.webp"},
	{"id": "spike_rock", "node": "SpikeRock", "source": "res://assets/backgrounds/spikerock.webp"},
	{"id": "sand01", "node": "Sand01", "source": "res://assets/backgrounds/sand1.webp"},
	{"id": "sand02", "node": "Sand02", "source": "res://assets/backgrounds/sand2.webp"},
	{"id": "beach", "node": "Beach", "source": "res://assets/backgrounds/beach.webp"},
]


func _initialize() -> void:
	var failure_count: int = 0
	for entry: Dictionary in MANIFEST:
		if not _generate_scene(entry):
			failure_count += 1

	if failure_count == 0:
		_remove_runtime_generator_files()
		_write_readme()
		print("Generated %d baked landscape collision scenes." % MANIFEST.size())
	else:
		push_error("Landscape generation failed for %d scene(s)." % failure_count)

	quit(failure_count)


func _generate_scene(entry: Dictionary) -> bool:
	var landscape_id: String = str(entry["id"])
	var node_name: String = str(entry["node"])
	var source_path: String = str(entry["source"])
	var output_path: String = "%s/%s.tscn" % [OUTPUT_DIR, landscape_id]
	var absolute_source_path: String = ProjectSettings.globalize_path(source_path)

	if not FileAccess.file_exists(absolute_source_path):
		push_error("Missing landscape source: %s" % source_path)
		return false

	var source_image := Image.new()
	var image_error: Error = source_image.load(absolute_source_path)
	if image_error != OK or source_image.is_empty():
		push_error("Could not load landscape image: %s" % source_path)
		return false
	source_image.convert(Image.FORMAT_RGBA8)

	var polygons: Array[PackedVector2Array] = _trace_polygons(source_image)
	if polygons.is_empty():
		push_error("No alpha collision polygons were produced for: %s" % source_path)
		return false

	var texture: Texture2D = load(source_path) as Texture2D
	if texture == null:
		push_error("Could not load landscape texture resource: %s" % source_path)
		return false

	var root := StaticBody2D.new()
	root.name = node_name
	root.collision_layer = 1
	root.collision_mask = 0
	root.set_meta(&"landscape_id", landscape_id)
	root.set_meta(&"source_asset", source_path)
	root.set_meta(&"collision_source", "baked_texture_alpha")
	root.set_meta(&"alpha_threshold", ALPHA_THRESHOLD)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	root.add_child(sprite)
	sprite.owner = root

	for polygon_index: int in range(polygons.size()):
		var collision_polygon := CollisionPolygon2D.new()
		collision_polygon.name = "CollisionPolygon%02d" % (polygon_index + 1)
		collision_polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		collision_polygon.polygon = polygons[polygon_index]
		root.add_child(collision_polygon)
		collision_polygon.owner = root

	var packed_scene := PackedScene.new()
	var pack_error: Error = packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack landscape scene: %s" % output_path)
		root.free()
		return false

	var save_error: Error = ResourceSaver.save(packed_scene, output_path)
	root.free()
	if save_error != OK:
		push_error("Could not save landscape scene: %s" % output_path)
		return false

	print("Baked %s with %d collision polygon(s)." % [output_path, polygons.size()])
	return true


func _trace_polygons(source_image: Image) -> Array[PackedVector2Array]:
	var original_size: Vector2i = source_image.get_size()
	var trace_image: Image = source_image.duplicate()
	var trace_scale: float = 1.0
	var largest_dimension: int = maxi(original_size.x, original_size.y)
	if largest_dimension > TRACE_MAX_DIMENSION:
		trace_scale = float(TRACE_MAX_DIMENSION) / float(largest_dimension)
		trace_image.resize(
			maxi(1, roundi(float(original_size.x) * trace_scale)),
			maxi(1, roundi(float(original_size.y) * trace_scale)),
			Image.INTERPOLATE_BILINEAR,
		)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(trace_image, ALPHA_THRESHOLD)
	var traced_polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, trace_image.get_size()),
		POLYGON_SIMPLIFICATION,
	)

	var result: Array[PackedVector2Array] = []
	var scale_back: float = 1.0 / trace_scale
	var centre_offset: Vector2 = Vector2(original_size) * 0.5
	for traced_polygon: PackedVector2Array in traced_polygons:
		var local_polygon := PackedVector2Array()
		for point: Vector2 in traced_polygon:
			local_polygon.append(point * scale_back - centre_offset)
		if local_polygon.size() < 3:
			continue
		if absf(_signed_area(local_polygon)) < MINIMUM_COMPONENT_AREA:
			continue
		result.append(local_polygon)
	return result


func _signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for point_index: int in range(points.size()):
		var next_index: int = (point_index + 1) % points.size()
		area += (
			points[point_index].x * points[next_index].y
			- points[next_index].x * points[point_index].y
		)
	return area * 0.5


func _remove_runtime_generator_files() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	if directory == null:
		push_error("Could not open landscape output directory for cleanup.")
		return
	for obsolete_file: String in [
		"alpha_collision_landscape.gd",
		"alpha_collision_landscape.gd.uid",
		"alpha_collision_landscape_base.tscn",
	]:
		if directory.file_exists(obsolete_file):
			directory.remove(obsolete_file)


func _write_readme() -> void:
	var readme_path: String = ProjectSettings.globalize_path("%s/README.md" % OUTPUT_DIR)
	var file := FileAccess.open(readme_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not update the landscape README.")
		return
	file.store_string(
		"# Landscape scenes\n\n"
		+ "This folder contains drag-ready landscape scenes with collision polygons baked into each saved `.tscn`.\n\n"
		+ "The polygons were traced from the visible texture alpha at a threshold of `0.12`, simplified, centred to match the Sprite2D, and saved as ordinary CollisionPolygon2D children. Transparent regions do not receive generated collision.\n\n"
		+ "There is no editor-running or runtime collision generator attached to these scenes. They can be opened, inspected, moved, rotated and scaled directly in Godot.\n\n"
		+ "Included: rock02–rock15, rock_corner, island00–island03, spike_rock, sand01–sand02 and beach. `island02.tscn` deliberately references the existing misspelled source asset `lsland02.webp`.\n"
	)
	file.close()
