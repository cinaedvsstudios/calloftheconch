class_name CotcRockHitRouter
extends Node

## Focused gameplay routing only. The target rock owns all integrity, debris,
## sprite and collision decisions.

@onready var _hylas: Node = get_parent()

var _tail_flip_delivered_count: int = 0
var _last_tail_flip_target: NodePath = NodePath("")


func _on_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	var receiver: Node = _find_receiver(target, &"receive_tail_flip_bash")
	if receiver == null:
		return
	_tail_flip_delivered_count += 1
	_last_tail_flip_target = receiver.get_path()
	receiver.call(
		&"receive_tail_flip_bash",
		contact_position,
		normal,
		_hylas,
	)


func _find_receiver(target: Node, method_name: StringName) -> Node:
	var candidate: Node = target
	var remaining_parent_checks: int = 4
	while candidate != null and remaining_parent_checks >= 0:
		if candidate.has_method(method_name):
			return candidate
		candidate = candidate.get_parent()
		remaining_parent_checks -= 1
	return null


func get_debug_lines() -> Array[String]:
	return [
		"[RockHitRouter]",
		"tail_flip_delivered=%d" % _tail_flip_delivered_count,
		"last_tail_flip_target=%s" % str(_last_tail_flip_target),
	]
