shader_type spatial;
render_mode unshaded, cull_disabled,depth_draw_never;
uniform sampler2D mask_tex : source_color;
void fragment(){
 ALBEDO=mix(vec3(1.0,.84,.22),vec3(1.0,.32,.035),UV.y);
 ALPHA=texture(mask_tex,UV).r;
 ROUGHNESS=.6;
}
