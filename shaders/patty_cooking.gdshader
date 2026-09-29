shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
uniform float cook_time = 0.0;
uniform float first_side_time = 0.0;
uniform bool flipped = false;
uniform sampler2D sear_mask : filter_linear, repeat_disable;
vec3 cooked(float t) {
	t = max(t, 0.0);
	vec3 raw = vec3(.78,.38,.40), light = vec3(.82,.42,.42), rich = vec3(.62,.18,.18);
	vec3 seared = vec3(.55,.26,.16), brown = vec3(.40,.22,.12), dark = vec3(.22,.11,.06);
	if (!flipped && t < .35) return raw;
	if (t < 3.6) return mix(flipped ? light : raw, light, t/3.6);
	if (t < 8.0) return mix(light,rich,(t-3.6)/4.4);
	if (t < 15.0) return mix(rich,seared,(t-8.0)/7.0);
	if (t < 21.0) return mix(seared,brown,(t-15.0)/6.0);
	if (t < 38.0) return mix(brown,dark,(t-21.0)/17.0);
	return mix(dark,vec3(.06,.04,.03),min((t-38.0)/8.0,1.0));
}
void fragment() {
	float v = clamp(UV.y,0.0,1.0);
	vec3 c;
	if (flipped) {
		c = cooked(max(first_side_time+2.0-v*5.5,cook_time-(1.0-v)*5.5));
		float b = clamp(1.0-v/.35,0.0,1.0);
		c = mix(c,cooked(first_side_time+3.0)*.92,b*.55)*(1.0-.04*b);
	} else { c = cooked(cook_time-(1.0-v)*5.5); }
	c *= 1.0-(flipped ? 1.0-v : v)*.1;
	if (flipped && v < .45) {
		float n = texture(sear_mask,UV).r;
		float w = clamp(1.0-v/.45,0.0,1.0)*clamp((first_side_time-8.0)/14.0,.4,1.0);
		if (n > .58) c *= 1.0-clamp(.12+(n-.58)/.42*w*.28,0.0,.38);
		else if (n > .45) c *= 1.0-.08*w;
	}
	// StandardMaterial's previous color texture was sRGB.
	ALBEDO = mix(c/12.92,pow((c+.055)/1.055,vec3(2.4)),step(vec3(.04045),c));
	ALPHA = 1.0;
}
