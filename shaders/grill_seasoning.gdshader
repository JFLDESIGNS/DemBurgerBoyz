shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Subtle aged flat-top: chunky edge vignette + large oil/water splotches with thin-film tint.

uniform float vignette_strength : hint_range(0.0, 0.6) = 0.20;
uniform float vignette_softness : hint_range(0.2, 1.4) = 0.78;
uniform float vignette_noise : hint_range(0.0, 1.0) = 0.55;
uniform float splotch_strength : hint_range(0.0, 0.5) = 0.16;
uniform float splotch_scale : hint_range(0.5, 8.0) = 2.35;
uniform float splotch_threshold : hint_range(0.35, 0.95) = 0.62;
uniform float oil_chroma : hint_range(0.0, 1.0) = 0.42;
uniform float grain_amount : hint_range(0.0, 0.35) = 0.10;

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

// Chunky cellular blobs — large irregular oil/water islands.
float chunky_splotch(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 1.0;
	float mid = 1.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(n + g), hash21(n + g + 19.7));
			o = 0.15 + 0.70 * o;
			vec2 r = g + o - f;
			float d = length(r);
			if (d < md) {
				mid = md;
				md = d;
			} else if (d < mid) {
				mid = d;
			}
		}
	}
	float edge = mid - md;
	float blob = 1.0 - smoothstep(0.12, 0.55, md);
	blob *= smoothstep(0.02, 0.22, edge);
	return clamp(blob, 0.0, 1.0);
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
	float slide = fbm(uv * vec2(7.5, 2.4) + 4.0); // elongated “wipe / slide” grain
	float vig_noise = mix(chunk, slide, 0.55);
	vig_mask *= mix(1.0 - vignette_noise, 1.0, vig_noise);
	float vig_a = vig_mask * vignette_strength;

	// --- Large oil / water splotches ---
	float cell = chunky_splotch(uv * splotch_scale + vec2(0.3, 1.1));
	float cell2 = chunky_splotch(uv * (splotch_scale * 0.62) + vec2(2.4, 0.7));
	float splat = max(cell * 0.85, cell2 * 0.55);
	// Keep only stronger islands so the steel stays mostly clean.
	splat = smoothstep(splotch_threshold, splotch_threshold + 0.22, splat + fbm(uv * 3.0) * 0.18);
	float splat_a = splat * splotch_strength;

	// Thin-film multicolor — muted soap/oil sheen.
	float hue = fract(fbm(uv * 2.8 + splat * 1.5) * 1.35 + cell * 0.25);
	vec3 oil = hsv2rgb(vec3(hue, oil_chroma * (0.55 + 0.45 * splat), 0.72));
	// Cool water tint mixed in for some patches.
	float water = smoothstep(0.4, 0.85, fbm(uv * 1.9 + 8.0));
	oil = mix(oil, vec3(0.55, 0.68, 0.78), water * 0.35);

	// Dark steel stain under the sheen.
	vec3 stain = vec3(0.07, 0.075, 0.08) * (0.75 + 0.25 * chunk);
	vec3 col = mix(stain, oil, clamp(splat * 0.85 + 0.15, 0.0, 1.0));

	// Fine slide grain in the vignette band.
	float grain = (value_noise(uv * 48.0) - 0.5) * grain_amount * vig_mask;
	col += grain;

	float alpha = clamp(vig_a + splat_a, 0.0, 0.38);
	ALBEDO = col;
	ALPHA = alpha;
}
