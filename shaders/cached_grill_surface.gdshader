shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D baked_surface : source_color, filter_linear, repeat_disable;
void fragment() {
	vec4 baked=texture(baked_surface,UV);
	ALBEDO=baked.rgb;
	ALPHA=baked.a;
}
