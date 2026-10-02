shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR.a *= step(UV.x, progress) * step(0.00001, progress);
}
