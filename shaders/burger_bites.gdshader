shader_type canvas_item;
uniform float consumed = 0.0;
uniform vec2 layer_origin;
uniform vec2 burger_origin;
uniform vec2 burger_size = vec2(180.0, 100.0);
varying vec2 burger_uv;
void vertex() {
	burger_uv = (VERTEX + layer_origin - burger_origin) / max(burger_size, vec2(1.0));
}
float bite(vec2 center, float radius, float start) {
 // Measure both axes in burger-width units so bite edges are circular in pixels.
 vec2 delta = (burger_uv - center) * burger_size / max(burger_size.x, 1.0);
 float growth = smoothstep(start, start + 0.30, consumed);
 return smoothstep(-0.005, 0.005, length(delta) - radius * growth);
}
void fragment() {
 // Edge-centered semicircles leave a substantial middle after all three bites.
 float remaining = bite(vec2(0.96, 0.35), 0.23, 0.001);
 remaining *= bite(vec2(0.04, 0.58), 0.24, 0.334);
 remaining *= bite(vec2(0.58, 0.03), 0.23, 0.667);
 COLOR.a *= remaining;
}
