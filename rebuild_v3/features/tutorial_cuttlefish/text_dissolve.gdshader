shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.25) = 0.07;
uniform float background_brightness : hint_range(0.5, 1.5) = 1.0;

float random_value(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	vec2 cells = floor(UV * vec2(240.0, 90.0));
	float noise_value = random_value(cells);
	float threshold = 1.0 - reveal;
	float dissolve_mask = smoothstep(threshold - softness, threshold + softness, noise_value);
	vec3 ocean_colour = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float outline_pass = step(2.85, COLOR.r + COLOR.g + COLOR.b);
	vec3 text_colour = mix(ocean_colour * background_brightness, vec3(1.0), outline_pass);
	COLOR = vec4(text_colour, glyph.a * dissolve_mask);
}
