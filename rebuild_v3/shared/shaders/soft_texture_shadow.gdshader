shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.03, 0.07, 0.11, 0.75);
uniform float blur_radius : hint_range(0.0, 8.0, 0.25) = 4.0;
uniform vec2 shadow_offset = vec2(3.0, 4.0);

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 sample_uv = UV - shadow_offset * pixel;
	float alpha_sum = 0.0;
	float sample_count = 0.0;

	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 spread = vec2(float(x), float(y)) * pixel * (blur_radius / 3.0);
			alpha_sum += texture(TEXTURE, sample_uv + spread).a;
			sample_count += 1.0;
		}
	}

	float blurred_alpha = alpha_sum / sample_count;
	COLOR = vec4(shadow_color.rgb, blurred_alpha * shadow_color.a);
}
