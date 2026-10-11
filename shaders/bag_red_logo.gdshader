shader_type spatial;
render_mode cull_disabled,depth_draw_never;
uniform sampler2D mask_tex : source_color;
void fragment(){ ALBEDO=vec3(.78,.055,.025); ALPHA=texture(mask_tex,UV).r*.62; ROUGHNESS=.8; }
