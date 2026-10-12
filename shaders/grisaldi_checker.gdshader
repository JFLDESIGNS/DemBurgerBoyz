shader_type spatial;
void fragment(){
 // Fitted garments supply stable rest-position X/Z in UV2 (FBX centimeter scale).
 vec2 cells=UV2*640.0;
 float c=mod(floor(cells.x)+floor(cells.y),2.0);
 ALBEDO=mix(vec3(.018,.023,.019),vec3(.65,.018,.027),c);
 ROUGHNESS=.86;
}
