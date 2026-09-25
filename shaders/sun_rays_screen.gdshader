shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 source_uv = vec2(0.75,0.12);
uniform vec4 ray_color : source_color = vec4(1.0,0.78,0.4,1.0);
uniform float strength = 0.35;
uniform float reach = 0.85;
uniform float blocker_distance = 5.0;
uniform float source_visibility = 1.0;
float mask_at(vec2 uv, mat4 invproj) {
 if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return 0.0;
 float d=texture(depth_tex,uv).r;
 vec4 v=invproj*vec4(uv*2.0-1.0,d,1.0);
 float dist=-v.z/v.w;
 return smoothstep(blocker_distance,blocker_distance+0.5,dist);
}
void vertex(){ POSITION=vec4(VERTEX.xy,1.0,1.0); }
void fragment(){
 vec2 delta=(source_uv-SCREEN_UV)*reach/32.0;
 vec2 p=SCREEN_UV; float illum=0.0; float decay=1.0;
 for(int i=0;i<32;i++){ p+=delta; illum+=mask_at(p,INV_PROJECTION_MATRIX)*decay; decay*=0.965; }
 float local_mask=mask_at(SCREEN_UV,INV_PROJECTION_MATRIX);
 float radial=exp(-length(SCREEN_UV-source_uv)*1.6);
 ALBEDO=ray_color.rgb;
 ALPHA=clamp(illum/32.0*strength*radial*local_mask*source_visibility,0.0,0.55);
}
