class_name GameState
extends RefCounted
## Long-lived, serialisable game data. Keep node/UI/audio behaviour out of here.
## Replace the demonstration counters/flags with the real domains of each game.

const SAVE_SCHEMA_VERSION: int = 1

var schema_version: int = SAVE_SCHEMA_VERSION
var current_level_id: StringName = &""
var counters: Dictionary = {}
var flags: Dictionary = {}
var play_time_seconds: float = 0.0


func reset() -> void:
	schema_version = SAVE_SCHEMA_VERSION
	current_level_id = &""
	counters.clear()
	flags.clear()
	play_time_seconds = 0.0


func increment_counter(counter_id: StringName, amount: int = 1) -> int:
	var current_value: int = get_counter(counter_id)
	var new_value: int = current_value + amount
	counters[str(counter_id)] = new_value
	return new_value


func get_counter(counter_id: StringName) -> int:
	return int(counters.get(str(counter_id), 0))


func set_flag(flag_id: StringName, value: bool) -> void:
	flags[str(flag_id)] = value


func get_flag(flag_id: StringName, fallback: bool = false) -> bool:
	return bool(flags.get(str(flag_id), fallback))


func to_save_data() -> Dictionary:
	return {
		"schema_version": schema_version,
		"current_level_id": str(current_level_id),
		"counters": counters.duplicate(true),
		"flags": flags.duplicate(true),
		"play_time_seconds": play_time_seconds,
	}


static func from_save_data(data: Dictionary) -> GameState:
	var result: GameState = GameState.new()
	result.schema_version = int(data.get("schema_version", SAVE_SCHEMA_VERSION))
	result.current_level_id = StringName(str(data.get("current_level_id", "")))

	var saved_counters: Variant = data.get("counters", {})
	if saved_counters is Dictionary:
		result.counters = (saved_counters as Dictionary).duplicate(true)

	var saved_flags: Variant = data.get("flags", {})
	if saved_flags is Dictionary:
		result.flags = (saved_flags as Dictionary).duplicate(true)

	result.play_time_seconds = maxf(0.0, float(data.get("play_time_seconds", 0.0)))
	return result
