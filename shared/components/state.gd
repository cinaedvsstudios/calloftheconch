class_name State
extends Node
## Optional reusable finite-state-machine state.
## Subclass this and override enter/exit/update/physics_update/handle_input.

signal transition_requested(next_state_name: StringName)


func enter(_previous_state: State) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func request_transition(next_state_name: StringName) -> void:
	transition_requested.emit(next_state_name)
