shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, ambient_light_disabled, specular_disabled;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float shadow_strength : hint_range(0.05, 1.0) = 0.85;

void fragment() {
	ALBEDO = shadow_color.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ALPHA = 0.0;
}

void light() {
	DIFFUSE_LIGHT = ALBEDO;
	SPECULAR_LIGHT = vec3(0.0);
	// Omni / spot falloff is packed into ATTENUATION. Out-of-range kitchen lights
	// read as 0 and were painting this whole plane solid black.
	if (LIGHT_IS_DIRECTIONAL) {
		if (max(dot(NORMAL, LIGHT), 0.0) >= 0.05) {
			float shadow = 1.0 - clamp(ATTENUATION, 0.0, 1.0);
			ALPHA = min(ALPHA + shadow * shadow_strength * shadow_color.a, 1.0);
		}
	}
}
