shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Radial heat blot with vertical grate punch-outs at a fixed physical period
// so FULL and ½ spots share the same line width regardless of blot size.

uniform float plane_width = 1.0; ## meters across UV.x
uniform float bar_period = 0.12; ## meters per grate cycle (same on every spot)
uniform float gap_frac : hint_range(0.05, 0.72) = 0.38;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float glow_mul : hint_range(0.0, 1.5) = 1.0;
uniform vec3 heat_tint : source_color = vec3(1.0, 0.48, 0.12);

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv;
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float core = pow(clamp(1.0 - r / 0.40, 0.0, 1.0), 1.15);
	float mid = pow(clamp(1.0 - r / 0.78, 0.0, 1.0), 1.55);
	float outer = pow(clamp(1.0 - r / 1.0, 0.0, 1.0), 2.2);
	float a = clamp(core * 0.78 + mid * 0.40 + outer * 0.18, 0.0, 0.92);

	// Physical X across the plane — identical period on every heat blot.
	float x_m = (uv.x - 0.5) * max(plane_width, 0.001);
	float period = max(bar_period, 0.004);
	float phase = fract(x_m / period);
	// Center the opaque light band; gap is the dark steel punch-out.
	if (phase < gap_frac) {
		a = 0.0;
	}

	if (a < 0.02 || r > 0.995) {
		discard;
	}

	vec3 hot = vec3(1.0, 0.62, 0.22);
	vec3 deep = heat_tint;
	vec3 col = mix(deep, hot, core);
	float alpha = a * mix(0.55, 1.0, intensity) * glow_mul;
	ALBEDO = col * (1.4 + intensity * 1.6) * glow_mul;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = col * (2.2 + intensity * 2.6) * glow_mul;
}
