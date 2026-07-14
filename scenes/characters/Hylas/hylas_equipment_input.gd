extends "res://scenes/characters/Hylas/hylas_reliable_input.gd"

## Equipment-aware action layer for Hylas.
##
## Input is matched through InputMap actions so remapped controls retain the
## same conflict rules. The inherited movement and interaction timing remain
## unchanged: a nearby interaction receives the first Item A press, while a
## second press inside the interaction window uses Item A instead.

signal item_a_requested(item_id: StringName, origin: Vector2, direction: Vector2)

const NORMAL_CONCH_ID: StringName = &"normal_conch"

var _equipped_item_a: StringName = NORMAL_CONCH_ID


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

	# The utility chord owns this event completely. It must not arm an
	# interaction or fall through to Item A, even if its physical key overlaps.
	if event.is_action_pressed(&"utility_item"):
		_space_action_pressed_this_frame = false
		_pending_interaction_remaining = 0.0
		_pending_conch_remaining = 0.0
		return

	if event.is_action_pressed(&"tail_flip"):
		_shift_space_tail_flip_requested = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"conch"):
		_space_action_pressed_this_frame = true


func _handle_conch_pressed(input_direction: Vector2) -> void:
	if _tail_flip_chord_active or Input.is_action_pressed(&"utility_item"):
		return

	# Any remapped Item A binding now participates in the same interaction rule.
	if not _space_action_pressed_this_frame or not _interaction_available:
		_request_equipped_item_a(input_direction)
		return

	if _pending_interaction_remaining > 0.0:
		_pending_interaction_remaining = 0.0
		_request_equipped_item_a(input_direction)
		return

	_pending_interaction_remaining = interaction_double_tap_window


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
	return lines
