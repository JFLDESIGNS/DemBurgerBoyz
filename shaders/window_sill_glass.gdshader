shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

// Cheap sill glass: sample the screen with a slight zoom + tiny offset, then tint.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float magnify : hint_range(0.0, 0.12) = 0.045;
uniform float offset_amt : hint_range(0.0, 0.04) = 0.012;
uniform vec3 tint_color : source_color = vec3(0.72, 0.12, 0.04);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.62;
uniform float opacity : hint_range(0.0, 1.0) = 0.58;
uniform float darken : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	// Zoom toward the fragment center in screen space (cheap "thick glass" magnify).
	vec2 uv = (SCREEN_UV - vec2(0.5)) * (1.0 - magnify) + vec2(0.5);
	// Tiny static ripple offset — no TIME cost, still reads as warped glass.
	uv += vec2(
		sin(UV.y * 22.0 + UV.x * 3.0),
		cos(UV.x * 18.0 - UV.y * 4.0)
	) * offset_amt;
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 bg = textureLod(screen_texture, uv, 0.0).rgb;
	bg *= 1.0 - darken;
	ALBEDO = mix(bg, tint_color, tint_strength);
	ALPHA = opacity;
}
