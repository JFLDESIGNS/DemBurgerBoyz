shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D artwork : source_color, filter_linear_mipmap;
uniform float blur_amount = 0.0;
void fragment() {
 vec4 sum = vec4(0.0);
 for (int i=-4;i<=4;i++) {
  vec4 s=texture(artwork, UV+vec2(float(i)*blur_amount*0.006,0.0));
  sum.rgb+=s.rgb*s.a; sum.a+=s.a;
 }
 // Cut out the background, but keep the printed sign fully opaque and depth-writing.
 if (sum.a / 9.0 < 0.08) { discard; }
 ALBEDO=sum.rgb/max(sum.a,0.001)*0.672;
}
