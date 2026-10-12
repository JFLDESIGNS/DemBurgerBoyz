shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float edge=1.0-smoothstep(.4,1.0,dot(p,p));
 ALBEDO=vec3(.065,.055,.045);
 ALPHA=edge*.26;
}
