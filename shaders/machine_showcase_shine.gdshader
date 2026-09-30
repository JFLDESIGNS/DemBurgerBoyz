shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
 // View-space normal follows the turning machine, so highlights sweep its facets.
 float facing = dot(normalize(NORMAL), normalize(vec3(-0.45, 0.65, 1.0)));
 float sweep = sin(TIME * 1.7) * 0.17 + 0.68;
 float band = smoothstep(sweep - 0.10, sweep - 0.035, facing) * (1.0 - smoothstep(sweep + 0.035, sweep + 0.09, facing));
 float thin = smoothstep(0.90, 0.95, facing) * 0.35;
 ALBEDO = vec3(1.0, 0.94, 0.72);
 ALPHA = (band * 0.34 + thin) * smoothstep(0.0, 0.35, dot(NORMAL, VIEW));
}
