class_name CotcWaterVideoBackground
extends Control

@export var auto_play_on_ready: bool = true

@onready var _video: VideoStreamPlayer = %WaterBackgroundVideo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_video.process_mode = Node.PROCESS_MODE_ALWAYS
	if auto_play_on_ready:
		play_background()
	else:
		_video.stop()


func play_background() -> void:
	show()
	if _video.stream == null:
		return
	_video.stream_paused = false
	if not _video.is_playing():
		_video.play()


func stop_background() -> void:
	_video.stop()
	hide()


func set_background_active(is_active: bool) -> void:
	if is_active:
		play_background()
	else:
		stop_background()


func is_background_playing() -> bool:
	return _video.is_playing()
