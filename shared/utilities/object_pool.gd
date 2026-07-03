class_name ObjectPool
extends RefCounted
## Optional pool for repeatedly spawned Node-based effects, bullets or pickups.
## Keep pooled objects alive and reset them in their own on_pool_obtained and
## on_pool_released methods.

var _scene: PackedScene
var _parent: Node
var _available: Array[Node] = []
var _active: Array[Node] = []


func _init(scene: PackedScene, parent: Node) -> void:
	_scene = scene
	_parent = parent


func warm(count: int) -> void:
	for _index: int in range(maxi(0, count)):
		var instance := _create_instance()
		if instance != null:
			_release_internal(instance)


func obtain() -> Node:
	var instance: Node
	if _available.is_empty():
		instance = _create_instance()
	else:
		instance = _available.pop_back()

	if instance == null:
		return null

	_active.append(instance)
	if instance is CanvasItem:
		(instance as CanvasItem).show()
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if instance.has_method("on_pool_obtained"):
		instance.call("on_pool_obtained")
	return instance


func release(instance: Node) -> void:
	if instance == null or not _active.has(instance):
		return

	_active.erase(instance)
	_release_internal(instance)


func clear() -> void:
	for instance: Node in _available + _active:
		if is_instance_valid(instance):
			instance.queue_free()
	_available.clear()
	_active.clear()


func _create_instance() -> Node:
	if _scene == null or _parent == null:
		push_warning("ObjectPool needs both a PackedScene and a parent Node.")
		return null

	var instance: Node = _scene.instantiate()
	_parent.add_child(instance)
	return instance


func _release_internal(instance: Node) -> void:
	if instance.has_method("on_pool_released"):
		instance.call("on_pool_released")
	if instance is CanvasItem:
		(instance as CanvasItem).hide()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	_available.append(instance)
