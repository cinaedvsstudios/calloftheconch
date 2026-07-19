extends "res://scenes/characters/Hylas/hylas_phase6_fix.gd"

## Carries active vent tiers into Speed Run surface jumps and applies local
## seaweed movement modifiers without weakening environmental currents.

const SUPER_JUMP_AUDIO: AudioStream = preload("res://assets/audio/superjump.mp3")
const PRESSURE_JUMP_THRESHOLD: float = 1.99

@export_category("Vent Surface Jump")
@export_range(-30.0, 6.0, 1.0) var super_jump_volume_db: float = -4.0

var _active_jump_arc_height: float = 0.0
var _active_jump_duration: float = 0.0
var _active_vent_jump_multiplier: float = 1.0
var _pressure_jump_active: bool = false
var _super_jump_audio: AudioStreamPlayer
var _seaweed_slow_sources: Dictionary[Node, float] = {}


func _ready() -> void:
	super._ready()
	_super_jump_audio = AudioStreamPlayer.new()
	_super_jump_audio.name = "SuperJumpAudio"
	_super_jump_audio.stream = SUPER_JUMP_AUDIO
	_super_jump_audio.volume_db = super_jump_volume_db
	add_child(_super_jump_audio)


func set_seaweed_slow_source(
		source: Node,
		movement_multiplier: float = 0.5,
	) -> void:
	if not is_instance_valid(source):
		return
	_seaweed_slow_sources[source] = clampf(movement_multiplier, 0.05, 1.0)


func remove_seaweed_slow_source(source: Node) -> void:
	_seaweed_slow_sources.erase(source)


func is_seaweed_slowed() -> bool:
	return get_seaweed_movement_multiplier() < 0.999


func get_seaweed_movement_multiplier() -> float:
	_remove_invalid_seaweed_sources()
	if is_item_surge_active() or is_conus_wall_climbing():
		return 1.0

	var strongest_slow: float = 1.0
	for source: Node in _seaweed_slow_sources.keys():
		strongest_slow = minf(strongest_slow, _seaweed_slow_sources[source])
	return strongest_slow


func _apply_motion(motion_velocity: Vector2, idle: bool) -> void:
	var movement_multiplier: float = get_seaweed_movement_multiplier()
	super._apply_motion(motion_velocity * movement_multiplier, idle)


func _remove_invalid_seaweed_sources() -> void:
	for source: Node in _seaweed_slow_sources.keys():
		if not is_instance_valid(source):
			_seaweed_slow_sources.erase(source)


func _begin_surface_jump() -> void:
	var jump_multiplier: float = _resolve_active_vent_jump_multiplier()
	var duration_multiplier: float = _resolve_active_vent_jump_duration_multiplier()

	super._begin_surface_jump()
	if _jump_elapsed <= 0.0:
		return

	_active_vent_jump_multiplier = maxf(1.0, jump_multiplier)
	_active_jump_arc_height = jump_arc_height * _active_vent_jump_multiplier
	_active_jump_duration = jump_duration * maxf(1.0, duration_multiplier)
	_pressure_jump_active = _active_vent_jump_multiplier >= PRESSURE_JUMP_THRESHOLD

	var facing_sign: float = -1.0 if _facing_left else 1.0
	_jump_end = Vector2(
		_jump_start.x + facing_sign * jump_forward_distance * _active_vent_jump_multiplier,
		_swim_ceiling_y + 40.0,
	)

	if _pressure_jump_active:
		_animated_sprite.pause()
		if is_instance_valid(_super_jump_audio):
			_super_jump_audio.stop()
			_super_jump_audio.play()


func _update_surface_jump(delta: float) -> void:
	_jump_elapsed += delta
	var active_duration: float = maxf(
		0.01,
		_active_jump_duration if _active_jump_duration > 0.0 else jump_duration,
	)
	var active_arc_height: float = (
		_active_jump_arc_height if _active_jump_arc_height > 0.0 else jump_arc_height
	)
	var progress: float = clampf(_jump_elapsed / active_duration, 0.0, 1.0)
	var base_position: Vector2 = _jump_start.lerp(_jump_end, progress)
	global_position = Vector2(
		base_position.x,
		base_position.y - sin(progress * PI) * active_arc_height,
	)

	if _pressure_jump_active:
		_update_pressure_jump_frame(progress)

	if progress >= 0.80 and _jump_elapsed - delta < active_duration * 0.80:
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
	if progress < 1.0:
		return

	_jump_elapsed = 0.0
	global_position = _clamp_to_world(_jump_end)
	_active_jump_arc_height = 0.0
	_active_jump_duration = 0.0
	_active_vent_jump_multiplier = 1.0
	_pressure_jump_active = false
	_animated_sprite.speed_scale = 1.0
	_set_animation(&"idle")


func _resolve_active_vent_jump_multiplier() -> float:
	var strongest_multiplier: float = 1.0
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			continue
		if not source.has_method(&"get_surface_jump_multiplier"):
			continue
		strongest_multiplier = maxf(
			strongest_multiplier,
			float(source.call(&"get_surface_jump_multiplier")),
		)
	return strongest_multiplier


func _resolve_active_vent_jump_duration_multiplier() -> float:
	var longest_multiplier: float = 1.0
	for source: Node in _external_currents.keys():
		if not is_instance_valid(source):
			continue
		if not source.has_method(&"get_surface_jump_duration_multiplier"):
			continue
		longest_multiplier = maxf(
			longest_multiplier,
			float(source.call(&"get_surface_jump_duration_multiplier")),
		)
	return longest_multiplier


func _update_pressure_jump_frame(progress: float) -> void:
	if _animated_sprite.animation != &"jump":
		_animated_sprite.animation = &"jump"
	var frame_count: int = _animated_sprite.sprite_frames.get_frame_count(&"jump")
	if frame_count <= 0:
		return

	var frame_index: int = 0
	if progress < 0.12:
		frame_index = 0
	elif progress < 0.26:
		frame_index = 1
	elif progress < 0.42:
		frame_index = 2
	elif progress < 0.68:
		frame_index = 3
	elif progress < 0.84:
		frame_index = 4
	else:
		frame_index = 5

	_animated_sprite.frame = mini(frame_index, frame_count - 1)
	_animated_sprite.pause()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("seaweed_sources=%d" % _seaweed_slow_sources.size())
	lines.append("seaweed_multiplier=%.2f" % get_seaweed_movement_multiplier())
	lines.append("seaweed_bypassed_by_surge=%s" % str(is_item_surge_active()))
	lines.append("seaweed_bypassed_by_conus=%s" % str(is_conus_wall_climbing()))
	return lines
