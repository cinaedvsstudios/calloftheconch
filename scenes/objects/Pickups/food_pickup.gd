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
var _dissolving: bool = false
var _base_sprite_material: Material
var _dissolve_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_sprite_material = _sprite.material
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
	if _dissolving and is_collected:
		_collected = true
		_apply_collection_state()
		return
	_collected = is_collected
	_dissolving = false
	_kill_dissolve_tween()
	_restore_sprite_material()
	_apply_collection_state()


func is_collected() -> bool:
	return _collected


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	_apply_collection_state()


func _apply_collection_state() -> void:
	visible = _dissolving or not _collected
	monitoring = _distance_active and not _collected and not _dissolving
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(
			&"disabled",
			_collected or _dissolving or not _distance_active,
		)
	if not _collected and not _dissolving:
		_restore_sprite_material()
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE


func _on_body_entered(body: Node2D) -> void:
	if _collected or _dissolving or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	_collected = true
	_begin_collection_effect()
	pickup_collected.emit(
		pickup_type_id,
		pickup_instance_id,
		heal_amount,
		restores_full,
		activates_greatfin,
		full_health_onos_value,
	)


func _begin_collection_effect() -> void:
	_dissolving = true
	visible = true
	monitoring = false
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(&"disabled", true)
	_prepare_dissolve_material()
	_spawn_magic_sparkles()
	_kill_dissolve_tween()
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_method(
		Callable(self, "_set_dissolve_strength"),
		0.0,
		1.0,
		maxf(0.05, dissolve_seconds),
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dissolve_tween.finished.connect(_finish_runtime_dissolve, Object.CONNECT_ONE_SHOT)


func _prepare_dissolve_material() -> void:
	var dissolve_material: ShaderMaterial = ShaderMaterial.new()
	dissolve_material.resource_local_to_scene = true
	dissolve_material.shader = PICKUP_DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(&"strength", 0.0)
	dissolve_material.set_shader_parameter(&"seed", randf_range(0.05, 1.0))
	dissolve_material.set_shader_parameter(&"direction", dissolve_direction)
	dissolve_material.set_shader_parameter(&"mask_vignette_strength", dissolve_vignette_strength)
	dissolve_material.set_shader_parameter(&"mask_vignette_center", dissolve_vignette_center)
	_sprite.material = dissolve_material
	_sprite.modulate = Color.WHITE


func _set_dissolve_strength(value: float) -> void:
	var dissolve_material: ShaderMaterial = _sprite.material as ShaderMaterial
	if dissolve_material == null:
		return
	dissolve_material.set_shader_parameter(&"strength", clampf(value, 0.0, 1.0))


func _finish_runtime_dissolve() -> void:
	_dissolving = false
	visible = false
	monitoring = false
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(&"disabled", true)


func _spawn_magic_sparkles() -> void:
	if sparkle_count <= 0:
		return
	var sparkles: CPUParticles2D = CPUParticles2D.new()
	sparkles.name = "PickupMagicSparkles"
	sparkles.z_index = 8
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
	add_child(sparkles)
	sparkles.global_position = _sprite.global_position
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


func _kill_dissolve_tween() -> void:
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	_dissolve_tween = null


func _restore_sprite_material() -> void:
	if is_instance_valid(_sprite):
		_sprite.material = _base_sprite_material


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
