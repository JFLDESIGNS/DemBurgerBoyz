shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Full flat-top darkening vignette (cook + HOLD).
// Edge: chunky solid noise. Inward: dithered smaller chunks.
// noise_feather = 0 hard cuts, 1 soft feathered blends.

uniform float darken_a : hint_range(0.0, 1.0) = 0.42;
uniform float darken_b : hint_range(0.0, 1.0) = 0.58;
uniform float dual_blend : hint_range(0.0, 1.0) = 0.0;
uniform float vig_size : hint_range(0.15, 1.6) = 0.85;
uniform float vig_noise : hint_range(0.0, 1.0) = 0.55;
uniform float vig_choke : hint_range(-0.45, 0.45) = 0.0;
uniform float noise_feather : hint_range(0.0, 1.0) = 0.18; // 0 = chunky hard, 1 = soft feather
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
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = m * p * 2.05;
		a *= 0.5;
	}
	return v;
}

// Hard cell blocks — optional tiny feather on the cell edge only.
float chunk_cells(vec2 uv, float cells, float thresh, float feather) {
	vec2 g = uv * max(cells, 0.5);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float n = hash21(id);
	// Irregular blob inside each cell (not a soft cloud).
	float blob = length((f - 0.5) * vec2(1.0, 1.15 + hash21(id + 2.7) * 0.5));
	float r = 0.22 + n * 0.38;
	float fw = mix(0.01, 0.22, clamp(feather, 0.0, 1.0));
	float fill = 1.0 - smoothstep(r - fw, r + fw, blob);
	float gate = step(thresh, n);
	return fill * gate;
}

// Ordered + hash dither for smaller inward flecks.
float dither_chunks(vec2 uv, float cells, float density) {
	vec2 g = uv * max(cells, 1.0);
	vec2 id = floor(g);
	float n = hash21(id + vec2(9.1, 3.4));
	float bayer = hash21(floor(uv * cells * 3.7));
	float dith = mix(n, bayer, 0.45);
	return step(1.0 - clamp(density, 0.0, 1.0), dith);
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

	vec2 p = uv * 2.0 - 1.0;
	p *= vec2(0.94, 1.06);
	float radial = length(p);
	float box = max(abs(p.x) * 0.92, abs(p.y) * 1.02);
	float edge = mix(radial, box, 0.55);

	float size = max(vig_size, 0.05);
	// Tighter base falloff — less soft wash before noise breaks it up.
	float soft_lo = mix(0.62, 0.22, clamp(size, 0.0, 1.0));
	float soft_hi = mix(1.18, 0.78, clamp(size * 0.85, 0.0, 1.0));
	soft_lo = clamp(soft_lo + vig_choke, 0.02, 1.4);
	soft_hi = clamp(soft_hi + vig_choke * 0.65, soft_lo + 0.03, 1.6);

	float vig_fall = smoothstep(soft_lo, soft_hi, edge);
	// How close to the rim (1 = edge, 0 = center).
	float rim = clamp(vig_fall, 0.0, 1.0);

	float feather = clamp(noise_feather, 0.0, 1.0);
	float namp = clamp(vig_noise, 0.0, 1.0);
	float nsc = max(noise_scale, 0.5);

	// Big solid chunks near the edge.
	float big = chunk_cells(uv, nsc * 1.35, 0.32, feather);
	float big2 = chunk_cells(uv + vec2(0.17, -0.09), nsc * 0.85, 0.40, feather * 0.85);
	float chunky = max(big, big2 * 0.85);

	// Smaller dithered flecks further from the edge (toward center of falloff).
	float inward = 1.0 - rim;
	float fine = dither_chunks(uv, nsc * 4.8, 0.18 + inward * 0.42 * namp);
	float fine2 = dither_chunks(uv + vec2(0.31, 0.19), nsc * 7.2, 0.10 + inward * 0.28 * namp);
	float dither = max(fine, fine2 * 0.7);

	// Rim prefers chunky solids; inward mixes in dithered micro-chunks.
	float noise_body = mix(dither, chunky, mix(0.35, 0.92, rim));
	// Optional soft blend amount — only when feather is high.
	float soft_cloud = fbm(uv * nsc * 0.9 + 2.0);
	noise_body = mix(noise_body, soft_cloud, feather * 0.35);

	// Harder multiply: noise punches solid holes / islands, not a feathered haze.
	float punch = mix(1.0 - namp * 0.92, 1.0 + namp * 0.25, noise_body);
	float vig_mask = clamp(vig_fall * punch, 0.0, 1.0);
	// Extra solid island lift on the rim so chunks read as dark blotches.
	vig_mask = clamp(vig_mask + chunky * namp * rim * 0.35, 0.0, 1.0);

	float tone_n = hash21(floor(uv * nsc * 0.7) + 8.2);
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
