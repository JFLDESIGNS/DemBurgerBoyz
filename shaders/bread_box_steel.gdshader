shader_type spatial;
varying vec3 surface_position;
void vertex(){surface_position=VERTEX;}
void fragment(){
 float phase=surface_position.y*5500.0;
 float grain=sin(phase)*.5*clamp(1.0-fwidth(phase)/3.14,0.0,1.0)+.5;
 ALBEDO=vec3(.70,.75,.79)+vec3(grain*.018);
 METALLIC=.48;
 ROUGHNESS=.32+grain*.04;
 SPECULAR=.65;
 EMISSION=vec3(.035,.039,.043);
}
