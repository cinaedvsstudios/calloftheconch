class_name CotcConchImpactEffect
extends Node2D

@onready var _video: VideoStreamPlayer = %ImpactVideo
@onready var _audio: AudioStreamPlayer2D = %ImpactAudio
@onready var _lifetime: Timer = %Lifetime

var _finished: bool = false
var _follow_target: Node2D
var _follow_local_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_video.finished.connect(_finish)
	_lifetime.timeout.connect(_finish)
	hide()
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_follow_target):
		_follow_target = null
		set_process(false)
		return
	global_position = _follow_target.to_global(_follow_local_offset)


func play_effect() -> void:
	_follow_target = null
	_follow_local_offset = Vector2.ZERO
	set_process(false)
	_start_effect()


func play_attached(target: Node2D, hit_position: Vector2) -> void:
	if is_instance_valid(target):
		_follow_target = target
		_follow_local_offset = target.to_local(hit_position)
		global_position = hit_position
		set_process(true)
	else:
		_follow_target = null
		_follow_local_offset = Vector2.ZERO
		global_position = hit_position
		set_process(false)
	_start_effect()


func _start_effect() -> void:
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
	var playback_speed: float = maxf(0.01, _video.speed_scale)
	_lifetime.start(maxf(0.25, _video.get_stream_length() / playback_speed + 0.20))


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	_video.stop()
	_audio.stop()
	queue_free()