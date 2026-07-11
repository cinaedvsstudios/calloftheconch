extends "res://rebuild_v3/features/hylas/hylas_land_controller.gd"

## Captures Shift + Space from the actual keyboard event. This avoids relying
## on modifier matching between the separate Shift and Space input actions.

var _shift_space_tail_flip_requested: bool = false


func _input(event: InputEvent) -> void:
	if not _play_enabled or crawl_active or airborne_active:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var is_space: bool = key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE
	if not is_space:
		return
	if not key_event.shift_pressed and not Input.is_key_pressed(KEY_SHIFT):
		return
	_shift_space_tail_flip_requested = true
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _shift_space_tail_flip_requested:
		_shift_space_tail_flip_requested = false
		if not crawl_active and not airborne_active:
			_brake_active = false
			_pending_conch_remaining = 0.0
			_try_start_tail_flip_combo()
	super._physics_process(delta)


func _is_braking(input_direction: Vector2) -> bool:
	if _shift_space_tail_flip_requested or _tail_flip_remaining > 0.0:
		return false
	return super._is_braking(input_direction)
