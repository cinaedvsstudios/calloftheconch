class_name CotcWeaponEmissionFX2D
extends Node2D

const PROFILE_NORMAL_CONCH: StringName = &"normal_conch"
const PROFILE_SUPER_CONCH: StringName = &"super_conch"
const PROFILE_TEREBRIDAE: StringName = &"terebridae"
const PROFILE_CONUS_TEXTILE: StringName = &"conus_textile"

@export_category("Weapon Emission VFX")
@export_range(0.10, 1.00, 0.01) var effect_duration: float = 0.20
@export var sparks_only: bool = false

@export_category("Optional Autoplay")
@export var autoplay_on_ready: bool = false
@export var autoplay_profile_id: StringName = PROFILE_NORMAL_CONCH
@export var autoplay_parent_anchor_method: StringName = &""
@export var autoplay_direction_node_path: NodePath = ^""

@onready var _radial_glow: Sprite2D = %RadialGlow
@onready var _additive_core: Sprite2D = %AdditiveCore
@onready var _primary_sparks: GPUParticles2D = %PrimarySparks
@onready var _accent_sparks: GPUParticles2D = %AccentSparks
@onready var _finish_timer: Timer = %FinishTimer

var _primary_process_material: ParticleProcessMaterial
var _accent_process_material: ParticleProcessMaterial
var _effect_tween: Tween
var _active_profile_id: StringName = &""
var _active: bool = false


func _ready() -> void:
	_finish_timer.timeout.connect(stop_effect)
	_duplicate_particle_materials()
	stop_effect()
	if sparks_only:
		_radial_glow.hide()
		_additive_core.hide()
	if autoplay_on_ready:
		call_deferred(&"_play_deferred_autoplay")


func play_profile(
		profile_id: StringName = PROFILE_NORMAL_CONCH,
		local_direction: Vector2 = Vector2.RIGHT,
		primary_override: Variant = null,
	) -> void:
	stop_effect()
	_active_profile_id = _normalize_profile_id(profile_id)

	var primary_color: Color = Color(0.10, 0.88, 1.00, 1.00)
	var accent_color: Color = Color(0.70, 0.96, 1.00, 1.00)
	var core_color: Color = Color(0.90, 0.99, 1.00, 1.00)
	var glow_scale: float = 0.99
	var core_scale: float = 0.405
	var primary_amount: int = 16
	var accent_amount: int = 7
	var spark_spread: float = 42.0
	var primary_velocity_min: float = 230.0
	var primary_velocity_max: float = 430.0
	var accent_velocity_min: float = 150.0
	var accent_velocity_max: float = 310.0
	var spark_scale_min: float = 0.0675
	var spark_scale_max: float = 0.165
	var angular_velocity: float = 90.0
	var play_duration: float = effect_duration

	match _active_profile_id:
		PROFILE_SUPER_CONCH:
			primary_color = Color(0.16, 1.00, 0.30, 1.00)
			accent_color = Color(0.76, 1.00, 0.80, 1.00)
			core_color = Color(0.96, 1.00, 0.96, 1.00)
			glow_scale = 0.91125
			core_scale = 0.37125
			primary_amount = 23
			accent_amount = 10
			spark_spread = 54.0
			primary_velocity_min = 280.0
			primary_velocity_max = 530.0
			accent_velocity_min = 190.0
			accent_velocity_max = 390.0
			spark_scale_min = 0.055
			spark_scale_max = 0.13
			angular_velocity = 120.0
			play_duration = maxf(effect_duration, 0.24)
		PROFILE_TEREBRIDAE:
			primary_color = Color(1.00, 0.08, 0.88, 1.00)
			accent_color = Color(1.00, 0.66, 0.94, 1.00)
			core_color = Color(1.00, 0.88, 0.98, 1.00)
			glow_scale = 0.81
			core_scale = 0.375
			primary_amount = 18
			accent_amount = 8
			spark_spread = 17.0
			primary_velocity_min = 300.0
			primary_velocity_max = 520.0
			accent_velocity_min = 210.0
			accent_velocity_max = 390.0
			spark_scale_min = 0.08
			spark_scale_max = 0.19
			angular_velocity = 300.0
			play_duration = minf(effect_duration, 0.16)
		PROFILE_CONUS_TEXTILE:
			primary_color = Color(1.00, 0.42, 0.06, 1.00)
			accent_color = Color(0.62, 0.18, 1.00, 1.00)
			core_color = Color(1.00, 0.91, 0.78, 1.00)
			glow_scale = 0.93
			core_scale = 0.39
			primary_amount = 16
			accent_amount = 11
			spark_spread = 32.0
			primary_velocity_min = 255.0
			primary_velocity_max = 465.0
			accent_velocity_min = 185.0
			accent_velocity_max = 350.0
			spark_scale_min = 0.09
			spark_scale_max = 0.21
			angular_velocity = 180.0
			play_duration = maxf(effect_duration, 0.22)

	if primary_override is Color:
		primary_color = primary_override
		accent_color = primary_color.lerp(Color.WHITE, 0.72)

	var resolved_direction: Vector2 = local_direction
	if resolved_direction.length_squared() <= 0.0001:
		resolved_direction = Vector2.RIGHT
	else:
		resolved_direction = resolved_direction.normalized()

	_configure_particle_material(
		_primary_process_material,
		resolved_direction,
		spark_spread,
		primary_velocity_min,
		primary_velocity_max,
		spark_scale_min,
		spark_scale_max,
		angular_velocity,
	)
	_configure_particle_material(
		_accent_process_material,
		resolved_direction,
		maxf(6.0, spark_spread * 0.72),
		accent_velocity_min,
		accent_velocity_max,
		spark_scale_min * 0.72,
		spark_scale_max * 0.72,
		-angular_velocity,
	)

	_primary_sparks.amount = primary_amount
	_accent_sparks.amount = accent_amount
	_primary_sparks.modulate = primary_color
	_accent_sparks.modulate = accent_color

	_radial_glow.scale = Vector2.ONE * glow_scale * 0.34
	_additive_core.scale = Vector2.ONE * core_scale * 0.55
	_radial_glow.modulate = Color(primary_color.r, primary_color.g, primary_color.b, 0.88)
	_additive_core.modulate = Color(core_color.r, core_color.g, core_color.b, 1.00)

	show()
	_active = true
	_start_particle_burst(_primary_sparks)
	_start_particle_burst(_accent_sparks)
	_start_visual_tween(glow_scale, core_scale, play_duration)
	_finish_timer.start(play_duration)


func _on_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		_target: Node,
	) -> void:
	var impact_direction: Vector2 = normal.normalized()
	if impact_direction.length_squared() <= 0.0001:
		impact_direction = Vector2.RIGHT
	top_level = true
	global_position = contact_position
	global_rotation = 0.0
	play_profile(PROFILE_NORMAL_CONCH, impact_direction)


func stop_effect() -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
	_effect_tween = null
	_finish_timer.stop()
	_stop_particles(_primary_sparks)
	_stop_particles(_accent_sparks)
	_radial_glow.modulate.a = 0.0
	_additive_core.modulate.a = 0.0
	_active = false
	_active_profile_id = &""
	hide()


func is_active() -> bool:
	return _active


func get_active_profile_id() -> StringName:
	return _active_profile_id


func _play_deferred_autoplay() -> void:
	if not is_inside_tree():
		return
	var source: Node = get_parent()
	var effect_position: Vector2 = global_position
	var effect_direction: Vector2 = Vector2.RIGHT

	if source != null:
		if (
				not String(autoplay_parent_anchor_method).is_empty()
				and source.has_method(autoplay_parent_anchor_method)
			):
			var anchor_value: Variant = source.call(autoplay_parent_anchor_method)
			if anchor_value is Vector2:
				effect_position = anchor_value

		if not String(autoplay_direction_node_path).is_empty():
			var direction_node: Node2D = source.get_node_or_null(
				autoplay_direction_node_path
			) as Node2D
			if direction_node != null:
				effect_direction = Vector2.RIGHT.rotated(direction_node.rotation)

	top_level = true
	global_position = effect_position
	global_rotation = 0.0
	play_profile(autoplay_profile_id, effect_direction)


func _normalize_profile_id(profile_id: StringName) -> StringName:
	match profile_id:
		PROFILE_SUPER_CONCH, PROFILE_TEREBRIDAE, PROFILE_CONUS_TEXTILE:
			return profile_id
		_:
			return PROFILE_NORMAL_CONCH


func _duplicate_particle_materials() -> void:
	var primary_source: ParticleProcessMaterial = (
		_primary_sparks.process_material as ParticleProcessMaterial
	)
	if primary_source != null:
		_primary_process_material = primary_source.duplicate(true) as ParticleProcessMaterial
		_primary_sparks.process_material = _primary_process_material

	var accent_source: ParticleProcessMaterial = (
		_accent_sparks.process_material as ParticleProcessMaterial
	)
	if accent_source != null:
		_accent_process_material = accent_source.duplicate(true) as ParticleProcessMaterial
		_accent_sparks.process_material = _accent_process_material


func _configure_particle_material(
		material: ParticleProcessMaterial,
		direction: Vector2,
		spread_degrees: float,
		velocity_min: float,
		velocity_max: float,
		scale_minimum: float,
		scale_maximum: float,
		angular_velocity: float,
	) -> void:
	if material == null:
		return
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = spread_degrees
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.scale_min = scale_minimum
	material.scale_max = scale_maximum
	material.angular_velocity_min = -absf(angular_velocity)
	material.angular_velocity_max = absf(angular_velocity)


func _start_particle_burst(particles: GPUParticles2D) -> void:
	particles.process_mode = Node.PROCESS_MODE_INHERIT
	particles.emitting = true
	particles.restart()


func _stop_particles(particles: GPUParticles2D) -> void:
	particles.emitting = false
	particles.process_mode = Node.PROCESS_MODE_DISABLED


func _start_visual_tween(
		glow_scale: float,
		core_scale: float,
		play_duration: float,
	) -> void:
	_effect_tween = create_tween()
	_effect_tween.set_parallel(true)
	_effect_tween.tween_property(
		_radial_glow,
		^"scale",
		Vector2.ONE * glow_scale,
		play_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_property(
		_radial_glow,
		^"modulate:a",
		0.0,
		play_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_effect_tween.tween_property(
		_additive_core,
		^"scale",
		Vector2.ONE * core_scale,
		play_duration * 0.72,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_property(
		_additive_core,
		^"modulate:a",
		0.0,
		play_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
