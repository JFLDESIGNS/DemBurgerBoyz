shader_type spatial;
render_mode unshaded, cull_disabled;

uniform bool powered = false;
uniform float heat : hint_range(0.0, 1.0) = 0.0;

float box(vec2 p, vec2 half_size) {
	vec2 edge = abs(p) - half_size;
	float d = max(edge.x, edge.y);
	return 1.0 - smoothstep(-0.0015, 0.0015, d);
}

// Five by seven LED glyphs: O, N, F. Lit cells have small dark gaps.
float glyph(vec2 p, int letter) {
	if (p.x < 0.0 || p.x >= 5.0 || p.y < 0.0 || p.y >= 7.0) return 0.0;
	int row = int(floor(p.y));
	int bits = 17;
	if (letter == 0) bits = (row == 0 || row == 6) ? 14 : 17;
	if (letter == 1) {
		if (row == 1 || row == 2) bits = 25;
		if (row == 3) bits = 21;
		if (row == 4 || row == 5) bits = 19;
	}
	if (letter == 2) bits = row == 0 ? 31 : (row == 3 ? 30 : 16);
	float lit = float((bits >> (4 - int(floor(p.x)))) & 1);
	vec2 cell = abs(fract(p) - 0.5);
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.5;
	return lit * (1.0 - smoothstep(0.39 - aa, 0.39 + aa, max(cell.x, cell.y)));
}

void fragment() {
	vec2 uv = UV;
	vec3 color = vec3(0.016, 0.026, 0.038);
	vec3 amber = powered ? vec3(1.0, 0.59, 0.12) : vec3(0.17, 0.23, 0.22);
	float letters = 0.0;
	if (powered) {
		letters += glyph((uv - vec2(0.34, 0.12)) / vec2(0.028, 0.067), 0);
		letters += glyph((uv - vec2(0.52, 0.12)) / vec2(0.028, 0.067), 1);
	} else {
		letters += glyph((uv - vec2(0.255, 0.12)) / vec2(0.026, 0.067), 0);
		letters += glyph((uv - vec2(0.425, 0.12)) / vec2(0.026, 0.067), 2);
		letters += glyph((uv - vec2(0.595, 0.12)) / vec2(0.026, 0.067), 2);
	}
	color = mix(color, amber, clamp(letters, 0.0, 1.0));
	// Small power symbol at left; three rising heat strokes at right.
	vec2 power_p = (uv - vec2(0.14, 0.36)) * vec2(1.0, 0.385);
	float ring = 1.0 - smoothstep(0.003, 0.006, abs(length(power_p) - 0.041));
	ring *= step(-0.023, power_p.y);
	float stem = box(uv - vec2(0.14, 0.265), vec2(0.004, 0.078));
	float waves = 0.0;
	for (int i = 0; i < 3; i++) {
		float x = 0.81 + float(i) * 0.028 + sin(uv.y * 24.0 + float(i)) * 0.006;
		waves += (1.0 - smoothstep(0.003, 0.006, abs(uv.x - x))) * step(0.23, uv.y) * step(uv.y, 0.49);
	}
	color = mix(color, amber * 0.6, clamp(ring + stem + waves, 0.0, 1.0));
	// Twelve separate heat segments fill left-to-right over the power ramp.
	float count = floor(clamp(heat, 0.0, 1.0) * 12.0 + 0.001);
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		vec3 segment_color = t < 0.5 ? mix(vec3(1.0, 0.10, 0.07), vec3(1.0, 0.43, 0.035), t * 2.0) : mix(vec3(1.0, 0.43, 0.035), vec3(1.0, 0.91, 0.24), (t - 0.5) * 2.0);
		float segment = box(uv - vec2(0.115 + float(i) * 0.07, 0.80), vec2(0.026, 0.085));
		bool lit = powered && float(i) < count;
		color = mix(color, segment_color * (lit ? 1.0 : 0.10), segment);
	}
	// Sparse, quiet double streak like the robot's cartoon glass reflection.
	float sweep = 0.72; // Fixed glass reflection.
	float across = uv.x + uv.y * 0.18 - sweep;
	float shine = (1.0 - smoothstep(0.028, 0.042, abs(across))) * 0.045;
	shine += (1.0 - smoothstep(0.006, 0.011, abs(across - 0.065))) * 0.07;
	color += vec3(0.74, 0.88, 1.0) * shine;
	ALBEDO = color;
}
