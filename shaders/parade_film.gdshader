shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount = 1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec3 rgb=texture(screen_texture,SCREEN_UV).rgb;
 float gray=dot(rgb,vec3(.299,.587,.114));
 float frame=floor(TIME*18.0);
 float grain=(hash(FRAGCOORD.xy+frame*7.0)-.5)*.12;
 float vignette=1.0-.23*smoothstep(.25,.7,length(SCREEN_UV-.5));
 float flicker=.97+.03*hash(vec2(frame,4.0));
 vec3 film=vec3(clamp(gray*1.08+grain,0.0,1.0)*vignette*flicker);
 COLOR=vec4(mix(rgb,film,amount),1.0);
}
