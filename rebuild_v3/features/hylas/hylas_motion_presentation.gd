extends "res://rebuild_v3/features/hylas/hylas.gd"

## Presentation-only control for the timing-sensitive Hylas actions.
## Gameplay movement remains in the inherited CotcHylas script.

const BURST_DURATION: float = 1.50
const BURST_STARTUP_FRAME_DURATION: float = 0.10
const BURST_HOLD_START: float = 0.20
const BURST_HOLD_END: float = 1.20
const BURST_FINISH_FRAME_DURATION: float = 0.10
const IDLE_ANIMATION_FPS: float = 2.50
const TAIL_FLIP_ANIMATION_FPS: float = 10.0
const TAIL_FLIP_GAMEPLAY_DURATION: float = 1.0

@export_category("Collision Profiles")
@export var default_collision_shape: Shape2D
@export var tail_flip_collision_shape: Shape2D
@export var conch_collision_shape: Shape2D
@export var stop_collision_shape: Shape2D

var _stop_pose_held: bool = false
var _collision_profile_name: StringName = &"default"


func _ready() -> void:
	burst_max_duration = BURST_DURATION
	tail_flip_duration = TAIL_FLIP_GAMEPLAY_DURATION
	super._ready()
	_configure_tail_flip_animation()
	_animated_sprite.sprite_frames.set_animation_speed(&"idle", IDLE_ANIMATION_FPS)
	_apply_collision_profile(_animated_sprite.animation)


func _configure_tail_flip_animation() -> void:
	# Use a local copy so rebuilding Hylas's Tail Flip does not modify any other
	# scene that happens to reference the shared SpriteFrames resource.
	var sprite_frames: SpriteFrames = _animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
	_animated_sprite.sprite_frames = sprite_frames

	var flip_01: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 0)
	var flip_02: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 1)
	var flip_03: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 2)
	var flip_04: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 3)
	var flip_05: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 4)
	var flip_06: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 5)
	var flip_07: Texture2D = sprite_frames.get_frame_texture(&"tail_flip", 6)
	var stop_06: Texture2D = sprite_frames.get_frame_texture(&"stop", 5)

	var sequence: Array[Texture2D] = [
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
	for texture: Texture2D in sequence:
		if texture == null:
			push_error("Tail Flip animation is missing a required source frame.")
			return

	sprite_frames.clear(&"tail_flip")
	for texture: Texture2D in sequence:
		sprite_frames.add_frame(&"tail_flip", texture, 1.0)
	sprite_frames.set_animation_loop(&"tail_flip", false)
	sprite_frames.set_animation_speed(&"tail_flip", TAIL_FLIP_ANIMATION_FPS)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_stop_pose_hold()
	_update_burst_presentation()
	_apply_collision_profile(_animated_sprite.animation)


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
	if _burst_elapsed < BURST_STARTUP_FRAME_DURATION:
		burst_frame = 0 # hylas-speed_02.webp
	elif _burst_elapsed < BURST_HOLD_START:
		burst_frame = 1 # hylas-speed_03.webp
	elif _burst_elapsed < BURST_HOLD_END:
		burst_frame = 2 # hylas-speed_04.webp
	else:
		var finish_elapsed: float = _burst_elapsed - BURST_HOLD_END
		var finish_step: int = floori(finish_elapsed / BURST_FINISH_FRAME_DURATION)
		burst_frame = 3 + (finish_step % 2) # Alternates hylas-speed_05 and _06.

	_animated_sprite.frame = burst_frame
	_animated_sprite.pause()
