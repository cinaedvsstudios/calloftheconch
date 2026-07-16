class_name CotcSeaOfPillarsRuntime
extends "res://rebuild_v3/features/sea_of_pillars/sea_of_pillars.gd"

## Sea-specific integration for the reusable gameplay item controller.
## Shell effects remain owned by GameplayContext; this level only exposes its
## local conch pulse and damage route.


func trigger_special_conch(origin: Vector2, direction: Vector2, profile: Dictionary) -> bool:
	if not _active:
		return false
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()
	var pulse_origin: Vector2 = origin + pulse_direction * conch_origin_forward_offset
	if _conch_pulse.has_method(&"trigger_profile_from_player"):
		_conch_pulse.call(
			&"trigger_profile_from_player",
			pulse_origin,
			pulse_direction,
			origin,
			profile,
		)
	else:
		_conch_pulse.trigger_from_player(pulse_origin, pulse_direction, origin)
	conch_used.emit()
	return true


func show_item_reward_feedback(reward_kind: StringName) -> void:
	if _active:
		_spawn_pickup_feedback(reward_kind)


func _on_damage_requested(
		hylas_body: Node,
		amount: int,
		source: Node = null,
	) -> void:
	super._on_damage_requested(hylas_body, amount, source)
