class_name CotcBlackBloomHazard
extends Node2D

## Emits this for the future Fin health system. It does not subtract Fins yet.
signal damage_requested(hylas: Node, amount: int)

@export_category("Wake Range")
@export var wake_distance: float = 560.0
@export var sleep_distance: float = 780.0

@export_category("Damage")
@export var damage_amount: int = 1
@export var damage_cooldown: float = 1.0

@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var _wake_area: Area2D = %WakeArea
@onready var _hurt_area: Area2D = %HurtArea
@onready var _wake_bubble_burst: CotcBubbleBurst = %WakeBubbleBurst

var _hylas: Node2D
var _awake: bool = false
var _last_damage_time: float = -999.0
var _distance_active: bool = true


func _ready() -> void:
	_animated_sprite.animation_finished.connect(_on_animation_finished)
	_wake_area.body_entered.connect(_on_wake_area_body_entered)
	_hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	_wake_area.monitoring = true
	_hurt_area.monitoring = true
	set_process(true)
	_go_to_sleep()


func set_distance_active(is_active: bool) -> void:
	if _distance_active == is_active:
		return
	_distance_active = is_active
	set_process(_distance_active)
	_wake_area.monitoring = _distance_active
	_hurt_area.monitoring = _distance_active
	if _distance_active:
		return
	_wake_bubble_burst.stop_burst()
	_go_to_sleep()
	_hylas = null


func _process(_delta: float) -> void:
	_resolve_hylas()
	if _hylas == null:
		return

	var distance_to_hylas: float = global_position.distance_to(_hylas.global_position)
	if not _awake and distance_to_hylas <= wake_distance:
		_wake_up()
	elif _awake and distance_to_hylas >= sleep_distance:
		_go_to_sleep()

	if _awake:
		_damage_touching_hylas_if_needed()


func _resolve_hylas() -> void:
	if _hylas != null and is_instance_valid(_hylas):
		return
	_hylas = get_tree().get_first_node_in_group(&"hylas") as Node2D


func _on_wake_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"hylas"):
		_hylas = body
		_wake_up()


func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"hylas"):
		_hylas = body
		if not _awake:
			_wake_up()
		_damage_hylas(body)


func _wake_up() -> void:
	if _awake:
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
	if _awake and _animated_sprite.animation == &"wake":
		_animated_sprite.play(&"active")


func _damage_touching_hylas_if_needed() -> void:
	for body: Node2D in _hurt_area.get_overlapping_bodies():
		if body.is_in_group(&"hylas"):
			_damage_hylas(body)
			return


func _damage_hylas(hylas_body: Node2D) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	_last_damage_time = now
	damage_requested.emit(hylas_body, damage_amount)
	if hylas_body.has_method(&"play_fin_loss_sound"):
		hylas_body.call(&"play_fin_loss_sound")
