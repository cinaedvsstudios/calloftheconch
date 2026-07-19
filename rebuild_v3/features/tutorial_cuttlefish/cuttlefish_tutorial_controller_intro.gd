extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller.gd"

## Adds the automatic first-game greeting, presentation polish and tooltip toggle.

const INTRO_HINT_ID: StringName = &"intro_welcome"
const INTRO_PLAYTIME_LIMIT: float = 1.0

@onready var _ink_sound: AudioStreamPlayer = %InkSound
@onready var _tooltip_sound: AudioStreamPlayer = %TooltipSound

var _tooltips_enabled: bool = true
var _tooltip_sound_tween: Tween


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
	# The ink opens between Lykos and Hylas while the text remains centred in it.
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
		super._reveal_hint()
		return
	_stop_tooltip_sound_tween()
	_ink_sound.stop()
	_ink_sound.play()
	super._reveal_hint()
	if _state != State.REVEALING:
		return
	_tooltip_sound_tween = create_tween()
	_tooltip_sound_tween.tween_interval(ink_appear_duration)
	_tooltip_sound_tween.tween_callback(_play_tooltip_sound)


func _play_tooltip_sound() -> void:
	if not _tooltips_enabled or not _active or _state != State.REVEALING:
		return
	_tooltip_sound.stop()
	_tooltip_sound.play()


func _stop_tooltip_sound_tween() -> void:
	if _tooltip_sound_tween != null and _tooltip_sound_tween.is_valid():
		_tooltip_sound_tween.kill()
	_tooltip_sound_tween = null


func _cancel_presentation() -> void:
	_stop_tooltip_sound_tween()
	if is_instance_valid(_ink_sound):
		_ink_sound.stop()
	if is_instance_valid(_tooltip_sound):
		_tooltip_sound.stop()
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
	_sprite.flip_h = true
	_sprite.play(&"pre_hint")
	_state = State.PRE_HINT
	hint_started.emit(definition.hint_id)
