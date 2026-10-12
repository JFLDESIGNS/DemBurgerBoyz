shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D window_mask : filter_linear;
uniform float opacity=0.0;
uniform float phase=0.0;
uniform float drift=0.0;
uniform bool cat=false;
uniform float aspect=1.0;
float oval(vec2 p,vec2 c,vec2 r){vec2 q=(p-c)/r;return 1.0-smoothstep(0.78,1.16,dot(q,q));}
void fragment(){
 vec2 p=vec2((UV.x-.5-drift)*aspect+.5,1.0-UV.y);
 float shape;
 if(cat){
  shape=oval(p,vec2(.5,.23),vec2(.24,.25));
  shape=max(shape,oval(p,vec2(.5,.53),vec2(.19,.19)));
  shape=max(shape,oval(vec2(abs(p.x-.5),p.y),vec2(.135,.69),vec2(.07,.10)));
  shape=max(shape,oval(p,vec2(.78,.24),vec2(.08,.23)));
 }else{
  shape=oval(p,vec2(.5,.79),vec2(.135,.14));
  shape=max(shape,oval(p,vec2(.5,.45),vec2(.22,.25)));
  shape=max(shape,oval(p,vec2(.39,.13),vec2(.085,.22)));
  shape=max(shape,oval(p,vec2(.61,.13),vec2(.085,.22)));
  shape=max(shape,oval(p,vec2(.25,.49+sin(phase)*.09),vec2(.07,.20)));
  shape=max(shape,oval(p,vec2(.75,.49-sin(phase)*.09),vec2(.07,.20)));
 }
 ALBEDO=vec3(.024,.049,.072);
 ALPHA=texture(window_mask,UV).r*shape*opacity;
}
