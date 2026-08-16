shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform vec4 flag_color : source_color = vec4(1.0, 0.84, 0.23, 1.0);
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.68;
uniform float center_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float edge_width : hint_range(0.0, 0.35) = 0.08;
uniform float edge_softness : hint_range(0.005, 0.35) = 0.09;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.03;

void fragment() {
	// UVs follow the triangular pennant: top-left (0,0), top-right (1,0), tip (.5,1).
	// Measuring all three edges creates a translucent cloth edge around a more solid center.
	float top_distance = UV.y;
	float left_distance = UV.x - UV.y * 0.5;
	float right_distance = 1.0 - UV.x - UV.y * 0.5;
	float nearest_edge = min(top_distance, min(left_distance, right_distance));
	float edge_mask = 1.0 - smoothstep(edge_width, edge_width + edge_softness, nearest_edge);
	float alpha = mix(center_opacity, edge_opacity, edge_mask) * flag_color.a;

	ALBEDO = flag_color.rgb;
	EMISSION = flag_color.rgb * glow_strength;
	ALPHA = alpha;
}
