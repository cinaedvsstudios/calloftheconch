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

// Animation
uniform float drift_speed_x : hint_range(-0.20, 0.20, 0.001) = 0.01;
uniform float drift_speed_y : hint_range(-0.20, 0.20, 0.001) = 0.002;

uniform float warp_strength_x : hint_range(0.0, 0.20, 0.001) = 0.015;
uniform float warp_strength_y : hint_range(0.0, 0.20, 0.001) = 0.006;

uniform float warp_frequency_x : hint_range(0.0, 30.0, 0.1) = 6.0;
uniform float warp_frequency_y : hint_range(0.0, 30.0, 0.1) = 3.5;
uniform float warp_speed : hint_range(0.0, 5.0, 0.01) = 0.35;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	// Animate the tiled texture coordinates
	vec2 animated_uv = UV;

	animated_uv += vec2(drift_speed_x, drift_speed_y) * TIME;

	animated_uv.x += sin((UV.y * warp_frequency_x) + TIME * warp_speed) * warp_strength_x;
	animated_uv.y += sin((UV.x * warp_frequency_y) + TIME * warp_speed * 0.8) * warp_strength_y;

	vec4 overlay = texture(TEXTURE, animated_uv) * COLOR * tint;
	vec3 background = texture(screen_texture, SCREEN_UV).rgb;

	float brightest_channel = max(max(overlay.r, overlay.g), overlay.b);

	float visible_mask = smoothstep(
		black_threshold,
		black_threshold + black_softness,
		brightest_channel
	) * overlay.a;

	// Keep the working fade based on the TextureRect's local height
	float box_v = clamp(local_y / 1179.5, 0.0, 1.0);
	float vertical_fade = 1.0 - smoothstep(0.0, 0.5, box_v);

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