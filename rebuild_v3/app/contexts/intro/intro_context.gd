class_name CotcIntroContext
extends Control

signal intro_finished

const INTRO_VIDEO_PATH: String = "res://assets/ui/introvideo.ogv"

@onready var _video: VideoStreamPlayer = %IntroVideo
@onready var _skip_hint: Label = %SkipHint

var _active: bool = false
var _finishing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_video.process_mode = Node.PROCESS_MODE_ALWAYS
	_video.finished.connect(_on_video_finished)
	hide()


func activate() -> void:
	_active = true
	_finishing = false
	show()
	_skip_hint.show()
	_video.stop()
	if not ResourceLoader.exists(INTRO_VIDEO_PATH):
		push_warning("Intro video is not present yet at %s. Starting the new game without it." % INTRO_VIDEO_PATH)
		call_deferred(&"_finish_intro")
		return
	var loaded_resource: Resource = load(INTRO_VIDEO_PATH)
	var intro_stream: VideoStream = loaded_resource as VideoStream
	if intro_stream == null:
		push_warning("The intro video could not be loaded from %s." % INTRO_VIDEO_PATH)
		call_deferred(&"_finish_intro")
		return
	_video.stream = intro_stream
	_video.play()


func deactivate() -> void:
	_active = false
	_video.stop()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _finishing:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish_intro()


func _on_video_finished() -> void:
	_finish_intro()


func _finish_intro() -> void:
	if not _active or _finishing:
		return
	_finishing = true
	_video.stop()
	hide()
	_active = false
	intro_finished.emit()


func get_debug_lines() -> Array[String]:
	return [
		"[IntroContext]",
		"visible=%s" % str(visible),
		"active=%s" % str(_active),
		"video_present=%s" % str(ResourceLoader.exists(INTRO_VIDEO_PATH)),
		"video_playing=%s" % str(_video.is_playing()),
	]
