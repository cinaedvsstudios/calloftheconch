shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 haze_color : source_color = vec4(0.72, 0.93, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 0.45, 0.001) = 0.16;
uniform float drift_speed : hint_range(0.0, 0.25, 0.001) = 0.012;
uniform float wave_amount : hint_range(0.0, 0.5, 0.001) = 0.07;
uniform float band_softness : hint_range(0.2, 4.0, 0.01) = 1.15;

void fragment() {
	float distance_from_center = abs(UV.y - 0.5) * 2.0;
	float band = pow(max(1.0 - distance_from_center, 0.0), band_softness);
	float ripple = sin((UV.x * 170.0 + TIME * drift_speed * 60.0) * TAU) * 0.5 + 0.5;
	float alpha = clamp(band + (ripple - 0.5) * wave_amount, 0.0, 1.0) * opacity;
	COLOR = vec4(haze_color.rgb, alpha);
}
