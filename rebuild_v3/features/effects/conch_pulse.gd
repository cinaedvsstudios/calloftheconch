class_name CotcConchPulse
extends Node2D

signal pulse_wave_started(pulse_index: int)
signal pulse_wave_finished(pulse_index: int)
signal target_hit(target: Node2D, hit_position: Vector2, pulse_index: int)

@export_category("Directional Pulse Stream")
@export var start_diameter: float = 20.0
@export var pulse_range: float = 700.0
@export var pulse_duration: float = 0.52
@export_range(1, 12, 1) var pulse_count: int = 4
@export_range(0.02, 0.5, 0.01) var pulse_interval: float = 0.11
@export_range(0.0, 0.4, 0.01) var echo_alpha_decay: float = 0.12
@export_range(1.0, 180.0, 0.5) var arc_degrees: float = 45.0
@export_range(0.0, 30.0, 0.5) var arc_edge_softness_degrees: float = 4.0
@export_range(0.0, 8.0, 0.05) var sonar_brightness: float = 1.35

@export_category("Hit Tracking")
@export var target_group: StringName = &"conch_target"
@export_range(0.0, 200.0, 1.0) var target_radius_padding: float = 30.0
@export var hit_once_per_trigger: bool = true
@export_range(20.0, 400.0, 1.0) var close_range_radius: float = 185.0
@export_range(0.0, 250.0, 1.0) var point_blank_radius: float = 95.0
@export_range(1.0, 180.0, 1.0) var close_range_arc_degrees: float = 120.0

@export_category("Origin Flash")
@export_range(0.05, 2.0, 0.01) var flash_scale: float = 0.35

@onready var _sonar_arc_template: Sprite2D = %SonarArc
@onready var _origin_flash_pivot: Node2D = %OriginFlashPivot
@onready var _origin_flash: VideoStreamPlayer = %OriginFlash

var _sequence_elapsed: float = 0.0
var _sequence_active: bool = false
var _flash_active: bool = false
var _pulse_reference_diameter: float = 1.0
var _pulse_direction: Vector2 = Vector2.RIGHT
var _pulse_material: ShaderMaterial
var _pulse_sprites: Array[Sprite2D] = []
var _pulse_started: Array[bool] = []
var _pulse_finished: Array[bool] = []
var _pulse_previous_radius: Array[float] = []
var _pulse_hit_targets: Array[Dictionary] = []
var _sequence_hit_targets: Dictionary = {}
var _last_hit_count: int = 0
var _last_trigger_origin: Vector2 = Vector2.ZERO
var _last_player_origin: Vector2 = Vector2.ZERO
var _player_source: Node2D
var _player_forward_offset: float = 0.0


func _ready() -> void:
	_prepare_pulse_material()
	_measure_pulse_reference_diameter()
	_build_pulse_sprites()
	_origin_flash.loop = false
	_update_origin_flash_transform()
	_origin_flash.finished.connect(_on_origin_flash_finished)
	_origin_flash.hide()
	hide()
	set_process(false)


func trigger(origin: Vector2, direction: Vector2) -> void:
	trigger_from_player(origin, direction, origin)


func trigger_from_player(origin: Vector2, direction: Vector2, player_origin: Vector2) -> void:
	_player_source = _find_player_source(player_origin)
	var resolved_origin: Vector2 = origin
	if is_instance_valid(_player_source):
		resolved_origin = _get_source_pulse_origin(_player_source, origin)

	global_position = resolved_origin
	_last_trigger_origin = resolved_origin
	_last_player_origin = player_origin
	_player_forward_offset = resolved_origin.distance_to(player_origin)
	_pulse_direction = direction
	if _pulse_direction.length_squared() <= 0.0001:
		_pulse_direction = Vector2.RIGHT
	else:
		_pulse_direction = _pulse_direction.normalized()

	_sequence_elapsed = 0.0
	_sequence_active = true
	_last_hit_count = 0
	_sequence_hit_targets.clear()
	_reset_pulse_state()
	_track_close_range_targets(player_origin)
	_apply_pulse_direction()

	show()
	_play_origin_flash()
	set_process(true)
	_update_pulse_stream()


func stop() -> void:
	_sequence_active = false
	_flash_active = false
	_sequence_elapsed = 0.0
	_player_source = null
	_player_forward_offset = 0.0
	_origin_flash.stop()
	_origin_flash.hide()
	for pulse_sprite: Sprite2D in _pulse_sprites:
		pulse_sprite.hide()
	set_process(false)
	hide()


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


func _prepare_pulse_material() -> void:
	var source_material: ShaderMaterial = _sonar_arc_template.material as ShaderMaterial
	if source_material == null:
		return
	_pulse_material = source_material.duplicate() as ShaderMaterial
	_sonar_arc_template.material = _pulse_material
	_pulse_material.set_shader_parameter(&"arc_degrees", arc_degrees)
	_pulse_material.set_shader_parameter(&"edge_softness_degrees", arc_edge_softness_degrees)
	_pulse_material.set_shader_parameter(&"brightness", sonar_brightness)


func _measure_pulse_reference_diameter() -> void:
	if _sonar_arc_template.texture == null:
		_pulse_reference_diameter = 1.0
		return
	var texture_size: Vector2 = _sonar_arc_template.texture.get_size()
	_pulse_reference_diameter = maxf(1.0, maxf(texture_size.x, texture_size.y))


func _build_pulse_sprites() -> void:
	_pulse_sprites.clear()
	_pulse_sprites.append(_sonar_arc_template)
	for pulse_index: int in range(1, pulse_count):
		var echo_sprite: Sprite2D = Sprite2D.new()
		echo_sprite.name = "SonarArcEcho%02d" % pulse_index
		echo_sprite.texture = _sonar_arc_template.texture
		echo_sprite.material = _sonar_arc_template.material
		echo_sprite.centered = _sonar_arc_template.centered
		echo_sprite.offset = _sonar_arc_template.offset
		echo_sprite.position = _sonar_arc_template.position
		echo_sprite.z_index = _sonar_arc_template.z_index
		echo_sprite.texture_filter = _sonar_arc_template.texture_filter
		add_child(echo_sprite)
		_pulse_sprites.append(echo_sprite)
	_reset_pulse_state()


func _reset_pulse_state() -> void:
	_pulse_started.resize(_pulse_sprites.size())
	_pulse_finished.resize(_pulse_sprites.size())
	_pulse_previous_radius.resize(_pulse_sprites.size())
	_pulse_hit_targets.resize(_pulse_sprites.size())
	for pulse_index: int in range(_pulse_sprites.size()):
		_pulse_started[pulse_index] = false
		_pulse_finished[pulse_index] = false
		_pulse_previous_radius[pulse_index] = 0.0
		_pulse_hit_targets[pulse_index] = {}
		var pulse_sprite: Sprite2D = _pulse_sprites[pulse_index]
		pulse_sprite.modulate.a = 0.0
		pulse_sprite.hide()


func _find_player_source(player_origin: Vector2) -> Node2D:
	var closest_source: Node2D = null
	var closest_distance_squared: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"hylas"):
		var candidate: Node2D = node as Node2D
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance_squared: float = candidate.global_position.distance_squared_to(player_origin)
		if distance_squared >= closest_distance_squared:
			continue
		closest_source = candidate
		closest_distance_squared = distance_squared
	return closest_source


func _get_source_pulse_origin(source: Node2D, fallback_origin: Vector2) -> Vector2:
	var origin_marker: Marker2D = source.get_node_or_null("ConchPulseOrigin") as Marker2D
	if origin_marker == null:
		return fallback_origin

	var local_offset: Vector2 = origin_marker.position
	var player_sprite: AnimatedSprite2D = source.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if player_sprite != null:
		if player_sprite.flip_h:
			local_offset.x = -local_offset.x
		local_offset = local_offset.rotated(player_sprite.rotation)
	return source.global_position + local_offset


func _update_player_tracking() -> void:
	if not is_instance_valid(_player_source):
		return
	var player_sprite: AnimatedSprite2D = _player_source.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if player_sprite == null or player_sprite.animation != &"conch":
		return

	var facing_direction: Vector2 = Vector2.LEFT if player_sprite.flip_h else Vector2.RIGHT
	var updated_direction: Vector2 = facing_direction.rotated(player_sprite.rotation)
	if updated_direction.length_squared() <= 0.0001:
		return
	_pulse_direction = updated_direction.normalized()
	_last_player_origin = _player_source.global_position
	var fallback_origin: Vector2 = _last_player_origin + _pulse_direction * _player_forward_offset
	global_position = _get_source_pulse_origin(_player_source, fallback_origin)
	_apply_pulse_direction()


func _apply_pulse_direction() -> void:
	for pulse_sprite: Sprite2D in _pulse_sprites:
		pulse_sprite.rotation = _pulse_direction.angle()
	_update_origin_flash_transform()


func _update_origin_flash_transform() -> void:
	if not is_instance_valid(_origin_flash_pivot):
		return

	var facing_left: bool = _pulse_direction.x < -0.0001
	var visual_rotation: float = _pulse_direction.angle()
	if facing_left:
		visual_rotation = wrapf(visual_rotation - PI, -PI, PI)

	if is_instance_valid(_player_source):
		var player_sprite: AnimatedSprite2D = _player_source.get_node_or_null("AnimatedSprite") as AnimatedSprite2D
		if player_sprite != null:
			facing_left = player_sprite.flip_h
			visual_rotation = player_sprite.rotation

	var facing_sign: float = -1.0 if facing_left else 1.0
	_origin_flash_pivot.rotation = visual_rotation
	_origin_flash_pivot.scale = Vector2(facing_sign * flash_scale, flash_scale)


func _track_close_range_targets(player_origin: Vector2) -> void:
	if target_group == &"":
		return
	var minimum_dot: float = cos(deg_to_rad(close_range_arc_degrees * 0.5))
	for node: Node in get_tree().get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_offset: Vector2 = target.global_position - player_origin
		var target_distance: float = target_offset.length()
		if target_distance > close_range_radius + target_radius_padding:
			continue
		if target_distance > point_blank_radius and target_offset.length_squared() > 0.0001:
			if _pulse_direction.dot(target_offset.normalized()) < minimum_dot:
				continue
		_register_target_hit(target, 0)


func _update_pulse_stream() -> void:
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

		var sampled_elapsed: float = minf(local_elapsed, pulse_duration)
		var progress: float = sampled_elapsed / maxf(0.01, pulse_duration)
		var diameter: float = lerpf(start_diameter, pulse_range, progress)
		_apply_diameter(pulse_sprite, diameter)
		var echo_strength: float = maxf(0.25, 1.0 - float(pulse_index) * echo_alpha_decay)
		pulse_sprite.modulate.a = (1.0 - progress) * echo_strength

		var current_radius: float = diameter * 0.5
		_track_pulse_targets(
			pulse_index,
			_pulse_previous_radius[pulse_index],
			current_radius,
		)
		_pulse_previous_radius[pulse_index] = current_radius

		if local_elapsed >= pulse_duration:
			_pulse_finished[pulse_index] = true
			pulse_sprite.hide()
			pulse_wave_finished.emit(pulse_index)


func _apply_diameter(pulse_sprite: Sprite2D, diameter: float) -> void:
	var scale_factor: float = maxf(0.0, diameter) / _pulse_reference_diameter
	pulse_sprite.scale = Vector2.ONE * scale_factor


func _track_pulse_targets(pulse_index: int, previous_radius: float, current_radius: float) -> void:
	if target_group == &"":
		return

	var minimum_dot: float = cos(deg_to_rad(arc_degrees * 0.5))
	var minimum_distance: float = maxf(0.0, previous_radius - target_radius_padding)
	var maximum_distance: float = current_radius + target_radius_padding

	for node: Node in get_tree().get_nodes_in_group(target_group):
		var target: Node2D = node as Node2D
		if target == null or not is_instance_valid(target):
			continue

		var target_id: int = target.get_instance_id()
		if _pulse_hit_targets[pulse_index].has(target_id):
			continue
		if hit_once_per_trigger and _sequence_hit_targets.has(target_id):
			continue

		var target_offset: Vector2 = target.global_position - global_position
		var target_distance: float = target_offset.length()
		if target_distance < minimum_distance or target_distance > maximum_distance:
			continue
		if target_offset.length_squared() > 0.0001:
			var direction_dot: float = _pulse_direction.dot(target_offset.normalized())
			if direction_dot < minimum_dot:
				continue

		_pulse_hit_targets[pulse_index][target_id] = true
		_register_target_hit(target, pulse_index)


func _register_target_hit(target: Node2D, pulse_index: int) -> void:
	var target_id: int = target.get_instance_id()
	if hit_once_per_trigger and _sequence_hit_targets.has(target_id):
		return
	_sequence_hit_targets[target_id] = true
	_last_hit_count += 1
	target_hit.emit(target, target.global_position, pulse_index)


func _play_origin_flash() -> void:
	if _origin_flash.stream == null:
		_flash_active = false
		_origin_flash.hide()
		return
	_flash_active = true
	_origin_flash.stop()
	_origin_flash.show()
	_origin_flash.play()


func _on_origin_flash_finished() -> void:
	_flash_active = false
	_origin_flash.hide()
	_hide_when_finished()


func _hide_when_finished() -> void:
	if not _sequence_active and not _flash_active:
		hide()


func get_debug_lines() -> Array[String]:
	return [
		"[ConchPulse]",
		"sequence_active=%s" % str(_sequence_active),
		"pulse_count=%d" % _pulse_sprites.size(),
		"pulse_interval=%.2f" % pulse_interval,
		"direction=%s" % str(_pulse_direction),
		"last_origin=%s" % str(_last_trigger_origin),
		"last_player_origin=%s" % str(_last_player_origin),
		"player_tracking=%s" % str(is_instance_valid(_player_source)),
		"last_hit_events=%d" % _last_hit_count,
		"target_group=%s" % str(target_group),
	]
