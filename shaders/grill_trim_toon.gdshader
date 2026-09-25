shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color=vec4(0.64,0.66,0.71,1.0);
uniform sampler2D base_texture : source_color, hint_default_white;
uniform float hue_shift : hint_range(-1.0,1.0)=0.08;
uniform float shine_strength : hint_range(0.0,1.0)=0.16;
uniform vec3 bounds_min=vec3(0.0);
uniform vec3 bounds_size=vec3(1.0);
varying vec3 local_pos;
varying vec3 local_normal;
void vertex(){local_pos=VERTEX;local_normal=NORMAL;}
float shine_band(float u,float center,float width){
 float distance_from_center=abs(u-center)/width;
 return 1.0-smoothstep(0.0,1.0,distance_from_center);
}
void fragment(){
 vec3 pos=(local_pos-bounds_min)/max(bounds_size,vec3(0.001));
 // A side return uses its depth axis, keeping the streaks vertical on all upright panels.
 float u=mix(pos.x,pos.z,step(0.7,abs(normalize(local_normal).x)));
 float height=clamp(pos.y,0.0,1.0);
 vec3 cool=vec3(0.77,0.85,1.0);
 vec3 warm=vec3(1.0,0.9,0.76);
 vec3 tint=mix(cool,warm,clamp(0.25+u*0.35+hue_shift,0.0,1.0));
 float gradient=mix(0.78,1.04,smoothstep(0.0,1.0,height));
 ALBEDO=base_color.rgb*texture(base_texture,UV).rgb*tint*gradient;
 METALLIC=0.24;ROUGHNESS=0.58;SPECULAR=0.2;
 u+=VIEW.x*0.025;
 float bands=shine_band(u,0.18,0.065)*0.7+shine_band(u,0.56,0.12)+shine_band(u,0.84,0.055)*0.55;
 float dark_bands=shine_band(u,0.34,0.075)*0.08+shine_band(u,0.73,0.055)*0.06;
 ALBEDO*=1.0-dark_bands;
 float shine_gradient=mix(0.45,1.0,smoothstep(0.0,1.0,height));
 EMISSION=mix(cool,warm,height*0.65)*bands*shine_strength*shine_gradient;
}
