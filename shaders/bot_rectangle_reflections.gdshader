shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex(){
 float slide=sin(MODEL_MATRIX[3].x*3.0+MODEL_MATRIX[3].z*2.0)*0.018;
 VERTEX.z+=slide;
}
void fragment(){ ALBEDO=vec3(0.94,0.98,1.0); ALPHA=0.28; }
