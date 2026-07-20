extends AnimatedSprite2D

## Displays the one-frame stop release pose before Hylas returns to idle.

const STOP_RELEASE_DURATION: float = 0.12

var _shift_was_held: bool = false
var _stop_was_active: bool = false
var _release_remaining: float = 0.0


func _ready() -> void:
	# Hylas replaces this node's SpriteFrames during the parent's ready sequence.
	# Waiting until that setup is complete prevents the initial idle loop from
	# being reset to frame 0 before gameplay begins.
	call_deferred(&"_start_initial_idle")


func _start_initial_idle() -> void:
	if animation == &"idle":
		play(&"idle")


func _process(delta: float) -> void:
	var shift_is_held: bool = Input.is_action_pressed(&"action_a")

	if animation == &"stop" and shift_is_held:
		_stop_was_active = true
	elif animation != &"stop":
		# Another action replaced the stop pose. Releasing Shift after Tail Flip,
		# conch, burst, jump, swim, or idle must not trigger stop_release.
		_stop_was_active = false

	if _shift_was_held and not shift_is_held and _stop_was_active:
		_stop_was_active = false
		_release_remaining = STOP_RELEASE_DURATION
		_play_release_frame()

	if _release_remaining > 0.0:
		_release_remaining = maxf(0.0, _release_remaining - delta)
		_play_release_frame()
		if _release_remaining <= 0.0:
			play(&"idle")

	_shift_was_held = shift_is_held


func _play_release_frame() -> void:
	animation = &"stop_release"
	frame = 0
	pause()
