extends SceneTree

const LANDSCAPE_DIR: String = "res://rebuild_v3/game/shared/background_scenery/landscape"
const EXPECTED_LANDSCAPE_SCENES: int = 23
const REQUIRED_SCENES: Array[String] = [
	"res://rebuild_v3/app/front_end.tscn",
	"res://rebuild_v3/app/contexts/gameplay/gameplay_context.tscn",
	"res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_prototype.tscn",
	"res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_main.tscn",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	_validate_required_scenes()
	_validate_landscape_scenes()
	await process_frame
	await process_frame

	if _failures.is_empty():
		print("GODOT_VALIDATION_OK")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("GODOT_VALIDATION_FAILED count=%d" % _failures.size())
	quit(1)


func _validate_required_scenes() -> void:
	for scene_path: String in REQUIRED_SCENES:
		var packed_scene: PackedScene = ResourceLoader.load(
			scene_path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_REPLACE,
		) as PackedScene
		if packed_scene == null:
			_failures.append("Could not load required scene: %s" % scene_path)
			continue
		var instance: Node = packed_scene.instantiate()
		if instance == null:
			_failures.append("Could not instantiate required scene: %s" % scene_path)
			continue
		if scene_path.ends_with("gameplay_context.tscn"):
			if not instance.has_method(&"set_level_variant"):
				_failures.append("Gameplay context is missing set_level_variant().")
			if not instance.has_method(&"get_level_variant"):
				_failures.append("Gameplay context is missing get_level_variant().")
		instance.free()


func _validate_landscape_scenes() -> void:
	var directory := DirAccess.open(LANDSCAPE_DIR)
	if directory == null:
		_failures.append("Could not open landscape directory.")
		return

	var scene_files: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.ends_with(".tscn"):
			scene_files.append(file_name)
	scene_files.sort()

	if scene_files.size() != EXPECTED_LANDSCAPE_SCENES:
		_failures.append(
			"Expected %d landscape scenes but found %d." % [
				EXPECTED_LANDSCAPE_SCENES,
				scene_files.size(),
			]
		)

	for file_name: String in scene_files:
		var scene_path: String = "%s/%s" % [LANDSCAPE_DIR, file_name]
		var packed_scene: PackedScene = ResourceLoader.load(
			scene_path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_REPLACE,
		) as PackedScene
		if packed_scene == null:
			_failures.append("Could not load landscape scene: %s" % scene_path)
			continue
		var root: Node = packed_scene.instantiate()
		if root == null:
			_failures.append("Could not instantiate landscape scene: %s" % scene_path)
			continue
		if not root is StaticBody2D:
			_failures.append("Landscape root is not StaticBody2D: %s" % scene_path)
		if root.get_script() != null:
			_failures.append("Landscape scene still has a runtime/editor script: %s" % scene_path)
		if str(root.get_meta(&"collision_source", "")) != "baked_texture_alpha_outline":
			_failures.append("Landscape scene does not identify baked alpha-outline collision: %s" % scene_path)

		var sprite: Sprite2D = root.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			_failures.append("Landscape scene is missing its visible Sprite2D texture: %s" % scene_path)

		var collision_count: int = 0
		for child: Node in root.get_children():
			var collision_polygon := child as CollisionPolygon2D
			if collision_polygon == null:
				continue
			if collision_polygon.build_mode != CollisionPolygon2D.BUILD_SEGMENTS:
				_failures.append("Landscape collision is not using stable segment mode: %s/%s" % [scene_path, child.name])
				continue
			if collision_polygon.polygon.size() < 3:
				_failures.append("Landscape collision outline has fewer than three points: %s/%s" % [scene_path, child.name])
				continue
			collision_count += 1
		if collision_count == 0:
			_failures.append("Landscape scene has no baked collision outlines: %s" % scene_path)
		root.free()
