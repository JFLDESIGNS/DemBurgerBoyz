shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform sampler2D bun_art : source_color, filter_linear_mipmap;
void fragment(){
 vec4 art=texture(bun_art,UV);
 ALBEDO=art.rgb;
 ALPHA=art.a;
 ALPHA_SCISSOR_THRESHOLD=.18;
 float sweep=fract(TIME*.16)*1.7-.35;
 float glint=pow(max(0.0,1.0-abs(UV.x+UV.y*.25-sweep)/.12),3.0);
 EMISSION=art.rgb*.14+vec3(1.0,.88,.64)*glint*.25;
 ROUGHNESS=.23;
 SPECULAR=.7;
}
