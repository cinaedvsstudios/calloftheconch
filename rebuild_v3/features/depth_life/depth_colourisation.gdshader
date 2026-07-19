shader_type canvas_item;

uniform sampler2D colour_map_a : filter_linear_mipmap, repeat_disable;
uniform sampler2D colour_map_b : filter_linear_mipmap, repeat_disable;
uniform float map_blend : hint_range(0.0, 1.0) = 0.0;
uniform float colour_strength : hint_range(0.0, 1.0) = 0.88;
uniform float saturation_multiplier : hint_range(0.0, 2.5) = 1.0;
uniform float brightness_multiplier : hint_range(0.0, 2.5) = 1.0;


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

	COLOR = vec4(
		mix(source.rgb, colourised, clamp(colour_strength, 0.0, 1.0)),
		source.a
	);
}
