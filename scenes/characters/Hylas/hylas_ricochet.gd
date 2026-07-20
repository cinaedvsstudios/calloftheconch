extends "res://scenes/characters/Hylas/hylas.gd"

## Adds the lane-gated Ricochet maneuver without changing the consolidated Hylas
## controller. Speed Run still starts normally; Ricochet only queues from a fresh
## Shift/action_a tap while Hylas is already moving fast inside a RicochetLane.

signal ricochet_attempt_queued(origin: Vector2, direction: Vector2)
signal ricochet_bounced(contact_position: Vector2, normal: Vector2, new_direction: Vector2, chain_count: int)
signal ricochet_failed(contact_position: Vector2, normal: Vector2, reason: StringName)
signal ricochet_finished(reason: StringName)

const DEFAULT_RICOCHET_SURFACE_GROUP: StringName = &"ricochet_surface"
const NON_RICOCHET_SURFACE_GROUP: StringName = &"non_ricochet_surface"
const HAZARD_SURFACE_GROUP: StringName = &"hazard_surface"
const RICOCHET_ANIMATION: StringName = &"ricochet"
const RICOCHET_CONTACT_FX_SCENE: PackedScene = preload(
	"res://rebuild_v3/features/effects/ricochet_contact_fx/ricochet_contact_fx.tscn"
)
const RICOCHET_01: Texture2D = preload("res://assets/characters/hylas-ricochet_01.webp")
const RICOCHET_02: Texture2D = preload("res://assets/characters/hylas-ricochet_02.webp")

@export_category("Ricochet Maneuver")
@export_range(100.0, 3000.0, 10.0) var ricochet_bounce_speed: float = 1120.0
@export_range(50.0, 3000.0, 10.0) var ricochet_minimum_speed: float = 520.0
@export_range(0.05, 1.00, 0.01) var ricochet_queue_seconds: float = 0.42
@export_range(0.00, 1.00, 0.01) var ricochet_post_bounce_queue_grace: float = 0.30
@export_range(0.02, 0.50, 0.01) var ricochet_minimum_time_between_bounces: float = 0.10
@export_range(0.05, 1.00, 0.01) var ricochet_wall_minimum_dot: float = 0.25
@export_range(0.10, 2.00, 0.05) var ricochet_vertical_bias_strength: float = 1.0
@export_range(0.0, 48.0, 1.0) var ricochet_wall_separation: float = 8.0
@export var ricochet_default_requires_surface_group: bool = false

@export_category("Ricochet Contact Presentation")
@export_range(1.0, 60.0, 0.5) var ricochet_animation_fps: float = 16.0
@export var ricochet_contact_fx_enabled: bool = true
@export var ricochet_contact_fx_rock_tint: Color = Color.WHITE
@export_range(0.10, 3.0, 0.05) var ricochet_contact_fx_intensity: float = 1.0

var _ricochet_lanes: Array[Node] = []
var _ricochet_queued: bool = false
var _ricochet_queue_remaining: float = 0.0
var _ricochet_chain_active: bool = false
var _ricochet_chain_grace_remaining: float = 0.0
var _ricochet_bounce_cooldown_remaining: float = 0.0
var _ricochet_chain_count: int = 0
var _ricochet_last_vertical_sign: float = -1.0
var _last_ricochet_wall_id: int = 0
var _ricochet_animation_remaining: float = 0.0


func _ready() -> void:
	super._ready()
	_install_ricochet_animation(_animated_sprite.sprite_frames)


func enter_ricochet_lane(lane: Node) -> void:
	if not is_instance_valid(lane):
		return
	if _ricochet_lanes.has(lane):
		return
	_ricochet_lanes.append(lane)


func exit_ricochet_lane(lane: Node) -> void:
	_ricochet_lanes.erase(lane)
	if _get_active_ricochet_lane() == null:
		_finish_ricochet(&"lane_exit")


func is_ricochet_lane_active() -> bool:
	return _get_active_ricochet_lane() != null


func is_ricochet_queued() -> bool:
	return _ricochet_queued


func is_ricochet_chain_active() -> bool:
	return _ricochet_chain_active


func set_play_enabled(enabled: bool) -> void:
	if not enabled:
		_clear_ricochet_state(&"play_disabled")
	super.set_play_enabled(enabled)


func reset_to_start(start_position: Vector2) -> void:
	_clear_ricochet_state(&"reset")
	super.reset_to_start(start_position)


func start_death_sequence() -> void:
	_clear_ricochet_state(&"death")
	super.start_death_sequence()


func _start_burst(input_direction: Vector2) -> void:
	# A fresh Shift tap during Speed Run coast is the ricochet input. Without this
	# guard the base burst code starts a new Speed Run on the same tap and clears
	# the ricochet queue before wall contact can consume it.
	if _should_reserve_action_a_for_ricochet(input_direction):
		return
	_clear_ricochet_queue()
	_ricochet_chain_active = false
	_ricochet_chain_count = 0
	super._start_burst(input_direction)


func _start_brake() -> void:
	_clear_ricochet_state(&"stop")
	super._start_brake()


func _is_burst_input_held(input_direction: Vector2) -> bool:
	if (
			_ricochet_chain_active
			and input_direction.length_squared() > 0.0001
			and _get_active_ricochet_lane() != null
		):
		return true
	return super._is_burst_input_held(input_direction)


func _can_start_burst(input_direction: Vector2) -> bool:
	if _should_reserve_action_a_for_ricochet(input_direction):
		return false
	return super._can_start_burst(input_direction)


func _physics_process(delta: float) -> void:
	_update_ricochet_timers(delta)
	var input_direction: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_up",
		&"move_down"
	)
	if Input.is_action_just_pressed(&"action_a"):
		_handle_ricochet_shift_press(input_direction)

	super._physics_process(delta)
	_resolve_ricochet_wall_contacts()
	_update_ricochet_animation_return(delta)


func _handle_ricochet_shift_press(input_direction: Vector2) -> void:
	if input_direction.length_squared() <= 0.0001:
		_clear_ricochet_queue()
		if _ricochet_chain_active:
			_finish_ricochet(&"stop_override")
		return

	var lane: Node = _get_active_ricochet_lane()
	if lane == null:
		return
	if not _can_queue_ricochet():
		return

	_ricochet_queued = true
	_ricochet_queue_remaining = _get_lane_float(lane, &"queue_seconds", ricochet_queue_seconds)
	ricochet_attempt_queued.emit(global_position, _get_ricochet_travel_direction())


func _can_queue_ricochet() -> bool:
	return (
		_play_enabled
		and not _death_sequence_active
		and not crawl_active
		and not airborne_active
		and not _conus_climb_active
		and not _leaf_sheep_active
		and _get_active_ricochet_lane() != null
		and _has_ricochet_motion()
	)


func _should_reserve_action_a_for_ricochet(input_direction: Vector2) -> bool:
	return (
		_play_enabled
		and input_direction.length_squared() > 0.0001
		and _get_active_ricochet_lane() != null
		and (
			_ricochet_queued
			or _ricochet_chain_active
			or _has_burst_coast()
		)
	)


func _update_ricochet_timers(delta: float) -> void:
	if _ricochet_bounce_cooldown_remaining > 0.0:
		_ricochet_bounce_cooldown_remaining = maxf(0.0, _ricochet_bounce_cooldown_remaining - delta)
	if _ricochet_chain_grace_remaining > 0.0:
		_ricochet_chain_grace_remaining = maxf(0.0, _ricochet_chain_grace_remaining - delta)
	if _ricochet_queued:
		_ricochet_queue_remaining = maxf(0.0, _ricochet_queue_remaining - delta)
		if _ricochet_queue_remaining <= 0.0:
			_clear_ricochet_queue()
	if _ricochet_chain_active and _get_active_ricochet_lane() == null:
		_finish_ricochet(&"lane_exit")
	elif _ricochet_chain_active and not _has_ricochet_motion():
		_finish_ricochet(&"speed_lost")


func _resolve_ricochet_wall_contacts() -> void:
	var lane: Node = _get_active_ricochet_lane()
	if lane == null:
		return
	if not _has_ricochet_motion():
		return
	if not _ricochet_queued and not _ricochet_chain_active:
		return
	if _ricochet_bounce_cooldown_remaining > 0.0:
		return

	var travel_velocity: Vector2 = _get_ricochet_travel_velocity()
	if travel_velocity.length() < ricochet_minimum_speed:
		if _ricochet_chain_active:
			_finish_ricochet(&"speed_lost")
		return

	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if not _is_valid_ricochet_collision(collision, lane, travel_velocity):
			continue
		if _ricochet_queued:
			_perform_ricochet_bounce(collision, lane, travel_velocity)
		elif _ricochet_chain_active:
			ricochet_failed.emit(collision.get_position(), collision.get_normal(), &"missing_queue")
			_finish_ricochet(&"missing_queue")
		return


func _is_valid_ricochet_collision(
		collision: KinematicCollision2D,
		lane: Node,
		travel_velocity: Vector2,
	) -> bool:
	if collision == null:
		return false
	var collider: Node = collision.get_collider() as Node
	if not is_instance_valid(collider) or collider == self:
		return false
	var normal: Vector2 = collision.get_normal()
	if normal.length_squared() <= 0.0001:
		return false
	var travel_direction: Vector2 = travel_velocity.normalized()
	var minimum_dot: float = _get_lane_float(lane, &"wall_minimum_dot", ricochet_wall_minimum_dot)
	if travel_direction.dot(normal.normalized()) > -minimum_dot:
		return false
	return _lane_allows_ricochet_surface(lane, collider)


func _lane_allows_ricochet_surface(lane: Node, surface: Node) -> bool:
	if not is_instance_valid(surface):
		return false
	if is_instance_valid(lane) and lane.has_method(&"allows_ricochet_surface"):
		return bool(lane.call(&"allows_ricochet_surface", surface))
	if surface.is_in_group(NON_RICOCHET_SURFACE_GROUP):
		return false
	if surface.is_in_group(HAZARD_SURFACE_GROUP):
		return false
	if ricochet_default_requires_surface_group:
		return surface.is_in_group(DEFAULT_RICOCHET_SURFACE_GROUP)
	return true


func _perform_ricochet_bounce(
		collision: KinematicCollision2D,
		lane: Node,
		travel_velocity: Vector2,
	) -> void:
	var normal: Vector2 = collision.get_normal().normalized()
	var new_direction: Vector2 = _calculate_ricochet_direction(normal, lane, travel_velocity)
	if new_direction.length_squared() <= 0.0001:
		ricochet_failed.emit(collision.get_position(), normal, &"bad_direction")
		_finish_ricochet(&"bad_direction")
		return

	var lane_speed: float = _get_lane_float(lane, &"bounce_speed", ricochet_bounce_speed)
	var speed_multiplier: float = _get_lane_float(lane, &"speed_multiplier", 1.0)
	var resolved_speed: float = maxf(ricochet_minimum_speed, maxf(travel_velocity.length(), lane_speed))
	resolved_speed *= maxf(0.05, speed_multiplier)

	global_position = _clamp_to_world(global_position + normal * _get_lane_float(
		lane,
		&"wall_separation",
		ricochet_wall_separation
	))

	_ricochet_queued = false
	_ricochet_queue_remaining = 0.0
	_ricochet_chain_active = true
	_ricochet_chain_grace_remaining = _get_lane_float(
		lane,
		&"post_bounce_queue_grace",
		ricochet_post_bounce_queue_grace
	)
	_ricochet_bounce_cooldown_remaining = _get_lane_float(
		lane,
		&"minimum_time_between_bounces",
		ricochet_minimum_time_between_bounces
	)
	_ricochet_chain_count += 1
	_last_ricochet_wall_id = collision.get_collider_id()

	_facing_left = new_direction.x < -0.01
	_burst_direction = new_direction
	_burst_active = true
	_burst_elapsed = 0.0
	_burst_remaining = burst_max_duration
	_burst_requires_release = false
	_pending_surface_jump = false
	_swim_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	_burst_coast_velocity = new_direction * resolved_speed
	velocity = _burst_coast_velocity

	var contact_position: Vector2 = collision.get_position()
	var incoming_direction: Vector2 = _safe_ricochet_direction(travel_velocity, -normal)
	var surface: Node = collision.get_collider() as Node

	_set_visual_rotation(_direction_rotation(new_direction, vertical_burst_angle_degrees))
	_set_animation(&"burst")
	_play_ricochet_contact_animation()
	_play_ricochet_contact_fx(contact_position, normal, incoming_direction, new_direction, surface)
	_play_burst_audio()
	_play_tail_bubble_burst()
	_trigger_camera_shake()
	ricochet_bounced.emit(contact_position, normal, new_direction, _ricochet_chain_count)


func _calculate_ricochet_direction(normal: Vector2, lane: Node, travel_velocity: Vector2) -> Vector2:
	var bias_strength: float = _get_lane_float(
		lane,
		&"vertical_bias_strength",
		ricochet_vertical_bias_strength
	)
	if absf(normal.x) >= absf(normal.y):
		var horizontal_sign: float = -1.0 if normal.x < 0.0 else 1.0
		var vertical_axis: float = Input.get_axis(&"move_up", &"move_down")
		if absf(vertical_axis) <= 0.01:
			if _ricochet_last_vertical_sign == 0.0:
				_ricochet_last_vertical_sign = -1.0 if travel_velocity.y < 0.0 else 1.0
			vertical_axis = _ricochet_last_vertical_sign
		_ricochet_last_vertical_sign = -1.0 if vertical_axis < 0.0 else 1.0
		return Vector2(horizontal_sign, _ricochet_last_vertical_sign * bias_strength).normalized()

	var vertical_sign: float = -1.0 if normal.y < 0.0 else 1.0
	var horizontal_axis: float = Input.get_axis(&"move_left", &"move_right")
	if absf(horizontal_axis) <= 0.01:
		horizontal_axis = -1.0 if travel_velocity.x < 0.0 else 1.0
	return Vector2(horizontal_axis * bias_strength, vertical_sign).normalized()


func _play_ricochet_contact_animation() -> void:
	if not is_instance_valid(_animated_sprite):
		return
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames
	if sprite_frames == null or not sprite_frames.has_animation(RICOCHET_ANIMATION):
		return
	_set_animation(RICOCHET_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.play(RICOCHET_ANIMATION)
	_ricochet_animation_remaining = 2.0 / maxf(0.1, ricochet_animation_fps)


func _update_ricochet_animation_return(delta: float) -> void:
	if _ricochet_animation_remaining <= 0.0:
		return
	_ricochet_animation_remaining = maxf(0.0, _ricochet_animation_remaining - maxf(delta, 0.0))
	if _ricochet_animation_remaining > 0.0:
		return
	if not is_instance_valid(_animated_sprite):
		return
	if _animated_sprite.animation != RICOCHET_ANIMATION:
		return
	if _burst_active or _ricochet_chain_active or _has_burst_coast():
		_set_animation(&"burst")
	else:
		_set_animation(&"swim")


func _play_ricochet_contact_fx(
		contact_position: Vector2,
		normal: Vector2,
		incoming_direction: Vector2,
		new_direction: Vector2,
		surface: Node,
	) -> void:
	if not ricochet_contact_fx_enabled:
		return
	var effect_parent: Node = get_parent()
	if effect_parent == null:
		effect_parent = get_tree().current_scene
	if effect_parent == null:
		return
	var contact_fx: Node = RICOCHET_CONTACT_FX_SCENE.instantiate()
	if contact_fx == null:
		return
	effect_parent.add_child(contact_fx)
	if contact_fx.has_method(&"play_contact"):
		contact_fx.call(
			&"play_contact",
			contact_position,
			normal,
			incoming_direction,
			new_direction,
			_get_ricochet_surface_kind(surface),
			ricochet_contact_fx_rock_tint,
			ricochet_contact_fx_intensity
		)


func _install_ricochet_animation(sprite_frames: SpriteFrames) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(RICOCHET_ANIMATION):
		sprite_frames.clear(RICOCHET_ANIMATION)
	else:
		sprite_frames.add_animation(RICOCHET_ANIMATION)
	sprite_frames.add_frame(RICOCHET_ANIMATION, RICOCHET_01)
	sprite_frames.add_frame(RICOCHET_ANIMATION, RICOCHET_02)
	sprite_frames.set_animation_speed(RICOCHET_ANIMATION, ricochet_animation_fps)
	sprite_frames.set_animation_loop(RICOCHET_ANIMATION, false)


func _get_ricochet_surface_kind(surface: Node) -> StringName:
	if is_instance_valid(surface) and surface.has_method(&"get_ricochet_surface_kind"):
		var value: Variant = surface.call(&"get_ricochet_surface_kind")
		if value is StringName:
			return value
		if value is String:
			return StringName(value)
	return &"rock"


func _safe_ricochet_direction(direction: Vector2, fallback: Vector2) -> Vector2:
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	if fallback.length_squared() > 0.0001:
		return fallback.normalized()
	return Vector2.RIGHT


func _get_ricochet_travel_velocity() -> Vector2:
	if _burst_coast_velocity.length_squared() > 1.0:
		return _burst_coast_velocity
	if _burst_active and _burst_direction.length_squared() > 0.0001:
		return _burst_direction.normalized() * burst_speed
	if velocity.length_squared() > 1.0:
		return velocity
	return _swim_velocity + _special_velocity


func _get_ricochet_travel_direction() -> Vector2:
	var travel_velocity: Vector2 = _get_ricochet_travel_velocity()
	if travel_velocity.length_squared() <= 0.0001:
		return Vector2.LEFT if _facing_left else Vector2.RIGHT
	return travel_velocity.normalized()


func _has_ricochet_motion() -> bool:
	return (
		_burst_active
		or _has_burst_coast()
		or _ricochet_chain_active
		or is_item_surge_active()
	)


func _get_active_ricochet_lane() -> Node:
	while not _ricochet_lanes.is_empty():
		var candidate: Node = _ricochet_lanes[_ricochet_lanes.size() - 1]
		if is_instance_valid(candidate):
			return candidate
		_ricochet_lanes.remove_at(_ricochet_lanes.size() - 1)
	return null


func _get_lane_float(lane: Node, property_name: StringName, fallback: float) -> float:
	if not is_instance_valid(lane):
		return fallback
	var value: Variant = lane.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _clear_ricochet_queue() -> void:
	_ricochet_queued = false
	_ricochet_queue_remaining = 0.0


func _finish_ricochet(reason: StringName) -> void:
	if not _ricochet_chain_active and not _ricochet_queued:
		return
	_clear_ricochet_queue()
	_ricochet_chain_active = false
	_ricochet_chain_grace_remaining = 0.0
	_ricochet_bounce_cooldown_remaining = 0.0
	_ricochet_chain_count = 0
	_last_ricochet_wall_id = 0
	ricochet_finished.emit(reason)


func _clear_ricochet_state(reason: StringName) -> void:
	_clear_ricochet_queue()
	_ricochet_chain_active = false
	_ricochet_chain_grace_remaining = 0.0
	_ricochet_bounce_cooldown_remaining = 0.0
	_ricochet_chain_count = 0
	_ricochet_animation_remaining = 0.0
	_last_ricochet_wall_id = 0
	if reason != &"reset":
		ricochet_finished.emit(reason)


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("ricochet_lane_count=%d" % _ricochet_lanes.size())
	lines.append("ricochet_lane_active=%s" % str(is_ricochet_lane_active()))
	lines.append("ricochet_motion=%s" % str(_has_ricochet_motion()))
	lines.append("ricochet_queued=%s" % str(_ricochet_queued))
	lines.append("ricochet_queue_remaining=%.2f" % _ricochet_queue_remaining)
	lines.append("ricochet_chain_active=%s" % str(_ricochet_chain_active))
	lines.append("ricochet_chain_count=%d" % _ricochet_chain_count)
	lines.append("ricochet_chain_grace=%.2f" % _ricochet_chain_grace_remaining)
	lines.append("ricochet_bounce_cooldown=%.2f" % _ricochet_bounce_cooldown_remaining)
	lines.append("ricochet_animation_remaining=%.2f" % _ricochet_animation_remaining)
	return lines
