class_name CotcVent1
extends Area2D

## Reusable hydrothermal vent. Its force area begins at the visual mouth and
## follows the root node's local upward axis, so rotating the placed vent also
## rotates the current direction. Any overlapping body or area that implements
## set_external_current() and remove_external_current() can receive the force.

@export_category("Visual")
@export var play_on_ready: bool = true
@export var loop_video: bool = true

@export_category("Vent Tier")
@export_range(1, 3, 1) var strength_tier: int = 1
@export_range(0.10, 4.00, 0.05) var strength_multiplier: float = 1.0
@export_range(1.00, 3.00, 0.05) var surface_jump_multiplier: float = 1.0
@export_range(1.00, 2.00, 0.05) var surface_jump_duration_multiplier: float = 1.0

@export_category("Vent Current")
@export_range(-2000.0, 0.0, 1.0) var opening_local_y: float = -520.0
@export_range(50.0, 5000.0, 10.0) var force_length: float = 1100.0
@export_range(10.0, 3000.0, 10.0) var force_start_width: float = 260.0
@export_range(10.0, 3000.0, 10.0) var force_end_width: float = 900.0
@export_range(0.0, 2000.0, 10.0) var force_max_speed: float = 680.0
@export_range(0.0, 2000.0, 10.0) var force_min_speed: float = 180.0

@onready var _vent_video: VideoStreamPlayer = %VentVideo
@onready var _force_collision: CollisionPolygon2D = %ForceCollision

var _affected_receivers: Dictionary = {}
var _distance_active: bool = true
var _playback_requested: bool = true


func _ready() -> void:
	_configure_force_area()
	_vent_video.loop = loop_video
	_playback_requested = play_on_ready
	monitoring = true
	set_physics_process(true)
	_apply_video_playback()


func _exit_tree() -> void:
	_clear_affected_receivers()


func set_vent_playing(should_play: bool) -> void:
	_playback_requested = should_play
	_apply_video_playback()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitoring = _distance_active
	if not _distance_active:
		_clear_affected_receivers()
	_apply_video_playback()


func get_surface_jump_multiplier() -> float:
	return surface_jump_multiplier


func get_surface_jump_duration_multiplier() -> float:
	return surface_jump_duration_multiplier


func get_strength_multiplier() -> float:
	return strength_multiplier


func _apply_video_playback() -> void:
	if _distance_active and _playback_requested and _vent_video.stream != null:
		if not _vent_video.is_playing():
			_vent_video.play()
		return
	_vent_video.stop()


func _physics_process(_delta: float) -> void:
	var detected_receivers: Dictionary = {}
	for body: Node2D in get_overlapping_bodies():
		_collect_receiver(body, detected_receivers)
	for area: Area2D in get_overlapping_areas():
		if area != self:
			_collect_receiver(area, detected_receivers)

	for previous_receiver: Node in _affected_receivers.keys():
		if not detected_receivers.has(previous_receiver):
			_remove_current_from_receiver(previous_receiver)

	for receiver: Node in detected_receivers.keys():
		if not is_instance_valid(receiver):
			continue
		var receiver_2d: Node2D = receiver as Node2D
		if receiver_2d == null:
			continue
		receiver.call(
			&"set_external_current",
			self,
			_get_current_velocity(receiver_2d.global_position),
		)

	_affected_receivers = detected_receivers


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


func _collect_receiver(candidate: Node, receivers: Dictionary) -> void:
	var receiver: Node2D = _find_current_receiver(candidate)
	if receiver != null and receiver != self:
		receivers[receiver] = true


func _find_current_receiver(candidate: Node) -> Node2D:
	var current_node: Node = candidate
	while current_node != null:
		if (
			current_node is Node2D
			and current_node.has_method(&"set_external_current")
			and current_node.has_method(&"remove_external_current")
		):
			return current_node as Node2D
		current_node = current_node.get_parent()
	return null


func _get_current_velocity(receiver_position: Vector2) -> Vector2:
	var local_receiver_position: Vector2 = to_local(receiver_position)
	var distance_from_mouth: float = -(local_receiver_position.y - opening_local_y)
	var distance_ratio: float = clampf(distance_from_mouth / force_length, 0.0, 1.0)
	var force_speed: float = lerpf(force_max_speed, force_min_speed, distance_ratio)
	var emission_direction: Vector2 = global_transform.basis_xform(Vector2.UP).normalized()
	return emission_direction * force_speed * strength_multiplier


func _clear_affected_receivers() -> void:
	for receiver: Node in _affected_receivers.keys():
		_remove_current_from_receiver(receiver)
	_affected_receivers.clear()


func _remove_current_from_receiver(receiver: Node) -> void:
	if is_instance_valid(receiver) and receiver.has_method(&"remove_external_current"):
		receiver.call(&"remove_external_current", self)
