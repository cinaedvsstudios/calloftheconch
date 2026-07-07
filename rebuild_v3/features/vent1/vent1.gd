class_name CotcVent1
extends Area2D

## Reusable hydrothermal vent. Its force area begins at the visual mouth and
## follows the root node's local upward axis, so rotating the placed vent also
## rotates the current direction.

@export_category("Visual")
@export var play_on_ready: bool = true
@export var loop_video: bool = true

@export_category("Vent Current")
@export_range(-2000.0, 0.0, 1.0) var opening_local_y: float = -520.0
@export_range(50.0, 5000.0, 10.0) var force_length: float = 1100.0
@export_range(10.0, 3000.0, 10.0) var force_start_width: float = 260.0
@export_range(10.0, 3000.0, 10.0) var force_end_width: float = 900.0
@export_range(0.0, 2000.0, 10.0) var force_max_speed: float = 680.0
@export_range(0.0, 2000.0, 10.0) var force_min_speed: float = 180.0

@onready var _vent_video: VideoStreamPlayer = %VentVideo
@onready var _force_collision: CollisionPolygon2D = %ForceCollision

var _hylas: CotcHylas


func _ready() -> void:
	_configure_force_area()
	_vent_video.loop = loop_video
	if play_on_ready:
		_vent_video.play()
	set_physics_process(true)


func _exit_tree() -> void:
	_remove_current_from_hylas()


func set_vent_playing(should_play: bool) -> void:
	if should_play:
		_vent_video.play()
	else:
		_vent_video.stop()


func _physics_process(_delta: float) -> void:
	var detected_hylas: CotcHylas = _find_hylas_in_force_area()
	if detected_hylas != _hylas:
		_remove_current_from_hylas()
		_hylas = detected_hylas
	if is_instance_valid(_hylas):
		_hylas.set_external_current(self, _get_current_velocity())


func _configure_force_area() -> void:
	var half_start_width: float = force_start_width * 0.5
	var half_end_width: float = force_end_width * 0.5
	var far_edge_y: float = opening_local_y - force_length
	_force_collision.polygon = PackedVector2Array([
		Vector2(-half_start_width, opening_local_y),
		Vector2(half_start_width, opening_local_y),
		Vector2(half_end_width, far_edge_y),
		Vector2(-half_end_width, far_edge_y),
	])


func _find_hylas_in_force_area() -> CotcHylas:
	for body: Node2D in get_overlapping_bodies():
		if body is CotcHylas:
			return body as CotcHylas
	return null


func _get_current_velocity() -> Vector2:
	var local_hylas_position: Vector2 = to_local(_hylas.global_position)
	var distance_from_mouth: float = -(local_hylas_position.y - opening_local_y)
	var distance_ratio: float = clampf(distance_from_mouth / force_length, 0.0, 1.0)
	var force_speed: float = lerpf(force_max_speed, force_min_speed, distance_ratio)
	var emission_direction: Vector2 = global_transform.basis_xform(Vector2.UP).normalized()
	return emission_direction * force_speed


func _remove_current_from_hylas() -> void:
	if is_instance_valid(_hylas):
		_hylas.remove_external_current(self)
