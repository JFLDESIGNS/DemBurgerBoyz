shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 float soft = exp(-3.8 * r * r) * (1.0 - smoothstep(0.65, 1.0, r));
 COLOR = vec4(0.12, 0.065, 0.025, soft * 0.40);
}
