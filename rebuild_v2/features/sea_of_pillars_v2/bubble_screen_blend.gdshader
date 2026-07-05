shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 video = texture(TEXTURE, UV) * COLOR;
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec3 screened = vec3(1.0) - (vec3(1.0) - scene) * (vec3(1.0) - video.rgb);
	COLOR = vec4(screened, 1.0);
}
