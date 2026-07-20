class_name CotcCuttlefishTutorialController
extends Node

## Single controller for Lykos/cuttlefish arrival, editor-authored layout, ink video,
## dialogue paging, tooltip gating and one-shot completion.
##
## The scene is authoritative:
## - Change HintAnchor position/size to move/resize the ink video.
## - Change InkVideo.stream to swap the video.
## - Change InkVideo material opacity to set maximum runtime opacity.
## - Change HintText position/size to move/resize the text area.
## - Change Cuttlefish relative to HylasEditorAnchor to set Lykos hover position.
## - Cuttlefish is the only Lykos visual used at runtime; there is no separate overlay sprite.

signal hint_started(hint_id: StringName)
signal hint_finished(hint_id: StringName)

enum State {
	INACTIVE,
	IDLE,
	ENTERING,
	PRE_HINT,
	REVEALING,
	SHOWING,
	HIDING,
	EXITING,
}

const ACTION_TAIL_FLIP: StringName = &"tail_flip"
const ACTION_SPEED_RUN: StringName = &"speed_run"
const ACTION_CONCH: StringName = &"conch"
const INTRO_HINT_ID: StringName = &"intro_welcome"
const INTRO_PLAYTIME_LIMIT: float = 1.0

@export var hint_library: CotcTutorialHintLibrary

@export_group("Cuttlefish Movement")
@export_range(100.0, 1400.0, 10.0) var entry_speed: float = 360.0
@export_range(100.0, 1400.0, 10.0) var hover_follow_speed: float = 304.0
@export_range(40.0, 320.0, 5.0) var hover_horizontal_offset: float = 60.0
@export_range(20.0, 240.0, 5.0) var hover_vertical_offset: float = 35.0
@export_range(0.0, 40.0, 1.0) var hover_bob_amplitude: float = 4.0
@export_range(0.1, 5.0, 0.1) var hover_bob_frequency: float = 0.4
@export_range(4.0, 80.0, 1.0) var arrival_radius: float = 18.0
@export_range(40.0, 400.0, 5.0) var offscreen_margin: float = 190.0
@export_range(20.0, 180.0, 5.0) var world_screen_margin: float = 80.0

@export_group("Ink Hint Presentation")
@export_range(0.1, 2.0, 0.05) var ink_appear_duration: float = 0.6
@export_range(0.1, 2.0, 0.05) var text_reveal_duration: float = 0.8
@export_range(0.1, 2.0, 0.05) var text_hide_duration: float = 0.55
@export_range(0.1, 2.0, 0.05) var ink_hide_duration: float = 0.9
@export_range(0.0, 3.0, 0.05) var minimum_read_time: float = 3.0
@export_range(80.0, 420.0, 5.0) var hint_screen_horizontal_offset: float = 75.0
@export_range(-360.0, 120.0, 5.0) var hint_screen_vertical_offset: float = -85.0
@export_range(10.0, 120.0, 5.0) var hint_screen_margin: float = 36.0
@export_range(0.0, 1.0, 0.01) var ink_max_opacity: float = 0.65

@export_group("Typewriter Text")
@export_range(8.0, 80.0, 1.0) var typewriter_characters_per_second: float = 28.0
@export_range(0.1, 3.0, 0.1) var intro_page_pause: float = 1.1
@export_range(0.05, 1.0, 0.05) var page_transition_duration: float = 0.3
@export_range(8, 40, 1) var max_characters_per_line: int = 22
@export_range(1, 8, 1) var max_lines_per_page: int = 4

@export_group("Lykos Swimming Polish")
@export_range(0.0, 5.0, 0.1) var startup_intro_delay: float = 2.0
@export_range(0.0, 80.0, 1.0) var entry_exit_curve_amplitude: float = 28.0
@export_range(0.1, 3.0, 0.1) var entry_exit_curve_frequency: float = 0.7

@onready var _cuttlefish: Node2D = %Cuttlefish
@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _hint_anchor: Control = %HintAnchor
@onready var _ink_video: VideoStreamPlayer = %InkVideo
@onready var _hint_label: Label = %HintText
@onready var _ink_editor_preview: ColorRect = get_node_or_null("%InkEditorPreview") as ColorRect
@onready var _text_area_editor_preview: ColorRect = get_node_or_null("%TextAreaEditorPreview") as ColorRect
@onready var _hylas_editor_anchor: Marker2D = %HylasEditorAnchor
@onready var _ink_sound: AudioStreamPlayer = %InkSound
@onready var _tooltip_sound: AudioStreamPlayer = %TooltipSound
@onready var _advance_dots: Label = %AdvanceDots

var _game_state: CotcGameState
var _level: Node
var _hylas: CotcHylas
var _active: bool = false
var _state: State = State.INACTIVE
var _current_side: int = CotcTutorialHintTrigger.EntrySide.LEFT
var _current_trigger: CotcTutorialHintTrigger
var _current_definition: CotcTutorialHintDefinition
var _queued_triggers: Array[CotcTutorialHintTrigger] = []
var _connected_triggers: Array[CotcTutorialHintTrigger] = []
var _session_completed: Dictionary = {}
var _show_elapsed: float = 0.0
var _bob_time: float = 0.0
var _required_action_completed: bool = false
var _hint_tween: Tween
var _ink_video_available: bool = false
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
var _startup_intro_pending: bool = false
var _runtime_ink_max_opacity: float = 0.65

var _authored_hover_offset: Vector2 = Vector2(135.0, -35.0)
var _authored_hint_position: Vector2 = Vector2.ZERO
var _authored_hint_size: Vector2 = Vector2(900.0, 380.0)
var _authored_text_position: Vector2 = Vector2(60.0, 40.0)
var _authored_text_size: Vector2 = Vector2(780.0, 300.0)
var _authored_dots_position: Vector2 = Vector2(760.0, 305.0)
var _authored_dots_size: Vector2 = Vector2(80.0, 40.0)


func _ready() -> void:
	_capture_authored_editor_layout()
	_cuttlefish.hide()
	_hint_anchor.hide()
	_ink_video.hide()
	if _ink_editor_preview != null:
		_ink_editor_preview.hide()
	if _text_area_editor_preview != null:
		_text_area_editor_preview.hide()
	if is_instance_valid(_advance_dots):
		_advance_dots.hide()
	_hint_label.text = ""
	_sprite.show()
	_sprite.play(&"swim")
	if not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_runtime_ink_max_opacity = _read_scene_ink_opacity(ink_max_opacity)
	_update_hint_anchor_pivot()
	_sync_hint_text_layout()
	_configure_ink_video()
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_time += maxf(delta, 0.0)

	match _state:
		State.ENTERING:
			_process_entry(delta)
		State.PRE_HINT, State.REVEALING, State.SHOWING, State.HIDING:
			_follow_hylas(delta)
			if _state != State.PRE_HINT:
				_update_hint_anchor_position()
			if _state == State.SHOWING:
				_show_elapsed += maxf(delta, 0.0)
				if _should_dismiss_current_hint():
					_begin_hide_hint()
		State.EXITING:
			_process_exit(delta)

	if _awaiting_page_advance:
		_advance_dots_elapsed += maxf(delta, 0.0)
		var show_fixed_dots: bool = fmod(_advance_dots_elapsed, 0.8) < 0.4
		if show_fixed_dots != _inline_ellipsis_visible:
			_inline_ellipsis_visible = show_fixed_dots
			_refresh_waiting_page_text()


func _input(event: InputEvent) -> void:
	if not _awaiting_page_advance or not _active or _state != State.REVEALING:
		return
	if not event.is_action_pressed(&"ui_accept", false, true):
		return
	get_viewport().set_input_as_handled()
	_advance_to_next_page()


func bind_game_state(game_state: CotcGameState) -> void:
	_game_state = game_state


func bind_level(level: Node) -> void:
	_disconnect_trigger_signals()
	_disconnect_hylas_signals()
	_cancel_presentation()
	_level = level
	_hylas = null
	if is_inside_tree():
		call_deferred(&"_refresh_level_bindings")


func activate() -> void:
	_active = true
	_state = State.IDLE
	set_process(true)
	_refresh_level_bindings()
	_apply_trigger_monitoring()
	if _tooltips_enabled and _start_intro_if_possible():
		return
	_start_next_hint_if_possible()


func deactivate() -> void:
	_active = false
	_cancel_presentation()
	_state = State.INACTIVE
	set_process(false)


func refresh_triggers() -> void:
	_disconnect_trigger_signals()
	if _level == null or not is_instance_valid(_level):
		return

	var callback: Callable = Callable(self, "_on_hint_requested")
	for candidate: Node in get_tree().get_nodes_in_group(&"tutorial_hint_trigger"):
		var trigger: CotcTutorialHintTrigger = candidate as CotcTutorialHintTrigger
		if trigger == null or not _level.is_ancestor_of(trigger):
			continue
		_connected_triggers.append(trigger)
		if not trigger.hint_requested.is_connected(callback):
			trigger.hint_requested.connect(callback)
	_apply_trigger_monitoring()


func set_tooltips_enabled(enabled: bool) -> void:
	if _tooltips_enabled == enabled:
		return
	_tooltips_enabled = enabled
	if not enabled:
		_cancel_presentation()
	_apply_trigger_monitoring()
	if enabled and _active:
		if _start_intro_if_possible():
			return
		_start_next_hint_if_possible()


func are_tooltips_enabled() -> bool:
	return _tooltips_enabled


func get_debug_lines() -> Array[String]:
	return [
		"[CuttlefishTutorial]",
		"active=%s" % str(_active),
		"state=%d" % int(_state),
		"level_bound=%s" % str(is_instance_valid(_level)),
		"hylas_bound=%s" % str(is_instance_valid(_hylas)),
		"triggers=%d" % _connected_triggers.size(),
		"queued=%d" % _queued_triggers.size(),
		"current_hint=%s" % (
			String(_current_definition.hint_id) if _current_definition != null else ""
		),
		"ink_video_available=%s" % str(_ink_video_available),
		"intro_page=%d/%d" % [_intro_page_index + 1, _intro_pages.size()],
		"awaiting_space=%s" % str(_awaiting_page_advance),
		"startup_intro_pending=%s" % str(_startup_intro_pending),
		"authored_hover_offset=%s" % str(_authored_hover_offset),
		"authored_hint_position=%s" % str(_authored_hint_position),
		"authored_hint_size=%s" % str(_authored_hint_size),
	]


func _refresh_level_bindings() -> void:
	if _level == null or not is_instance_valid(_level):
		return
	_resolve_hylas()
	_connect_hylas_signals()
	refresh_triggers()


func _resolve_hylas() -> void:
	if is_instance_valid(_hylas):
		return
	for candidate: Node in get_tree().get_nodes_in_group(&"hylas"):
		if _level != null and not _level.is_ancestor_of(candidate):
			continue
		_hylas = candidate as CotcHylas
		if is_instance_valid(_hylas):
			return


func _connect_hylas_signals() -> void:
	if not is_instance_valid(_hylas):
		return
	if not _hylas.tail_flip_started.is_connected(_on_hylas_tail_flip_started):
		_hylas.tail_flip_started.connect(_on_hylas_tail_flip_started)
	if not _hylas.burst_started.is_connected(_on_hylas_burst_started):
		_hylas.burst_started.connect(_on_hylas_burst_started)
	if not _hylas.normal_conch_used.is_connected(_on_hylas_conch_used):
		_hylas.normal_conch_used.connect(_on_hylas_conch_used)


func _disconnect_hylas_signals() -> void:
	if not is_instance_valid(_hylas):
		return
	if _hylas.tail_flip_started.is_connected(_on_hylas_tail_flip_started):
		_hylas.tail_flip_started.disconnect(_on_hylas_tail_flip_started)
	if _hylas.burst_started.is_connected(_on_hylas_burst_started):
		_hylas.burst_started.disconnect(_on_hylas_burst_started)
	if _hylas.normal_conch_used.is_connected(_on_hylas_conch_used):
		_hylas.normal_conch_used.disconnect(_on_hylas_conch_used)


func _disconnect_trigger_signals() -> void:
	var callback: Callable = Callable(self, "_on_hint_requested")
	for trigger: CotcTutorialHintTrigger in _connected_triggers:
		if is_instance_valid(trigger) and trigger.hint_requested.is_connected(callback):
			trigger.hint_requested.disconnect(callback)
	_connected_triggers.clear()


func _on_hint_requested(trigger: CotcTutorialHintTrigger) -> void:
	if not _tooltips_enabled or not _active or trigger == null or hint_library == null:
		return
	var definition: CotcTutorialHintDefinition = hint_library.get_hint(trigger.hint_id)
	if definition == null or not definition.is_valid_definition():
		push_warning("Tutorial trigger requested unknown hint '%s'." % String(trigger.hint_id))
		return
	if _is_hint_completed(definition):
		trigger.mark_consumed()
		return
	if trigger == _current_trigger or _queued_triggers.has(trigger):
		return
	trigger.set_claimed(true)
	_queued_triggers.append(trigger)
	_start_next_hint_if_possible()


func _start_next_hint_if_possible() -> void:
	if _startup_intro_pending:
		return
	if not _active or _state != State.IDLE or _queued_triggers.is_empty():
		return
	_resolve_hylas()
	_connect_hylas_signals()
	if not is_instance_valid(_hylas):
		return

	var trigger: CotcTutorialHintTrigger = _queued_triggers.pop_front() as CotcTutorialHintTrigger
	if trigger == null or not is_instance_valid(trigger):
		call_deferred(&"_start_next_hint_if_possible")
		return
	var definition: CotcTutorialHintDefinition = hint_library.get_hint(trigger.hint_id)
	if definition == null or not definition.is_valid_definition():
		trigger.rearm()
		call_deferred(&"_start_next_hint_if_possible")
		return
	if _is_hint_completed(definition):
		trigger.mark_consumed()
		call_deferred(&"_start_next_hint_if_possible")
		return

	_current_trigger = trigger
	_current_definition = definition
	_current_side = _resolve_entry_side(trigger.entry_side)
	_show_elapsed = 0.0
	_required_action_completed = false
	_bob_time = 0.0
	_spawn_cuttlefish()
	_state = State.ENTERING
	hint_started.emit(definition.hint_id)


func _apply_trigger_monitoring() -> void:
	for trigger: CotcTutorialHintTrigger in _connected_triggers:
		if not is_instance_valid(trigger):
			continue
		var should_monitor: bool = _tooltips_enabled and not trigger.is_claimed()
		trigger.set_deferred(&"monitoring", should_monitor)


func _start_intro_if_possible() -> bool:
	if (
			not _tooltips_enabled
			or not _active
			or _state != State.IDLE
			or hint_library == null
		):
		return false
	if _game_state == null or _game_state.playtime_seconds > INTRO_PLAYTIME_LIMIT:
		return false

	var definition: CotcTutorialHintDefinition = hint_library.get_hint(INTRO_HINT_ID)
	if definition == null or not definition.is_valid_definition():
		push_warning("Cuttlefish intro hint is missing from the tutorial hint library.")
		return false
	if _is_hint_completed(definition):
		return false

	_resolve_hylas()
	_connect_hylas_signals()
	if not is_instance_valid(_hylas):
		return false

	_current_trigger = null
	_current_definition = definition
	_current_side = CotcTutorialHintTrigger.EntrySide.RIGHT
	_show_elapsed = 0.0
	_required_action_completed = false
	_bob_time = 0.0
	_startup_intro_pending = true
	_cuttlefish.hide()
	_hint_anchor.hide()
	_ink_video.hide()

	if startup_intro_delay <= 0.0:
		call_deferred(&"_begin_delayed_startup_intro")
	else:
		get_tree().create_timer(startup_intro_delay).timeout.connect(_begin_delayed_startup_intro)
	return true


func _begin_delayed_startup_intro() -> void:
	if not _startup_intro_pending:
		return
	_startup_intro_pending = false
	if not _tooltips_enabled or not _active or _current_definition == null:
		_current_definition = null
		return
	_resolve_hylas()
	if not is_instance_valid(_hylas):
		_current_definition = null
		return

	_current_side = CotcTutorialHintTrigger.EntrySide.RIGHT
	_bob_time = 0.0
	_spawn_cuttlefish()
	_state = State.ENTERING
	_sprite.show()
	_sprite.flip_h = true
	_sprite.play(&"swim")
	hint_started.emit(_current_definition.hint_id)


func _process_entry(delta: float) -> void:
	if not is_instance_valid(_hylas):
		_begin_exit()
		return
	var hover_target: Vector2 = _get_hover_target()
	var curved_target: Vector2 = _get_curved_entry_exit_target(hover_target)
	_move_cuttlefish_toward(curved_target, entry_speed, delta)
	if (
			_cuttlefish.global_position.distance_to(hover_target) <= arrival_radius
			or _cuttlefish.global_position.distance_to(curved_target) <= arrival_radius
		):
		_state = State.PRE_HINT
		_sprite.play(&"pre_hint")
		_sprite.flip_h = true


func _follow_hylas(delta: float) -> void:
	if not is_instance_valid(_hylas):
		return
	_move_cuttlefish_toward(_get_hover_target(), hover_follow_speed, delta)
	if _state != State.EXITING:
		_sprite.flip_h = true


func _process_exit(delta: float) -> void:
	var world_rect: Rect2 = _get_visible_world_rect()
	var target_x: float = world_rect.position.x - offscreen_margin
	if _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		target_x = world_rect.end.x + offscreen_margin
	var exit_target: Vector2 = Vector2(target_x, _cuttlefish.global_position.y)
	_move_cuttlefish_toward(_get_curved_entry_exit_target(exit_target), entry_speed, delta)
	if _is_cuttlefish_offscreen():
		_finish_current_hint()


func _get_curved_entry_exit_target(target: Vector2) -> Vector2:
	if entry_exit_curve_amplitude <= 0.0:
		return target
	var curve_offset: float = sin(_bob_time * TAU * entry_exit_curve_frequency) * entry_exit_curve_amplitude
	return target + Vector2(0.0, curve_offset)


func _move_cuttlefish_toward(target: Vector2, speed: float, delta: float) -> void:
	var previous_x: float = _cuttlefish.global_position.x
	_cuttlefish.global_position = _cuttlefish.global_position.move_toward(
		target,
		maxf(0.0, speed) * maxf(0.0, delta),
	)
	var horizontal_delta: float = _cuttlefish.global_position.x - previous_x
	if absf(horizontal_delta) > 0.05:
		_sprite.flip_h = horizontal_delta < 0.0


func _spawn_cuttlefish() -> void:
	var world_rect: Rect2 = _get_visible_world_rect()
	var spawn_x: float = world_rect.position.x - offscreen_margin
	if _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		spawn_x = world_rect.end.x + offscreen_margin
	var hover_target: Vector2 = _get_hover_target()
	var minimum_y: float = world_rect.position.y + world_screen_margin
	var maximum_y: float = maxf(minimum_y, world_rect.end.y - world_screen_margin)
	var spawn_y: float = clampf(hover_target.y, minimum_y, maximum_y)
	_cuttlefish.global_position = Vector2(spawn_x, spawn_y)
	_cuttlefish.show()
	_sprite.show()
	_sprite.flip_h = _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT
	_sprite.play(&"swim")


func _get_hover_target() -> Vector2:
	if not is_instance_valid(_hylas):
		return _cuttlefish.global_position
	var world_rect: Rect2 = _get_visible_world_rect()
	var bob_offset: float = sin(_bob_time * TAU * hover_bob_frequency) * hover_bob_amplitude
	var target: Vector2 = _hylas.global_position + _authored_hover_offset
	target.y += bob_offset

	var minimum_x: float = world_rect.position.x + world_screen_margin
	var maximum_x: float = maxf(minimum_x, world_rect.end.x - world_screen_margin)
	var minimum_y: float = world_rect.position.y + world_screen_margin
	var maximum_y: float = maxf(minimum_y, world_rect.end.y - world_screen_margin)
	target.x = clampf(target.x, minimum_x, maximum_x)
	target.y = clampf(target.y, minimum_y, maximum_y)
	return target


func _resolve_entry_side(requested_side: int) -> int:
	if requested_side == CotcTutorialHintTrigger.EntrySide.LEFT:
		return CotcTutorialHintTrigger.EntrySide.LEFT
	if requested_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		return CotcTutorialHintTrigger.EntrySide.RIGHT
	if not is_instance_valid(_hylas):
		return CotcTutorialHintTrigger.EntrySide.RIGHT
	var hylas_screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _hylas.global_position
	)
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	if hylas_screen_position.x <= viewport_width * 0.5:
		return CotcTutorialHintTrigger.EntrySide.LEFT
	return CotcTutorialHintTrigger.EntrySide.RIGHT


func _on_sprite_animation_finished() -> void:
	if _state != State.PRE_HINT or _sprite.animation != &"pre_hint":
		return
	_sprite.play(&"swim")
	_reveal_hint()


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

	if _current_definition.text_color != Color.TRANSPARENT:
		_hint_label.add_theme_color_override(&"font_color", _current_definition.text_color)
	_sprite.show()
	_kill_hint_tween()
	_update_hint_anchor_pivot()
	_set_typewriter_page(_intro_pages[0])
	_hide_advance_dots()
	_set_text_reveal(1.0)
	_set_ink_opacity(0.0)
	_update_hint_anchor_position()
	_ink_position_locked = true

	var final_scale: Vector2 = Vector2.ONE
	_hint_anchor.scale = final_scale * 0.05
	_hint_anchor.show()
	if _ink_video_available and _ink_video.stream != null:
		_ink_video.show()
		_ink_video.play()
	else:
		_ink_video.hide()

	_state = State.REVEALING
	if is_instance_valid(_ink_sound):
		_ink_sound.stop()
		_ink_sound.play()

	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_OUT)
	_hint_tween.tween_property(_hint_anchor, "scale", final_scale, ink_appear_duration)
	_hint_tween.parallel().tween_method(_set_ink_opacity, 0.0, _get_ink_target_opacity(), ink_appear_duration)
	_hint_tween.tween_callback(_begin_current_page_typewriter)


func _on_hint_revealed() -> void:
	if _state != State.REVEALING:
		return
	_show_elapsed = 0.0
	_state = State.SHOWING


func _should_dismiss_current_hint() -> bool:
	if _current_definition == null or _show_elapsed < minimum_read_time:
		return false
	var duration_complete: bool = _show_elapsed >= _current_definition.display_duration
	var action_required: bool = not String(_current_definition.required_action).is_empty()
	var action_complete: bool = action_required and _required_action_completed

	match _current_definition.dismiss_mode:
		CotcTutorialHintDefinition.DismissMode.AFTER_DURATION:
			return duration_complete
		CotcTutorialHintDefinition.DismissMode.REQUIRED_ACTION:
			return action_complete if action_required else duration_complete
		CotcTutorialHintDefinition.DismissMode.ACTION_OR_DURATION:
			return action_complete or duration_complete
		_:
			return duration_complete


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
	_hint_tween.parallel().tween_method(_set_ink_opacity, _get_ink_target_opacity(), 0.0, ink_hide_duration)
	_hint_tween.tween_callback(_on_hint_hidden)


func _on_hint_hidden() -> void:
	_hint_anchor.hide()
	_ink_video.stop()
	_ink_video.hide()
	_begin_exit()


func _begin_exit() -> void:
	if _state == State.EXITING:
		return
	_ink_position_locked = false
	_startup_intro_pending = false
	_set_conch_input_suppressed(false)
	_hint_anchor.hide()
	_ink_video.stop()
	_ink_video.hide()
	_sprite.show()
	_sprite.play(&"swim")
	_state = State.EXITING


func _finish_current_hint() -> void:
	var finished_id: StringName = &""
	if _current_definition != null:
		finished_id = _current_definition.hint_id
		if _current_definition.show_only_once:
			_mark_hint_completed(_current_definition)

	if is_instance_valid(_current_trigger):
		if (
				_current_definition != null
				and not _current_definition.show_only_once
				and _current_trigger.repeatable
			):
			_current_trigger.rearm()
		else:
			_current_trigger.mark_consumed()

	_cuttlefish.hide()
	_hint_anchor.hide()
	_current_trigger = null
	_current_definition = null
	_show_elapsed = 0.0
	_required_action_completed = false
	_state = State.IDLE
	if not String(finished_id).is_empty():
		hint_finished.emit(finished_id)
	call_deferred(&"_start_next_hint_if_possible")


func _cancel_presentation() -> void:
	_kill_hint_tween()
	if is_instance_valid(_ink_sound):
		_ink_sound.stop()
	if is_instance_valid(_tooltip_sound):
		_tooltip_sound.stop()
	if is_instance_valid(_ink_video):
		_ink_video.stop()
		_ink_video.hide()
	if is_instance_valid(_hint_anchor):
		_hint_anchor.hide()
	if is_instance_valid(_cuttlefish):
		_cuttlefish.hide()
	if is_instance_valid(_hint_label):
		_hint_label.visible_characters = 0
		_set_text_reveal(0.0)
	_startup_intro_pending = false
	_awaiting_page_advance = false
	_ink_position_locked = false
	_set_conch_input_suppressed(false)
	_current_page_plain_text = ""
	_inline_ellipsis_visible = false
	_intro_pages.clear()
	_intro_page_index = 0
	_hide_advance_dots()
	if is_instance_valid(_current_trigger):
		_current_trigger.rearm()
	for trigger: CotcTutorialHintTrigger in _queued_triggers:
		if is_instance_valid(trigger):
			trigger.rearm()
	_queued_triggers.clear()
	_current_trigger = null
	_current_definition = null
	_show_elapsed = 0.0
	_required_action_completed = false
	if _active:
		_state = State.IDLE


func _register_action(action_id: StringName) -> void:
	if _current_definition == null:
		return
	if _current_definition.required_action == action_id:
		_required_action_completed = true


func _on_hylas_tail_flip_started(_origin: Vector2, _direction: Vector2) -> void:
	_register_action(ACTION_TAIL_FLIP)


func _on_hylas_burst_started(_origin: Vector2, _direction: Vector2) -> void:
	_register_action(ACTION_SPEED_RUN)


func _on_hylas_conch_used(_origin: Vector2, _direction: Vector2) -> void:
	_register_action(ACTION_CONCH)


func _is_hint_completed(definition: CotcTutorialHintDefinition) -> bool:
	if definition == null or not definition.show_only_once:
		return false
	var key: String = _completion_flag_key(definition.hint_id)
	if bool(_session_completed.get(key, false)):
		return true
	if _game_state != null:
		return bool(_game_state.story_flags.get(key, false))
	return false


func _mark_hint_completed(definition: CotcTutorialHintDefinition) -> void:
	var key: String = _completion_flag_key(definition.hint_id)
	_session_completed[key] = true
	if _game_state != null:
		_game_state.set_story_flag(StringName(key), true)


func _completion_flag_key(hint_id: StringName) -> String:
	return "tutorial_hint_%s" % String(hint_id)


func _update_hint_anchor_position() -> void:
	if _ink_position_locked:
		return
	_apply_authored_hint_rect()


func _apply_authored_hint_rect() -> void:
	if not is_instance_valid(_hint_anchor):
		return
	_hint_anchor.position = _authored_hint_position
	_hint_anchor.size = _authored_hint_size
	_update_hint_anchor_pivot()
	_sync_hint_text_layout()


func _capture_authored_editor_layout() -> void:
	var authored_hylas_position: Vector2 = Vector2.ZERO
	if is_instance_valid(_hylas_editor_anchor):
		authored_hylas_position = _hylas_editor_anchor.global_position

	var authored_lykos_position: Vector2 = _cuttlefish.global_position
	if is_instance_valid(_sprite):
		authored_lykos_position = _sprite.global_position

	_authored_hover_offset = authored_lykos_position - authored_hylas_position
	hover_horizontal_offset = absf(_authored_hover_offset.x)
	hover_vertical_offset = -_authored_hover_offset.y

	if is_instance_valid(_hint_anchor):
		_authored_hint_position = _hint_anchor.position
		_authored_hint_size = _hint_anchor.size

	if is_instance_valid(_hint_label):
		_authored_text_position = _hint_label.position
		_authored_text_size = _hint_label.size

	if is_instance_valid(_advance_dots):
		_authored_dots_position = _advance_dots.position
		_authored_dots_size = _advance_dots.size

	# A direct child-sprite drag is converted into the authored hover offset, so
	# the runtime sprite can remain centred on the moving Cuttlefish parent.
	if is_instance_valid(_sprite):
		_sprite.position = Vector2.ZERO


func _sync_hint_text_layout() -> void:
	if is_instance_valid(_hint_label):
		_hint_label.position = _authored_text_position
		_hint_label.size = _authored_text_size
	if is_instance_valid(_advance_dots):
		_advance_dots.position = _authored_dots_position
		_advance_dots.size = _authored_dots_size


func _update_hint_anchor_pivot() -> void:
	if is_instance_valid(_hint_anchor):
		_hint_anchor.pivot_offset = _hint_anchor.size * 0.5


func _get_visible_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var inverse_canvas: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var corner_a: Vector2 = inverse_canvas * Vector2.ZERO
	var corner_b: Vector2 = inverse_canvas * viewport_size
	var minimum: Vector2 = Vector2(
		minf(corner_a.x, corner_b.x),
		minf(corner_a.y, corner_b.y),
	)
	var maximum: Vector2 = Vector2(
		maxf(corner_a.x, corner_b.x),
		maxf(corner_a.y, corner_b.y),
	)
	return Rect2(minimum, maximum - minimum)


func _is_cuttlefish_offscreen() -> bool:
	var screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return (
		screen_position.x < -offscreen_margin
		or screen_position.x > viewport_width + offscreen_margin
	)


func _configure_ink_video() -> void:
	# Do not assign a fallback here. The InkVideo node in the scene is the source of
	# truth, so changing InkVideo.stream in the editor changes gameplay.
	_ink_video_available = _ink_video.stream != null
	if not _ink_video_available:
		push_warning("Cuttlefish tutorial InkVideo has no stream assigned in the scene.")


func _read_scene_ink_opacity(fallback: float) -> float:
	if not is_instance_valid(_ink_video):
		return clampf(fallback, 0.0, 1.0)
	var material: ShaderMaterial = _ink_video.material as ShaderMaterial
	if material == null:
		return clampf(fallback, 0.0, 1.0)
	var opacity_value: Variant = material.get_shader_parameter(&"opacity")
	if typeof(opacity_value) == TYPE_FLOAT or typeof(opacity_value) == TYPE_INT:
		return clampf(float(opacity_value), 0.0, 1.0)
	return clampf(fallback, 0.0, 1.0)


func _get_ink_target_opacity() -> float:
	return clampf(_runtime_ink_max_opacity, 0.0, 1.0)


func _set_ink_opacity(value: float) -> void:
	var material: ShaderMaterial = _ink_video.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"opacity", clampf(value, 0.0, 1.0))


func _set_text_reveal(value: float) -> void:
	var material: ShaderMaterial = _hint_label.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"reveal", clampf(value, 0.0, 1.0))


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
		_advance_dots.show()
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
	_hint_label.text = _current_page_plain_text
	_hint_label.visible_characters = -1
	if is_instance_valid(_advance_dots) and _awaiting_page_advance:
		_advance_dots.visible = _inline_ellipsis_visible


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
	if is_instance_valid(_tooltip_sound):
		_tooltip_sound.stop()
		_tooltip_sound.play()


func _kill_hint_tween() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
