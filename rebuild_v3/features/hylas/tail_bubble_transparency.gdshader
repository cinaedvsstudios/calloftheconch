shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float black_cutoff : hint_range(0.0, 0.30, 0.001) = 0.01;
uniform float edge_softness : hint_range(0.001, 0.50, 0.001) = 0.10;
uniform float brightness : hint_range(0.1, 6.0, 0.01) = 4.0;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 video_colour = source.rgb * COLOR.rgb;

	float lightness = max(
		video_colour.r,
		max(video_colour.g, video_colour.b)
	);

	float bubble_mask = smoothstep(
		black_cutoff,
		black_cutoff + edge_softness,
		lightness
	);

	COLOR = vec4(
		video_colour * bubble_mask * brightness * opacity,
		1.0
	);
}