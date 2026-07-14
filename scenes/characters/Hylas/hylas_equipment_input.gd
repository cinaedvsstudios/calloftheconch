extends "res://scenes/characters/Hylas/hylas_reliable_input.gd"

## Equipment-aware action layer for Hylas.
##
## Input is matched through InputMap actions so remapped controls retain the
## same conflict rules. The first Item A binding shares the nearby interaction
## timing, while alternate Item A bindings continue to activate directly.

signal item_a_requested(item_id: StringName, origin: Vector2, direction: Vector2)

const NORMAL_CONCH_ID: StringName = &"normal_conch"

var _equipped_item_a: StringName = NORMAL_CONCH_ID
var _utility_item_pressed_this_frame: bool = false


func set_equipped_item_a(item_id: StringName) -> void:
	_equipped_item_a = item_id if not String(item_id).is_empty() else NORMAL_CONCH_ID


func get_equipped_item_a() -> StringName:
	return _equipped_item_a


func activate_normal_conch(direction: Vector2) -> bool:
	if (
			_death_sequence_active
			or not _play_enabled
			or crawl_active
			or airborne_active
			or _burst_active
			or _tail_flip_remaining > 0.0
			or _jump_elapsed > 0.0
			or _conch_cooldown_remaining > 0.0
		):
		return false

	var resolved_direction: Vector2 = direction
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = _conch_direction(Vector2.ZERO)
	else:
		resolved_direction = resolved_direction.normalized()

	_pending_conch_remaining = 0.0
	_start_conch(resolved_direction)
	return true


func _input(event: InputEvent) -> void:
	if _death_sequence_active or not _play_enabled or crawl_active or airborne_active:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return

	# Exact matching is essential because Item A, Item B and Tail Flip can share
	# the same base key while differing only by their modifiers.
	if event.is_action_pressed(&"utility_item", false, true):
		_utility_item_pressed_this_frame = true
		_space_action_pressed_this_frame = false
		_pending_interaction_remaining = 0.0
		_pending_conch_remaining = 0.0
		return

	if event.is_action_pressed(&"tail_flip", false, true):
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"conch", false, true):
		_space_action_pressed_this_frame = _is_primary_item_a_binding(event)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_utility_item_pressed_this_frame = false


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active or _utility_item_pressed_this_frame:
		return

	if not _space_action_pressed_this_frame or not _interaction_available:
		_request_equipped_item_a(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		_request_equipped_item_a(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window


func _is_primary_item_a_binding(event: InputEvent) -> bool:
	var bindings: Array[InputEvent] = InputMap.action_get_events(&"conch")
	if bindings.is_empty():
		return true
	return event.is_match(bindings[0], true)


func _request_equipped_item_a(input_direction: Vector2) -> bool:
	if (
			_death_sequence_active
			or not _play_enabled
			or crawl_active
			or airborne_active
			or _burst_active
			or _tail_flip_remaining > 0.0
			or _jump_elapsed > 0.0
		):
		return false

	var direction: Vector2 = _conch_direction(input_direction)
	if _equipped_item_a == NORMAL_CONCH_ID:
		return activate_normal_conch(direction)

	if String(_equipped_item_a).is_empty():
		return false

	_pending_conch_remaining = 0.0
	item_a_requested.emit(_equipped_item_a, global_position, direction)
	return true


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("equipped_item_a=%s" % String(_equipped_item_a))
	lines.append("utility_item_pressed_this_frame=%s" % str(_utility_item_pressed_this_frame))
	return lines
