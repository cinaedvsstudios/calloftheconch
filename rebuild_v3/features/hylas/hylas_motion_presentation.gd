extends "res://rebuild_v3/features/hylas/hylas.gd"

## Presentation-only control for the two timing-sensitive Hylas actions.
## Gameplay movement remains in the inherited CotcHylas script.

const BURST_DURATION: float = 1.50
const BURST_STARTUP_FRAME_DURATION: float = 0.10
const BURST_HOLD_START: float = 0.20
const BURST_HOLD_END: float = 1.20
const BURST_FINISH_FRAME_DURATION: float = 0.10
const IDLE_ANIMATION_FPS: float = 2.50

@export_category("Collision Profiles")
@export var default_collision_shape: Shape2D
@export var tail_flip_collision_shape: Shape2D
@export var conch_collision_shape: Shape2D
@export var stop_collision_shape: Shape2D

var _stop_pose_held: bool = false
var _collision_profile_name: StringName = &"default"


func _ready() -> void:
	burst_max_duration = BURST_DURATION
	super._ready()
	_animated_sprite.sprite_frames.set_animation_speed(&"idle", IDLE_ANIMATION_FPS)
	_apply_collision_profile(_animated_sprite.animation)


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
