shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.42;
uniform float albedo_boost : hint_range(0.5, 2.5) = 1.22;
uniform float sway_strength : hint_range(0.0, 1.5) = 0.22;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.05;
uniform float sway_seed = 0.0;
uniform float sway_y_min = 2.0;
uniform float sway_y_max = 20.0;
uniform vec3 sss_color : source_color = vec3(0.55, 0.92, 0.28);
uniform float sss_emissive : hint_range(0.0, 3.0) = 0.42;
uniform float sss_rim : hint_range(0.0, 3.0) = 0.55;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.88;

void vertex() {
	float h = smoothstep(sway_y_min, sway_y_max, VERTEX.y);
	h *= h;
	float phase = TIME * sway_speed + sway_seed + VERTEX.x * 0.31 + VERTEX.z * 0.27;
	float amp = sway_strength * h;
	VERTEX.x += sin(phase) * amp;
	VERTEX.z += cos(phase * 0.83 + 1.7) * amp * 0.72;
	VERTEX.y += sin(phase * 1.25 + 0.4) * amp * 0.12;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	vec3 leaf = tex.rgb * albedo_boost;
	ALBEDO = leaf;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
	SPECULAR = 0.15;

	/* Fake SSS: soft green glow + thinner rim “light through leaves”. */
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float transmit = pow(1.0 - ndv, 1.65);
	float wrap = 0.38 + transmit * sss_rim;
	EMISSION = sss_color * sss_emissive * wrap * leaf;
}
