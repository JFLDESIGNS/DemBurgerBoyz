shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 // Match the 48px orange HOLD ring, including its soft edges and width.
 vec2 p = UV * 48.0 - vec2(23.5);
 float radius = length(p);
 float ring = clamp((radius - 23.5 * 0.58) / 1.2, 0.0, 1.0)
            * clamp((23.5 * 0.92 - radius) / 1.2, 0.0, 1.0);
 float angle = mod(atan(p.x, -p.y) + 6.2831853, 6.2831853) / 6.2831853;
 ALBEDO = vec3(1.0);
 ALPHA = ring * mix(0.10, 0.45, step(angle, progress) * step(0.001, progress));
}
