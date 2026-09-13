shader_type spatial;
render_mode cull_disabled;

uniform vec4 fabric_color : source_color = vec4(1.0);
uniform vec4 fabric_tint : source_color = vec4(1.0);
uniform bool graphic_enabled = false;
uniform sampler2D graphic_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 graphic_color : source_color = vec4(1.0);
uniform vec2 graphic_center = vec2(0.0, 0.0216);
uniform float graphic_size = 0.0026;
void fragment() {
	vec3 base = fabric_color.rgb * fabric_tint.rgb;
	vec2 print_uv = vec2(
		(UV2.x - graphic_center.x) / graphic_size + 0.5,
		0.5 - (UV2.y - graphic_center.y) / graphic_size
	);
	if (graphic_enabled && COLOR.a > 0.5
			&& all(greaterThanEqual(print_uv, vec2(0.0))) && all(lessThanEqual(print_uv, vec2(1.0)))) {
		vec4 ink = texture(graphic_texture, print_uv);
		base = mix(base, vec3(dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722))) * graphic_color.rgb, ink.a * graphic_color.a);
	}
	ALBEDO = base;
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
}
