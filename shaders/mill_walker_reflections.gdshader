shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform int person_count = 0;
uniform vec4 people[8]; // feet UV, width, height
uniform float gait[8];
float ellipse(vec2 p, vec2 center, vec2 radius) {
 return 1.0-smoothstep(0.82,1.10,length((p-center)/radius));
}
float limb(vec2 p, vec2 a, vec2 b, float radius) {
 vec2 ab=b-a;
 float d=length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0));
 return 1.0-smoothstep(radius*0.65,radius*1.25,d);
}
void fragment() {
 vec4 glass=texture(glass_texture,UV);
 float silhouette=0.0;
 for(int i=0;i<8;i++) {
  if(i>=person_count) break;
  vec2 p=vec2((UV.x-people[i].x)/people[i].z,(people[i].y-UV.y)/people[i].w);
  float stride=sin(gait[i])*0.13;
  float body=ellipse(p,vec2(0.0,0.83),vec2(0.20,0.15));
  body=max(body,ellipse(p,vec2(0.0,0.51),vec2(0.28,0.25)));
  body=max(body,limb(p,vec2(-0.13,0.33),vec2(-0.17+stride,0.02),0.075));
  body=max(body,limb(p,vec2(0.13,0.33),vec2(0.17-stride,0.02),0.075));
  body=max(body,limb(p,vec2(-0.22,0.66),vec2(-0.35-stride,0.34),0.065));
  body=max(body,limb(p,vec2(0.22,0.66),vec2(0.35+stride,0.34),0.065));
  silhouette=max(silhouette,body);
 }
 vec3 reflected_blue = min(glass.rgb * vec3(0.22,0.38,0.52),vec3(0.012,0.06,0.11));
 ALBEDO=mix(glass.rgb,reflected_blue,silhouette*0.72);
 ALPHA=glass.a; // Reflections cannot spill onto frames, pavement, or walls.
}
