shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 noise_color : source_color = vec4(0.04, 0.31, 0.48, 1.0);
uniform float opacity : hint_range(0.0, 0.30, 0.001) = 0.10;
uniform float drift_speed : hint_range(0.0, 0.10, 0.001) = 0.010;
uniform vec2 pattern_scale = vec2(210.0, 65.0);
uniform vec2 drift_direction = vec2(0.8, 0.22);
uniform vec2 seed_offset = vec2(0.0, 0.0);
uniform float threshold : hint_range(0.0, 1.0, 0.001) = 0.48;
uniform float softness : hint_range(0.01, 0.50, 0.001) = 0.22;
uniform float depth_strength : hint_range(0.0, 1.0, 0.001) = 0.30;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);

	float lower = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x);
	float upper = mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x);
	return mix(lower, upper, local.y);
}

float fractal_noise(vec2 point) {
	float value = value_noise(point);
	value += value_noise(point * 2.03 + vec2(17.3, 9.2)) * 0.5;
	value += value_noise(point * 4.11 + vec2(4.7, 31.8)) * 0.25;
	return value / 1.75;
}

void fragment() {
	vec2 direction = drift_direction;
	float direction_length = max(length(direction), 0.001);
	direction /= direction_length;

	vec2 animated_position = UV * pattern_scale + seed_offset + direction * TIME * drift_speed;
	float noise_value = fractal_noise(animated_position);
	float mottle = smoothstep(threshold - softness, threshold + softness, noise_value);
	float depth_fade = mix(1.0 - depth_strength, 1.0, UV.y);
	float alpha = mottle * depth_fade * opacity;

	COLOR = vec4(noise_color.rgb, alpha);
}
