extends "res://scenes/characters/Hylas/hylas_item_visuals.gd"

const NORMAL_IDLE_ANIMATION: StringName = &"idle"
# Two successive 15% increases: 1.15 * 1.15 = 1.3225.
const NORMAL_IDLE_SCALE_MULTIPLIER: float = 1.3225

var _normal_idle_scale_applied: bool = false


func _process(delta: float) -> void:
	_sync_normal_idle_scale()
	super._process(delta)


func set_greatfin_active(is_active: bool) -> void:
	_remove_normal_idle_scale()
	super.set_greatfin_active(is_active)
	_sync_normal_idle_scale()


func _sync_normal_idle_scale() -> void:
	if not is_instance_valid(_animated_sprite):
		return
	var should_enlarge: bool = (
		not _greatfin_active
		and _animated_sprite.sprite_frames == NORMAL_FRAMES
		and _animated_sprite.animation == NORMAL_IDLE_ANIMATION
	)
	if should_enlarge and not _normal_idle_scale_applied:
		_animated_sprite.scale *= NORMAL_IDLE_SCALE_MULTIPLIER
		_normal_idle_scale_applied = true
	elif not should_enlarge and _normal_idle_scale_applied:
		_remove_normal_idle_scale()


func _remove_normal_idle_scale() -> void:
	if not _normal_idle_scale_applied or not is_instance_valid(_animated_sprite):
		return
	_animated_sprite.scale /= NORMAL_IDLE_SCALE_MULTIPLIER
	_normal_idle_scale_applied = false
