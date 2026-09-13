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
	vec2 delta = burger_uv - center;
	float teeth = 0.025 * cos(atan(delta.y, delta.x) * 11.0);
	float growth = smoothstep(start, start + 0.30, consumed);
	return smoothstep(-0.008, 0.008, length(delta) - (radius + teeth) * growth);
}
void fragment() {
	float remaining = bite(vec2(0.88, 0.12), 0.53, 0.001);
	remaining *= bite(vec2(0.12, 0.35), 0.70, 0.334);

	remaining *= bite(vec2(0.40, 0.50), 1.30, 0.667);
	COLOR.a *= remaining;
}
