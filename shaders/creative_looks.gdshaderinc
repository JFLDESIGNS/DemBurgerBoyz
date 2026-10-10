uniform float look_ghibli = 0.0;
uniform float look_cross_teal = 0.0;
uniform float look_cross_lime = 0.0;
uniform float look_cross_ruby = 0.0;
uniform float look_blue_hour = 0.0;
uniform float look_silver = 0.0;

vec3 look_saturate(vec3 c, float amount) {
	return mix(vec3(luminance(c)), c, amount);
}
vec3 look_contrast(vec3 c, float amount) {
	return (c-.5)*amount+.5;
}
vec3 creative_looks(vec3 input_color, vec2 uv, vec2 viewport) {
	vec3 c=input_color;
	if(look_ghibli>0.0) {
		float l=luminance(c);
		float shade=1.0-smoothstep(.08,.60,l);
		float sun=smoothstep(.35,.95,l);
		vec3 painted=pow(max(c,vec3(0)),vec3(.90));
		painted=look_saturate(painted,.94);
		painted+=shade*vec3(-.012,.025,.042)+sun*vec3(.060,.026,-.028);
		// Broad, restrained light diffusion rather than a bright screen overlay.
		vec2 offset=vec2(5.0)/viewport;
		vec3 halo=(sample_scene(uv+offset)+sample_scene(uv-offset)+sample_scene(uv+vec2(offset.x,-offset.y))+sample_scene(uv+vec2(-offset.x,offset.y)))*.25;
		painted+=max(halo-.65,vec3(0))*.14;
		painted=mix(painted,painted*.96+vec3(.030,.026,.016),.35);
		c=mix(c,clamp(painted,vec3(0),vec3(1)),look_ghibli);
	}
	if(look_cross_teal>0.0) {
		float l=luminance(c);
		vec3 graded=pow(max(c,vec3(0)),vec3(.78,1.12,1.30));
		graded=look_contrast(look_saturate(graded,1.28),1.14);
		graded+=(1.0-smoothstep(.1,.65,l))*vec3(-.10,.11,.16)+smoothstep(.3,.95,l)*vec3(.15,.025,-.075);
		c=mix(c,clamp(graded,vec3(0),vec3(1)),look_cross_teal);
	}
	if(look_cross_lime>0.0) {
		float l=luminance(c);
		vec3 graded=look_contrast(look_saturate(c,1.15),1.12);
		graded+=(1.0-smoothstep(.1,.65,l))*vec3(.16,-.065,.20)+smoothstep(.22,.88,l)*vec3(.09,.15,-.18);
		graded=mix(graded,vec3(graded.r*.93,graded.g*1.10,graded.b*.87),.65);
		c=mix(c,clamp(graded,vec3(0),vec3(1)),look_cross_lime);
	}
	if(look_cross_ruby>0.0) {
		float l=luminance(c);
		vec3 graded=look_contrast(pow(max(c,vec3(0)),vec3(.85,1.25,.85)),1.13);
		graded+=(1.0-smoothstep(.04,.60,l))*vec3(.18,-.055,.075)+smoothstep(.38,.95,l)*vec3(-.12,.13,.15);
		c=mix(c,clamp(look_saturate(graded,1.22),vec3(0),vec3(1)),look_cross_ruby);
	}
	if(look_blue_hour>0.0) {
		float l=luminance(c);
		vec3 graded=look_saturate(c,.80)*vec3(.66,.78,1.08);
		graded+=vec3(.014,.025,.07)*(1.0-smoothstep(.15,.8,l));
		graded+=smoothstep(.65,1.0,l)*vec3(.17,.09,-.08);
		c=mix(c,clamp(graded,vec3(0),vec3(1)),look_blue_hour);
	}
	if(look_silver>0.0) {
		float value=clamp((luminance(c)-.5)*1.18+.5,0.0,1.0);
		vec3 graded=mix(vec3(.024,.032,.046),vec3(1.0,.955,.85),value);
		c=mix(c,graded,look_silver);
	}
	return c;
}
