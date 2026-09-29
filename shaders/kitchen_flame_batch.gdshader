shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	float phase=INSTANCE_CUSTOM.x+TIME*INSTANCE_CUSTOM.y;
	float pulse=.96+.07*abs(sin(phase*INSTANCE_CUSTOM.w));
	VERTEX *= pulse;
	VERTEX.x += (sin(phase)+sin(phase*1.7+.4)*.28)*INSTANCE_CUSTOM.z;
	VERTEX.z += cos(phase*.9+.6)*INSTANCE_CUSTOM.z*.18;
}
void fragment() { ALBEDO=COLOR.rgb; ALPHA=COLOR.a; }
