extends "res://rebuild_v3/features/pirate_ship/pirate_ship_coordinator.gd"

## Keeps the permanent Leaf Sheep companion alive while the local pirate-ship
## room replaces the open-sea Hylas. CotcPirateShipInterior retargets the shared
## companion to its local Hylas and restores it on exit.


func _disable_open_sea_systems() -> void:
	if is_instance_valid(_tutorial) and _tutorial.has_method(&"deactivate"):
		_tutorial.call(&"deactivate")
