class_name CotcWhaleTravel
extends Node2D

signal interaction_availability_changed(is_available: bool)
signal travel_requested

@export_category("Movement")
@export_range(0.05, 1.0, 0.01) var drift_screen_fraction: float = 0.5
@export_range(1.0, 500.0, 1.0) var horizontal_speed: float = 48.0
@export_range(0.0, 200.0, 1.0) var bob_amplitude: float = 18.0
@export_range(0.01, 5.0, 0.01) var bob_speed: float = 0.8
@export_range(0.0, 3.0, 0.05) var turn_pause: float = 0.35
@export var source_frames_face_left: bool = true

@onready var _whale_sprite: AnimatedSprite2D = %WhaleSprite
@onready var _interaction_area: Area2D = %InteractionArea

var _origin_position: Vector2
var _drift_distance: float = 960.0
var _travel_direction: float = -1.0
var _turn_pause_remaining: float = 0.0
var _bob_time: float = 0.0
var _hylas_in_range: bool = false


func _ready() -> void:
	_origin_position = position
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)
	_whale_sprite.play(&"swim")
	_apply_facing()
	call_deferred(&"_refresh_drift_distance")


func _process(delta: float) -> void:
	_update_horizontal_drift(delta)
	_update_bob(delta)


func _refresh_drift_distance() -> void:
	var viewport_width: float = get_viewport_rect().size.x
	var active_camera: Camera2D = get_viewport().get_camera_2d()
	if active_camera != null:
		viewport_width /= maxf(0.001, absf(active_camera.zoom.x))
	_drift_distance = maxf(1.0, viewport_width * drift_screen_fraction)


func _update_horizontal_drift(delta: float) -> void:
	if _turn_pause_remaining > 0.0:
		_turn_pause_remaining = maxf(0.0, _turn_pause_remaining - delta)
		return

	position.x += _travel_direction * horizontal_speed * delta
	var left_limit: float = _origin_position.x - _drift_distance
	var right_limit: float = _origin_position.x

	if _travel_direction < 0.0 and position.x <= left_limit:
		position.x = left_limit
		_travel_direction = 1.0
		_turn_pause_remaining = turn_pause
		_apply_facing()
	elif _travel_direction > 0.0 and position.x >= right_limit:
		position.x = right_limit
		_travel_direction = -1.0
		_turn_pause_remaining = turn_pause
		_apply_facing()


func _update_bob(delta: float) -> void:
	_bob_time += delta * bob_speed
	position.y = _origin_position.y + sin(_bob_time) * bob_amplitude


func _apply_facing() -> void:
	var moving_left: bool = _travel_direction < 0.0
	_whale_sprite.flip_h = moving_left != source_frames_face_left


func request_travel() -> bool:
	if not _hylas_in_range:
		return false
	travel_requested.emit()
	return true


func is_hylas_in_interaction_range() -> bool:
	return _hylas_in_range


func _on_interaction_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"hylas"):
		return
	_hylas_in_range = true
	interaction_availability_changed.emit(true)


func _on_interaction_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"hylas"):
		return
	_hylas_in_range = false
	interaction_availability_changed.emit(false)
