extends "res://rebuild_v3/features/hylas/hylas_land_controller.gd"

## Captures the exact requested chord: hold Shift, then press Space.
## The chord remains locked for the whole physics frame so neither the normal
## Shift brake nor the Space conch action can cancel or replace Tail Flip.

@export_range(0.0, 200.0, 1.0) var brake_minimum_speed: float = 5.0

var _shift_space_tail_flip_requested: bool = false
var _tail_flip_chord_active: bool = false


func _input(event: InputEvent) -> void:
	if not _play_enabled or crawl_active or airborne_active:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var is_space: bool = (
		key_event.keycode == KEY_SPACE
		or key_event.physical_keycode == KEY_SPACE
		or key_event.unicode == 32
	)
	if not is_space:
		return

	# Shift must already be held when the Space key-down event arrives. Check
	# both the event modifier and the current Shift action so left/right Shift
	# and keyboard-layout differences cannot prevent the chord.
	var shift_is_held: bool = key_event.shift_pressed or Input.is_action_pressed(&"action_a") or Input.is_key_pressed(KEY_SHIFT)
	if not shift_is_held:
		return

	_shift_space_tail_flip_requested = true
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_tail_flip_chord_active = _shift_space_tail_flip_requested
	_shift_space_tail_flip_requested = false

	if _tail_flip_chord_active:
		_brake_active = false
		_pending_conch_remaining = 0.0
		if (
			not _burst_active
			and _tail_flip_remaining <= 0.0
			and _conch_remaining <= 0.0
			and _jump_elapsed <= 0.0
			and _tail_flip_cooldown_remaining <= 0.0
		):
			_start_tail_flip()

	super._physics_process(delta)
	_tail_flip_chord_active = false


func _is_braking(input_direction: Vector2) -> bool:
	if _tail_flip_chord_active or _tail_flip_remaining > 0.0:
		return false
	if not _has_brakeable_motion():
		return false
	return super._is_braking(input_direction)


func _has_brakeable_motion() -> bool:
	if _burst_active:
		return true
	var controlled_motion: Vector2 = _swim_velocity + _burst_coast_velocity + _special_velocity
	return controlled_motion.length() >= brake_minimum_speed


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active:
		return
	super._handle_conch_pressed(input_direction)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("tail_flip_remaining=%.2f" % _tail_flip_remaining)
	lines.append("tail_flip_chord_active=%s" % str(_tail_flip_chord_active))
	lines.append("brakeable_motion=%s" % str(_has_brakeable_motion()))
	return lines
