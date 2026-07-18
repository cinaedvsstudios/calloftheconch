class_name CotcHylasActionVFXRefinement
extends Node

const TAIL_FLIP_ANIMATION: StringName = &"tail_flip"
const ORBIT_SEGMENTS: int = 48
const ORBIT_TILT_RADIANS: float = -0.31415926536
const SPEED_TRAIL_VERTICAL_OFFSET: float = -15.0
const SPEED_TRAIL_FORWARD_OFFSET: float = 15.0

@onready var _action_vfx: Node2D = get_parent() as Node2D
@onready var _player: CharacterBody2D = get_parent().get_parent() as CharacterBody2D
@onready var _sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite") as AnimatedSprite2D

var _speed_trail: Line2D
var _legacy_tail_trail: Line2D
var _front_start_arc: Line2D
var _back_arc: Line2D
var _front_end_arc: Line2D
var _tail_flip_was_active: bool = false
var _orbit_alpha: float = 0.0
var _impact_colliders: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	_build_orbit_lines()
	call_deferred(&"_resolve_parent_layers")
	set_process(true)


func _process(delta: float) -> void:
	if _player == null or _sprite == null:
		return
	_resolve_parent_layers()
	_offset_speed_trail()
	_hide_legacy_tail_trail()

	var tail_flip_active: bool = _is_tail_flip_active()
	if tail_flip_active:
		if not _tail_flip_was_active:
			_impact_colliders.clear()
		_orbit_alpha = 1.0
		_update_orbit_geometry(_tail_flip_progress())
		_update_slide_impact_sparks()
	else:
		_orbit_alpha = move_toward(_orbit_alpha, 0.0, maxf(delta, 0.0) * 6.5)
		if _orbit_alpha <= 0.001:
			_clear_orbit_lines()
			_impact_colliders.clear()

	_apply_orbit_alpha()
	_tail_flip_was_active = tail_flip_active


func play_impact_sparks(world_position: Vector2, _outward_normal: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_action_vfx) or not _action_vfx.has_method(&"_spawn_tail_sparks"):
		return
	for _burst_index: int in range(4):
		_action_vfx.call(&"_spawn_tail_sparks", world_position)


func _resolve_parent_layers() -> void:
	if not is_instance_valid(_action_vfx):
		return
	if not is_instance_valid(_speed_trail):
		_speed_trail = _action_vfx.get_node_or_null("BurstTailTrail") as Line2D
	if not is_instance_valid(_legacy_tail_trail):
		_legacy_tail_trail = _action_vfx.get_node_or_null("TailFlipArcTrail") as Line2D


func _offset_speed_trail() -> void:
	if not is_instance_valid(_speed_trail):
		return
	var forward_offset: float = -SPEED_TRAIL_FORWARD_OFFSET if _sprite.flip_h else SPEED_TRAIL_FORWARD_OFFSET
	_speed_trail.global_position = Vector2(forward_offset, SPEED_TRAIL_VERTICAL_OFFSET)


func _hide_legacy_tail_trail() -> void:
	if is_instance_valid(_legacy_tail_trail):
		_legacy_tail_trail.hide()


func _build_orbit_lines() -> void:
	_front_start_arc = _create_orbit_line(
		"TailFlipFrontStartArc",
		17.0,
		2,
		Color(0.16, 0.72, 1.0, 0.18),
		Color(0.72, 0.98, 1.0, 0.94)
	)
	_back_arc = _create_orbit_line(
		"TailFlipBackArc",
		9.0,
		-1,
		Color(0.05, 0.24, 0.72, 0.06),
		Color(0.18, 0.62, 1.0, 0.42)
	)
	_front_end_arc = _create_orbit_line(
		"TailFlipFrontEndArc",
		19.0,
		3,
		Color(0.12, 0.62, 1.0, 0.20),
		Color(0.78, 1.0, 1.0, 1.0)
	)


func _create_orbit_line(
		line_name: String,
		line_width: float,
		z_offset: int,
		start_color: Color,
		end_color: Color,
	) -> Line2D:
	var line: Line2D = Line2D.new()
	line.name = line_name
	line.top_level = true
	line.global_position = Vector2.ZERO
	line.z_as_relative = false
	line.z_index = _sprite.z_index + z_offset
	line.width = line_width
	line.antialiased = true
	line.gradient = _make_gradient(start_color, end_color)
	line.hide()
	add_child(line)
	return line


func _make_gradient(start_color: Color, end_color: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([start_color, end_color])
	return gradient


func _is_tail_flip_active() -> bool:
	return (
		float(_player.get("_tail_flip_remaining")) > 0.0
		and _sprite.animation == TAIL_FLIP_ANIMATION
	)


func _tail_flip_progress() -> float:
	var duration: float = maxf(0.01, float(_player.get("tail_flip_duration")))
	var remaining: float = maxf(0.0, float(_player.get("_tail_flip_remaining")))
	return clampf(1.0 - remaining / duration, 0.0, 1.0)


func _update_orbit_geometry(progress: float) -> void:
	var front_start_points: PackedVector2Array = PackedVector2Array()
	var back_points: PackedVector2Array = PackedVector2Array()
	var front_end_points: PackedVector2Array = PackedVector2Array()
	var phase_end: float = clampf(progress, 0.0, 1.0) * TAU
	var step_count: int = maxi(1, ceili(float(ORBIT_SEGMENTS) * clampf(progress, 0.0, 1.0)))
	var boundary_epsilon: float = 0.0001

	for point_index: int in range(step_count + 1):
		var phase: float = minf(
			phase_end,
			TAU * float(point_index) / float(ORBIT_SEGMENTS)
		)
		var world_point: Vector2 = _orbit_point(phase)
		if phase <= PI * 0.5 + boundary_epsilon:
			front_start_points.append(world_point)
		if phase >= PI * 0.5 - boundary_epsilon and phase <= PI * 1.5 + boundary_epsilon:
			back_points.append(world_point)
		if phase >= PI * 1.5 - boundary_epsilon:
			front_end_points.append(world_point)

	_set_line_points(_front_start_arc, front_start_points)
	_set_line_points(_back_arc, back_points)
	_set_line_points(_front_end_arc, front_end_points)


func _orbit_point(phase: float) -> Vector2:
	var texture: Texture2D = _current_texture()
	var display_size: Vector2 = Vector2(230.0, 180.0)
	if texture != null:
		display_size = texture.get_size() * Vector2(
			absf(_sprite.scale.x),
			absf(_sprite.scale.y)
		)

	var radius_x: float = maxf(108.0, display_size.x * 0.48)
	var radius_y: float = maxf(44.0, display_size.y * 0.26)
	var facing_sign: float = -1.0 if _sprite.flip_h else 1.0
	var start_angle: float = PI if _sprite.flip_h else 0.0
	var orbit_angle: float = start_angle + phase * facing_sign
	var local_point: Vector2 = Vector2(
		cos(orbit_angle) * radius_x,
		sin(orbit_angle) * radius_y
	).rotated(ORBIT_TILT_RADIANS)
	return _player.global_position + Vector2(0.0, -6.0) + local_point


func _set_line_points(line: Line2D, points: PackedVector2Array) -> void:
	line.points = points
	line.visible = points.size() >= 2 and _orbit_alpha > 0.001


func _apply_orbit_alpha() -> void:
	var alpha_color: Color = Color(1.0, 1.0, 1.0, _orbit_alpha)
	_front_start_arc.modulate = alpha_color
	_back_arc.modulate = alpha_color
	_front_end_arc.modulate = alpha_color


func _clear_orbit_lines() -> void:
	_set_line_points(_front_start_arc, PackedVector2Array())
	_set_line_points(_back_arc, PackedVector2Array())
	_set_line_points(_front_end_arc, PackedVector2Array())


func _update_slide_impact_sparks() -> void:
	var collision_count: int = _player.get_slide_collision_count()
	for collision_index: int in range(collision_count):
		var collision: KinematicCollision2D = _player.get_slide_collision(collision_index)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var collider_id: int = collider.get_instance_id()
		if _impact_colliders.has(collider_id):
			continue
		_impact_colliders[collider_id] = true
		play_impact_sparks(collision.get_position(), collision.get_normal())


func _current_texture() -> Texture2D:
	if _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
