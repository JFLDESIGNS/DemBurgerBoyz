shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_disabled;
uniform float phase=0.0;
uniform float motion_amount=0.0;
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
 vec2 d=abs(UV-.5)*2.0;
 float star=pow(max(0.0,1.0-d.x),8.0)*(1.0-smoothstep(.0,.95,d.y))+pow(max(0.0,1.0-d.y),8.0)*(1.0-smoothstep(.0,.95,d.x));
 float pulse=pow(.5+.5*sin(TIME*3.8+phase),4.0);
 ALBEDO=vec3(1.0,.96,.78)*1.6;
 ALPHA=clamp(star,0.0,1.0)*pulse*motion_amount;
}
