shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 glass_color : source_color = vec4(.78,.90,1.0,1.0);
uniform float opacity : hint_range(0.0,1.0) = .055;
uniform float edge_strength : hint_range(0.0,1.0) = .035;
void fragment(){
 vec3 n=normalize(NORMAL);
 float facing=clamp(abs(dot(n,normalize(VIEW))),0.0,1.0);
 float edge=pow(1.0-facing,3.0);
 // Broad, quiet painted reflections instead of tiny metallic light hotspots.
 float stripe=1.0-smoothstep(.08,.16,abs(n.x+.43));
 float thin=1.0-smoothstep(.015,.05,abs(n.x-.63));
 float shine=(stripe*.22+thin*.12)*smoothstep(.1,.5,facing);
 ALBEDO=mix(glass_color.rgb,vec3(1.0,.98,.88),shine);
 ALPHA=clamp(opacity*(.65+edge*2.5+shine*2.0)+edge*edge_strength,0.0,.55);
}
