shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec2 pupil_gaze = vec2(0.0);
uniform vec4 iris_color : source_color = vec4(0.95, 0.78, 0.12, 1.0);
void fragment() {
 vec2 eye = UV * 2.0 - 1.0;
 // Equal UV radii follow the eye mesh's own oval; 0.61 * 1.4 is 40% larger.
 vec2 gaze = pupil_gaze * min(1.0, 0.10 / max(length(pupil_gaze), 0.0001));
 float pupil = 1.0 - smoothstep(0.98, 1.03, length((eye - gaze) / vec2(0.854)));
 // A graphic pie-eye wedge stays on the right side instead of reflecting lights.
 vec2 cut = eye - gaze;
 cut.x -= 0.3416; // Move the wedge tip outward: 60% of its former width/height.
 float wedge = smoothstep(-0.015, 0.015, cut.x) * (1.0 - smoothstep(-0.015, 0.015, abs(cut.y + 0.08) - cut.x * 0.42));
 pupil *= 1.0 - wedge;
 ALBEDO = mix(iris_color.rgb, vec3(0.012, 0.009, 0.007), pupil);
 ROUGHNESS = 0.58;
 SPECULAR = 0.22;
}
