shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform mat4 food_inverse;
uniform vec3 bounds_min;
uniform vec3 bounds_size;
uniform float consumed = 0.0;
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec3 p=(food_inverse*vec4(world_position,1.0)).xyz;
 float y=(p.y-bounds_min.y)/max(bounds_size.y,0.001);
 float teeth=0.035*sin(p.x*130.0+consumed*9.0)*cos(p.z*110.0);
 if(consumed>0.001 && y>1.0-consumed+teeth){discard;}
 if(consumed>=0.999){discard;}
 ALBEDO=tint.rgb*texture(albedo_tex,UV).rgb;
 ROUGHNESS=.65;
}
