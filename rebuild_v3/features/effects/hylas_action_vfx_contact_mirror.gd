extends "res://rebuild_v3/features/effects/hylas_action_vfx_refinement.gd"

const WEAPON_EMISSION_FX_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/weapon_emission_fx_2d/weapon_emission_fx_2d.tscn"
)
const TAIL_FLIP_SPARK_COLOR: Color = Color(0.06, 0.62, 1.0, 1.0)

var _contact_spark_fx: CotcWeaponEmissionFX2D


func _ready() -> void:
	super._ready()
	_build_contact_spark_fx()


func play_impact_sparks(
		world_position: Vector2,
		outward_normal: Vector2 = Vector2.ZERO,
	) -> void:
	if not is_instance_valid(_contact_spark_fx):
		return
	var spark_direction: Vector2 = outward_normal
	if spark_direction.length_squared() <= 0.0001:
		spark_direction = Vector2.LEFT if _tail_flip_faces_left() else Vector2.RIGHT
	else:
		spark_direction = spark_direction.normalized()
	_contact_spark_fx.global_position = world_position
	_contact_spark_fx.global_rotation = 0.0
	_contact_spark_fx.play_profile(
		&"normal_conch",
		spark_direction,
		TAIL_FLIP_SPARK_COLOR,
	)


func _build_contact_spark_fx() -> void:
	_contact_spark_fx = WEAPON_EMISSION_FX_SCENE.instantiate() as CotcWeaponEmissionFX2D
	if _contact_spark_fx == null:
		push_warning("Tail Flip contact sparks could not instantiate the weapon emission effect.")
		return
	add_child(_contact_spark_fx)
	_contact_spark_fx.top_level = true
	_contact_spark_fx.scale = Vector2.ONE
	var radial_glow: CanvasItem = _contact_spark_fx.get_node_or_null("RadialGlow") as CanvasItem
	var additive_core: CanvasItem = _contact_spark_fx.get_node_or_null("AdditiveCore") as CanvasItem
	if radial_glow != null:
		radial_glow.hide()
	if additive_core != null:
		additive_core.hide()


func _update_orbit_geometry(progress: float) -> void:
	# This method deliberately does not call the inherited geometry builder.
	# The inherited builder contains its own facing reversal. Rebuilding the
	# canonical points here and applying one CanvasItem mirror avoids the two
	# facing operations cancelling one another.
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
	if direction_value is Vector2 and direction_value.length_squared() > 0.0001:
		return direction_value.x < 0.0
	return is_instance_valid(_sprite) and _sprite.flip_h


func _apply_line_facing_transform(line: Line2D, faces_left: bool) -> void:
	if not is_instance_valid(line):
		return
	line.global_rotation = 0.0
	if faces_left:
		# The orbit points are world-space coordinates and each Line2D is top-level.
		# A negative X scale plus a translated origin is therefore a literal mirror
		# around Hylas's current world-space X position.
		line.global_position = Vector2(_player.global_position.x * 2.0, 0.0)
		line.scale = Vector2(-1.0, 1.0)
	else:
		line.global_position = Vector2.ZERO
		line.scale = Vector2.ONE
