extends "res://scenes/objects/Pickups/treasure_pickup.gd"

## Transitional controller for catalogue treasure pickups whose permanent
## visual size is authored on PickupSprite in the base or inherited .tscn.
## Texture selection remains catalogue-driven, but texture changes no longer
## replace the authored child transform.


func _apply_display_scale() -> void:
	pass
