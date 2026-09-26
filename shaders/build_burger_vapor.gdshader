shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, ambient_light_disabled;
uniform sampler2D alpha_tex : filter_linear_mipmap, repeat_enable;
varying float height01;
void vertex(){height01=clamp(VERTEX.y*.5+.5,0.0,1.0);}
void fragment(){
 float mask=texture(alpha_tex,UV).r;
 float fade=pow(1.0-smoothstep(.12,1.0,height01),1.4);
 float facing=smoothstep(.05,.5,abs(dot(normalize(NORMAL),normalize(VIEW))));
 ALBEDO=vec3(1.0);EMISSION=vec3(1.0);
 ALPHA=mask*fade*facing*.40;
}
