shader_type canvas_item;

uniform vec2 hylas_world_position = vec2(-100000.0, -100000.0);
uniform vec2 hylas_half_size = vec2(92.0, 55.0);
uniform float hylas_world_rotation = 0.0;
uniform float overlap_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.12;

varying vec2 fragment_world_position;


void vertex() {
	fragment_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


float get_hylas_overlap(vec2 world_position) {
	vec2 delta = world_position - hylas_world_position;
	float cosine = cos(-hylas_world_rotation);
	float sine = sin(-hylas_world_rotation);
	vec2 local_delta = vec2(
		cosine * delta.x - sine * delta.y,
		sine * delta.x + cosine * delta.y
	);
	vec2 safe_half_size = max(hylas_half_size, vec2(1.0));
	float ellipse_distance = length(local_delta / safe_half_size);
	float inner_edge = max(0.0, 1.0 - edge_softness);
	return 1.0 - smoothstep(inner_edge, 1.0, ellipse_distance);
}


void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float overlap = get_hylas_overlap(fragment_world_position);
	source.a *= mix(1.0, overlap_opacity, overlap);
	COLOR = source;
}
