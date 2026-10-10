shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// The transparent 3D viewport contains premultiplied RGB. Use its coverage
	// only, so steam stays white instead of being darkened a second time.
	float coverage = texture(TEXTURE, UV).a;
	COLOR = vec4(vec3(1.0), coverage * 0.65 * COLOR.a);
}
