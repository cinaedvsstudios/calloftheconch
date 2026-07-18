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

@export_category("Collection Flash")
@export var flash_color: Color = Color(0.12, 1.0, 1.0, 1.0)
@export_range(0.01, 0.25, 0.01) var pre_flash_on_seconds: float = 0.06
@export_range(0.01, 0.25, 0.01) var pre_flash_off_seconds: float = 0.07
@export_range(0.0, 1.0, 0.01) var dissolve_flash_min_strength: float = 0.08
@export_range(0.0, 1.0, 0.01) var dissolve_flash_max_strength: float = 0.82
@export_range(0.01, 0.25, 0.01) var dissolve_flash_on_seconds: float = 0.06
@export_range(0.01, 0.25, 0.01) var dissolve_flash_off_seconds: float = 0.08

@export_category("Collection Sparkles")
@export_range(0, 80, 1) var sparkle_count: int = 18
@export_range(0.05, 2.0, 0.01) var sparkle_lifetime: float = 0.52
@export_range(0.0, 360.0, 1.0) var sparkle_spread_degrees: float = 86.0
@export_range(0.0, 500.0, 1.0) var sparkle_min_speed: float = 42.0
@export_range(0.0, 500.0, 1.0) var sparkle_max_speed: float = 122.0
@export_range(0.01, 1.0, 0.01) var sparkle_min_scale: float = 0.045
@export_range(0.01, 1.0, 0.01) var sparkle_max_scale: float = 0.115
@export var sparkle_color: Color = Color(0.72, 0.96, 1.0, 0.92)

@export_category("Collection Radial Sparks")
@export_range(0, 80, 1) var radial_spark_count: int = 24
@export_range(0.05, 1.0, 0.01) var radial_spark_lifetime: float = 0.34
@export_range(0.0, 500.0, 1.0) var radial_spark_min_speed: float = 110.0
@export_range(0.0, 500.0, 1.0) var radial_spark_max_speed: float = 220.0
@export_range(0.01, 1.5, 0.01) var radial_spark_min_scale: float = 0.28
@export_range(0.01, 1.5, 0.01) var radial_spark_max_scale: float = 0.62
@export var radial_spark_color: Color = Color(0.62, 1.0, 1.0, 0.96)

@onready var _sprite: Sprite2D = %PickupSprite
@onready var _collision_shape: CollisionShape2D = %PickupCollision

var _collected: bool = false
var _distance_active: bool = true
var _dissolving: bool = false
var _base_sprite_material: Material
var _dissolve_material: ShaderMaterial
var _preflash_tween: Tween
var _dissolve_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	_base_sprite_material = _sprite.material
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
	if _dissolving:
		_apply_collection_state()
		return
	if not _collected:
		_kill_dissolve_tween()
		_dissolve_material = null
		_restore_sprite_material()
	_apply_collection_state()


func is_collected() -> bool:
	return _collected


func set_distance_active(is_active: bool) -> void:
	_distance_active = is_active
	_apply_collection_state()


func _apply_collection_state() -> void:
	var should_hide: bool = _collected and not _dissolving
	visible = not should_hide
	monitoring = _distance_active and not _collected and not _dissolving
	if is_instance_valid(_collision_shape):
		_collision_shape.set_deferred(&"disabled", _collected or _dissolving or not _distance_active)
	if not _collected and not _dissolving and is_instance_valid(_sprite):
		_restore_sprite_material()


func _on_body_entered(body: Node2D) -> void:
	if _collected or _dissolving or not body.is_in_group(&"hylas"):
		return
	_collect()


func _collect() -> void:
	_collected = true
	_dissolving = true
	_apply_collection_state()
	_begin_collection_dissolve()
	pickup_collected.emit(
		pickup_type_id,
		pickup_instance_id,
		heal_amount,
		restores_full,
		activates_greatfin,
		full_health_onos_value,
	)


func _begin_collection_dissolve() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		_finish_runtime_dissolve()
		return
	_kill_dissolve_tween()
	_dissolve_material = _create_dissolve_material()
	_sprite.material = _dissolve_material
	_sprite.modulate = Color.WHITE
	_set_dissolve_strength(0.0)
	_set_flash_strength(0.0)
	_spawn_magic_sparkles()
	_start_preflash_sequence()


func _start_preflash_sequence() -> void:
	_preflash_tween = create_tween()
	_preflash_tween.set_loops(2)
	_preflash_tween.tween_method(
		Callable(self, "_set_flash_strength"),
		0.0,
		1.0,
		maxf(0.01, pre_flash_on_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_preflash_tween.tween_method(
		Callable(self, "_set_flash_strength"),
		1.0,
		0.0,
		maxf(0.01, pre_flash_off_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_preflash_tween.finished.connect(Callable(self, "_start_dissolve_phase"), Object.CONNECT_ONE_SHOT)


func _start_dissolve_phase() -> void:
	_preflash_tween = null
	if not _dissolving or _dissolve_material == null:
		return
	_set_flash_strength(dissolve_flash_min_strength)
	_spawn_radial_sparks()

	_dissolve_tween = create_tween()
	_dissolve_tween.tween_method(
		Callable(self, "_set_dissolve_strength"),
		0.0,
		1.0,
		maxf(0.05, dissolve_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dissolve_tween.finished.connect(Callable(self, "_finish_runtime_dissolve"), Object.CONNECT_ONE_SHOT)

	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.tween_method(
		Callable(self, "_set_flash_strength"),
		dissolve_flash_min_strength,
		dissolve_flash_max_strength,
		maxf(0.01, dissolve_flash_on_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(
		Callable(self, "_set_flash_strength"),
		dissolve_flash_max_strength,
		dissolve_flash_min_strength,
		maxf(0.01, dissolve_flash_off_seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _create_dissolve_material() -> ShaderMaterial:
	var dissolve_material: ShaderMaterial = ShaderMaterial.new()
	dissolve_material.resource_local_to_scene = true
	dissolve_material.shader = PICKUP_DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(&"strength", 0.0)
	dissolve_material.set_shader_parameter(&"seed", randf_range(0.05, 1.0))
	dissolve_material.set_shader_parameter(&"direction", dissolve_direction)
	dissolve_material.set_shader_parameter(&"mask_vignette_strength", dissolve_vignette_strength)
	dissolve_material.set_shader_parameter(&"mask_vignette_center", dissolve_vignette_center)
	dissolve_material.set_shader_parameter(&"flash_color", flash_color)
	dissolve_material.set_shader_parameter(&"flash_strength", 0.0)
	return dissolve_material


func _set_dissolve_strength(strength: float) -> void:
	if _dissolve_material == null:
		return
	_dissolve_material.set_shader_parameter(&"strength", clampf(strength, 0.0, 1.0))


func _set_flash_strength(strength: float) -> void:
	if _dissolve_material == null:
		return
	_dissolve_material.set_shader_parameter(&"flash_strength", clampf(strength, 0.0, 1.0))


func _finish_runtime_dissolve() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_preflash_tween = null
	_dissolve_tween = null
	_set_flash_strength(0.0)
	_dissolving = false
	_apply_collection_state()


func _kill_dissolve_tween() -> void:
	if _preflash_tween != null and _preflash_tween.is_valid():
		_preflash_tween.kill()
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_preflash_tween = null
	_dissolve_tween = null
	_flash_tween = null


func _restore_sprite_material() -> void:
	if not is_instance_valid(_sprite):
		return
	_sprite.material = _base_sprite_material
	_sprite.modulate = Color.WHITE


func _spawn_magic_sparkles() -> void:
	if sparkle_count <= 0 or not is_instance_valid(_sprite):
		return
	var sparkle_texture: Texture2D = _create_sparkle_texture()
	var lifetime: float = maxf(0.05, sparkle_lifetime)
	var half_spread: float = deg_to_rad(sparkle_spread_degrees) * 0.5
	for _index in range(sparkle_count):
		var sparkle: Sprite2D = Sprite2D.new()
		sparkle.name = "PickupMagicSparkle"
		sparkle.texture = sparkle_texture
		sparkle.centered = true
		sparkle.z_index = _sprite.z_index + 2
		sparkle.position = _sprite.position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		var sparkle_scale: float = randf_range(sparkle_min_scale, sparkle_max_scale)
		sparkle.scale = Vector2.ONE * sparkle_scale
		sparkle.modulate = sparkle_color
		add_child(sparkle)

		var angle: float = -PI * 0.5 + randf_range(-half_spread, half_spread)
		var distance: float = randf_range(sparkle_min_speed, sparkle_max_speed) * lifetime
		var target_position: Vector2 = sparkle.position + Vector2(cos(angle), sin(angle)) * distance
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, ^"position", target_position, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, ^"modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(Callable(sparkle, "queue_free"), Object.CONNECT_ONE_SHOT)


func _spawn_radial_sparks() -> void:
	if radial_spark_count <= 0 or not is_instance_valid(_sprite):
		return
	var sparkle_texture: Texture2D = _create_sparkle_texture()
	var lifetime: float = maxf(0.05, radial_spark_lifetime)
	for _index in range(radial_spark_count):
		var spark: Sprite2D = Sprite2D.new()
		spark.name = "PickupRadialSpark"
		spark.texture = sparkle_texture
		spark.centered = true
		spark.z_index = _sprite.z_index + 3
		spark.position = _sprite.position
		var spark_scale: float = randf_range(radial_spark_min_scale, radial_spark_max_scale)
		spark.scale = Vector2.ONE * spark_scale
		spark.modulate = radial_spark_color
		add_child(spark)

		var angle: float = randf_range(0.0, TAU)
		var distance: float = randf_range(radial_spark_min_speed, radial_spark_max_speed) * lifetime
		var target_position: Vector2 = spark.position + Vector2(cos(angle), sin(angle)) * distance
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, ^"position", target_position, lifetime).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, ^"modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(spark, ^"scale", Vector2.ZERO, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.finished.connect(Callable(spark, "queue_free"), Object.CONNECT_ONE_SHOT)


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
