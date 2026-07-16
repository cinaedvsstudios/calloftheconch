class_name CotcBlackBloomHazard
extends Node2D

signal damage_requested(hylas: Node, amount: int)
signal stun_started
signal stun_finished

@export_category("Wake Range")
@export var wake_distance: float = 560.0
@export var sleep_distance: float = 780.0

@export_category("Damage")
@export var damage_amount: int = 1
@export var damage_cooldown: float = 1.0

@export_category("Conch Stun")
@export_range(0.1, 20.0, 0.1) var stun_duration: float = 10.0
@export var stun_tint: Color = Color(0.35, 0.78, 1.0, 1.0)

@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _wake_area: Area2D = %WakeArea
@onready var _hurt_area: Area2D = %HurtArea
@onready var _wake_bubble_burst: CotcBubbleBurst = %WakeBubbleBurst
@onready var _conch_target: Node2D = %ConchTarget
@onready var _stun_audio: AudioStreamPlayer2D = %StunAudio

var _hylas: Node2D
var _awake: bool = false
var _last_damage_time: float = -999.0
var _distance_active: bool = true
var _stun_ends_at_msec: int = 0
var _stun_visual_active: bool = false


func _ready() -> void:
	_animated_sprite.animation_finished.connect(_on_animation_finished)
	_wake_area.body_entered.connect(_on_wake_area_body_entered)
	_hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	_wake_area.monitoring = true
	_hurt_area.monitoring = true
	set_process(true)
	_go_to_sleep()
	_connect_to_level_conch_signal()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_process(_distance_active)
	_wake_area.monitoring = _distance_active
	_hurt_area.monitoring = _distance_active and not is_stunned()
	if _distance_active:
		if is_stunned():
			_begin_stun(false)
		elif _stun_visual_active:
			_finish_stun()
		return
	_wake_bubble_burst.stop_burst()
	_go_to_sleep()
	_hylas = null


func _process(_delta: float) -> void:
	if is_stunned():
		if not _stun_visual_active:
			_begin_stun(false)
		return
	if _stun_visual_active:
		_finish_stun()

	_resolve_hylas()
	if not _is_hylas_targetable():
		if _awake:
			_go_to_sleep()
		return

	var distance_to_hylas: float = global_position.distance_to(_hylas.global_position)
	if not _awake and distance_to_hylas <= wake_distance:
		_wake_up()
	elif _awake and distance_to_hylas >= sleep_distance:
		_go_to_sleep()

	if _awake:
		_damage_touching_hylas_if_needed()


func receive_conch_hit(
		_origin: Vector2,
		_pulse_direction: Vector2,
		_distance: float,
		_strength: float,
	) -> void:
	var was_already_stunned: bool = is_stunned()
	_stun_ends_at_msec = Time.get_ticks_msec() + int(round(stun_duration * 1000.0))
	if not was_already_stunned or not _stun_visual_active:
		_begin_stun(not was_already_stunned)


func receive_conus_dart(_source: Node2D) -> void:
	receive_conch_hit(global_position, Vector2.ZERO, 0.0, 1.0)


func is_stunned() -> bool:
	return Time.get_ticks_msec() < _stun_ends_at_msec


func get_stun_time_remaining() -> float:
	return maxf(
		0.0,
		float(_stun_ends_at_msec - Time.get_ticks_msec()) / 1000.0,
	)


func _begin_stun(play_audio: bool) -> void:
	_stun_visual_active = true
	_wake_bubble_burst.stop_burst()
	_animated_sprite.pause()
	_hurt_area.monitoring = false
	_animated_sprite.modulate = stun_tint
	if play_audio and _stun_audio.stream != null:
		_stun_audio.stop()
		_stun_audio.play()
		stun_started.emit()


func _finish_stun() -> void:
	if not _stun_visual_active:
		return
	_stun_ends_at_msec = 0
	_stun_visual_active = false
	_animated_sprite.modulate = Color.WHITE
	if not _distance_active:
		_animated_sprite.pause()
		return
	_hurt_area.monitoring = true
	_resolve_hylas()
	if is_instance_valid(_hylas) and global_position.distance_to(_hylas.global_position) <= wake_distance:
		_awake = true
		_animated_sprite.play(&"active")
	else:
		_go_to_sleep()
	stun_finished.emit()


func _is_targetable_hylas(candidate: Node) -> bool:
	if not is_instance_valid(candidate):
		return false
	return not (
		candidate.has_method(&"is_camouflage_active")
		and bool(candidate.call(&"is_camouflage_active"))
	)


func _is_hylas_targetable() -> bool:
	return _is_targetable_hylas(_hylas)


func _resolve_hylas() -> void:
	if _hylas != null and is_instance_valid(_hylas):
		return
	_hylas = get_tree().get_first_node_in_group(&"hylas") as Node2D


func _on_wake_area_body_entered(body: Node2D) -> void:
	if is_stunned():
		return
	if body.is_in_group(&"hylas") and _is_targetable_hylas(body):
		_hylas = body
		_wake_up()


func _on_hurt_area_body_entered(body: Node2D) -> void:
	if is_stunned():
		return
	if body.is_in_group(&"hylas") and _is_targetable_hylas(body):
		_hylas = body
		if not _awake:
			_wake_up()
		_damage_hylas(body)


func _wake_up() -> void:
	if _awake or is_stunned():
		return
	_awake = true
	_wake_bubble_burst.trigger()
	_animated_sprite.play(&"wake")


func _go_to_sleep() -> void:
	_awake = false
	_animated_sprite.animation = &"sleep"
	_animated_sprite.frame = 0
	_animated_sprite.pause()


func _on_animation_finished() -> void:
	if _awake and not is_stunned() and _animated_sprite.animation == &"wake":
		_animated_sprite.play(&"active")


func _damage_touching_hylas_if_needed() -> void:
	if is_stunned() or not _hurt_area.monitoring:
		return
	for body: Node2D in _hurt_area.get_overlapping_bodies():
		if body.is_in_group(&"hylas") and _is_targetable_hylas(body):
			_damage_hylas(body)
			return


func _damage_hylas(hylas_body: Node2D) -> void:
	if is_stunned() or not _is_targetable_hylas(hylas_body):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	_last_damage_time = now
	damage_requested.emit(hylas_body, damage_amount)


func _connect_to_level_conch_signal() -> void:
	var ancestor: Node = get_parent()
	var callback: Callable = Callable(self, "_on_level_conch_target_hit")
	while ancestor != null:
		if ancestor.has_signal(&"conch_target_hit"):
			if not ancestor.is_connected(&"conch_target_hit", callback):
				ancestor.connect(&"conch_target_hit", callback)
			return
		ancestor = ancestor.get_parent()


func _on_level_conch_target_hit(
		target: Node2D,
		hit_position: Vector2,
		_pulse_index: int,
	) -> void:
	if target != self and target != _conch_target:
		return
	var origin: Vector2 = hit_position
	var pulse_direction: Vector2 = Vector2.RIGHT
	var hit_distance: float = 0.0
	_resolve_hylas()
	if is_instance_valid(_hylas):
		origin = _hylas.global_position
		var target_offset: Vector2 = hit_position - origin
		hit_distance = target_offset.length()
		if target_offset.length_squared() > 0.001:
			pulse_direction = target_offset.normalized()
	receive_conch_hit(origin, pulse_direction, hit_distance, 1.0)


func get_debug_lines() -> Array[String]:
	return [
		"[BlackBloomHazard]",
		"awake=%s" % str(_awake),
		"distance_active=%s" % str(_distance_active),
		"stunned=%s" % str(is_stunned()),
		"stun_remaining=%.2f" % get_stun_time_remaining(),
	]
