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
		spark_direction = Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT
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
	# Build one canonical right-facing orbit first, then mirror the completed line
	# geometry around Hylas. This guarantees a true horizontal flip and avoids the
	# phase calculation cancelling the visual mirror.
	super._update_orbit_geometry(progress)
	if _sprite.flip_h:
		_mirror_completed_orbit_lines()


func _orbit_point(phase: float, height: float, radius_scale: float) -> Vector2:
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


func _mirror_completed_orbit_lines() -> void:
	var mirror_axis_x: float = _player.global_position.x
	for band: Dictionary in _orbit_bands:
		_mirror_line_points(band.get("back") as Line2D, mirror_axis_x)
		_mirror_line_points(band.get("front") as Line2D, mirror_axis_x)
		_mirror_line_points(band.get("highlight") as Line2D, mirror_axis_x)


func _mirror_line_points(line: Line2D, mirror_axis_x: float) -> void:
	if not is_instance_valid(line) or line.points.is_empty():
		return
	var mirrored_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in line.points:
		mirrored_points.append(Vector2(mirror_axis_x * 2.0 - point.x, point.y))
	line.points = mirrored_points
