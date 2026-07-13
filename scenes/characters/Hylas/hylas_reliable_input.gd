extends "res://scenes/characters/Hylas/hylas_land_controller.gd"

## Owns the timing-sensitive Space input rules. A single Space press uses the
## nearby interaction, while a second press inside the short window ignores the
## interaction and fires the conch. Shift+Space remains reserved for Tail Flip.

signal interaction_requested
signal interaction_availability_changed(is_available: bool)

@export_range(0.0, 200.0, 1.0) var brake_minimum_speed: float = 5.0
@export_range(0.05, 0.5, 0.01) var interaction_double_tap_window: float = 0.20

var _shift_space_tail_flip_requested: bool = false
var _tail_flip_chord_active: bool = false
var _space_action_pressed_this_frame: bool = false
var _interaction_available: bool = false
var _pending_interaction_remaining: float = 0.0


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

	var shift_is_held: bool = (
		key_event.shift_pressed
		or Input.is_action_pressed(&"action_a")
		or Input.is_key_pressed(KEY_SHIFT)
	)
	if shift_is_held:
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	_space_action_pressed_this_frame = true


func _physics_process(delta: float) -> void:
	_tail_flip_chord_active = _shift_space_tail_flip_requested
	_shift_space_tail_flip_requested = false

	if _tail_flip_chord_active:
		_brake_active = false
		_pending_conch_remaining = 0.0
		_pending_interaction_remaining = 0.0
		if (
			not _burst_active
			and _tail_flip_remaining <= 0.0
			and _conch_remaining <= 0.0
			and _jump_elapsed <= 0.0
			and _tail_flip_cooldown_remaining <= 0.0
		):
			_start_tail_flip()

	super._physics_process(delta)
	_update_pending_interaction(delta)
	_space_action_pressed_this_frame = false
	_tail_flip_chord_active = false


func set_interaction_available(is_available: bool) -> void:
	if _interaction_available == is_available:
		return
	_interaction_available = is_available
	if not _interaction_available:
		_pending_interaction_remaining = 0.0
	interaction_availability_changed.emit(_interaction_available)


func is_interaction_available() -> bool:
	return _interaction_available


func cancel_pending_interaction() -> void:
	_pending_interaction_remaining = 0.0


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

	# J and other direct conch bindings bypass interaction routing. Only the raw
	# Space press recorded in _input() participates in this single/double rule.
	if not _space_action_pressed_this_frame or not _interaction_available:
		super._handle_conch_pressed(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		super._handle_conch_pressed(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window


func _update_pending_interaction(delta: float) -> void:
	if _pending_interaction_remaining <= 0.0:
		return
	_pending_interaction_remaining = maxf(0.0, _pending_interaction_remaining - delta)
	if _pending_interaction_remaining <= 0.0 and _interaction_available:
		interaction_requested.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("tail_flip_remaining=%.2f" % _tail_flip_remaining)
	lines.append("tail_flip_chord_active=%s" % str(_tail_flip_chord_active))
	lines.append("brakeable_motion=%s" % str(_has_brakeable_motion()))
	lines.append("interaction_available=%s" % str(_interaction_available))
	lines.append("pending_interaction=%.2f" % _pending_interaction_remaining)
	return lines
