shader_type spatial;
render_mode blend_mix, shadows_disabled;
uniform vec4 bubble_color : source_color = vec4(1.0,.92,.28,.72);
varying float pulse;
void vertex() {
	pulse=.5+.5*sin(TIME*3.3+INSTANCE_CUSTOM.x);
	float s=.68+pulse*.22;
	VERTEX*=vec3(s,s*.65,s);
	VERTEX.y += pulse*INSTANCE_CUSTOM.y;
}
void fragment() {
	ALBEDO=bubble_color.rgb;
	ROUGHNESS=.18;
	EMISSION=bubble_color.rgb*.24;
	ALPHA=bubble_color.a*(.76+pulse*.24);
}
