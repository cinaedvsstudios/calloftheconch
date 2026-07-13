class_name CotcSpawnCheckpoint
extends Area2D

signal checkpoint_activated(level_id: StringName, spawn_point_id: StringName)

@export var level_id: StringName = &"sea_of_pillars"
@export var spawn_point_id: StringName = &"sea_of_pillars_whale_ground_01"
@export var activate_on_body_enter: bool = true

var _activated: bool = false


func _ready() -> void:
	monitoring = activate_on_body_enter
	if activate_on_body_enter:
		body_entered.connect(_on_body_entered)


func activate_checkpoint() -> void:
	if String(spawn_point_id).is_empty():
		push_warning("Spawn checkpoint has no spawn_point_id.")
		return
	_activated = true
	checkpoint_activated.emit(level_id, spawn_point_id)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group(&"hylas"):
		return
	activate_checkpoint()


func has_been_activated() -> bool:
	return _activated
