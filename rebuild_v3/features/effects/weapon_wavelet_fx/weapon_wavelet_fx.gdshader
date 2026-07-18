shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progression : hint_range(0.0, 1.0) = 0.5;
uniform float fade : hint_range(0.0, 1.0) = 0.84;
uniform float opacity : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.01, 1.0) = 0.1;
uniform float wavelet_factor : hint_range(0.1, 4.0) = 4.0;
uniform float deformation_length = 16.0;
uniform vec2 screen_pos = vec2(0.0);
uniform vec2 screen_size = vec2(0.0);

void fragment() {
	vec2 norm = normalize(UV - vec2(0.5));
	float dist = distance(UV, vec2(0.5)) * 2.0;
	float prog = progression * (1.0 - thickness - 0.01);
	float distortion = clamp((dist - prog) / thickness, -1.0, 1.0);
	distortion = mix(
		cos(distortion * (PI / wavelet_factor)),
		0.0,
		step(0.99, abs(distortion))
	);
	vec2 def = distortion * deformation_length * SCREEN_PIXEL_SIZE;
	vec2 offset_vector = norm * def;
	vec2 target_uv = screen_pos + ((UV + offset_vector) * screen_size);
	target_uv.y = 1.0 - target_uv.y;
	float fade_alpha = 1.0 - smoothstep(fade, 1.0, progression);
	COLOR = mix(
		vec4(0.0),
		vec4(texture(screen_texture, target_uv).rgb, opacity * fade_alpha),
		step(0.01, distortion)
	);
}
