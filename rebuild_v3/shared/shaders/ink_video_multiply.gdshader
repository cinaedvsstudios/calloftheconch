shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform float strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float contrast : hint_range(0.25, 3.0, 0.05) = 1.15;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 contrasted = clamp((source.rgb - vec3(0.5)) * contrast + vec3(0.5), vec3(0.0), vec3(1.0));
	float opacity = clamp(source.a * COLOR.a * strength, 0.0, 1.0);
	vec3 multiplier = mix(vec3(1.0), contrasted, opacity);
	COLOR = vec4(multiplier, 1.0);
}
