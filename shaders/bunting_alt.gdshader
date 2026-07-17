shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 yellow_color : source_color = vec3(1.0, 0.84, 0.16);
uniform vec3 red_color : source_color = vec3(0.86, 0.14, 0.13);
/* Up to 8 pennant center X positions in model space (unused = 999). */
uniform vec4 peaks_a = vec4(999.0, 999.0, 999.0, 999.0);
uniform vec4 peaks_b = vec4(999.0, 999.0, 999.0, 999.0);

varying float flag_id;

void vertex() {
	float px = VERTEX.x;
	float best_i = 0.0;
	float best_d = 1e9;
	float peaks[8] = {
		peaks_a.x, peaks_a.y, peaks_a.z, peaks_a.w,
		peaks_b.x, peaks_b.y, peaks_b.z, peaks_b.w
	};
	for (int i = 0; i < 8; i++) {
		float p = peaks[i];
		if (p > 900.0) {
			continue;
		}
		float d = abs(px - p);
		if (d < best_d) {
			best_d = d;
			best_i = float(i);
		}
	}
	flag_id = best_i;
}

void fragment() {
	bool is_yellow = mod(flag_id, 2.0) < 0.5;
	ALBEDO = is_yellow ? yellow_color : red_color;
}
