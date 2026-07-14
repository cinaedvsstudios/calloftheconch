extends "res://rebuild_v3/features/effects/conch_pulse.gd"

@export_category("Screen Range")
@export_range(0.0, 200.0, 1.0) var screen_edge_padding: float = 36.0

@export_category("Visual Lifetime")
@export_range(0.05, 0.95, 0.01) var visual_fade_start_fraction: float = 0.34
@export_range(0.05, 1.0, 0.01) var visual_fade_end_fraction: float = 0.50
@export_range(0.5, 1.0, 0.01) var visual_end_scale: float = 0.92

var _minimum_pulse_diameter: float = 700.0


func _ready() -> void:
	_minimum_pulse_diameter = pulse_range
	super._ready()


func _process(delta: float) -> void:
	if not _sequence_active:
		return

	_update_player_tracking()
	_sequence_elapsed += delta
	_update_pulse_stream()
	var final_pulse_delay: float = float(maxi(0, _pulse_sprites.size() - 1)) * pulse_interval
	if _sequence_elapsed >= final_pulse_delay + pulse_duration:
		_sequence_active = false
		set_process(false)
		_hide_when_finished()


func trigger(origin: Vector2, direction: Vector2) -> void:
	trigger_from_player(origin, direction, origin)


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()

	var resolved_origin: Vector2 = origin
	var source: Node2D = _find_player_source(player_origin)
	if is_instance_valid(source):
		resolved_origin = _get_source_pulse_origin(source, origin)
	pulse_range = _calculate_screen_edge_diameter(resolved_origin, pulse_direction)
	super.trigger_from_player(origin, pulse_direction, player_origin)


func _update_pulse_stream() -> void:
	var fade_start_fraction: float = clampf(visual_fade_start_fraction, 0.05, 0.95)
	var fade_end_fraction: float = clampf(
		maxf(visual_fade_end_fraction, fade_start_fraction + 0.01),
		0.06,
		1.0,
	)
	var reach_edge_time: float = maxf(0.01, pulse_duration * fade_start_fraction)
	var fade_end_time: float = maxf(reach_edge_time + 0.01, pulse_duration * fade_end_fraction)

	for pulse_index: int in range(_pulse_sprites.size()):
		if _pulse_finished[pulse_index]:
			continue

		var local_elapsed: float = _sequence_elapsed - float(pulse_index) * pulse_interval
		if local_elapsed < 0.0:
			continue

		var pulse_sprite: Sprite2D = _pulse_sprites[pulse_index]
		if not _pulse_started[pulse_index]:
			_pulse_started[pulse_index] = true
			pulse_sprite.show()
			pulse_wave_started.emit(pulse_index)

		var travel_progress: float = clampf(local_elapsed / reach_edge_time, 0.0, 1.0)
		var eased_travel: float = smoothstep(0.0, 1.0, travel_progress)
		var hit_diameter: float = lerpf(start_diameter, pulse_range, eased_travel)
		var visual_diameter: float = hit_diameter
		var visual_alpha: float = 1.0

		if local_elapsed > reach_edge_time:
			var fade_progress: float = clampf(
				inverse_lerp(reach_edge_time, fade_end_time, local_elapsed),
				0.0,
				1.0,
			)
			var eased_fade: float = smoothstep(0.0, 1.0, fade_progress)
			visual_alpha = 1.0 - eased_fade
			visual_diameter = pulse_range * lerpf(1.0, visual_end_scale, eased_fade)

		_apply_diameter(pulse_sprite, visual_diameter)
		var echo_strength: float = maxf(0.25, 1.0 - float(pulse_index) * echo_alpha_decay)
		pulse_sprite.modulate.a = visual_alpha * echo_strength

		var current_radius: float = hit_diameter * 0.5
		var previous_radius: float = _pulse_previous_radius[pulse_index]
		if current_radius >= previous_radius:
			_track_pulse_targets(pulse_index, previous_radius, current_radius)
			_pulse_previous_radius[pulse_index] = current_radius

		if local_elapsed >= fade_end_time:
			_pulse_finished[pulse_index] = true
			pulse_sprite.modulate.a = 0.0
			pulse_sprite.hide()
			pulse_wave_finished.emit(pulse_index)

	if _flash_active and _sequence_elapsed >= fade_end_time:
		_flash_active = false
		_origin_flash.stop()
		_origin_flash.hide()


func _calculate_screen_edge_diameter(origin: Vector2, direction: Vector2) -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return _minimum_pulse_diameter

	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var screen_origin: Vector2 = canvas_transform * origin
	var screen_step: Vector2 = (canvas_transform * (origin + direction)) - screen_origin
	var screen_units_per_world_unit: float = screen_step.length()
	if screen_units_per_world_unit <= 0.0001:
		return _minimum_pulse_diameter

	var world_distance: float = INF
	if screen_step.x > 0.0001:
		var right_distance: float = (viewport_size.x - screen_origin.x) / screen_step.x
		if right_distance > 0.0:
			world_distance = minf(world_distance, right_distance)
	elif screen_step.x < -0.0001:
		var left_distance: float = (0.0 - screen_origin.x) / screen_step.x
		if left_distance > 0.0:
			world_distance = minf(world_distance, left_distance)

	if screen_step.y > 0.0001:
		var bottom_distance: float = (viewport_size.y - screen_origin.y) / screen_step.y
		if bottom_distance > 0.0:
			world_distance = minf(world_distance, bottom_distance)
	elif screen_step.y < -0.0001:
		var top_distance: float = (0.0 - screen_origin.y) / screen_step.y
		if top_distance > 0.0:
			world_distance = minf(world_distance, top_distance)

	if world_distance == INF or world_distance <= 0.0:
		return _minimum_pulse_diameter

	var padding_world_units: float = screen_edge_padding / screen_units_per_world_unit
	return maxf(
		_minimum_pulse_diameter,
		(world_distance + padding_world_units) * 2.0,
	)
