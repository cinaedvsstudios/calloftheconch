extends "res://rebuild_v3/features/effects/conch_pulse_screen_range.gd"

## Adds one-shot colour and shape profiles without changing the normal conch
## trigger route. A profile remains active for the complete pulse sequence and
## the next ordinary trigger automatically restores the authored defaults.

var _default_arc_degrees: float
var _default_close_arc_degrees: float
var _default_sonar_brightness: float
var _default_pulse_duration: float
var _default_echo_alpha_decay: float
var _default_pulse_tint: Color = Color.WHITE
var _default_flash_modulate: Color = Color.WHITE
var _active_pulse_tint: Color = Color.WHITE
var _active_flash_tint: Color = Color.WHITE
var _profile_trigger_pending: bool = false


func _ready() -> void:
	_default_arc_degrees = arc_degrees
	_default_close_arc_degrees = close_range_arc_degrees
	_default_sonar_brightness = sonar_brightness
	_default_pulse_duration = pulse_duration
	_default_echo_alpha_decay = echo_alpha_decay
	_default_pulse_tint = _sonar_arc_template.modulate
	_default_flash_modulate = _origin_flash.self_modulate
	_active_pulse_tint = _default_pulse_tint
	_active_flash_tint = _default_flash_modulate
	super._ready()


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


func _apply_profile(profile: Dictionary) -> void:
	arc_degrees = float(profile.get("arc_degrees", _default_arc_degrees))
	close_range_arc_degrees = float(
		profile.get("close_range_arc_degrees", _default_close_arc_degrees)
	)
	sonar_brightness = float(profile.get("brightness", _default_sonar_brightness))
	pulse_duration = float(profile.get("duration", _default_pulse_duration))
	echo_alpha_decay = float(profile.get("echo_alpha_decay", _default_echo_alpha_decay))
	_active_pulse_tint = profile.get("tint", _default_pulse_tint) as Color
	_active_flash_tint = profile.get("flash_tint", _default_flash_modulate) as Color
	if _pulse_material != null:
		_pulse_material.set_shader_parameter(&"arc_degrees", arc_degrees)
		_pulse_material.set_shader_parameter(&"brightness", sonar_brightness)


func _reset_pulse_state() -> void:
	super._reset_pulse_state()
	for pulse_sprite: Sprite2D in _pulse_sprites:
		pulse_sprite.modulate = Color(
			_active_pulse_tint.r,
			_active_pulse_tint.g,
			_active_pulse_tint.b,
			0.0,
		)


func _play_origin_flash() -> void:
	_origin_flash.self_modulate = Color(
		_active_flash_tint.r,
		_active_flash_tint.g,
		_active_flash_tint.b,
		_default_flash_modulate.a,
	)
	super._play_origin_flash()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("profile_arc_degrees=%.1f" % arc_degrees)
	lines.append("profile_brightness=%.2f" % sonar_brightness)
	lines.append("profile_tint=%s" % str(_active_pulse_tint))
	return lines
