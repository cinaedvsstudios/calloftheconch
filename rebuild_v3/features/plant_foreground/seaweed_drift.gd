class_name CotcSeaweedDrift
extends AnimatedSprite2D

## Adds a slow local drift loop without replacing the seaweed frame animation.

@export_category("Drift")
@export var drift_radius: Vector2 = Vector2(52.0, 24.0)
@export_range(2.0, 30.0, 0.1) var drift_period_seconds: float = 8.0
@export_range(0.0, 12.0, 0.1) var rotation_amplitude_degrees: float = 2.5

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _elapsed: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	var phase_seed: int = absi(hash(str(get_path()))) % 10000
	_phase = (float(phase_seed) / 10000.0) * TAU


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	var cycle: float = (
		_elapsed / maxf(0.1, drift_period_seconds) * TAU
		+ _phase
	)
	position = _base_position + Vector2(
		sin(cycle) * drift_radius.x,
		sin(cycle * 0.73 + 1.7) * drift_radius.y,
	)
	rotation = _base_rotation + deg_to_rad(
		sin(cycle * 0.61 + 0.9) * rotation_amplitude_degrees
	)
