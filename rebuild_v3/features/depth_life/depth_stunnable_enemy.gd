class_name CotcDepthStunnableEnemy
extends Area2D

## Shared contact damage and profile-aware stun contract for the dark-depth enemies.

signal damage_requested(hylas: Node, amount: int)
signal frozen_started()
signal frozen_finished()

@export_category("Damage")
@export_range(1, 8, 1) var damage_amount: int = 1
@export_range(0.1, 10.0, 0.1) var damage_cooldown: float = 3.0

@export_category("Stun")
@export_range(0.1, 60.0, 0.1) var freeze_duration: float = 10.0
@export_range(0.1, 60.0, 0.1) var conus_dart_stun_seconds: float = 3.5
@export var pause_animation_while_stunned: bool = true

@onready var _sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _hurt_area: Area2D = %HurtArea
@onready var _stun_audio: AudioStreamPlayer2D = %StunAudio

var _distance_active: bool = true
var _last_damage_time: float = -999.0
var _freeze_ends_at_msec: int = 0
var _frozen_visual_active: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
	_hurt_area.monitoring = true
	_hurt_area.monitorable = false


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_physics_process(_distance_active)
	monitorable = _distance_active
	_hurt_area.monitoring = _distance_active and not is_frozen()
	if _distance_active:
		_refresh_frozen_state_after_wake()
	else:
		_sprite.pause()
		_on_distance_sleep()


func receive_conch_hit(
		origin: Vector2,
		pulse_direction: Vector2,
		_distance: float,
		strength: float,
	) -> void:
	_on_conch_hit_impulse(origin, pulse_direction, strength)
	_start_or_extend_stun(freeze_duration, true)


func receive_conus_dart(_source: Node2D) -> void:
	apply_item_paralysis(conus_dart_stun_seconds)


func apply_item_paralysis(duration_seconds: float) -> void:
	_start_or_extend_stun(duration_seconds, true)


func is_frozen() -> bool:
	return Time.get_ticks_msec() < _freeze_ends_at_msec


func get_frozen_time_remaining() -> float:
	return maxf(
		0.0,
		float(_freeze_ends_at_msec - Time.get_ticks_msec()) / 1000.0,
	)


func _start_or_extend_stun(duration_seconds: float, play_audio: bool) -> void:
	var was_frozen: bool = is_frozen()
	var requested_msec: int = maxi(1, roundi(maxf(0.05, duration_seconds) * 1000.0))
	_freeze_ends_at_msec = maxi(
		_freeze_ends_at_msec,
		Time.get_ticks_msec() + requested_msec,
	)
	if not was_frozen or not _frozen_visual_active:
		_begin_frozen_state(play_audio)


func _consume_stun_frame(delta: float) -> bool:
	if is_frozen():
		if not _frozen_visual_active:
			_begin_frozen_state(false)
		_on_stunned_physics(delta)
		return true
	if _frozen_visual_active:
		_finish_frozen_state()
	return false


func _begin_frozen_state(play_audio: bool) -> void:
	_frozen_visual_active = true
	_hurt_area.monitoring = false
	if pause_animation_while_stunned:
		_sprite.pause()
	_on_stun_started()
	if play_audio and _stun_audio.stream != null:
		_stun_audio.stop()
		_stun_audio.play()
	frozen_started.emit()


func _finish_frozen_state() -> void:
	if not _frozen_visual_active:
		return
	_freeze_ends_at_msec = 0
	_frozen_visual_active = false
	_hurt_area.monitoring = _distance_active
	_on_stun_finished()
	frozen_finished.emit()


func _refresh_frozen_state_after_wake() -> void:
	if is_frozen():
		_frozen_visual_active = true
		_hurt_area.monitoring = false
		if pause_animation_while_stunned:
			_sprite.pause()
		_on_stun_started()
		return
	if _frozen_visual_active:
		_finish_frozen_state()
	else:
		_hurt_area.monitoring = true
		_on_distance_wake()


func _damage_touching_hylas_if_needed() -> void:
	if _frozen_visual_active or not _hurt_area.monitoring:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	for body: Node2D in _hurt_area.get_overlapping_bodies():
		if not body.is_in_group(&"hylas"):
			continue
		if (
				body.has_method(&"is_camouflage_active")
				and bool(body.call(&"is_camouflage_active"))
			):
			continue
		_last_damage_time = now
		damage_requested.emit(body, damage_amount)
		return


func _on_conch_hit_impulse(
		_origin: Vector2,
		_pulse_direction: Vector2,
		_strength: float,
	) -> void:
	pass


func _on_stun_started() -> void:
	pass


func _on_stunned_physics(_delta: float) -> void:
	pass


func _on_stun_finished() -> void:
	pass


func _on_distance_sleep() -> void:
	pass


func _on_distance_wake() -> void:
	pass
