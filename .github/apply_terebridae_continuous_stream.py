from pathlib import Path

CONTROLLER = Path("rebuild_v3/app/contexts/gameplay/item_effect_controller.gd")
PROFILES = Path("rebuild_v3/features/effects/conch_pulse_item_profiles.gd")
SCREEN_RANGE = Path("rebuild_v3/features/effects/conch_pulse_screen_range.gd")

controller_text = CONTROLLER.read_text()
old_duration = '\t\t\t"duration": 5.0,\n'
new_duration = '\t\t\t"stream_duration": 5.0,\n'
if new_duration not in controller_text:
    if controller_text.count(old_duration) != 1:
        raise SystemExit("Expected exactly one Terebridae duration profile entry.")
    controller_text = controller_text.replace(old_duration, new_duration, 1)
    CONTROLLER.write_text(controller_text)

profiles_text = '''extends "res://rebuild_v3/features/effects/conch_pulse_screen_range.gd"

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
var _profile_trigger_pending: bool = false


func _ready() -> void:
\t_default_arc_degrees = arc_degrees
\t_default_close_arc_degrees = close_range_arc_degrees
\t_default_sonar_brightness = sonar_brightness
\t_default_pulse_duration = pulse_duration
\t_default_echo_alpha_decay = echo_alpha_decay
\t_default_pulse_interval = pulse_interval
\t_default_continuous_emission_duration = continuous_emission_duration
\t_default_pulse_tint = _sonar_arc_template.modulate
\t_default_flash_modulate = _origin_flash.self_modulate
\t_default_flash_scale = _origin_flash.scale
\t_active_pulse_tint = _default_pulse_tint
\t_active_flash_tint = _default_flash_modulate
\tsuper._ready()


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
\tif not _profile_trigger_pending:
\t\t_apply_profile({})
\tsuper.trigger_from_player(origin, direction, player_origin)
\t_profile_trigger_pending = false


func trigger_profile_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2, profile: Dictionary) -> void:
\t_profile_trigger_pending = true
\t_apply_profile(profile)
\ttrigger_from_player(origin, direction, player_origin)


func _apply_profile(profile: Dictionary) -> void:
\tarc_degrees = float(profile.get("arc_degrees", _default_arc_degrees))
\tclose_range_arc_degrees = float(profile.get("close_range_arc_degrees", _default_close_arc_degrees))
\tsonar_brightness = float(profile.get("brightness", _default_sonar_brightness))
\tpulse_duration = float(profile.get("duration", _default_pulse_duration))
\techo_alpha_decay = float(profile.get("echo_alpha_decay", _default_echo_alpha_decay))
\tpulse_interval = _default_pulse_interval * float(profile.get("pulse_interval_scale", 1.0))
\tcontinuous_emission_duration = float(
\t\tprofile.get("stream_duration", _default_continuous_emission_duration)
\t)
\tvar tint_value: Variant = profile.get("tint", _default_pulse_tint)
\t_active_pulse_tint = tint_value if tint_value is Color else _default_pulse_tint
\tvar flash_tint_value: Variant = profile.get("flash_tint", _default_flash_modulate)
\t_active_flash_tint = flash_tint_value if flash_tint_value is Color else _default_flash_modulate
\t_active_flash_scale_multiplier = float(profile.get("flash_scale_multiplier", 1.0))
\tif not profile.is_empty() and arc_degrees >= 60.0:
\t\t_active_flash_scale_multiplier = maxf(_active_flash_scale_multiplier, 1.5)
\tif _pulse_material != null:
\t\t_pulse_material.set_shader_parameter(&"tint_color", _active_pulse_tint)
\t\t_pulse_material.set_shader_parameter(&"arc_degrees", arc_degrees)
\t\t_pulse_material.set_shader_parameter(&"brightness", sonar_brightness)


func _reset_pulse_state() -> void:
\tsuper._reset_pulse_state()
\tfor pulse_sprite: Sprite2D in _pulse_sprites:
\t\tpulse_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _play_origin_flash() -> void:
\t_origin_flash.self_modulate = Color(_active_flash_tint.r, _active_flash_tint.g, _active_flash_tint.b, _default_flash_modulate.a)
\t_origin_flash.scale = _default_flash_scale * _active_flash_scale_multiplier
\tsuper._play_origin_flash()


func get_debug_lines() -> Array[String]:
\tvar lines: Array[String] = super.get_debug_lines()
\tlines.append("profile_arc_degrees=%.1f" % arc_degrees)
\tlines.append("profile_brightness=%.2f" % sonar_brightness)
\tlines.append("profile_tint=%s" % str(_active_pulse_tint))
\tlines.append("profile_flash_scale=%.2f" % _active_flash_scale_multiplier)
\tlines.append("profile_stream_duration=%.2f" % continuous_emission_duration)
\treturn lines
'''
PROFILES.write_text(profiles_text)

screen_range_text = '''extends "res://rebuild_v3/features/effects/conch_pulse.gd"

@export_category("Screen Range")
@export_range(0.0, 200.0, 1.0) var screen_edge_padding: float = 36.0

@export_category("Visual Lifetime")
@export_range(0.05, 0.95, 0.01) var visual_fade_start_fraction: float = 0.34
@export_range(0.05, 1.0, 0.01) var visual_fade_end_fraction: float = 0.50
@export_range(0.5, 1.0, 0.01) var visual_end_scale: float = 0.92

@export_category("Continuous Stream")
@export_range(0.0, 10.0, 0.05) var continuous_emission_duration: float = 0.0

var _minimum_pulse_diameter: float = 700.0
var _continuous_next_emit_time: float = 0.0
var _continuous_pulse_started_at: Array[float] = []


func _ready() -> void:
\t_minimum_pulse_diameter = pulse_range
\tsuper._ready()


func _process(delta: float) -> void:
\tif not _sequence_active:
\t\treturn

\t_update_player_tracking()
\tpulse_range = _calculate_screen_edge_diameter(global_position, _pulse_direction)
\t_sequence_elapsed += delta
\t_update_pulse_stream()

\tif continuous_emission_duration > 0.0:
\t\tif (
\t\t\t\t_continuous_next_emit_time > continuous_emission_duration
\t\t\t\tand not _has_active_continuous_pulses()
\t\t\t):
\t\t\t_sequence_active = false
\t\t\tset_process(false)
\t\t\t_hide_when_finished()
\t\treturn

\tvar final_pulse_delay: float = float(maxi(0, _pulse_sprites.size() - 1)) * pulse_interval
\tif _sequence_elapsed >= final_pulse_delay + pulse_duration:
\t\t_sequence_active = false
\t\tset_process(false)
\t\t_hide_when_finished()


func trigger(origin: Vector2, direction: Vector2) -> void:
\ttrigger_from_player(origin, direction, origin)


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
\tvar pulse_direction: Vector2 = direction
\tif pulse_direction.length_squared() <= 0.0001:
\t\tpulse_direction = Vector2.RIGHT
\telse:
\t\tpulse_direction = pulse_direction.normalized()

\tvar resolved_origin: Vector2 = origin
\tvar source: Node2D = _find_player_source(player_origin)
\tif is_instance_valid(source):
\t\tresolved_origin = _get_source_pulse_origin(source, origin)
\tpulse_range = _calculate_screen_edge_diameter(resolved_origin, pulse_direction)
\tsuper.trigger_from_player(origin, pulse_direction, player_origin)


func _reset_pulse_state() -> void:
\tsuper._reset_pulse_state()
\t_continuous_next_emit_time = 0.0
\t_continuous_pulse_started_at.resize(_pulse_sprites.size())
\tfor pulse_index: int in range(_continuous_pulse_started_at.size()):
\t\t_continuous_pulse_started_at[pulse_index] = -1.0


func _update_pulse_stream() -> void:
\tvar fade_start_fraction: float = clampf(visual_fade_start_fraction, 0.05, 0.95)
\tvar fade_end_fraction: float = clampf(
\t\tmaxf(visual_fade_end_fraction, fade_start_fraction + 0.01),
\t\t0.06,
\t\t1.0,
\t)
\tvar reach_edge_time: float = maxf(0.01, pulse_duration * fade_start_fraction)
\tvar fade_end_time: float = maxf(reach_edge_time + 0.01, pulse_duration * fade_end_fraction)
\tvar continuous_stream_active: bool = continuous_emission_duration > 0.0

\tif continuous_stream_active:
\t\t_emit_continuous_pulses()

\tfor pulse_index: int in range(_pulse_sprites.size()):
\t\tif continuous_stream_active:
\t\t\tif _continuous_pulse_started_at[pulse_index] < 0.0:
\t\t\t\tcontinue
\t\telse:
\t\t\tif _pulse_finished[pulse_index]:
\t\t\t\tcontinue

\t\tvar local_elapsed: float = (
\t\t\t_sequence_elapsed - _continuous_pulse_started_at[pulse_index]
\t\t\tif continuous_stream_active
\t\t\telse _sequence_elapsed - float(pulse_index) * pulse_interval
\t\t)
\t\tif local_elapsed < 0.0:
\t\t\tcontinue

\t\tvar pulse_sprite: Sprite2D = _pulse_sprites[pulse_index]
\t\tif not _pulse_started[pulse_index]:
\t\t\t_pulse_started[pulse_index] = true
\t\t\tpulse_sprite.show()
\t\t\tpulse_wave_started.emit(pulse_index)

\t\tvar travel_progress: float = clampf(local_elapsed / reach_edge_time, 0.0, 1.0)
\t\tvar eased_travel: float = smoothstep(0.0, 1.0, travel_progress)
\t\tvar hit_diameter: float = lerpf(start_diameter, pulse_range, eased_travel)
\t\tvar visual_diameter: float = hit_diameter
\t\tvar visual_alpha: float = 1.0

\t\tif local_elapsed > reach_edge_time:
\t\t\tvar fade_progress: float = clampf(
\t\t\t\tinverse_lerp(reach_edge_time, fade_end_time, local_elapsed),
\t\t\t\t0.0,
\t\t\t\t1.0,
\t\t\t)
\t\t\tvar eased_fade: float = smoothstep(0.0, 1.0, fade_progress)
\t\t\tvisual_alpha = 1.0 - eased_fade
\t\t\tvisual_diameter = pulse_range * lerpf(1.0, visual_end_scale, eased_fade)

\t\t_apply_diameter(pulse_sprite, visual_diameter)
\t\tvar echo_strength: float = (
\t\t\t1.0
\t\t\tif continuous_stream_active
\t\t\telse maxf(0.25, 1.0 - float(pulse_index) * echo_alpha_decay)
\t\t)
\t\tpulse_sprite.modulate.a = visual_alpha * echo_strength

\t\tvar current_radius: float = hit_diameter * 0.5
\t\tvar previous_radius: float = _pulse_previous_radius[pulse_index]
\t\tif current_radius >= previous_radius:
\t\t\t_track_pulse_targets(pulse_index, previous_radius, current_radius)
\t\t\t_pulse_previous_radius[pulse_index] = current_radius

\t\tif local_elapsed >= fade_end_time:
\t\t\t_pulse_finished[pulse_index] = true
\t\t\tpulse_sprite.modulate.a = 0.0
\t\t\tpulse_sprite.hide()
\t\t\tpulse_wave_finished.emit(pulse_index)
\t\t\tif continuous_stream_active:
\t\t\t\t_continuous_pulse_started_at[pulse_index] = -1.0

\tif _flash_active and _sequence_elapsed >= fade_end_time:
\t\t_flash_active = false
\t\t_origin_flash.stop()
\t\t_origin_flash.hide()


func _emit_continuous_pulses() -> void:
\tvar emission_interval: float = maxf(0.01, pulse_interval)
\tvar emission_limit: float = minf(_sequence_elapsed, continuous_emission_duration)
\twhile _continuous_next_emit_time <= emission_limit + 0.0001:
\t\tvar pulse_index: int = _find_available_continuous_pulse()
\t\tif pulse_index < 0:
\t\t\treturn
\t\t_continuous_pulse_started_at[pulse_index] = _continuous_next_emit_time
\t\t_pulse_started[pulse_index] = false
\t\t_pulse_finished[pulse_index] = false
\t\t_pulse_previous_radius[pulse_index] = 0.0
\t\t_pulse_hit_targets[pulse_index] = {}
\t\tvar pulse_sprite: Sprite2D = _pulse_sprites[pulse_index]
\t\tpulse_sprite.modulate.a = 0.0
\t\tpulse_sprite.hide()
\t\t_continuous_next_emit_time += emission_interval


func _find_available_continuous_pulse() -> int:
\tfor pulse_index: int in range(_continuous_pulse_started_at.size()):
\t\tif _continuous_pulse_started_at[pulse_index] < 0.0:
\t\t\treturn pulse_index
\treturn -1


func _has_active_continuous_pulses() -> bool:
\tfor started_at: float in _continuous_pulse_started_at:
\t\tif started_at >= 0.0:
\t\t\treturn true
\treturn false


func _calculate_screen_edge_diameter(origin: Vector2, direction: Vector2) -> float:
\tvar viewport_size: Vector2 = get_viewport_rect().size
\tif viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
\t\treturn _minimum_pulse_diameter

\tvar canvas_transform: Transform2D = get_viewport().get_canvas_transform()
\tvar screen_origin: Vector2 = canvas_transform * origin
\tvar screen_step: Vector2 = (canvas_transform * (origin + direction)) - screen_origin
\tvar screen_units_per_world_unit: float = screen_step.length()
\tif screen_units_per_world_unit <= 0.0001:
\t\treturn _minimum_pulse_diameter

\tvar world_distance: float = INF
\tif screen_step.x > 0.0001:
\t\tvar right_distance: float = (viewport_size.x - screen_origin.x) / screen_step.x
\t\tif right_distance > 0.0:
\t\t\tworld_distance = minf(world_distance, right_distance)
\telif screen_step.x < -0.0001:
\t\tvar left_distance: float = (0.0 - screen_origin.x) / screen_step.x
\t\tif left_distance > 0.0:
\t\t\tworld_distance = minf(world_distance, left_distance)

\tif screen_step.y > 0.0001:
\t\tvar bottom_distance: float = (viewport_size.y - screen_origin.y) / screen_step.y
\t\tif bottom_distance > 0.0:
\t\t\tworld_distance = minf(world_distance, bottom_distance)
\telif screen_step.y < -0.0001:
\t\tvar top_distance: float = (0.0 - screen_origin.y) / screen_step.y
\t\tif top_distance > 0.0:
\t\t\tworld_distance = minf(world_distance, top_distance)

\tif world_distance == INF or world_distance <= 0.0:
\t\treturn _minimum_pulse_diameter

\tvar padding_world_units: float = screen_edge_padding / screen_units_per_world_unit
\treturn maxf(
\t\t_minimum_pulse_diameter,
\t\t(world_distance + padding_world_units) * 2.0,
\t)
'''
SCREEN_RANGE.write_text(screen_range_text)
