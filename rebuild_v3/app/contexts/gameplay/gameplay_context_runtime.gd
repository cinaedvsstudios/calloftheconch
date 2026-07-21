extends "res://rebuild_v3/app/contexts/gameplay/gameplay_context.gd"

## Keeps Item A and Item B routed to a temporary local-room Hylas while the
## persistent Sea of Pillars level remains instantiated in the background.

var _open_sea_hylas_before_local_room: CotcHylas
var _local_room_player_active: bool = false


func enter_local_room_player(room_level: Node, room_hylas: CotcHylas) -> bool:
	if not is_instance_valid(room_hylas):
		push_warning("GameplayContext could not enter local-room player mode: Hylas is missing.")
		return false
	if not _local_room_player_active:
		_open_sea_hylas_before_local_room = _hylas
	_disconnect_item_request_from(_hylas)
	_hylas = room_hylas
	_connect_hylas_item_request()
	_sync_equipped_item_a()
	if is_instance_valid(_item_effect_controller):
		if _item_effect_controller.has_method(&"retarget_local_room"):
			_item_effect_controller.call(&"retarget_local_room", self, room_level, room_hylas)
		_item_effect_controller.set_active(true)
	_set_leaf_sheep_gameplay_active(true)
	_local_room_player_active = true
	return true


func exit_local_room_player() -> void:
	if not _local_room_player_active:
		return
	_disconnect_item_request_from(_hylas)
	_hylas = _open_sea_hylas_before_local_room
	_open_sea_hylas_before_local_room = null
	if not is_instance_valid(_hylas):
		_hylas = null
		_resolve_hylas()
	_connect_hylas_item_request()
	_sync_equipped_item_a()
	if is_instance_valid(_item_effect_controller) and is_instance_valid(_hylas):
		_item_effect_controller.configure(self, _level, _hylas)
		_item_effect_controller.set_active(_active)
	_set_leaf_sheep_gameplay_active(_active)
	_local_room_player_active = false


func _disconnect_item_request_from(hylas: CotcHylas) -> void:
	if not is_instance_valid(hylas) or not hylas.has_signal(&"item_a_requested"):
		return
	var callback: Callable = Callable(self, "_on_hylas_item_a_requested")
	if hylas.is_connected(&"item_a_requested", callback):
		hylas.disconnect(&"item_a_requested", callback)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("local_room_player_active=%s" % str(_local_room_player_active))
	lines.append("active_hylas_path=%s" % str(_hylas.get_path() if is_instance_valid(_hylas) else NodePath()))
	return lines
