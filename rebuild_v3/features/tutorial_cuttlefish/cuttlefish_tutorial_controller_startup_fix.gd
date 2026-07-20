extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller_intro.gd"

## Corrects startup dialogue typewriter sequencing and manual Space paging.


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("intro_page=%d/%d" % [_intro_page_index + 1, _intro_pages.size()])
	lines.append("awaiting_space=%s" % str(_awaiting_page_advance))
	return lines


func _begin_current_page_typewriter() -> void:
	if _state != State.REVEALING or _intro_page_index >= _intro_pages.size():
		return
	_set_typewriter_page(_intro_pages[_intro_page_index])
	_hide_advance_dots()
	_play_tooltip_sound()
	var page_text: String = _intro_pages[_intro_page_index]
	var type_duration: float = maxf(
		0.05,
		float(page_text.length()) / maxf(typewriter_characters_per_second, 1.0),
	)

	# The ink tween invokes this method from its final callback. Reusing that
	# already-running tween leaves visible_characters at zero, so the text never
	# appears. The typewriter must always own a fresh tween.
	_hint_tween = create_tween()
	_hint_tween.tween_method(
		_set_visible_character_count,
		0.0,
		float(page_text.length()),
		type_duration,
	)
	_hint_tween.tween_callback(_on_page_typewriter_complete)


func _on_page_typewriter_complete() -> void:
	if _state != State.REVEALING:
		return
	_hint_label.visible_characters = -1
	_set_text_reveal(1.0)
	var has_more_pages: bool = _intro_page_index < _intro_pages.size() - 1
	if has_more_pages or _is_startup_greeting():
		_awaiting_page_advance = true
		_show_advance_dots()
		return
	_on_hint_revealed()


func _advance_to_next_page() -> void:
	if not _awaiting_page_advance:
		return
	_awaiting_page_advance = false
	_hide_advance_dots()

	if _intro_page_index >= _intro_pages.size() - 1:
		if _is_startup_greeting():
			_begin_hide_hint()
		else:
			_on_hint_revealed()
		return

	_intro_page_index += 1
	_kill_hint_tween()
	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_OUT)
	_hint_tween.tween_method(_set_text_reveal, 1.0, 0.0, page_transition_duration)
	_hint_tween.tween_callback(_begin_current_page_typewriter)


func _is_startup_greeting() -> bool:
	return _current_definition != null and _current_definition.hint_id == INTRO_HINT_ID
