shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float cut_off : hint_range(0.0, 1.0) = 0.01;
uniform float fade_width : hint_range(0.001, 1.0) = 0.08;
uniform float brightness : hint_range(0.0, 8.0) = 5.0;

void fragment() {
	vec3 video = texture(TEXTURE, UV).rgb * COLOR.rgb;
	float light = max(video.r, max(video.g, video.b));
	float visible_mask = smoothstep(cut_off, cut_off + fade_width, light);
	COLOR = vec4(video * visible_mask * brightness, 1.0);
}
