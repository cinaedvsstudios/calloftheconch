class_name CotcPauseOverlay
extends Control

signal settings_requested
signal menu_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(close_overlay)
	_settings_button.pressed.connect(_open_settings)
	_menu_button.pressed.connect(_menu)
	hide()


func open_overlay() -> void:
	show()
	_resume_button.grab_focus()


func close_overlay() -> void:
	hide()


func _open_settings() -> void:
	hide()
	settings_requested.emit()


func _menu() -> void:
	hide()
	menu_requested.emit()
