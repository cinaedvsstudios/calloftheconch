shader_type canvas_item;

uniform sampler2D colour_map_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D colour_map_b : filter_linear_mipmap, repeat_disable;
uniform float map_blend : hint_range(0.0, 1.0) = 0.0;
uniform float colour_strength : hint_range(0.0, 1.0) = 0.88;
uniform float saturation_multiplier : hint_range(0.0, 2.5) = 1.0;
uniform float brightness_multiplier : hint_range(0.0, 2.5) = 1.0;

uniform vec2 hylas_world_position = vec2(-100000.0, -100000.0);
uniform vec2 hylas_half_size = vec2(92.0, 55.0);
uniform float hylas_world_rotation = 0.0;
uniform float overlap_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.12;

varying vec2 fragment_world_position;


void vertex() {
	fragment_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


vec3 rgb_to_hsv(vec3 colour) {
	vec4 k = vec4(0.0, -0.3333333333, 0.6666666667, -1.0);
	vec4 p = mix(
		vec4(colour.bg, k.wz),
		vec4(colour.gb, k.xy),
		step(colour.b, colour.g)
	);
	vec4 q = mix(
		vec4(p.xyw, colour.r),
		vec4(colour.r, p.yzx),
		step(p.x, colour.r)
	);
	float d = q.x - min(q.w, q.y);
	float e = 0.0000001;
	return vec3(
		abs(q.z + (q.w - q.y) / (6.0 * d + e)),
		d / (q.x + e),
		q.x
	);
}


vec3 hsv_to_rgb(vec3 colour) {
	vec3 p = abs(fract(colour.xxx + vec3(0.0, 0.6666666667, 0.3333333333)) * 6.0 - 3.0);
	return colour.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), colour.y);
}


float get_hylas_overlap(vec2 world_position) {
	vec2 delta = world_position - hylas_world_position;
	float cosine = cos(-hylas_world_rotation);
	float sine = sin(-hylas_world_rotation);
	vec2 local_delta = vec2(
		cosine * delta.x - sine * delta.y,
		sine * delta.x + cosine * delta.y
	);
	vec2 safe_half_size = max(hylas_half_size, vec2(1.0));
	float ellipse_distance = length(local_delta / safe_half_size);
	float inner_edge = max(0.0, 1.0 - edge_softness);
	return 1.0 - smoothstep(inner_edge, 1.0, ellipse_distance);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 map_a = texture(colour_map_a, UV).rgb;
	vec3 map_b = texture(colour_map_b, UV).rgb;
	vec3 colour_map = mix(map_a, map_b, clamp(map_blend, 0.0, 1.0));

	vec3 source_hsv = rgb_to_hsv(source.rgb);
	vec3 map_hsv = rgb_to_hsv(colour_map);
	float mapped_value = source_hsv.z * mix(0.82, 1.18, map_hsv.z);
	mapped_value = clamp(mapped_value * brightness_multiplier, 0.0, 1.0);
	float mapped_saturation = clamp(map_hsv.y * saturation_multiplier, 0.0, 1.0);
	vec3 colourised = hsv_to_rgb(vec3(map_hsv.x, mapped_saturation, mapped_value));

	float overlap = get_hylas_overlap(fragment_world_position);
	float final_alpha = source.a * mix(1.0, overlap_opacity, overlap);
	COLOR = vec4(
		mix(source.rgb, colourised, clamp(colour_strength, 0.0, 1.0)),
		final_alpha
	);
}
