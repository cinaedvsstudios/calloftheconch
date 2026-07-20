shader_type canvas_item;
render_mode unshaded, blend_add;

const float TWO_PI = 6.28318530718;

uniform vec4 outer_color : source_color = vec4(0.20, 0.48, 0.78, 1.0);
uniform vec4 inner_color : source_color = vec4(0.58, 0.82, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 2.0) = 0.72;
uniform float rotation_speed : hint_range(-4.0, 4.0) = 0.42;
uniform float turns : hint_range(1.0, 14.0) = 7.0;
uniform float strand_thickness : hint_range(0.002, 0.12) = 0.018;
uniform float funnel_curve : hint_range(0.25, 3.0) = 1.15;
uniform float water_wobble : hint_range(0.0, 0.25) = 0.045;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float depth = clamp(UV.y, 0.0, 1.0);
	float funnel_width = mix(0.95, 0.055, pow(depth, funnel_curve));
	float edge = 1.0 - smoothstep(funnel_width, funnel_width + 0.08, abs(p.x));
	float vertical_fade = smoothstep(0.0, 0.09, depth) * (1.0 - smoothstep(0.92, 1.0, depth));
	float wobble = sin(depth * 17.0 + TIME * 0.55) * water_wobble;
	float strand_alpha = 0.0;

	for (int strand_index = 0; strand_index < 7; strand_index++) {
		float phase = float(strand_index) / 7.0 * TWO_PI;
		float center_x = sin(
			depth * turns * TWO_PI
			- TIME * rotation_speed * TWO_PI
			+ phase
		) * funnel_width * 0.79 + wobble;
		float strand_distance = abs(p.x - center_x);
		float strand = 1.0 - smoothstep(
			strand_thickness,
			strand_thickness * 3.2,
			strand_distance
		);
		strand_alpha = max(strand_alpha, strand);
	}

	float cross_rings = 1.0 - smoothstep(
		0.025,
		0.085,
		abs(sin((depth * turns * 0.72 - TIME * rotation_speed) * TWO_PI))
	);
	cross_rings *= 0.28 * edge;

	float alpha = clamp(
		(strand_alpha + cross_rings) * edge * vertical_fade * opacity,
		0.0,
		1.0
	);
	vec3 colour = mix(outer_color.rgb, inner_color.rgb, pow(depth, 1.35));
	COLOR = vec4(colour, alpha);
}
