class_name VisualCollisionGuard
extends Node
## The current mountain artwork is visual-only. It must not create a full-screen alpha collision field.
## Solid land and breakable surfaces will later use dedicated placed collision shapes.


func _ready() -> void:
	call_deferred("_remove_visual_backdrop_collisions")


func _remove_visual_backdrop_collisions() -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var scenery_layer: Node = world.get_node_or_null("SceneryLayer")
	if scenery_layer == null:
		return
	for child: Node in scenery_layer.get_children():
		if child is StaticBody2D and child.name.begins_with("MountainCollision"):
			child.queue_free()
