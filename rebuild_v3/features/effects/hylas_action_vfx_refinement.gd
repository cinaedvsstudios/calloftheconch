class_name CotcHylasActionVFXRefinement
extends Node

const BURST_ANIMATION: StringName = &"burst"
const TAIL_FLIP_ANIMATION: StringName = &"tail_flip"
const ORBIT_SEGMENTS: int = 64
const ORBIT_HIGHLIGHT_SEGMENTS: int = 24
const ORBIT_HIGHLIGHT_SPAN: float = 1.55
const ORBIT_TILT_RADIANS: float = -0.31415926536
const ORBIT_REVOLUTIONS: float = 2.0
const CANONICAL_START_PROGRESS: float = 13.0 / 60.0
const NORMAL_SPEED_TRAIL_VERTICAL_OFFSET: float = -15.0
const NORMAL_SPEED_TRAIL_FORWARD_OFFSET: float = 15.0
const GREATFIN_SPEED_TRAIL_VERTICAL_OFFSET: float = -45.0
const GREATFIN_SPEED_TRAIL_FORWARD_OFFSET: float = 55.0

@onready var _action_vfx: Node2D = get_parent() as Node2D
@onready var _player: CharacterBody2D = get_parent().get_parent() as CharacterBody2D
@onready var _sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite") as AnimatedSprite2D

var _speed_trail: Line2D
var _legacy_tail_trail: Line2D
var _orbit_bands: Array[Dictionary] = []
var _orbit_alpha: float = 0.0


func _ready() -> void:
	process_priority = 110
	_build_orbit_bands()
	call_deferred(&"_resolve_parent_layers")
	set_process(true)


func _process(delta: float) -> void:
	if _player == null or _sprite == null:
		return
	_resolve_parent_layers()
	_offset_speed_trail()
	_hide_legacy_tail_trail()

	if _is_tail_flip_active():
		_orbit_alpha = 1.0
		_update_orbit_geometry(_tail_flip_orbit_progress())
	else:
		_orbit_alpha = move_toward(_orbit_alpha, 0.0, maxf(delta, 0.0) * 6.5)
		if _orbit_alpha <= 0.001:
			_clear_orbit_lines()

	_apply_orbit_alpha()


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
	var vertical_offset: float = NORMAL_SPEED_TRAIL_VERTICAL_OFFSET
	var forward_distance: float = NORMAL_SPEED_TRAIL_FORWARD_OFFSET
	if _is_greatfin_burst_set():
		vertical_offset = GREATFIN_SPEED_TRAIL_VERTICAL_OFFSET
		forward_distance = GREATFIN_SPEED_TRAIL_FORWARD_OFFSET
	var forward_offset: float = -forward_distance if _sprite.flip_h else forward_distance
	_speed_trail.global_position = Vector2(forward_offset, vertical_offset)


func _is_greatfin_burst_set() -> bool:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(BURST_ANIMATION):
		return false
	return _sprite.sprite_frames.get_frame_count(BURST_ANIMATION) >= 6


func _hide_legacy_tail_trail() -> void:
	if is_instance_valid(_legacy_tail_trail):
		_legacy_tail_trail.hide()


func _build_orbit_bands() -> void:
	var band_definitions: Array[Dictionary] = [
		{
			"name": "Upper",
			"height": -24.0,
			"radius_scale": 0.86,
			"phase_offset": -0.42,
			"base_width": 4.5,
			"highlight_width": 10.0,
			"base_color": Color(0.08, 0.45, 0.94, 0.16),
			"highlight_color": Color(0.42, 0.90, 1.0, 0.72),
		},
		{
			"name": "Middle",
			"height": 0.0,
			"radius_scale": 1.0,
			"phase_offset": 0.0,
			"base_width": 6.0,
			"highlight_width": 15.0,
			"base_color": Color(0.12, 0.60, 1.0, 0.25),
			"highlight_color": Color(0.78, 0.99, 1.0, 1.0),
		},
		{
			"name": "Lower",
			"height": 24.0,
			"radius_scale": 1.14,
			"phase_offset": 0.48,
			"base_width": 3.5,
			"highlight_width": 8.0,
			"base_color": Color(0.04, 0.30, 0.82, 0.11),
			"highlight_color": Color(0.22, 0.68, 1.0, 0.56),
		},
	]

	for definition: Dictionary in band_definitions:
		var band_name: String = str(definition.get("name", "Band"))
		var base_width: float = float(definition.get("base_width", 4.0))
		var highlight_width: float = float(definition.get("highlight_width", 10.0))
		var base_color: Color = definition.get("base_color", Color(0.1, 0.5, 1.0, 0.15))
		var highlight_color: Color = definition.get("highlight_color", Color(0.7, 1.0, 1.0, 0.9))

		var back_line: Line2D = _create_orbit_line(
			"TailFlip%sBack" % band_name,
			base_width * 0.72,
			-1,
			_make_uniform_gradient(base_color.darkened(0.45)),
		)
		var front_line: Line2D = _create_orbit_line(
			"TailFlip%sFront" % band_name,
			base_width,
			1,
			_make_uniform_gradient(base_color),
		)
		var highlight_line: Line2D = _create_orbit_line(
			"TailFlip%sHighlight" % band_name,
			highlight_width,
			3,
			_make_highlight_gradient(highlight_color),
		)

		_orbit_bands.append({
			"height": float(definition.get("height", 0.0)),
			"radius_scale": float(definition.get("radius_scale", 1.0)),
			"phase_offset": float(definition.get("phase_offset", 0.0)),
			"back": back_line,
			"front": front_line,
			"highlight": highlight_line,
		})


func _create_orbit_line(
		line_name: String,
		line_width: float,
		z_offset: int,
		line_gradient: Gradient,
	) -> Line2D:
	var line: Line2D = Line2D.new()
	line.name = line_name
	line.top_level = true
	line.global_position = Vector2.ZERO
	line.z_as_relative = false
	line.z_index = _sprite.z_index + z_offset
	line.width = line_width
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.gradient = line_gradient
	line.hide()
	add_child(line)
	return line


func _make_uniform_gradient(color_value: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([color_value, color_value])
	return gradient


func _make_highlight_gradient(bright_color: Color) -> Gradient:
	var transparent_color: Color = Color(bright_color.r, bright_color.g, bright_color.b, 0.0)
	var shoulder_color: Color = Color(
		bright_color.r,
		bright_color.g,
		bright_color.b,
		bright_color.a * 0.42,
	)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.50, 0.70, 1.0])
	gradient.colors = PackedColorArray([
		transparent_color,
		shoulder_color,
		bright_color,
		shoulder_color,
		transparent_color,
	])
	return gradient


func _is_tail_flip_active() -> bool:
	return (
		float(_player.get("_tail_flip_remaining")) > 0.0
		and _sprite.animation == TAIL_FLIP_ANIMATION
	)


func _tail_flip_orbit_progress() -> float:
	var frame_count: int = _sprite.sprite_frames.get_frame_count(TAIL_FLIP_ANIMATION)
	if frame_count <= 1:
		return CANONICAL_START_PROGRESS

	var final_frame_index: float = float(frame_count - 1)
	var frame_progress: float = clampf(_sprite.frame_progress, 0.0, 1.0)
	var animation_progress: float = clampf(
		(float(_sprite.frame) + frame_progress) / final_frame_index,
		0.0,
		1.0,
	)
	return fposmod(
		CANONICAL_START_PROGRESS - animation_progress * ORBIT_REVOLUTIONS,
		1.0,
	)


func _update_orbit_geometry(progress: float) -> void:
	var faces_left: bool = _tail_flip_faces_left()
	for band: Dictionary in _orbit_bands:
		var height: float = float(band.get("height", 0.0))
		var radius_scale: float = float(band.get("radius_scale", 1.0))
		var phase_offset: float = float(band.get("phase_offset", 0.0))
		var back_line: Line2D = band.get("back") as Line2D
		var front_line: Line2D = band.get("front") as Line2D
		var highlight_line: Line2D = band.get("highlight") as Line2D

		_apply_line_facing_transform(back_line, faces_left)
		_apply_line_facing_transform(front_line, faces_left)
		_apply_line_facing_transform(highlight_line, faces_left)

		var front_points: PackedVector2Array = PackedVector2Array()
		var back_points: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(ORBIT_SEGMENTS + 1):
			var phase: float = TAU * float(point_index) / float(ORBIT_SEGMENTS)
			var point: Vector2 = _canonical_orbit_point(phase, height, radius_scale)
			if phase <= PI:
				front_points.append(point)
			if phase >= PI:
				back_points.append(point)
		_set_line_points(front_line, front_points)
		_set_line_points(back_line, back_points)

		var center_phase: float = progress * TAU + phase_offset
		var highlight_points: PackedVector2Array = PackedVector2Array()
		for highlight_index: int in range(ORBIT_HIGHLIGHT_SEGMENTS + 1):
			var ratio: float = float(highlight_index) / float(ORBIT_HIGHLIGHT_SEGMENTS)
			var phase: float = center_phase + lerpf(
				-ORBIT_HIGHLIGHT_SPAN * 0.5,
				ORBIT_HIGHLIGHT_SPAN * 0.5,
				ratio,
			)
			highlight_points.append(_canonical_orbit_point(phase, height, radius_scale))
		_set_line_points(highlight_line, highlight_points)
		var visible_phase: float = fposmod(center_phase, TAU)
		highlight_line.z_index = _sprite.z_index + (3 if visible_phase <= PI else -1)


func _canonical_orbit_point(phase: float, height: float, radius_scale: float) -> Vector2:
	var texture: Texture2D = _current_texture()
	var display_size: Vector2 = Vector2(230.0, 180.0)
	if texture != null:
		display_size = texture.get_size() * Vector2(
			absf(_sprite.scale.x),
			absf(_sprite.scale.y),
		)

	var radius_x: float = maxf(108.0, display_size.x * 0.48) * radius_scale
	var radius_y: float = maxf(44.0, display_size.y * 0.26) * radius_scale
	var local_point: Vector2 = Vector2(
		cos(phase) * radius_x,
		sin(phase) * radius_y,
	).rotated(ORBIT_TILT_RADIANS)
	return _player.global_position + Vector2(0.0, height - 6.0) + local_point


func _tail_flip_faces_left() -> bool:
	if not is_instance_valid(_player):
		return false
	var direction_value: Variant = _player.get("_tail_flip_direction")
	if direction_value is Vector2:
		var tail_direction: Vector2 = direction_value
		if tail_direction.length_squared() > 0.0001:
			return tail_direction.x < 0.0
	return is_instance_valid(_sprite) and _sprite.flip_h


func _apply_line_facing_transform(line: Line2D, faces_left: bool) -> void:
	if not is_instance_valid(line):
		return
	line.global_rotation = 0.0
	if faces_left:
		line.global_position = Vector2(_player.global_position.x * 2.0, 0.0)
		line.scale = Vector2(-1.0, 1.0)
	else:
		line.global_position = Vector2.ZERO
		line.scale = Vector2.ONE


func _set_line_points(line: Line2D, points: PackedVector2Array) -> void:
	if not is_instance_valid(line):
		return
	line.points = points
	line.visible = points.size() >= 2 and _orbit_alpha > 0.001


func _apply_orbit_alpha() -> void:
	var alpha_color: Color = Color(1.0, 1.0, 1.0, _orbit_alpha)
	for band: Dictionary in _orbit_bands:
		var back_line: Line2D = band.get("back") as Line2D
		var front_line: Line2D = band.get("front") as Line2D
		var highlight_line: Line2D = band.get("highlight") as Line2D
		if is_instance_valid(back_line):
			back_line.modulate = alpha_color
		if is_instance_valid(front_line):
			front_line.modulate = alpha_color
		if is_instance_valid(highlight_line):
			highlight_line.modulate = alpha_color


func _clear_orbit_lines() -> void:
	for band: Dictionary in _orbit_bands:
		_set_line_points(band.get("back") as Line2D, PackedVector2Array())
		_set_line_points(band.get("front") as Line2D, PackedVector2Array())
		_set_line_points(band.get("highlight") as Line2D, PackedVector2Array())


func _current_texture() -> Texture2D:
	if _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)