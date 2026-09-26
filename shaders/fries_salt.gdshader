shader_type spatial;
uniform vec4 food_color : source_color = vec4(1.0,.62,.08,1.0);
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=UV*vec2(90.0,160.0); vec2 cell=floor(p);
 float seed=hash(cell); vec2 d=abs(fract(p)-vec2(.5));
 float salt=(1.0-smoothstep(.07,.13,d.x+d.y))*step(.76,seed);
 float glint=pow(max(0.0,sin(TIME*2.0+seed*30.0)),12.0)*smoothstep(.3,.8,dot(normalize(NORMAL),normalize(VIEW)));
 ALBEDO=mix(food_color.rgb,vec3(1.0,.98,.87),salt*.8);
 ROUGHNESS=.72; SPECULAR=.32; EMISSION=vec3(1.0,.95,.8)*salt*glint*.65;
}
