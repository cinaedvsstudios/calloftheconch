extends "res://scenes/characters/Hylas/hylas_phase6_fix.gd"

## Final Hylas layer for the death sequence. Both visual frame resources receive
## the same death animations, and the legacy level callback is delayed until the
## body has actually landed so the death menu cannot cover the descent.

const NORMAL_DEATH_FRAMES: SpriteFrames = preload(
	"res://scenes/characters/Hylas/hylas_v3_sprite_frames.tres"
)
const GREATFIN_DEATH_FRAMES: SpriteFrames = preload(
	"res://scenes/characters/Hylas/hylas_greatfin_sprite_frames.tres"
)

var _landing_notification_sent: bool = false


func start_death_sequence() -> void:
	_configure_death_animations()
	_landing_notification_sent = false
	super.start_death_sequence()
	if _death_sequence_active:
		_animated_sprite.frame = 0
		_animated_sprite.play(DEATH_INTRO_ANIMATION)


func reset_to_start(start_position: Vector2) -> void:
	_landing_notification_sent = false
	super.reset_to_start(start_position)


func cancel_death_sequence() -> void:
	_landing_notification_sent = false
	super.cancel_death_sequence()


func _configure_death_animations() -> void:
	_configure_death_frames(NORMAL_DEATH_FRAMES)
	_configure_death_frames(GREATFIN_DEATH_FRAMES)


func _configure_death_frames(sprite_frames: SpriteFrames) -> void:
	if sprite_frames == null:
		return
	if sprite_frames.has_animation(DEATH_INTRO_ANIMATION):
		sprite_frames.remove_animation(DEATH_INTRO_ANIMATION)
	if sprite_frames.has_animation(DEATH_DRIFT_ANIMATION):
		sprite_frames.remove_animation(DEATH_DRIFT_ANIMATION)

	sprite_frames.add_animation(DEATH_INTRO_ANIMATION)
	for texture: Texture2D in [DIE_01, DIE_02, DIE_03, DIE_04, DIE_05, DIE_06]:
		sprite_frames.add_frame(DEATH_INTRO_ANIMATION, texture)
	sprite_frames.set_animation_speed(DEATH_INTRO_ANIMATION, death_intro_fps)
	sprite_frames.set_animation_loop(DEATH_INTRO_ANIMATION, false)

	sprite_frames.add_animation(DEATH_DRIFT_ANIMATION)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_07)
	sprite_frames.add_frame(DEATH_DRIFT_ANIMATION, DIE_08)
	sprite_frames.set_animation_speed(DEATH_DRIFT_ANIMATION, death_drift_fps)
	sprite_frames.set_animation_loop(DEATH_DRIFT_ANIMATION, true)


func _on_animation_finished() -> void:
	if not _death_sequence_active or _animated_sprite.animation != DEATH_INTRO_ANIMATION:
		return
	_death_drift_active = true
	_set_animation(DEATH_DRIFT_ANIMATION)
	_animated_sprite.frame = 0
	_animated_sprite.play(DEATH_DRIFT_ANIMATION)


func _update_death_sequence(delta: float) -> void:
	var was_landed: bool = _death_body_landed
	super._update_death_sequence(delta)
	if was_landed or not _death_body_landed or _landing_notification_sent:
		return
	_landing_notification_sent = true
	# SeaOfPillars still consumes this compatibility signal. It now occurs only
	# after the inherited update emitted death_landed.
	death_drift_started.emit()


func get_debug_lines() -> Array[String]:
	var lines: Array[String] = super.get_debug_lines()
	lines.append("death_frames_normal=%s" % str(NORMAL_DEATH_FRAMES.has_animation(DEATH_INTRO_ANIMATION)))
	lines.append("death_frames_greatfin=%s" % str(GREATFIN_DEATH_FRAMES.has_animation(DEATH_INTRO_ANIMATION)))
	lines.append("death_landing_notified=%s" % str(_landing_notification_sent))
	return lines
