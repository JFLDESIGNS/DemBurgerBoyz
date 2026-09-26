shader_type canvas_item;
void fragment(){
 float mask=texture(TEXTURE,UV).r;
 vec3 ink=mix(vec3(1.0,.84,.22),vec3(1.0,.32,.035),UV.y);
 COLOR=vec4(ink,mask)*COLOR;
}
