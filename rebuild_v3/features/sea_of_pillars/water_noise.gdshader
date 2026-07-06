shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 noise_color : source_color = vec4(0.24, 0.72, 0.92, 1.0);
uniform float opacity : hint_range(0.0, 0.35, 0.001) = 0.05;
uniform float drift_speed : hint_range(0.0, 0.25, 0.001) = 0.008;
uniform vec2 pattern_scale = vec2(220.0, 55.0);
uniform float contrast : hint_range(0.0, 1.0, 0.001) = 0.48;
uniform vec2 drift_direction = vec2(0.8, 0.22);
uniform float depth_strength : hint_range(0.0, 1.0, 0.001) = 0.35;

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

float layered_noise(vec2 point) {
	float value = value_noise(point);
	value += value_noise(point * 2.03 + vec2(17.3, 9.2)) * 0.5;
	value += value_noise(point * 4.11 + vec2(4.7, 31.8)) * 0.25;
	return value / 1.75;
}

void fragment() {
	vec2 direction = normalize(drift_direction);
	vec2 animated_position = UV * pattern_scale + direction * TIME * drift_speed;
	float noise_value = layered_noise(animated_position);
	float noise_mask = smoothstep(contrast, 1.0, noise_value);
	float depth_mask = mix(1.0 - depth_strength, 1.0, UV.y);
	float alpha = noise_mask * depth_mask * opacity;
	COLOR = vec4(noise_color.rgb, alpha);
}
