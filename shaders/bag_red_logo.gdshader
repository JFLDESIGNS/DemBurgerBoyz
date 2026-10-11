shader_type spatial;
render_mode cull_disabled,depth_draw_never;
uniform sampler2D mask_tex : source_color;
void fragment(){
 ALBEDO=vec3(1.0,.14,.055);
 EMISSION=ALBEDO*.35;
 ALPHA=texture(mask_tex,UV).r*.98;
 ROUGHNESS=.9;
 SPECULAR=.1;
}
