class_name VisualCollisionGuard
extends Node

func _ready() -> void:
	call_deferred("_disable_lower_overlay")

func _disable_lower_overlay() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var water_layer: Node = parent_node.get_node_or_null("WaterLayer")
	if water_layer == null:
		return
	for child: Node in water_layer.get_children():
		if child is Sprite2D and child.z_index == -20:
			child.visible = false
