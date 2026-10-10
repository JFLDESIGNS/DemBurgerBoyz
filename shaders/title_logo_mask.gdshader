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
 float grain=fract(sin(dot(floor(UV*vec2(1200.0,720.0)),vec2(12.9898,78.233)))*43758.5453);
 vec3 red=mix(vec3(.87,.19,.105),vec3(1.0,.35,.20),smoothstep(.87,1.0,grain)*.65);
 COLOR=vec4(mix(vec3(.78,.19,.12),red,face),depth)*tint;
}
