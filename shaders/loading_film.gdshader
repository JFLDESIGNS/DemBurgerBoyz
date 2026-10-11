shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress = 0.0;
uniform float film_time = 0.0;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void fragment() {
 float frame = floor(film_time * 12.0);
 vec2 shake = vec2(hash(frame)-0.5,hash(frame+41.0)-0.5)*vec2(0.0038,0.0048);
 float splice = step(0.94,hash(frame+19.0));
 shake.y += splice * (hash(frame+3.0)-0.5)*0.013;
 vec2 uv = clamp(SCREEN_UV+shake,vec2(0.001),vec2(0.999));
 vec3 c = texture(screen_texture,uv).rgb;
 float gray = dot(c,vec3(0.2126,0.7152,0.0722));
 c = mix(vec3(gray),c,1.08);
 float grain = hash(dot(floor(SCREEN_UV/SCREEN_PIXEL_SIZE),vec2(17.0,131.0))+frame*331.0)-0.5;
 c += grain*0.065;
 float scratch_x = hash(floor(frame/3.0)+65.0);
 float scratch = (1.0-smoothstep(0.0003,0.0011,abs(SCREEN_UV.x-scratch_x)))*step(0.67,hash(frame+81.0));
 c += vec3(scratch*0.16);
 vec2 cells = floor(SCREEN_UV*vec2(160.0,90.0));
 float seed = dot(cells,vec2(47.0,113.0))+floor(frame/2.0);
 vec2 speck = fract(SCREEN_UV*vec2(160.0,90.0))-vec2(hash(seed+7.0),hash(seed+21.0));
 float radius = 0.10+hash(seed+45.0)*0.18;
 float dust = step(0.991,hash(seed))*(1.0-smoothstep(radius*0.5,radius,length(speck*vec2(1.0,0.7+hash(seed+4.0)))));
 c *= 1.0-dust*0.65;
 float vignette = smoothstep(0.2,0.77,length(SCREEN_UV-0.5));
 float darken = 0.40*smoothstep(0.0,0.95,progress);
 c *= (1.0-darken)*(1.0-vignette*0.58)*(0.975+0.025*hash(frame+9.0));
 COLOR = vec4(max(c,vec3(0.0)),1.0);
}
