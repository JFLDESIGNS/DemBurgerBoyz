shader_type canvas_item;
void fragment() {
 vec4 logo = texture(TEXTURE, UV);
 float mask = dot(logo.rgb, vec3(0.299,0.587,0.114)) * logo.a;
 COLOR = vec4(0.75,0.08,0.06,mask * 0.06);
}
