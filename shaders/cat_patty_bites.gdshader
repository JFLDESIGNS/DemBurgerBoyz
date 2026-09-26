shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.30,.14,.07,1.0);
uniform float bites = 0.0;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
 if(bites>=1.0 && distance(local_pos.xz,vec2(.11,.015))<.09) discard;
 if(bites>=2.0 && distance(local_pos.xz,vec2(-.06,-.10))<.125) discard;
 if(bites>=3.0 && distance(local_pos.xz,vec2(-.055,.085))<.13) discard;
 if(bites>=4.0) discard;
 ALBEDO=tint.rgb;ROUGHNESS=.85;
}
