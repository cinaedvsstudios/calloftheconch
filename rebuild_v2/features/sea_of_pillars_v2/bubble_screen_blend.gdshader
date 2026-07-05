shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float dark_cutoff : hint_range(0.0, 1.0) = 0.28;
uniform float soft_edge : hint_range(0.001, 1.0) = 0.10;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	vec4 video = texture(TEXTURE, UV) * COLOR;
	float light = max(video.r, max(video.g, video.b));
	float mask = smoothstep(dark_cutoff, dark_cutoff + soft_edge, light);

	COLOR = vec4(video.rgb * brightness, mask);
}