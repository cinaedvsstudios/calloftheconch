class_name CotcPickupFeedback
extends CanvasLayer

@onready var _video: VideoStreamPlayer = %PickupVideo
@onready var _audio: AudioStreamPlayer = %PickupAudio
@onready var _lifetime: Timer = %Lifetime

var _finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_video.finished.connect(_finish)
	_lifetime.timeout.connect(_finish)
	visible = false


func play_feedback() -> void:
	_finished = false
	visible = true
	_video.stop()
	_audio.stop()
	if _video.stream == null:
		_finish()
		return
	_video.play()
	if _audio.stream != null:
		_audio.play()
	_lifetime.start(maxf(0.25, _video.get_stream_length() + 0.20))


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_video.stop()
	_audio.stop()
	queue_free()
