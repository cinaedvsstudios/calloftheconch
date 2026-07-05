shader_type canvas_item;
render_mode unshaded;

// ShadowSprite's ShaderMaterial owns every adjustable appearance value.
uniform vec4 shadow_color : source_color;
uniform float core_radius : hint_range(0.0, 16.0, 0.1);
uniform float core_opacity : hint_range(0.0, 1.0, 0.01);
uniform float soft_radius : hint_range(0.0, 32.0, 0.1);
uniform float soft_opacity : hint_range(0.0, 1.0, 0.01);

const int DIRECTION_COUNT = 16;
const int SOFT_STEPS = 4;

void fragment() {
	float source_alpha = texture(TEXTURE, UV).a;
	float core_alpha = 0.0;
	float soft_alpha = 0.0;

	for (int direction_index = 0; direction_index < DIRECTION_COUNT; direction_index++) {
		float angle = TAU * float(direction_index) / float(DIRECTION_COUNT);
		vec2 direction = vec2(cos(angle), sin(angle));

		float core_sample = texture(
			TEXTURE,
			UV + direction * TEXTURE_PIXEL_SIZE * core_radius
		).a;

		core_alpha = max(core_alpha, core_sample);

		for (int step = 1; step <= SOFT_STEPS; step++) {
			float progress = float(step) / float(SOFT_STEPS);
			float distance = mix(core_radius, soft_radius, progress);
			float fade = 1.0 - progress;

			float soft_sample = texture(
				TEXTURE,
				UV + direction * TEXTURE_PIXEL_SIZE * distance
			).a;

			soft_alpha = max(soft_alpha, soft_sample * fade);
		}
	}

	float outside_source = 1.0 - source_alpha;
	float alpha = outside_source * max(
		core_alpha * core_opacity,
		soft_alpha * soft_opacity
	);

	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a);
}
