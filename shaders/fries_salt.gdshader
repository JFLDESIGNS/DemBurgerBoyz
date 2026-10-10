shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform float motion_amount=0.0;
uniform float grain_scale = 100.0;
varying vec3 grain_pos;
varying vec3 grain_normal;
void vertex(){ grain_pos=VERTEX; grain_normal=NORMAL; VERTEX += NORMAL * 0.00005; }
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec3 n=abs(grain_normal);
 vec2 plane=n.z>n.x ? grain_pos.xy : grain_pos.zy;
 if(n.y>max(n.x,n.z)) plane=grain_pos.xz;
 vec2 p=plane*grain_scale;
 float seed=hash(floor(p)); vec2 d=abs(fract(p)-vec2(.5));
 float salt=(1.0-smoothstep(.10,.18,d.x+d.y))*step(.87,seed);
 float glint=pow(max(0.0,sin(TIME*2.0+seed*30.0)),18.0);
 // Larger four-point glints sit on the fry surface and remain readable in play.
 vec2 star_p=plane*grain_scale*.10;
 float star_seed=hash(floor(star_p)+vec2(41.0,17.0));
 vec2 star_d=abs(fract(star_p)-vec2(.5));
 float cross_shape=max((1.0-smoothstep(.022,.055,star_d.x))*(1.0-smoothstep(.07,.32,star_d.y)),(1.0-smoothstep(.022,.055,star_d.y))*(1.0-smoothstep(.07,.32,star_d.x)));
 float pulse=pow(max(0.0,sin(TIME*2.8+star_seed*TAU)),6.0);
 float star=cross_shape*step(.80,star_seed)*pulse*motion_amount;
 ALBEDO=vec3(1.0,.98,.87); ALPHA=clamp(salt*.85+star,0.0,1.0);
 ROUGHNESS=.22; SPECULAR=.65; EMISSION=vec3(1.0,.95,.8)*(glint*1.3*motion_amount+star*3.0);
}
