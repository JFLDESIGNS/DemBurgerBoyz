shader_type canvas_item;
uniform float consumed = 0.0;
uniform vec2 layer_origin;
uniform vec2 burger_origin;
uniform vec2 burger_size = vec2(180.0, 100.0);
varying vec2 burger_uv;
void vertex() {
 burger_uv = (VERTEX + layer_origin - burger_origin) / max(burger_size, vec2(1.0));
}
float mouthful(vec2 center, float radius, float index) {
 vec2 delta = (burger_uv - center) * burger_size / max(burger_size.x, 1.0);
 float growth = smoothstep(index / 6.0, (index + 1.0) / 6.0, consumed);
 // Small rounded tooth impressions break up the cut, shared across every ingredient.
 float angle = atan(delta.y, delta.x);
 float scallop = 0.012 * cos(angle * 11.0 + index * 0.9)
               + 0.005 * sin(angle * 19.0 + index);
 float edge = length(delta) - (radius + scallop) * growth;
 float aa = max(fwidth(edge), 0.002);
 return growth < 0.001 ? 1.0 : smoothstep(-aa, aa, edge);
}
void fragment() {
 if (consumed >= 0.999) { discard; }
 // Start along the upper/back edge beside the customer's mouth, then work inward.
 float remaining = mouthful(vec2(0.68, 0.04), 0.24, 0.0);
 remaining *= mouthful(vec2(0.31, 0.08), 0.25, 1.0);
 remaining *= mouthful(vec2(0.94, 0.48), 0.28, 2.0);
 remaining *= mouthful(vec2(0.07, 0.52), 0.29, 3.0);
 remaining *= mouthful(vec2(0.64, 0.83), 0.31, 4.0);
 remaining *= mouthful(vec2(0.35, 0.66), 0.62, 5.0);
 COLOR.rgb *= 1.05; // Lift the served burger five percent without changing its alpha.
 COLOR.a *= remaining;
}
