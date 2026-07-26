shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// Cheap sill glass: subtle screen zoom, then darker tint. No wavy offset.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float magnify : hint_range(0.0, 0.08) = 0.018;
uniform vec3 tint_color : source_color = vec3(0.55, 0.08, 0.03);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float darken : hint_range(0.0, 1.0) = 0.40;

void fragment() {
	// Simple subtle zoom only — no ripple / sine warp.
	vec2 uv = (SCREEN_UV - vec2(0.5)) * (1.0 - magnify) + vec2(0.5);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 bg = textureLod(screen_texture, uv, 0.0).rgb;
	bg *= 1.0 - darken;
	ALBEDO = mix(bg, tint_color, tint_strength);
	ALPHA = opacity;
}
