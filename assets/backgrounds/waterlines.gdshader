shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform int blend_mode : hint_enum("Screen", "Add", "Lighten") = 0;

uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float strength : hint_range(0.0, 4.0, 0.01) = 1.0;

uniform float brightness : hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float lightness : hint_range(-1.0, 1.0, 0.01) = 0.0;

uniform vec4 tint : source_color = vec4(1.0);

uniform float black_threshold : hint_range(0.0, 0.25, 0.001) = 0.008;
uniform float black_softness : hint_range(0.001, 0.25, 0.001) = 0.025;

uniform float waterlines_height : hint_range(1.0, 10000.0, 0.5) = 1179.5;
uniform float fade_start : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float fade_end : hint_range(0.0, 1.0, 0.01) = 1.00;

varying float waterlines_local_y;

void vertex() {
	waterlines_local_y = VERTEX.y;
}

void fragment() {
	vec4 overlay = texture(TEXTURE, UV) * COLOR * tint;
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;

	float brightest_channel = max(max(overlay.r, overlay.g), overlay.b);

	float visible_mask = smoothstep(
		black_threshold,
		black_threshold + black_softness,
		brightest_channel
	) * overlay.a;

	float box_v = clamp(
		waterlines_local_y / max(waterlines_height, 1.0),
		0.0,
		1.0
	);

	float safe_fade_end = max(fade_start + 0.05, fade_end);
	float vertical_fade = 1.0 - smoothstep(
		fade_start,
		safe_fade_end,
		box_v
	);

	visible_mask *= vertical_fade;

	vec3 source = overlay.rgb;

	source += vec3(brightness * visible_mask);

	if (lightness > 0.0) {
		source = mix(source, vec3(1.0), lightness);
	} else {
		source *= 1.0 + lightness;
	}

	source *= strength;

	vec3 result = background;

	if (blend_mode == 0) {
		vec3 clamped_source = clamp(source, vec3(0.0), vec3(1.0));
		result = vec3(1.0) - (vec3(1.0) - background) * (vec3(1.0) - clamped_source);
	} else if (blend_mode == 1) {
		result = background + source;
	} else {
		result = max(background, source);
	}

	COLOR = vec4(mix(background, result, visible_mask * opacity), 1.0);
}
