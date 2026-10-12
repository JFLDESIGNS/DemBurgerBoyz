shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_speed = 0.008;
float puff(vec2 p,vec2 center,vec2 radius){
 vec2 q=(p-center)/radius;
 return 1.0-smoothstep(.85,1.15,dot(q,q));
}
void fragment() {
 vec4 glass = texture(glass_texture, UV);
 // Two staggered rows of rounded puffs, clipped by the upper-glass alpha.
 vec2 cloud_uv = UV * vec2(5.0,5.0) + vec2(TIME * cloud_speed,0.0);
 vec2 p=fract(cloud_uv);
 float clouds=puff(p,vec2(.49,.53),vec2(.32,.10));
 clouds=max(clouds,puff(p,vec2(.33,.46),vec2(.14,.15)));
 clouds=max(clouds,puff(p,vec2(.49,.39),vec2(.18,.20)));
 clouds=max(clouds,puff(p,vec2(.68,.47),vec2(.13,.13)));
 ALBEDO = mix(glass.rgb, vec3(0.88, 0.91, 0.83), clouds * cloud_opacity);
 ALPHA = glass.a;
}
