shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 glow_color : source_color = vec4(0.12, 0.95, 1.0, 1.0);
uniform float body_brightness : hint_range(0.5, 3.0, 0.05) = 1.22;
uniform float glow_strength : hint_range(0.0, 5.0, 0.05) = 1.8;
uniform float glow_radius : hint_range(0.0, 14.0, 0.5) = 5.0;
uniform float pulse_speed : hint_range(0.0, 10.0, 0.05) = 4.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec2 pixel = TEXTURE_PIXEL_SIZE * glow_radius;
	float neighbour_alpha = 0.0;
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(UV + vec2(pixel.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(UV - vec2(pixel.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(UV + vec2(0.0, pixel.y), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(UV - vec2(0.0, pixel.y), vec2(0.0), vec2(1.0))).a);
	float outline = max(0.0, neighbour_alpha - source.a);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed * 6.28318530718);
	vec3 body = source.rgb * body_brightness + glow_color.rgb * source.a * 0.16 * pulse;
	vec3 glow = glow_color.rgb * outline * glow_strength * pulse;
	COLOR = vec4(body + glow, max(source.a, outline * glow_color.a));
}
