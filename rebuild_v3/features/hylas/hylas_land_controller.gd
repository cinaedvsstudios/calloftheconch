extends "res://rebuild_v3/features/hylas/hylas_motion_presentation.gd"

@export var crawl_speed := 170.0
@export var crawl_water_reentry_depth := 36.0
@onready var splash: AudioStreamPlayer = %SplashAudio
var crawl_active := false
var entry_splash_done := false

func _physics_process(delta: float) -> void:
	if crawl_active:
		crawl_update(delta)
		return
	super._physics_process(delta)

func _begin_surface_jump() -> void:
	crawl_active = false
	entry_splash_done = false
	super._begin_surface_jump()
	play_splash()

func _update_surface_jump(delta: float) -> void:
	_jump_elapsed += delta
	var p := clampf(_jump_elapsed / maxf(0.01, jump_duration), 0.0, 1.0)
	var b := _jump_start.lerp(_jump_end, p)
	var next := Vector2(b.x, b.y - sin(p * PI) * jump_arc_height)
	var above := global_position.y < _swim_ceiling_y
	if next.y > global_position.y:
		if move_and_collide(next - global_position) != null:
			begin_crawl()
			return
	else:
		global_position = next
	if not entry_splash_done and above and global_position.y >= _swim_ceiling_y:
		entry_splash_done = true
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
		play_splash()
	if p >= 1.0:
		_jump_elapsed = 0.0
		global_position = _clamp_to_world(_jump_end)
		_set_animation(&"idle")

func begin_crawl() -> void:
	crawl_active = true
	_jump_elapsed = 0.0
	_pending_surface_jump = false
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	global_position = _clamp_to_world(global_position)
	_set_animation(&"crawl")
	_stop_movement_audio()

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

func _clamp_to_world(value: Vector2) -> Vector2:
	var min_y := _world_bounds.position.y + player_edge_padding
	if _jump_elapsed <= 0.0 and not crawl_active:
		min_y = maxf(min_y, _swim_ceiling_y)
	return Vector2(clampf(value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding), clampf(value.y, min_y, _world_bounds.end.y - player_edge_padding))

func play_splash() -> void:
	if splash.stream != null:
		splash.stop()
		splash.play()
