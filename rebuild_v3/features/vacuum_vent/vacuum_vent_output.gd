class_name CotcVacuumVentOutput
extends "res://rebuild_v3/features/vent1/vent1.gd"

## A normal strong Vent 2 output with an explicit ejection marker used by its
## locally owned pair controller.

@export_category("Linked Ejection")
@export_range(100.0, 2400.0, 10.0) var transport_launch_speed: float = 980.0
@export_range(20.0, 500.0, 5.0) var emergence_distance: float = 185.0

@onready var _exit_marker: Marker2D = %ExitMarker


func get_exit_global_position() -> Vector2:
	return _exit_marker.global_position


func get_launch_direction() -> Vector2:
	var direction: Vector2 = global_transform.basis_xform(Vector2.UP).normalized()
	return direction if direction.length_squared() > 0.0001 else Vector2.UP


func get_transport_launch_velocity() -> Vector2:
	return get_launch_direction() * transport_launch_speed


func get_emergence_target_global_position() -> Vector2:
	return get_exit_global_position() + get_launch_direction() * emergence_distance


func get_debug_lines() -> Array[String]:
	var direction: Vector2 = get_launch_direction()
	return [
		"vacuum_output_launch_speed=%.1f" % transport_launch_speed,
		"vacuum_output_emergence_distance=%.1f" % emergence_distance,
		"vacuum_output_direction=(%.3f, %.3f)" % [direction.x, direction.y],
	]
