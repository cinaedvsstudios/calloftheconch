shader_type canvas_item;
render_mode unshaded, blend_add;

// Removes the dark OGV background before adding the bright effect pixels.
// Adjust these in the ShaderMaterial Inspector if needed.
uniform float black_level : hint_range(0.0, 1.0) = 0.55;
uniform float brightness : hint_range(0.0, 4.0) = 1.50;

void fragment() {
	vec3 video = texture(TEXTURE, UV).rgb * COLOR.rgb;
	vec3 cleaned = max(video - vec3(black_level), vec3(0.0));
	cleaned /= max(1.0 - black_level, 0.001);
	COLOR = vec4(cleaned * brightness, 1.0);
}
