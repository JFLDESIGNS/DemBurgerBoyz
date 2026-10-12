shader_type canvas_item;
void fragment(){
 vec2 p=UV-vec2(.5,.42);p.x*=1.35;
 float radius=clamp(length(p)*1.55,0.0,1.0);
 vec3 color=mix(vec3(.80,.19,.13),vec3(.24,.025,.04),smoothstep(0.0,1.0,radius));
 COLOR=vec4(color,1.0);
}
