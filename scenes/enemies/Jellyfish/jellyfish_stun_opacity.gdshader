shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(0.0, 0.82, 1.0, 1.0);
uniform float stunned_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float pulse_speed : hint_range(0.1, 12.0, 0.1) = 4.5;
uniform float glow_strength : hint_range(0.0, 3.0, 0.05) = 1.25;
uniform float glow_radius : hint_range(0.0, 12.0, 0.5) = 5.0;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.4;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float base_alpha = source.a * opacity;

	if (stunned_amount <= 0.001) {
		COLOR = vec4(source.rgb, base_alpha);
		return;
	}

	float nearby_alpha = 0.0;
	vec2 horizontal = vec2(TEXTURE_PIXEL_SIZE.x * glow_radius, 0.0);
	vec2 vertical = vec2(0.0, TEXTURE_PIXEL_SIZE.y * glow_radius);
	vec2 diagonal = vec2(TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y) * glow_radius * 0.70710678;

	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + horizontal).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - horizontal).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vertical).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vertical).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + diagonal).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - diagonal).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(diagonal.x, -diagonal.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-diagonal.x, diagonal.y)).a);

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float active_pulse = stunned_amount * mix(0.45, 1.0, pulse);
	float outline_alpha = max(0.0, nearby_alpha - source.a) * active_pulse * glow_strength * opacity;
	float body_tint = base_alpha * active_pulse * 0.58;

	vec3 brightened_source = source.rgb + glow_color.rgb * body_tint;
	vec3 final_rgb = mix(brightened_source, glow_color.rgb, clamp(outline_alpha, 0.0, 1.0));
	float final_alpha = max(base_alpha, outline_alpha * glow_color.a);

	COLOR = vec4(final_rgb, final_alpha);
}