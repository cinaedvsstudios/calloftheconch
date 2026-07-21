extends "res://scenes/objects/Pickups/food_pickup.gd"

## Transitional controller for pickup scenes whose permanent visual size is
## authored directly on PickupSprite in the reusable .tscn.
##
## The inherited collection pulse still reads _resting_sprite_scale, but this
## override captures the authored child transform instead of recalculating it
## from display_height and the texture dimensions at runtime.


func _apply_display_scale() -> void:
	if not is_instance_valid(_sprite):
		return
	_resting_sprite_scale = _sprite.scale
