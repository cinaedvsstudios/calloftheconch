extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller.gd"

## Adds Escape-to-skip behaviour for an active Lykos/cuttlefish tutorial
## sequence without changing the consolidated tutorial controller.


func _input(event: InputEvent) -> void:
	if _is_escape_skip_event(event):
		get_viewport().set_input_as_handled()
		_skip_current_dialogue_sequence()
		return
	super._input(event)


func _is_escape_skip_event(event: InputEvent) -> bool:
	if event == null or not _active or not _can_escape_skip_sequence():
		return false
	if InputMap.has_action(&"ui_cancel") and event.is_action_pressed(&"ui_cancel", false, true):
		return true
	var key_event: InputEventKey = event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE


func _can_escape_skip_sequence() -> bool:
	return (
		_state == State.ENTERING
		or _state == State.PRE_HINT
		or _state == State.REVEALING
		or _state == State.SHOWING
		or _state == State.HIDING
	)


func _skip_current_dialogue_sequence() -> void:
	if not _can_escape_skip_sequence():
		return

	_startup_intro_pending = false
	_kill_hint_tween()

	if is_instance_valid(_ink_sound):
		_ink_sound.stop()
	if is_instance_valid(_tooltip_sound):
		_tooltip_sound.stop()

	# Treat a skipped one-shot sequence as complete so Escape cannot make the same
	# Lykos dialogue immediately reopen while Hylas is still in the trigger area.
	if _current_definition != null and _current_definition.show_only_once:
		_mark_hint_completed(_current_definition)

	# Non-one-shot trigger hints are also consumed for this pass. This prevents the
	# exact same trigger from rearming beneath Hylas and reopening instantly.
	if is_instance_valid(_current_trigger):
		_current_trigger.mark_consumed()
		_current_trigger = null

	_awaiting_page_advance = false
	_inline_ellipsis_visible = false
	_current_page_plain_text = ""
	_intro_pages.clear()
	_intro_page_index = 0
	_hide_advance_dots()

	if is_instance_valid(_hint_label):
		_hint_label.visible_characters = 0
	_set_text_reveal(0.0)

	if is_instance_valid(_hint_anchor):
		_hint_anchor.hide()
	if is_instance_valid(_ink_video):
		_ink_video.stop()
		_ink_video.hide()

	_ink_position_locked = false
	_set_conch_input_suppressed(false)
	_begin_exit()
