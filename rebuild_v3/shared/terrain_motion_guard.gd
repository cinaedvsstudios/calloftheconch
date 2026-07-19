class_name CotcTerrainMotionGuard
extends Node

## Corrects direct global_position movement after the target has processed. This
## lets older Area2D drift scripts obey terrain without replacing their gameplay
## logic or changing their root node type.

@export var target_path: NodePath = ^".."
@export_flags_2d_physics var terrain_collision_mask: int = 1
@export_range(4.0, 400.0, 1.0) var terrain_collision_radius: float = 72.0
@export_range(0.0, 12.0, 0.5) var terrain_margin: float = 2.0
@export_range(50.0, 5000.0, 10.0) var teleport_distance: float = 900.0
@export var velocity_properties: PackedStringArray = PackedStringArray()
@export var retarget_method: StringName = StringName()

var _target: Node2D
var _previous_global_position: Vector2 = Vector2.ZERO
var _has_previous_position: bool = false
var _inside_terrain_warning_sent: bool = false


func _ready() -> void:
	process_physics_priority = 100
	_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		push_error("CotcTerrainMotionGuard could not resolve its target Node2D.")
		set_physics_process(false)
		return
	_previous_global_position = _target.global_position
	_has_previous_position = true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target):
		set_physics_process(false)
		return
	if not _has_previous_position:
		_previous_global_position = _target.global_position
		_has_previous_position = true
		return

	var desired_position: Vector2 = _target.global_position
	var attempted_motion: Vector2 = desired_position - _previous_global_position
	if attempted_motion.length() >= teleport_distance:
		_previous_global_position = desired_position
		return
	if attempted_motion.length_squared() <= 0.000001:
		_previous_global_position = desired_position
		return

	_target.global_position = _previous_global_position
	var result: Dictionary = CotcTerrainSafeMotion.move_circle(
		_target,
		attempted_motion,
		terrain_collision_radius,
		terrain_collision_mask,
		terrain_margin,
		2,
	)
	_previous_global_position = _target.global_position
	if not bool(result.get(&"blocked", false)):
		return

	var normal: Vector2 = result.get(&"normal", Vector2.ZERO)
	_slide_velocity_properties(normal)
	if bool(result.get(&"started_overlapping", false)):
		if not _inside_terrain_warning_sent:
			_inside_terrain_warning_sent = true
			push_warning("%s started inside terrain; move the placed instance into open water." % _target.name)
		return
	if retarget_method != StringName() and _target.has_method(retarget_method):
		_target.call(retarget_method, false)


func reset_after_teleport() -> void:
	if is_instance_valid(_target):
		_previous_global_position = _target.global_position
		_has_previous_position = true


func _slide_velocity_properties(normal: Vector2) -> void:
	if normal.length_squared() <= 0.001:
		return
	for property_name: String in velocity_properties:
		var current_value: Variant = _target.get(property_name)
		if current_value is Vector2:
			var velocity: Vector2 = current_value
			_target.set(property_name, velocity.slide(normal))
