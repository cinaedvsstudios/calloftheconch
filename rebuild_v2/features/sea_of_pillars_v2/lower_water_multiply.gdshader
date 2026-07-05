shader_type canvas_item;
render_mode unshaded, blend_mul;

uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float fade_end : hint_range(0.0, 1.0) = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float fade = 1.0 - smoothstep(fade_start, fade_end, UV.x);
	float alpha = tex.a * fade * strength;

	vec3 rgb = mix(vec3(1.0), tex.rgb, alpha);

	COLOR = vec4(rgb, alpha);
}