class_name CotcPickupFeedback
extends CanvasLayer

const REWARD_FIN: StringName = &"fin"
const REWARD_ONOS: StringName = &"onos"

@export var fin_icon: Texture2D
@export var coin_icon: Texture2D
@export_range(0.1, 4.0, 0.05) var playback_speed: float = 2.0
@export_range(0.1, 3.0, 0.05) var reward_animation_seconds: float = 0.95
@export var reward_drift: Vector2 = Vector2(24.0, -105.0)

@onready var _anchor: Control = %Anchor
@onready var _video: VideoStreamPlayer = %PickupVideo
@onready var _reward_icon: TextureRect = %RewardIcon
@onready var _audio: AudioStreamPlayer = %PickupAudio
@onready var _lifetime: Timer = %Lifetime

var _finished: bool = false
var _follow_target: Node2D
var _reward_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_video.finished.connect(_on_video_finished)
	_lifetime.timeout.connect(_finish)
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_follow_target):
		_follow_target = null
		return
	_anchor.position = _world_to_screen(_get_target_anchor_position())


func play_feedback(target: Node2D = null, reward_kind: StringName = &"") -> void:
	_follow_target = target
	_finished = false
	visible = true
	set_process(true)
	_anchor.position = _world_to_screen(_get_target_anchor_position())
	_video.stop()
	_audio.stop()
	_video.speed_scale = playback_speed
	_prepare_reward_icon(reward_kind)
	if _video.stream != null:
		_video.play()
	if _audio.stream != null:
		_audio.play()
	var video_seconds: float = 0.0
	if _video.stream != null:
		video_seconds = _video.get_stream_length() / maxf(0.01, playback_speed)
	_lifetime.start(maxf(0.35, maxf(video_seconds + 0.12, reward_animation_seconds + 0.08)))


func _prepare_reward_icon(reward_kind: StringName) -> void:
	if _reward_tween != null and _reward_tween.is_valid():
		_reward_tween.kill()
	_reward_icon.position = Vector2(-38.0, -38.0)
	_reward_icon.scale = Vector2.ONE * 0.20
	_reward_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if reward_kind == REWARD_FIN:
		_reward_icon.texture = fin_icon
	elif reward_kind == REWARD_ONOS:
		_reward_icon.texture = coin_icon
	else:
		_reward_icon.texture = null
		_reward_icon.hide()
		return

	_reward_icon.show()
	_reward_tween = create_tween()
	_reward_tween.set_parallel(true)
	_reward_tween.tween_property(_reward_icon, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_property(_reward_icon, "modulate:a", 1.0, 0.12)
	_reward_tween.tween_property(
		_reward_icon,
		"position",
		Vector2(-38.0, -38.0) + reward_drift,
		reward_animation_seconds,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade_tween: PropertyTweener = _reward_tween.tween_property(
		_reward_icon,
		"modulate:a",
		0.0,
		0.42,
	)
	fade_tween.set_delay(maxf(0.0, reward_animation_seconds - 0.42))


func _get_target_anchor_position() -> Vector2:
	if not is_instance_valid(_follow_target):
		return get_viewport().get_visible_rect().size * 0.5
	if _follow_target.has_method(&"get_pickup_feedback_anchor_position"):
		return Vector2(_follow_target.call(&"get_pickup_feedback_anchor_position"))
	return _follow_target.global_position


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _on_video_finished() -> void:
	_video.stop()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	if _reward_tween != null and _reward_tween.is_valid():
		_reward_tween.kill()
	_video.stop()
	_audio.stop()
	queue_free()