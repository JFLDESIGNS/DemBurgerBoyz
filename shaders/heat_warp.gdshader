shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.0032;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.2, 6.0) = 1.1;

void fragment() {
	float h = clamp(heat, 0.0, 1.0);
	if (h < 0.02) {
		discard;
	}
	vec2 centered = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.45, 1.05, length(centered * vec2(1.0, 1.2)));
	if (edge < 0.01) {
		discard;
	}
	float wobble = sin(UV.y * 16.0 + TIME * time_scale) * 0.55
		+ sin(UV.x * 11.0 + TIME * time_scale * 0.75 + 1.2) * 0.3;
	float wobble_y = cos(UV.x * 13.0 + TIME * time_scale * 0.9) * 0.45
		+ sin(UV.y * 9.0 + TIME * time_scale * 0.65 + 0.5) * 0.35;
	vec2 offset = vec2(wobble, wobble_y) * warp_strength * h * edge;
	vec3 col = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = col;
	ALPHA = edge * (0.24 + 0.22 * h);
}
