shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D window_mask : filter_linear;
uniform sampler2D silhouette_atlas : filter_linear_mipmap;
uniform float opacity=0.0;
uniform float phase=0.0;
uniform float drift=0.0;
uniform bool cat=false;
uniform float variant=0.0;
uniform float aspect=1.0;
uniform float floor_y=1.28;
void fragment(){
 float size=cat ? .84 : 1.20;
 vec2 p=vec2((UV.x-.5-drift)*aspect/size+.5,(UV.y-floor_y)/size+1.0);
 p.x += sin(phase)*.008;
 float inside=step(0.0,p.x)*step(p.x,1.0)*step(0.0,p.y)*step(p.y,1.0);
 vec2 cell=vec2(variant,cat ? 1.0 : 0.0);
 vec2 atlas_uv=(clamp(p,vec2(.005),vec2(.995))+cell)*.5;
 vec2 blur=vec2(.004);
 float ink=texture(silhouette_atlas,atlas_uv).r*.4;
 ink+=(texture(silhouette_atlas,atlas_uv+vec2(blur.x,0)).r+texture(silhouette_atlas,atlas_uv-vec2(blur.x,0)).r+texture(silhouette_atlas,atlas_uv+vec2(0,blur.y)).r+texture(silhouette_atlas,atlas_uv-vec2(0,blur.y)).r)*.15;
 float shape=1.0-ink;
 ALBEDO=vec3(.024,.049,.072);
 ALPHA=texture(window_mask,UV).r*shape*inside*opacity;
}
