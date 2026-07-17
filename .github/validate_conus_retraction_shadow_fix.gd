extends SceneTree

const HYLAS_INPUT_PATH: String = "res://scenes/characters/Hylas/hylas_equipment_input.gd"
const SHADOW_SYNC_PATH: String = "res://scenes/characters/Hylas/hylas_shadow_sync.gd"
const HYLAS_SCENE_PATH: String = "res://scenes/characters/Hylas/hylas.tscn"


func _init() -> void:
	var hylas_source: String = FileAccess.get_file_as_string(HYLAS_INPUT_PATH)
	var shadow_source: String = FileAccess.get_file_as_string(SHADOW_SYNC_PATH)

	_require(
		hylas_source.contains(
			"_conus_climb_wait_for_conch_release = Input.is_action_pressed(&\"conch\")"
		),
		"Conus climb did not capture the original firing press for its release latch.",
	)
	_require(
		hylas_source.contains("elif Input.is_action_just_pressed(&\"conch\")"),
		"Conus retraction is not owned by the physics Input action path.",
	)
	_require(
		hylas_source.contains("_conus_climb_tether.call(&\"retract\")"),
		"The climb physics path does not retract the stored tether.",
	)
	_require(
		not hylas_source.contains(
			"event.is_action_pressed(&\"conch\", false, true) and _is_primary_item_a_binding(event)"
		),
		"The obsolete event-based climb retraction route is still present.",
	)
	_require(
		shadow_source.contains("position = _animated_sprite.position"),
		"ShadowSprite does not copy AnimatedSprite's local climb offset.",
	)
	_require(
		ResourceLoader.exists(HYLAS_SCENE_PATH, "PackedScene"),
		"The canonical Hylas scene is not loadable after the fix.",
	)
	var hylas_scene: PackedScene = load(HYLAS_SCENE_PATH) as PackedScene
	_require(hylas_scene != null, "Godot could not load the canonical Hylas scene.")

	print("Conus retraction and shadow alignment validation passed.")
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
