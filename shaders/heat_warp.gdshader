shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.012;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.2, 14.0) = 3.2;
/* Higher = smaller oval footprint on the plane. */
uniform float mask_tight : hint_range(0.5, 2.2) = 0.95;

void fragment() {
	float h = clamp(heat, 0.0, 1.0);
	if (h < 0.02) {
		discard;
	}
	vec2 centered = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.22 / mask_tight, 0.88 / mask_tight, length(centered * vec2(1.0, 1.2)));
	if (edge < 0.01) {
		discard;
	}
	float ts = time_scale;
	/* Bigger rising heat blobs — lower frequency, still lively. */
	float wobble = sin(UV.y * 9.0 + TIME * ts * 1.55) * 0.55
		+ sin(UV.x * 7.0 + TIME * ts * 1.15 + 1.2) * 0.35
		+ sin((UV.x + UV.y) * 5.5 + TIME * ts * 1.9) * 0.22
		+ sin(UV.y * 14.0 - TIME * ts * 2.3 + 0.7) * 0.12;
	float wobble_y = cos(UV.x * 8.0 + TIME * ts * 1.35) * 0.48
		+ sin(UV.y * 6.5 + TIME * ts * 1.05 + 0.5) * 0.35
		+ cos(UV.y * 12.0 - TIME * ts * 1.85) * 0.18
		+ sin((UV.x * 3.0 - UV.y) * 4.5 + TIME * ts * 1.45) * 0.15;
	vec2 offset = vec2(wobble, wobble_y) * warp_strength * h * edge;
	vec3 col = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = col;
	/* Stronger visibility so the shimmer reads without going opaque. */
	ALPHA = edge * (0.42 + 0.38 * h);
}
