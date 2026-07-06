shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 ray_color : source_color = vec4(0.46, 0.88, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 0.35, 0.001) = 0.05;
uniform float drift_speed : hint_range(0.0, 0.2, 0.001) = 0.025;
uniform float ray_density : hint_range(1.0, 300.0, 0.1) = 135.0;
uniform float depth_fade_power : hint_range(0.1, 5.0, 0.01) = 1.3;
uniform float wave_distortion : hint_range(0.0, 2.0, 0.01) = 0.32;

void fragment() {
	float wave = sin((UV.y * 18.0 + TIME * drift_speed * 4.0) * TAU) * wave_distortion;
	float phase = (UV.x * ray_density + wave + TIME * drift_speed) * TAU;
	float ray = sin(phase) * 0.5 + 0.5;
	float ray_mask = smoothstep(0.79, 0.98, ray);
	float depth_fade = pow(1.0 - UV.y, depth_fade_power);
	float alpha = ray_mask * depth_fade * intensity;
	COLOR = vec4(ray_color.rgb, alpha);
}
