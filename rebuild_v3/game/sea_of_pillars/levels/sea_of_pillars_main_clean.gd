class_name CotcSeaOfPillarsMainClean
extends "res://rebuild_v3/game/sea_of_pillars/levels/sea_of_pillars_runtime.gd"

## The production Sea of Pillars scene starts as an uncluttered construction
## canvas. The populated prototype keeps the city, enemies, hazards, pickups and
## travel interactions. These overrides make the hidden compatibility nodes in
## the clean scene inert while preserving the shared gameplay controller API.


func _create_city_gate_interaction() -> void:
	_city_gate_area = null
	_city_gate_in_range = false


func _refresh_hylas_interaction_available() -> void:
	_set_hylas_interaction_available(false)


func _on_hylas_interaction_requested() -> void:
	pass


func _on_whale_interaction_availability_changed(_is_available: bool) -> void:
	_set_hylas_interaction_available(false)


func _resolve_spawn_point_id(requested_id: StringName) -> StringName:
	if requested_id == WHALE_GROUND_SPAWN_POINT_ID or requested_id == CITY_GATE_SPAWN_POINT_ID:
		return DEFAULT_SPAWN_POINT_ID
	return super._resolve_spawn_point_id(requested_id)


func _resolve_spawn_position(spawn_point_id: StringName) -> Vector2:
	if spawn_point_id == WHALE_GROUND_SPAWN_POINT_ID or spawn_point_id == CITY_GATE_SPAWN_POINT_ID:
		return _start_marker.global_position
	return super._resolve_spawn_position(spawn_point_id)
