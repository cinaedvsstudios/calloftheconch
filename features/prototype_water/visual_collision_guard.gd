class_name VisualCollisionGuard
extends Node
## Compatibility fix for the prototype water stack.
## It leaves mountain and sand collision entirely untouched.

const PARALLAX_MULTIPLY_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float darken_strength : hint_range(0.0, 1.0) = 0.64;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a <= 0.001) {
		discard;
	}
	float coverage = source.a * darken_strength;
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(background * source.rgb, coverage);
}
"""

var _parallax_material: ShaderMaterial


func _ready() -> void:
	_parallax_material = _create_parallax_material()
	call_deferred("_restore_original_water_stack")
	set_process(false)


func _restore_original_water_stack() -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var water_layer: Node = world.get_node_or_null("WaterLayer")
	if water_layer == null:
		return

	for child: Node in water_layer.get_children():
		if not (child is Sprite2D):
			continue
		var sprite: Sprite2D = child as Sprite2D
		# The latest background change added an extra waterbg tile above waterskybg.
		# Hide only that top duplicate; the original lower waterbg tile remains active.
		if sprite.z_index == -40 and sprite.position.y < 1.0:
			sprite.hide()
		# The parallax remains a multiply effect, but only actual non-transparent pixels participate.
		if sprite.z_index == -20:
			sprite.material = _parallax_material


func _create_parallax_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = PARALLAX_MULTIPLY_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
