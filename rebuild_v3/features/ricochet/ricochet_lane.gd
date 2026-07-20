class_name CotcRicochetLane
extends Area2D

## Designer-placed lane that allows Hylas's Speed Run ricochet maneuver.
## The lane only enables ricochet; Hylas still requires a fresh Shift/action_a
## tap and a valid wall collision before each shoulder-bump bounce.

const RICOCHET_LANE_GROUP: StringName = &"ricochet_lane"
const DEFAULT_SURFACE_GROUP: StringName = &"ricochet_surface"
const NON_RICOCHET_SURFACE_GROUP: StringName = &"non_ricochet_surface"
const HAZARD_SURFACE_GROUP: StringName = &"hazard_surface"

@export_category("Ricochet Tuning")
@export_range(100.0, 3000.0, 10.0) var bounce_speed: float = 1120.0
@export_range(0.05, 1.00, 0.01) var queue_seconds: float = 0.42
@export_range(0.00, 1.00, 0.01) var post_bounce_queue_grace: float = 0.30
@export_range(0.02, 0.50, 0.01) var minimum_time_between_bounces: float = 0.10
@export_range(0.05, 1.00, 0.01) var wall_minimum_dot: float = 0.25
@export_range(0.10, 2.00, 0.05) var vertical_bias_strength: float = 1.0
@export_range(0.05, 2.00, 0.05) var speed_multiplier: float = 1.0
@export_range(0.0, 48.0, 1.0) var wall_separation: float = 8.0

@export_category("Surface Rules")
@export var require_surface_group: bool = false
@export var surface_group: StringName = DEFAULT_SURFACE_GROUP
@export var allow_hazard_surfaces: bool = false


func _ready() -> void:
	add_to_group(RICOCHET_LANE_GROUP)
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func allows_ricochet_surface(surface: Node) -> bool:
	if not is_instance_valid(surface):
		return false
	if surface.is_in_group(NON_RICOCHET_SURFACE_GROUP):
		return false
	if surface.is_in_group(HAZARD_SURFACE_GROUP) and not allow_hazard_surfaces:
		return false
	if require_surface_group and not surface.is_in_group(surface_group):
		return false
	return true


func _on_body_entered(body: Node2D) -> void:
	if body == null or not body.has_method(&"enter_ricochet_lane"):
		return
	body.call(&"enter_ricochet_lane", self)


func _on_body_exited(body: Node2D) -> void:
	if body == null or not body.has_method(&"exit_ricochet_lane"):
		return
	body.call(&"exit_ricochet_lane", self)
