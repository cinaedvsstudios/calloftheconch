extends SceneTree

const ITEM_CONTROLLER_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/item_effect_controller.tscn"
const TRANSFORM_SCENE: String = "res://rebuild_v3/game/shared/items/crown_sea_grapes/greatfin_transform_effect.tscn"
const INK_SCENE: String = "res://rebuild_v3/game/shared/items/argonauta/ink_paralysis_cloud.tscn"
const CONUS_SCENE: String = "res://rebuild_v3/game/shared/items/conus_textile/conus_tether_projectile.tscn"
const INVENTORY_SCENE: String = "res://rebuild_v3/app/contexts/gameplay/inventory_overlay.tscn"
const HYLAS_SCENE: String = "res://scenes/characters/Hylas/hylas.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	_validate_item_controller()
	_validate_transform_effect()
	_validate_ink_cloud()
	_validate_conus_tether()
	_validate_inventory()
	_validate_hylas()

	if _failures.is_empty():
		print("ITEM_POLISH_VALIDATION_OK")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("ITEM_POLISH_VALIDATION_FAILED count=%d" % _failures.size())
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


func _validate_item_controller() -> void:
	var controller: Node = _instantiate_scene(ITEM_CONTROLLER_SCENE)
	if controller == null:
		return
	if not is_equal_approx(float(controller.get("purple_shield_seconds")), 10.0):
		_failures.append("Purple Shield is not configured for 10 seconds.")
	if not is_equal_approx(float(controller.get("camouflage_seconds")), 10.0):
		_failures.append("Haliotis camouflage is not configured for 10 seconds.")
	if int(controller.process_mode) != Node.PROCESS_MODE_PAUSABLE:
		_failures.append("Item effect timers must pause while the inventory pauses gameplay.")
	var drill_tint: Color = controller.get("sonic_drill_tint") as Color
	if drill_tint.g <= drill_tint.r or drill_tint.g <= drill_tint.b:
		_failures.append("Sonic drill tint is not predominantly green.")
	if float(controller.get("sonic_drill_brightness")) < 3.0:
		_failures.append("Sonic drill brightness is below the requested brighter profile.")
	controller.free()


func _validate_transform_effect() -> void:
	var effect: Node = _instantiate_scene(TRANSFORM_SCENE)
	if effect == null:
		return
	var effect_control: Control = effect as Control
	if effect_control == null or not effect_control.scale.is_equal_approx(Vector2(0.75, 0.75)):
		_failures.append("Greatfin transformation video is not scaled to 75 percent.")
	effect.free()


func _validate_ink_cloud() -> void:
	var cloud: Node = _instantiate_scene(INK_SCENE)
	if cloud == null:
		return
	if float(cloud.get("paralysis_radius")) < 250.0:
		_failures.append("Ink paralysis radius is smaller than its visible cloud target.")
	var shape_node: CollisionShape2D = cloud.get_node_or_null("ParalysisArea/CollisionShape2D") as CollisionShape2D
	var circle: CircleShape2D = shape_node.shape as CircleShape2D if shape_node != null else null
	if circle == null or circle.radius < 250.0:
		_failures.append("Ink cloud collision does not cover the reliable paralysis radius.")
	cloud.free()


func _validate_conus_tether() -> void:
	var tether: Node = _instantiate_scene(CONUS_SCENE)
	if tether == null:
		return
	var rope: Line2D = tether.get_node_or_null("Rope") as Line2D
	var glow: Line2D = tether.get_node_or_null("RopeGlow") as Line2D
	var dart: Sprite2D = tether.get_node_or_null("Dart") as Sprite2D
	if rope == null:
		_failures.append("Conus tether is missing its Rope Line2D.")
	else:
		if rope.width > 4.0:
			_failures.append("Conus rope is still too thick.")
		if rope.texture_mode != Line2D.LINE_TEXTURE_STRETCH:
			_failures.append("Conus rope is not stretching one texture across the tether.")
		if rope.texture_repeat != CanvasItem.TEXTURE_REPEAT_DISABLED:
			_failures.append("Conus rope texture repeat is not disabled.")
	if glow == null or glow.width <= (rope.width if rope != null else 0.0):
		_failures.append("Conus rope glow is missing or not wider than the rope.")
	if dart == null or dart.texture == null:
		_failures.append("Conus dart artwork is missing.")
	tether.free()


func _validate_inventory() -> void:
	var inventory: Node = _instantiate_scene(INVENTORY_SCENE)
	if inventory == null:
		return
	var close_button: Button = inventory.get_node_or_null("PanelRoot/CloseButton") as Button
	if close_button == null:
		_failures.append("Inventory close button is missing.")
	else:
		var button_center_x: float = (close_button.offset_left + close_button.offset_right) * 0.5
		if absf(button_center_x - 285.0) > 2.0:
			_failures.append("Inventory close button is not centred on the panel.")
	inventory.free()


func _validate_hylas() -> void:
	var hylas: Node = _instantiate_scene(HYLAS_SCENE)
	if hylas == null:
		return
	if hylas.get_node_or_null("AnimatedSprite") == null:
		_failures.append("Hylas is missing AnimatedSprite.")
	if hylas.get_node_or_null("ItemVisuals") == null:
		_failures.append("Hylas is missing ItemVisuals.")
	hylas.free()
