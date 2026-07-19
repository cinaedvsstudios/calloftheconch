extends "res://rebuild_v3/app/contexts/gameplay/gameplay_tutorial_context.gd"

## Applies Leaf Sheep forced-deactivation rules at gameplay-context boundaries.

@onready var _leaf_sheep_item_effects: Node = %ItemEffectController


func activate() -> void:
	super.activate()
	_set_leaf_sheep_gameplay_active(true)


func deactivate() -> void:
	_force_deactivate_leaf_sheep(&"context_deactivated")
	_set_leaf_sheep_gameplay_active(false)
	super.deactivate()


func complete_death_respawn() -> void:
	super.complete_death_respawn()
	_set_leaf_sheep_gameplay_active(true)


func _on_level_city_entry_requested() -> void:
	_force_deactivate_leaf_sheep(&"city")
	_set_leaf_sheep_gameplay_active(false)
	super._on_level_city_entry_requested()


func _on_city_exit_requested() -> void:
	super._on_city_exit_requested()
	if _active and not _in_city:
		_set_leaf_sheep_gameplay_active(true)


func _on_level_death_sequence_requested() -> void:
	_force_deactivate_leaf_sheep(&"death")
	_set_leaf_sheep_gameplay_active(false)
	super._on_level_death_sequence_requested()


func _on_level_whale_travel_requested() -> void:
	_force_deactivate_leaf_sheep(&"whale_travel")
	_set_leaf_sheep_gameplay_active(false)
	super._on_level_whale_travel_requested()


func _force_deactivate_leaf_sheep(reason: StringName) -> void:
	if is_instance_valid(_leaf_sheep_item_effects):
		_leaf_sheep_item_effects.call(&"force_deactivate_leaf_sheep", reason)


func _set_leaf_sheep_gameplay_active(is_active: bool) -> void:
	if is_instance_valid(_leaf_sheep_item_effects):
		_leaf_sheep_item_effects.call(&"set_leaf_sheep_gameplay_active", is_active)
