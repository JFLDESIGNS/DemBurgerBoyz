shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec2 pupil_gaze = vec2(0.0);
uniform vec4 iris_color : source_color = vec4(0.95, 0.78, 0.12, 1.0);
void fragment() {
 vec2 eye = UV * 2.0 - 1.0;
 float pupil = 1.0 - smoothstep(0.98, 1.03, length((eye - pupil_gaze) / vec2(0.36, 0.48)));
 ALBEDO = mix(iris_color.rgb, vec3(0.012, 0.009, 0.007), pupil);
 ROUGHNESS = 0.18;
 SPECULAR = 0.65;
}
