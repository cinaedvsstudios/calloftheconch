shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform vec4 mottle_color : source_color = vec4(0.015, 0.1, 0.30, 1.0);
uniform float opacity : hint_range(0.0, 2., 0.001) = 0.6;
uniform vec2 tile_count = vec2(48.0, 28.0);
uniform vec2 flow_a = vec2(0.007, 0.015);
uniform vec2 flow_b = vec2(-0.004, 0.03);
uniform float evolution_speed : hint_range(0.0, 2.0, 0.001) = 0.5;
uniform float threshold : hint_range(0.0, 1.0, 0.001) = 0.54;
uniform float softness : hint_range(0.01, 0.50, 0.001) = 0.4;
uniform float depth_strength : hint_range(0.0, 1.0, 0.001) = 0.16;
uniform bool mati_use_manual_time = false;
uniform float mati_manual_time = 0.0;

void fragment() {
	float animation_time = mati_use_manual_time ? mati_manual_time : TIME;
	vec2 cloud_uv_a = UV * tile_count + flow_a * animation_time;
	vec2 cloud_uv_b = UV * tile_count * 0.73 + vec2(0.317, 0.683) + flow_b * animation_time;

	float cloud_a = texture(cloud_noise, cloud_uv_a).r;
	float cloud_b = texture(cloud_noise, cloud_uv_b).r;
	float blend_amount = 0.36 + sin(animation_time * evolution_speed) * 0.14;
	float cloud_value = mix(cloud_a, cloud_b, blend_amount);
	float cloud_mask = smoothstep(threshold - softness, threshold + softness, cloud_value);
	float depth_fade = mix(1.0 - depth_strength, 1.0, UV.y);

	COLOR = vec4(mottle_color.rgb, cloud_mask * depth_fade * opacity);
}
