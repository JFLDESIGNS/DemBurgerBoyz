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
 // Additional soft four-point stars share this surface pass: no extra particles.
 vec2 star_p=UV*vec2(8.0,25.0);
 float star_seed=hash(floor(star_p)+vec2(13.0,29.0));
 vec2 sd=abs(fract(star_p)-.5)*2.0;
 float cross_star=pow(max(0.0,1.0-sd.x),10.0)*(1.0-smoothstep(.0,.9,sd.y))+pow(max(0.0,1.0-sd.y),10.0)*(1.0-smoothstep(.0,.9,sd.x));
 float star_pulse=pow(max(0.0,sin(TIME*3.0+star_seed*30.0)),6.0);
 vec3 pastel=mix(vec3(1.0,.97,.88),mix(vec3(.91,.82,1.0),vec3(.81,.92,1.0),step(.66,star_seed)),step(.33,star_seed));
 vec3 extra=pastel*cross_star*star_pulse*step(.72,star_seed)*.65*motion_amount;
 EMISSION=extra+vec3(1.0,0.96,0.83)*diamond*blink*visible*sparkle_strength*motion_amount;
}
