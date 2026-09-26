shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float dusk = 0.0;
uniform float blackout = 0.0;
void fragment(){
 vec3 day=texture(screen_texture,SCREEN_UV).rgb;
 float luma=dot(day,vec3(.299,.587,.114));
 vec3 night=mix(day,vec3(luma),.25)*vec3(.33,.44,.68)+vec3(.012,.019,.038);
 float edge=smoothstep(.25,.75,length(SCREEN_UV-.5));
 night*=1.0-.15*edge;
 // Retain warm practical lamps along the ceiling while the street cools.
 float lamp_mask=(1.0-smoothstep(.04,.14,SCREEN_UV.y))*smoothstep(.6,.95,luma);
 night=mix(night,day*vec3(.9,.74,.5),lamp_mask*.8);
 vec3 sunset=day*vec3(1.05,.82,.68);
 vec3 evening=mix(sunset,night,smoothstep(.15,1.0,dusk));
 COLOR=vec4(mix(day,evening,smoothstep(0.0,.2,dusk))*(1.0-blackout),1.0);
}
