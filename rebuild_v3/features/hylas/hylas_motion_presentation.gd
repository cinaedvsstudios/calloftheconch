extends "res://rebuild_v3/features/hylas/hylas.gd"

## Presentation-only control for the two timing-sensitive Hylas actions.
## Gameplay movement remains in the inherited CotcHylas script.

const BURST_DURATION: float = 1.50
const BURST_STARTUP_FRAME_DURATION: float = 0.10
const BURST_HOLD_START: float = 0.20
const BURST_HOLD_END: float = 1.20
const BURST_FINISH_FRAME_DURATION: float = 0.10

var _stop_pose_held: bool = false


func _ready() -> void:
	burst_max_duration = BURST_DURATION
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_stop_pose_hold()
	_update_burst_presentation()


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
