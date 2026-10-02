shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float patch_seed = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 p = local_position * 170.0;
	float mottling = sin(p.x + patch_seed) * sin(p.z * 1.3 - patch_seed)
		+ 0.35 * sin(p.y * 1.8 + p.z * 2.1 + patch_seed);
	float patches = smoothstep(0.12, 0.82, mottling);
	vec3 pale_onion = mix(COLOR.rgb, vec3(0.93, 0.79, 0.53), progress);
	float caramel = smoothstep(0.35, 1.0, progress);
	ALBEDO = mix(pale_onion, vec3(0.48, 0.25, 0.09), patches * caramel * 0.86);
	ALPHA = mix(1.0, 0.86, progress);
	ROUGHNESS = mix(0.42, 0.30, progress);
}
