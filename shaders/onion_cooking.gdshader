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
	float patches = smoothstep(-0.10, 0.70, mottling);
	vec3 pale_onion = mix(vec3(0.96, 0.90, 0.73), vec3(0.88, 0.73, 0.46), progress);
	float caramel = smoothstep(0.35, 1.0, progress);
	float outer_edge = 1.0 - smoothstep(0.84, 0.94, COLOR.g);
	ALBEDO = mix(pale_onion, vec3(0.40, 0.19, 0.055), max(patches, outer_edge * 0.85) * caramel * 0.90);
	ALPHA = mix(1.0, 0.94, progress);
	ROUGHNESS = 0.52;
	SPECULAR = 0.15;
}
