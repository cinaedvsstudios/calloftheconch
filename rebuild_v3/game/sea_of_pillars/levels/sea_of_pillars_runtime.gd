class_name CotcSeaOfPillarsRuntime
extends "res://rebuild_v3/features/sea_of_pillars/sea_of_pillars.gd"

## Sea-specific integration for the reusable gameplay item controller.
## Shell effects remain owned by GameplayContext; this level only exposes its
## local reward-feedback and damage routes.


func show_item_reward_feedback(reward_kind: StringName) -> void:
	if _active:
		_spawn_pickup_feedback(reward_kind)


func _on_damage_requested(
		hylas_body: Node,
		amount: int,
		source: Node = null,
	) -> void:
	super._on_damage_requested(hylas_body, amount, source)
