shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float upper_body_start = 0.5;
uniform float upper_body_end = 0.8;
uniform float shade_amount : hint_range(0.0, 1.0) = 0.0;
uniform float door_dark=0.0;
uniform float door_alpha=1.0;
varying float world_height;
void vertex() { world_height = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
 ALBEDO = vec3(0.035,0.055,0.075);
 ALPHA = max(door_dark,shade_amount * smoothstep(upper_body_start,upper_body_end,world_height)) * door_alpha;
}
