shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_speed = 0.025;
void fragment() {
 vec4 glass = texture(glass_texture, UV);
 // Two staggered rows of rounded puffs, clipped by the upper-glass alpha.
 vec2 cloud_uv = UV * vec2(6.0,6.0) + vec2(TIME * cloud_speed,0.0);
 float clouds = max(texture(cloud_texture,cloud_uv).r,texture(cloud_texture,cloud_uv+vec2(0.47,0.38)).r*0.7);
 ALBEDO = mix(glass.rgb, vec3(0.88, 0.91, 0.83), clouds * cloud_opacity);
 ALPHA = glass.a;
}
