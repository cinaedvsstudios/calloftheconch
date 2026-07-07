class_name CotcVent1
extends Node2D

## Visual-only reusable hydrothermal vent. Gameplay current or launch behaviour
## will be added separately when the vent mechanics are defined.

@export var play_on_ready: bool = true
@export var loop_video: bool = true

@onready var _vent_video: VideoStreamPlayer = %VentVideo


func _ready() -> void:
	_vent_video.loop = loop_video
	if play_on_ready:
		_vent_video.play()


func set_vent_playing(should_play: bool) -> void:
	if should_play:
		_vent_video.play()
	else:
		_vent_video.stop()
