extends SceneTree

const HYLAS_SCENE: PackedScene = preload("res://scenes/characters/Hylas/hylas.tscn")


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


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _fail(message: String) -> void:
	push_error(message)
	Input.action_release(&"conch")
	quit(1)


func _run_validation() -> void:
	var hylas: Node = HYLAS_SCENE.instantiate()
	root.add_child(hylas)
	await process_frame

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

	# Simulate the original firing press still being held when the tether anchors.
	Input.action_press(&"conch")
	hylas.call(&"begin_conus_wall_climb", tether.anchor_position, tether)
	await physics_frame
	await process_frame

	if tether.retract_called:
		_fail("Conus tether retracted from the original firing press.")
		return
	if not bool(hylas.call(&"is_conus_wall_climbing")):
		_fail("Hylas did not remain in Conus wall-climb mode.")
		return

	var animated_sprite: AnimatedSprite2D = hylas.get_node("AnimatedSprite") as AnimatedSprite2D
	var shadow_sprite: Sprite2D = hylas.get_node("ShadowSprite") as Sprite2D
	if animated_sprite.position.is_equal_approx(Vector2.ZERO):
		_fail("Normal climb alignment did not apply its sprite offset.")
		return
	if not shadow_sprite.position.is_equal_approx(animated_sprite.position):
		_fail(
			"ShadowSprite position %s did not match AnimatedSprite position %s."
			% [shadow_sprite.position, animated_sprite.position]
		)
		return

	# Release the firing press, then press Space again. This second press must be
	# consumed by the climb state and retract the existing tether without refiring.
	Input.action_release(&"conch")
	await physics_frame
	Input.action_press(&"conch")
	await physics_frame

	if not tether.retract_called:
		_fail("The second Conus press did not retract the wall tether.")
		return
	if bool(hylas.call(&"is_conus_wall_climbing")):
		_fail("Hylas remained in climb mode after tether retraction.")
		return

	Input.action_release(&"conch")
	hylas.queue_free()
	tether.queue_free()
	await process_frame
	print("Conus retraction and shadow alignment validation passed.")
	quit(0)
