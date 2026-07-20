@tool
class_name CotcProceduralFishSchool
extends Area2D

## Lightweight 2D shoal made from individual fish sprites.
##
## The school root handles shared travel, currents, terrain avoidance and conch
## impulses. Each fish keeps a local formation target, separation force and
## occasional dart, so the group reads as many animals rather than one flat image.

enum FormationMode {
	RIBBON,
	WEDGE,
	SHOAL,
}

const FISH_TEXTURES: Array[Texture2D] = [
	preload("res://assets/objects/1fish.png"),
	preload("res://assets/objects/2fish.png"),
	preload("res://assets/objects/3fish.png"),
	preload("res://assets/objects/4fish.png"),
	preload("res://assets/objects/5fish.png"),
]

@export_category("School Composition")
@export_range(1, 60, 1) var fish_count: int = 10
@export var formation_mode: FormationMode = FormationMode.RIBBON
@export var school_half_extents: Vector2 = Vector2(260.0, 105.0)
@export_range(10.0, 180.0, 1.0) var minimum_fish_height: float = 40.0
@export_range(10.0, 220.0, 1.0) var maximum_fish_height: float = 76.0
@export_range(0.0, 1.0, 0.01) var size_variation: float = 0.32
@export var source_faces_left: bool = false
@export var random_seed: int = 0

@export_category("Whole-School Travel")
@export var initial_direction: Vector2 = Vector2.RIGHT
@export var patrol_half_extents: Vector2 = Vector2(950.0, 260.0)
@export_range(1.0, 500.0, 1.0) var minimum_cruise_speed: float = 44.0
@export_range(1.0, 500.0, 1.0) var maximum_cruise_speed: float = 78.0
@export_range(1.0, 1000.0, 1.0) var steering_acceleration: float = 115.0
@export_range(10.0, 300.0, 1.0) var waypoint_reached_distance: float = 75.0
@export_range(0.0, 1.0, 0.01) var vertical_wander_strength: float = 0.22
@export_range(0.01, 3.0, 0.01) var vertical_wander_frequency: float = 0.18

@export_category("Local Fish Motion")
@export_range(1.0, 500.0, 1.0) var local_steering_acceleration: float = 185.0
@export_range(1.0, 500.0, 1.0) var local_maximum_speed: float = 95.0
@export_range(1.0, 200.0, 1.0) var separation_distance: float = 42.0
@export_range(0.0, 500.0, 1.0) var separation_strength: float = 145.0
@export_range(0.0, 80.0, 1.0) var formation_sway: float = 18.0
@export_range(0.01, 4.0, 0.01) var formation_sway_frequency: float = 0.42
@export_range(0.1, 20.0, 0.1) var individual_dart_interval_minimum: float = 2.2
@export_range(0.1, 20.0, 0.1) var individual_dart_interval_maximum: float = 5.8
@export_range(0.05, 2.0, 0.05) var individual_dart_duration: float = 0.38
@export_range(0.0, 300.0, 1.0) var individual_dart_distance: float = 72.0

@export_category("Synchronized Dart")
@export_range(0.1, 30.0, 0.1) var synchronized_dart_interval_minimum: float = 4.0
@export_range(0.1, 30.0, 0.1) var synchronized_dart_interval_maximum: float = 7.5
@export_range(0.05, 3.0, 0.05) var synchronized_dart_duration: float = 0.62
@export_range(0.0, 4.0, 0.05) var synchronized_speed_multiplier: float = 1.65
@export_range(0.1, 1.0, 0.01) var synchronized_formation_compression: float = 0.78

@export_category("Terrain Avoidance")
@export_flags_2d_physics var terrain_collision_mask: int = 1
@export_range(10.0, 500.0, 1.0) var terrain_collision_radius: float = 135.0
@export_range(0.0, 12.0, 0.5) var terrain_margin: float = 2.0
@export_range(0.0, 2.0, 0.05) var terrain_retarget_cooldown: float = 0.35

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.32
@export_range(0.0, 1000.0, 1.0) var conch_push_speed: float = 220.0
@export_range(1.0, 2000.0, 1.0) var conch_push_decay: float = 210.0

@onready var _fish_container: Node2D = %FishContainer

var _fish_states: Array[Dictionary] = []
var _home_position: Vector2
var _patrol_target: Vector2
var _movement_velocity: Vector2 = Vector2.ZERO
var _conch_impulse: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _travel_sign: float = 1.0
var _cruise_speed: float = 60.0
var _synchronized_dart_remaining: float = 0.0
var _synchronized_dart_cooldown: float = 0.0
var _terrain_retarget_remaining: float = 0.0
var _distance_active: bool = true
var _inside_terrain_warning_sent: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_seed_rng()
	_build_school()
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return

	_home_position = global_position
	_wander_phase = _rng.randf_range(0.0, TAU)
	_travel_sign = _resolve_initial_travel_sign()
	_choose_next_patrol_target(true)
	_reset_synchronized_dart_cooldown()
	monitorable = true
	set_physics_process(true)


func _seed_rng() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed


func _build_school() -> void:
	if not is_instance_valid(_fish_container):
		return
	for child: Node in _fish_container.get_children():
		child.queue_free()
	_fish_states.clear()

	var count: int = maxi(1, fish_count)
	for index: int in count:
		var texture: Texture2D = FISH_TEXTURES[index % FISH_TEXTURES.size()]
		var sprite := Sprite2D.new()
		sprite.name = "Fish%02d" % (index + 1)
		sprite.texture = texture
		sprite.centered = true
		sprite.position = _formation_offset(index, count)
		sprite.flip_h = source_faces_left
		var normalized_index: float = float(index) / maxf(1.0, float(count - 1))
		var base_height: float = lerpf(minimum_fish_height, maximum_fish_height, normalized_index)
		var random_scale: float = _rng.randf_range(1.0 - size_variation, 1.0 + size_variation)
		var texture_height: float = maxf(1.0, float(texture.get_height()))
		sprite.scale = Vector2.ONE * (base_height * random_scale / texture_height)
		_fish_container.add_child(sprite)
		_fish_states.append({
			"sprite": sprite,
			"base_offset": sprite.position,
			"velocity": Vector2.ZERO,
			"phase": _rng.randf_range(0.0, TAU),
			"dart_remaining": 0.0,
			"dart_cooldown": _random_individual_dart_interval(),
			"dart_scale": _rng.randf_range(0.75, 1.25),
		})


func _formation_offset(index: int, count: int) -> Vector2:
	match formation_mode:
		FormationMode.WEDGE:
			return _wedge_offset(index)
		FormationMode.SHOAL:
			return _shoal_offset(index, count)
		_:
			return _ribbon_offset(index, count)


func _ribbon_offset(index: int, count: int) -> Vector2:
	var t: float = float(index) / maxf(1.0, float(count - 1))
	var x: float = lerpf(-school_half_extents.x, school_half_extents.x, t)
	var y: float = sin(t * TAU * 1.35) * school_half_extents.y * 0.52
	y += _rng.randf_range(-school_half_extents.y * 0.18, school_half_extents.y * 0.18)
	return Vector2(x, y)


func _wedge_offset(index: int) -> Vector2:
	var row: int = 0
	var consumed: int = 0
	while consumed + row + 1 <= index:
		consumed += row + 1
		row += 1
	var column: int = index - consumed
	var row_width: int = row + 1
	var spacing_x: float = school_half_extents.x / 4.5
	var spacing_y: float = school_half_extents.y / 3.0
	return Vector2(
		school_half_extents.x * 0.60 - float(row) * spacing_x,
		(float(column) - float(row_width - 1) * 0.5) * spacing_y,
	)


func _shoal_offset(index: int, count: int) -> Vector2:
	var golden_angle: float = 2.39996323
	var radial_ratio: float = sqrt((float(index) + 0.5) / maxf(1.0, float(count)))
	var angle: float = float(index) * golden_angle
	return Vector2(
		cos(angle) * school_half_extents.x * radial_ratio,
		sin(angle) * school_half_extents.y * radial_ratio,
	)


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitorable = _distance_active
	if is_instance_valid(_fish_container):
		_fish_container.visible = _distance_active
	if not _distance_active:
		_external_currents.clear()
		_conch_impulse = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_terrain_retarget_remaining = maxf(0.0, _terrain_retarget_remaining - delta)
	_update_synchronized_dart(delta)
	_update_school_travel(delta)
	_update_fish(delta)


func _update_school_travel(delta: float) -> void:
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= waypoint_reached_distance or _has_passed_patrol_target():
		_choose_next_patrol_target(false)
		to_target = _patrol_target - global_position

	if to_target.length_squared() > 0.001:
		var desired_direction: Vector2 = to_target.normalized()
		desired_direction.y += sin(
			_elapsed * TAU * vertical_wander_frequency + _wander_phase
		) * vertical_wander_strength
		desired_direction = desired_direction.normalized()
		var speed_multiplier: float = (
			synchronized_speed_multiplier if _synchronized_dart_remaining > 0.0 else 1.0
		)
		_movement_velocity = _movement_velocity.move_toward(
			desired_direction * _cruise_speed * speed_multiplier,
			steering_acceleration * delta * speed_multiplier,
		)

	_conch_impulse = _conch_impulse.move_toward(Vector2.ZERO, conch_push_decay * delta)
	var total_velocity: Vector2 = (
		_movement_velocity
		+ _get_external_current_velocity() * current_influence
		+ _conch_impulse
	)
	var motion_result: Dictionary = CotcTerrainSafeMotion.move_circle(
		self,
		total_velocity * delta,
		terrain_collision_radius,
		terrain_collision_mask,
		terrain_margin,
		2,
	)
	_handle_terrain_result(motion_result)


func _update_synchronized_dart(delta: float) -> void:
	if _synchronized_dart_remaining > 0.0:
		_synchronized_dart_remaining = maxf(0.0, _synchronized_dart_remaining - delta)
		if _synchronized_dart_remaining <= 0.0:
			_reset_synchronized_dart_cooldown()
		return
	_synchronized_dart_cooldown = maxf(0.0, _synchronized_dart_cooldown - delta)
	if _synchronized_dart_cooldown <= 0.0:
		_synchronized_dart_remaining = synchronized_dart_duration


func _update_fish(delta: float) -> void:
	var movement_sign: float = _get_movement_sign()
	var compression: float = (
		synchronized_formation_compression if _synchronized_dart_remaining > 0.0 else 1.0
	)
	for index: int in _fish_states.size():
		var state: Dictionary = _fish_states[index]
		var sprite: Sprite2D = state["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue

		var base_offset: Vector2 = state["base_offset"] as Vector2
		if formation_mode == FormationMode.WEDGE:
			base_offset.x *= movement_sign
		base_offset *= compression
		var phase: float = float(state["phase"])
		var sway := Vector2(
			cos(_elapsed * formation_sway_frequency + phase) * formation_sway * 0.35,
			sin(_elapsed * formation_sway_frequency * 1.35 + phase) * formation_sway,
		)

		var dart_remaining: float = float(state["dart_remaining"])
		var dart_cooldown: float = float(state["dart_cooldown"])
		if dart_remaining > 0.0:
			dart_remaining = maxf(0.0, dart_remaining - delta)
		elif dart_cooldown > 0.0:
			dart_cooldown = maxf(0.0, dart_cooldown - delta)
		else:
			dart_remaining = individual_dart_duration * float(state["dart_scale"])
			dart_cooldown = _random_individual_dart_interval()

		var dart_ratio: float = 0.0
		if dart_remaining > 0.0:
			dart_ratio = sin(
				clampf(dart_remaining / maxf(0.001, individual_dart_duration), 0.0, 1.0) * PI
			)
		var desired_position: Vector2 = base_offset + sway
		desired_position.x += movement_sign * individual_dart_distance * dart_ratio
		var separation_force: Vector2 = _calculate_separation(index, sprite.position)
		var desired_velocity: Vector2 = (desired_position - sprite.position) * 2.2 + separation_force
		desired_velocity = desired_velocity.limit_length(local_maximum_speed)
		var local_velocity: Vector2 = state["velocity"] as Vector2
		local_velocity = local_velocity.move_toward(
			desired_velocity,
			local_steering_acceleration * delta,
		)
		sprite.position += local_velocity * delta

		var visible_velocity: Vector2 = _movement_velocity + local_velocity
		if absf(visible_velocity.x) > 1.0:
			var moving_left: bool = visible_velocity.x < 0.0
			sprite.flip_h = moving_left != source_faces_left
		var target_rotation: float = clampf(
			visible_velocity.y / maxf(80.0, absf(visible_velocity.x)) * 0.22,
			-0.16,
			0.16,
		)
		sprite.rotation = lerp_angle(sprite.rotation, target_rotation, clampf(delta * 5.0, 0.0, 1.0))
		sprite.z_index = int(round(sprite.position.y / 12.0))

		state["velocity"] = local_velocity
		state["dart_remaining"] = dart_remaining
		state["dart_cooldown"] = dart_cooldown
		_fish_states[index] = state


func _calculate_separation(current_index: int, current_position: Vector2) -> Vector2:
	var force: Vector2 = Vector2.ZERO
	var minimum_distance_squared: float = separation_distance * separation_distance
	for other_index: int in _fish_states.size():
		if other_index == current_index:
			continue
		var other_sprite: Sprite2D = _fish_states[other_index]["sprite"] as Sprite2D
		if not is_instance_valid(other_sprite):
			continue
		var difference: Vector2 = current_position - other_sprite.position
		var distance_squared: float = difference.length_squared()
		if distance_squared <= 0.001 or distance_squared >= minimum_distance_squared:
			continue
		var distance: float = sqrt(distance_squared)
		force += difference / distance * (1.0 - distance / separation_distance) * separation_strength
	return force


func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if is_instance_valid(source):
		_external_currents[source] = current_velocity


func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)


func receive_conch_hit(
		origin: Vector2,
		pulse_direction: Vector2,
		_distance: float,
		strength: float,
	) -> void:
	var away_direction: Vector2 = global_position - origin
	if away_direction.length_squared() <= 0.001:
		away_direction = pulse_direction
	if away_direction.length_squared() <= 0.001:
		return
	_conch_impulse += away_direction.normalized() * conch_push_speed * clampf(strength, 0.55, 1.35)
	_synchronized_dart_remaining = maxf(_synchronized_dart_remaining, synchronized_dart_duration)
	for index: int in _fish_states.size():
		var state: Dictionary = _fish_states[index]
		state["velocity"] = (state["velocity"] as Vector2) + Vector2(
			_rng.randf_range(-55.0, 55.0),
			_rng.randf_range(-45.0, 45.0),
		)
		_fish_states[index] = state


func _handle_terrain_result(result: Dictionary) -> void:
	if not bool(result.get(&"blocked", false)):
		return
	var normal: Vector2 = result.get(&"normal", Vector2.ZERO)
	if normal.length_squared() > 0.001:
		_movement_velocity = _movement_velocity.slide(normal)
		_conch_impulse = _conch_impulse.slide(normal)
	if bool(result.get(&"started_overlapping", false)):
		_movement_velocity = Vector2.ZERO
		_conch_impulse = Vector2.ZERO
		if not _inside_terrain_warning_sent:
			_inside_terrain_warning_sent = true
			push_warning("ProceduralFishSchool started inside terrain; move it into open water.")
		return
	if _terrain_retarget_remaining <= 0.0:
		_choose_target_away_from_terrain(normal)
		_terrain_retarget_remaining = terrain_retarget_cooldown


func _choose_target_away_from_terrain(normal: Vector2) -> void:
	if normal.length_squared() <= 0.001:
		_choose_next_patrol_target(false)
		return
	var tangent: Vector2 = normal.orthogonal()
	if tangent.dot(_patrol_target - global_position) < 0.0:
		tangent = -tangent
	var escape_direction: Vector2 = (normal * 0.8 + tangent * 0.6).normalized()
	var escape_distance: float = minf(
		patrol_half_extents.x * 0.65,
		_rng.randf_range(300.0, 620.0),
	)
	_patrol_target = _clamp_to_patrol_area(global_position + escape_direction * escape_distance)
	_travel_sign = -1.0 if _patrol_target.x < global_position.x else 1.0
	_wander_phase = _rng.randf_range(0.0, TAU)


func _choose_next_patrol_target(initial_target: bool) -> void:
	if not initial_target:
		_travel_sign *= -1.0
	var horizontal_distance: float = patrol_half_extents.x * _rng.randf_range(0.68, 1.0)
	_patrol_target = _home_position + Vector2(
		_travel_sign * horizontal_distance,
		_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
	)
	_cruise_speed = _rng.randf_range(
		minf(minimum_cruise_speed, maximum_cruise_speed),
		maxf(minimum_cruise_speed, maximum_cruise_speed),
	)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _resolve_initial_travel_sign() -> float:
	if absf(initial_direction.x) > 0.01:
		return -1.0 if initial_direction.x < 0.0 else 1.0
	return -1.0 if _rng.randf() < 0.5 else 1.0


func _has_passed_patrol_target() -> bool:
	if _travel_sign > 0.0:
		return global_position.x >= _patrol_target.x
	return global_position.x <= _patrol_target.x


func _clamp_to_patrol_area(candidate: Vector2) -> Vector2:
	return Vector2(
		clampf(candidate.x, _home_position.x - patrol_half_extents.x, _home_position.x + patrol_half_extents.x),
		clampf(candidate.y, _home_position.y - patrol_half_extents.y, _home_position.y + patrol_half_extents.y),
	)


func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	var invalid_sources: Array[Node] = []
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			invalid_sources.append(source)
			continue
		total_velocity += _external_currents[source] as Vector2
	for invalid_source: Node in invalid_sources:
		_external_currents.erase(invalid_source)
	return total_velocity


func _get_movement_sign() -> float:
	if absf(_movement_velocity.x) > 1.0:
		return -1.0 if _movement_velocity.x < 0.0 else 1.0
	return _travel_sign


func _random_individual_dart_interval() -> float:
	return _rng.randf_range(
		minf(individual_dart_interval_minimum, individual_dart_interval_maximum),
		maxf(individual_dart_interval_minimum, individual_dart_interval_maximum),
	)


func _reset_synchronized_dart_cooldown() -> void:
	_synchronized_dart_cooldown = _rng.randf_range(
		minf(synchronized_dart_interval_minimum, synchronized_dart_interval_maximum),
		maxf(synchronized_dart_interval_minimum, synchronized_dart_interval_maximum),
	)
