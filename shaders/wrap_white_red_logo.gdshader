shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D mask_tex : source_color, filter_linear;
void fragment() {
 vec2 step_uv = 1.0 / vec2(textureSize(mask_tex, 0));
 float center = texture(mask_tex, UV).r;
 float border = center;
 for (int i = 0; i < 16; i++) {
  float angle = float(i) * 0.3926991;
  vec2 offset = vec2(cos(angle), sin(angle)) * step_uv * 7.0;
  border = max(border, texture(mask_tex, UV + offset).r);
  border = max(border, texture(mask_tex, UV + offset * 0.5).r);
 }
 ALBEDO = mix(vec3(0.72, 0.015, 0.025), vec3(1.0), center);
 EMISSION = ALBEDO * 0.25;
 ALPHA = border;
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
