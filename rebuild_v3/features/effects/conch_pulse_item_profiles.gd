extends "res://rebuild_v3/features/effects/conch_pulse_screen_range.gd"

const EMISSION_PROFILE_NORMAL: StringName = &"normal_conch"
const EMISSION_PROFILE_SUPER: StringName = &"super_conch"
const EMISSION_PROFILE_TEREBRIDAE: StringName = &"terebridae"

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


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
	if not _profile_trigger_pending:
		_apply_profile({})
	super.trigger_from_player(origin, direction, player_origin)
	_profile_trigger_pending = false


func trigger_profile_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2, profile: Dictionary) -> void:
	_profile_trigger_pending = true
	_apply_profile(profile)
	trigger_from_player(origin, direction, player_origin)
	_hold_terebridae_pose_for_stream()


func stop() -> void:
	_weapon_emission.stop_effect()
	super.stop()


func _apply_profile(profile: Dictionary) -> void:
	arc_degrees = float(profile.get("arc_degrees", _default_arc_degrees))
	close_range_arc_degrees = float(profile.get("close_range_arc_degrees", _default_close_arc_degrees))
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
	_active_flash_tint = flash_tint_value if flash_tint_value is Color else _default_flash_modulate
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
	for pulse_sprite: Sprite2D in _pulse_sprites:
		pulse_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _play_origin_flash() -> void:
	_origin_flash.self_modulate = Color(_active_flash_tint.r, _active_flash_tint.g, _active_flash_tint.b, _default_flash_modulate.a)
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


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("profile_arc_degrees=%.1f" % arc_degrees)
	lines.append("profile_brightness=%.2f" % sonar_brightness)
	lines.append("profile_tint=%s" % str(_active_pulse_tint))
	lines.append("profile_flash_scale=%.2f" % _active_flash_scale_multiplier)
	lines.append("profile_stream_duration=%.2f" % continuous_emission_duration)
	lines.append("weapon_emission_active=%s" % str(_weapon_emission.is_active()))
	lines.append("weapon_emission_profile=%s" % String(_active_emission_profile_id))
	return lines
