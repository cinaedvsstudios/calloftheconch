shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(1.0, 0.34, 0.08, 0.9);
uniform float outline_pixels : hint_range(0.5, 4.0, 0.25) = 1.25;
uniform float pulse_speed : hint_range(0.1, 12.0, 0.1) = 3.2;
uniform float body_glow_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float point_glow_strength : hint_range(0.0, 2.0, 0.01) = 0.34;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_pixels;
	float surrounding_alpha = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			surrounding_alpha = max(
				surrounding_alpha,
				texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a
			);
		}
	}

	float outline_alpha = max(surrounding_alpha - base.a, 0.0);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float point_band = smoothstep(0.66, 1.0, UV.x);
	float point_center = 1.0 - smoothstep(0.08, 0.34, abs(UV.y - 0.5));
	float point_mask = point_band * point_center * base.a;

	vec3 orange = outline_color.rgb;
	vec3 lit_base = base.rgb + orange * base.a * body_glow_strength * pulse;
	lit_base += orange * point_mask * point_glow_strength * (0.45 + 0.55 * pulse);
	vec3 final_rgb = mix(lit_base, orange, outline_alpha);
	float final_alpha = max(base.a, outline_alpha * outline_color.a);
	COLOR = vec4(final_rgb, final_alpha);
}
