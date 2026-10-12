shader_type spatial;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=world_pos.xz;
 float grain=hash(floor(p*65.0));
 vec3 base=mix(vec3(.085,.12,.145),vec3(.12,.165,.185),grain*.45);
 float border=step(27.0,max(abs(p.x),abs(p.y)))*(1.0-step(27.18,max(abs(p.x),abs(p.y))));
 float centerline=(1.0-step(.065,min(abs(p.x),abs(p.y))))*step(.3,fract(max(abs(p.x),abs(p.y))*.22));
 ALBEDO=mix(base,vec3(.82,.67,.37),max(border,centerline)*.7);
 ROUGHNESS=.92;
}
