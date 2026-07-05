class_name CotcSurfaceSplash
extends AnimatedSprite2D


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	hide()


func trigger(world_position: Vector2) -> void:
	global_position = world_position
	frame = 0
	show()
	play(&"splash")


func stop_splash() -> void:
	stop()
	frame = 0
	hide()


func _on_animation_finished() -> void:
	if animation == &"splash":
		stop_splash()
