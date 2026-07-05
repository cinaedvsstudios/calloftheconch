class_name CotcLoopingAudioPlayer
extends AudioStreamPlayer

@export var loop_stream: bool = true

func _ready() -> void:
	if loop_stream:
		_set_stream_looping()

func _set_stream_looping() -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
