shader_type spatial;
render_mode unshaded;
varying vec2 disk_position;
void vertex(){disk_position=VERTEX.xz/.087;}
void fragment(){
 float radius=clamp(max(abs(disk_position.x),abs(disk_position.y)),0.0,1.0);
 vec3 warm=mix(vec3(1.0,.78,.38),vec3(1.0,.34,.045),smoothstep(.12,1.0,radius));
 ALBEDO=warm;
 EMISSION=warm*mix(1.65,.45,smoothstep(0.0,1.0,radius));
}
