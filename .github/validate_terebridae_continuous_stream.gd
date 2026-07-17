extends SceneTree

const CONCH_PULSE_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/conch_pulse.tscn"
)

var _started_count: int = 0


func _init() -> void:
	call_deferred(&"_run_validation")


func _on_pulse_started(_pulse_index: int) -> void:
	_started_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run_validation() -> void:
	var pulse: Node = CONCH_PULSE_SCENE.instantiate()
	root.add_child(pulse)
	await process_frame

	pulse.connect(&"pulse_wave_started", Callable(self, "_on_pulse_started"))
	pulse.call(
		&"trigger_profile_from_player",
		Vector2(100.0, 100.0),
		Vector2.RIGHT,
		Vector2(100.0, 100.0),
		{
			"arc_degrees": 18.0,
			"pulse_interval_scale": 0.48,
			"stream_duration": 5.0,
		},
	)
	pulse.set_process(false)
	for _step: int in range(110):
		pulse.call(&"_process", 0.05)

	var continuous_count: int = _started_count
	if continuous_count < 80 or continuous_count > 110:
		_fail(
			"Expected a dense five-second Terebridae stream; got %d pulse starts."
			% continuous_count
		)
		return
	if bool(pulse.get("_sequence_active")):
		_fail("Terebridae stream remained active after its final pulses faded.")
		return

	_started_count = 0
	pulse.call(
		&"trigger_profile_from_player",
		Vector2(100.0, 100.0),
		Vector2.RIGHT,
		Vector2(100.0, 100.0),
		{},
	)
	pulse.set_process(false)
	for _step: int in range(50):
		pulse.call(&"_process", 0.05)

	if _started_count != 6:
		_fail(
			"Fixed conch profile changed unexpectedly; expected 6 pulses and got %d."
			% _started_count
		)
		return

	pulse.call(&"stop")
	pulse.queue_free()
	print(
		"Terebridae continuous stream validation passed: %d continuous pulses, 6 fixed pulses."
		% continuous_count
	)
	quit(0)
