shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float fade_end : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 overlay = texture(TEXTURE, UV);

	float fade = smoothstep(fade_start, fade_end, UV.x);
	float amount = overlay.a * COLOR.a * strength * fade;

	vec3 darkening = mix(
		vec3(1.0),
		overlay.rgb * COLOR.rgb,
		amount
	);

	COLOR = vec4(darkening, 1.0);
}