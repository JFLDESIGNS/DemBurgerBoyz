shader_type canvas_item;

void fragment() {
	float luminance = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = clamp(mix(vec3(luminance), COLOR.rgb, 1.05) * 1.10, vec3(0.0), vec3(1.0));
}
