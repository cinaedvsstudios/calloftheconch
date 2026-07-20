class_name CotcVacuumVentIntake
extends Area2D

## Pulls Hylas toward a local vent mouth and emits a local capture request once
## he reaches the inner capture area. Transport itself remains owned by the pair.

signal capture_requested(hylas: Node2D)

const TRANSPORT_LOCK_META: StringName = &"vacuum_transport_locked_until_msec"

@export_category("Visual")
@export var play_on_ready: bool = true
@export var loop_video: bool = true

@export_category("Suction Field")
@export_range(-2000.0, 0.0, 1.0) var opening_local_y: float = -520.0
@export_range(100.0, 5000.0, 10.0) var suction_length: float = 1400.0
@export_range(20.0, 3000.0, 10.0) var suction_start_width: float = 280.0
@export_range(20.0, 3000.0, 10.0) var suction_end_width: float = 1120.0
@export_range(0.0, 2400.0, 10.0) var suction_max_speed: float = 920.0
@export_range(0.0, 2400.0, 10.0) var suction_min_speed: float = 130.0
@export_range(0.0, 800.0, 5.0) var swirl_speed: float = 105.0
@export_range(-1.0, 1.0, 1.0) var swirl_direction: float = 1.0
@export_range(0.0, 1.0, 0.05) var tridacna_pull_multiplier: float = 0.35

@export_category("Capture")
@export_range(20.0, 260.0, 1.0) var capture_radius: float = 105.0

@onready var _reverse_bubble_video: VideoStreamPlayer = %ReverseBubbleVideo
@onready var _whirlpool_overlay: CanvasItem = %WhirlpoolOverlay
@onready var _force_collision: CollisionPolygon2D = %ForceCollision
@onready var _capture_area: Area2D = %CaptureArea
@onready var _capture_collision: CollisionShape2D = %CaptureCollision

var _affected_receivers: Dictionary[Node, bool] = {}
var _capture_pending_ids: Dictionary[int, bool] = {}
var _distance_active: bool = true
var _playback_requested: bool = true


func _ready() -> void:
	_configure_force_area()
	_configure_capture_area()
	_reverse_bubble_video.loop = loop_video
	_playback_requested = play_on_ready
	monitoring = true
	_capture_area.monitoring = true
	set_physics_process(true)
	_capture_area.body_entered.connect(_on_capture_body_entered)
	_capture_area.body_exited.connect(_on_capture_body_exited)
	_apply_visual_playback()


func _exit_tree() -> void:
	_clear_affected_receivers()


func set_vent_playing(should_play: bool) -> void:
	_playback_requested = should_play
	_apply_visual_playback()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	set_deferred(&"monitoring", _distance_active)
	_capture_area.set_deferred(&"monitoring", _distance_active)
	_whirlpool_overlay.visible = _distance_active
	if not _distance_active:
		_clear_affected_receivers()
	_apply_visual_playback()


func get_capture_mouth_global_position() -> Vector2:
	return to_global(Vector2(0.0, opening_local_y))


func release_receiver(receiver: Node) -> void:
	_affected_receivers.erase(receiver)
	_remove_current_from_receiver(receiver)


func complete_capture(hylas: Node) -> void:
	if is_instance_valid(hylas):
		_capture_pending_ids.erase(hylas.get_instance_id())
	release_receiver(hylas)


func cancel_capture(hylas: Node) -> void:
	if is_instance_valid(hylas):
		_capture_pending_ids.erase(hylas.get_instance_id())


func _apply_visual_playback() -> void:
	if _distance_active and _playback_requested and _reverse_bubble_video.stream != null:
		if not _reverse_bubble_video.is_playing():
			_reverse_bubble_video.play()
		return
	_reverse_bubble_video.stop()


func _physics_process(_delta: float) -> void:
	var detected_receivers: Dictionary[Node, bool] = {}
	for body: Node2D in get_overlapping_bodies():
		var receiver: Node2D = _find_hylas_receiver(body)
		if receiver == null:
			continue
		if _should_ignore_receiver(receiver):
			_remove_current_from_receiver(receiver)
			continue
		detected_receivers[receiver] = true

	for previous_receiver: Node in _affected_receivers.keys():
		if not detected_receivers.has(previous_receiver):
			_remove_current_from_receiver(previous_receiver)

	for receiver: Node in detected_receivers.keys():
		var receiver_2d: Node2D = receiver as Node2D
		if receiver_2d == null or not is_instance_valid(receiver_2d):
			continue
		receiver_2d.call(
			&"set_external_current",
			self,
			_get_suction_velocity(receiver_2d),
		)

	_affected_receivers = detected_receivers


func _configure_force_area() -> void:
	var half_start_width: float = suction_start_width * 0.5
	var half_end_width: float = suction_end_width * 0.5
	var far_edge_y: float = opening_local_y - suction_length
	_force_collision.polygon = PackedVector2Array([
		Vector2(-half_start_width, opening_local_y),
		Vector2(half_start_width, opening_local_y),
		Vector2(half_end_width, far_edge_y),
		Vector2(-half_end_width, far_edge_y),
	])


func _configure_capture_area() -> void:
	_capture_area.position = Vector2(0.0, opening_local_y)
	var circle: CircleShape2D = _capture_collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		_capture_collision.shape = circle
	circle.radius = capture_radius


func _find_hylas_receiver(candidate: Node) -> Node2D:
	var current_node: Node = candidate
	while current_node != null:
		if (
			current_node is Node2D
			and current_node.is_in_group(&"hylas")
			and current_node.has_method(&"set_external_current")
			and current_node.has_method(&"remove_external_current")
		):
			return current_node as Node2D
		current_node = current_node.get_parent()
	return null


func _should_ignore_receiver(receiver: Node2D) -> bool:
	if not is_instance_valid(receiver):
		return true
	if _capture_pending_ids.has(receiver.get_instance_id()):
		return true
	if _is_transport_locked(receiver):
		return true
	return _is_conus_climbing(receiver)


func _get_suction_velocity(receiver: Node2D) -> Vector2:
	var to_mouth: Vector2 = get_capture_mouth_global_position() - receiver.global_position
	var distance: float = maxf(1.0, to_mouth.length())
	var distance_ratio: float = clampf(distance / suction_length, 0.0, 1.0)
	var pull_speed: float = lerpf(suction_max_speed, suction_min_speed, distance_ratio)
	if _is_tridacna_surge_active(receiver):
		pull_speed *= tridacna_pull_multiplier

	var pull_direction: Vector2 = to_mouth / distance
	var tangent: Vector2 = Vector2(-pull_direction.y, pull_direction.x)
	var inward_strength: float = 1.0 - distance_ratio
	return (
		pull_direction * pull_speed
		+ tangent * swirl_speed * swirl_direction * inward_strength
	)


func _on_capture_body_entered(body: Node2D) -> void:
	var hylas: Node2D = _find_hylas_receiver(body)
	if hylas == null or _is_transport_locked(hylas) or _is_conus_climbing(hylas):
		return
	var instance_id: int = hylas.get_instance_id()
	if _capture_pending_ids.has(instance_id):
		return
	_capture_pending_ids[instance_id] = true
	release_receiver(hylas)
	call_deferred(&"_emit_capture_request", hylas)


func _on_capture_body_exited(body: Node2D) -> void:
	var hylas: Node2D = _find_hylas_receiver(body)
	if hylas != null:
		_capture_pending_ids.erase(hylas.get_instance_id())


func _emit_capture_request(hylas: Node2D) -> void:
	if not is_instance_valid(hylas):
		return
	if not _capture_area.overlaps_body(hylas):
		_capture_pending_ids.erase(hylas.get_instance_id())
		return
	capture_requested.emit(hylas)


func _is_tridacna_surge_active(hylas: Node) -> bool:
	return (
		is_instance_valid(hylas)
		and hylas.has_method(&"is_item_surge_active")
		and bool(hylas.call(&"is_item_surge_active"))
	)


func _is_conus_climbing(hylas: Node) -> bool:
	return (
		is_instance_valid(hylas)
		and hylas.has_method(&"is_conus_wall_climbing")
		and bool(hylas.call(&"is_conus_wall_climbing"))
	)


func _is_transport_locked(hylas: Node) -> bool:
	if not is_instance_valid(hylas) or not hylas.has_meta(TRANSPORT_LOCK_META):
		return false
	var locked_until_msec: int = int(hylas.get_meta(TRANSPORT_LOCK_META, 0))
	if Time.get_ticks_msec() < locked_until_msec:
		return true
	hylas.remove_meta(TRANSPORT_LOCK_META)
	return false


func _clear_affected_receivers() -> void:
	for receiver: Node in _affected_receivers.keys():
		_remove_current_from_receiver(receiver)
	_affected_receivers.clear()


func _remove_current_from_receiver(receiver: Node) -> void:
	if is_instance_valid(receiver) and receiver.has_method(&"remove_external_current"):
		receiver.call(&"remove_external_current", self)


func get_debug_lines() -> Array[String]:
	return [
		"vacuum_intake_active=%s" % str(_distance_active),
		"vacuum_intake_receivers=%d" % _affected_receivers.size(),
		"vacuum_capture_pending=%d" % _capture_pending_ids.size(),
		"vacuum_suction_min=%.1f" % suction_min_speed,
		"vacuum_suction_max=%.1f" % suction_max_speed,
	]
