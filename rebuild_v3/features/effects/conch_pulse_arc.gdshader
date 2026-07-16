shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float arc_degrees : hint_range(1.0, 180.0, 0.5) = 45.0;
uniform float edge_softness_degrees : hint_range(0.0, 30.0, 0.5) = 4.0;
uniform float cut_off : hint_range(0.0, 1.0, 0.001) = 0.01;
uniform float fade_width : hint_range(0.001, 1.0, 0.001) = 0.08;
uniform float brightness : hint_range(0.0, 8.0, 0.05) = 1.35;
uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float light = max(source.r, max(source.g, source.b));
	float texture_mask = source.a * smoothstep(cut_off, cut_off + fade_width, light);

	vec2 from_center = UV - vec2(0.5);
	float angle_from_forward = abs(atan(from_center.y, from_center.x));
	float half_arc = radians(arc_degrees * 0.5);
	float edge_softness = min(radians(edge_softness_degrees), half_arc);
	float arc_mask = 1.0 - smoothstep(
		max(0.0, half_arc - edge_softness),
		half_arc,
		angle_from_forward
	);

	float final_mask = texture_mask * arc_mask;
	COLOR = vec4(tint_color.rgb * light * brightness, final_mask * tint_color.a * COLOR.a);
}
