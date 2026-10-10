shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float opacity : hint_range(0.0, 1.0) = 0.16;
varying float tank_height;
void vertex() { tank_height = VERTEX.y / 0.13; }
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
 float ends = smoothstep(0.50, 1.0, abs(tank_height));
 float edge = max(rim, ends * 0.65);
 ALBEDO = vec3(0.88, 0.95, 1.0);
 ROUGHNESS = 0.10;
 METALLIC = 0.0;
 SPECULAR = 0.25;
 ALPHA = opacity * mix(0.06, 1.0, edge);
}
