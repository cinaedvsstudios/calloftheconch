class_name VisualCollisionGuard
extends Node

const LOWER_WATER_SHADER: String = """
shader_type canvas_item;
render_mode blend_mix;

uniform float overlay_opacity : hint_range(0.0, 1.0) = 0.64;
uniform float top_fade_fraction : hint_range(0.001, 1.0) = 0.045;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float top_fade = smoothstep(0.0, top_fade_fraction, UV.y);
	COLOR = vec4(source.rgb, source.a * overlay_opacity * top_fade);
}
"""

var _lower_water_material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lower_water_material = _create_lower_water_material()
	set_process(true)


func _process(_delta: float) -> void:
	var world: Node = get_parent()
	if world == null:
		return
	_disable_generated_backdrop_collision(world)
	_apply_lower_water_overlay_material(world)


func _disable_generated_backdrop_collision(world: Node) -> void:
	_disable_collision_in_layer(world.get_node_or_null("WaterLayer"))
	_disable_collision_in_layer(world.get_node_or_null("SceneryLayer"))
	_disable_collision_in_layer(world.get_node_or_null("ForegroundLayer"))


func _disable_collision_in_layer(layer: Node) -> void:
	if layer == null:
		return
	for child: Node in layer.get_children():
		if child is StaticBody2D:
			var body: StaticBody2D = child as StaticBody2D
			body.collision_layer = 0
			body.collision_mask = 0


func _apply_lower_water_overlay_material(world: Node) -> void:
	var water_layer: Node = world.get_node_or_null("WaterLayer")
	if water_layer == null:
		return
	for child: Node in water_layer.get_children():
		if child is Sprite2D and child.z_index == -20:
			var lower_overlay: Sprite2D = child as Sprite2D
			if lower_overlay.material != _lower_water_material:
				lower_overlay.material = _lower_water_material


func _create_lower_water_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = LOWER_WATER_SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
