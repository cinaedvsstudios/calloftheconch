class_name MenuContextV2
extends Control

signal start_game_requested
signal exit_requested

@onready var _main_music: AudioStreamPlayer = %MainMusic
@onready var _start_button: Button = %StartButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_exit_button.pressed.connect(_on_exit_button_pressed)


func activate() -> void:
	show()
	_start_button.grab_focus()
	if _main_music.stream != null and not _main_music.playing:
		_main_music.play()


func deactivate() -> void:
	_main_music.stop()
	hide()


func _on_start_button_pressed() -> void:
	start_game_requested.emit()


func _on_exit_button_pressed() -> void:
	exit_requested.emit()
