class_name HealthComponent
extends Node
## Generic health module with local signals. The owner decides wider game effects.

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died()

@export_range(1, 999999, 1) var max_health: int = 10
@export var start_full: bool = true

var current_health: int = 0
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health if start_full else clampi(current_health, 0, max_health)
	health_changed.emit(current_health, max_health)


func apply_damage(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0

	var applied: int = mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		is_dead = true
		died.emit()
	return applied


func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0

	var previous_health: int = current_health
	current_health = mini(max_health, current_health + amount)
	var applied: int = current_health - previous_health
	if applied > 0:
		healed.emit(applied)
		health_changed.emit(current_health, max_health)
	return applied


func revive(health_amount: int = -1) -> void:
	is_dead = false
	current_health = max_health if health_amount < 0 else clampi(health_amount, 1, max_health)
	health_changed.emit(current_health, max_health)


func get_health_fraction() -> float:
	return float(current_health) / float(maxi(1, max_health))
