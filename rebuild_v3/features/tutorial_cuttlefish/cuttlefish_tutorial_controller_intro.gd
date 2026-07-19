extends "res://rebuild_v3/features/tutorial_cuttlefish/cuttlefish_tutorial_controller.gd"

## Adds the automatic first-game greeting and the global tutorial-tooltip toggle.

const INTRO_HINT_ID: StringName = &"intro_welcome"
const INTRO_PLAYTIME_LIMIT: float = 1.0

var _tooltips_enabled: bool = true


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
	_current_side = CotcTutorialHintTrigger.EntrySide.LEFT
	_show_elapsed = 0.0
	_required_action_completed = false
	_bob_time = 0.0

	# The opening greeting begins with the cuttlefish already beside Hylas.
	_cuttlefish.global_position = _get_hover_target()
	_cuttlefish.show()
	_sprite.flip_h = false
	_sprite.play(&"pre_hint")
	_state = State.PRE_HINT
	hint_started.emit(definition.hint_id)
