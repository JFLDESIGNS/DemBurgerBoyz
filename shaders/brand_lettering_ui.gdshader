shader_type canvas_item;
uniform vec4 ink_top : source_color = vec4(1.0,.84,.22,1.0);
uniform vec4 ink_bottom : source_color = vec4(1.0,.32,.035,1.0);
void fragment(){
 float mask=texture(TEXTURE,UV).r;
 vec3 ink=mix(ink_top.rgb,ink_bottom.rgb,UV.y);
 COLOR=vec4(ink,mask)*COLOR;
}
