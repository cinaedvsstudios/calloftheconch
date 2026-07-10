shader_type canvas_item;
render_mode unshaded, blend_add;

// Each VideoStreamPlayer material owns these appearance values.
uniform float cut_off : hint_range(0.0, 1.0);
uniform float fade_width : hint_range(0.001, 1.0);
uniform float brightness : hint_range(3.0, 6.0);

// Screen-space waterline mask. A value below 0.0 leaves the full overlay visible,
// which keeps menu instances of this shader unchanged.
uniform float waterline_screen_y = -1.0;
uniform float waterline_fade : hint_range(0.001, 0.1, 0.001) = 0.012;

void fragment() {
	vec3 video = texture(TEXTURE, UV).rgb * COLOR.rgb;
	float light = max(video.r, max(video.g, video.b));
	float bubble_mask = smoothstep(cut_off, cut_off + fade_width, light);
	float underwater_mask = smoothstep(
		waterline_screen_y,
		waterline_screen_y + waterline_fade,
		UV.y
	);
	float final_mask = bubble_mask * underwater_mask;
	COLOR = vec4(video * final_mask * brightness, 1.0);
}
