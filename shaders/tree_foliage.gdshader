shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.42;
uniform float albedo_boost : hint_range(0.5, 3.0) = 1.38;
uniform float sway_strength : hint_range(0.0, 3.0) = 0.55;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.45;
uniform float sway_seed = 0.0;
uniform float sway_y_min = 2.0;
uniform float sway_y_max = 20.0;
uniform float wind_strength : hint_range(0.0, 4.0) = 1.75;
uniform float wind_dir_deg : hint_range(0.0, 360.0) = 40.0;
uniform vec3 sss_color : source_color = vec3(0.58, 0.95, 0.30);
uniform float sss_emissive : hint_range(0.0, 4.0) = 0.76; /* −20% vs prior 0.95 */
uniform float sss_rim : hint_range(0.0, 4.0) = 0.92;
uniform float sss_base : hint_range(0.0, 2.0) = 0.336;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.82;

void vertex() {
	float h = smoothstep(sway_y_min, sway_y_max, VERTEX.y);
	h = h * h * (0.55 + h * 0.45);
	float phase = TIME * sway_speed + sway_seed + VERTEX.x * 0.38 + VERTEX.z * 0.33;
	float amp = sway_strength * wind_strength * h;
	float dir = radians(wind_dir_deg);
	vec2 wdir = vec2(cos(dir), sin(dir));
	/* Primary lean along wind direction. */
	float primary = sin(phase);
	float cross = cos(phase * 0.83 + 1.7);
	VERTEX.x += (primary * wdir.x + cross * (-wdir.y) * 0.55) * amp;
	VERTEX.z += (primary * wdir.y + cross * wdir.x * 0.55) * amp * 0.92;
	VERTEX.y += sin(phase * 1.35 + 0.4) * amp * 0.22;
	/* Secondary gust for a livelier 3D read. */
	float gust = sin(phase * 1.7 + VERTEX.y * 0.15) * amp * 0.42;
	VERTEX.x += gust * wdir.x;
	VERTEX.z += gust * wdir.y;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	vec3 leaf = tex.rgb * albedo_boost;
	ALBEDO = leaf;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
	SPECULAR = 0.12;

	/* Fake SSS: base glow through the leaf + brighter rim transmission. */
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float transmit = pow(1.0 - ndv, 1.35);
	float wrap = sss_base + transmit * sss_rim;
	EMISSION = sss_color * sss_emissive * wrap * max(leaf, vec3(0.18));
}
