shader_type canvas_item;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float angle = atan(p.y, p.x);
 float radius = 0.77 + 0.10 * sin(angle * 5.0) + 0.06 * cos(angle * 3.0 + 1.1);
 float edge = length(p) - radius;
 float aa = max(fwidth(edge), 0.025);
 float mask = 1.0 - smoothstep(-aa, aa, edge);
 // Uneven food chips with a warm lit edge instead of flat square confetti.
 float shade = clamp(1.0 - p.y * 0.25 - p.x * 0.12, 0.65, 1.3);
 COLOR.rgb *= shade;
 COLOR.a *= mask;
}
