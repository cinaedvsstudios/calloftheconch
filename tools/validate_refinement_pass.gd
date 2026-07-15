extends SceneTree

const CONTINUE_SCENE: String = "res://rebuild_v3/app/contexts/continue/continue_context.tscn"
const HUD_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/gameplay_hud.tscn"
const ITEM_CONTROLLER_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.tscn"
const COUNTDOWN_SCENE: String = "res://rebuild_v3/game/shared/ui/effect_countdown_overlay.tscn"
const INK_BLOB_SCENE: String = "res://rebuild_v3/features/items/ink_blob_projectile.tscn"
const INK_CLOUD_SCENE: String = "res://rebuild_v3/features/items/ink_paralysis_cloud.tscn"
const CONUS_SCENE: String = "res://rebuild_v3/features/items/conus_tether_projectile.tscn"
const HYLAS_SCENE: String = "res://scenes/characters/Hylas/hylas.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	_validate_continue_scene()
	_validate_hud_and_countdown()
	_validate_item_controller()
	_validate_ink_items()
	_validate_conus()
	_validate_hylas()

	if _failures.is_empty():
		print("REFINEMENT_PASS_VALIDATION_OK")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("REFINEMENT_PASS_VALIDATION_FAILED count=%d" % _failures.size())
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


func _validate_continue_scene() -> void:
	var context: Node = _instantiate_scene(CONTINUE_SCENE)
	if context == null:
		return
	if not context.has_method(&"_on_save_row_pressed"):
		_failures.append("Continue context is missing click selection.")
	context.free()


func _validate_hud_and_countdown() -> void:
	var hud: Node = _instantiate_scene(HUD_SCENE)
	if hud == null:
		return
	if hud.get_node_or_null("ItemBCountdown") == null:
		_failures.append("Gameplay HUD is missing ItemBCountdown.")
	if not hud.has_method(&"set_item_effect_countdown"):
		_failures.append("Gameplay HUD is missing countdown control methods.")
	hud.free()

	var countdown: Node = _instantiate_scene(COUNTDOWN_SCENE)
	if countdown == null:
		return
	if not countdown.has_method(&"set_countdown"):
		_failures.append("Reusable countdown scene is missing set_countdown().")
	countdown.free()


func _validate_item_controller() -> void:
	var controller: Node = _instantiate_scene(ITEM_CONTROLLER_SCENE)
	if controller == null:
		return
	if not is_equal_approx(float(controller.get("purple_shield_seconds")), 10.0):
		_failures.append("Purple Shield is not ten seconds.")
	if not is_equal_approx(float(controller.get("camouflage_seconds")), 10.0):
		_failures.append("Haliotis camouflage is not ten seconds.")
	controller.free()


func _validate_ink_items() -> void:
	var blob: Node = _instantiate_scene(INK_BLOB_SCENE)
	if blob == null:
		return
	if float(blob.get("impact_radius")) < 70.0:
		_failures.append("Argonauta projectile impact radius is below 70 pixels.")
	blob.free()

	var cloud: Node = _instantiate_scene(INK_CLOUD_SCENE)
	if cloud == null:
		return
	if not is_equal_approx(float(cloud.get("active_seconds")), 10.0):
		_failures.append("Argonauta cloud active phase is not ten seconds.")
	if not is_equal_approx(float(cloud.get("minimum_opacity")), 0.40):
		_failures.append("Argonauta cloud minimum opacity is not 40 percent.")
	if not is_equal_approx(float(cloud.get("maximum_opacity")), 0.80):
		_failures.append("Argonauta cloud maximum opacity is not 80 percent.")
	if not cloud.has_signal(&"countdown_changed"):
		_failures.append("Argonauta cloud is missing synchronized countdown signal.")
	cloud.free()


func _validate_conus() -> void:
	var tether: Node = _instantiate_scene(CONUS_SCENE)
	if tether == null:
		return
	if not is_equal_approx(float(tether.get("dart_display_height")), 34.0):
		_failures.append("Conus dart is not 34 pixels high.")
	var dart_glow: Sprite2D = tether.get_node_or_null("DartGlow") as Sprite2D
	if dart_glow == null or dart_glow.material == null:
		_failures.append("Conus dart orange glow material is missing.")
	tether.free()


func _validate_hylas() -> void:
	var hylas: Node = _instantiate_scene(HYLAS_SCENE)
	if hylas == null:
		return
	var anchor: Marker2D = hylas.get_node_or_null("ItemVisuals/ConchOverlayAnchor") as Marker2D
	if anchor == null:
		_failures.append("Hylas is missing draggable ConchOverlayAnchor.")
	if hylas.get_node_or_null("ItemVisuals/ConchOverlayAnchor/EquippedShellOverlay") == null:
		_failures.append("Equipped shell is not parented to ConchOverlayAnchor.")
	if not hylas.has_signal(&"death_landed"):
		_failures.append("Hylas is missing death_landed signal.")
	var normal_frames: SpriteFrames = load("res://scenes/characters/Hylas/hylas_v3_sprite_frames.tres") as SpriteFrames
	var greatfin_frames: SpriteFrames = load("res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres") as SpriteFrames
	if normal_frames == null or greatfin_frames == null:
		_failures.append("Could not load normal and Greatfin SpriteFrames.")
	hylas.free()
