class_name ConchPulseV2
extends Node2D

@export var pulse_range: float = 700.0
@export var pulse_duration: float = 0.52

@onready var _ring: Line2D = %Ring

var _elapsed: float = 0.0
var _active: bool = false


func _ready() -> void:
	hide()
	set_process(false)


func trigger(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	rotation = direction.angle()
	_elapsed = 0.0
	_active = true
	scale = Vector2.ONE * 0.05
	modulate.a = 1.0
	show()
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed = minf(pulse_duration, _elapsed + delta)
	var progress: float = _elapsed / maxf(0.01, pulse_duration)
	var diameter: float = lerpf(20.0, pulse_range, progress)
	scale = Vector2.ONE * (diameter / 200.0)
	modulate.a = 1.0 - progress
	_ring.width = lerpf(5.0, 1.0, progress)
	if _elapsed >= pulse_duration:
		_active = false
		hide()
		set_process(false)
