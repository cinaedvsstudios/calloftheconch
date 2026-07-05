class_name CotcBubbleBurst
extends Node2D

@export var display_duration: float = 0.40

@onready var _video: VideoStreamPlayer = %BubbleVideo

var _remaining_display_time: float = 0.0


func _ready() -> void:
	hide()
	set_process(false)


func trigger() -> void:
	if _video.stream == null:
		return
	_remaining_display_time = display_duration
	_video.stop()
	show()
	_video.play()
	set_process(true)


func stop_burst() -> void:
	_remaining_display_time = 0.0
	_video.stop()
	hide()
	set_process(false)


func is_active() -> bool:
	return visible and _remaining_display_time > 0.0


func get_remaining_display_time() -> float:
	return _remaining_display_time


func _process(delta: float) -> void:
	_remaining_display_time = maxf(0.0, _remaining_display_time - delta)
	if _remaining_display_time <= 0.0:
		stop_burst()
