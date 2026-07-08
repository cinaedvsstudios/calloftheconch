extends "res://rebuild_v3/features/hylas/hylas_motion_presentation.gd"

@export_category("Land Movement")
@export var land_gravity := 5800.0
@export var jump_horizontal_speed := 720.0
@export var jump_launch_upward_speed := 1665.0
@export var crawl_speed := 170.0
@export var crawl_water_reentry_depth := 36.0

@onready var splash: AudioStreamPlayer = %SplashAudio
@onready var hurt_audio: AudioStreamPlayer = %HurtAudio
@onready var land_impact_audio: AudioStreamPlayer = %LandImpactAudio

var crawl_active := false
var airborne_active := false
var left_water := false
var entry_splash_done := false


func _ready() -> void:
	super._ready()
	splash.process_mode = Node.PROCESS_MODE_ALWAYS
	hurt_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	land_impact_audio.process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if crawl_active:
		crawl_update(delta)
		return
	if airborne_active:
		airborne_update(delta)
		return
	super._physics_process(delta)


func _begin_surface_jump() -> void:
	crawl_active = false
	airborne_active = true
	left_water = false
	entry_splash_done = false
	super._begin_surface_jump()
	var facing_sign := -1.0 if _facing_left else 1.0
	velocity = Vector2(facing_sign * jump_horizontal_speed, -jump_launch_upward_speed)
	play_splash()


func airborne_update(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()
	_jump_elapsed += delta
	velocity.y += land_gravity * delta
	var was_descending := velocity.y > 0.0
	move_and_slide()
	global_position = clamp_airborne_position(global_position)

	if global_position.y < _swim_ceiling_y:
		left_water = true
	if was_descending and _has_ground_collision():
		begin_crawl()
		return
	if left_water and velocity.y > 0.0 and global_position.y >= _swim_ceiling_y:
		enter_water()


func _has_ground_collision() -> bool:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision != null and collision.get_normal().y < -0.2:
			return true
	return false


func begin_crawl() -> void:
	airborne_active = false
	crawl_active = true
	_jump_elapsed = 0.0
	_pending_surface_jump = false
	_swim_velocity = Vector2.ZERO
	_burst_coast_velocity = Vector2.ZERO
	_special_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_set_visual_rotation(0.0)
	_set_animation(&"crawl")
	_stop_movement_audio()
	play_hurt_sound()
	play_land_impact_sound()


func enter_water() -> void:
	airborne_active = false
	_jump_elapsed = 0.0
	velocity = Vector2.ZERO
	global_position.y = _swim_ceiling_y + crawl_water_reentry_depth
	if not entry_splash_done:
		entry_splash_done = true
		surface_splash_requested.emit(Vector2(global_position.x, _swim_ceiling_y), false)
		play_splash()
	_set_visual_rotation(0.0)
	_set_animation(&"idle")


func crawl_update(delta: float) -> void:
	if not _play_enabled:
		return
	_current_time += delta
	_update_cooldowns(delta)
	_update_camera_shake(delta)
	_update_shadow()
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var floor_normal := get_floor_normal()
	var ground_tangent := Vector2(-floor_normal.y, floor_normal.x)
	var crawl_axis := direction.dot(ground_tangent)
	if absf(crawl_axis) > 0.01:
		_facing_left = crawl_axis < 0.0
	velocity = ground_tangent * crawl_axis * crawl_speed
	velocity.y += land_gravity * delta
	_set_visual_rotation(0.0)
	_stop_movement_audio()
	_set_animation(&"crawl")
	if absf(crawl_axis) <= 0.01:
		_animated_sprite.frame = 0
		_animated_sprite.pause()
	else:
		_animated_sprite.play()
	move_and_slide()
	global_position = _clamp_to_world(global_position)
	if not is_on_floor():
		crawl_active = false
		airborne_active = true
		_set_animation(&"jump")
		_animated_sprite.frame = _animated_sprite.sprite_frames.get_frame_count(&"jump") - 1
		_animated_sprite.pause()
		return
	if global_position.y >= _swim_ceiling_y + crawl_water_reentry_depth:
		crawl_active = false
		velocity = Vector2.ZERO
		_set_animation(&"idle")


func clamp_airborne_position(value: Vector2) -> Vector2:
	return Vector2(
		clampf(value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding),
		clampf(value.y, _world_bounds.position.y + player_edge_padding, _world_bounds.end.y - player_edge_padding),
	)


func _clamp_to_world(value: Vector2) -> Vector2:
	var minimum_y := _world_bounds.position.y + player_edge_padding
	if not crawl_active and not airborne_active and _jump_elapsed <= 0.0:
		minimum_y = maxf(minimum_y, _swim_ceiling_y)
	return Vector2(
		clampf(value.x, _world_bounds.position.x + player_edge_padding, _world_bounds.end.x - player_edge_padding),
		clampf(value.y, minimum_y, _world_bounds.end.y - player_edge_padding),
	)


func play_splash() -> void:
	if splash.stream != null:
		splash.stop()
		splash.play()


func play_hurt_sound() -> void:
	if hurt_audio.stream != null:
		hurt_audio.stop()
		hurt_audio.play()


func play_land_impact_sound() -> void:
	if land_impact_audio.stream != null:
		land_impact_audio.stop()
		land_impact_audio.play()
