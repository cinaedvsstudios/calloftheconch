shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 flash_color : source_color = vec4(0.0, 0.82, 1.0, 1.0);

void fragment() {
	float texture_alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(
		flash_color.rgb,
		texture_alpha * flash_color.a * COLOR.a
	);
}
