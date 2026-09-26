shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float sparkle_strength : hint_range(0.0,3.0)=1.4;
uniform float sparkle_density : hint_range(4.0,40.0)=28.0;
uniform float motion_amount = 0.0;
varying vec3 local_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){local_pos=VERTEX;}
void fragment(){
 vec2 p=UV*vec2(sparkle_density,sparkle_density*5.5);
 vec2 cell=floor(p);
 float seed=hash(cell);
 vec2 offset=vec2(hash(cell+7.0),hash(cell+19.0))*0.5+0.25;
 vec2 d=abs(fract(p)-offset);
 float diamond=1.0-smoothstep(0.10,0.14,d.x+d.y*0.75);
 float blink=pow(max(0.0,sin(TIME*2.0+seed*30.0)),14.0);
 float visible=step(0.79,seed)*smoothstep(0.15,0.6,dot(normalize(NORMAL),normalize(VIEW)));
 ALBEDO=vec3(1.0,0.95,0.84);
 ROUGHNESS=0.4;SPECULAR=0.35;
 EMISSION=vec3(1.0,0.96,0.83)*diamond*blink*visible*sparkle_strength*motion_amount;
}
