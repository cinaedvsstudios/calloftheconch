extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller.gd"

## Adds the automatic first-game greeting, presentation polish and tooltip toggle.

const INTRO_HINT_ID: StringName = &"intro_welcome"
const INTRO_PLAYTIME_LIMIT: float = 1.0

@export_group("Typewriter Text")
@export_range(8.0, 80.0, 1.0) var typewriter_characters_per_second: float = 28.0
@export_range(0.1, 3.0, 0.1) var intro_page_pause: float = 1.1
@export_range(0.05, 1.0, 0.05) var page_transition_duration: float = 0.3
@export_range(0.5, 1.0, 0.01) var ink_max_opacity: float = 0.90
@export_range(8, 40, 1) var max_characters_per_line: int = 22
@export_range(1, 8, 1) var max_lines_per_page: int = 4

var _tooltips_enabled: bool = true
var _intro_pages: Array[String] = []
var _intro_page_index: int = 0
var _awaiting_page_advance: bool = false
var _advance_dots_elapsed: float = 0.0
var _current_page_plain_text: String = ""
var _inline_ellipsis_visible: bool = false
var _ink_position_locked: bool = false
var _conch_input_suppressed: bool = false
var _saved_conch_input_events: Array[InputEvent] = []

@onready var _ink_sound: AudioStreamPlayer = %InkSound
@onready var _tooltip_sound: AudioStreamPlayer = %TooltipSound
@onready var _lykos_overlay: AnimatedSprite2D = %LykosOverlay
@onready var _advance_dots: Label = %AdvanceDots


func _process(delta: float) -> void:
	super._process(delta)
	_sync_lykos_overlay()
	if _awaiting_page_advance:
		_advance_dots_elapsed += maxf(delta, 0.0)
		var show_inline_ellipsis: bool = fmod(_advance_dots_elapsed, 0.8) < 0.4
		if show_inline_ellipsis != _inline_ellipsis_visible:
			_inline_ellipsis_visible = show_inline_ellipsis
			_refresh_waiting_page_text()


func _input(event: InputEvent) -> void:
	if not _awaiting_page_advance or not _active or _state != State.REVEALING:
		return
	if not event.is_action_pressed(&"ui_accept", false, true):
		return
	get_viewport().set_input_as_handled()
	_advance_to_next_page()


func activate() -> void:
	super.activate()
	_apply_trigger_monitoring()
	if _tooltips_enabled:
		_start_intro_if_possible()


func refresh_triggers() -> void:
	super.refresh_triggers()
	_apply_trigger_monitoring()


func set_tooltips_enabled(enabled: bool) -> void:
	if _tooltips_enabled == enabled:
		return
	_tooltips_enabled = enabled
	if not enabled:
		_cancel_presentation()
	_apply_trigger_monitoring()
	if enabled and _active:
		_start_intro_if_possible()
		_start_next_hint_if_possible()


func are_tooltips_enabled() -> bool:
	return _tooltips_enabled


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("intro_page=%d/%d" % [_intro_page_index + 1, _intro_pages.size()])
	lines.append("awaiting_space=%s" % str(_awaiting_page_advance))
	return lines


func _on_hint_requested(trigger: CotcTutorialHintTrigger) -> void:
	if not _tooltips_enabled:
		return
	super._on_hint_requested(trigger)


func _apply_trigger_monitoring() -> void:
	for trigger: CotcTutorialHintTrigger in _connected_triggers:
		if not is_instance_valid(trigger):
			continue
		var should_monitor: bool = _tooltips_enabled and not trigger.is_claimed()
		trigger.set_deferred(&"monitoring", should_monitor)


func _process_entry(delta: float) -> void:
	super._process_entry(delta)
	if _state == State.PRE_HINT:
		# Lykos hovers to Hylas's right and turns back toward him.
		_sprite.flip_h = true


func _follow_hylas(delta: float) -> void:
	super._follow_hylas(delta)
	if _state != State.EXITING:
		_sprite.flip_h = true


func _get_hover_target() -> Vector2:
	if not is_instance_valid(_hylas):
		return _cuttlefish.global_position
	var world_rect: Rect2 = _get_visible_world_rect()
	var bob_offset: float = sin(_bob_time * TAU * hover_bob_frequency) * hover_bob_amplitude
	var target: Vector2 = _hylas.global_position + Vector2(
		hover_horizontal_offset,
		-hover_vertical_offset + bob_offset,
	)
	var minimum_x: float = world_rect.position.x + world_screen_margin
	var maximum_x: float = maxf(minimum_x, world_rect.end.x - world_screen_margin)
	var minimum_y: float = world_rect.position.y + world_screen_margin
	var maximum_y: float = maxf(minimum_y, world_rect.end.y - world_screen_margin)
	target.x = clampf(target.x, minimum_x, maximum_x)
	target.y = clampf(target.y, minimum_y, maximum_y)
	return target


func _update_hint_anchor_position() -> void:
	if _ink_position_locked:
		return
	if not _cuttlefish.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cuttlefish_screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	# The enlarged ink opens behind Lykos, with the dialogue centred inside it.
	var desired_center: Vector2 = cuttlefish_screen_position + Vector2(
		-hint_screen_horizontal_offset,
		hint_screen_vertical_offset,
	)
	var presentation_scale: float = 1.0
	if _current_definition != null:
		presentation_scale = _current_definition.ink_scale
	var scaled_half_size: Vector2 = _hint_anchor.size * presentation_scale * 0.5
	var minimum_center: Vector2 = Vector2.ONE * hint_screen_margin + scaled_half_size
	var maximum_center: Vector2 = viewport_size - Vector2.ONE * hint_screen_margin - scaled_half_size
	maximum_center.x = maxf(maximum_center.x, minimum_center.x)
	maximum_center.y = maxf(maximum_center.y, minimum_center.y)
	desired_center.x = clampf(desired_center.x, minimum_center.x, maximum_center.x)
	desired_center.y = clampf(desired_center.y, minimum_center.y, maximum_center.y)
	_hint_anchor.position = desired_center - _hint_anchor.size * 0.5
	_sync_hint_text_layout()


func _reveal_hint() -> void:
	if _current_definition == null:
		_begin_exit()
		return

	_set_conch_input_suppressed(true)
	_ink_position_locked = false
	_intro_pages = _get_current_hint_pages()
	_intro_page_index = 0
	_awaiting_page_advance = false
	if _intro_pages.is_empty():
		_begin_exit()
		return

	_begin_lykos_overlay()
	_kill_hint_tween()
	_set_typewriter_page(_intro_pages[0])
	_hide_advance_dots()
	_set_text_reveal(1.0)
	_set_ink_opacity(0.0)
	_update_hint_anchor_position()
	_ink_position_locked = true

	var final_scale: Vector2 = Vector2.ONE * _current_definition.ink_scale
	_hint_anchor.scale = final_scale * 0.05
	_hint_anchor.show()
	if _ink_video_available and _ink_video.stream != null:
		_ink_video.show()
		_ink_video.play()
	else:
		_ink_video.hide()

	_state = State.REVEALING
	_ink_sound.stop()
	_ink_sound.play()

	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_OUT)
	_hint_tween.tween_property(_hint_anchor, "scale", final_scale, ink_appear_duration)
	_hint_tween.parallel().tween_method(_set_ink_opacity, 0.0, ink_max_opacity, ink_appear_duration)

	_hint_tween.tween_callback(_begin_current_page_typewriter)


func _get_current_hint_pages() -> Array[String]:
	var pages: Array[String] = []
	if _current_definition == null:
		return pages

	var source_text: String = _current_definition.text.replace("\r", "")
	var forced_sections: PackedStringArray = source_text.split("[[page]]", true)
	for forced_section: String in forced_sections:
		var cleaned_section: String = forced_section.strip_edges()
		if cleaned_section.is_empty():
			continue
		pages.append_array(_paginate_text_section(cleaned_section))

	return pages


func _paginate_text_section(source_text: String) -> Array[String]:
	var pages: Array[String] = []
	var current_page_lines: Array[String] = []
	var sentences: Array[String] = _split_sentences(source_text)

	for sentence: String in sentences:
		var sentence_lines: Array[String] = _wrap_text_lines(sentence)
		if sentence_lines.is_empty():
			continue

		# A sentence that cannot fit on one page is the only case where a page
		# may end before the sentence itself ends.
		if sentence_lines.size() > max_lines_per_page:
			if not current_page_lines.is_empty():
				pages.append("\n".join(current_page_lines))
				current_page_lines.clear()
			var line_index: int = 0
			while line_index < sentence_lines.size():
				var page_chunk: Array[String] = []
				var chunk_end: int = mini(
					line_index + max_lines_per_page,
					sentence_lines.size(),
				)
				for chunk_index: int in range(line_index, chunk_end):
					page_chunk.append(sentence_lines[chunk_index])
				pages.append("\n".join(page_chunk))
				line_index = chunk_end
			continue

		# Keep complete sentences together. When the next sentence would exceed
		# four lines, finish the current page at the previous sentence.
		if (
				not current_page_lines.is_empty()
				and current_page_lines.size() + sentence_lines.size() > max_lines_per_page
			):
			pages.append("\n".join(current_page_lines))
			current_page_lines.clear()

		current_page_lines.append_array(sentence_lines)

	if not current_page_lines.is_empty():
		pages.append("\n".join(current_page_lines))

	return pages


func _split_sentences(source_text: String) -> Array[String]:
	var sentences: Array[String] = []
	var normalized_words: PackedStringArray = source_text.replace("\n", " ").split(" ", false)
	var normalized_text: String = " ".join(normalized_words)
	var current_sentence: String = ""

	for character_index: int in range(normalized_text.length()):
		var character: String = normalized_text.substr(character_index, 1)
		current_sentence += character
		if character != "." and character != "!" and character != "?":
			continue
		var is_text_end: bool = character_index >= normalized_text.length() - 1
		var next_is_space: bool = (
			not is_text_end
			and normalized_text.substr(character_index + 1, 1) == " "
		)
		if is_text_end or next_is_space:
			var completed_sentence: String = current_sentence.strip_edges()
			if not completed_sentence.is_empty():
				sentences.append(completed_sentence)
			current_sentence = ""

	var remaining_text: String = current_sentence.strip_edges()
	if not remaining_text.is_empty():
		sentences.append(remaining_text)

	return sentences


func _wrap_text_lines(source_text: String) -> Array[String]:
	var lines: Array[String] = []
	var words: PackedStringArray = source_text.replace("\n", " ").split(" ", false)
	var current_line: String = ""

	for raw_word: String in words:
		var word: String = raw_word.strip_edges()
		if word.is_empty():
			continue

		if current_line.is_empty():
			while word.length() > max_characters_per_line:
				lines.append(word.substr(0, max_characters_per_line))
				word = word.substr(max_characters_per_line)
			current_line = word
			continue

		var candidate_line: String = current_line + " " + word
		if candidate_line.length() <= max_characters_per_line:
			current_line = candidate_line
			continue

		lines.append(current_line)
		current_line = ""
		while word.length() > max_characters_per_line:
			lines.append(word.substr(0, max_characters_per_line))
			word = word.substr(max_characters_per_line)
		current_line = word

	if not current_line.is_empty():
		lines.append(current_line)

	return lines


func _set_typewriter_page(page_text: String) -> void:
	_current_page_plain_text = page_text
	_hint_label.text = page_text
	_hint_label.visible_characters = 0
	_set_text_reveal(1.0)
	_sync_hint_text_layout()


func _set_visible_character_count(value: float) -> void:
	var maximum_characters: int = _hint_label.text.length()
	_hint_label.visible_characters = clampi(roundi(value), 0, maximum_characters)


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


func _show_advance_dots() -> void:
	_advance_dots_elapsed = 0.0
	_inline_ellipsis_visible = true
	if is_instance_valid(_advance_dots):
		_advance_dots.hide()
	_refresh_waiting_page_text()


func _hide_advance_dots() -> void:
	_inline_ellipsis_visible = false
	if is_instance_valid(_advance_dots):
		_advance_dots.hide()
	_refresh_waiting_page_text()


func _refresh_waiting_page_text() -> void:
	if not is_instance_valid(_hint_label):
		return
	if _current_page_plain_text.is_empty():
		return
	if _awaiting_page_advance and _inline_ellipsis_visible:
		_hint_label.text = _current_page_plain_text + "..."
	else:
		_hint_label.text = _current_page_plain_text
	_hint_label.visible_characters = -1


func _sync_hint_text_layout() -> void:
	if not is_instance_valid(_hint_label) or not is_instance_valid(_ink_video):
		return
	var padding: Vector2 = Vector2(60.0, 40.0)
	var target_position: Vector2 = _ink_video.position + padding
	var target_size: Vector2 = _ink_video.size - padding * 2.0
	target_size.x = maxf(target_size.x, 160.0)
	target_size.y = maxf(target_size.y, 96.0)
	_hint_label.position = target_position
	_hint_label.size = target_size


func _begin_hide_hint() -> void:
	if _state == State.HIDING or _state == State.EXITING:
		return
	_state = State.HIDING
	_awaiting_page_advance = false
	_inline_ellipsis_visible = false
	_refresh_waiting_page_text()
	_kill_hint_tween()
	var hidden_scale: Vector2 = _hint_anchor.scale * 0.05
	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_IN)
	_hint_tween.tween_method(_set_text_reveal, 1.0, 0.0, text_hide_duration)
	_hint_tween.tween_property(_hint_anchor, "scale", hidden_scale, ink_hide_duration)
	_hint_tween.parallel().tween_method(_set_ink_opacity, ink_max_opacity, 0.0, ink_hide_duration)
	_hint_tween.tween_callback(_on_hint_hidden)


func _begin_exit() -> void:
	_ink_position_locked = false
	_set_conch_input_suppressed(false)
	_end_lykos_overlay()
	super._begin_exit()


func _set_conch_input_suppressed(suppressed: bool) -> void:
	if _conch_input_suppressed == suppressed:
		return
	_conch_input_suppressed = suppressed
	if not InputMap.has_action(&"conch"):
		return

	if suppressed:
		_saved_conch_input_events.clear()
		for input_event: InputEvent in InputMap.action_get_events(&"conch"):
			_saved_conch_input_events.append(input_event)
		InputMap.action_erase_events(&"conch")
		Input.action_release(&"conch")
		return

	InputMap.action_erase_events(&"conch")
	for input_event: InputEvent in _saved_conch_input_events:
		InputMap.action_add_event(&"conch", input_event)
	_saved_conch_input_events.clear()
	Input.action_release(&"conch")


func _play_tooltip_sound() -> void:
	if not _tooltips_enabled or not _active or _state != State.REVEALING:
		return
	_tooltip_sound.stop()
	_tooltip_sound.play()


func _begin_lykos_overlay() -> void:
	if not is_instance_valid(_lykos_overlay) or not is_instance_valid(_sprite):
		return
	_sprite.hide()
	_lykos_overlay.flip_h = true
	_lykos_overlay.play(&"swim")
	_sync_lykos_overlay()
	_lykos_overlay.show()


func _sync_lykos_overlay() -> void:
	if not is_instance_valid(_lykos_overlay) or not _lykos_overlay.visible:
		return
	if not is_instance_valid(_cuttlefish):
		return
	_lykos_overlay.position = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	_lykos_overlay.flip_h = true


func _end_lykos_overlay() -> void:
	if is_instance_valid(_lykos_overlay):
		_lykos_overlay.hide()
	if is_instance_valid(_sprite):
		_sprite.show()
		_sprite.flip_h = true
		_sprite.play(&"swim")


func _cancel_presentation() -> void:
	if is_instance_valid(_ink_sound):
		_ink_sound.stop()
	if is_instance_valid(_tooltip_sound):
		_tooltip_sound.stop()
	if is_instance_valid(_hint_label):
		_hint_label.visible_characters = 0
		_set_text_reveal(0.0)
	_awaiting_page_advance = false
	_ink_position_locked = false
	_set_conch_input_suppressed(false)
	_current_page_plain_text = ""
	_inline_ellipsis_visible = false
	_intro_pages.clear()
	_intro_page_index = 0
	_hide_advance_dots()
	_end_lykos_overlay()
	super._cancel_presentation()


func _start_intro_if_possible() -> void:
	if (
			not _tooltips_enabled
			or not _active
			or _state != State.IDLE
			or hint_library == null
		):
		return
	if _game_state == null or _game_state.playtime_seconds > INTRO_PLAYTIME_LIMIT:
		return

	var definition: CotcTutorialHintDefinition = hint_library.get_hint(INTRO_HINT_ID)
	if definition == null or not definition.is_valid_definition():
		push_warning("Cuttlefish intro hint is missing from the tutorial hint library.")
		return
	if _is_hint_completed(definition):
		return

	_resolve_hylas()
	_connect_hylas_signals()
	if not is_instance_valid(_hylas):
		return

	_current_trigger = null
	_current_definition = definition
	_current_side = CotcTutorialHintTrigger.EntrySide.RIGHT
	_show_elapsed = 0.0
	_required_action_completed = false
	_bob_time = 0.0

	# The opening greeting begins with Lykos beside Hylas, facing back toward him.
	_cuttlefish.global_position = _get_hover_target()
	_cuttlefish.show()
	_sprite.show()
	_sprite.flip_h = true
	_sprite.play(&"pre_hint")
	_state = State.PRE_HINT
	hint_started.emit(definition.hint_id)
