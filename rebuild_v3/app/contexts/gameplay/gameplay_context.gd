class_name CotcGameplayContext
extends Node

signal menu_requested

@onready var _level: CotcSeaOfPillars = %SeaOfPillars
@onready var _sea_environment: Node2D = $SeaEnvironment
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _gameplay_ui: CanvasLayer = $GameplayUI
@onready var _hint: Label = $GameplayUI/Hint
@onready var _pause_overlay: CotcPauseOverlay = %PauseOverlay

var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gameplay_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.menu_requested.connect(_on_pause_menu_requested)
	_sea_environment.hide()


func activate() -> void:
	_active = true
	get_tree().paused = false
	_sea_environment.show()
	_gameplay_ui.visible = true
	_pause_overlay.close_overlay()
	_level.activate()
	_play_gameplay_music()


func deactivate() -> void:
	_active = false
	get_tree().paused = false
	_pause_overlay.close_overlay()
	_gameplay_ui.visible = false
	_gameplay_music.stop()
	_sea_environment.hide()
	_level.deactivate()


func apply_accessibility_settings(show_control_hints: bool, screen_shake_scale: float) -> void:
	_hint.visible = show_control_hints
	_level.set_screen_shake_scale(screen_shake_scale)


func _play_gameplay_music() -> void:
	if _gameplay_music.stream == null:
		return
	_gameplay_music.stream_paused = false
	if not _gameplay_music.playing:
		_gameplay_music.play()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"pause"):
		if get_tree().paused:
			get_tree().paused = false
			_pause_overlay.close_overlay()
		else:
			get_tree().paused = true
			_pause_overlay.open_overlay()
		get_viewport().set_input_as_handled()


func _on_pause_menu_requested() -> void:
	get_tree().paused = false
	menu_requested.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = [
		"[GameplayContext]",
		"active=%s" % str(_active),
		"environment_visible=%s" % str(_sea_environment.visible),
		"ui_visible=%s" % str(_gameplay_ui.visible),
		"control_hint_visible=%s" % str(_hint.visible),
		"music_playing=%s" % str(_gameplay_music.playing),
		"paused=%s" % str(get_tree().paused),
	]
	lines.append_array(_level.get_debug_lines())
	return lines
