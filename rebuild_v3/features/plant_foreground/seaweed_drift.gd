class_name CotcSeaweedDrift
extends AnimatedSprite2D

## Adds a slow local drift loop without replacing the seaweed frame animation.
## The loop reverses at terrain instead of carrying the plant through rocks.

@export_category("Drift")
@export var drift_radius: Vector2 = Vector2(52.0, 24.0)
@export_range(2.0, 30.0, 0.1) var drift_period_seconds: float = 8.0
@export_range(0.0, 12.0, 0.1) var rotation_amplitude_degrees: float = 2.5

@export_category("Terrain Avoidance")
@export_flags_2d_physics var terrain_collision_mask: int = 1
@export_range(4.0, 180.0, 1.0) var terrain_collision_radius: float = 46.0
@export_range(0.0, 12.0, 0.5) var terrain_margin: float = 1.5

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _elapsed: float = 0.0
var _phase: float = 0.0
var _cycle_direction: float = 1.0
var _inside_terrain_warning_sent: bool = false


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	var phase_seed: int = absi(hash(str(get_path()))) % 10000
	_phase = (float(phase_seed) / 10000.0) * TAU


func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta) * _cycle_direction
	var cycle: float = (
		_elapsed / maxf(0.1, drift_period_seconds) * TAU
		+ _phase
	)
	var desired_local_position := _base_position + Vector2(
		sin(cycle) * drift_radius.x,
		sin(cycle * 0.73 + 1.7) * drift_radius.y,
	)
	var desired_global_position: Vector2 = desired_local_position
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d != null:
		desired_global_position = parent_2d.to_global(desired_local_position)

	var intended_motion: Vector2 = desired_global_position - global_position
	var motion_result: Dictionary = CotcTerrainSafeMotion.move_circle(
		self,
		intended_motion,
		terrain_collision_radius,
		terrain_collision_mask,
		terrain_margin,
		2,
	)
	if bool(motion_result.get(&"blocked", false)):
		_cycle_direction *= -1.0
		if bool(motion_result.get(&"started_overlapping", false)):
			if not _inside_terrain_warning_sent:
				_inside_terrain_warning_sent = true
				push_warning("Seaweed56 started inside terrain; move the placed instance into open water.")
			set_physics_process(false)

	rotation = _base_rotation + deg_to_rad(
		sin(cycle * 0.61 + 0.9) * rotation_amplitude_degrees
	)
