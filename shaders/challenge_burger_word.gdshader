shader_type canvas_item;
void fragment(){
 float cutoff = 0.518;
 if(UV.x < .24) cutoff = mix(.77,.518,clamp((UV.x-.185)/.055,0.0,1.0));
 if(UV.x > .864) cutoff = .73;
 float ink=texture(TEXTURE,UV).r*step(UV.y,cutoff);
 COLOR=vec4(.68,.16,.095,ink);
}
