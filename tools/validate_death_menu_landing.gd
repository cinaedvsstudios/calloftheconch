extends SceneTree

const HYLAS_SCENE: String = "res://scenes/characters/Hylas/hylas.tscn"

var _drift_signal_count: int = 0
var _landed_signal_count: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var packed: PackedScene = ResourceLoader.load(
		HYLAS_SCENE,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as PackedScene
	if packed == null:
		_failures.append("Could not load Hylas scene.")
		_finish()
		return

	var hylas: Node2D = packed.instantiate() as Node2D
	if hylas == null:
		_failures.append("Could not instantiate Hylas scene.")
		_finish()
		return
	root.add_child(hylas)
	await process_frame

	hylas.connect(&"death_drift_started", _on_death_menu_signal)
	hylas.connect(&"death_landed", _on_death_landed)
	hylas.call(
		&"configure_world",
		Rect2(Vector2.ZERO, Vector2(1000.0, 1000.0)),
		0.0,
		Vector2(500.0, 990.0),
	)
	hylas.call(&"reset_to_start", Vector2(500.0, 990.0))
	hylas.call(&"start_death_sequence")

	# Complete frames 1–6 directly. The menu signal must not fire when the
	# looping drift frames begin.
	hylas.call(&"_on_animation_finished")
	if _drift_signal_count != 0:
		_failures.append("Death menu signal fired when drift began.")

	# Hylas begins close enough to the world bottom to land during this update.
	hylas.call(&"_update_death_sequence", 0.25)
	if _landed_signal_count != 1:
		_failures.append("death_landed did not fire exactly once.")
	if _drift_signal_count != 1:
		_failures.append("Death menu signal did not fire exactly once after landing.")

	hylas.queue_free()
	await process_frame
	_finish()


func _on_death_menu_signal() -> void:
	_drift_signal_count += 1


func _on_death_landed() -> void:
	_landed_signal_count += 1


func _finish() -> void:
	if _failures.is_empty():
		print("DEATH_MENU_LANDING_VALIDATION_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("DEATH_MENU_LANDING_VALIDATION_FAILED count=%d" % _failures.size())
	quit(1)
