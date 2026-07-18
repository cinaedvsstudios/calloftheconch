extends "res://scenes/characters/Hylas/hylas.gd"

## Presentation-only control for the timing-sensitive Hylas actions.
## Gameplay movement remains in the inherited CotcHylas script.

signal tail_flip_impact(contact_position: Vector2, normal: Vector2, target: Node)

@export_category("Action Gameplay Timing")
@export_range(0.10, 10.0, 0.01) var speed_run_gameplay_duration: float = 1.50
@export_range(0.10, 5.0, 0.01) var tail_flip_gameplay_duration: float = 1.00
@export_range(0.10, 5.0, 0.01) var conch_gameplay_duration: float = 0.5555556

@export_category("Animation Speeds")
@export_range(0.1, 60.0, 0.1) var idle_animation_fps: float = 2.0
@export_range(0.1, 60.0, 0.1) var tail_flip_animation_fps: float = 10.0
@export_range(0.1, 60.0, 0.1) var conch_animation_fps: float = 18.0
@export_range(0.1, 60.0, 0.1) var stop_animation_fps: float = 9.0

@export_category("Speed Run Animation Timing")
@export_range(0.01, 2.0, 0.01) var speed_run_startup_frame_duration: float = 0.10
@export_range(0.01, 10.0, 0.01) var speed_run_hold_start: float = 0.20
@export_range(0.01, 10.0, 0.01) var speed_run_hold_end: float = 1.20
@export_range(0.01, 2.0, 0.01) var speed_run_finish_frame_duration: float = 0.10

@export_category("Collision Profiles")
@export var default_collision_shape: Shape2D
@export var tail_flip_collision_shape: Shape2D
@export var conch_collision_shape: Shape2D
@export var stop_collision_shape: Shape2D

@export_category("Conch Steering")
@export_range(10.0, 180.0, 1.0) var conch_steer_speed_degrees: float = 90.0

var _stop_pose_held: bool = false
var _collision_profile_name: StringName = &"default"
var _tail_flip_impact_target_ids: Dictionary = {}


func _ready() -> void:
	burst_max_duration = speed_run_gameplay_duration
	tail_flip_duration = tail_flip_gameplay_duration
	conch_duration = conch_gameplay_duration
	super._ready()
	_configure_action_animations()
	_animated_sprite.sprite_frames.set_animation_speed(&"idle", idle_animation_fps)
	_apply_collision_profile(_animated_sprite.animation)


func _configure_action_animations() -> void:
	# Use a local copy so rebuilding Hylas's action animations does not modify
	# any other scene that happens to reference the shared SpriteFrames resource.
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
	_animated_sprite.sprite_frames = sprite_frames

	var flip_01: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 0)
	var flip_02: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 1)
	var flip_03: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 2)
	var flip_04: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 3)
	var flip_05: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 4)
	var flip_06: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 5)
	var flip_07: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 6)
	var stop_01: Texture2D = sprite_frames.get_frame_texture(&"stop", 0)
	var stop_02: Texture2D = sprite_frames.get_frame_texture(&"stop", 1)
	var stop_03: Texture2D = sprite_frames.get_frame_texture(&"stop", 2)
	var stop_04: Texture2D = sprite_frames.get_frame_texture(&"stop", 3)
	var stop_05: Texture2D = sprite_frames.get_frame_texture(&"stop", 4)
	var stop_06: Texture2D = sprite_frames.get_frame_texture(&"stop", 5)
	var stop_07: Texture2D = sprite_frames.get_frame_texture(&"stop_release", 0)

	var tail_flip_sequence: Array[Texture2D] = [
		flip_01,
		flip_02,
		flip_03,
		flip_04,
		flip_05,
		flip_06,
		flip_07,
		flip_02,
		flip_01,
		stop_06,
	]
	if not _replace_animation_frames(
			sprite_frames,
			&"tail_flip",
			tail_flip_sequence,
			tail_flip_animation_fps,
		):
		return

	var conch_01: Texture2D = sprite_frames.get_frame_texture(&"conch", 0)
	var conch_02: Texture2D = sprite_frames.get_frame_texture(&"conch", 1)
	var conch_03: Texture2D = sprite_frames.get_frame_texture(&"conch", 2)
	var conch_04: Texture2D = sprite_frames.get_frame_texture(&"conch", 3)
	var conch_05: Texture2D = sprite_frames.get_frame_texture(&"conch", 4)
	var conch_06: Texture2D = sprite_frames.get_frame_texture(&"conch", 5)

	var conch_sequence: Array[Texture2D] = [
		stop_07,
		stop_06,
		conch_01,
		conch_02,
		conch_03,
		conch_04,
		conch_05,
		conch_06,
		stop_06,
		stop_07,
	]
	if not _replace_animation_frames(
			sprite_frames,
			&"conch",
			conch_sequence,
			conch_animation_fps,
		):
		return

	var stop_sequence: Array[Texture2D] = [
		stop_07,
		stop_06,
		stop_01,
		stop_02,
		stop_03,
		stop_04,
		stop_05,
		stop_06,
	]
	_replace_animation_frames(
		sprite_frames,
		&"stop",
		stop_sequence,
		stop_animation_fps,
	)


func _replace_animation_frames(
		sprite_frames: SpriteFrames,
		animation_name: StringName,
		sequence: Array[Texture2D],
		animation_fps: float,
	) -> bool:
	for texture: Texture2D in sequence:
		if texture == null:
			push_error("%s animation is missing a required source frame." % animation_name)
			return false

	sprite_frames.clear(animation_name)
	for texture: Texture2D in sequence:
		sprite_frames.add_frame(animation_name, texture, 1.0)
	sprite_frames.set_animation_loop(animation_name, false)
	sprite_frames.set_animation_speed(animation_name, animation_fps)
	return true


func _physics_process(delta: float) -> void:
	var tail_flip_was_active: bool = (
		_tail_flip_remaining > 0.0
		and _animated_sprite.animation == &"tail_flip"
	)
	super._physics_process(delta)
	var tail_flip_is_active: bool = (
		_tail_flip_remaining > 0.0
		and _animated_sprite.animation == &"tail_flip"
	)
	_apply_collision_profile(_animated_sprite.animation)
	if tail_flip_was_active or tail_flip_is_active:
		_report_tail_flip_slide_impacts()
	_update_stop_pose_hold()
	_update_burst_presentation()


func _start_tail_flip() -> void:
	_tail_flip_impact_target_ids.clear()
	super._start_tail_flip()


func report_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	if _tail_flip_remaining <= 0.0 or _animated_sprite.animation != &"tail_flip":
		return
	_emit_tail_flip_impact(contact_position, normal, target)


func _report_tail_flip_slide_impacts() -> void:
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var target: Node = collision.get_collider() as Node
		if target == null:
			continue
		_emit_tail_flip_impact(
			collision.get_position(),
			collision.get_normal(),
			target,
		)

	if _collision_shape.shape == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _collision_shape.shape
	query.transform = _collision_shape.global_transform
	query.motion = Vector2.ZERO
	query.margin = 4.0
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var rest_info: Dictionary = get_world_2d().direct_space_state.get_rest_info(query)
	if rest_info.is_empty():
		return
	var resting_target: Node = rest_info.get("collider") as Node
	if resting_target == null:
		return
	var contact_position: Vector2 = rest_info.get("point", global_position)
	var contact_normal: Vector2 = rest_info.get("normal", -_tail_flip_direction)
	_emit_tail_flip_impact(contact_position, contact_normal, resting_target)


func _emit_tail_flip_impact(
		contact_position: Vector2,
		normal: Vector2,
		target: Node,
	) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if _tail_flip_impact_target_ids.has(target_id):
		return
	_tail_flip_impact_target_ids[target_id] = true
	var impact_normal: Vector2 = normal.normalized()
	if impact_normal.length_squared() <= 0.0001:
		impact_normal = -_tail_flip_direction
	tail_flip_impact.emit(contact_position, impact_normal, target)


func _update_conch(delta: float) -> void:
	_conch_remaining = maxf(0.0, _conch_remaining - delta)
	_special_velocity = _special_velocity.move_toward(
		Vector2.ZERO,
		idle_momentum_deceleration * delta,
	)

	var vertical_input: float = Input.get_axis(&"move_up", &"move_down")
	if absf(vertical_input) > 0.01:
		var vertical_axis: float = -1.0 if vertical_input < 0.0 else 1.0
		var facing_axis: float = -1.0 if _facing_left else 1.0
		var target_rotation: float = (
			vertical_axis
			* facing_axis
			* deg_to_rad(conch_direction_angle_degrees)
		)
		var rotation_step: float = deg_to_rad(conch_steer_speed_degrees) * delta
		_set_visual_rotation(move_toward(_visual_rotation, target_rotation, rotation_step))

	if _conch_remaining <= 0.0:
		_set_visual_rotation(0.0)
		_set_animation(&"idle")


func _set_animation(animation_name: StringName) -> void:
	super._set_animation(animation_name)
	_apply_collision_profile(animation_name)


func _apply_collision_profile(animation_name: StringName) -> void:
	var target_shape: Shape2D = default_collision_shape
	var target_profile: StringName = &"default"

	if animation_name == &"tail_flip":
		target_shape = tail_flip_collision_shape
		target_profile = &"tail_flip"
	elif animation_name == &"conch":
		target_shape = conch_collision_shape
		target_profile = &"conch"
	elif animation_name == &"stop" or animation_name == &"stop_release":
		target_shape = stop_collision_shape
		target_profile = &"stop"

	if target_shape == null:
		return
	if _collision_shape.shape != target_shape:
		_collision_shape.shape = target_shape
	_collision_profile_name = target_profile


func _update_stop_pose_hold() -> void:
	# Shift can remain held while another action starts. Never let the retained
	# stop pose overwrite an active Tail Flip, conch, burst, or jump animation.
	if _tail_flip_remaining > 0.0 or _conch_remaining > 0.0 or _burst_active or _jump_elapsed > 0.0:
		_stop_pose_held = false
		return

	if _animated_sprite.animation == &"stop":
		_stop_pose_held = true
	if not Input.is_action_pressed(&"action_a"):
		_stop_pose_held = false
		return
	if not _stop_pose_held:
		return

	var last_stop_frame: int = _animated_sprite.sprite_frames.get_frame_count(&"stop") - 1
	if _animated_sprite.animation != &"stop":
		_animated_sprite.animation = &"stop"
		_animated_sprite.frame = last_stop_frame
		_animated_sprite.pause()
		return
	if _animated_sprite.frame >= last_stop_frame:
		_animated_sprite.frame = last_stop_frame
		_animated_sprite.pause()


func _update_burst_presentation() -> void:
	if not _burst_active or _animated_sprite.animation != &"burst":
		return

	var burst_frame: int = 0
	if _burst_elapsed < speed_run_startup_frame_duration:
		burst_frame = 0 # hylas-speed_02.webp
	elif _burst_elapsed < speed_run_hold_start:
		burst_frame = 1 # hylas-speed_03.webp
	elif _burst_elapsed < speed_run_hold_end:
		burst_frame = 2 # hylas-speed_04.webp
	else:
		var finish_elapsed: float = _burst_elapsed - speed_run_hold_end
		var finish_step: int = floori(finish_elapsed / maxf(0.01, speed_run_finish_frame_duration))
		burst_frame = 3 + (finish_step % 2) # Alternates hylas-speed_05 and _06.

	_animated_sprite.frame = burst_frame
	_animated_sprite.pause()
