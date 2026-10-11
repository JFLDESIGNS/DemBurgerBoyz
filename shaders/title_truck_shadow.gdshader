shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment(){
	vec2 p=(UV-.5)*2.0;
	float radius=dot(p,p);
	ALBEDO=vec3(.045,.028,.02);
	ALPHA=(1.0-smoothstep(.38,1.0,radius))*.88;
}
