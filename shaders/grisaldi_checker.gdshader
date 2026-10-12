shader_type spatial;
uniform vec4 check_red : source_color=vec4(.65,.018,.027,1);
uniform vec4 check_black : source_color=vec4(.018,.023,.019,1);
void fragment(){
 // Fitted garments supply stable rest-position X/Z in UV2 (FBX centimeter scale).
 vec2 cells=UV2*640.0;
 float c=mod(floor(cells.x)+floor(cells.y),2.0);
 ALBEDO=mix(check_black.rgb,check_red.rgb,c);
 ROUGHNESS=.86;
}
