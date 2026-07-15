shader_type canvas_item;
uniform float scroll_speed = 0.85;
uniform vec4 glow_color : source_color = vec4(1.0, 0.25, 0.03, 1.0);
void fragment() {
  vec2 uv = UV;
  uv.x = fract(uv.x + TIME * scroll_speed);
  vec4 tex = texture(TEXTURE, uv);
  vec3 tinted = mix(tex.rgb, glow_color.rgb, 0.32);
  COLOR = vec4(tinted, tex.a) * COLOR;
}
