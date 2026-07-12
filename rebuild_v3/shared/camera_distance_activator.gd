class_name CotcCameraDistanceActivator
extends Node

## Keeps expensive scene behaviour awake only near the active Camera2D.
## The target decides exactly what sleeping means through set_distance_active().

signal activation_changed(is_active: bool)

@export var target_path: NodePath = NodePath("..")
@export_category("Camera Distance")
@export var wake_margin_screens: Vector2 = Vector2(2.0, 2.0)
@export var sleep_margin_screens: Vector2 = Vector2(2.25, 2.25)
@export_range(0.05, 2.0, 0.05) var check_interval: float = 0.25
@export var stay_active_without_camera: bool = true

var _target: Node2D
var _distance_active: bool = true
var _check_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		push_error("CotcCameraDistanceActivator requires a Node2D target at %s." % target_path)
		set_process(false)
		return
	call_deferred(&"refresh_now")


func _process(delta: float) -> void:
	_check_elapsed += delta
	if _check_elapsed < check_interval:
		return
	_check_elapsed = fmod(_check_elapsed, maxf(0.05, check_interval))
	refresh_now()


func refresh_now() -> void:
	if not is_instance_valid(_target):
		set_process(false)
		return
	if not _target.is_visible_in_tree():
		_apply_distance_active(false)
		return

	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		if stay_active_without_camera:
			_apply_distance_active(true)
		return

	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var camera_zoom: Vector2 = Vector2(
		maxf(0.001, absf(camera.zoom.x)),
		maxf(0.001, absf(camera.zoom.y)),
	)
	var visible_world_size: Vector2 = Vector2(
		viewport_size.x / camera_zoom.x,
		viewport_size.y / camera_zoom.y,
	)
	var margin_screens: Vector2 = sleep_margin_screens if _distance_active else wake_margin_screens
	var allowed_offset: Vector2 = visible_world_size * 0.5 + visible_world_size * margin_screens
	var camera_centre: Vector2 = camera.get_screen_center_position()
	var target_offset: Vector2 = _target.global_position - camera_centre
	var should_be_active: bool = (
		absf(target_offset.x) <= allowed_offset.x
		and absf(target_offset.y) <= allowed_offset.y
	)
	_apply_distance_active(should_be_active)


func is_distance_active() -> bool:
	return _distance_active


func _apply_distance_active(should_be_active: bool) -> void:
	if should_be_active == _distance_active:
		return
	_distance_active = should_be_active
	if _target.has_method(&"set_distance_active"):
		_target.call(&"set_distance_active", _distance_active)
	else:
		_target.set_process(_distance_active)
		_target.set_physics_process(_distance_active)
	activation_changed.emit(_distance_active)
