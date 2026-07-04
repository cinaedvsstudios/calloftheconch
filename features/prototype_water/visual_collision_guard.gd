class_name VisualCollisionGuard
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_delta: float) -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var scenery_layer: Node = world.get_node_or_null("SceneryLayer")
	if scenery_layer == null:
		return
	for child: Node in scenery_layer.get_children():
		if child is StaticBody2D and child.name.begins_with("MountainCollision"):
			var mountain_body: StaticBody2D = child as StaticBody2D
			mountain_body.collision_layer = 0
			mountain_body.collision_mask = 0