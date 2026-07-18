shader_type canvas_item;

uniform float strength: hint_range(0.0, 1.0) = 0.0;
uniform float seed: hint_range(0.01, 1.0) = 0.5;
uniform vec2 direction = vec2(0.0, -0.22);
uniform float mask_vignette_strength: hint_range(0.0, 1.0) = 0.42;
uniform vec2 mask_vignette_center = vec2(0.5, 0.45);

float pickup_random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 offset = vec2(
		pickup_random(UV * seed),
		pickup_random((UV + vec2(0.19, 0.37)) * seed)
	);
	offset.x = clamp(offset.x, 0.0, 0.52);
	offset.y = clamp(offset.y, 0.0, 1.35);

	vec2 offset_uv = UV + offset * strength + direction * strength;
	vec4 source_color = texture(TEXTURE, offset_uv);
	float circle_clip = distance(UV, mask_vignette_center);
	float dust_cut = clamp(offset.x * strength, 0.0, 3.0);
	float dissolve_alpha = source_color.a - dust_cut - strength;
	dissolve_alpha -= circle_clip * strength * mask_vignette_strength * 3.0;

	COLOR = source_color;
	COLOR.a = clamp(dissolve_alpha, 0.0, source_color.a);
}
