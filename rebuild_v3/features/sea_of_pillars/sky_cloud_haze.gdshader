shader_type canvas_item;
render_mode unshaded;

uniform vec4 haze_color : source_color = vec4(0.93, 0.99, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 0.20, 0.001) = 0.035;
uniform float drift_speed : hint_range(0.0, 0.08, 0.001) = 0.006;
uniform float pattern_scale : hint_range(0.25, 5.0, 0.01) = 1.10;

float cloud_field(vec2 sample_position: vec2) {
	float large_shape: float = sin(sample_position.x * 2.1 + sin(sample_position.y * 2.8));
	float medium_shape: float = sin(sample_position.x * 4.6 - sample_position.y * 1.3);
	float fine_shape: float = sin(sample_position.x * 8.4 + sample_position.y * 2.1);
	return large_shape * 0.48 + medium_shape * 0.34 + fine_shape * 0.18;
}

void fragment() {
	vec2 sample_position: vec2 = SCREEN_UV * vec2(3.2, 1.35) * pattern_scale;
	sample_position.x += TIME * drift_speed;

	float cloud_mask: float = smoothstep(0.23, 0.83, cloud_field(sample_position));
	float horizon_fade: float = 1.0 - smoothstep(0.48, 1.0, UV.y);
	float alpha: float = cloud_mask * horizon_fade * opacity;
	COLOR = vec4(haze_color.rgb, alpha);
}
