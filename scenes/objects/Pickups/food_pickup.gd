class_name CotcFoodPickup
extends Area2D

signal pickup_collected(
	pickup_type_id: StringName,
	pickup_instance_id: StringName,
	heal_amount: int,
	restores_full: bool,
	activates_greatfin: bool,
	full_health_onos_value: int,
)

const PICKUP_FEEDBACK_SCENE: PackedScene = preload(
	"res://scenes/effects/PickupFeedback/pickup_feedback.tscn"
)

@export_category("Pickup Identity")
@export var pickup_type_id: StringName = &"food"
@export var pickup_instance_id: StringName = &""
@export var display_name: String = "Food"

@export_category("Food Effect")
@export_range(0, 8, 1) var heal_amount: int = 1
@export var restores_full: bool = false
@export var activates_greatfin: bool = false
@export_range(0, 100, 1) var full_health_onos_value: int = 1

@export_category("Presentation")
@export_range(20.0, 400.0, 1.0) var display_height: float = 120.0
@export_range(20.0, 250.0, 1.0) var pickup_radius: float = 65.0

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _collision_shape: CollisionShape2D = %PickupCollision

var _collected: bool = false
var _distance_active: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_display_scale()
	_configure_collision()
	monitoring = true
	monitorable = false


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	monitoring = _distance_active and not _collected


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	_collected = true
	monitoring = false
	_collision_shape.set_deferred(&"disabled", true)
	hide()
	pickup_collected.emit(
		pickup_type_id,
		pickup_instance_id,
		heal_amount,
		restores_full,
		activates_greatfin,
		full_health_onos_value,
	)
	_spawn_pickup_feedback()
	queue_free()


func _spawn_pickup_feedback() -> void:
	var feedback: Node = PICKUP_FEEDBACK_SCENE.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(feedback)
	if feedback.has_method(&"play_feedback"):
		feedback.call(&"play_feedback")


func _apply_display_scale() -> void:
	if _sprite.texture == null:
		return
	var texture_height: float = float(_sprite.texture.get_height())
	if texture_height <= 0.0:
		return
	var scale_factor: float = display_height / texture_height
	_sprite.scale = Vector2.ONE * scale_factor


func _configure_collision() -> void:
	var circle: CircleShape2D = _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = pickup_radius
