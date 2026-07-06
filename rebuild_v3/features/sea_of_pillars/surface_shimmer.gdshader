shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 shimmer_color : source_color = vec4(0.65, 0.96, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 0.50, 0.001) = 0.17;
uniform float drift_speed : hint_range(0.0, 3.0, 0.01) = 0.62;
uniform float glint_density : hint_range(1.0, 120.0, 0.1) = 42.0;
uniform float vertical_fade : hint_range(0.1, 4.0, 0.01) = 1.45;

void fragment() {
	float coarse_phase = SCREEN_UV.x * glint_density + SCREEN_UV.y * 8.0 + TIME * drift_speed;
	float fine_phase = SCREEN_UV.x * glint_density * 2.8 - TIME * drift_speed * 1.7;
	float coarse_glints = sin(coarse_phase * TAU) * 0.5 + 0.5;
	float fine_glints = sin(fine_phase * TAU) * 0.5 + 0.5;
	float glint_mask = smoothstep(0.76, 0.96, coarse_glints * 0.58 + fine_glints * 0.42);
	float waterline_fade = pow(1.0 - UV.y, vertical_fade);
	float alpha = glint_mask * waterline_fade * intensity;
	COLOR = vec4(shimmer_color.rgb, alpha);
}
