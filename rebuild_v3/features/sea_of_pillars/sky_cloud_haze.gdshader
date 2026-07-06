shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 haze_color : source_color = vec4(0.84, 0.95, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 0.3, 0.001) = 0.035;
uniform float drift_speed : hint_range(0.0, 0.08, 0.001) = 0.004;
uniform vec2 pattern_scale = vec2(150.0, 5.0);
uniform float cloud_coverage : hint_range(0.0, 1.0, 0.001) = 0.56;
uniform float softness : hint_range(0.01, 0.5, 0.001) = 0.16;

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
	value += value_noise(point * 2.07 + vec2(19.2, 8.4)) * 0.5;
	value += value_noise(point * 4.13 + vec2(7.1, 29.6)) * 0.25;
	return value / 1.75;
}

void fragment() {
	vec2 drift = vec2(TIME * drift_speed, TIME * drift_speed * 0.18);
	float cloud_noise = layered_noise(UV * pattern_scale + drift);
	float cloud_mask = smoothstep(cloud_coverage - softness, cloud_coverage + softness, cloud_noise);
	float vertical_fade = 1.0 - smoothstep(0.15, 0.96, UV.y);
	float alpha = cloud_mask * vertical_fade * opacity;
	COLOR = vec4(haze_color.rgb, alpha);
}
