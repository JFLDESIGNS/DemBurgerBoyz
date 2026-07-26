shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Full flat-top darkening vignette (cook + HOLD). Dual darken tones,
// noisy chokeable edge, subtle oil-like color shift, optional spots.

uniform float darken_a : hint_range(0.0, 1.0) = 0.42;
uniform float darken_b : hint_range(0.0, 1.0) = 0.58;
uniform float dual_blend : hint_range(0.0, 1.0) = 0.0; // 0 = only A, 1 = full A/B noise mix
uniform float vig_size : hint_range(0.15, 1.6) = 0.85; // larger = more coverage toward center
uniform float vig_noise : hint_range(0.0, 1.0) = 0.45;
uniform float vig_choke : hint_range(-0.45, 0.45) = 0.0; // + = tighter (less area), - = expand
uniform float opacity : hint_range(0.0, 2.0) = 0.72;
uniform float color_shift : hint_range(0.0, 1.0) = 0.28;
uniform float spot_amount : hint_range(0.0, 1.5) = 0.35;
uniform float spot_scale : hint_range(0.3, 6.0) = 1.55;
uniform float noise_scale : hint_range(0.5, 12.0) = 4.2;
uniform float uv_offset_x = 0.0;
uniform float uv_offset_y = 0.0;

varying vec2 v_uv;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p = m * p * 2.05;
		a *= 0.5;
	}
	return v;
}

float chunky_stain(vec2 uv, float scale) {
	vec2 p = uv * scale;
	vec2 warp = vec2(
		fbm(p * 0.85 + vec2(2.1, 0.4)),
		fbm(p * 0.85 + vec2(7.3, 4.8))
	);
	p += (warp - 0.5) * 1.45;
	float n = fbm(p);
	n = mix(n, fbm(p * vec2(1.7, 0.55) + 3.2), 0.35);
	n += (fbm(p * 3.4 + 9.0) - 0.5) * 0.22;
	return clamp(n, 0.0, 1.0);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv + vec2(uv_offset_x, uv_offset_y);

	// Rectangular + radial hybrid so HOLD and cook corners all darken.
	vec2 p = uv * 2.0 - 1.0;
	p *= vec2(0.94, 1.06);
	float radial = length(p);
	float box = max(abs(p.x) * 0.92, abs(p.y) * 1.02);
	float edge = mix(radial, box, 0.55);

	float size = max(vig_size, 0.05);
	float soft_lo = mix(0.55, 0.12, clamp(size, 0.0, 1.0));
	float soft_hi = mix(1.25, 0.72, clamp(size * 0.85, 0.0, 1.0));
	soft_lo = clamp(soft_lo + vig_choke, 0.02, 1.4);
	soft_hi = clamp(soft_hi + vig_choke * 0.65, soft_lo + 0.04, 1.6);

	float vig_mask = smoothstep(soft_lo, soft_hi, edge);

	float n1 = fbm(uv * noise_scale + vec2(1.7, 3.1));
	float n2 = fbm(uv * noise_scale * 1.55 + vec2(4.0, -1.2));
	float npat = mix(n1, n2, 0.45);
	vig_mask *= mix(1.0 - vig_noise * 0.85, 1.0 + vig_noise * 0.35, npat);
	vig_mask = clamp(vig_mask, 0.0, 1.0);

	float tone_n = fbm(uv * (noise_scale * 0.65) + 8.2);
	float darken = mix(darken_a, mix(darken_a, darken_b, tone_n), clamp(dual_blend, 0.0, 1.0));

	float raw = chunky_stain(uv + vec2(0.17, 0.41), spot_scale);
	float raw2 = chunky_stain(uv + vec2(-0.8, 1.1), spot_scale * 0.78);
	float field = max(raw * 0.85, raw2 * 0.6);
	float spots = smoothstep(0.38, 0.62, field) * spot_amount;

	float hue = fract(fbm(uv * 1.4 + field) * 0.85 + 0.18);
	vec3 shift_col = hsv2rgb(vec3(hue, 0.35 + color_shift * 0.45, 0.55));
	vec3 base_dark = vec3(0.045, 0.04, 0.038);
	base_dark = mix(base_dark, shift_col * 0.35, color_shift * 0.55);
	base_dark = mix(base_dark, shift_col * 0.22, spots * 0.4);

	float body = clamp(vig_mask * darken + spots * 0.55 * darken, 0.0, 1.0);
	float alpha = clamp(body * opacity, 0.0, 0.88);
	if (alpha < 0.015) {
		discard;
	}
	ALBEDO = base_dark;
	ALPHA = alpha;
}
