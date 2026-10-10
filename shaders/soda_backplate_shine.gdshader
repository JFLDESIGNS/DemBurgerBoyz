shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;
float shine_band(float u,float center,float width){return 1.0-smoothstep(0.0,1.0,abs(u-center)/width);}
void fragment(){
 float u=UV.x+VIEW.x*.025;
 float height=1.0-UV.y;
 float bands=shine_band(u,.18,.065)*.7+shine_band(u,.56,.12)+shine_band(u,.84,.055)*.55;
 ALBEDO=mix(vec3(.77,.85,1.0),vec3(1.0,.9,.76),height*.65);
 ALPHA=bands*.16*mix(.45,1.0,smoothstep(0.0,1.0,height));
}
