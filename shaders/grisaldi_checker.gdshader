shader_type spatial;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){float c=mod(floor(local_pos.x*16.0)+floor(local_pos.y*16.0),2.0);ALBEDO=mix(vec3(.015),vec3(.95),c);ROUGHNESS=.9;}
