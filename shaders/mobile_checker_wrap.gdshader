shader_type spatial;
render_mode cull_disabled;
uniform sampler2D checker : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool wrapped_paper = false;
uniform vec3 bounds_min = vec3(0.0);
uniform float paper_span = 1.0;
varying vec3 paper_position;
void vertex(){ paper_position=VERTEX; }
void fragment(){
 // Authored UVs follow folded paper without blending red and white projections.
 vec2 print_uv = wrapped_paper ? UV * 4.0 : (paper_position.xz-bounds_min.xz)/max(paper_span,.0001);
 ALBEDO=texture(checker,print_uv).rgb*vec3(1.0,.97,.91);
 ROUGHNESS=1.0;
 SPECULAR=0.0;
}
