shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 0.25) = 0.07;

float random_value(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	vec2 cells = floor(UV * vec2(240.0, 90.0));
	float noise_value = random_value(cells);
	float threshold = 1.0 - reveal;
	float dissolve_mask = smoothstep(threshold - softness, threshold + softness, noise_value);

	// Preserve the Label's cyan fill, white outline and cyan shadow/glow colours.
	COLOR = vec4(glyph.rgb, glyph.a * dissolve_mask);
}
