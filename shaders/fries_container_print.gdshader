shader_type spatial;
uniform sampler2D mask_tex : source_color;
uniform vec3 bounds_min;
uniform vec3 bounds_size;
varying vec3 pos;
varying vec3 norm;
void vertex(){pos=(VERTEX-bounds_min)/max(bounds_size,vec3(0.00001)); norm=NORMAL;}
void fragment(){
 vec2 uv=vec2((0.5-pos.x)/0.58+0.5,0.5-(pos.y-0.43)/0.34);
 float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0)*step(0.2,norm.z);
 float ink=texture(mask_tex,clamp(uv,vec2(0.0),vec2(1.0))).r*inside;
 ALBEDO=mix(vec3(0.82,0.06,0.04),vec3(1.0),ink);
 ROUGHNESS=.55;
}
