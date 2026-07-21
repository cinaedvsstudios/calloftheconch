class_name CotcSeaweedDrift
extends AnimatedSprite2D

## Adds a slow local drift loop without replacing the seaweed frame animation.
## The loop reverses at terrain and releases small rotating fragments when the
## seaweed7, seaweed8 and seaweed9 artwork is available in assets/backgrounds.

const FRAGMENT_PATHS: PackedStringArray = [
	"res://assets/backgrounds/seaweed7.webp",
	"res://assets/backgrounds/seaweed8.webp",
	"res://assets/backgrounds/seaweed9.webp",
]

@export_category("Drift")
@export var drift_radius: Vector2 = Vector2(52.0, 24.0)
@export_range(2.0, 30.0, 0.1) var drift_period_seconds: float = 8.0
@export_range(0.0, 30.0, 0.1) var rotation_amplitude_degrees: float = 12.0
@export_range(0.0, 25.0, 0.1) var movement_lean_degrees: float = 8.0

@export_category("Loose Fragments")
@export_range(0.5, 60.0, 0.5) var fragment_spawn_min_seconds: float = 5.0
@export_range(0.5, 60.0, 0.5) var fragment_spawn_max_seconds: float = 9.0
@export_range(1.0, 180.0, 1.0) var fragment_lifetime_seconds: float = 60.0
@export_range(1, 40, 1) var maximum_active_fragments: int = 12
@export_range(0.02, 2.0, 0.01) var fragment_min_scale: float = 0.16
@export_range(0.02, 2.0, 0.01) var fragment_max_scale: float = 0.42
@export_range(1.0, 300.0, 1.0) var fragment_min_speed: float = 12.0
@export_range(1.0, 300.0, 1.0) var fragment_max_speed: float = 38.0
@export_range(0.0, 360.0, 1.0) var fragment_min_rotation_degrees: float = 18.0
@export_range(0.0, 720.0, 1.0) var fragment_max_rotation_degrees: float = 86.0
@export_range(0.1, 20.0, 0.1) var fragment_fade_seconds: float = 6.0

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
var _fragment_asset_warning_sent: bool = false
var _fragment_spawn_remaining: float = 0.0
var _fragment_textures: Array[Texture2D] = []
var _fragments: Array[Sprite2D] = []
var _fragment_velocities: Array[Vector2] = []
var _fragment_rotation_speeds: Array[float] = []
var _fragment_ages: Array[float] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	var phase_seed: int = absi(hash(str(get_path()))) % 10000
	_phase = (float(phase_seed) / 10000.0) * TAU
	_rng.seed = absi(hash("%s|fragments" % str(get_path())))
	_load_fragment_textures()
	_schedule_next_fragment()
	set_process(true)


func _process(delta: float) -> void:
	_update_fragments(maxf(0.0, delta))
	if _fragment_textures.is_empty():
		return
	_fragment_spawn_remaining -= maxf(0.0, delta)
	if _fragment_spawn_remaining > 0.0:
		return
	_schedule_next_fragment()
	if _fragments.size() < maximum_active_fragments:
		_spawn_fragment()


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

	var horizontal_lean: float = clampf(
		intended_motion.x / maxf(1.0, drift_radius.x),
		-1.0,
		1.0,
	) * movement_lean_degrees
	rotation = _base_rotation + deg_to_rad(
		sin(cycle * 0.61 + 0.9) * rotation_amplitude_degrees
		+ horizontal_lean
	)


func _load_fragment_textures() -> void:
	_fragment_textures.clear()
	for path: String in FRAGMENT_PATHS:
		if not ResourceLoader.exists(path, "Texture2D"):
			continue
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture != null:
			_fragment_textures.append(texture)
	if _fragment_textures.is_empty() and not _fragment_asset_warning_sent:
		_fragment_asset_warning_sent = true
		push_warning(
			"Seaweed56 fragment spawning is ready, but seaweed7.webp, seaweed8.webp "
			+ "and seaweed9.webp are not yet in res://assets/backgrounds/."
		)


func _schedule_next_fragment() -> void:
	_fragment_spawn_remaining = _rng.randf_range(
		minf(fragment_spawn_min_seconds, fragment_spawn_max_seconds),
		maxf(fragment_spawn_min_seconds, fragment_spawn_max_seconds),
	)


func _spawn_fragment() -> void:
	if _fragment_textures.is_empty():
		return
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	var fragment: Sprite2D = Sprite2D.new()
	fragment.name = "LooseSeaweedFragment"
	fragment.z_as_relative = false
	fragment.z_index = z_index - 1
	fragment.texture = _fragment_textures[_rng.randi_range(0, _fragment_textures.size() - 1)]
	scene_root.add_child(fragment)
	fragment.top_level = true
	fragment.global_position = global_position + Vector2(
		_rng.randf_range(-24.0, 24.0),
		_rng.randf_range(-18.0, 18.0),
	)
	fragment.global_rotation = _rng.randf_range(-PI, PI)
	var scale_value: float = _rng.randf_range(
		minf(fragment_min_scale, fragment_max_scale),
		maxf(fragment_min_scale, fragment_max_scale),
	)
	fragment.scale = Vector2.ONE * scale_value
	fragment.modulate = Color.WHITE

	var drift_direction: Vector2 = Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-0.65, 0.35),
	)
	if drift_direction.length_squared() <= 0.001:
		drift_direction = Vector2.RIGHT
	drift_direction = drift_direction.normalized()
	var drift_speed: float = _rng.randf_range(
		minf(fragment_min_speed, fragment_max_speed),
		maxf(fragment_min_speed, fragment_max_speed),
	)
	var rotation_speed: float = deg_to_rad(_rng.randf_range(
		minf(fragment_min_rotation_degrees, fragment_max_rotation_degrees),
		maxf(fragment_min_rotation_degrees, fragment_max_rotation_degrees),
	))
	if _rng.randf() < 0.5:
		rotation_speed *= -1.0

	_fragments.append(fragment)
	_fragment_velocities.append(drift_direction * drift_speed)
	_fragment_rotation_speeds.append(rotation_speed)
	_fragment_ages.append(0.0)


func _update_fragments(delta: float) -> void:
	for index: int in range(_fragments.size() - 1, -1, -1):
		var fragment: Sprite2D = _fragments[index]
		if not is_instance_valid(fragment):
			_remove_fragment_at(index, false)
			continue
		_fragment_ages[index] += delta
		if _fragment_ages[index] >= fragment_lifetime_seconds:
			_remove_fragment_at(index, true)
			continue
		fragment.global_position += _fragment_velocities[index] * delta
		fragment.global_rotation += _fragment_rotation_speeds[index] * delta
		var fade_start: float = maxf(0.0, fragment_lifetime_seconds - fragment_fade_seconds)
		if _fragment_ages[index] > fade_start:
			fragment.modulate.a = clampf(
				(fragment_lifetime_seconds - _fragment_ages[index])
				/ maxf(0.1, fragment_fade_seconds),
				0.0,
				1.0,
			)


func _remove_fragment_at(index: int, free_fragment: bool) -> void:
	if index < 0 or index >= _fragments.size():
		return
	var fragment: Sprite2D = _fragments[index]
	if free_fragment and is_instance_valid(fragment):
		fragment.queue_free()
	_fragments.remove_at(index)
	_fragment_velocities.remove_at(index)
	_fragment_rotation_speeds.remove_at(index)
	_fragment_ages.remove_at(index)
