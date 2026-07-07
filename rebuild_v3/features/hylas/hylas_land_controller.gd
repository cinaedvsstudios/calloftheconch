extends "res://rebuild_v3/features/hylas/hylas_motion_presentation.gd"

@export var crawl_speed := 170.0
@export var crawl_water_reentry_depth := 36.0

var crawl_active := false


func _physics_process(delta: float) -> void:
	if crawl_active:
		crawl_update(delta)
		return
	super._physics_process(delta)


func crawl_update(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if absf(direction.x) > 0.01:
		_facing_left = direction.x < 0.0
	_set_visual_rotation(0.0)
	_stop_movement_audio()
	_set_animation(&"crawl")
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		_animated_sprite.frame = 0
		_animated_sprite.pause()
	else:
		velocity = direction.normalized() * crawl_speed
		_animated_sprite.play()
		move_and_slide()
		global_position = _clamp_to_world(global_position)
	if global_position.y >= _swim_ceiling_y + crawl_water_reentry_depth:
		crawl_active = false
		velocity = Vector2.ZERO
		_set_animation(&"idle")
