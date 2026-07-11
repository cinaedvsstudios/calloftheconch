class_name CotcConchPulse
extends Node2D

@export_category("Directional Pulse")
@export var start_diameter: float = 20.0
@export var pulse_range: float = 700.0
@export var pulse_duration: float = 0.52
@export_range(1.0, 180.0, 0.5) var arc_degrees: float = 45.0
@export_range(0.0, 30.0, 0.5) var arc_edge_softness_degrees: float = 4.0
@export_range(0.0, 8.0, 0.05) var sonar_brightness: float = 1.35

@export_category("Origin Flash")
@export_range(0.05, 2.0, 0.01) var flash_scale: float = 0.35

@onready var _sonar_arc: Sprite2D = %SonarArc
@onready var _origin_flash: VideoStreamPlayer = %OriginFlash

var _elapsed: float = 0.0
var _pulse_active: bool = false
var _flash_active: bool = false
var _pulse_reference_diameter: float = 1.0
var _pulse_material: ShaderMaterial


func _ready() -> void:
	_prepare_pulse_material()
	_measure_pulse_reference_diameter()
	_origin_flash.loop = false
	_origin_flash.scale = Vector2.ONE * flash_scale
	_origin_flash.finished.connect(_on_origin_flash_finished)
	_sonar_arc.hide()
	_origin_flash.hide()
	hide()
	set_process(false)


func trigger(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	show()

	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()

	_sonar_arc.rotation = pulse_direction.angle()
	_elapsed = 0.0
	_pulse_active = true
	_apply_diameter(start_diameter)
	_sonar_arc.modulate.a = 1.0
	_sonar_arc.show()
	_play_origin_flash()
	set_process(true)


func _process(delta: float) -> void:
	if not _pulse_active:
		return

	_elapsed = minf(pulse_duration, _elapsed + delta)
	var progress: float = _elapsed / maxf(0.01, pulse_duration)
	_apply_diameter(lerpf(start_diameter, pulse_range, progress))
	_sonar_arc.modulate.a = 1.0 - progress

	if _elapsed >= pulse_duration:
		_pulse_active = false
		_sonar_arc.hide()
		set_process(false)
		_hide_when_finished()


func _prepare_pulse_material() -> void:
	var source_material: ShaderMaterial = _sonar_arc.material as ShaderMaterial
	if source_material == null:
		return
	_pulse_material = source_material.duplicate() as ShaderMaterial
	_sonar_arc.material = _pulse_material
	_pulse_material.set_shader_parameter(&"arc_degrees", arc_degrees)
	_pulse_material.set_shader_parameter(&"edge_softness_degrees", arc_edge_softness_degrees)
	_pulse_material.set_shader_parameter(&"brightness", sonar_brightness)


func _measure_pulse_reference_diameter() -> void:
	if _sonar_arc.texture == null:
		_pulse_reference_diameter = 1.0
		return
	var texture_size: Vector2 = _sonar_arc.texture.get_size()
	_pulse_reference_diameter = maxf(1.0, maxf(texture_size.x, texture_size.y))


func _apply_diameter(diameter: float) -> void:
	var scale_factor: float = maxf(0.0, diameter) / _pulse_reference_diameter
	_sonar_arc.scale = Vector2.ONE * scale_factor


func _play_origin_flash() -> void:
	if _origin_flash.stream == null:
		_flash_active = false
		_origin_flash.hide()
		return
	_flash_active = true
	_origin_flash.stop()
	_origin_flash.show()
	_origin_flash.play()


func _on_origin_flash_finished() -> void:
	_flash_active = false
	_origin_flash.hide()
	_hide_when_finished()


func _hide_when_finished() -> void:
	if not _pulse_active and not _flash_active:
		hide()
