shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_back;

uniform sampler2D live_print : source_color, filter_linear, repeat_disable;
uniform sampler2D blank_atlas : source_color, filter_linear_mipmap, repeat_disable;

uniform float curl_lighting : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 paper = texture(blank_atlas, clamp(UV, vec2(0.001), vec2(0.999)));
	float gray = dot(paper.rgb, vec3(0.299, 0.587, 0.114));
	paper.rgb = mix(vec3(gray), paper.rgb, 0.8);
	if (UV.x < 0.5) {
		vec2 print_uv = vec2(clamp((UV.x - 0.001) / 0.498, 0.002, 0.998), clamp(UV.y, 0.002, 0.998));
		vec4 ink = texture(live_print, print_uv);
		paper.rgb = mix(paper.rgb, ink.rgb, ink.a);
	}
	ALBEDO = paper.rgb * curl_lighting;
	EMISSION = paper.rgb * (1.0 - curl_lighting);
	ROUGHNESS = 0.96;
	SPECULAR = 0.0;
}
