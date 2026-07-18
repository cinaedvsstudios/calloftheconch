class_name CotcSeaOfPillarsRuntime
extends "res://rebuild_v3/features/sea_of_pillars/sea_of_pillars.gd"

## Sea-specific integration for the reusable gameplay item controller.
## Shell effects remain owned by GameplayContext; this level only exposes its
## local conch pulse and damage route.

const CONCH_PROFILE_NORMAL: StringName = &"normal_conch"
const CONCH_PROFILE_SUPER: StringName = &"super_conch"
const CONCH_PROFILE_TEREBRIDAE: StringName = &"terebridae"

const NORMAL_ENEMY_NUDGE_DISTANCE: float = 10.0
const SUPER_ENEMY_NUDGE_DISTANCE: float = 18.0
const TEREBRIDAE_ENEMY_TWITCH_DISTANCE: float = 14.0
const TEREBRIDAE_TWITCH_OUT_SECONDS: float = 0.07
const TEREBRIDAE_TWITCH_RETURN_SECONDS: float = 0.12

const NORMAL_AMBIENT_PUSH_SPEED: float = 85.0
const SUPER_AMBIENT_PUSH_SPEED: float = 120.0
const TEREBRIDAE_AMBIENT_PUSH_SPEED: float = 170.0
const AMBIENT_PUSH_DECAY: float = 400.0
const TEREBRIDAE_AMBIENT_PUSH_DECAY: float = 1800.0


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


func _on_conch_pulse_target_hit(
		target: Node2D,
		hit_position: Vector2,
		pulse_index: int,
	) -> void:
	if not _active:
		return
	_spawn_conch_impact(target, hit_position)

	var response_target: Node2D = _resolve_conch_response_target(target)
	var profile_id: StringName = _get_active_conch_profile_id()
	if response_target is CotcAmbientFish:
		_configure_ambient_conch_push(response_target as CotcAmbientFish, profile_id)

	conch_target_hit.emit(target, hit_position, pulse_index)

	if (
			response_target == null
			or response_target is CotcAmbientFish
			or not response_target.is_in_group(&"enemy")
			or _is_conch_knockback_immune(response_target)
		):
		return
	_apply_enemy_conch_response(response_target, profile_id)


func _resolve_conch_response_target(target: Node2D) -> Node2D:
	var candidate: Node = target
	var movement_fallback: Node2D = null
	while candidate != null and candidate != self:
		var candidate_2d: Node2D = candidate as Node2D
		if candidate_2d != null:
			if (
					candidate_2d.is_in_group(&"ambient_fish")
					or candidate_2d.is_in_group(&"enemy")
					or candidate_2d.is_in_group(&"hazard")
					or _has_boss_group(candidate_2d)
				):
				return candidate_2d
			if movement_fallback == null and (
					candidate_2d is CharacterBody2D
					or candidate_2d is Area2D
				):
				movement_fallback = candidate_2d
		candidate = candidate.get_parent()
	return movement_fallback


func _get_active_conch_profile_id() -> StringName:
	if _conch_pulse.has_method(&"get_active_emission_profile_id"):
		return StringName(str(_conch_pulse.call(&"get_active_emission_profile_id")))
	return CONCH_PROFILE_NORMAL


func _configure_ambient_conch_push(
		ambient_fish: CotcAmbientFish,
		profile_id: StringName,
	) -> void:
	match profile_id:
		CONCH_PROFILE_SUPER:
			ambient_fish.conch_push_speed = SUPER_AMBIENT_PUSH_SPEED
			ambient_fish.conch_push_decay = AMBIENT_PUSH_DECAY
		CONCH_PROFILE_TEREBRIDAE:
			ambient_fish.conch_push_speed = TEREBRIDAE_AMBIENT_PUSH_SPEED
			ambient_fish.conch_push_decay = TEREBRIDAE_AMBIENT_PUSH_DECAY
		_:
			ambient_fish.conch_push_speed = NORMAL_AMBIENT_PUSH_SPEED
			ambient_fish.conch_push_decay = AMBIENT_PUSH_DECAY


func _apply_enemy_conch_response(target: Node2D, profile_id: StringName) -> void:
	var away_direction: Vector2 = Vector2.RIGHT
	if is_instance_valid(_hylas):
		var target_offset: Vector2 = target.global_position - _hylas.global_position
		if target_offset.length_squared() > 0.001:
			away_direction = target_offset.normalized()

	match profile_id:
		CONCH_PROFILE_SUPER:
			target.global_position += away_direction * SUPER_ENEMY_NUDGE_DISTANCE
		CONCH_PROFILE_TEREBRIDAE:
			_play_terebridae_enemy_twitch(target, away_direction)
		_:
			target.global_position += away_direction * NORMAL_ENEMY_NUDGE_DISTANCE


func _play_terebridae_enemy_twitch(target: Node2D, away_direction: Vector2) -> void:
	var start_position: Vector2 = target.global_position
	var twitch_tween: Tween = create_tween()
	twitch_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	twitch_tween.tween_property(
		target,
		^"global_position",
		start_position + away_direction * TEREBRIDAE_ENEMY_TWITCH_DISTANCE,
		TEREBRIDAE_TWITCH_OUT_SECONDS,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	twitch_tween.tween_property(
		target,
		^"global_position",
		start_position,
		TEREBRIDAE_TWITCH_RETURN_SECONDS,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _is_conch_knockback_immune(target: Node2D) -> bool:
	return (
		target.is_in_group(&"hazard")
		or target.is_in_group(&"conch_knockback_immune")
		or _has_boss_group(target)
	)


func _has_boss_group(target: Node) -> bool:
	for group_name: StringName in target.get_groups():
		if String(group_name).to_lower().contains("boss"):
			return true
	return false


func show_item_reward_feedback(reward_kind: StringName) -> void:
	if _active:
		_spawn_pickup_feedback(reward_kind)


func _on_damage_requested(
		hylas_body: Node,
		amount: int,
		source: Node = null,
	) -> void:
	super._on_damage_requested(hylas_body, amount, source)
