class_name CotcScatterBubbleVideo
extends Node2D

## Placeable decorative bubble video. The shared bubble shader removes the
## video's black background so instances can be scattered through a level.

@export_category("Playback")
@export var play_on_ready: bool = true
@export var loop_video: bool = true

@onready var _bubble_video: VideoStreamPlayer = get_node_or_null("BubbleVideo") as VideoStreamPlayer

var _distance_active: bool = true
var _playback_requested: bool = true


func _ready() -> void:
	if _bubble_video == null:
		push_error("CotcScatterBubbleVideo requires a direct VideoStreamPlayer child named BubbleVideo.")
		return
	_bubble_video.loop = loop_video
	_playback_requested = play_on_ready
	_apply_video_playback()


func set_playing(should_play: bool) -> void:
	_playback_requested = should_play
	_apply_video_playback()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	_apply_video_playback()


func restart() -> void:
	_playback_requested = true
	if _bubble_video == null or _bubble_video.stream == null or not _distance_active:
		return
	_bubble_video.stop()
	_bubble_video.play()


func _apply_video_playback() -> void:
	if _bubble_video == null:
		return
	if _distance_active and _playback_requested and _bubble_video.stream != null:
		if not _bubble_video.is_playing():
			_bubble_video.play()
		return
	_bubble_video.stop()
