extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller.gd"

## Adds the automatic first-game greeting, presentation polish and tooltip toggle.

const INTRO_HINT_ID: StringName = &"intro_welcome"
const INTRO_PLAYTIME_LIMIT: float = 1.0

@export_group("Typewriter Text")
@export_range(8.0, 80.0, 1.0) var typewriter_characters_per_second: float = 28.0
@export_range(0.1, 3.0, 0.1) var intro_page_pause: float = 1.1
@export_range(0.05, 1.0, 0.05) var page_transition_duration: float = 0.3

@onready var _ink_sound: AudioStreamPlayer = %InkSound
@onready var _tooltip_sound: AudioStreamPlayer = %TooltipSound
@onready var _lykos_overlay: AnimatedSprite2D = %LykosOverlay

var _tooltips_enabled: bool = true


func _process(delta: float) -> void:
	super._process(delta)
	_sync_lykos_overlay()


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
	if not _cuttlefish.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cuttlefish_screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	# The enlarged ink opens behind Lykos, with the centred text kept to his left.
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


func _reveal_hint() -> void:
	if _current_definition == null:
		_begin_exit()
		return

	var pages: Array[String] = _get_current_hint_pages()
	if pages.is_empty():
		_begin_exit()
		return

	_begin_lykos_overlay()
	_kill_hint_tween()
	_set_typewriter_page(pages[0])
	_set_text_reveal(1.0)
	_set_ink_opacity(0.0)
	_update_hint_anchor_position()

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
	_hint_tween.parallel().tween_method(_set_ink_opacity, 0.0, 1.0, ink_appear_duration)

	for page_index: int in range(pages.size()):
		var page_text: String = pages[page_index]
		if page_index > 0:
			_hint_tween.tween_method(
				_set_text_reveal,
				1.0,
				0.0,
				page_transition_duration,
			)
			_hint_tween.tween_callback(_set_typewriter_page.bind(page_text))
		_hint_tween.tween_callback(_play_tooltip_sound)
		var type_duration: float = maxf(
			0.05,
			float(page_text.length()) / maxf(typewriter_characters_per_second, 1.0),
		)
		_hint_tween.tween_method(
			_set_visible_character_count,
			0.0,
			float(page_text.length()),
			type_duration,
		)
		if page_index < pages.size() - 1:
			_hint_tween.tween_interval(intro_page_pause)

	_hint_tween.tween_callback(_on_typewriter_complete)


func _get_current_hint_pages() -> Array[String]:
	var pages: Array[String] = []
	if _current_definition == null:
		return pages
	var split_pages: PackedStringArray = _current_definition.text.split("\n\n", false)
	for page: String in split_pages:
		var cleaned_page: String = page.strip_edges()
		if not cleaned_page.is_empty():
			pages.append(cleaned_page)
	return pages


func _set_typewriter_page(page_text: String) -> void:
	_hint_label.text = page_text
	_hint_label.visible_characters = 0
	_set_text_reveal(1.0)


func _set_visible_character_count(value: float) -> void:
	var maximum_characters: int = _hint_label.text.length()
	_hint_label.visible_characters = clampi(roundi(value), 0, maximum_characters)


func _on_typewriter_complete() -> void:
	if _state != State.REVEALING:
		return
	_hint_label.visible_characters = -1
	_set_text_reveal(1.0)
	_on_hint_revealed()


func _begin_exit() -> void:
	_end_lykos_overlay()
	super._begin_exit()


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
