class_name CotcRockDebrisBurst
extends Node2D

## Presentation-only rock debris burst. Gameplay objects decide whether a rock
## chips, cracks or breaks, then call play_burst() with the impact data.

signal finished

const MODE_SMALL_BREAK: StringName = &"small_break"
const MODE_DRILL_TICK: StringName = &"drill_tick"
const MODE_BIG_BREAK: StringName = &"big_break"
const MODE_RICOCHET_SCRAPE: StringName = &"ricochet_scrape"
const MODE_FINAL_COLLAPSE: StringName = &"final_collapse"

const MAX_CHUNKS: int = 24
const DEBRIS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/effects/debris00.webp"),
	preload("res://assets/effects/debris01.webp"),
	preload("res://assets/effects/debris02.webp"),
	preload("res://assets/effects/debris03.webp"),
	preload("res://assets/effects/debris04.webp"),
	preload("res://assets/effects/debris05.webp"),
]

const ROCK_PALETTE: Array[Color] = [
	Color(0.0314, 0.1098, 0.2510, 1.0),
	Color(0.0863, 0.1804, 0.3451, 1.0),
	Color(0.1882, 0.2824, 0.4431, 1.0),
	Color(0.3176, 0.4157, 0.5765, 1.0),
	Color(0.4353, 0.5373, 0.7020, 1.0),
	Color(0.5451, 0.6510, 0.8078, 1.0),
]
const DRILL_SPARK_PALETTE: Array[Color] = [
	Color(1.0, 0.08, 0.68, 1.0),
	Color(1.0, 0.24, 0.44, 1.0),
	Color(1.0, 0.42, 0.16, 1.0),
]


class ChunkParticle:
	var sprite: Sprite2D
	var velocity: Vector2 = Vector2.ZERO
	var spin: float = 0.0
	var remaining: float = 0.0
	var lifetime: float = 0.0
	var base_scale: Vector2 = Vector2.ONE


class DotParticle:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var remaining: float = 0.0
	var lifetime: float = 0.0
	var radius: float = 2.0
	var color: Color = Color.WHITE


class DustPuff:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var remaining: float = 0.0
	var lifetime: float = 0.0
	var radius: float = 12.0
	var growth: float = 24.0
	var color: Color = Color.WHITE


@export_category("Lifecycle")
@export var auto_free_when_finished: bool = true
@export_range(0.10, 5.0, 0.05) var maximum_lifetime_seconds: float = 3.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chunks: Array[ChunkParticle] = []
var _dots: Array[DotParticle] = []
var _dust: Array[DustPuff] = []
var _active_chunk_count: int = 0
var _active_drag: float = 2.0
var _active_gravity: float = 120.0
var _elapsed: float = 0.0
var _active: bool = false
var _active_mode: StringName = MODE_SMALL_BREAK


func _ready() -> void:
	_rng.randomize()
	_build_chunk_pool()
	hide()
	set_process(false)


func play_burst(
		impact_position: Vector2,
		surface_normal: Vector2,
		incoming_direction: Vector2,
		effect_mode: StringName = MODE_SMALL_BREAK,
		rock_tint: Color = Color.WHITE,
		intensity: float = 1.0,
	) -> void:
	_reset_particles()
	global_position = impact_position
	global_rotation = 0.0
	global_scale = Vector2.ONE
	_active_mode = _validated_mode(effect_mode)
	var profile: Dictionary = _profile_for(_active_mode)
	var resolved_intensity: float = clampf(intensity, 0.10, 3.0)
	var emit_direction: Vector2 = _resolve_emit_direction(surface_normal, incoming_direction)

	_active_drag = float(profile.get("drag", 2.0))
	_active_gravity = float(profile.get("gravity", 120.0))
	_active_chunk_count = clampi(
		roundi(float(profile.get("chunks", 0)) * resolved_intensity),
		0,
		MAX_CHUNKS,
	)
	_spawn_chunks(profile, emit_direction, rock_tint, resolved_intensity)
	_spawn_dots(profile, emit_direction, rock_tint, resolved_intensity)
	_spawn_dust(profile, emit_direction, rock_tint, resolved_intensity)

	_elapsed = 0.0
	_active = true
	show()
	set_process(true)
	queue_redraw()


func is_active() -> bool:
	return _active


func stop_effect() -> void:
	_reset_particles()
	_active = false
	set_process(false)
	hide()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	_elapsed += safe_delta
	_update_chunks(safe_delta)
	_update_dots(safe_delta)
	_update_dust(safe_delta)
	queue_redraw()
	if _elapsed >= maximum_lifetime_seconds or not _has_live_particles():
		_finish_effect()


func _draw() -> void:
	for puff: DustPuff in _dust:
		if puff.remaining <= 0.0:
			continue
		var ratio: float = clampf(puff.remaining / maxf(0.01, puff.lifetime), 0.0, 1.0)
		var puff_color: Color = puff.color
		puff_color.a *= ratio * ratio
		draw_circle(puff.position, puff.radius, puff_color)

	for dot: DotParticle in _dots:
		if dot.remaining <= 0.0:
			continue
		var ratio: float = clampf(dot.remaining / maxf(0.01, dot.lifetime), 0.0, 1.0)
		var dot_color: Color = dot.color
		dot_color.a *= minf(1.0, ratio * 1.8)
		draw_circle(dot.position, dot.radius * lerpf(0.45, 1.0, ratio), dot_color)


func _build_chunk_pool() -> void:
	for index: int in range(MAX_CHUNKS):
		var state: ChunkParticle = ChunkParticle.new()
		state.sprite = Sprite2D.new()
		state.sprite.name = "DebrisChunk%02d" % index
		state.sprite.z_index = 1
		state.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		state.sprite.hide()
		add_child(state.sprite)
		_chunks.append(state)


func _spawn_chunks(
		profile: Dictionary,
		emit_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	var spread_radians: float = deg_to_rad(float(profile.get("spread_degrees", 45.0)))
	var speed_min: float = float(profile.get("speed_min", 170.0)) * sqrt(intensity)
	var speed_max: float = float(profile.get("speed_max", 360.0)) * sqrt(intensity)
	var life_min: float = float(profile.get("life_min", 0.70))
	var life_max: float = float(profile.get("life_max", 1.45))
	var size_min: float = float(profile.get("chunk_size_min", 26.0))
	var size_max: float = float(profile.get("chunk_size_max", 72.0))
	var downward_fraction: float = float(profile.get("falling_chunk_fraction", 0.0))

	for index: int in range(_active_chunk_count):
		var state: ChunkParticle = _chunks[index]
		var texture: Texture2D = DEBRIS_TEXTURES[
			_rng.randi_range(0, DEBRIS_TEXTURES.size() - 1)
		]
		state.sprite.texture = texture
		state.sprite.position = Vector2.ZERO
		state.sprite.rotation = _rng.randf_range(-PI, PI)
		var desired_size: float = _rng.randf_range(size_min, size_max)
		var texture_extent: float = maxf(
			1.0,
			maxf(float(texture.get_width()), float(texture.get_height())),
		)
		var horizontal_scale: float = desired_size / texture_extent
		if _rng.randf() < 0.45:
			horizontal_scale *= -1.0
		state.base_scale = Vector2(horizontal_scale, absf(horizontal_scale))
		state.sprite.scale = state.base_scale
		state.sprite.modulate = _tinted_rock_color(_choose_rock_color(false), rock_tint)
		state.sprite.show()

		var launch_direction: Vector2 = emit_direction.rotated(
			_rng.randf_range(-spread_radians, spread_radians)
		)
		if _rng.randf() < downward_fraction:
			launch_direction = Vector2(
				launch_direction.x * _rng.randf_range(0.35, 0.85),
				absf(launch_direction.y) + _rng.randf_range(0.25, 0.75),
			).normalized()
		state.velocity = launch_direction * _rng.randf_range(speed_min, speed_max)
		state.spin = _rng.randf_range(-8.0, 8.0)
		state.lifetime = _rng.randf_range(life_min, life_max)
		state.remaining = state.lifetime

	for index: int in range(_active_chunk_count, MAX_CHUNKS):
		_reset_chunk(_chunks[index])


func _spawn_dots(
		profile: Dictionary,
		emit_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	var dot_count: int = maxi(0, roundi(float(profile.get("dots", 0)) * intensity))
	var spread_radians: float = deg_to_rad(
		float(profile.get("dot_spread_degrees", profile.get("spread_degrees", 45.0)))
	)
	var speed_min: float = float(profile.get("dot_speed_min", 120.0)) * sqrt(intensity)
	var speed_max: float = float(profile.get("dot_speed_max", 340.0)) * sqrt(intensity)
	var life_min: float = float(profile.get("dot_life_min", 0.35))
	var life_max: float = float(profile.get("dot_life_max", 1.10))
	var drill_spark_fraction: float = float(profile.get("drill_spark_fraction", 0.0))

	for _index: int in range(dot_count):
		var dot: DotParticle = DotParticle.new()
		var is_drill_spark: bool = _rng.randf() < drill_spark_fraction
		if is_drill_spark:
			dot.color = DRILL_SPARK_PALETTE[
				_rng.randi_range(0, DRILL_SPARK_PALETTE.size() - 1)
			]
		else:
			dot.color = _tinted_rock_color(_choose_rock_color(true), rock_tint)
		var direction: Vector2 = emit_direction.rotated(
			_rng.randf_range(-spread_radians, spread_radians)
		)
		dot.velocity = direction * _rng.randf_range(speed_min, speed_max)
		dot.lifetime = _rng.randf_range(life_min, life_max)
		dot.remaining = dot.lifetime
		dot.radius = _rng.randf_range(1.2, 2.6 if is_drill_spark else 3.8)
		_dots.append(dot)


func _spawn_dust(
		profile: Dictionary,
		emit_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	var dust_count: int = maxi(
		0,
		roundi(float(profile.get("dust", 0)) * minf(intensity, 1.6)),
	)
	for _index: int in range(dust_count):
		var puff: DustPuff = DustPuff.new()
		puff.position = emit_direction * _rng.randf_range(0.0, 22.0)
		puff.velocity = (
			emit_direction.rotated(_rng.randf_range(-0.75, 0.75))
			* _rng.randf_range(12.0, 48.0)
		)
		puff.lifetime = _rng.randf_range(0.55, 1.25)
		puff.remaining = puff.lifetime
		puff.radius = _rng.randf_range(12.0, 30.0) * sqrt(intensity)
		puff.growth = _rng.randf_range(20.0, 52.0)
		puff.color = _tinted_rock_color(
			ROCK_PALETTE[_rng.randi_range(0, 2)],
			rock_tint,
		)
		puff.color.a = _rng.randf_range(0.10, 0.24)
		_dust.append(puff)


func _update_chunks(delta: float) -> void:
	var drag_factor: float = exp(-maxf(0.0, _active_drag) * delta)
	for index: int in range(_active_chunk_count):
		var state: ChunkParticle = _chunks[index]
		if state.remaining <= 0.0:
			continue
		state.remaining = maxf(0.0, state.remaining - delta)
		state.velocity *= drag_factor
		state.velocity.y += _active_gravity * delta
		state.sprite.position += state.velocity * delta
		state.sprite.rotation += state.spin * delta
		var ratio: float = state.remaining / maxf(0.01, state.lifetime)
		state.sprite.modulate.a = minf(1.0, ratio * 1.7)
		state.sprite.scale = state.base_scale * lerpf(0.72, 1.0, ratio)
		if state.remaining <= 0.0:
			state.sprite.hide()


func _update_dots(delta: float) -> void:
	var drag_factor: float = exp(-maxf(0.0, _active_drag * 1.35) * delta)
	for dot: DotParticle in _dots:
		if dot.remaining <= 0.0:
			continue
		dot.remaining = maxf(0.0, dot.remaining - delta)
		dot.velocity *= drag_factor
		dot.velocity.y += _active_gravity * 0.45 * delta
		dot.position += dot.velocity * delta


func _update_dust(delta: float) -> void:
	for puff: DustPuff in _dust:
		if puff.remaining <= 0.0:
			continue
		puff.remaining = maxf(0.0, puff.remaining - delta)
		puff.velocity *= exp(-1.9 * delta)
		puff.position += puff.velocity * delta
		puff.radius += puff.growth * delta


func _has_live_particles() -> bool:
	for state: ChunkParticle in _chunks:
		if state.remaining > 0.0:
			return true
	for dot: DotParticle in _dots:
		if dot.remaining > 0.0:
			return true
	for puff: DustPuff in _dust:
		if puff.remaining > 0.0:
			return true
	return false


func _finish_effect() -> void:
	_active = false
	set_process(false)
	hide()
	finished.emit()
	if auto_free_when_finished:
		queue_free()


func _reset_particles() -> void:
	_dots.clear()
	_dust.clear()
	_active_chunk_count = 0
	_elapsed = 0.0
	for state: ChunkParticle in _chunks:
		_reset_chunk(state)


func _reset_chunk(state: ChunkParticle) -> void:
	state.velocity = Vector2.ZERO
	state.spin = 0.0
	state.remaining = 0.0
	state.lifetime = 0.0
	state.base_scale = Vector2.ONE
	state.sprite.modulate = Color.WHITE
	state.sprite.hide()


func _resolve_emit_direction(surface_normal: Vector2, incoming_direction: Vector2) -> Vector2:
	var normal: Vector2 = surface_normal.normalized()
	if normal.length_squared() <= 0.0001:
		normal = Vector2.UP
	if incoming_direction.length_squared() <= 0.0001:
		return normal
	var incoming: Vector2 = incoming_direction.normalized()
	var reflected: Vector2 = incoming - 2.0 * incoming.dot(normal) * normal
	var mixed: Vector2 = normal * 0.78 + reflected.normalized() * 0.22
	return normal if mixed.length_squared() <= 0.0001 else mixed.normalized()


func _choose_rock_color(prefer_dark: bool) -> Color:
	var maximum_index: int = 4 if prefer_dark else ROCK_PALETTE.size() - 1
	var roll: float = _rng.randf()
	if prefer_dark and roll < 0.72:
		maximum_index = 2
	elif not prefer_dark and roll < 0.76:
		maximum_index = 4
	return ROCK_PALETTE[_rng.randi_range(0, maximum_index)]


func _tinted_rock_color(base_color: Color, rock_tint: Color) -> Color:
	return Color(
		base_color.r * lerpf(1.0, rock_tint.r, 0.45),
		base_color.g * lerpf(1.0, rock_tint.g, 0.45),
		base_color.b * lerpf(1.0, rock_tint.b, 0.45),
		base_color.a * rock_tint.a,
	)


func _validated_mode(effect_mode: StringName) -> StringName:
	if effect_mode in [
		MODE_SMALL_BREAK,
		MODE_DRILL_TICK,
		MODE_BIG_BREAK,
		MODE_RICOCHET_SCRAPE,
		MODE_FINAL_COLLAPSE,
	]:
		return effect_mode
	return MODE_SMALL_BREAK


func _profile_for(effect_mode: StringName) -> Dictionary:
	match effect_mode:
		MODE_DRILL_TICK:
			return {
				"chunks": 5,
				"dots": 12,
				"dust": 1,
				"spread_degrees": 22.0,
				"dot_spread_degrees": 28.0,
				"speed_min": 145.0,
				"speed_max": 285.0,
				"dot_speed_min": 125.0,
				"dot_speed_max": 330.0,
				"life_min": 0.45,
				"life_max": 0.90,
				"dot_life_min": 0.28,
				"dot_life_max": 0.72,
				"chunk_size_min": 18.0,
				"chunk_size_max": 43.0,
				"drag": 2.8,
				"gravity": 105.0,
				"drill_spark_fraction": 0.24,
			}
		MODE_BIG_BREAK:
			return {
				"chunks": 20,
				"dots": 50,
				"dust": 5,
				"spread_degrees": 58.0,
				"dot_spread_degrees": 68.0,
				"speed_min": 235.0,
				"speed_max": 520.0,
				"dot_speed_min": 160.0,
				"dot_speed_max": 480.0,
				"life_min": 1.05,
				"life_max": 2.20,
				"dot_life_min": 0.65,
				"dot_life_max": 1.55,
				"chunk_size_min": 38.0,
				"chunk_size_max": 98.0,
				"drag": 1.55,
				"gravity": 150.0,
				"falling_chunk_fraction": 0.18,
			}
		MODE_RICOCHET_SCRAPE:
			return {
				"chunks": 3,
				"dots": 10,
				"dust": 0,
				"spread_degrees": 16.0,
				"dot_spread_degrees": 20.0,
				"speed_min": 150.0,
				"speed_max": 280.0,
				"dot_speed_min": 180.0,
				"dot_speed_max": 360.0,
				"life_min": 0.25,
				"life_max": 0.55,
				"dot_life_min": 0.18,
				"dot_life_max": 0.48,
				"chunk_size_min": 10.0,
				"chunk_size_max": 25.0,
				"drag": 3.4,
				"gravity": 90.0,
			}
		MODE_FINAL_COLLAPSE:
			return {
				"chunks": 22,
				"dots": 56,
				"dust": 6,
				"spread_degrees": 76.0,
				"dot_spread_degrees": 86.0,
				"speed_min": 245.0,
				"speed_max": 550.0,
				"dot_speed_min": 165.0,
				"dot_speed_max": 510.0,
				"life_min": 1.15,
				"life_max": 2.35,
				"dot_life_min": 0.75,
				"dot_life_max": 1.70,
				"chunk_size_min": 42.0,
				"chunk_size_max": 112.0,
				"drag": 1.40,
				"gravity": 175.0,
				"falling_chunk_fraction": 0.30,
			}
		_:
			return {
				"chunks": 11,
				"dots": 28,
				"dust": 3,
				"spread_degrees": 46.0,
				"dot_spread_degrees": 55.0,
				"speed_min": 185.0,
				"speed_max": 405.0,
				"dot_speed_min": 130.0,
				"dot_speed_max": 390.0,
				"life_min": 0.72,
				"life_max": 1.55,
				"dot_life_min": 0.42,
				"dot_life_max": 1.10,
				"chunk_size_min": 26.0,
				"chunk_size_max": 76.0,
				"drag": 2.05,
				"gravity": 125.0,
				"falling_chunk_fraction": 0.08,
			}


func get_debug_lines() -> Array[String]:
	return [
		"[RockDebrisBurst]",
		"active=%s" % str(_active),
		"mode=%s" % String(_active_mode),
		"chunks=%d" % _active_chunk_count,
		"dots=%d" % _dots.size(),
		"dust=%d" % _dust.size(),
	]
