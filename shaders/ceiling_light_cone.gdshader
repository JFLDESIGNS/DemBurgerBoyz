shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
varying float down;
void vertex(){down=clamp(.5-VERTEX.y/.85,0.0,1.0);}
void fragment(){
 // Clamp again after interpolation: fractional powers at the bottom rim
 // produced non-finite color values and bright bloom artifacts.
 float t=clamp(down,0.0,1.0);
 float feather=clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0);
 float fade=(1.0-smoothstep(0.0,1.0,t))*smoothstep(0.0,.08,t);
 ALBEDO=vec3(1.0,.59,.18);
 ALPHA=clamp(.075*fade*feather,0.0,.075);
}
