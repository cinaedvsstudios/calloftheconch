class_name CotcScatterBubbleVideo
extends Node2D

## Placeable decorative bubble video. The shared bubble shader removes the
## video's black background so instances can be scattered through a level.

@export_category("Playback")
@export var play_on_ready: bool = true
@export var loop_video: bool = true

@onready var _bubble_video: VideoStreamPlayer = get_node_or_null("BubbleVideo") as VideoStreamPlayer


func _ready() -> void:
	if _bubble_video == null:
		push_error("CotcScatterBubbleVideo requires a direct VideoStreamPlayer child named BubbleVideo.")
		return
	_bubble_video.loop = loop_video
	if play_on_ready and _bubble_video.stream != null:
		_bubble_video.play()


func set_playing(should_play: bool) -> void:
	if _bubble_video == null:
		return
	if should_play:
		if _bubble_video.stream != null and not _bubble_video.is_playing():
			_bubble_video.play()
	else:
		_bubble_video.stop()


func restart() -> void:
	if _bubble_video == null or _bubble_video.stream == null:
		return
	_bubble_video.stop()
	_bubble_video.play()
