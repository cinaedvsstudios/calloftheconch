extends "res://rebuild_v3/features/effects/conch_pulse_screen_range.gd"

const EMISSION_PROFILE_NORMAL: StringName = &"normal_conch"
const EMISSION_PROFILE_SUPER: StringName = &"super_conch"
const EMISSION_PROFILE_TEREBRIDAE: StringName = &"terebridae"
const DRILL_TARGET_GROUP: StringName = &"drill_target"
const TEREBRIDAE_REPEAT_INTERVAL: float = 0.75
const WEAPON_EMISSION_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/weapon_emission_fx_2d/weapon_emission_fx_2d.tscn"
)
const ENEMY_STUN_VISUAL_CONTROLLER = preload(
	"res://rebuild_v3/shared/enemy_stun_visual_controller.gd"
)

@onready var _weapon_emission: CotcWeaponEmissionFX2D = %WeaponEmissionFX

var _default_arc_degrees: float
var _default_close_arc_degrees: float
var _default_sonar_brightness: float
var _default_pulse_duration: float
var _default_echo_alpha_decay: float
var _default_pulse_interval: float
var _default_continuous_emission_duration: float
var _default_pulse_tint: Color = Color.WHITE
var _default_flash_modulate: Color = Color.WHITE
var _default_flash_scale: Vector2 = Vector2.ONE
var _active_pulse_tint: Color = Color.WHITE
var _active_flash_tint: Color = Color.WHITE
var _active_flash_scale_multiplier: float = 1.0
var _active_emission_profile_id: StringName = EMISSION_PROFILE_NORMAL
var _profile_trigger_pending: bool = false
var _terebridae_next_flash_time: float = TEREBRIDAE_REPEAT_INTERVAL
var _terebridae_impact_emission: CotcWeaponEmissionFX2D
var _drill_response_delivered_count: int = 0
var _last_drill_response_target: NodePath = NodePath("")


func _ready() -> void:
	_default_arc_degrees = arc_degrees
	_default_close_arc_degrees = close_range_arc_degrees
	_default_sonar_brightness = sonar_brightness
	_default_pulse_duration = pulse_duration
	_default_echo_alpha_decay = echo_alpha_decay
	_default_pulse_interval = pulse_interval
	_default_continuous_emission_duration = continuous_emission_duration
	_default_pulse_tint = _sonar_arc_template.modulate
	_default_flash_modulate = _origin_flash.self_modulate
	_default_flash_scale = _origin_flash.scale
	_active_pulse_tint = _default_pulse_tint
	_active_flash_tint = _default_flash_modulate
	super._ready()
	_weapon_emission.stop_effect()
	_create_terebridae_impact_emission()
	if not target_hit.is_connected(_on_target_hit):
		target_hit.connect(_on_target_hit)


func _process(delta: float) -> void:
	super._process(delta)
	if (
			not _sequence_active
			or _active_emission_profile_id != EMISSION_PROFILE_TEREBRIDAE
			or continuous_emission_duration <= 0.0
		):
		return

	var emission_limit: float = minf(_sequence_elapsed, continuous_emission_duration)
	while _terebridae_next_flash_time <= emission_limit + 0.0001:
		_play_terebridae_repeat_flash()
		_terebridae_next_flash_time += TEREBRIDAE_REPEAT_INTERVAL


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
	if not _profile_trigger_pending:
		_apply_profile({})
	super.trigger_from_player(origin, direction, player_origin)
	_profile_trigger_pending = false


func trigger_profile_from_player(
		origin: Vector2,
		direction: Vector2,
		player_origin: Vector2,
		profile: Dictionary,
	) -> void:
	_profile_trigger_pending = true
	_apply_profile(profile)
	trigger_from_player(origin, direction, player_origin)
	_hold_terebridae_pose_for_stream()


func stop() -> void:
	_weapon_emission.stop_effect()
	if is_instance_valid(_terebridae_impact_emission):
		_terebridae_impact_emission.stop_effect()
	super.stop()


func _apply_profile(profile: Dictionary) -> void:
	arc_degrees = float(profile.get("arc_degrees", _default_arc_degrees))
	close_range_arc_degrees = float(
		profile.get("close_range_arc_degrees", _default_close_arc_degrees)
	)
	sonar_brightness = float(profile.get("brightness", _default_sonar_brightness))
	pulse_duration = float(profile.get("duration", _default_pulse_duration))
	echo_alpha_decay = float(profile.get("echo_alpha_decay", _default_echo_alpha_decay))
	pulse_interval = _default_pulse_interval * float(profile.get("pulse_interval_scale", 1.0))
	continuous_emission_duration = float(
		profile.get("stream_duration", _default_continuous_emission_duration)
	)
	var tint_value: Variant = profile.get("tint", _default_pulse_tint)
	_active_pulse_tint = tint_value if tint_value is Color else _default_pulse_tint
	var flash_tint_value: Variant = profile.get("flash_tint", _default_flash_modulate)
	_active_flash_tint = (
		flash_tint_value if flash_tint_value is Color else _default_flash_modulate
	)
	_active_flash_scale_multiplier = float(profile.get("flash_scale_multiplier", 1.0))
	if not profile.is_empty() and arc_degrees >= 60.0:
		_active_flash_scale_multiplier = maxf(_active_flash_scale_multiplier, 1.5)
	_active_emission_profile_id = _resolve_emission_profile(profile)
	if _pulse_material != null:
		_pulse_material.set_shader_parameter(&"tint_color", _active_pulse_tint)
		_pulse_material.set_shader_parameter(&"arc_degrees", arc_degrees)
		_pulse_material.set_shader_parameter(&"brightness", sonar_brightness)


func _resolve_emission_profile(profile: Dictionary) -> StringName:
	var explicit_profile: StringName = StringName(str(profile.get("emission_profile_id", "")))
	if not String(explicit_profile).is_empty():
		return explicit_profile
	if continuous_emission_duration > 0.0:
		return EMISSION_PROFILE_TEREBRIDAE
	if not profile.is_empty() and arc_degrees >= 60.0:
		return EMISSION_PROFILE_SUPER
	return EMISSION_PROFILE_NORMAL


func _get_active_response_profile_id() -> StringName:
	return _active_emission_profile_id


func _get_active_response_strength_scale() -> float:
	match _active_emission_profile_id:
		EMISSION_PROFILE_SUPER:
			return 0.90
		EMISSION_PROFILE_TEREBRIDAE:
			return 1.15
		_:
			return 0.55


func _register_target_hit(target: Node2D, pulse_index: int) -> void:
	var drill_receiver: Node2D = _get_drill_response_target(target)
	var repeatable_drill_target: bool = (
		_active_emission_profile_id == EMISSION_PROFILE_TEREBRIDAE
		and drill_receiver != null
	)
	var target_id: int = target.get_instance_id()
	if (
			hit_once_per_trigger
			and not repeatable_drill_target
			and _sequence_hit_targets.has(target_id)
		):
		return
	if not repeatable_drill_target:
		_sequence_hit_targets[target_id] = true
	_last_hit_count += 1

	var hit_position: Vector2 = _get_target_hit_position(target)
	if repeatable_drill_target:
		_deliver_drill_target_response(drill_receiver, hit_position, pulse_index)
	else:
		_deliver_target_response(target, hit_position)
	_spawn_conch_impact(target, hit_position)
	target_hit.emit(target, hit_position, pulse_index)


func _get_drill_response_target(target: Node2D) -> Node2D:
	if _active_emission_profile_id != EMISSION_PROFILE_TEREBRIDAE:
		return null
	var candidate: Node = target
	var remaining_parent_checks: int = 4
	while candidate != null and remaining_parent_checks >= 0:
		if (
				candidate is Node2D
				and candidate.is_in_group(DRILL_TARGET_GROUP)
				and candidate.has_method(&"receive_drill_pulse")
			):
			return candidate as Node2D
		candidate = candidate.get_parent()
		remaining_parent_checks -= 1
	return null


func _deliver_drill_target_response(
		drill_receiver: Node2D,
		hit_position: Vector2,
		pulse_index: int,
	) -> void:
	if not is_instance_valid(drill_receiver):
		return
	var hit_distance: float = hit_position.distance_to(global_position)
	var hit_strength: float = _calculate_hit_strength(hit_distance)
	_last_response_profile_id = EMISSION_PROFILE_TEREBRIDAE
	_last_response_target_path = drill_receiver.get_path()
	_last_response_strength = hit_strength
	_response_delivered_count += 1
	_drill_response_delivered_count += 1
	_last_drill_response_target = drill_receiver.get_path()
	drill_receiver.call(
		&"receive_drill_pulse",
		hit_position,
		-_pulse_direction,
		pulse_index,
		_player_source,
	)


func _deliver_target_response(target: Node2D, hit_position: Vector2) -> void:
	_last_response_profile_id = _get_active_response_profile_id()
	var response_target: Node2D = _get_conch_response_target(target)
	if response_target == null:
		_response_rejected_count += 1
		_last_response_target_path = target.get_path()
		push_warning(
			"Conch target '%s' has no receive_conch_hit() response method." % str(target.get_path())
		)
		return
	var hit_distance: float = hit_position.distance_to(global_position)
	var hit_strength: float = _calculate_hit_strength(hit_distance)
	_last_response_target_path = response_target.get_path()
	_last_response_strength = hit_strength
	_response_delivered_count += 1
	if response_target.is_in_group(&"enemy"):
		ENEMY_STUN_VISUAL_CONTROLLER.request_conch_stun(
			response_target,
			_last_response_profile_id,
			global_position,
			_pulse_direction,
			hit_distance,
			hit_strength,
		)
		return
	response_target.call(
		&"receive_conch_hit",
		global_position,
		_pulse_direction,
		hit_distance,
		hit_strength,
	)


func _hold_terebridae_pose_for_stream() -> void:
	if _active_emission_profile_id != EMISSION_PROFILE_TEREBRIDAE:
		return
	if not is_instance_valid(_player_source):
		return
	if not _player_source.has_method(&"hold_current_item_pose_for_duration"):
		return
	_player_source.call(
		&"hold_current_item_pose_for_duration",
		continuous_emission_duration,
	)


func _reset_pulse_state() -> void:
	super._reset_pulse_state()
	_terebridae_next_flash_time = TEREBRIDAE_REPEAT_INTERVAL
	for pulse_sprite: Sprite2D in _pulse_sprites:
		pulse_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _play_origin_flash() -> void:
	_origin_flash.self_modulate = Color(
		_active_flash_tint.r,
		_active_flash_tint.g,
		_active_flash_tint.b,
		_default_flash_modulate.a,
	)
	_origin_flash.scale = _default_flash_scale * _active_flash_scale_multiplier
	var primary_override: Variant = null
	if _active_emission_profile_id != EMISSION_PROFILE_NORMAL:
		primary_override = _active_flash_tint
	_weapon_emission.play_profile(
		_active_emission_profile_id,
		Vector2.RIGHT,
		primary_override,
	)
	super._play_origin_flash()


func _play_terebridae_repeat_flash() -> void:
	_weapon_emission.play_profile(
		EMISSION_PROFILE_TEREBRIDAE,
		Vector2.RIGHT,
		_active_flash_tint,
	)


func _create_terebridae_impact_emission() -> void:
	var instance: Node = WEAPON_EMISSION_SCENE.instantiate()
	_terebridae_impact_emission = instance as CotcWeaponEmissionFX2D
	if _terebridae_impact_emission == null:
		if instance != null:
			instance.queue_free()
		return
	_terebridae_impact_emission.name = "TerebridaeImpactEmission"
	_terebridae_impact_emission.top_level = true
	_terebridae_impact_emission.scale = Vector2.ONE * 0.38
	add_child(_terebridae_impact_emission)
	_terebridae_impact_emission.stop_effect()


func _on_target_hit(_target: Node2D, hit_position: Vector2, _pulse_index: int) -> void:
	if _active_emission_profile_id != EMISSION_PROFILE_TEREBRIDAE:
		return
	if not is_instance_valid(_terebridae_impact_emission):
		return
	_terebridae_impact_emission.global_position = hit_position
	_terebridae_impact_emission.global_rotation = 0.0
	_terebridae_impact_emission.play_profile(
		EMISSION_PROFILE_TEREBRIDAE,
		-_pulse_direction,
		_active_flash_tint,
	)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("profile_arc_degrees=%.1f" % arc_degrees)
	lines.append("profile_brightness=%.2f" % sonar_brightness)
	lines.append("profile_tint=%s" % str(_active_pulse_tint))
	lines.append("profile_flash_scale=%.2f" % _active_flash_scale_multiplier)
	lines.append("profile_stream_duration=%.2f" % continuous_emission_duration)
	lines.append("profile_repeat_interval=%.2f" % TEREBRIDAE_REPEAT_INTERVAL)
	lines.append("weapon_emission_active=%s" % str(_weapon_emission.is_active()))
	lines.append("weapon_emission_profile=%s" % String(_active_emission_profile_id))
	lines.append("drill_response_delivered=%d" % _drill_response_delivered_count)
	lines.append("last_drill_response_target=%s" % str(_last_drill_response_target))
	return lines
