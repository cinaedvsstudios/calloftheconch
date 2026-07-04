class_name VisualCollisionGuard
extends Node
## Keeps the terrain collision created by PrototypeWater intact.
## Only changes how the visual-only lower-water parallax sprite is drawn.

const PARALLAX_SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_mul;

uniform float darken_strength : hint_range(0.0, 1.0) = 0.64;
uniform float transparent_cutoff : hint_range(0.0, 1.0) = 0.06;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a <= transparent_cutoff) {
		discard;
	}
	float coverage = smoothstep(transparent_cutoff, 1.0, source.a) * darken_strength;
	vec3 multiplier = mix(vec3(1.0), clamp(source.rgb, vec3(0.08), vec3(1.0)), coverage);
	COLOR = vec4(multiplier, coverage);
}
"""

var _parallax_material: ShaderMaterial


func _ready() -> void:
	_parallax_material = _create_parallax_material()
	call_deferred("_apply_parallax_material")
	set_process(false)


func _apply_parallax_material() -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var water_layer: Node = world.get_node_or_null("WaterLayer")
	if water_layer == null:
		return
	for child: Node in water_layer.get_children():
		if child is Sprite2D and child.z_index == -20:
			var parallax_sprite: Sprite2D = child as Sprite2D
			parallax_sprite.material = _parallax_material


func _create_parallax_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = PARALLAX_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
