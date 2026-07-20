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

@export_category("Lifecycle")
@export var auto_free_when_finished: bool = true
@export_range(0.10, 5.0, 0.05) var maximum_lifetime_seconds: float = 3.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _chunk_sprites: Array[Sprite2D] = []
var _chunk_velocity: Array[Vector2] = []
var _chunk_spin: Array[float] = []
var _chunk_remaining: Array[float] = []
var _chunk_lifetime: Array[float] = []
var _chunk_base_scale: Array[Vector2] = []
var _dot_particles: Array[Dictionary] = []
var _dust_puffs: Array[Dictionary] = []
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
	for puff: Dictionary in _dust_puffs:
		var remaining: float = float(puff.get("remaining", 0.0))
		if remaining <= 0.0:
			continue
		var lifetime: float = maxf(0.01, float(puff.get("lifetime", 1.0)))
		var ratio: float = clampf(remaining / lifetime, 0.0, 1.0)
		var color_value: Color = puff.get("color", ROCK_PALETTE[1])
		color_value.a *= ratio * ratio
		draw_circle(
			puff.get("position", Vector2.ZERO),
			float(puff.get("radius", 12.0)),
			color_value,
		)

	for particle: Dictionary in _dot_particles:
		var remaining: float = float(particle.get("remaining", 0.0))
		if remaining <= 0.0:
			continue
		var lifetime: float = maxf(0.01, float(particle.get("lifetime", 1.0)))
		var ratio: float = clampf(remaining / lifetime, 0.0, 1.0)
		var color_value: Color = particle.get("color", ROCK_PALETTE[2])
		color_value.a *= minf(1.0, ratio * 1.8)
		draw_circle(
			particle.get("position", Vector2.ZERO),
			float(particle.get("radius", 2.0)) * lerpf(0.45, 1.0, ratio),
			color_value,
		)


func _build_chunk_pool() -> void:
	for index: int in range(MAX_CHUNKS):
		var chunk: Sprite2D = Sprite2D.new()
		chunk.name = "DebrisChunk%02d" % index
		chunk.z_index = 1
		chunk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		chunk.hide()
		add_child(chunk)
		_chunk_sprites.append(chunk)
		_chunk_velocity.append(Vector2.ZERO)
		_chunk_spin.append(0.0)
		_chunk_remaining.append(0.0)
		_chunk_lifetime.append(0.0)
		_chunk_base_scale.append(Vector2.ONE)


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
		var chunk: Sprite2D = _chunk_sprites[index]
		var texture: Texture2D = DEBRIS_TEXTURES[_rng.randi_range(0, DEBRIS_TEXTURES.size() - 1)]
		chunk.texture = texture
		chunk.position = Vector2.ZERO
		chunk.rotation = _rng.randf_range(-PI, PI)
		var desired_size: float = _rng.randf_range(size_min, size_max)
		var texture_extent: float = maxf(1.0, maxf(float(texture.get_width()), float(texture.get_height())))
		var scale_value: float = desired_size / texture_extent
		if _rng.randf() < 0.45:
			scale_value *= -1.0
		chunk.scale = Vector2(scale_value, absf(scale_value))
		_chunk_base_scale[index] = chunk.scale
		chunk.modulate = _tinted_rock_color(_choose_rock_color(false), rock_tint)
		chunk.show()

		var launch_direction: Vector2 = emit_direction.rotated(
			_rng.randf_range(-spread_radians, spread_radians)
		)
		if _rng.randf() < downward_fraction:
			launch_direction = Vector2(
				launch_direction.x * _rng.randf_range(0.35, 0.85),
				absf(launch_direction.y) + _rng.randf_range(0.25, 0.75),
			).normalized()
		_chunk_velocity[index] = launch_direction * _rng.randf_range(speed_min, speed_max)
		_chunk_spin[index] = _rng.randf_range(-8.0, 8.0)
		_chunk_lifetime[index] = _rng.randf_range(life_min, life_max)
		_chunk_remaining[index] = _chunk_lifetime[index]

	for index: int in range(_active_chunk_count, MAX_CHUNKS):
		_chunk_sprites[index].hide()
		_chunk_remaining[index] = 0.0


func _spawn_dots(
		profile: Dictionary,
		emit_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	var dot_count: int = maxi(0, roundi(float(profile.get("dots", 0)) * intensity))
	var spread_radians: float = deg_to_rad(float(profile.get("dot_spread_degrees", profile.get("spread_degrees", 45.0))))
	var speed_min: float = float(profile.get("dot_speed_min", 120.0)) * sqrt(intensity)
	var speed_max: float = float(profile.get("dot_speed_max", 340.0)) * sqrt(intensity)
	var life_min: float = float(profile.get("dot_life_min", 0.35))
	var life_max: float = float(profile.get("dot_life_max", 1.10))
	var drill_spark_fraction: float = float(profile.get("drill_spark_fraction", 0.0))

	for _index: int in range(dot_count):
		var is_drill_spark: bool = _rng.randf() < drill_spark_fraction
		var color_value: Color
		if is_drill_spark:
			color_value = DRILL_SPARK_PALETTE[_rng.randi_range(0, DRILL_SPARK_PALETTE.size() - 1)]
		else:
			color_value = _tinted_rock_color(_choose_rock_color(true), rock_tint)
		var direction: Vector2 = emit_direction.rotated(
			_rng.randf_range(-spread_radians, spread_radians)
		)
		var lifetime: float = _rng.randf_range(life_min, life_max)
		_dot_particles.append({
			"position": Vector2.ZERO,
			"velocity": direction * _rng.randf_range(speed_min, speed_max),
			"remaining": lifetime,
			"lifetime": lifetime,
			"radius": _rng.randf_range(1.2, 3.8 if not is_drill_spark else 2.6),
			"color": color_value,
		})


func _spawn_dust(
		profile: Dictionary,
		emit_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	var dust_count: int = maxi(0, roundi(float(profile.get("dust", 0)) * minf(intensity, 1.6)))
	for _index: int in range(dust_count):
		var lifetime: float = _rng.randf_range(0.55, 1.25)
		var dust_color: Color = _tinted_rock_color(
			ROCK_PALETTE[_rng.randi_range(0, 2)],
			rock_tint,
		)
		dust_color.a = _rng.randf_range(0.10, 0.24)
		_dust_puffs.append({
			"position": emit_direction * _rng.randf_range(0.0, 22.0),
			"velocity": emit_direction.rotated(_rng.randf_range(-0.75, 0.75)) * _rng.randf_range(12.0, 48.0),
			"remaining": lifetime,
			"lifetime": lifetime,
			"radius": _rng.randf_range(12.0, 30.0) * sqrt(intensity),
			"growth": _rng.randf_range(20.0, 52.0),
			"color": dust_color,
		})


func _update_chunks(delta: float) -> void:
	var drag_factor: float = exp(-maxf(0.0, _active_drag) * delta)
	for index: int in range(_active_chunk_count):
		if _chunk_remaining[index] <= 0.0:
			continue
		_chunk_remaining[index] = maxf(0.0, _chunk_remaining[index] - delta)
		_chunk_velocity[index] *= drag_factor
		_chunk_velocity[index].y += _active_gravity * delta
		var chunk: Sprite2D = _chunk_sprites[index]
		chunk.position += _chunk_velocity[index] * delta
		chunk.rotation += _chunk_spin[index] * delta
		var ratio: float = _chunk_remaining[index] / maxf(0.01, _chunk_lifetime[index])
		chunk.modulate.a = minf(1.0, ratio * 1.7)
		chunk.scale = _chunk_base_scale[index] * lerpf(0.72, 1.0, ratio)
		if _chunk_remaining[index] <= 0.0:
			chunk.hide()


func _update_dots(delta: float) -> void:
	var drag_factor: float = exp(-maxf(0.0, _active_drag * 1.35) * delta)
	for index: int in range(_dot_particles.size()):
		var particle: Dictionary = _dot_particles[index]
		var remaining: float = maxf(0.0, float(particle.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			particle["remaining"] = 0.0
			_dot_particles[index] = particle
			continue
		var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
		velocity *= drag_factor
		velocity.y += _active_gravity * 0.45 * delta
		particle["velocity"] = velocity
		particle["position"] = particle.get("position", Vector2.ZERO) + velocity * delta
		particle["remaining"] = remaining
		_dot_particles[index] = particle


func _update_dust(delta: float) -> void:
	for index: int in range(_dust_puffs.size()):
		var puff: Dictionary = _dust_puffs[index]
		var remaining: float = maxf(0.0, float(puff.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			puff["remaining"] = 0.0
			_dust_puffs[index] = puff
			continue
		var velocity: Vector2 = puff.get("velocity", Vector2.ZERO)
		velocity *= exp(-1.9 * delta)
		puff["velocity"] = velocity
		puff["position"] = puff.get("position", Vector2.ZERO) + velocity * delta
		puff["radius"] = float(puff.get("radius", 12.0)) + float(puff.get("growth", 24.0)) * delta
		puff["remaining"] = remaining
		_dust_puffs[index] = puff


func _has_live_particles() -> bool:
	for remaining: float in _chunk_remaining:
		if remaining > 0.0:
			return true
	for particle: Dictionary in _dot_particles:
		if float(particle.get("remaining", 0.0)) > 0.0:
			return true
	for puff: Dictionary in _dust_puffs:
		if float(puff.get("remaining", 0.0)) > 0.0:
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
	_dot_particles.clear()
	_dust_puffs.clear()
	_active_chunk_count = 0
	_elapsed = 0.0
	for index: int in range(_chunk_sprites.size()):
		_chunk_sprites[index].hide()
		_chunk_sprites[index].modulate = Color.WHITE
		_chunk_remaining[index] = 0.0
		_chunk_lifetime[index] = 0.0
		_chunk_velocity[index] = Vector2.ZERO
		_chunk_spin[index] = 0.0


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
		"dots=%d" % _dot_particles.size(),
		"dust=%d" % _dust_puffs.size(),
	]
