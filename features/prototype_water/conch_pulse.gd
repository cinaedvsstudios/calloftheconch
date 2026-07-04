class_name ConchPulse
extends Node2D
## Temporary visual-only pulse for the Normal Conch's prototype range.

const ARC_HALF_ANGLE: float = 1.08
const ARC_SEGMENTS: int = 42

var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _max_range: float = 700.0
var _pulse_duration: float = 0.52
var _line_width: float = 4.0


func _ready() -> void:
	set_process(false)
	hide()


func trigger(origin: Vector2, direction: Vector2, tuning: PrototypeTuning) -> void:
	global_position = origin
	_direction = direction.normalized()
	if _direction.length_squared() <= 0.001:
		_direction = Vector2.RIGHT
	_max_range = tuning.conch_range
	_pulse_duration = tuning.conch_pulse_duration
	_line_width = tuning.conch_line_width
	_elapsed = 0.0
	show()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _pulse_duration:
		set_process(false)
		hide()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / _pulse_duration, 0.0, 1.0)
	var radius: float = lerpf(18.0, _max_range, progress)
	var alpha: float = 1.0 - progress
	var center_angle: float = _direction.angle()
	var start_angle: float = center_angle - ARC_HALF_ANGLE
	var end_angle: float = center_angle + ARC_HALF_ANGLE
	var pulse_color: Color = Color(0.30, 0.86, 1.0, alpha * 0.82)
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, ARC_SEGMENTS, pulse_color, _line_width, true)
