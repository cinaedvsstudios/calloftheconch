class_name PauseService
extends Node
## Stores pause state. GameplayContext chooses the input that requests it.

signal pause_changed(is_paused: bool)

var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_paused(should_pause: bool) -> void:
	if is_paused == should_pause:
		return

	is_paused = should_pause
	get_tree().paused = should_pause
	pause_changed.emit(is_paused)


func toggle_pause() -> void:
	set_paused(not is_paused)
