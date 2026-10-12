shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.24;
uniform float cloud_speed = 0.012;
void fragment() {
 vec4 glass = texture(glass_texture, UV);
 float clouds = texture(cloud_texture, vec2(UV.x, 1.0 - UV.y) * vec2(3.0, 2.0) + vec2(TIME * cloud_speed, 0.0)).r;
 ALBEDO = mix(glass.rgb, vec3(0.88, 0.91, 0.83), clouds * cloud_opacity);
 ALPHA = glass.a;
}
