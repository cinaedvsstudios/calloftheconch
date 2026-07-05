class_name PauseOverlayV2
extends Control

signal menu_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_resume)
	_menu_button.pressed.connect(_menu)
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		visible = not visible
		get_tree().paused = visible
		get_viewport().set_input_as_handled()

func _resume() -> void:
	get_tree().paused = false
	hide()

func _menu() -> void:
	get_tree().paused = false
	hide()
	menu_requested.emit()
