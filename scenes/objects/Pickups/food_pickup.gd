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

const PICKUP_DISSOLVE_SHADER: Shader = preload(
	"res://scenes/objects/Pickups/pickup_dissolve.gdshader"
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
		_sprite.material = null
		_sprite.modulate = Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	_spawn_collection_visual_copy()
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


func _spawn_collection_visual_copy() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var effect_root: Node2D = Node2D.new()
	effect_root.name = "%sCollectionEffect" % String(name)
	effect_root.z_index = z_index + 8
	parent_node.add_child(effect_root)
	effect_root.global_position = _sprite.global_position

	var dissolve_material: ShaderMaterial = _create_dissolve_material()
	var dissolve_sprite: Sprite2D = Sprite2D.new()
	dissolve_sprite.name = "DissolveSprite"
	dissolve_sprite.texture = _sprite.texture
	dissolve_sprite.centered = _sprite.centered
	dissolve_sprite.offset = _sprite.offset
	dissolve_sprite.flip_h = _sprite.flip_h
	dissolve_sprite.flip_v = _sprite.flip_v
	dissolve_sprite.region_enabled = _sprite.region_enabled
	dissolve_sprite.region_rect = _sprite.region_rect
	dissolve_sprite.hframes = _sprite.hframes
	dissolve_sprite.vframes = _sprite.vframes
	dissolve_sprite.frame = _sprite.frame
	dissolve_sprite.frame_coords = _sprite.frame_coords
	dissolve_sprite.modulate = _sprite.modulate
	dissolve_sprite.material = dissolve_material
	effect_root.add_child(dissolve_sprite)
	dissolve_sprite.global_transform = _sprite.global_transform

	_spawn_magic_sparkles(effect_root)

	var dissolve_tween: Tween = effect_root.create_tween()
	dissolve_tween.tween_property(
		dissolve_material,
		^"shader_parameter/strength",
		1.0,
		maxf(0.05, dissolve_seconds),
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dissolve_tween.finished.connect(effect_root.queue_free, Object.CONNECT_ONE_SHOT)


func _create_dissolve_material() -> ShaderMaterial:
	var dissolve_material: ShaderMaterial = ShaderMaterial.new()
	dissolve_material.resource_local_to_scene = true
	dissolve_material.shader = PICKUP_DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(&"strength", 0.0)
	dissolve_material.set_shader_parameter(&"seed", randf_range(0.05, 1.0))
	dissolve_material.set_shader_parameter(&"direction", dissolve_direction)
	dissolve_material.set_shader_parameter(&"mask_vignette_strength", dissolve_vignette_strength)
	dissolve_material.set_shader_parameter(&"mask_vignette_center", dissolve_vignette_center)
	return dissolve_material


func _spawn_magic_sparkles(effect_root: Node2D) -> void:
	if sparkle_count <= 0 or not is_instance_valid(effect_root):
		return
	var sparkles: CPUParticles2D = CPUParticles2D.new()
	sparkles.name = "PickupMagicSparkles"
	sparkles.z_index = 9
	sparkles.one_shot = true
	sparkles.amount = sparkle_count
	sparkles.lifetime = maxf(0.05, sparkle_lifetime)
	sparkles.explosiveness = 0.88
	sparkles.randomness = 0.58
	sparkles.local_coords = false
	sparkles.texture = _create_sparkle_texture()
	sparkles.direction = Vector2(0.0, -1.0)
	sparkles.spread = sparkle_spread_degrees
	sparkles.initial_velocity_min = sparkle_min_speed
	sparkles.initial_velocity_max = sparkle_max_speed
	sparkles.gravity = Vector2(0.0, -18.0)
	sparkles.scale_amount_min = sparkle_min_scale
	sparkles.scale_amount_max = sparkle_max_scale
	sparkles.color = sparkle_color
	effect_root.add_child(sparkles)
	sparkles.global_position = effect_root.global_position
	sparkles.finished.connect(sparkles.queue_free, Object.CONNECT_ONE_SHOT)
	sparkles.emitting = true


func _create_sparkle_texture() -> Texture2D:
	var image: Image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	for x in range(5):
		for y in range(5):
			var distance: float = Vector2(x - 2, y - 2).length()
			if distance <= 2.0:
				var alpha: float = clampf(1.0 - distance / 2.15, 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


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
