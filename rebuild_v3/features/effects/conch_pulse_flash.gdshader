shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float cut_off : hint_range(0.0, 1.0, 0.001) = 0.01;
uniform float fade_width : hint_range(0.001, 1.0, 0.001) = 0.08;
uniform float brightness : hint_range(0.0, 8.0, 0.05) = 1.5;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float light = max(source.r, max(source.g, source.b));
	float visible_mask = source.a * smoothstep(cut_off, cut_off + fade_width, light);
	COLOR = vec4(source.rgb * brightness, visible_mask);
}
