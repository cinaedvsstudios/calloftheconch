extends SceneTree

const HYLAS_SCENE: PackedScene = preload("res://scenes/characters/Hylas/hylas.tscn")
const TEST_DELTA: float = 1.0 / 60.0


class FakeTether:
	extends Node

	var anchor_position: Vector2 = Vector2(500.0, 0.0)
	var retract_called: bool = false
	var wall_tethered: bool = true
	var hylas: Node

	func is_wall_tethered() -> bool:
		return wall_tethered

	func get_anchor_position() -> Vector2:
		return anchor_position

	func retract() -> void:
		retract_called = true
		wall_tethered = false
		if is_instance_valid(hylas) and hylas.has_method(&"end_conus_wall_climb"):
			hylas.call(&"end_conus_wall_climb", self)


func _init() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var hylas: Node = HYLAS_SCENE.instantiate()
	root.add_child(hylas)
	hylas.call(
		&"configure_world",
		Rect2(Vector2(-2000.0, -2000.0), Vector2(4000.0, 4000.0)),
		-1000.0,
		Vector2.ZERO,
	)
	hylas.call(&"set_play_enabled", true)

	var tether := FakeTether.new()
	tether.hylas = hylas
	root.add_child(tether)

	# Hold the original firing press while the tether anchors. The release latch
	# must prevent this same press from retracting it.
	Input.action_press(&"conch")
	hylas.call(&"begin_conus_wall_climb", tether.anchor_position, tether)
	hylas.call(&"_physics_process", TEST_DELTA)

	if tether.retract_called:
		_fail("Conus tether retracted from the original firing press.")
		return
	if not bool(hylas.call(&"is_conus_wall_climbing")):
		_fail("Hylas did not remain in Conus wall-climb mode.")
		return

	var animated_sprite: AnimatedSprite2D = hylas.get_node("AnimatedSprite") as AnimatedSprite2D
	var shadow_sprite: Sprite2D = hylas.get_node("ShadowSprite") as Sprite2D
	shadow_sprite.call(&"_sync_to_animated_sprite")
	if animated_sprite.position.is_equal_approx(Vector2.ZERO):
		_fail("Normal climb alignment did not apply its sprite offset.")
		return
	if not shadow_sprite.position.is_equal_approx(animated_sprite.position):
		_fail(
			"ShadowSprite position %s did not match AnimatedSprite position %s."
			% [shadow_sprite.position, animated_sprite.position]
		)
		return

	# Release the firing press so the latch clears, then press Space again. The
	# second press must retract the existing tether before ordinary firing can run.
	Input.action_release(&"conch")
	hylas.call(&"_physics_process", TEST_DELTA)
	Input.action_press(&"conch")
	hylas.call(&"_physics_process", TEST_DELTA)

	if not tether.retract_called:
		_fail("The second Conus press did not retract the wall tether.")
		return
	if bool(hylas.call(&"is_conus_wall_climbing")):
		_fail("Hylas remained in climb mode after tether retraction.")
		return

	Input.action_release(&"conch")
	print("Conus retraction and shadow alignment validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	Input.action_release(&"conch")
	quit(1)
