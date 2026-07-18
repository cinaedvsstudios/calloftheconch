class_name CotcSpikeRock
extends Node2D

## Emitted through the Sea of Pillars' existing enemy-damage route. Touching the
## spike area removes one fin, uses the normal damage immunity window and sound,
## and triggers the existing defeat flow when Hylas has no fins remaining.
signal damage_requested(hylas_body: Node, amount: int)

@export_range(1, 4, 1) var fin_damage: int = 1

@onready var _hurt_area: Area2D = %HurtArea


func _ready() -> void:
	if not _hurt_area.body_entered.is_connected(_on_hurt_area_body_entered):
		_hurt_area.body_entered.connect(_on_hurt_area_body_entered)


func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group(&"hylas"):
		return
	damage_requested.emit(body, fin_damage)
