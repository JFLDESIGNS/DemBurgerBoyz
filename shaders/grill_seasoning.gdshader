shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Subtle aged flat-top: chunky edge vignette + large irregular oil/water stains.

uniform float vignette_strength : hint_range(0.0, 0.6) = 0.14;
uniform float vignette_softness : hint_range(0.2, 1.4) = 0.78;
uniform float vignette_noise : hint_range(0.0, 1.0) = 0.55;
uniform float splotch_strength : hint_range(0.0, 0.5) = 0.055;
uniform float splotch_scale : hint_range(0.3, 6.0) = 1.15;
uniform float splotch_threshold : hint_range(0.35, 0.95) = 0.58;
uniform float oil_chroma : hint_range(0.0, 1.0) = 0.18;
uniform float edge_darken : hint_range(0.0, 0.5) = 0.12;
uniform float grain_amount : hint_range(0.0, 0.35) = 0.06;

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

// Big irregular stains — warped fbm, not round cells.
float chunky_stain(vec2 uv, float scale) {
	vec2 p = uv * scale;
	// Heavy domain warp so islands get torn / blotchy edges.
	vec2 warp = vec2(
		fbm(p * 0.85 + vec2(2.1, 0.4)),
		fbm(p * 0.85 + vec2(7.3, 4.8))
	);
	p += (warp - 0.5) * 1.55;
	float n = fbm(p);
	n = mix(n, fbm(p * vec2(1.7, 0.55) + 3.2), 0.35); // stretch / smear
	n += (fbm(p * 3.4 + 9.0) - 0.5) * 0.22; // chunky internal noise
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
	vec2 uv = v_uv;

	// --- Noisy chunky vignette (edge seasoning / wear) ---
	vec2 p = uv * 2.0 - 1.0;
	p *= vec2(0.92, 1.08);
	float radial = length(p);
	float vig_mask = smoothstep(vignette_softness * 0.45, 1.05, radial);
	float chunk = fbm(uv * 5.2 + vec2(1.7, 3.1));
	float slide = fbm(uv * vec2(7.5, 2.4) + 4.0);
	float vig_noise = mix(chunk, slide, 0.55);
	vig_mask *= mix(1.0 - vignette_noise, 1.0, vig_noise);
	float vig_a = vig_mask * vignette_strength;

	// --- Large noisy oil / water stains (non-circular) ---
	float raw = chunky_stain(uv + vec2(0.11, 0.37), splotch_scale);
	float raw2 = chunky_stain(uv + vec2(1.9, -0.6), splotch_scale * 0.72);
	float field = max(raw * 0.78, raw2 * 0.55);

	float lo = splotch_threshold;
	float hi = splotch_threshold + 0.14;
	float splat = smoothstep(lo, hi, field); // soft body of stain
	// Ring at the contour — slightly darker rim.
	float rim = smoothstep(lo - 0.06, lo, field) * (1.0 - smoothstep(lo + 0.02, hi + 0.08, field));
	rim *= 0.55 + 0.45 * fbm(uv * 6.0 + 2.0);

	float splat_a = splat * splotch_strength + rim * edge_darken * 0.55;

	// Very muted thin-film tint inside the stain.
	float hue = fract(fbm(uv * 1.6 + field) * 0.9 + 0.15);
	vec3 oil = hsv2rgb(vec3(hue, oil_chroma, 0.55));
	float water = smoothstep(0.45, 0.8, fbm(uv * 1.4 + 8.0));
	oil = mix(oil, vec3(0.48, 0.58, 0.66), water * 0.25);

	// Soft steel darkening — mostly for the rim, barely for the fill.
	vec3 rim_col = vec3(0.05, 0.055, 0.06);
	vec3 fill = mix(rim_col * 1.15, oil, 0.55);
	vec3 col = mix(rim_col, fill, splat);
	col = mix(col, rim_col, rim * 0.65);

	float grain = (value_noise(uv * 42.0) - 0.5) * grain_amount * max(vig_mask, splat * 0.4);
	col += grain;

	float alpha = clamp(vig_a + splat_a, 0.0, 0.48);
	ALBEDO = col;
	ALPHA = alpha;
}
