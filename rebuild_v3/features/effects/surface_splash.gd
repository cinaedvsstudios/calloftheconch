class_name CotcSurfaceSplash
extends AnimatedSprite2D

const RING_POINT_COUNT: int = 40
const RING_BASE_RADIUS: float = 50.0
const FALLBACK_HORIZONTAL_SPEED: float = 220.0

@export_category("Surface Splash VFX")
@export_range(0.20, 2.00, 0.01) var effect_duration: float = 0.90
@export_range(0.10, 1.00, 0.01) var ring_duration: float = 0.48
@export var exit_ring_scale: Vector2 = Vector2(2.45, 0.46)
@export var entry_ring_scale: Vector2 = Vector2(2.90, 0.54)
@export_range(100.0, 2000.0, 10.0) var horizontal_velocity_reference: float = 900.0

@onready var _droplet_burst: GPUParticles2D = %DropletBurst
@onready var _fine_mist: GPUParticles2D = %FineMist
@onready var _surface_ring: Line2D = %SurfaceRing
@onready var _effect_timer: Timer = %EffectTimer

var _droplet_material: ParticleProcessMaterial
var _mist_material: ParticleProcessMaterial
var _ring_tween: Tween
var _default_is_exit: bool = true


func _ready() -> void:
	_default_is_exit = not name.to_lower().contains("entry")
	animation_finished.connect(_on_animation_finished)
	_effect_timer.timeout.connect(stop_splash)
	_duplicate_particle_materials()
	_prepare_surface_ring()
	stop_splash()


func trigger(
		world_position: Vector2,
		is_exit_override: Variant = null,
		horizontal_velocity: float = 0.0,
	) -> void:
	var is_exit: bool = _default_is_exit
	if is_exit_override is bool:
		is_exit = bool(is_exit_override)
	var resolved_horizontal_velocity: float = _resolve_horizontal_velocity(horizontal_velocity)

	stop_splash()
	global_position = world_position
	show()
	self_modulate = Color.WHITE
	frame = 0
	_configure_particles(is_exit, resolved_horizontal_velocity)
	_start_particles()
	_start_surface_ring(is_exit, resolved_horizontal_velocity)
	play(&"splash")
	_effect_timer.start(effect_duration)


func stop_splash() -> void:
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	_ring_tween = null
	_effect_timer.stop()
	stop()
	frame = 0
	self_modulate = Color.WHITE
	_stop_particles()
	_surface_ring.hide()
	_surface_ring.position = Vector2.ZERO
	_surface_ring.scale = Vector2.ONE
	_surface_ring.modulate = Color.WHITE
	hide()


func _resolve_horizontal_velocity(provided_velocity: float) -> float:
	if not is_zero_approx(provided_velocity):
		return provided_velocity
	var level_owner: Node = owner
	if level_owner == null:
		level_owner = get_parent()
	if level_owner == null:
		return 0.0

	var hylas: CharacterBody2D = level_owner.get_node_or_null("%Hylas") as CharacterBody2D
	if hylas == null:
		return 0.0
	if not is_zero_approx(hylas.velocity.x):
		return hylas.velocity.x

	var hylas_sprite: AnimatedSprite2D = hylas.get_node_or_null("%AnimatedSprite") as AnimatedSprite2D
	if hylas_sprite == null:
		return 0.0
	return -FALLBACK_HORIZONTAL_SPEED if hylas_sprite.flip_h else FALLBACK_HORIZONTAL_SPEED


func _duplicate_particle_materials() -> void:
	var droplet_source: ParticleProcessMaterial = (
		_droplet_burst.process_material as ParticleProcessMaterial
	)
	if droplet_source != null:
		_droplet_material = droplet_source.duplicate(true) as ParticleProcessMaterial
		_droplet_burst.process_material = _droplet_material

	var mist_source: ParticleProcessMaterial = (
		_fine_mist.process_material as ParticleProcessMaterial
	)
	if mist_source != null:
		_mist_material = mist_source.duplicate(true) as ParticleProcessMaterial
		_fine_mist.process_material = _mist_material


func _prepare_surface_ring() -> void:
	var ring_points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(RING_POINT_COUNT):
		var angle: float = TAU * float(point_index) / float(RING_POINT_COUNT)
		ring_points.append(Vector2(cos(angle), sin(angle)) * RING_BASE_RADIUS)
	_surface_ring.points = ring_points
	_surface_ring.closed = true
	_surface_ring.hide()


func _configure_particles(is_exit: bool, horizontal_velocity: float) -> void:
	var horizontal_bias: float = clampf(
		horizontal_velocity / maxf(1.0, horizontal_velocity_reference),
		-0.72,
		0.72,
	)
	var vertical_direction: float = -1.0 if is_exit else 1.0
	var droplet_direction: Vector3 = Vector3(
		horizontal_bias,
		vertical_direction,
		0.0,
	).normalized()
	var mist_direction: Vector3 = Vector3(
		horizontal_bias * 0.55,
		vertical_direction,
		0.0,
	).normalized()

	if _droplet_material != null:
		_droplet_material.direction = droplet_direction
		_droplet_material.spread = 54.0 if is_exit else 72.0
		_droplet_material.gravity = (
			Vector3(0.0, 620.0, 0.0)
			if is_exit
			else Vector3(0.0, 760.0, 0.0)
		)
		_droplet_material.initial_velocity_min = 260.0 if is_exit else 310.0
		_droplet_material.initial_velocity_max = 480.0 if is_exit else 540.0

	if _mist_material != null:
		_mist_material.direction = mist_direction
		_mist_material.spread = 68.0 if is_exit else 82.0
		_mist_material.gravity = (
			Vector3(0.0, 170.0, 0.0)
			if is_exit
			else Vector3(0.0, 260.0, 0.0)
		)
		_mist_material.initial_velocity_min = 80.0 if is_exit else 105.0
		_mist_material.initial_velocity_max = 175.0 if is_exit else 220.0


func _start_particles() -> void:
	for particles: GPUParticles2D in [_droplet_burst, _fine_mist]:
		particles.process_mode = Node.PROCESS_MODE_INHERIT
		particles.emitting = true
		particles.restart()


func _stop_particles() -> void:
	for particles: GPUParticles2D in [_droplet_burst, _fine_mist]:
		particles.emitting = false
		particles.process_mode = Node.PROCESS_MODE_DISABLED


func _start_surface_ring(is_exit: bool, horizontal_velocity: float) -> void:
	var horizontal_offset: float = clampf(horizontal_velocity * 0.015, -20.0, 20.0)
	var target_offset: float = clampf(horizontal_velocity * 0.035, -55.0, 55.0)
	var target_scale: Vector2 = exit_ring_scale if is_exit else entry_ring_scale

	_surface_ring.position = Vector2(horizontal_offset, 0.0)
	_surface_ring.scale = Vector2(0.28, 0.10)
	_surface_ring.width = 7.0 if is_exit else 9.0
	_surface_ring.modulate = Color(0.78, 0.96, 1.0, 0.95)
	_surface_ring.show()

	_ring_tween = create_tween()
	_ring_tween.set_parallel(true)
	_ring_tween.tween_property(
		_surface_ring,
		&"scale",
		target_scale,
		ring_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(
		_surface_ring,
		&"position:x",
		target_offset,
		ring_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(
		_surface_ring,
		&"width",
		2.0,
		ring_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(
		_surface_ring,
		&"modulate:a",
		0.0,
		ring_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_animation_finished() -> void:
	if animation != &"splash":
		return
	stop()
	self_modulate.a = 0.0
