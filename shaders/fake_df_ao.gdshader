shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// Cheap contact AO from the depth buffer (distance-field style neighborhood).
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 3.0) = 1.15;
uniform float radius_px : hint_range(1.0, 48.0) = 14.0;
uniform float contrast : hint_range(0.5, 4.0) = 1.65;
uniform float bias : hint_range(0.0, 0.02) = 0.0012;
uniform float distance_falloff : hint_range(0.2, 8.0) = 2.4;

float linearize_depth(float d, float z_near, float z_far) {
	return z_near * z_far / (z_far + d * (z_near - z_far));
}

void vertex() {
	// Fullscreen clip-space quad (pair with a 2x2 QuadMesh on the camera).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float raw = textureLod(DEPTH_TEXTURE, uv, 0.0).r;
	float ao = 1.0;
	if (raw > 0.00001 && raw < 0.99999) {
		float z_near = 0.05;
		float z_far = 80.0;
		float center = linearize_depth(raw, z_near, z_far);
		vec2 texel = 1.0 / VIEWPORT_SIZE;
		float r = radius_px;
		vec2 offs[8] = vec2[](
			vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
			vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707)
		);
		float occ = 0.0;
		float wsum = 0.0;
		for (int i = 0; i < 8; i++) {
			vec2 suv = clamp(uv + offs[i] * texel * r, vec2(0.001), vec2(0.999));
			float sd = textureLod(DEPTH_TEXTURE, suv, 0.0).r;
			if (sd > 0.00001 && sd < 0.99999) {
				float samp = linearize_depth(sd, z_near, z_far);
				float diff = (samp - center) - bias;
				float block = clamp((-diff) * distance_falloff / max(center, 0.15), 0.0, 1.0);
				occ += block;
				wsum += 1.0;
			}
		}
		if (wsum > 0.001) {
			ao = 1.0 - clamp((occ / wsum) * intensity, 0.0, 1.0);
			ao = pow(clamp(ao, 0.0, 1.0), contrast);
		}
	}
	ALBEDO = vec3(ao);
	ALPHA = 1.0;
}
