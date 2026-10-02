shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = pow(pow(p.x, 6.0) + pow(p.y, 6.0), 1.0 / 6.0);
	ALBEDO = vec3(0.025, 0.018, 0.012);
	ALPHA = 0.62 * (1.0 - smoothstep(0.64, 1.0, edge));
}
