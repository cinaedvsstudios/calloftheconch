shader_type canvas_item;
render_mode unshaded;

uniform vec4 darkness_tint : source_color = vec4(0.004, 0.012, 0.055, 1.0);
uniform float darkness_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 reveal_center = vec2(0.5, 0.5);
uniform vec2 reveal_radius = vec2(0.001, 0.001);
uniform float reveal_strength : hint_range(0.0, 1.0) = 0.0;
uniform float feather : hint_range(0.01, 0.8) = 0.28;
uniform float core_ratio : hint_range(0.02, 0.8) = 0.24;

void fragment() {
	vec2 safe_radius = max(reveal_radius, vec2(0.0001));
	vec2 ellipse_delta = (SCREEN_UV - reveal_center) / safe_radius;
	float ellipse_distance = length(ellipse_delta);
	float soft_reveal = 1.0 - smoothstep(1.0 - feather, 1.0, ellipse_distance);
	float core_reveal = 1.0 - smoothstep(0.0, core_ratio, ellipse_distance);
	float reveal = clamp((soft_reveal + core_reveal * 0.16) * reveal_strength, 0.0, 1.0);
	float final_alpha = darkness_strength * (1.0 - reveal) * darkness_tint.a;
	COLOR = vec4(darkness_tint.rgb, final_alpha);
}
