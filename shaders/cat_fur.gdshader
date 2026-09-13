shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 fur_position;
float hash3(vec3 p) {
 return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
float fur_noise(vec3 p) {
 vec3 cell=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(cell),hash3(cell+vec3(1,0,0)),f.x),mix(hash3(cell+vec3(0,1,0)),hash3(cell+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(cell+vec3(0,0,1)),hash3(cell+vec3(1,0,1)),f.x),mix(hash3(cell+vec3(0,1,1)),hash3(cell+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { fur_position=VERTEX; }
void fragment() {
 // Object-space masks stay attached to the moving cat. Fine elongated strands
 // blend with broad clumps without adding geometry or a noisy silhouette.
 float strands=fur_noise(fur_position*vec3(120.0,18.0,120.0));
 float clumps=fur_noise(fur_position*vec3(12.0,9.0,12.0));
 float mask=mix(clumps,strands,0.65);
 ALBEDO=vec3(0.019,0.015,0.013)*mix(0.72,1.28,mask);
 ROUGHNESS=mix(0.76,0.92,mask);
 SPECULAR=0.22;
 ANISOTROPY=0.65;
 ANISOTROPY_FLOW=vec2(0.0,1.0);
 RIM=0.12;
 RIM_TINT=0.35;
}
