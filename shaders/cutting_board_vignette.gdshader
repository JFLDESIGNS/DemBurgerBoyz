shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 board_center;
uniform mat4 mesh_to_board;
uniform vec3 board_extent = vec3(1.0);
varying vec2 board_uv;
varying float top_face;
void vertex() {
 vec3 board_normal = normalize(mat3(mesh_to_board) * NORMAL);
 top_face = smoothstep(0.5, 0.95, board_normal.y);
 vec3 board_position = (mesh_to_board * vec4(VERTEX,1.0)).xyz;
 board_uv = (board_position.xz - board_center.xz) / max(board_extent.xz, vec2(0.001));
}
void fragment() {
 // Keep the broad center untouched; darkening starts only near the rim.
 float rim = max(abs(board_uv.x), abs(board_uv.y));
 float edge = smoothstep(0.58, 1.0, rim) * top_face;
 float highlight = (1.0 - smoothstep(0.0, 0.70, length(board_uv))) * top_face;
 ALBEDO = vec3(mix(1.0, 0.48, edge)) + vec3(0.24, 0.20, 0.13) * highlight;
 ALPHA = 1.0;
}
