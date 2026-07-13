extends "res://rebuild_v3/features/effects/conch_pulse.gd"

@export_category("Screen Range")
@export_range(0.0, 200.0, 1.0) var screen_edge_padding: float = 36.0

@export_category("Visual Lifetime")
@export_range(0.0, 1.0, 0.01) var visual_fade_start_fraction: float = 0.34
@export_range(0.05, 1.0, 0.01) var visual_fade_end_fraction: float = 0.50

var _minimum_pulse_diameter: float = 700.0


func _ready() -> void:
	_minimum_pulse_diameter = pulse_range
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_apply_short_visual_lifetime()


func trigger(origin: Vector2, direction: Vector2) -> void:
	var pulse_direction: Vector2 = direction
	if pulse_direction.length_squared() <= 0.0001:
		pulse_direction = Vector2.RIGHT
	else:
		pulse_direction = pulse_direction.normalized()
	pulse_range = _calculate_screen_edge_diameter(origin, pulse_direction)
	super.trigger(origin, pulse_direction)


func _apply_short_visual_lifetime() -> void:
	var fade_start_fraction: float = clampf(visual_fade_start_fraction, 0.0, 0.95)
	var fade_end_fraction: float = clampf(
		maxf(visual_fade_end_fraction, fade_start_fraction + 0.01),
		0.01,
		1.0,
	)
	var fade_start_time: float = pulse_duration * fade_start_fraction
	var fade_end_time: float = pulse_duration * fade_end_fraction

	for pulse_index: int in range(_pulse_sprites.size()):
		if not _pulse_started[pulse_index]:
			continue
		var local_elapsed: float = _sequence_elapsed - float(pulse_index) * pulse_interval
		if local_elapsed <= fade_start_time:
			continue
		var pulse_sprite: Sprite2D = _pulse_sprites[pulse_index]
		if local_elapsed >= fade_end_time:
			pulse_sprite.modulate.a = 0.0
			pulse_sprite.hide()
			continue
		var fade_progress: float = inverse_lerp(fade_start_time, fade_end_time, local_elapsed)
		var fade_multiplier: float = 1.0 - smoothstep(0.0, 1.0, fade_progress)
		pulse_sprite.modulate.a *= fade_multiplier

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

	# The sonar texture is scaled by diameter while its wavefront travels by radius,
	# so the required diameter is twice the world distance to the visible edge.
	return maxf(_minimum_pulse_diameter, (world_distance + screen_edge_padding) * 2.0)
