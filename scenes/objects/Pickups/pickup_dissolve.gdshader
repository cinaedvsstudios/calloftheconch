shader_type canvas_item;

uniform float strength: hint_range(0.0, 1.0) = 0.0;
uniform float seed: hint_range(0.01, 1.0) = 0.5;
uniform vec2 direction = vec2(0.0, -0.22);
uniform float mask_vignette_strength: hint_range(0.0, 1.0) = 0.42;
uniform vec2 mask_vignette_center = vec2(0.5, 0.45);

uniform vec4 shine_color: source_color = vec4(0.20, 1.0, 1.0, 1.0);
uniform float shine_strength: hint_range(0.0, 2.0) = 0.86;
uniform float shine_width: hint_range(0.01, 0.5) = 0.15;
uniform float shine_progress: hint_range(-1.0, 2.0) = -1.0;

uniform vec4 flash_color: source_color = vec4(0.12, 1.0, 1.0, 1.0);
uniform float flash_strength: hint_range(0.0, 1.0) = 0.0;

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
	vec4 sampled_color = texture(TEXTURE, offset_uv);
	float circle_clip = distance(UV, mask_vignette_center);
	float dust_cut = clamp(offset.x * strength, 0.0, 3.0);
	float dissolve_alpha = sampled_color.a - dust_cut - strength;
	dissolve_alpha -= circle_clip * strength * mask_vignette_strength * 3.0;

	float diagonal_coordinate = (UV.x + UV.y) * 0.5;
	float distance_from_shine = abs(diagonal_coordinate - shine_progress);
	float normalized_shine_distance = distance_from_shine / max(shine_width, 0.001);
	float shine_gradient = exp(-4.0 * normalized_shine_distance * normalized_shine_distance);
	float shine_mix = clamp(
		shine_gradient * shine_strength * shine_color.a * sampled_color.a,
		0.0,
		1.0
	);
	vec3 shine_target = max(sampled_color.rgb, shine_color.rgb);
	sampled_color.rgb = mix(sampled_color.rgb, shine_target, shine_mix);

	float flash_mix = clamp(flash_strength * flash_color.a, 0.0, 1.0);
	vec3 bright_flash = max(sampled_color.rgb, flash_color.rgb);
	sampled_color.rgb = mix(sampled_color.rgb, bright_flash, flash_mix);

	COLOR = sampled_color;
	COLOR.a = clamp(dissolve_alpha, 0.0, sampled_color.a);
}
