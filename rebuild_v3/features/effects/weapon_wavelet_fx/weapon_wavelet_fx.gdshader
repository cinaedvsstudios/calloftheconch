shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progression : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.72;
uniform float thickness : hint_range(0.01, 1.0) = 0.12;
uniform float wavelet_factor : hint_range(0.1, 4.0) = 3.0;
uniform float deformation_length = 6.0;

const float PI = 3.14159265358979323846;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float centered_length = length(centered);
	if (centered_length <= 0.0001) {
		discard;
	}

	float distance_from_center = centered_length * 2.0;
	float wave_progress = progression * (1.0 - thickness - 0.01);
	float distortion = clamp(
		(distance_from_center - wave_progress) / thickness,
		-1.0,
		1.0
	);
	distortion = mix(
		cos(distortion * (PI / wavelet_factor)),
		0.0,
		step(0.99, abs(distortion))
	);
	if (abs(distortion) <= 0.01) {
		discard;
	}

	float fade_alpha = mix(
		1.0,
		smoothstep(
			1.0,
			0.0,
			(progression - fade) / max(0.0001, 1.0 - fade)
		),
		step(fade, progression)
	);
	vec2 deformation = (
		normalize(centered)
		* distortion
		* deformation_length
		* SCREEN_PIXEL_SIZE
	);
	vec2 source_uv = clamp(
		SCREEN_UV + deformation,
		vec2(0.0),
		vec2(1.0)
	);
	vec4 displaced_screen = texture(screen_texture, source_uv);
	COLOR = vec4(displaced_screen.rgb, displaced_screen.a * fade_alpha);
}
