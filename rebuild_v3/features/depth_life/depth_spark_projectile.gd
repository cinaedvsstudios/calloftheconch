class_name CotcDepthSparkProjectile
extends Area2D

signal hylas_touched(hylas: Node2D)

@export_category("Lifetime")
@export_range(1.0, 15.0, 0.1) var lifetime_seconds: float = 6.5
@export_range(0.1, 4.0, 0.1) var fade_seconds: float = 1.25

@export_category("Motion")
@export_range(0.0, 300.0, 1.0) var gravity: float = 72.0
@export_range(0.0, 200.0, 1.0) var horizontal_drag: float = 30.0
@export_range(0.0, 240.0, 1.0) var maximum_fall_speed: float = 112.0
@export_range(0.0, 80.0, 1.0) var drift_amplitude: float = 18.0
@export_range(0.1, 5.0, 0.1) var drift_cycles_per_second: float = 0.75
@export_range(-360.0, 360.0, 1.0) var spin_degrees_per_second: float = 120.0

@onready var _core: Sprite2D = %SparkCore
@onready var _halo: Sprite2D = %SparkHalo
@onready var _collision_shape: CollisionShape2D = %CollisionShape2D

var _velocity: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _phase: float = 0.0
var _hit_consumed: bool = false
var _base_core_scale: Vector2 = Vector2.ONE
var _base_halo_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_base_core_scale = _core.scale
	_base_halo_scale = _halo.scale
	body_entered.connect(_on_body_entered)


func configure(
		initial_velocity: Vector2,
		requested_lifetime: float,
		colour: Color,
		phase: float,
		visual_scale: float = 1.0,
	) -> void:
	_velocity = initial_velocity
	lifetime_seconds = maxf(0.2, requested_lifetime)
	_phase = phase
	var clamped_scale: float = maxf(0.2, visual_scale)
	_core.scale *= clamped_scale
	_halo.scale *= clamped_scale
	_base_core_scale = _core.scale
	_base_halo_scale = _halo.scale
	_core.modulate = Color(colour.r, colour.g, colour.b, 1.0)
	_halo.modulate = Color(colour.r, colour.g, colour.b, 0.55)


func _physics_process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	if _elapsed >= lifetime_seconds:
		queue_free()
		return

	_velocity.x = move_toward(_velocity.x, 0.0, horizontal_drag * delta)
	_velocity.y = minf(maximum_fall_speed, _velocity.y + gravity * delta)
	var drift: float = sin((_elapsed * drift_cycles_per_second + _phase) * TAU) * drift_amplitude
	global_position += (_velocity + Vector2(drift, 0.0)) * delta
	rotation += deg_to_rad(spin_degrees_per_second) * delta

	var pulse: float = 1.0 + sin((_elapsed * 3.0 + _phase) * TAU) * 0.12
	_core.scale = _base_core_scale * pulse
	_halo.scale = _base_halo_scale * (1.0 + (pulse - 1.0) * 1.6)

	var fade_start: float = maxf(0.0, lifetime_seconds - fade_seconds)
	if _elapsed <= fade_start:
		return
	var fade_progress: float = clampf(
		(_elapsed - fade_start) / maxf(0.01, fade_seconds),
		0.0,
		1.0,
	)
	_core.modulate.a = 1.0 - fade_progress
	_halo.modulate.a = 0.55 * (1.0 - fade_progress)
	if fade_progress >= 0.85:
		_collision_shape.set_deferred(&"disabled", true)


func _on_body_entered(body: Node2D) -> void:
	if _hit_consumed or not body.is_in_group(&"hylas"):
		return
	_hit_consumed = true
	_collision_shape.set_deferred(&"disabled", true)
	hylas_touched.emit(body)
	queue_free()
