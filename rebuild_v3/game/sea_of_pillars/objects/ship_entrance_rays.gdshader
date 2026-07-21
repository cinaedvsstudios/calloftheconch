shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 ray_colour : source_color = vec4(0.48, 0.84, 1.0, 0.34);
uniform float overall_strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.01, 0.30) = 0.105;
uniform float bottom_fade_start : hint_range(0.2, 0.95) = 0.63;

float beam_mask(
		vec2 uv,
		float centre,
		float top_half_width,
		float bottom_half_width,
		float drift,
		float softness
	) {
	float beam_centre = centre + drift * uv.y;
	float half_width = mix(top_half_width, bottom_half_width, smoothstep(0.0, 1.0, uv.y));
	float distance_from_centre = abs(uv.x - beam_centre);
	return 1.0 - smoothstep(
		max(0.0, half_width - softness),
		half_width + softness,
		distance_from_centre
	);
}

void fragment() {
	vec2 uv = UV;
	float top_fade = smoothstep(0.0, 0.055, uv.y);
	float bottom_fade = 1.0 - smoothstep(bottom_fade_start, 1.0, uv.y);
	float vertical_fade = top_fade * bottom_fade;

	float broad = beam_mask(uv, 0.50, 0.105, 0.455, 0.0, edge_softness) * 0.42;
	float left = beam_mask(uv, 0.39, 0.032, 0.145, -0.035, edge_softness * 0.72) * 0.22;
	float centre = beam_mask(uv, 0.50, 0.026, 0.105, 0.0, edge_softness * 0.64) * 0.20;
	float right = beam_mask(uv, 0.61, 0.032, 0.145, 0.035, edge_softness * 0.72) * 0.22;

	float soft_body = clamp(broad + left + centre + right, 0.0, 1.0);
	float depth_falloff = mix(1.0, 0.64, smoothstep(0.0, 1.0, uv.y));
	float alpha = soft_body * vertical_fade * depth_falloff * ray_colour.a * overall_strength;
	COLOR = vec4(ray_colour.rgb, alpha);
}
