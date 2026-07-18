class_name CotcPickupDissolveEffect
extends CanvasLayer

const PICKUP_DISSOLVE_SHADER: Shader = preload(
	"res://scenes/objects/Pickups/pickup_dissolve.gdshader"
)
const EFFECT_LAYER: int = 2048

var _dissolve_sprite: Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = EFFECT_LAYER


func play_from_sprite(
		source_sprite: Sprite2D,
		effect_seconds: float,
		dissolve_direction: Vector2,
		vignette_strength: float,
		vignette_center: Vector2,
		sparkle_count: int,
		sparkle_lifetime: float,
		sparkle_spread_degrees: float,
		sparkle_min_speed: float,
		sparkle_max_speed: float,
		sparkle_min_scale: float,
		sparkle_max_scale: float,
		sparkle_color: Color
	) -> void:
	if not is_instance_valid(source_sprite) or source_sprite.texture == null:
		queue_free()
		return

	layer = EFFECT_LAYER
	var dissolve_material: ShaderMaterial = _create_dissolve_material(
		dissolve_direction,
		vignette_strength,
		vignette_center
	)
	_dissolve_sprite = _create_sprite_copy(source_sprite, dissolve_material)
	add_child(_dissolve_sprite)
	_dissolve_sprite.transform = get_viewport().get_canvas_transform() * source_sprite.global_transform

	_spawn_magic_sparkles(
		_dissolve_sprite.transform.origin,
		sparkle_count,
		sparkle_lifetime,
		sparkle_spread_degrees,
		sparkle_min_speed,
		sparkle_max_speed,
		sparkle_min_scale,
		sparkle_max_scale,
		sparkle_color
	)

	var duration: float = maxf(0.05, effect_seconds)
	var dissolve_tween: Tween = create_tween()
	dissolve_tween.tween_property(
		dissolve_material,
		^"shader_parameter/strength",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dissolve_tween.finished.connect(Callable(self, "queue_free"), Object.CONNECT_ONE_SHOT)


func _create_sprite_copy(source_sprite: Sprite2D, dissolve_material: ShaderMaterial) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "PickupDissolveSprite"
	sprite.texture = source_sprite.texture
	sprite.centered = source_sprite.centered
	sprite.offset = source_sprite.offset
	sprite.flip_h = source_sprite.flip_h
	sprite.flip_v = source_sprite.flip_v
	sprite.region_enabled = source_sprite.region_enabled
	sprite.region_rect = source_sprite.region_rect
	sprite.hframes = source_sprite.hframes
	sprite.vframes = source_sprite.vframes
	sprite.frame = source_sprite.frame
	sprite.frame_coords = source_sprite.frame_coords
	sprite.modulate = source_sprite.modulate
	sprite.self_modulate = source_sprite.self_modulate
	sprite.material = dissolve_material
	return sprite


func _create_dissolve_material(
		dissolve_direction: Vector2,
		vignette_strength: float,
		vignette_center: Vector2
	) -> ShaderMaterial:
	var dissolve_material: ShaderMaterial = ShaderMaterial.new()
	dissolve_material.resource_local_to_scene = true
	dissolve_material.shader = PICKUP_DISSOLVE_SHADER
	dissolve_material.set_shader_parameter(&"strength", 0.0)
	dissolve_material.set_shader_parameter(&"seed", randf_range(0.05, 1.0))
	dissolve_material.set_shader_parameter(&"direction", dissolve_direction)
	dissolve_material.set_shader_parameter(&"mask_vignette_strength", vignette_strength)
	dissolve_material.set_shader_parameter(&"mask_vignette_center", vignette_center)
	return dissolve_material


func _spawn_magic_sparkles(
		screen_position: Vector2,
		sparkle_count: int,
		sparkle_lifetime: float,
		sparkle_spread_degrees: float,
		sparkle_min_speed: float,
		sparkle_max_speed: float,
		sparkle_min_scale: float,
		sparkle_max_scale: float,
		sparkle_color: Color
	) -> void:
	if sparkle_count <= 0:
		return
	var sparkles: CPUParticles2D = CPUParticles2D.new()
	sparkles.name = "PickupMagicSparkles"
	sparkles.z_index = 3
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
	sparkles.position = screen_position
	sparkles.finished.connect(Callable(sparkles, "queue_free"), Object.CONNECT_ONE_SHOT)
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
