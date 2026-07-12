class_name CotcConchImpactEffect
extends Node2D

@onready var _video: VideoStreamPlayer = %ImpactVideo
@onready var _audio: AudioStreamPlayer2D = %ImpactAudio
@onready var _lifetime: Timer = %Lifetime

var _finished: bool = false


func _ready() -> void:
	_video.finished.connect(_finish)
	_lifetime.timeout.connect(_finish)
	hide()


func play_effect() -> void:
	_finished = false
	show()
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
