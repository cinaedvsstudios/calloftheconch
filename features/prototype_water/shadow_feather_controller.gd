class_name ShadowFeatherController
extends Node
## Replaces the duplicate-silhouette shadow with a light, broadly feathered underwater falloff.

const CORE_OFFSET: Vector2 = Vector2(7.0, 8.0)
const TARGET_FEATHER_PIXELS_ON_SCREEN: float = 20.0
const SHADOW_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.005, 0.035, 0.10, 0.24);
uniform float feather_source_pixels = 60.0;

float ring_alpha(vec2 uv, float radius_pixels) {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * radius_pixels;
	float sum = 0.0;
	sum += texture(TEXTURE, clamp(uv + vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv - vec2(step_uv.x, 0.0), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv + vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv - vec2(0.0, step_uv.y), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv + step_uv, vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv + vec2(step_uv.x, -step_uv.y), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv + vec2(-step_uv.x, step_uv.y), vec2(0.0), vec2(1.0))).a;
	sum += texture(TEXTURE, clamp(uv - step_uv, vec2(0.0), vec2(1.0))).a;
	return sum;
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a * 0.003;
	alpha += ring_alpha(UV, feather_source_pixels * 0.25) * 0.015;
	alpha += ring_alpha(UV, feather_source_pixels * 0.55) * 0.009;
	alpha += ring_alpha(UV, feather_source_pixels) * 0.004;
	COLOR = vec4(shadow_tint.rgb, clamp(alpha, 0.0, 1.0) * shadow_tint.a);
}
"""

@onready var _hylas: HylasController = get_parent() as HylasController
@onready var _sprite: Sprite2D = _hylas.get_node_or_null("Sprite") as Sprite2D
@onready var _shadow: Sprite2D = _hylas.get_node_or_null("HylasShadow") as Sprite2D

var _material: ShaderMaterial


func _ready() -> void:
	process_priority = 200
	if _hylas == null or _sprite == null or _shadow == null:
		set_process(false)
		return
	_material = _make_material()
	call_deferred("_apply_soft_shadow")


func _process(_delta: float) -> void:
	_apply_soft_shadow()


func _apply_soft_shadow() -> void:
	if _shadow == null or _sprite == null or _material == null:
		return
	if _shadow.material != _material:
		_shadow.material = _material

	var texture: Texture2D = _shadow.texture
	if texture == null:
		return

	var display_height: float = 205.0
	var tuning_value: Variant = _hylas.get("_tuning")
	if tuning_value is PrototypeTuning:
		var tuning: PrototypeTuning = tuning_value as PrototypeTuning
		display_height = tuning.hylas_display_height

	var sprite_scale: float = display_height / maxf(1.0, float(texture.get_height()))
	var source_feather: float = maxf(12.0, TARGET_FEATHER_PIXELS_ON_SCREEN / maxf(0.001, sprite_scale))
	_material.set_shader_parameter(&"feather_source_pixels", source_feather)
	_shadow.position = CORE_OFFSET
	_shadow.scale = Vector2(sprite_scale, sprite_scale)
	_shadow.visible = true


func _make_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SHADOW_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
