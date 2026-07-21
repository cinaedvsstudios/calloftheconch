extends "res://scenes/objects/AmbientFish/ambient_fish.gd"

## Transitional controller for ambient fish scenes whose visual and collision
## sizes are authored directly in the reusable .tscn.
##
## The inherited movement, current response, Conch reaction and shark avoidance
## remain unchanged; only the old texture-height scale calculation is disabled.


func _apply_display_scale_and_collision() -> void:
	pass
