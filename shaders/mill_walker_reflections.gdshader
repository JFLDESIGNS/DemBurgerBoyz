shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D glass_texture : source_color, filter_linear;
uniform vec4 glass_region=vec4(0.0,0.0,1.0,1.0);
uniform bool reflection_only=false;
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
 vec2 scene_uv=glass_region.xy+UV*glass_region.zw;
 float silhouette=0.0;
 for(int i=0;i<8;i++) {
  if(i>=person_count) break;
  vec2 p=vec2((scene_uv.x-people[i].x)/people[i].z,(people[i].y-scene_uv.y)/people[i].w);
  if(abs(p.x)>0.65 || p.y< -0.2 || p.y>1.12) continue;
  float body=ellipse(p,vec2(0.0,0.83),vec2(0.20,0.15));
  body=max(body,ellipse(p,vec2(0.0,0.51),vec2(0.32,0.27)));
  body=max(body,ellipse(p,vec2(0.0,0.18),vec2(0.21,0.24)));
  silhouette=max(silhouette,body);
 }
 if(cat_blob.z > 0.0 && cat_blob.w > 0.0) {
  vec2 p=vec2((scene_uv.x-cat_blob.x)/cat_blob.z,(cat_blob.y-scene_uv.y)/cat_blob.w);
  // Four soft blobs; mirrored ears share one evaluation, no square roots.
  float cat=ellipse(p,vec2(-0.07,0.35),vec2(0.39,0.30));
  cat=max(cat,ellipse(p,vec2(0.06,0.69),vec2(0.23,0.23)));
  cat=max(cat,ellipse(vec2(abs(p.x-0.06),p.y),vec2(0.16,0.91),vec2(0.075,0.16)));
  cat=max(cat,ellipse(p,vec2(0.34,0.30),vec2(0.12,0.22)));
  cat *= 0.85;
  silhouette=max(silhouette,cat);
 }
 vec3 reflected_blue = min(glass.rgb * vec3(0.22,0.38,0.52),vec3(0.012,0.06,0.11));
 ALBEDO=mix(glass.rgb,reflected_blue,silhouette*0.58);
 if(reflection_only){ ALBEDO=vec3(.012,.06,.11); ALPHA=glass.r*silhouette*.43; }
 else ALPHA=glass.a; // Reflections cannot spill onto frames, pavement, or walls.
}
