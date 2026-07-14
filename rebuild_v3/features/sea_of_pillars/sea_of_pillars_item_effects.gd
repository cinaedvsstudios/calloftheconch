extends "res://rebuild_v3/features/sea_of_pillars/sea_of_pillars.gd"

## Phase 6 item hooks kept above the stable level controller. The base level
## continues to own enemy, pickup and conch routing; this layer only supplies
## the item-specific pulse profile and temporary shield check.


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


func _on_damage_requested(hylas_body: Node, amount: int) -> void:
	if (
			is_instance_valid(_hylas)
			and (hylas_body == _hylas or hylas_body.is_in_group(&"hylas"))
			and _hylas.has_method(&"is_purple_shield_active")
			and bool(_hylas.call(&"is_purple_shield_active"))
		):
		return
	super._on_damage_requested(hylas_body, amount)
