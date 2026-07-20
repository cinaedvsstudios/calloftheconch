class_name CotcRicochetContactFx
extends Node2D

## Presentation-only impact effect for a successful Hylas ricochet wall contact.
## Movement and gameplay stay in Hylas; this scene only draws the contact flash,
## cyan sparks, and optional rock debris scrape at the collision point.

signal finished

const ROCK_SURFACE_KIND: StringName = &"rock"
const STONE_SURFACE_KIND: StringName = &"stone"
const ROCK_DEBRIS_BURST_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/rock_debris_burst/rock_debris_burst.tscn"
)

class SparkParticle:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var remaining: float = 0.0
	var lifetime: float = 0.0
	var length: float = 18.0
	var width: float = 2.0
	var color: Color = Color.WHITE

@export_category("Flash")
@export var flash_color: Color = Color(0.55, 1.0, 1.0, 1.0)
@export var flash_core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.02, 0.50, 0.01) var flash_lifetime_seconds: float = 0.12
@export_range(4.0, 96.0, 1.0) var flash_radius: float = 26.0

@export_category("Sparks")
@export_range(0, 48, 1) var spark_count: int = 10
@export_range(40.0, 1200.0, 10.0) var spark_speed_min: float = 220.0
@export_range(40.0, 1600.0, 10.0) var spark_speed_max: float = 520.0
@export_range(0.02, 1.00, 0.01) var spark_lifetime_min: float = 0.10
@export_range(0.02, 1.00, 0.01) var spark_lifetime_max: float = 0.22
@export_range(0.0, 180.0, 1.0) var spark_spread_degrees: float = 58.0
@export_range(0.0, 20.0, 0.1) var spark_drag: float = 7.0

@export_category("Debris")
@export var play_rock_debris: bool = true
@export_range(0.10, 3.0, 0.05) var debris_intensity: float = 0.70

@export_category("Lifecycle")
@export var auto_free_when_finished: bool = true
@export_range(0.10, 2.0, 0.05) var maximum_lifetime_seconds: float = 0.65

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sparks: Array[SparkParticle] = []
var _flash_remaining: float = 0.0
var _elapsed: float = 0.0
var _active: bool = false


func _ready() -> void:
	_rng.randomize()
	hide()
	set_process(false)


func play_contact(
		contact_position: Vector2,
		surface_normal: Vector2,
		incoming_direction: Vector2,
		new_direction: Vector2,
		surface_kind: StringName = ROCK_SURFACE_KIND,
		rock_tint: Color = Color.WHITE,
		intensity: float = 1.0,
	) -> void:
	global_position = contact_position
	global_rotation = 0.0
	global_scale = Vector2.ONE

	var resolved_normal: Vector2 = _safe_direction(surface_normal, -incoming_direction)
	var resolved_incoming: Vector2 = _safe_direction(incoming_direction, -resolved_normal)
	var resolved_intensity: float = clampf(intensity, 0.10, 3.0)

	_sparks.clear()
	_flash_remaining = flash_lifetime_seconds
	_elapsed = 0.0
	_spawn_sparks(resolved_normal, resolved_incoming, resolved_intensity)
	_spawn_rock_debris(surface_kind, resolved_normal, resolved_incoming, rock_tint, resolved_intensity)

	_active = true
	show()
	set_process(true)
	queue_redraw()


func stop_effect() -> void:
	_sparks.clear()
	_flash_remaining = 0.0
	_active = false
	set_process(false)
	hide()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	_elapsed += safe_delta
	_flash_remaining = maxf(0.0, _flash_remaining - safe_delta)
	_update_sparks(safe_delta)
	queue_redraw()
	if _elapsed >= maximum_lifetime_seconds or (_flash_remaining <= 0.0 and not _has_live_sparks()):
		_finish_effect()


func _draw() -> void:
	_draw_flash()
	_draw_sparks()


func _draw_flash() -> void:
	if _flash_remaining <= 0.0:
		return
	var ratio: float = clampf(_flash_remaining / maxf(0.01, flash_lifetime_seconds), 0.0, 1.0)
	var radius: float = flash_radius * lerpf(1.35, 0.35, ratio)
	var outer_color: Color = flash_color
	outer_color.a *= ratio * 0.65
	var inner_color: Color = flash_core_color
	inner_color.a *= ratio
	draw_circle(Vector2.ZERO, radius, outer_color)
	draw_circle(Vector2.ZERO, radius * 0.38, inner_color)


func _draw_sparks() -> void:
	for spark: SparkParticle in _sparks:
		if spark.remaining <= 0.0:
			continue
		var ratio: float = clampf(spark.remaining / maxf(0.01, spark.lifetime), 0.0, 1.0)
		var spark_color: Color = spark.color
		spark_color.a *= minf(1.0, ratio * 1.6)
		var spark_direction: Vector2 = _safe_direction(spark.velocity, Vector2.RIGHT)
		draw_line(
			spark.position,
			spark.position - spark_direction * spark.length * lerpf(0.45, 1.0, ratio),
			spark_color,
			spark.width * ratio,
			true
		)


func _spawn_sparks(surface_normal: Vector2, incoming_direction: Vector2, intensity: float) -> void:
	var resolved_count: int = maxi(0, roundi(float(spark_count) * intensity))
	var spread_radians: float = deg_to_rad(spark_spread_degrees)
	var tangent: Vector2 = Vector2(-surface_normal.y, surface_normal.x)
	for index: int in range(resolved_count):
		var spark: SparkParticle = SparkParticle.new()
		var scrape_mix: float = _rng.randf_range(-0.42, 0.42)
		var direction: Vector2 = (
			surface_normal
			+ tangent * scrape_mix
			- incoming_direction * _rng.randf_range(0.0, 0.25)
		).normalized()
		if direction.length_squared() <= 0.0001:
			direction = surface_normal
		direction = direction.rotated(_rng.randf_range(-spread_radians, spread_radians) * 0.5)
		spark.velocity = direction * _rng.randf_range(spark_speed_min, spark_speed_max) * sqrt(intensity)
		spark.lifetime = _rng.randf_range(spark_lifetime_min, spark_lifetime_max)
		spark.remaining = spark.lifetime
		spark.length = _rng.randf_range(10.0, 26.0) * sqrt(intensity)
		spark.width = _rng.randf_range(1.1, 2.8)
		spark.color = _spark_color(index)
		_sparks.append(spark)


func _spawn_rock_debris(
		surface_kind: StringName,
		surface_normal: Vector2,
		incoming_direction: Vector2,
		rock_tint: Color,
		intensity: float,
	) -> void:
	if not play_rock_debris:
		return
	if surface_kind != ROCK_SURFACE_KIND and surface_kind != STONE_SURFACE_KIND:
		return
	var debris: Node = ROCK_DEBRIS_BURST_SCENE.instantiate()
	if debris == null:
		return
	var effect_parent: Node = get_parent()
	if effect_parent == null:
		add_child(debris)
	else:
		effect_parent.add_child(debris)
	if debris.has_method(&"play_burst"):
		debris.call(
			&"play_burst",
			global_position,
			surface_normal,
			incoming_direction,
			&"ricochet_scrape",
			rock_tint,
			debris_intensity * intensity
		)


func _update_sparks(delta: float) -> void:
	var drag_factor: float = exp(-maxf(0.0, spark_drag) * delta)
	for spark: SparkParticle in _sparks:
		if spark.remaining <= 0.0:
			continue
		spark.remaining = maxf(0.0, spark.remaining - delta)
		spark.position += spark.velocity * delta
		spark.velocity *= drag_factor


func _has_live_sparks() -> bool:
	for spark: SparkParticle in _sparks:
		if spark.remaining > 0.0:
			return true
	return false


func _finish_effect() -> void:
	finished.emit()
	_active = false
	set_process(false)
	hide()
	if auto_free_when_finished:
		queue_free()


func _safe_direction(direction: Vector2, fallback: Vector2) -> Vector2:
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	if fallback.length_squared() > 0.0001:
		return fallback.normalized()
	return Vector2.RIGHT


func _spark_color(index: int) -> Color:
	match index % 3:
		0:
			return Color(0.35, 1.0, 1.0, 1.0)
		1:
			return Color(0.75, 1.0, 1.0, 1.0)
		_:
			return Color(0.15, 0.72, 1.0, 1.0)
