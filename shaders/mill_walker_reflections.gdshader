shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform int person_count = 0;
uniform vec4 people[8]; // feet UV, width, height
uniform vec4 cat_blob = vec4(0.0); // feet UV, width, height; zero disables it
// Squared distance avoids square roots; broad falloff gives a soft glass shadow.
float ellipse(vec2 p, vec2 center, vec2 radius) {
 vec2 q=(p-center)/radius;
 return 1.0-smoothstep(0.42,1.50,dot(q,q));
}
void fragment() {
 vec4 glass=texture(glass_texture,UV);
 float silhouette=0.0;
 for(int i=0;i<8;i++) {
  if(i>=person_count) break;
  vec2 p=vec2((UV.x-people[i].x)/people[i].z,(people[i].y-UV.y)/people[i].w);
  if(abs(p.x)>0.65 || p.y< -0.2 || p.y>1.12) continue;
  float body=ellipse(p,vec2(0.0,0.83),vec2(0.20,0.15));
  body=max(body,ellipse(p,vec2(0.0,0.51),vec2(0.32,0.27)));
  body=max(body,ellipse(p,vec2(0.0,0.18),vec2(0.21,0.24)));
  silhouette=max(silhouette,body);
 }
 if(cat_blob.z > 0.0 && cat_blob.w > 0.0) {
  vec2 p=vec2((UV.x-cat_blob.x)/cat_blob.z,(cat_blob.y-UV.y)/cat_blob.w);
  float cat=ellipse(p,vec2(0.0,0.40),vec2(0.48,0.34));
  cat=max(cat,ellipse(p,vec2(0.0,0.73),vec2(0.29,0.23)));
  cat=max(cat,ellipse(p,vec2(-0.20,0.93),vec2(0.09,0.14)));
  cat=max(cat,ellipse(p,vec2(0.20,0.93),vec2(0.09,0.14)));
  silhouette=max(silhouette,cat);
 }
 vec3 reflected_blue = min(glass.rgb * vec3(0.22,0.38,0.52),vec3(0.012,0.06,0.11));
 ALBEDO=mix(glass.rgb,reflected_blue,silhouette*0.72);
 ALPHA=glass.a; // Reflections cannot spill onto frames, pavement, or walls.
}
