class_name CotcDeathOverlay
extends Control

## Gameplay-owned death menu. It intentionally does not pause the tree so the
## limp Hylas animation and seabed drift remain visible behind the choices.

signal continue_requested
signal menu_requested
signal exit_requested

@onready var _continue_button: Button = %ContinueButton
@onready var _menu_button: Button = %MenuButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_button.pressed.connect(_on_continue_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	close_overlay()


func open_overlay() -> void:
	visible = true
	_continue_button.grab_focus()


func close_overlay() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_exit_pressed() -> void:
	exit_requested.emit()
