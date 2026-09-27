shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 vec2 p = UV - vec2(0.5);
 float radius = length(p);
 float ring = smoothstep(0.395, 0.41, radius) * (1.0 - smoothstep(0.46, 0.475, radius));
 float angle = mod(atan(p.x, -p.y) + 6.2831853, 6.2831853) / 6.2831853;
 ALBEDO = vec3(1.0);
 ALPHA = ring * step(angle, progress) * step(0.001, progress) * 0.95;
}
