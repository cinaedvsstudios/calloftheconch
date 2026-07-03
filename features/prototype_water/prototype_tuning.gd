class_name PrototypeTuning
extends RefCounted
## Runtime-only data for the Prototype 0.1 movement and presentation tuning panel.
## It contains values only; HylasController and PrototypeWater apply the behaviour.

const FORMAT_ID: String = "call_of_the_conch_prototype_tuning"
const SCHEMA_VERSION: int = 4

var swim_speed: float = 320.0
var swim_acceleration: float = 1600.0
var idle_momentum_deceleration: float = 300.0
var brake_deceleration: float = 2800.0
var idle_sink_speed: float = 14.0
var current_base_x: float = 10.0
var current_base_y: float = 0.0
var current_sway_horizontal: float = 7.0
var current_sway_vertical: float = 2.0
var current_sway_frequency: float = 0.24
var burst_speed: float = 1120.0
var burst_duration: float = 0.36
var burst_cooldown: float = 0.0
var burst_max_charges: float = 3.0
var burst_charge_recovery: float = 1.20
var vertical_burst_angle_degrees: float = 75.0
var jump_trigger_depth: float = 300.0
var jump_forward_distance: float = 430.0
var jump_arc_height: float = 240.0
var jump_frame_duration: float = 0.090
var normal_conch_cooldown: float = 0.80
var swim_frame_duration: float = 0.105
var speed_frame_duration: float = 0.060
var conch_frame_duration: float = 0.110
var hylas_display_height: float = 205.0
var hylas_shadow_opacity: float = 0.07
var hylas_shadow_offset_x: float = 5.0
var hylas_shadow_offset_y: float = 10.0
var hylas_shadow_blur_radius: float = 60.0
var hylas_shadow_scale: float = 1.12
var camera_smoothing_speed: float = 5.5
var conch_range: float = 700.0
var conch_pulse_duration: float = 0.52
var conch_line_width: float = 4.0
var tail_burst_size: float = 310.0
var tail_burst_back_offset: float = 120.0
var tail_burst_offset_y: float = 15.0
var tail_burst_interval_min: float = 0.50
var tail_burst_interval_max: float = 1.15
var water_horizontal_tiles: float = 3.0
var water_parallax_scroll_scale: float = 0.12
var lower_water_parallax_scroll_scale: float = 0.32


static func get_field_definitions() -> Array[Dictionary]:
	return [
		{"section": "Movement", "key": &"swim_speed", "label": "Swim speed (px/sec)", "min": 10.0, "max": 1000.0, "step": 5.0},
		{"section": "Movement", "key": &"swim_acceleration", "label": "Swim acceleration", "min": 100.0, "max": 10000.0, "step": 50.0},
		{"section": "Movement", "key": &"idle_momentum_deceleration", "label": "Idle momentum fade", "min": 0.0, "max": 3000.0, "step": 25.0},
		{"section": "Movement", "key": &"brake_deceleration", "label": "Brake deceleration", "min": 100.0, "max": 12000.0, "step": 50.0},
		{"section": "Current and idle", "key": &"idle_sink_speed", "label": "Idle sink speed", "min": -100.0, "max": 200.0, "step": 1.0},
		{"section": "Current and idle", "key": &"current_base_x", "label": "Current base X", "min": -200.0, "max": 200.0, "step": 1.0},
		{"section": "Current and idle", "key": &"current_base_y", "label": "Current base Y", "min": -200.0, "max": 200.0, "step": 1.0},
		{"section": "Current and idle", "key": &"current_sway_horizontal", "label": "Current horizontal sway", "min": 0.0, "max": 150.0, "step": 1.0},
		{"section": "Current and idle", "key": &"current_sway_vertical", "label": "Current vertical sway", "min": 0.0, "max": 150.0, "step": 1.0},
		{"section": "Current and idle", "key": &"current_sway_frequency", "label": "Current sway frequency", "min": 0.01, "max": 2.0, "step": 0.01},
		{"section": "Burst", "key": &"burst_speed", "label": "Burst launch speed (px/sec)", "min": 10.0, "max": 2000.0, "step": 10.0},
		{"section": "Burst", "key": &"burst_duration", "label": "Whole burst duration (sec)", "min": 0.05, "max": 2.0, "step": 0.01},
		{"section": "Burst", "key": &"burst_cooldown", "label": "Extra burst lockout (sec)", "min": 0.0, "max": 5.0, "step": 0.01},
		{"section": "Burst", "key": &"burst_max_charges", "label": "Maximum chained bursts", "min": 1.0, "max": 5.0, "step": 1.0},
		{"section": "Burst", "key": &"burst_charge_recovery", "label": "One burst charge recovery (sec)", "min": 0.10, "max": 10.0, "step": 0.05},
		{"section": "Burst", "key": &"vertical_burst_angle_degrees", "label": "Vertical burst tilt (degrees)", "min": 10.0, "max": 89.0, "step": 1.0},
		{"section": "Surface jump", "key": &"jump_trigger_depth", "label": "Jump trigger depth below surface", "min": 50.0, "max": 800.0, "step": 5.0},
		{"section": "Surface jump", "key": &"jump_forward_distance", "label": "Jump forward distance", "min": 50.0, "max": 1200.0, "step": 10.0},
		{"section": "Surface jump", "key": &"jump_arc_height", "label": "Jump arc height", "min": 20.0, "max": 1000.0, "step": 5.0},
		{"section": "Surface jump", "key": &"jump_frame_duration", "label": "Jump-frame duration", "min": 0.02, "max": 1.0, "step": 0.005},
		{"section": "Normal Conch", "key": &"normal_conch_cooldown", "label": "Conch cooldown (sec)", "min": 0.0, "max": 5.0, "step": 0.01},
		{"section": "Normal Conch", "key": &"conch_range", "label": "Conch visual range", "min": 20.0, "max": 2000.0, "step": 10.0},
		{"section": "Normal Conch", "key": &"conch_pulse_duration", "label": "Conch pulse duration", "min": 0.05, "max": 3.0, "step": 0.01},
		{"section": "Normal Conch", "key": &"conch_line_width", "label": "Conch line width", "min": 1.0, "max": 30.0, "step": 0.5},
		{"section": "Animation and camera", "key": &"swim_frame_duration", "label": "Swim frame duration", "min": 0.02, "max": 1.0, "step": 0.005},
		{"section": "Animation and camera", "key": &"speed_frame_duration", "label": "Speed-frame duration", "min": 0.02, "max": 1.0, "step": 0.005},
		{"section": "Animation and camera", "key": &"conch_frame_duration", "label": "Conch frame duration", "min": 0.02, "max": 1.0, "step": 0.005},
		{"section": "Animation and camera", "key": &"hylas_display_height", "label": "Hylas display height", "min": 40.0, "max": 700.0, "step": 1.0},
		{"section": "Animation and camera", "key": &"camera_smoothing_speed", "label": "Camera smoothing speed", "min": 0.0, "max": 30.0, "step": 0.1},
		{"section": "Hylas shadow", "key": &"hylas_shadow_opacity", "label": "Shadow opacity", "min": 0.0, "max": 0.80, "step": 0.01},
		{"section": "Hylas shadow", "key": &"hylas_shadow_offset_x", "label": "Shadow horizontal offset", "min": -80.0, "max": 80.0, "step": 1.0},
		{"section": "Hylas shadow", "key": &"hylas_shadow_offset_y", "label": "Shadow vertical offset", "min": -80.0, "max": 80.0, "step": 1.0},
		{"section": "Hylas shadow", "key": &"hylas_shadow_blur_radius", "label": "Shadow blur radius", "min": 0.0, "max": 120.0, "step": 1.0},
		{"section": "Hylas shadow", "key": &"hylas_shadow_scale", "label": "Shadow spread scale", "min": 1.0, "max": 1.30, "step": 0.01},
		{"section": "Tail bubbles", "key": &"tail_burst_size", "label": "Tail burst size", "min": 50.0, "max": 1000.0, "step": 5.0},
		{"section": "Tail bubbles", "key": &"tail_burst_back_offset", "label": "Tail burst back offset", "min": 0.0, "max": 500.0, "step": 1.0},
		{"section": "Tail bubbles", "key": &"tail_burst_offset_y", "label": "Tail burst vertical offset", "min": -300.0, "max": 300.0, "step": 1.0},
		{"section": "Tail bubbles", "key": &"tail_burst_interval_min", "label": "Tail burst minimum interval", "min": 0.05, "max": 5.0, "step": 0.05},
		{"section": "Tail bubbles", "key": &"tail_burst_interval_max", "label": "Tail burst maximum interval", "min": 0.05, "max": 8.0, "step": 0.05},
		{"section": "World layers", "key": &"water_horizontal_tiles", "label": "Environment chunks across", "min": 1.0, "max": 9.0, "step": 1.0},
		{"section": "World layers", "key": &"water_parallax_scroll_scale", "label": "Far water parallax speed", "min": 0.0, "max": 1.0, "step": 0.01},
		{"section": "World layers", "key": &"lower_water_parallax_scroll_scale", "label": "Lower water parallax speed", "min": 0.0, "max": 1.0, "step": 0.01},
	]


func reset_defaults() -> void:
	swim_speed = 320.0
	swim_acceleration = 1600.0
	idle_momentum_deceleration = 300.0
	brake_deceleration = 2800.0
	idle_sink_speed = 14.0
	current_base_x = 10.0
	current_base_y = 0.0
	current_sway_horizontal = 7.0
	current_sway_vertical = 2.0
	current_sway_frequency = 0.24
	burst_speed = 1120.0
	burst_duration = 0.36
	burst_cooldown = 0.0
	burst_max_charges = 3.0
	burst_charge_recovery = 1.20
	vertical_burst_angle_degrees = 75.0
	jump_trigger_depth = 300.0
	jump_forward_distance = 430.0
	jump_arc_height = 240.0
	jump_frame_duration = 0.090
	normal_conch_cooldown = 0.80
	swim_frame_duration = 0.105
	speed_frame_duration = 0.060
	conch_frame_duration = 0.110
	hylas_display_height = 205.0
	hylas_shadow_opacity = 0.07
	hylas_shadow_offset_x = 5.0
	hylas_shadow_offset_y = 10.0
	hylas_shadow_blur_radius = 60.0
	hylas_shadow_scale = 1.12
	camera_smoothing_speed = 5.5
	conch_range = 700.0
	conch_pulse_duration = 0.52
	conch_line_width = 4.0
	tail_burst_size = 310.0
	tail_burst_back_offset = 120.0
	tail_burst_offset_y = 15.0
	tail_burst_interval_min = 0.50
	tail_burst_interval_max = 1.15
	water_horizontal_tiles = 3.0
	water_parallax_scroll_scale = 0.12
	lower_water_parallax_scroll_scale = 0.32


func get_value(key: StringName) -> float:
	match key:
		&"swim_speed": return swim_speed
		&"swim_acceleration": return swim_acceleration
		&"idle_momentum_deceleration": return idle_momentum_deceleration
		&"brake_deceleration": return brake_deceleration
		&"idle_sink_speed": return idle_sink_speed
		&"current_base_x": return current_base_x
		&"current_base_y": return current_base_y
		&"current_sway_horizontal": return current_sway_horizontal
		&"current_sway_vertical": return current_sway_vertical
		&"current_sway_frequency": return current_sway_frequency
		&"burst_speed": return burst_speed
		&"burst_duration": return burst_duration
		&"burst_cooldown": return burst_cooldown
		&"burst_max_charges": return burst_max_charges
		&"burst_charge_recovery": return burst_charge_recovery
		&"vertical_burst_angle_degrees": return vertical_burst_angle_degrees
		&"jump_trigger_depth": return jump_trigger_depth
		&"jump_forward_distance": return jump_forward_distance
		&"jump_arc_height": return jump_arc_height
		&"jump_frame_duration": return jump_frame_duration
		&"normal_conch_cooldown": return normal_conch_cooldown
		&"swim_frame_duration": return swim_frame_duration
		&"speed_frame_duration": return speed_frame_duration
		&"conch_frame_duration": return conch_frame_duration
		&"hylas_display_height": return hylas_display_height
		&"hylas_shadow_opacity": return hylas_shadow_opacity
		&"hylas_shadow_offset_x": return hylas_shadow_offset_x
		&"hylas_shadow_offset_y": return hylas_shadow_offset_y
		&"hylas_shadow_blur_radius": return hylas_shadow_blur_radius
		&"hylas_shadow_scale": return hylas_shadow_scale
		&"camera_smoothing_speed": return camera_smoothing_speed
		&"conch_range": return conch_range
		&"conch_pulse_duration": return conch_pulse_duration
		&"conch_line_width": return conch_line_width
		&"tail_burst_size": return tail_burst_size
		&"tail_burst_back_offset": return tail_burst_back_offset
		&"tail_burst_offset_y": return tail_burst_offset_y
		&"tail_burst_interval_min": return tail_burst_interval_min
		&"tail_burst_interval_max": return tail_burst_interval_max
		&"water_horizontal_tiles": return water_horizontal_tiles
		&"water_parallax_scroll_scale": return water_parallax_scroll_scale
		&"lower_water_parallax_scroll_scale": return lower_water_parallax_scroll_scale
		_: return 0.0


func set_value(key: StringName, value: float) -> void:
	match key:
		&"swim_speed": swim_speed = clampf(value, 10.0, 1000.0)
		&"swim_acceleration": swim_acceleration = clampf(value, 100.0, 10000.0)
		&"idle_momentum_deceleration": idle_momentum_deceleration = clampf(value, 0.0, 3000.0)
		&"brake_deceleration": brake_deceleration = clampf(value, 100.0, 12000.0)
		&"idle_sink_speed": idle_sink_speed = clampf(value, -100.0, 200.0)
		&"current_base_x": current_base_x = clampf(value, -200.0, 200.0)
		&"current_base_y": current_base_y = clampf(value, -200.0, 200.0)
		&"current_sway_horizontal": current_sway_horizontal = clampf(value, 0.0, 150.0)
		&"current_sway_vertical": current_sway_vertical = clampf(value, 0.0, 150.0)
		&"current_sway_frequency": current_sway_frequency = clampf(value, 0.01, 2.0)
		&"burst_speed": burst_speed = clampf(value, 10.0, 2000.0)
		&"burst_duration": burst_duration = clampf(value, 0.05, 2.0)
		&"burst_cooldown": burst_cooldown = clampf(value, 0.0, 5.0)
		&"burst_max_charges": burst_max_charges = float(clampi(roundi(value), 1, 5))
		&"burst_charge_recovery": burst_charge_recovery = clampf(value, 0.10, 10.0)
		&"vertical_burst_angle_degrees": vertical_burst_angle_degrees = clampf(value, 10.0, 89.0)
		&"jump_trigger_depth": jump_trigger_depth = clampf(value, 50.0, 800.0)
		&"jump_forward_distance": jump_forward_distance = clampf(value, 50.0, 1200.0)
		&"jump_arc_height": jump_arc_height = clampf(value, 20.0, 1000.0)
		&"jump_frame_duration": jump_frame_duration = clampf(value, 0.02, 1.0)
		&"normal_conch_cooldown": normal_conch_cooldown = clampf(value, 0.0, 5.0)
		&"swim_frame_duration": swim_frame_duration = clampf(value, 0.02, 1.0)
		&"speed_frame_duration": speed_frame_duration = clampf(value, 0.02, 1.0)
		&"conch_frame_duration": conch_frame_duration = clampf(value, 0.02, 1.0)
		&"hylas_display_height": hylas_display_height = clampf(value, 40.0, 700.0)
		&"hylas_shadow_opacity": hylas_shadow_opacity = clampf(value, 0.0, 0.80)
		&"hylas_shadow_offset_x": hylas_shadow_offset_x = clampf(value, -80.0, 80.0)
		&"hylas_shadow_offset_y": hylas_shadow_offset_y = clampf(value, -80.0, 80.0)
		&"hylas_shadow_blur_radius": hylas_shadow_blur_radius = clampf(value, 0.0, 120.0)
		&"hylas_shadow_scale": hylas_shadow_scale = clampf(value, 1.0, 1.30)
		&"camera_smoothing_speed": camera_smoothing_speed = clampf(value, 0.0, 30.0)
		&"conch_range": conch_range = clampf(value, 20.0, 2000.0)
		&"conch_pulse_duration": conch_pulse_duration = clampf(value, 0.05, 3.0)
		&"conch_line_width": conch_line_width = clampf(value, 1.0, 30.0)
		&"tail_burst_size": tail_burst_size = clampf(value, 50.0, 1000.0)
		&"tail_burst_back_offset": tail_burst_back_offset = clampf(value, 0.0, 500.0)
		&"tail_burst_offset_y": tail_burst_offset_y = clampf(value, -300.0, 300.0)
		&"tail_burst_interval_min": tail_burst_interval_min = clampf(value, 0.05, 5.0)
		&"tail_burst_interval_max": tail_burst_interval_max = clampf(value, 0.05, 8.0)
		&"water_horizontal_tiles": water_horizontal_tiles = float(clampi(roundi(value), 1, 9))
		&"water_parallax_scroll_scale": water_parallax_scroll_scale = clampf(value, 0.0, 1.0)
		&"lower_water_parallax_scroll_scale": lower_water_parallax_scroll_scale = clampf(value, 0.0, 1.0)
		_: push_warning("Unknown prototype tuning key: %s" % key)
	_normalise_interdependent_values()


func to_export_dictionary() -> Dictionary:
	var values: Dictionary = {}
	for definition: Dictionary in get_field_definitions():
		var key: StringName = StringName(definition["key"])
		values[str(key)] = get_value(key)
	return {
		"format": FORMAT_ID,
		"schema_version": SCHEMA_VERSION,
		"values": values,
	}


func _normalise_interdependent_values() -> void:
	if tail_burst_interval_max < tail_burst_interval_min:
		tail_burst_interval_max = tail_burst_interval_min
