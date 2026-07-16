shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.0045;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.2, 14.0) = 3.6;
/* Higher = smaller oval footprint on the plane. */
uniform float mask_tight : hint_range(0.5, 2.2) = 1.35;

void fragment() {
	float h = clamp(heat, 0.0, 1.0);
	if (h < 0.02) {
		discard;
	}
	vec2 centered = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.28 / mask_tight, 0.72 / mask_tight, length(centered * vec2(1.05, 1.35)));
	if (edge < 0.01) {
		discard;
	}
	float ts = time_scale;
	/* Faster, finer shimmer — rising heat, not a slow blob. */
	float wobble = sin(UV.y * 28.0 + TIME * ts * 1.85) * 0.5
		+ sin(UV.x * 22.0 + TIME * ts * 1.35 + 1.2) * 0.28
		+ sin((UV.x + UV.y) * 17.0 + TIME * ts * 2.4) * 0.18;
	float wobble_y = cos(UV.x * 24.0 + TIME * ts * 1.6) * 0.4
		+ sin(UV.y * 19.0 + TIME * ts * 1.15 + 0.5) * 0.3
		+ cos(UV.y * 31.0 - TIME * ts * 2.1) * 0.16;
	vec2 offset = vec2(wobble, wobble_y) * warp_strength * h * edge;
	vec3 col = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = col;
	ALPHA = edge * (0.2 + 0.2 * h);
}
