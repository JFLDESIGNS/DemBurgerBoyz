shader_type canvas_item;
uniform vec2 paper_size = vec2(220.0, 320.0);
varying vec2 paper_position;
void vertex() {
 paper_position = VERTEX;
}
void fragment() {
 vec4 paper = COLOR;
 float gray = dot(paper.rgb, vec3(0.299, 0.587, 0.114));
 paper.rgb = mix(vec3(gray), paper.rgb, 0.8);
 // Ten clean V cuts, with stable cartoon variation in depth and peak placement.
 float across = clamp(paper_position.x / max(paper_size.x, 1.0), 0.0, 0.99999) * 10.0;
 float index = floor(across);
 float phase = fract(across);
 float peak = 0.5 + sin(index * 2.1) * 0.10;
 float triangle = phase < peak ? phase / peak : (1.0 - phase) / (1.0 - peak);
 float depth = 7.0 + 2.5 * sin(index * 1.73 + 0.4);
 float edge = paper_size.y - 2.0 - triangle * depth;
 paper.a *= 1.0 - smoothstep(edge - 0.6, edge + 0.6, paper_position.y);
 COLOR = paper;
}
