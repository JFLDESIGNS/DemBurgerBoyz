shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Aged flat-top: chunky edge vignette + large irregular oil/water stains.
// Tuned to read clearly on brushed steel (not a near-invisible film).

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_softness : hint_range(0.2, 1.4) = 0.72;
uniform float vignette_noise : hint_range(0.0, 1.0) = 0.55;
uniform float splotch_strength : hint_range(0.0, 1.5) = 0.55;
uniform float splotch_scale : hint_range(0.3, 8.0) = 1.35;
uniform float splotch_threshold : hint_range(0.15, 0.95) = 0.42;
uniform float oil_chroma : hint_range(0.0, 1.0) = 0.72;
uniform float edge_darken : hint_range(0.0, 1.0) = 0.28;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.10;
uniform float opacity : hint_range(0.0, 3.0) = 1.35;
uniform float brightness : hint_range(0.2, 2.5) = 1.35;
uniform float uv_offset_x = 0.0;
uniform float uv_offset_y = 0.0;
uniform float uv_repeat : hint_range(0.25, 4.0) = 1.25;

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
	p += (warp - 0.5) * 1.55;
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
	vec2 uv = v_uv * max(uv_repeat, 0.01) + vec2(uv_offset_x, uv_offset_y);

	vec2 p = uv * 2.0 - 1.0;
	p *= vec2(0.92, 1.08);
	float radial = length(p);
	float vig_mask = smoothstep(vignette_softness * 0.45, 1.05, radial);
	float chunk = fbm(uv * 5.2 + vec2(1.7, 3.1));
	float slide = fbm(uv * vec2(7.5, 2.4) + 4.0);
	float vig_noise = mix(chunk, slide, 0.55);
	vig_mask *= mix(1.0 - vignette_noise, 1.0, vig_noise);
	float vig_a = vig_mask * vignette_strength;

	float raw = chunky_stain(uv + vec2(0.11, 0.37), splotch_scale);
	float raw2 = chunky_stain(uv + vec2(1.9, -0.6), splotch_scale * 0.72);
	float raw3 = chunky_stain(uv + vec2(-0.7, 1.2), splotch_scale * 1.35);
	float field = max(max(raw * 0.82, raw2 * 0.62), raw3 * 0.48);

	float lo = splotch_threshold;
	float hi = splotch_threshold + 0.18;
	float splat = smoothstep(lo, hi, field);
	float rim = smoothstep(lo - 0.08, lo, field) * (1.0 - smoothstep(lo + 0.02, hi + 0.10, field));
	rim *= 0.55 + 0.45 * fbm(uv * 6.0 + 2.0);

	float splat_a = splat * splotch_strength + rim * edge_darken * 0.75;

	float hue = fract(fbm(uv * 1.6 + field) * 0.9 + 0.15);
	// Bright thin-film rainbow — reads on dark steel.
	vec3 oil = hsv2rgb(vec3(hue, clamp(oil_chroma, 0.0, 1.0), 0.82));
	float water = smoothstep(0.45, 0.8, fbm(uv * 1.4 + 8.0));
	oil = mix(oil, vec3(0.55, 0.72, 0.88), water * 0.22);
	oil *= brightness;

	vec3 rim_col = vec3(0.08, 0.07, 0.06) * brightness;
	vec3 fill = mix(rim_col, oil, 0.82);
	vec3 col = mix(rim_col * 0.55, fill, splat);
	col = mix(col, rim_col * 0.75, rim * 0.45);

	float grain = (value_noise(uv * 42.0) - 0.5) * grain_amount * max(vig_mask, splat * 0.55);
	col += grain;

	float alpha = clamp((vig_a * 0.55 + splat_a) * opacity, 0.0, 0.92);
	if (alpha < 0.02) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
