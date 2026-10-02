shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_back;

uniform sampler2D live_print : source_color, filter_linear, repeat_disable;
uniform sampler2D blank_atlas : source_color, filter_linear_mipmap, repeat_disable;

uniform float curl_lighting : hint_range(0.0, 1.0) = 0.0;

uniform float paper_height = 320.0;
void fragment() {
 float across = fract(UV.x * 2.0) * 10.0;
 float index = floor(across);
 float phase = fract(across);
 float peak = 0.5 + sin(index * 2.1) * 0.10;
 float triangle = phase < peak ? phase / peak : (1.0 - phase) / (1.0 - peak);
 float depth = 7.0 + 2.5 * sin(index * 1.73 + 0.4);
 if (UV.y > 1.0 - (2.0 + triangle * depth) / max(paper_height, 1.0)) { discard; }

	// Sample inside each atlas half's printed outline while retaining the paper mesh edge.
	float half_offset = UV.x < 0.5 ? 0.0 : 0.5;
	vec2 paper_uv = vec2(half_offset + 0.008 + fract(UV.x * 2.0) * 0.484, 0.008 + UV.y * 0.984);
	vec4 paper = texture(blank_atlas, paper_uv);
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
