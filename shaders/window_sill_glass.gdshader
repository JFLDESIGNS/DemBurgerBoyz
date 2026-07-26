shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, fog_disabled;

// Thick sill glass: screen magnify, bottom→top darken, red/white strip, edge vignette.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float magnify : hint_range(0.0, 0.12) = 0.022;
uniform float distort : hint_range(0.0, 0.08) = 0.012;
uniform vec3 tint_color : source_color = vec3(0.48, 0.06, 0.02);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.58;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float darken : hint_range(0.0, 1.0) = 0.42;
uniform float bottom_darken : hint_range(0.0, 1.0) = 0.55; // linear darken from bottom
uniform float reflectiveness : hint_range(0.0, 1.0) = 0.28;
uniform float vig_strength : hint_range(0.0, 1.0) = 0.35;
uniform float strip_y : hint_range(0.0, 1.0) = 0.72; // 0=bottom 1=top
uniform float strip_h : hint_range(0.01, 0.5) = 0.10;
uniform float strip_opacity : hint_range(0.0, 1.0) = 0.85;
uniform float strip_reps : hint_range(1.0, 40.0) = 14.0;
uniform vec3 strip_red : source_color = vec3(0.78, 0.08, 0.05);
uniform vec3 strip_white : source_color = vec3(0.92, 0.92, 0.90);
uniform float glass_half_h = 0.1; // meters — maps VERTEX.y to 0..1

varying float v_y01;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float hh = max(glass_half_h, 0.001);
	v_y01 = clamp(VERTEX.y / hh * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	// Bottom = 0, top = 1 (linear height on the panel).
	float y01 = v_y01;

	// Subtle screen zoom + slight UV warp (distort).
	vec2 uv = (SCREEN_UV - vec2(0.5)) * (1.0 - magnify) + vec2(0.5);
	uv += vec2(
		sin(v_uv.y * 18.0 + v_uv.x * 4.0),
		cos(v_uv.x * 16.0 - v_uv.y * 3.0)
	) * distort;
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 bg = textureLod(screen_texture, uv, 0.0).rgb;

	// Linear darkening from the bottom.
	float bot = (1.0 - y01) * bottom_darken;
	bg *= 1.0 - clamp(darken + bot, 0.0, 0.92);

	vec3 col = mix(bg, tint_color, tint_strength);

	// Cheap glossy reflect — brighten toward facing view.
	float fres = pow(clamp(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	col = mix(col, vec3(1.0, 0.92, 0.88), fres * reflectiveness * 0.55);
	col += vec3(0.08, 0.05, 0.03) * reflectiveness * (0.35 + fres * 0.65);

	// Edge vignette on the glass face.
	vec2 e = abs(v_uv * 2.0 - 1.0);
	float vig = smoothstep(0.55, 1.05, max(e.x * 0.85, e.y));
	col *= 1.0 - vig * vig_strength * 0.75;

	// Red / white strip band.
	float band = 1.0 - smoothstep(0.0, strip_h * 0.35, abs(y01 - strip_y));
	band *= step(0.001, strip_opacity);
	float stripe = step(0.5, fract(v_uv.x * max(strip_reps, 1.0)));
	vec3 strip_col = mix(strip_red, strip_white, stripe);
	col = mix(col, strip_col, band * strip_opacity);

	float a = clamp(opacity + bot * 0.25 + band * strip_opacity * 0.15, 0.0, 0.92);
	ALBEDO = col;
	ALPHA = a;
	// Mild metallic read for thicker glass edges.
	METALLIC = reflectiveness * 0.35;
	ROUGHNESS = mix(0.08, 0.45, 1.0 - reflectiveness);
}
