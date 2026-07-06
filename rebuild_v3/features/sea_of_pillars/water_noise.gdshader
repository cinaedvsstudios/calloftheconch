shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 mottle_color : source_color = vec4(0.015, 0.20, 0.34, 1.0);
uniform float opacity : hint_range(0.0, 0.30, 0.001) = 0.09;
uniform float drift_speed : hint_range(0.0, 0.08, 0.001) = 0.006;
uniform vec2 pattern_scale = vec2(330.0, 88.0);
uniform vec2 drift_direction = vec2(0.78, 0.18);
uniform vec2 seed_offset = vec2(0.0, 0.0);
uniform float warp_strength : hint_range(0.0, 2.0, 0.001) = 0.72;
uniform float coverage : hint_range(0.0, 1.0, 0.001) = 0.47;
uniform float softness : hint_range(0.01, 0.50, 0.001) = 0.26;
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
	value += value_noise(point * 2.03 + vec2(17.3, 9.2)) * 0.50;
	value += value_noise(point * 4.11 + vec2(4.7, 31.8)) * 0.25;
	return value / 1.75;
}

void fragment() {
	vec2 direction = drift_direction;
	float direction_length = max(length(direction), 0.001);
	direction /= direction_length;

	vec2 position = UV * pattern_scale + seed_offset + direction * TIME * drift_speed;
	vec2 warp = vec2(
		fractal_noise(position * 0.42 + vec2(11.7, 5.4)),
		fractal_noise(position * 0.42 + vec2(37.2, 19.8))
	) - 0.5;
	float mottle_value = fractal_noise(position + warp * warp_strength);
	float mottle = smoothstep(coverage - softness, coverage + softness, mottle_value);
	float depth_fade = mix(1.0 - depth_strength, 1.0, UV.y);
	float alpha = mottle * depth_fade * opacity;

	COLOR = vec4(mottle_color.rgb, alpha);
}
