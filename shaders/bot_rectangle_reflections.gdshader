shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec2 reflection_direction;
varying float travel_phase;
void vertex(){
 // World-fixed light direction responds to the robot turning and travelling.
 vec3 direction = transpose(mat3(MODEL_MATRIX)) * normalize(vec3(0.7,0.0,0.7));
 reflection_direction = normalize(direction.xz);
 travel_phase = dot(MODEL_MATRIX[3].xz,vec2(0.65,0.4));
}
void fragment(){
 vec2 p=(UV-0.5)*2.0;
 float edge=1.0-smoothstep(0.94,0.99,length(p));
 float sweep=sin(travel_phase)*0.72;
 float across=dot(p,reflection_direction)-sweep;
 float aa=max(fwidth(across),0.012);
 float broad=1.0-smoothstep(0.075,0.075+aa,abs(across));
 float thin=1.0-smoothstep(0.018,0.018+aa,abs(across-0.18));
 // One continuous glass reflection, including over the LED pixels.
 float view_glow=0.7+0.3*(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))));
 ALBEDO=vec3(0.84,0.94,1.0);
 ALPHA=edge*view_glow*(broad*0.021+thin*0.039);
}
