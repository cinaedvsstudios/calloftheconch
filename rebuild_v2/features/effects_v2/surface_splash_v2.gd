class_name SurfaceSplashV2
extends VideoStreamPlayer

@export var display_duration: float = 0.42

var _remaining: float = 0.0


func _ready() -> void:
	hide()
	set_process(false)


func trigger(world_position: Vector2) -> void:
	global_position = world_position
	_remaining = display_duration
	stop()
	show()
	play()
	set_process(true)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		stop()
		hide()
		set_process(false)
