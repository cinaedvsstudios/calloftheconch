shader_type canvas_item;
render_mode unshaded, blend_mul;

// The shared material in SeaOfPillarsV2 owns the strength value.
uniform float strength : hint_range(0.0, 1.0);

void fragment() {
	vec4 overlay = texture(TEXTURE, UV);
	float amount = overlay.a * COLOR.a * strength;
	vec3 darkening = mix(vec3(1.0), overlay.rgb * COLOR.rgb, amount);
	COLOR = vec4(darkening, 1.0);
}
