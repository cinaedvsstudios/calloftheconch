shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 ray_color : source_color = vec4(0.29, 0.86, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 0.40, 0.001) = 0.075;
uniform float drift_speed : hint_range(0.0, 0.30, 0.001) = 0.035;
uniform float ray_density : hint_range(0.5, 12.0, 0.01) = 3.5;
uniform float depth_fade_power : hint_range(0.1, 4.0, 0.01) = 1.35;

void fragment() {
	float coarse_phase = SCREEN_UV.x * ray_density + UV.y * 1.15 - TIME * drift_speed;
	float fine_phase = SCREEN_UV.x * ray_density * 2.65 - UV.y * 0.55 + TIME * drift_speed * 0.65;
	float coarse_rays = sin(coarse_phase * TAU) * 0.5 + 0.5;
	float fine_rays = sin(fine_phase * TAU) * 0.5 + 0.5;
	float ray_mask = smoothstep(0.70, 0.93, coarse_rays * 0.72 + fine_rays * 0.28);
	float depth_fade = pow(1.0 - UV.y, depth_fade_power);
	float alpha = ray_mask * depth_fade * intensity;
	COLOR = vec4(ray_color.rgb, alpha);
}
