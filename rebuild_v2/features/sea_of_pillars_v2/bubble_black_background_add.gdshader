shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float dark_cutoff : hint_range(0.0, 1.0) = 0.10;
uniform float soft_edge : hint_range(0.001, 1.0) = 0.18;
uniform float brightness : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	vec4 video = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(video.rgb, vec3(0.2126, 0.7152, 0.0722));
	float visible_amount = smoothstep(dark_cutoff, dark_cutoff + soft_edge, luminance);
	COLOR = vec4(video.rgb * visible_amount * brightness, visible_amount);
}
