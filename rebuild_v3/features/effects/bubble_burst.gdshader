shader_type canvas_item;
render_mode unshaded, blend_add;

// Each VideoStreamPlayer material owns these appearance values.
uniform float cut_off : hint_range(0.0, 1.0);
uniform float fade_width : hint_range(0.001, 1.0);
uniform float brightness : hint_range(3.0, 6.0);

void fragment() {
	vec3 video = texture(TEXTURE, UV).rgb * COLOR.rgb;
	float light = max(video.r, max(video.g, video.b));
	float bubble_mask = smoothstep(cut_off, cut_off + fade_width, light);
	COLOR = vec4(video * bubble_mask * brightness, 1.0);
}
