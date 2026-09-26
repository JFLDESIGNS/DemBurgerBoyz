shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
float mask_at(sampler2D tex,vec2 uv){
 if(any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0))))return 0.0;
 return smoothstep(.35,.65,texture(tex,uv).r);
}
void fragment(){
 float face=mask_at(TEXTURE,UV);
 float depth=face;
 for(int i=1;i<=24;i++)depth=max(depth,mask_at(TEXTURE,UV-vec2(.013,.038)*float(i)/24.0));
 COLOR=vec4(mix(vec3(.502,.784,.776),vec3(1.0),face),depth)*tint;
}
