shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Soft radial heat blot — subtle red ember with grate punch-outs,
// slow flicker, and a slight UV wobble.

uniform float plane_width = 1.0; // meters across UV.x
uniform float bar_period = 0.12; // meters per grate cycle (same on every spot)
uniform float gap_frac : hint_range(0.05, 0.72) = 0.38;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float glow_mul : hint_range(0.0, 1.5) = 1.0;
uniform float opacity : hint_range(0.0, 1.5) = 0.72;
uniform vec3 heat_tint : source_color = vec3(0.92, 0.16, 0.04);
uniform float flicker_amt : hint_range(0.0, 1.0) = 0.22;
uniform float flicker_speed : hint_range(0.1, 4.0) = 0.85;
uniform float wobble_amt : hint_range(0.0, 1.0) = 0.18;
uniform float wobble_speed : hint_range(0.1, 4.0) = 0.55;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	float t = TIME;
	// Slow smooth flicker — layered sines, never harsh strobe.
	float flick = 1.0
		+ sin(t * flicker_speed * 1.7) * 0.55 * flicker_amt
		+ sin(t * flicker_speed * 0.73 + 1.7) * 0.35 * flicker_amt
		+ sin(t * flicker_speed * 2.9 + 4.1) * 0.18 * flicker_amt;
	flick = clamp(flick, 0.55, 1.35);

	// Slight UV wobble so the blot breathes / drifts.
	vec2 uv = v_uv;
	float wob = wobble_amt * 0.028;
	uv.x += sin(t * wobble_speed * 1.1 + uv.y * 6.0) * wob;
	uv.y += cos(t * wobble_speed * 0.9 + uv.x * 5.0) * wob * 0.85;

	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float core = pow(clamp(1.0 - r / 0.36, 0.0, 1.0), 1.35);
	float mid = pow(clamp(1.0 - r / 0.72, 0.0, 1.0), 1.85);
	float outer = pow(clamp(1.0 - r / 0.98, 0.0, 1.0), 2.6);
	float a = clamp(core * 0.70 + mid * 0.32 + outer * 0.10, 0.0, 0.78);

	// Physical X grate punch — soft dark bands, not hard white zebra.
	float x_m = (uv.x - 0.5) * max(plane_width, 0.001);
	float period = max(bar_period, 0.004);
	float phase = fract(x_m / period);
	float bar_mask = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(gap_frac, gap_frac + 0.08, phase));
	// Keep a soft ember under the gaps so it never reads as bright white stripes.
	a *= mix(0.22, 1.0, bar_mask);

	if (a < 0.015 || r > 0.995) {
		discard;
	}

	vec3 deep = heat_tint;
	vec3 hot = mix(heat_tint, vec3(1.0, 0.42, 0.10), 0.45);
	vec3 col = mix(deep, hot, core * 0.65);
	float strength = a * mix(0.45, 0.85, intensity) * glow_mul * opacity * flick;
	ALBEDO = col * (0.55 + intensity * 0.35) * strength;
	ALPHA = clamp(strength, 0.0, 1.0);
	EMISSION = col * (0.85 + intensity * 0.55) * strength;
}
