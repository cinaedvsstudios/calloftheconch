shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.34, 0.04, 0.72);
uniform float outline_pixels : hint_range(0.5, 5.0, 0.25) = 1.5;
uniform float silhouette_strength : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float point_strength : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float pulse_speed : hint_range(0.1, 10.0, 0.1) = 3.8;

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_pixels;
	float centre_alpha = texture(TEXTURE, UV).a;
	float surrounding_alpha = centre_alpha;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + pixel).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - pixel).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);

	float outline_alpha = max(surrounding_alpha - centre_alpha, 0.0);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	float point_mask = smoothstep(0.62, 1.0, UV.x) * smoothstep(0.44, 0.08, abs(UV.y - 0.5));
	float glow_alpha = outline_alpha * 0.78;
	glow_alpha += centre_alpha * silhouette_strength;
	glow_alpha += centre_alpha * point_mask * point_strength * (0.75 + 0.25 * sin(TIME * pulse_speed * 1.35));
	COLOR = vec4(glow_color.rgb, glow_alpha * glow_color.a * pulse * COLOR.a);
}
