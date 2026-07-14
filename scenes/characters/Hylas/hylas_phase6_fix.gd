extends "res://scenes/characters/Hylas/hylas_equipment_input.gd"

signal surge_ram_started(origin: Vector2, direction: Vector2, duration: float)

func activate_item_surge(duration_seconds: float = 30.0) -> bool:
	var activated: bool = super.activate_item_surge(duration_seconds)
	if not activated:
		return false
	var direction: Vector2 = _burst_direction
	if direction.length_squared() <= 0.0001:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	surge_ram_started.emit(global_position, direction.normalized(), duration_seconds)
	return true
