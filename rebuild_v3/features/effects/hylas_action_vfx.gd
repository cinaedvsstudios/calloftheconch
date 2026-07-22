class_name CotcHylasActionVFX
extends Node2D

const BURST_ANIMATION: StringName = &"burst"
const TAIL_FLIP_ANIMATION: StringName = &"tail_flip"
const AFTERIMAGE_POOL_SIZE: int = 7
const TAIL_SPARK_POOL_SIZE: int = 14
const SPARK_TEXTURE: Texture2D = preload(
	"res://rebuild_v3/features/effects/splash_particle.svg"
)

@export_category("Speed Run Afterimages")
@export_range(0.02, 0.30, 0.01) var afterimage_interval: float = 0.07
@export_range(0.05, 1.00, 0.01) var afterimage_lifetime: float = 0.28
@export_range(0.0, 1.0, 0.01) var afterimage_alpha: float = 0.34

@export_category("Speed Run Trail")
@export_range(2, 30, 1) var burst_trail_min_points: int = 7
@export_range(3, 80, 1) var burst_trail_max_points: int = 32
@export_range(0.005, 0.20, 0.005) var burst_trail_sample_interval: float = 0.018
@export_range(1.0, 40.0, 0.5) var burst_trail_min_width: float = 7.0
@export_range(1.0, 60.0, 0.5) var burst_trail_max_width: float = 21.0
@export_range(0, 4, 1) var burst_trail_smoothing_passes: int = 2

@export_category("Tail Flip Trail")
@export_range(3, 40, 1) var tail_flip_trail_points: int = 20
@export_range(0.01, 0.20, 0.01) var tail_flip_sample_interval: float = 0.025
@export_range(1.0, 60.0, 0.5) var tail_flip_trail_width: float = 17.0

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _sprite: AnimatedSprite2D = get_parent().get_node_or_null("AnimatedSprite") as AnimatedSprite2D
@onready var _item_visuals: Node = get_parent().get_node_or_null("ItemVisuals")

var _burst_glow_wide: Sprite2D
var _burst_glow_core: Sprite2D
var _burst_trail: Line2D
var _tail_flip_trail: Line2D

var _afterimages: Array[Sprite2D] = []
var _afterimage_remaining: Array[float] = []
var _afterimage_lifetime: Array[float] = []
var _afterimage_initial_alpha: Array[float] = []
var _afterimage_base_scale: Array[Vector2] = []
var _afterimage_cursor: int = 0

var _tail_sparks: Array[Sprite2D] = []
var _tail_spark_velocity: Array[Vector2] = []
var _tail_spark_remaining: Array[float] = []
var _tail_spark_lifetime: Array[float] = []
var _tail_spark_base_scale: Array[Vector2] = []
var _tail_spark_cursor: int = 0

var _burst_points: Array[Vector2] = []
var _tail_flip_points: Array[Vector2] = []
var _afterimage_elapsed: float = 0.0
var _burst_sample_elapsed: float = 0.0
var _tail_flip_sample_elapsed: float = 0.0
var _trail_decay_elapsed: float = 0.0
var _tail_decay_elapsed: float = 0.0
var _elapsed: float = 0.0
var _burst_was_active: bool = false
var _tail_flip_was_active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if _player == null or _sprite == null:
		push_error("HylasActionVFX requires a CharacterBody2D parent with AnimatedSprite.")
		set_process(false)
		return

	_rng.randomize()
	_build_glow_layers()
	_build_trails()
	_build_afterimage_pool()
	_build_tail_spark_pool()
	_clear_all_effects()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	_update_afterimages(delta)
	_update_tail_sparks(delta)

	if _effects_blocked():
		_clear_active_layers()
		_burst_was_active = false
		_tail_flip_was_active = false
		return

	var burst_active: bool = _is_burst_active()
	var tail_flip_active: bool = _is_tail_flip_active()

	_update_burst_glow(burst_active)
	_update_burst_afterimages(burst_active, delta)
	_update_burst_trail(burst_active, delta)
	_update_tail_flip_trail(tail_flip_active, delta)

	_burst_was_active = burst_active
	_tail_flip_was_active = tail_flip_active


func clear_effects() -> void:
	_clear_all_effects()


func _build_glow_layers() -> void:
	var additive_material: CanvasItemMaterial = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_burst_glow_wide = Sprite2D.new()
	_burst_glow_wide.name = "BurstGlowWide"
	_burst_glow_wide.material = additive_material
	_burst_glow_wide.z_index = _sprite.z_index + 1
	_burst_glow_wide.texture_filter = _sprite.texture_filter
	add_child(_burst_glow_wide)

	_burst_glow_core = Sprite2D.new()
	_burst_glow_core.name = "BurstGlowCore"
	_burst_glow_core.material = additive_material
	_burst_glow_core.z_index = _sprite.z_index + 2
	_burst_glow_core.texture_filter = _sprite.texture_filter
	add_child(_burst_glow_core)


func _build_trails() -> void:
	_burst_trail = Line2D.new()
	_burst_trail.name = "BurstBodyCenterTrail"
	_burst_trail.top_level = true
	_burst_trail.global_position = Vector2.ZERO
	_burst_trail.z_index = _sprite.z_index - 1
	_burst_trail.width = burst_trail_min_width
	_burst_trail.antialiased = true
	_burst_trail.gradient = _make_gradient(
		Color(0.04, 0.46, 1.0, 0.0),
		Color(0.32, 0.96, 1.0, 0.72)
	)
	add_child(_burst_trail)

	_tail_flip_trail = Line2D.new()
	_tail_flip_trail.name = "TailFlipArcTrail"
	_tail_flip_trail.top_level = true
	_tail_flip_trail.global_position = Vector2.ZERO
	_tail_flip_trail.z_index = _sprite.z_index + 1
	_tail_flip_trail.width = tail_flip_trail_width
	_tail_flip_trail.antialiased = true
	_tail_flip_trail.gradient = _make_gradient(
		Color(0.37, 0.12, 1.0, 0.0),
		Color(0.65, 0.98, 1.0, 0.92)
	)
	add_child(_tail_flip_trail)


func _build_afterimage_pool() -> void:
	for index: int in range(AFTERIMAGE_POOL_SIZE):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.name = "BurstAfterimage%02d" % index
		ghost.top_level = true
		ghost.z_index = _sprite.z_index - 1
		ghost.texture_filter = _sprite.texture_filter
		ghost.hide()
		add_child(ghost)
		_afterimages.append(ghost)
		_afterimage_remaining.append(0.0)
		_afterimage_lifetime.append(afterimage_lifetime)
		_afterimage_initial_alpha.append(afterimage_alpha)
		_afterimage_base_scale.append(Vector2.ONE)


func _build_tail_spark_pool() -> void:
	var additive_material: CanvasItemMaterial = CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for index: int in range(TAIL_SPARK_POOL_SIZE):
		var spark: Sprite2D = Sprite2D.new()
		spark.name = "TailFlipSpark%02d" % index
		spark.top_level = true
		spark.texture = SPARK_TEXTURE
		spark.material = additive_material
		spark.z_index = _sprite.z_index + 2
		spark.hide()
		add_child(spark)
		_tail_sparks.append(spark)
		_tail_spark_velocity.append(Vector2.ZERO)
		_tail_spark_remaining.append(0.0)
		_tail_spark_lifetime.append(0.0)
		_tail_spark_base_scale.append(Vector2.ONE)


func _make_gradient(start_color: Color, end_color: Color) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([start_color, end_color])
	return gradient


func _effects_blocked() -> bool:
	if not _sprite.visible or not bool(_player.get("_play_enabled")):
		return true
	if _player.has_method(&"is_death_sequence_active"):
		if bool(_player.call(&"is_death_sequence_active")):
			return true
	if is_instance_valid(_item_visuals) and _item_visuals.has_method(&"is_camouflage_active"):
		if bool(_item_visuals.call(&"is_camouflage_active")):
			return true
	return false


func _is_burst_active() -> bool:
	return bool(_player.get("_burst_active")) and _sprite.animation == BURST_ANIMATION


func _is_tail_flip_active() -> bool:
	return float(_player.get("_tail_flip_remaining")) > 0.0 and _sprite.animation == TAIL_FLIP_ANIMATION


func _update_burst_glow(active: bool) -> void:
	if not active:
		_burst_glow_wide.hide()
		_burst_glow_core.hide()
		return

	_sync_overlay_sprite(_burst_glow_wide, 1.045)
	_sync_overlay_sprite(_burst_glow_core, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 18.0)
	var source_alpha: float = _sprite.modulate.a * _sprite.self_modulate.a
	_burst_glow_wide.modulate = Color(0.08, 0.72, 1.0, lerpf(0.10, 0.22, pulse) * source_alpha)
	_burst_glow_core.modulate = Color(0.72, 0.98, 1.0, lerpf(0.08, 0.16, 1.0 - pulse) * source_alpha)
	_burst_glow_wide.show()
	_burst_glow_core.show()


func _sync_overlay_sprite(overlay: Sprite2D, scale_multiplier: float) -> void:
	overlay.texture = _current_texture()
	overlay.centered = _sprite.centered
	overlay.offset = _sprite.offset
	overlay.position = _sprite.position
	overlay.rotation = _sprite.rotation
	overlay.scale = _sprite.scale * scale_multiplier
	overlay.flip_h = _sprite.flip_h
	overlay.flip_v = _sprite.flip_v


func _update_burst_afterimages(active: bool, delta: float) -> void:
	if not active:
		_afterimage_elapsed = 0.0
		return
	if not _burst_was_active:
		_afterimage_elapsed = afterimage_interval

	_afterimage_elapsed += delta
	while _afterimage_elapsed >= afterimage_interval:
		_afterimage_elapsed -= afterimage_interval
		_spawn_afterimage()


func _spawn_afterimage() -> void:
	var texture: Texture2D = _current_texture()
	if texture == null:
		return
	var index: int = _afterimage_cursor
	_afterimage_cursor = (_afterimage_cursor + 1) % _afterimages.size()
	var ghost: Sprite2D = _afterimages[index]
	ghost.texture = texture
	ghost.centered = _sprite.centered
	ghost.offset = _sprite.offset
	ghost.flip_h = _sprite.flip_h
	ghost.flip_v = _sprite.flip_v
	ghost.global_transform = _sprite.global_transform
	ghost.modulate = Color(0.18, 0.82, 1.0, afterimage_alpha)
	ghost.show()
	_afterimage_remaining[index] = afterimage_lifetime
	_afterimage_lifetime[index] = afterimage_lifetime
	_afterimage_initial_alpha[index] = afterimage_alpha
	_afterimage_base_scale[index] = ghost.scale


func _update_afterimages(delta: float) -> void:
	for index: int in range(_afterimages.size()):
		if _afterimage_remaining[index] <= 0.0:
			continue
		_afterimage_remaining[index] = maxf(0.0, _afterimage_remaining[index] - delta)
		var ratio: float = _afterimage_remaining[index] / maxf(0.01, _afterimage_lifetime[index])
		var ghost: Sprite2D = _afterimages[index]
		ghost.modulate.a = _afterimage_initial_alpha[index] * ratio * ratio
		ghost.scale = _afterimage_base_scale[index] * lerpf(1.07, 1.0, ratio)
		if _afterimage_remaining[index] <= 0.0:
			ghost.hide()


func _update_burst_trail(active: bool, delta: float) -> void:
	if active:
		if not _burst_was_active:
			_burst_points.clear()
			_burst_sample_elapsed = burst_trail_sample_interval
		_burst_sample_elapsed += delta
		var speed_ratio: float = _burst_speed_ratio()
		var point_limit: int = maxi(
			2,
			roundi(lerpf(float(burst_trail_min_points), float(burst_trail_max_points), speed_ratio))
		)
		while _burst_sample_elapsed >= burst_trail_sample_interval:
			_burst_sample_elapsed -= burst_trail_sample_interval
			_append_unique_point(_burst_points, _get_burst_body_center_point(), 2.0)
		while _burst_points.size() > point_limit:
			_burst_points.pop_front()
		_burst_trail.width = move_toward(
			_burst_trail.width,
			lerpf(burst_trail_min_width, burst_trail_max_width, speed_ratio),
			delta * 80.0
		)
		_trail_decay_elapsed = 0.0
	else:
		_decay_points(_burst_points, delta, 0.025, true)
		_burst_trail.width = move_toward(_burst_trail.width, burst_trail_min_width, delta * 55.0)

	var rendered_burst_points: Array[Vector2] = _copy_points(_burst_points)
	if active:
		_append_unique_point(rendered_burst_points, _get_burst_body_center_point(), 0.5)
	_apply_line_points(_burst_trail, rendered_burst_points, true)


func _update_tail_flip_trail(active: bool, delta: float) -> void:
	if active:
		if not _tail_flip_was_active:
			_tail_flip_points.clear()
			_tail_flip_sample_elapsed = tail_flip_sample_interval
		_tail_flip_sample_elapsed += delta
		while _tail_flip_sample_elapsed >= tail_flip_sample_interval:
			_tail_flip_sample_elapsed -= tail_flip_sample_interval
			var tail_point: Vector2 = _get_tail_flip_tip_point()
			_append_unique_point(_tail_flip_points, tail_point, 2.0)
			_spawn_tail_sparks(tail_point)
		while _tail_flip_points.size() > tail_flip_trail_points:
			_tail_flip_points.pop_front()
		_tail_decay_elapsed = 0.0
	else:
		_decay_points(_tail_flip_points, delta, 0.022, false)

	_apply_line_points(_tail_flip_trail, _tail_flip_points)


func _decay_points(points: Array[Vector2], delta: float, interval: float, burst_trail: bool) -> void:
	if points.is_empty():
		return
	if burst_trail:
		_trail_decay_elapsed += delta
		while _trail_decay_elapsed >= interval and not points.is_empty():
			_trail_decay_elapsed -= interval
			points.pop_front()
	else:
		_tail_decay_elapsed += delta
		while _tail_decay_elapsed >= interval and not points.is_empty():
			_tail_decay_elapsed -= interval
			points.pop_front()


func _append_unique_point(points: Array[Vector2], point: Vector2, minimum_distance: float) -> void:
	if not points.is_empty() and points[-1].distance_squared_to(point) < minimum_distance * minimum_distance:
		return
	points.append(point)


func _apply_line_points(line: Line2D, points: Array[Vector2], smooth: bool = false) -> void:
	var rendered_points: Array[Vector2] = _copy_points(points)
	if smooth and rendered_points.size() >= 3 and burst_trail_smoothing_passes > 0:
		rendered_points = _smooth_trail_points(rendered_points, burst_trail_smoothing_passes)
	line.points = PackedVector2Array(rendered_points)
	line.visible = rendered_points.size() >= 2


func _copy_points(source_points: Array[Vector2]) -> Array[Vector2]:
	var copied_points: Array[Vector2] = []
	for point: Vector2 in source_points:
		copied_points.append(point)
	return copied_points


func _smooth_trail_points(source_points: Array[Vector2], passes: int) -> Array[Vector2]:
	var result: Array[Vector2] = _copy_points(source_points)
	for pass_index: int in range(clampi(passes, 0, 4)):
		if result.size() < 3:
			break
		var smoothed: Array[Vector2] = []
		smoothed.append(result[0])
		for index: int in range(result.size() - 1):
			var current: Vector2 = result[index]
			var next: Vector2 = result[index + 1]
			smoothed.append(current.lerp(next, 0.25))
			smoothed.append(current.lerp(next, 0.75))
		smoothed.append(result[result.size() - 1])
		result = smoothed
	return result


func _burst_speed_ratio() -> float:
	var reference_speed: float = maxf(1.0, float(_player.get("burst_speed")))
	return clampf(_player.velocity.length() / reference_speed, 0.0, 1.0)


func _get_burst_body_center_point() -> Vector2:
	return _sprite.to_global(_sprite.offset)


func _get_tail_flip_tip_point() -> Vector2:
	var texture: Texture2D = _current_texture()
	if texture == null:
		return _sprite.global_position
	var texture_size: Vector2 = texture.get_size()
	var normalised_offsets: Array[Vector2] = [
		Vector2(-0.42, 0.18),
		Vector2(-0.28, 0.42),
		Vector2(0.04, 0.48),
		Vector2(0.38, 0.24),
		Vector2(0.43, -0.16),
		Vector2(0.08, -0.45),
		Vector2(-0.34, -0.28),
	]
	var frame_count: int = maxi(1, _sprite.sprite_frames.get_frame_count(TAIL_FLIP_ANIMATION))
	var mapped_index: int = clampi(
		roundi(float(_sprite.frame) * float(normalised_offsets.size() - 1) / float(maxi(1, frame_count - 1))),
		0,
		normalised_offsets.size() - 1
	)
	var offset_ratio: Vector2 = normalised_offsets[mapped_index]
	if _sprite.flip_h:
		offset_ratio.x = -offset_ratio.x
	var local_point: Vector2 = _sprite.offset + Vector2(
		texture_size.x * offset_ratio.x,
		texture_size.y * offset_ratio.y
	)
	return _sprite.to_global(local_point)


func _spawn_tail_sparks(origin: Vector2) -> void:
	var spark_count: int = 2 if _rng.randf() > 0.45 else 1
	for count_index: int in range(spark_count):
		var index: int = _tail_spark_cursor
		_tail_spark_cursor = (_tail_spark_cursor + 1) % _tail_sparks.size()
		var spark: Sprite2D = _tail_sparks[index]
		var angle: float = _rng.randf_range(-PI, PI)
		var speed: float = _rng.randf_range(45.0, 125.0)
		var lifetime: float = _rng.randf_range(0.18, 0.34)
		var scale_value: float = _rng.randf_range(0.08, 0.17)
		spark.global_position = origin
		spark.global_rotation = angle
		spark.scale = Vector2.ONE * scale_value
		spark.modulate = Color(0.42, 0.90, 1.0, 0.82)
		spark.show()
		_tail_spark_velocity[index] = Vector2.RIGHT.rotated(angle) * speed - _player.velocity * 0.05
		_tail_spark_remaining[index] = lifetime
		_tail_spark_lifetime[index] = lifetime
		_tail_spark_base_scale[index] = spark.scale


func _update_tail_sparks(delta: float) -> void:
	for index: int in range(_tail_sparks.size()):
		if _tail_spark_remaining[index] <= 0.0:
			continue
		_tail_spark_remaining[index] = maxf(0.0, _tail_spark_remaining[index] - delta)
		var ratio: float = _tail_spark_remaining[index] / maxf(0.01, _tail_spark_lifetime[index])
		var spark: Sprite2D = _tail_sparks[index]
		spark.global_position += _tail_spark_velocity[index] * delta
		_tail_spark_velocity[index] *= pow(0.08, delta)
		spark.modulate.a = 0.82 * ratio
		spark.scale = _tail_spark_base_scale[index] * lerpf(1.65, 1.0, ratio)
		if _tail_spark_remaining[index] <= 0.0:
			spark.hide()


func _current_texture() -> Texture2D:
	if _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)


func _clear_active_layers() -> void:
	_burst_glow_wide.hide()
	_burst_glow_core.hide()
	_burst_points.clear()
	_tail_flip_points.clear()
	_apply_line_points(_burst_trail, _burst_points, true)
	_apply_line_points(_tail_flip_trail, _tail_flip_points)


func _clear_all_effects() -> void:
	_clear_active_layers()
	_afterimage_elapsed = 0.0
	_burst_sample_elapsed = 0.0
	_tail_flip_sample_elapsed = 0.0
	for index: int in range(_afterimages.size()):
		_afterimage_remaining[index] = 0.0
		_afterimages[index].hide()
	for index: int in range(_tail_sparks.size()):
		_tail_spark_remaining[index] = 0.0
		_tail_sparks[index].hide()
