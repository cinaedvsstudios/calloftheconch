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

const PICKUP_DISSOLVE_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/effects/PickupDissolve/pickup_dissolve_effect.tscn"
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

@export_category("Collection Dissolve")
@export_range(0.05, 2.0, 0.01) var dissolve_seconds: float = 0.62
@export var dissolve_direction: Vector2 = Vector2(0.0, -0.22)
@export_range(0.0, 1.0, 0.01) var dissolve_vignette_strength: float = 0.42
@export var dissolve_vignette_center: Vector2 = Vector2(0.5, 0.45)

@export_category("Collection Sparkles")
@export_range(0, 80, 1) var sparkle_count: int = 18
@export_range(0.05, 2.0, 0.01) var sparkle_lifetime: float = 0.52
@export_range(0.0, 360.0, 1.0) var sparkle_spread_degrees: float = 86.0
@export_range(0.0, 500.0, 1.0) var sparkle_min_speed: float = 42.0
@export_range(0.0, 500.0, 1.0) var sparkle_max_speed: float = 122.0
@export_range(0.01, 1.0, 0.01) var sparkle_min_scale: float = 0.045
@export_range(0.01, 1.0, 0.01) var sparkle_max_scale: float = 0.115
@export var sparkle_color: Color = Color(0.72, 0.96, 1.0, 0.92)

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _collision_shape: CollisionShape2D = %PickupCollision

var _collected: bool = false
var _distance_active: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_display_scale()
	_configure_collision()
	monitorable = false
	_apply_collection_state()


func assign_persistent_id(level_id: StringName) -> StringName:
	if not String(pickup_instance_id).is_empty():
		return pickup_instance_id
	var level_key: String = String(level_id)
	if level_key.is_empty():
		level_key = "unknown_level"
	pickup_instance_id = StringName("%s:%s" % [level_key, String(name)])
	return pickup_instance_id


func set_persistently_collected(is_collected: bool) -> void:
	_collected = is_collected
	_apply_collection_state()


func is_collected() -> bool:
	return _collected


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	_apply_collection_state()


func _apply_collection_state() -> void:
	visible = not _collected
	monitoring = _distance_active and not _collected
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(&"disabled", _collected or not _distance_active)
	if not _collected and is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	_spawn_collection_dissolve_effect()
	_collected = true
	_apply_collection_state()
	pickup_collected.emit(
		pickup_type_id,
		pickup_instance_id,
		heal_amount,
		restores_full,
		activates_greatfin,
		full_health_onos_value,
	)


func _spawn_collection_dissolve_effect() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	var dissolve_effect: Node = PICKUP_DISSOLVE_EFFECT_SCENE.instantiate()
	var effect_parent: Node = get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_parent()
	if effect_parent == null:
		dissolve_effect.queue_free()
		return
	effect_parent.add_child(dissolve_effect)
	if dissolve_effect.has_method(&"play_from_sprite"):
		dissolve_effect.call(
			&"play_from_sprite",
			_sprite,
			maxf(0.05, dissolve_seconds),
			dissolve_direction,
			dissolve_vignette_strength,
			dissolve_vignette_center,
			sparkle_count,
			sparkle_lifetime,
			sparkle_spread_degrees,
			sparkle_min_speed,
			sparkle_max_speed,
			sparkle_min_scale,
			sparkle_max_scale,
			sparkle_color
		)
	else:
		dissolve_effect.queue_free()


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
