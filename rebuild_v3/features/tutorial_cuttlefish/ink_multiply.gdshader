shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float black_point : hint_range(0.0, 0.5) = 0.08;
uniform float white_point : hint_range(0.5, 1.0) = 0.94;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float neutralized = smoothstep(black_point, white_point, luminance);
	float multiplier = mix(1.0, neutralized, opacity * source.a);
	COLOR = vec4(vec3(multiplier), 1.0);
}
