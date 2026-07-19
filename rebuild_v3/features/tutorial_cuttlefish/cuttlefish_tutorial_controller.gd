class_name CotcCuttlefishTutorialController
extends Node

## Owns cuttlefish arrival, hint animation, ink presentation and one-shot completion.

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

@export var hint_library: CotcTutorialHintLibrary

@export_group("Cuttlefish Movement")
@export_range(100.0, 1400.0, 10.0) var entry_speed: float = 620.0
@export_range(100.0, 1400.0, 10.0) var hover_follow_speed: float = 760.0
@export_range(40.0, 320.0, 5.0) var hover_horizontal_offset: float = 185.0
@export_range(20.0, 240.0, 5.0) var hover_vertical_offset: float = 105.0
@export_range(0.0, 40.0, 1.0) var hover_bob_amplitude: float = 10.0
@export_range(0.1, 5.0, 0.1) var hover_bob_frequency: float = 1.6
@export_range(4.0, 80.0, 1.0) var arrival_radius: float = 18.0
@export_range(40.0, 400.0, 5.0) var offscreen_margin: float = 190.0
@export_range(20.0, 180.0, 5.0) var world_screen_margin: float = 80.0

@export_group("Ink Hint Presentation")
@export_file("*.ogv") var ink_video_path: String = "res://assets/effects/inkloop.ogv"
@export_range(0.1, 2.0, 0.05) var ink_appear_duration: float = 0.45
@export_range(0.1, 2.0, 0.05) var text_reveal_duration: float = 0.45
@export_range(0.1, 2.0, 0.05) var text_hide_duration: float = 0.35
@export_range(0.1, 2.0, 0.05) var ink_hide_duration: float = 0.45
@export_range(0.0, 3.0, 0.05) var minimum_read_time: float = 0.8
@export_range(80.0, 420.0, 5.0) var hint_screen_horizontal_offset: float = 220.0
@export_range(-360.0, 120.0, 5.0) var hint_screen_vertical_offset: float = -150.0
@export_range(10.0, 120.0, 5.0) var hint_screen_margin: float = 36.0

@onready var _cuttlefish: Node2D = %Cuttlefish
@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _hint_anchor: Control = %HintAnchor
@onready var _ink_video: VideoStreamPlayer = %InkVideo
@onready var _hint_label: Label = %HintText

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


func _ready() -> void:
	_cuttlefish.hide()
	_hint_anchor.hide()
	_ink_video.hide()
	_hint_label.text = ""
	_sprite.play(&"swim")
	if not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
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
	if not _active or trigger == null or hint_library == null:
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
	_spawn_cuttlefish()
	_state = State.ENTERING
	hint_started.emit(definition.hint_id)


func _process_entry(delta: float) -> void:
	if not is_instance_valid(_hylas):
		_begin_exit()
		return
	var target: Vector2 = _get_hover_target()
	_move_cuttlefish_toward(target, entry_speed, delta)
	if _cuttlefish.global_position.distance_to(target) <= arrival_radius:
		_state = State.PRE_HINT
		_sprite.play(&"pre_hint")


func _follow_hylas(delta: float) -> void:
	if not is_instance_valid(_hylas):
		return
	_move_cuttlefish_toward(_get_hover_target(), hover_follow_speed, delta)


func _process_exit(delta: float) -> void:
	var world_rect: Rect2 = _get_visible_world_rect()
	var target_x: float = world_rect.position.x - offscreen_margin
	if _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		target_x = world_rect.end.x + offscreen_margin
	var target: Vector2 = Vector2(target_x, _cuttlefish.global_position.y)
	_move_cuttlefish_toward(target, entry_speed, delta)
	if _is_cuttlefish_offscreen():
		_finish_current_hint()


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
	var minimum_y: float = world_rect.position.y + world_screen_margin
	var maximum_y: float = maxf(minimum_y, world_rect.end.y - world_screen_margin)
	var spawn_y: float = clampf(
		_hylas.global_position.y - hover_vertical_offset,
		minimum_y,
		maximum_y,
	)
	_cuttlefish.global_position = Vector2(spawn_x, spawn_y)
	_cuttlefish.show()
	_sprite.flip_h = _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT
	_sprite.play(&"swim")


func _get_hover_target() -> Vector2:
	var world_rect: Rect2 = _get_visible_world_rect()
	var side_sign: float = -1.0
	if _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		side_sign = 1.0
	var bob_offset: float = sin(_bob_time * TAU * hover_bob_frequency) * hover_bob_amplitude
	var target: Vector2 = _hylas.global_position + Vector2(
		side_sign * hover_horizontal_offset,
		-hover_vertical_offset + bob_offset,
	)
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
	_kill_hint_tween()
	_hint_label.text = _current_definition.text
	_hint_label.add_theme_color_override(&"font_color", _current_definition.text_color)
	_set_text_reveal(0.0)
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

	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_OUT)
	_hint_tween.tween_property(_hint_anchor, "scale", final_scale, ink_appear_duration)
	_hint_tween.parallel().tween_method(_set_ink_opacity, 0.0, 1.0, ink_appear_duration)
	_hint_tween.tween_method(_set_text_reveal, 0.0, 1.0, text_reveal_duration)
	_hint_tween.tween_callback(_on_hint_revealed)


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
	_kill_hint_tween()
	var hidden_scale: Vector2 = _hint_anchor.scale * 0.05
	_hint_tween = create_tween()
	_hint_tween.set_trans(Tween.TRANS_QUAD)
	_hint_tween.set_ease(Tween.EASE_IN)
	_hint_tween.tween_method(_set_text_reveal, 1.0, 0.0, text_hide_duration)
	_hint_tween.tween_property(_hint_anchor, "scale", hidden_scale, ink_hide_duration)
	_hint_tween.parallel().tween_method(_set_ink_opacity, 1.0, 0.0, ink_hide_duration)
	_hint_tween.tween_callback(_on_hint_hidden)


func _on_hint_hidden() -> void:
	_hint_anchor.hide()
	_ink_video.stop()
	_ink_video.hide()
	_begin_exit()


func _begin_exit() -> void:
	if _state == State.EXITING:
		return
	_hint_anchor.hide()
	_ink_video.stop()
	_ink_video.hide()
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
	_ink_video.stop()
	_ink_video.hide()
	_hint_anchor.hide()
	_cuttlefish.hide()
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
	if not _cuttlefish.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cuttlefish_screen_position: Vector2 = (
		get_viewport().get_canvas_transform() * _cuttlefish.global_position
	)
	var horizontal_direction: float = 1.0
	if _current_side == CotcTutorialHintTrigger.EntrySide.RIGHT:
		horizontal_direction = -1.0
	var desired_center: Vector2 = cuttlefish_screen_position + Vector2(
		horizontal_direction * hint_screen_horizontal_offset,
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
	var candidates: Array[String] = [
		ink_video_path,
		"res://assets/effects/black smoke rise.ogv",
	]
	var resolved_path: String = ""
	for candidate: String in candidates:
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			resolved_path = candidate
			break
	if resolved_path.is_empty():
		_ink_video_available = false
		push_warning(
			"Cuttlefish tutorial ink needs an Ogg Theora file at "
			+ "assets/effects/inkloop.ogv or black smoke rise.ogv."
		)
		return
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = resolved_path
	_ink_video.stream = stream
	_ink_video_available = true


func _set_ink_opacity(value: float) -> void:
	var material: ShaderMaterial = _ink_video.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"opacity", clampf(value, 0.0, 1.0))


func _set_text_reveal(value: float) -> void:
	var material: ShaderMaterial = _hint_label.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"reveal", clampf(value, 0.0, 1.0))


func _kill_hint_tween() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
