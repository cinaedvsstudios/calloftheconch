class_name StateMachine
extends Node
## Optional finite state machine. Add State children and choose one as
## initial_state in the Inspector.

@export var initial_state: State

var current_state: State
var _states: Dictionary = {}


func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			var state: State = child as State
			_states[StringName(state.name)] = state
			state.transition_requested.connect(_on_transition_requested)

	if initial_state == null and not _states.is_empty():
		initial_state = _states.values()[0] as State

	current_state = initial_state
	if current_state != null:
		current_state.enter(null)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


func change_state(next_state_name: StringName) -> void:
	var next_state: Variant = _states.get(next_state_name)
	if not next_state is State:
		push_warning("StateMachine has no state named '%s'." % next_state_name)
		return

	if next_state == current_state:
		return

	var previous_state: State = current_state
	if previous_state != null:
		previous_state.exit()

	current_state = next_state as State
	current_state.enter(previous_state)


func _on_transition_requested(next_state_name: StringName) -> void:
	change_state(next_state_name)
