class_name ConchPulseV2
extends Node2D

@export_category("Pulse")
@export var start_diameter: float = 20.0
@export var pulse_range: float = 700.0
@export var pulse_duration: float = 0.52
@export var start_width: float = 5.0
@export var end_width: float = 1.0

@onready var _ring: Line2D = %Ring

var _elapsed: float = 0.0
var _active: bool = false
var _ring_reference_radius: float = 1.0


func _ready() -> void:
	_ring_reference_radius = _measure_ring_reference_radius()
	_ring.width = start_width
	hide()
	set_process(false)


func trigger(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	rotation = direction.angle()
	_elapsed = 0.0
	_active = true
	_apply_diameter(start_diameter)
	modulate.a = 1.0
	show()
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed = minf(pulse_duration, _elapsed + delta)
	var progress: float = _elapsed / maxf(0.01, pulse_duration)
	_apply_diameter(lerpf(start_diameter, pulse_range, progress))
	modulate.a = 1.0 - progress
	_ring.width = lerpf(start_width, end_width, progress)
	if _elapsed >= pulse_duration:
		_active = false
		hide()
		set_process(false)


func _apply_diameter(diameter: float) -> void:
	scale = Vector2.ONE * ((diameter * 0.5) / _ring_reference_radius)


func _measure_ring_reference_radius() -> float:
	var largest_distance: float = 1.0
	for point: Vector2 in _ring.points:
		largest_distance = maxf(largest_distance, point.length())
	return largest_distance
