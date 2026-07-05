class_name GameplayContextV2
extends Node

signal menu_requested

@onready var _level: SeaOfPillarsV2 = %SeaOfPillarsV2
@onready var _gameplay_music: AudioStreamPlayer = %GameplayMusic
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_on_resume_button_pressed)
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_pause_overlay.hide()


func activate() -> void:
	show()
	get_tree().paused = false
	_level.activate()
	if _gameplay_music.stream != null and not _gameplay_music.playing:
		_gameplay_music.play()


func deactivate() -> void:
	get_tree().paused = false
	_pause_overlay.hide()
	_gameplay_music.stop()
	_level.deactivate()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_pause_overlay.visible = is_paused
	if is_paused:
		_resume_button.grab_focus()


func _on_resume_button_pressed() -> void:
	_set_paused(false)


func _on_menu_button_pressed() -> void:
	_set_paused(false)
	menu_requested.emit()
