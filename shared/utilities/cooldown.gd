class_name Cooldown
extends RefCounted
## Tiny timer utility for abilities, attacks and interactions.

var duration: float = 0.0
var remaining: float = 0.0


func _init(cooldown_duration: float = 0.0) -> void:
	duration = maxf(0.0, cooldown_duration)


func start(custom_duration: float = -1.0) -> void:
	remaining = duration if custom_duration < 0.0 else maxf(0.0, custom_duration)


func tick(delta: float) -> void:
	remaining = maxf(0.0, remaining - maxf(0.0, delta))


func is_ready() -> bool:
	return remaining <= 0.0


func reset() -> void:
	remaining = 0.0
