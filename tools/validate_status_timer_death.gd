extends SceneTree

const GAMEPLAY_CONTEXT_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/gameplay_context.tscn"
const CONTINUE_SCRIPT: String = "res://rebuild_v3/app/contexts/continue/continue_context.gd"
const STATUS_OVERLAY_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/status_countdown_overlay.tscn"
const INK_BLOB_SCENE: String = "res://rebuild_v3/game/shared/items/argonauta/ink_blob_projectile.tscn"
const INK_CLOUD_SCENE: String = "res://rebuild_v3/game/shared/items/argonauta/ink_paralysis_cloud.tscn"
const CONUS_SCENE: String = "res://rebuild_v3/game/shared/items/conus_textile/conus_tether_projectile.tscn"
const HYLAS_SCENE: String = "res://scenes/characters/Hylas/hylas.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	_validate_gameplay_context()
	_validate_continue_selection()
	_validate_status_overlay()
	_validate_ink()
	_validate_conus()
	await _validate_hylas_death_and_scale()

	if _failures.is_empty():
		print("STATUS_TIMER_DEATH_VALIDATION_OK")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("STATUS_TIMER_DEATH_VALIDATION_FAILED count=%d" % _failures.size())
	quit(1)


func _instantiate_scene(path: String) -> Node:
	var packed_scene: PackedScene = ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as PackedScene
	if packed_scene == null:
		_failures.append("Could not load scene: %s" % path)
		return null
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		_failures.append("Could not instantiate scene: %s" % path)
	return instance


func _validate_gameplay_context() -> void:
	var gameplay: Node = _instantiate_scene(GAMEPLAY_CONTEXT_SCENE)
	if gameplay == null:
		return
	var countdown: Node = gameplay.get_node_or_null(
		"GameplayUI/GameplayHud/ItemBIcon/ItemStatusCountdown"
	)
	if countdown == null:
		_failures.append("Gameplay HUD is missing the Item B hourglass countdown.")
	gameplay.free()


func _validate_continue_selection() -> void:
	var file: FileAccess = FileAccess.open(CONTINUE_SCRIPT, FileAccess.READ)
	if file == null:
		_failures.append("Could not read ContinueContext script.")
		return
	var source: String = file.get_as_text()
	if source.contains("row.mouse_entered.connect(_on_save_row_hovered"):
		_failures.append("Save rows still select themselves on mouse hover.")


func _validate_status_overlay() -> void:
	var overlay: Node = _instantiate_scene(STATUS_OVERLAY_SCENE)
	if overlay == null:
		return
	root.add_child(overlay)
	await process_frame
	overlay.call(&"set_countdown", &"murex_pecten", 10.0, 10.0)
	if not overlay.visible:
		_failures.append("Hourglass countdown does not become visible.")
	var hourglass: TextureRect = overlay.get_node_or_null("Hourglass") as TextureRect
	var shadow: TextureRect = overlay.get_node_or_null("Shadow") as TextureRect
	if hourglass == null or hourglass.texture == null:
		_failures.append("Hourglass first frame is missing.")
	if shadow == null or shadow.material == null:
		_failures.append("Hourglass blurred black shadow is missing.")
	overlay.call(&"set_countdown", &"murex_pecten", 0.1, 10.0)
	if hourglass != null and hourglass.texture == null:
		_failures.append("Hourglass final frame is missing.")
	overlay.queue_free()
	await process_frame


func _validate_ink() -> void:
	var blob: Node = _instantiate_scene(INK_BLOB_SCENE)
	if blob != null:
		if float(blob.get("impact_radius")) < 70.0:
			_failures.append("Ink blob impact radius is still too small.")
		blob.free()

	var cloud: Node = _instantiate_scene(INK_CLOUD_SCENE)
	if cloud == null:
		return
	if not is_equal_approx(float(cloud.get("active_seconds")), 10.0):
		_failures.append("Ink cloud is not configured for ten seconds.")
	if not is_equal_approx(float(cloud.get("minimum_opacity")), 0.4):
		_failures.append("Ink minimum opacity is not 40 percent.")
	if not is_equal_approx(float(cloud.get("maximum_opacity")), 0.8):
		_failures.append("Ink maximum opacity is not 80 percent.")
	if float(cloud.get("paralysis_radius")) < 300.0:
		_failures.append("Ink paralysis radius is smaller than the visible cloud.")
	var video: VideoStreamPlayer = cloud.get_node_or_null("InkVideo") as VideoStreamPlayer
	if video == null or not video.loop:
		_failures.append("Ink video is not configured to loop.")
	var shape_node: CollisionShape2D = cloud.get_node_or_null(
		"ParalysisArea/CollisionShape2D"
	) as CollisionShape2D
	var circle: CircleShape2D = shape_node.shape as CircleShape2D if shape_node != null else null
	if circle == null or circle.radius < 300.0:
		_failures.append("Ink collision radius does not match its reliable area.")
	cloud.free()


func _validate_conus() -> void:
	var tether: Node = _instantiate_scene(CONUS_SCENE)
	if tether == null:
		return
	if not is_equal_approx(float(tether.get("dart_display_height")), 34.0):
		_failures.append("Conus dart is not fifty percent smaller.")
	var dart: Sprite2D = tether.get_node_or_null("Dart") as Sprite2D
	var glow: Sprite2D = tether.get_node_or_null("DartGlow") as Sprite2D
	if dart == null or dart.material == null:
		_failures.append("Conus dart orange outline material is missing.")
	if glow == null or glow.modulate.r <= glow.modulate.g:
		_failures.append("Conus dart glow is not orange.")
	tether.free()


func _validate_hylas_death_and_scale() -> void:
	var hylas: Node = _instantiate_scene(HYLAS_SCENE)
	if hylas == null:
		return
	root.add_child(hylas)
	await process_frame
	var sprite: AnimatedSprite2D = hylas.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	var item_visuals: Node = hylas.get_node_or_null("ItemVisuals")
	var anchor: Marker2D = hylas.get_node_or_null("ItemVisuals/ConchOverlayAnchor") as Marker2D
	if sprite == null or item_visuals == null:
		_failures.append("Hylas visual nodes are missing.")
		hylas.queue_free()
		return
	if anchor == null:
		_failures.append("Hylas conch overlay anchor is missing.")

	var normal_scale: Vector2 = sprite.scale
	item_visuals.call(&"set_greatfin_active", true)
	if not is_equal_approx(sprite.scale.x / maxf(0.0001, normal_scale.x), 1.30):
		_failures.append("Greatfin Hylas is not 130 percent of normal size.")
	item_visuals.call(&"set_greatfin_active", false)

	hylas.call(
		&"configure_world",
		Rect2(Vector2.ZERO, Vector2(3000.0, 3000.0)),
		0.0,
		Vector2(800.0, 800.0),
	)
	hylas.call(&"start_death_sequence")
	if not bool(hylas.call(&"is_death_sequence_active")):
		_failures.append("Hylas death sequence did not activate.")
	if sprite.animation != &"death_intro":
		_failures.append("Hylas did not switch to death_intro.")
	if not sprite.sprite_frames.has_animation(&"death_intro"):
		_failures.append("Hylas death_intro frames were not rebuilt.")
	if not sprite.sprite_frames.has_animation(&"death_drift"):
		_failures.append("Hylas death_drift frames were not rebuilt.")
	hylas.queue_free()
	await process_frame
