class_name CotcJellyfishEnemy
extends Area2D

signal damage_requested(hylas: Node, amount: int)
signal frozen_started()
signal frozen_finished()

@export_category("Animation")
@export_range(40.0, 900.0, 1.0) var display_height: float = 250.0

@export_category("Drift")
@export var patrol_half_extents: Vector2 = Vector2(700.0, 260.0)
@export_range(1.0, 500.0, 1.0) var minimum_drift_speed: float = 30.0
@export_range(1.0, 500.0, 1.0) var maximum_drift_speed: float = 52.0
@export_range(1.0, 1000.0, 1.0) var steering_acceleration: float = 80.0
@export_range(10.0, 300.0, 1.0) var waypoint_reached_distance: float = 60.0
@export_range(0.0, 1.0, 0.01) var vertical_wander_strength: float = 0.24
@export_range(0.01, 3.0, 0.01) var vertical_wander_frequency: float = 0.20
@export var random_seed: int = 0

@export_category("Activation")
@export_range(0.05, 1.0, 0.05) var activation_screen_fraction: float = 0.25

@export_category("Opacity")
@export_range(0.0, 1.0, 0.01) var idle_opacity_min: float = 0.10
@export_range(0.0, 1.0, 0.01) var idle_opacity_max: float = 0.40
@export_range(0.0, 1.0, 0.01) var alert_opacity_min: float = 0.40
@export_range(0.0, 1.0, 0.01) var alert_opacity_max: float = 0.80
@export_range(0.1, 5.0, 0.1) var opacity_transition_min_duration: float = 0.45
@export_range(0.1, 5.0, 0.1) var opacity_transition_max_duration: float = 1.25

@export_category("Damage")
@export_range(1, 8, 1) var damage_amount: int = 1
@export_range(0.1, 10.0, 0.1) var damage_cooldown: float = 4.0

@export_category("Conch Stun")
@export_range(0.1, 20.0, 0.1) var freeze_duration: float = 10.0
@export_range(1.0, 500.0, 1.0) var stunned_sink_speed: float = 105.0
@export_range(1.0, 100.0, 1.0) var floor_probe_extra_distance: float = 18.0

@export_category("Stun Glow")
@export var stun_glow_color: Color = Color(0.0, 0.82, 1.0, 1.0)
@export_range(0.1, 12.0, 0.1) var stun_glow_pulse_speed: float = 4.5
@export_range(0.0, 3.0, 0.05) var stun_glow_strength: float = 1.25
@export_range(0.0, 12.0, 0.5) var stun_glow_radius: float = 5.0

@export_category("Water Forces")
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.32

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _hurt_area: Area2D = %HurtArea
@onready var _floor_probe: RayCast2D = %FloorProbe
@onready var _stun_audio: AudioStreamPlayer2D = %StunAudio
@onready var _stun_material: ShaderMaterial = %AnimatedSprite.material as ShaderMaterial

var _home_position: Vector2
var _patrol_target: Vector2
var _travel_sign: float = 1.0
var _cruise_speed: float = 40.0
var _movement_velocity: Vector2 = Vector2.ZERO
var _external_currents: Dictionary = {}
var _hylas: Node2D
var _alerted: bool = false
var _elapsed: float = 0.0
var _wander_phase: float = 0.0
var _distance_active: bool = true
var _last_damage_time: float = -999.0
var _freeze_ends_at_msec: int = 0
var _frozen_visual_active: bool = false
var _resting_on_floor: bool = false
var _current_opacity: float = 0.25
var _opacity_target: float = 0.25
var _opacity_speed: float = 0.0
var _opacity_remaining: float = 0.0
var _opacity_rising: bool = true
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home_position = global_position
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_travel_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_wander_phase = _rng.randf_range(0.0, TAU)
	_choose_next_patrol_target(true)
	_apply_display_scale()
	_configure_stun_material()
	_resolve_hylas()
	_set_alerted(false, true)
	_hurt_area.monitoring = true
	_hurt_area.monitorable = false
	_floor_probe.enabled = false
	monitoring = false
	monitorable = true
	set_physics_process(true)
	_connect_to_level_conch_signal()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitorable = _distance_active
	_hurt_area.monitoring = _distance_active and not is_frozen()
	if _distance_active:
		_refresh_frozen_state_after_wake()
		return
	_sprite.pause()
	_floor_probe.enabled = false
	_external_currents.clear()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_resolve_hylas()

	if is_frozen():
		if not _frozen_visual_active:
			_begin_frozen_state(false)
		_update_frozen(delta)
		return
	if _frozen_visual_active:
		_finish_frozen_state()

	_set_alerted(_is_hylas_in_activation_range())
	_update_opacity(delta)
	_update_drift(delta)
	_damage_touching_hylas_if_needed()


func set_external_current(source: Node, current_velocity: Vector2) -> void:
	if not is_instance_valid(source):
		return
	_external_currents[source] = current_velocity


func remove_external_current(source: Node) -> void:
	_external_currents.erase(source)


func receive_conch_hit(
		_origin: Vector2,
		_pulse_direction: Vector2,
		_distance: float,
		_strength: float,
	) -> void:
	var was_already_frozen: bool = is_frozen()
	_freeze_ends_at_msec = Time.get_ticks_msec() + int(round(freeze_duration * 1000.0))
	if not was_already_frozen:
		_begin_frozen_state(true)
	elif not _frozen_visual_active:
		_begin_frozen_state(false)
	else:
		_set_stun_glow_enabled(true)
		_set_opacity(alert_opacity_max)


func is_frozen() -> bool:
	return Time.get_ticks_msec() < _freeze_ends_at_msec


func get_frozen_time_remaining() -> float:
	return maxf(
		0.0,
		float(_freeze_ends_at_msec - Time.get_ticks_msec()) / 1000.0,
	)


func _begin_frozen_state(play_audio: bool) -> void:
	_frozen_visual_active = true
	_resting_on_floor = false
	_movement_velocity = Vector2.ZERO
	_sprite.pause()
	_hurt_area.monitoring = false
	_floor_probe.enabled = _distance_active
	_set_stun_glow_enabled(true)
	_set_opacity(alert_opacity_max)
	if play_audio and _stun_audio.stream != null:
		_stun_audio.stop()
		_stun_audio.play()
		frozen_started.emit()


func _update_frozen(delta: float) -> void:
	_set_opacity(alert_opacity_max)
	if _resting_on_floor:
		return

	var sink_step: float = stunned_sink_speed * delta
	_floor_probe.target_position = Vector2(0.0, sink_step + floor_probe_extra_distance)
	_floor_probe.force_raycast_update()
	if _floor_probe.is_colliding():
		var collision_point: Vector2 = _floor_probe.get_collision_point()
		global_position.y = collision_point.y - _floor_probe.position.y
		_resting_on_floor = true
		return
	global_position.y += sink_step


func _finish_frozen_state() -> void:
	if not _frozen_visual_active:
		return
	_freeze_ends_at_msec = 0
	_frozen_visual_active = false
	_resting_on_floor = false
	_floor_probe.enabled = false
	_set_stun_glow_enabled(false)
	_hurt_area.monitoring = _distance_active
	_choose_next_patrol_target(true)
	_set_alerted(_is_hylas_in_activation_range(), true)
	frozen_finished.emit()


func _refresh_frozen_state_after_wake() -> void:
	if is_frozen():
		_frozen_visual_active = true
		_sprite.pause()
		_hurt_area.monitoring = false
		_floor_probe.enabled = true
		_set_stun_glow_enabled(true)
		_set_opacity(alert_opacity_max)
		return
	if _frozen_visual_active:
		_finish_frozen_state()
		return
	_floor_probe.enabled = false
	_hurt_area.monitoring = true
	_set_stun_glow_enabled(false)
	_set_alerted(_is_hylas_in_activation_range(), true)


func _update_drift(delta: float) -> void:
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= waypoint_reached_distance or _has_passed_patrol_target():
		_choose_next_patrol_target(false)
		to_target = _patrol_target - global_position

	if to_target.length_squared() > 0.001:
		var desired_direction: Vector2 = to_target.normalized()
		desired_direction.y += sin(
			_elapsed * TAU * vertical_wander_frequency + _wander_phase
		) * vertical_wander_strength
		desired_direction = desired_direction.normalized()
		_movement_velocity = _movement_velocity.move_toward(
			desired_direction * _cruise_speed,
			steering_acceleration * delta,
		)

	var total_velocity: Vector2 = (
		_movement_velocity
		+ _get_external_current_velocity() * current_influence
	)
	global_position += total_velocity * delta


func _set_alerted(is_alerted: bool, force: bool = false) -> void:
	if not force and _alerted == is_alerted:
		return
	_alerted = is_alerted
	_sprite.play(&"alert" if _alerted else &"idle")
	_reset_opacity_cycle()


func _is_hylas_in_activation_range() -> bool:
	if not is_instance_valid(_hylas):
		return false
	return global_position.distance_to(_hylas.global_position) <= _get_activation_distance()


func _get_activation_distance() -> float:
	var visible_width: float = get_viewport_rect().size.x
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		visible_width /= maxf(0.01, absf(camera.zoom.x))
	return visible_width * activation_screen_fraction


func _reset_opacity_cycle() -> void:
	var limits: Vector2 = _get_opacity_limits()
	_current_opacity = clampf(_current_opacity, limits.x, limits.y)
	_opacity_rising = _current_opacity <= (limits.x + limits.y) * 0.5
	_choose_next_opacity_target()
	_set_opacity(_current_opacity)


func _update_opacity(delta: float) -> void:
	_opacity_remaining = maxf(0.0, _opacity_remaining - delta)
	_current_opacity = move_toward(
		_current_opacity,
		_opacity_target,
		_opacity_speed * delta,
	)
	_set_opacity(_current_opacity)
	if _opacity_remaining <= 0.0 or is_equal_approx(_current_opacity, _opacity_target):
		_choose_next_opacity_target()


func _choose_next_opacity_target() -> void:
	var limits: Vector2 = _get_opacity_limits()
	var midpoint: float = (limits.x + limits.y) * 0.5
	if _opacity_rising:
		_opacity_target = _rng.randf_range(midpoint, limits.y)
	else:
		_opacity_target = _rng.randf_range(limits.x, midpoint)
	_opacity_rising = not _opacity_rising
	var duration: float = _rng.randf_range(
		minf(opacity_transition_min_duration, opacity_transition_max_duration),
		maxf(opacity_transition_min_duration, opacity_transition_max_duration),
	)
	_opacity_remaining = duration
	_opacity_speed = absf(_opacity_target - _current_opacity) / maxf(0.01, duration)


func _get_opacity_limits() -> Vector2:
	if _alerted:
		return Vector2(
			minf(alert_opacity_min, alert_opacity_max),
			maxf(alert_opacity_min, alert_opacity_max),
		)
	return Vector2(
		minf(idle_opacity_min, idle_opacity_max),
		maxf(idle_opacity_min, idle_opacity_max),
	)


func _set_opacity(value: float) -> void:
	_current_opacity = clampf(value, 0.0, 1.0)
	if _stun_material != null:
		_stun_material.set_shader_parameter(&"opacity", _current_opacity)


func _damage_touching_hylas_if_needed() -> void:
	if _frozen_visual_active or not _hurt_area.monitoring:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	for body: Node2D in _hurt_area.get_overlapping_bodies():
		if body.is_in_group(&"hylas"):
			_last_damage_time = now
			damage_requested.emit(body, damage_amount)
			if body.has_method(&"play_fin_loss_sound"):
				body.call(&"play_fin_loss_sound")
			return


func _resolve_hylas() -> void:
	if is_instance_valid(_hylas):
		return
	_hylas = get_tree().get_first_node_in_group(&"hylas") as Node2D
	var hylas_collision: CollisionObject2D = _hylas as CollisionObject2D
	if hylas_collision != null:
		_floor_probe.add_exception(hylas_collision)


func _connect_to_level_conch_signal() -> void:
	var ancestor: Node = get_parent()
	var callback := Callable(self, "_on_level_conch_target_hit")
	while ancestor != null:
		if ancestor.has_signal(&"conch_target_hit"):
			if not ancestor.is_connected(&"conch_target_hit", callback):
				ancestor.connect(&"conch_target_hit", callback)
			return
		ancestor = ancestor.get_parent()


func _on_level_conch_target_hit(
		target: Node2D,
		hit_position: Vector2,
		_pulse_index: int,
	) -> void:
	if target != self:
		return
	var origin: Vector2 = hit_position
	var pulse_direction: Vector2 = Vector2.RIGHT
	var hit_distance: float = 0.0
	if is_instance_valid(_hylas):
		origin = _hylas.global_position
		var target_offset: Vector2 = hit_position - origin
		hit_distance = target_offset.length()
		if target_offset.length_squared() > 0.001:
			pulse_direction = target_offset.normalized()
	receive_conch_hit(origin, pulse_direction, hit_distance, 1.0)


func _choose_next_patrol_target(initial_target: bool) -> void:
	if not initial_target:
		_travel_sign *= -1.0
	var horizontal_distance: float = patrol_half_extents.x * _rng.randf_range(0.68, 1.0)
	_patrol_target = _home_position + Vector2(
		_travel_sign * horizontal_distance,
		_rng.randf_range(-patrol_half_extents.y, patrol_half_extents.y),
	)
	_cruise_speed = _rng.randf_range(
		minf(minimum_drift_speed, maximum_drift_speed),
		maxf(minimum_drift_speed, maximum_drift_speed),
	)
	_wander_phase = _rng.randf_range(0.0, TAU)


func _has_passed_patrol_target() -> bool:
	if _travel_sign > 0.0:
		return global_position.x >= _patrol_target.x
	return global_position.x <= _patrol_target.x


func _get_external_current_velocity() -> Vector2:
	var total_velocity: Vector2 = Vector2.ZERO
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			_external_currents.erase(source)
			continue
		var source_velocity: Vector2 = _external_currents[source]
		total_velocity += source_velocity
	return total_velocity


func _configure_stun_material() -> void:
	if _stun_material == null:
		return
	_stun_material.set_shader_parameter(&"glow_color", stun_glow_color)
	_stun_material.set_shader_parameter(&"pulse_speed", stun_glow_pulse_speed)
	_stun_material.set_shader_parameter(&"glow_strength", stun_glow_strength)
	_stun_material.set_shader_parameter(&"glow_radius", stun_glow_radius)
	_stun_material.set_shader_parameter(&"stunned_amount", 0.0)
	_stun_material.set_shader_parameter(&"opacity", _current_opacity)


func _set_stun_glow_enabled(enabled: bool) -> void:
	if _stun_material == null:
		return
	_stun_material.set_shader_parameter(&"stunned_amount", 1.0 if enabled else 0.0)


func _apply_display_scale() -> void:
	var first_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if first_texture != null:
		var scale_factor: float = display_height / maxf(1.0, float(first_texture.get_height()))
		_sprite.scale = Vector2.ONE * scale_factor
	_floor_probe.position.y = display_height * 0.34
