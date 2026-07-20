@tool
class_name CotcTreasurePickup
extends Area2D

signal pickup_collected(
	pickup_type_id: StringName,
	pickup_instance_id: StringName,
	heal_amount: int,
	restores_full: bool,
	activates_greatfin: bool,
	full_health_onos_value: int,
)

const TREASURE_CATALOG = preload("res://rebuild_v3/app/inventory/treasure_catalog.gd")

@export_category("Pickup Identity")
@export var treasure_id: StringName = &"ancient_greek_coins":
	set(value):
		treasure_id = value
		if Engine.is_editor_hint() and is_node_ready():
			_load_catalogue_texture()
			_apply_display_scale()
@export var pickup_instance_id: StringName = &""

@export_category("Presentation")
@export_range(20.0, 400.0, 1.0) var display_height: float = 120.0:
	set(value):
		display_height = value
		if Engine.is_editor_hint() and is_node_ready():
			_apply_display_scale()
@export_range(20.0, 250.0, 1.0) var pickup_radius: float = 65.0

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _collision_shape: CollisionShape2D = %PickupCollision

var _collected: bool = false
var _distance_active: bool = true


func _ready() -> void:
	_load_catalogue_texture()
	_apply_display_scale()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
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


func get_display_name() -> String:
	return TREASURE_CATALOG.get_display_name(treasure_id)


func get_onos_value() -> int:
	return TREASURE_CATALOG.get_onos_value(treasure_id)


func _apply_collection_state() -> void:
	visible = not _collected
	monitoring = _distance_active and not _collected
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(&"disabled", _collected or not _distance_active)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	if not TREASURE_CATALOG.has_treasure(treasure_id):
		push_warning("Treasure pickup '%s' has an unknown treasure ID '%s'." % [name, String(treasure_id)])
		return
	_collected = true
	_apply_collection_state()
	pickup_collected.emit(
		treasure_id,
		pickup_instance_id,
		0,
		false,
		false,
		TREASURE_CATALOG.get_onos_value(treasure_id),
	)


func _load_catalogue_texture() -> void:
	if not TREASURE_CATALOG.has_treasure(treasure_id):
		push_warning("Treasure pickup '%s' has an unknown treasure ID '%s'." % [name, String(treasure_id)])
		return
	var icon_path: String = TREASURE_CATALOG.get_icon_path(treasure_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path, "Texture2D"):
		push_warning("Treasure pickup '%s' could not load '%s'." % [String(treasure_id), icon_path])
		return
	_sprite.texture = ResourceLoader.load(icon_path, "Texture2D") as Texture2D


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
