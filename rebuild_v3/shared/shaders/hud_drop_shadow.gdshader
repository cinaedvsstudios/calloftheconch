shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.62);
uniform float blur_radius : hint_range(0.0, 10.0, 0.5) = 5.0;

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	float accumulated_alpha = 0.0;
	float accumulated_weight = 0.0;

	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float distance_squared = float(x * x + y * y);
			float weight = exp(-distance_squared / 7.0);
			vec2 sample_uv = UV + vec2(float(x), float(y)) * pixel_size * blur_radius;
			float sample_alpha = 0.0;
			if (
				sample_uv.x >= 0.0
				&& sample_uv.x <= 1.0
				&& sample_uv.y >= 0.0
				&& sample_uv.y <= 1.0
			) {
				sample_alpha = texture(TEXTURE, sample_uv).a;
			}
			accumulated_alpha += sample_alpha * weight;
			accumulated_weight += weight;
		}
	}

	float blurred_alpha = accumulated_alpha / max(accumulated_weight, 0.0001);
	COLOR = vec4(shadow_color.rgb, blurred_alpha * shadow_color.a);
}
