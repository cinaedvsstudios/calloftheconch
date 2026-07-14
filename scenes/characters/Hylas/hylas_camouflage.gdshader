shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float warp_strength : hint_range(0.0, 0.05, 0.001) = 0.010;
uniform float warp_speed : hint_range(0.0, 8.0, 0.05) = 2.2;
uniform float opacity_min : hint_range(0.0, 1.0, 0.01) = 0.30;
uniform float opacity_max : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float opacity_pulse_speed : hint_range(0.0, 8.0, 0.05) = 1.8;
uniform float hue_speed : hint_range(-2.0, 2.0, 0.01) = 0.22;
uniform float rainbow_mix : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform vec4 glow_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0, 0.05) = 1.35;
uniform float glow_radius : hint_range(0.0, 12.0, 0.5) = 4.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -0.3333333333, 0.6666666667, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 0.0000001;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 0.6666666667, 0.3333333333)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE * glow_radius;
	float wave_x = sin((UV.y * 11.0 + TIME * warp_speed) * 6.28318530718);
	float wave_y = cos((UV.x * 8.0 - TIME * warp_speed * 0.73) * 6.28318530718);
	vec2 warped_uv = clamp(UV + vec2(wave_x, wave_y) * warp_strength, vec2(0.0), vec2(1.0));
	vec4 source = texture(TEXTURE, warped_uv) * COLOR;

	float neighbour_alpha = 0.0;
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(warped_uv + vec2(pixel.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(warped_uv - vec2(pixel.x, 0.0), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(warped_uv + vec2(0.0, pixel.y), vec2(0.0), vec2(1.0))).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, clamp(warped_uv - vec2(0.0, pixel.y), vec2(0.0), vec2(1.0))).a);
	float outline = max(0.0, neighbour_alpha - source.a);

	vec3 hsv = rgb_to_hsv(max(source.rgb, vec3(0.0001)));
	hsv.x = fract(hsv.x + TIME * hue_speed + UV.y * 0.32);
	vec3 rainbow = hsv_to_rgb(hsv);
	vec3 body_color = mix(source.rgb, rainbow, rainbow_mix);
	vec3 final_color = body_color + glow_color.rgb * outline * glow_strength;

	float pulse = 0.5 + 0.5 * sin(TIME * opacity_pulse_speed * 6.28318530718);
	float body_alpha = source.a * mix(opacity_min, opacity_max, pulse);
	float final_alpha = max(body_alpha, outline * glow_color.a * 0.78);
	COLOR = vec4(final_color, final_alpha);
}
