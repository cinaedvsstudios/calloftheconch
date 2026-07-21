extends "res://rebuild_v3/features/pirate_ship/pirate_ship_coordinator.gd"

## Keeps the permanent item system alive while the local pirate-ship room
## replaces the open-sea Hylas, then restores the original routing on exit.


func _disable_open_sea_systems() -> void:
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"deactivate"):
		_tutorial.call(&"deactivate")


func _on_interior_requested(
		return_position: Vector2,
		facing_left: bool,
		entry: CotcPirateShipEntry,
	) -> void:
	super._on_interior_requested(return_position, facing_left, entry)
	if not is_instance_valid(_interior) or not is_instance_valid(_gameplay_context):
		return
	if not _gameplay_context.has_method(&"enter_local_room_player"):
		push_warning("GameplayContext does not support pirate-ship item retargeting.")
		return
	_gameplay_context.call(&"enter_local_room_player", _interior, _interior.get_hylas())


func _restore_open_sea_systems() -> void:
	super._restore_open_sea_systems()
	if (
			is_instance_valid(_gameplay_context)
			and _gameplay_context.has_method(&"exit_local_room_player")
		):
		_gameplay_context.call(&"exit_local_room_player")
