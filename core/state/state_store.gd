class_name StateStore
extends Node
## Owns the active GameState. Behavioural systems receive this service explicitly.

signal state_replaced(state: GameState)
signal state_changed(change_key: StringName)

var state: GameState = GameState.new()


func start_new_game() -> void:
	state = GameState.new()
	state_replaced.emit(state)
	state_changed.emit(&"new_game")


func import_save_data(data: Dictionary) -> void:
	state = GameState.from_save_data(data)
	state_replaced.emit(state)
	state_changed.emit(&"save_loaded")


func export_save_data() -> Dictionary:
	return state.to_save_data()


func increment_counter(counter_id: StringName, amount: int = 1) -> int:
	var result: int = state.increment_counter(counter_id, amount)
	state_changed.emit(counter_id)
	return result


func set_flag(flag_id: StringName, value: bool) -> void:
	state.set_flag(flag_id, value)
	state_changed.emit(flag_id)


func advance_play_time(delta_seconds: float) -> void:
	if delta_seconds <= 0.0:
		return

	state.play_time_seconds += delta_seconds
	state_changed.emit(&"play_time_seconds")
