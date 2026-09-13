shader_type canvas_item;

void fragment() {
	vec4 paper = COLOR;
	float gray = dot(paper.rgb, vec3(0.299, 0.587, 0.114));
	paper.rgb = mix(vec3(gray), paper.rgb, 0.8);
	COLOR = paper;
}
