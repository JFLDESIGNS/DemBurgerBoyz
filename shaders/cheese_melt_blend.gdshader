shader_type canvas_item;
uniform sampler2D next_state : filter_linear;
uniform float blend_amount = 0.0;
uniform float wobble_age = 0.0;
uniform float wobble_amount = 0.0;
varying vec4 sprite_tint;
void vertex() { sprite_tint = COLOR; }
void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(next_state, UV);
	if (wobble_amount > 0.001) {
		// Only the yellow slice moves: keep the meat, stack and hit box fixed.
		vec3 surface = mix(a.rgb,b.rgb,blend_amount);
		float cheese_mask = smoothstep(.12,.30,surface.g-surface.b) * smoothstep(.38,.68,surface.g);
		vec2 shift = vec2(sin(UV.y*27.0+wobble_age*7.5),sin(UV.x*23.0-wobble_age*6.0)*.55);
		vec2 wobble_uv = UV + shift*.035*wobble_amount*cheese_mask;
		a = texture(TEXTURE,wobble_uv);
		b = texture(next_state,wobble_uv);
	}
	float alpha = mix(a.a, b.a, blend_amount);
	vec3 rgb = mix(a.rgb*a.a, b.rgb*b.a, blend_amount) / max(alpha, .00001);
	COLOR = vec4(rgb, alpha) * sprite_tint;
}
