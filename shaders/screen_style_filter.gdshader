shader_type canvas_item;
render_mode unshaded;

// Finished-frame world styling. An explicit BackBufferCopy supplies the complete
// 3D frame, including transparent food/reflection layers. The HUD renders later.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool toon_enabled = false;
uniform bool pixel_enabled = false;
uniform float pixel_block_size : hint_range(1.0, 32.0) = 5.0;
uniform float pixel_mix : hint_range(0.0, 1.0) = 1.0;
uniform float pixel_palette_steps : hint_range(2.0, 64.0) = 32.0;
uniform float pixel_palette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_grid_strength : hint_range(0.0, 0.8) = 0.0;
uniform float toon_mix : hint_range(0.0, 1.0) = 1.0;
uniform float toon_levels : hint_range(2.0, 16.0) = 6.0;
uniform float step_strength : hint_range(0.0, 1.0) = 1.0;
uniform float band_smoothness : hint_range(0.0, 1.0) = 0.18;
uniform float band_offset : hint_range(-0.5, 0.5) = 0.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.08;
uniform float dither_scale : hint_range(0.5, 12.0) = 1.0;
uniform float dither_smoothness : hint_range(0.0, 1.0) = 0.45;
uniform float dither_contrast : hint_range(0.25, 4.0) = 1.0;
uniform float dither_bias : hint_range(-0.5, 0.5) = 0.0;
uniform float light_balance : hint_range(-0.3, 0.3) = 0.0;
uniform float shade_curve : hint_range(0.4, 2.5) = 1.0;
uniform float shadow_depth : hint_range(0.0, 0.8) = 0.0;
uniform float shadow_cutoff : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.54;
uniform float highlight_cutoff : hint_range(0.0, 1.0) = 0.75;
uniform float highlight_softness : hint_range(0.01, 1.0) = 0.40;
uniform bool outlines_enabled = false;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.52;
uniform float outline_threshold : hint_range(0.01, 0.4) = 0.055;
uniform float outline_softness : hint_range(0.005, 0.25) = 0.125;
uniform float outline_thickness : hint_range(0.5, 4.0) = 1.0;
uniform float outline_color_sensitivity : hint_range(0.0, 1.0) = 0.0;
uniform float outline_color_retention : hint_range(0.0, 1.0) = 0.0;
uniform float color_brightness : hint_range(0.5, 1.5) = 1.0;
uniform float color_contrast : hint_range(0.5, 1.8) = 1.0;
uniform float color_saturation : hint_range(0.0, 2.0) = 1.0;
uniform float color_gamma : hint_range(0.35, 2.5) = 1.0;
uniform float black_lift : hint_range(-0.2, 0.3) = 0.0;
uniform float highlight_rolloff : hint_range(0.0, 1.0) = 0.0;
uniform float hue_shift_degrees : hint_range(-180.0, 180.0) = 0.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;
uniform float green_magenta : hint_range(-1.0, 1.0) = 0.0;
uniform float shadow_color : hint_range(-1.0, 1.0) = 0.0;
uniform float highlight_color : hint_range(-1.0, 1.0) = 0.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sample_scene(vec2 uv) {
	return textureLod(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).rgb;
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, vec3(0.0), vec3(1.0)), c.y);
}

float dither_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float smooth_dither_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dither_hash(cell);
	float b = dither_hash(cell + vec2(1.0, 0.0));
	float c = dither_hash(cell + vec2(0.0, 1.0));
	float d = dither_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 viewport_size = vec2(textureSize(screen_texture, 0));
	vec2 raw_uv = SCREEN_UV;
	vec2 uv = raw_uv;
	float block = pixel_enabled ? pixel_block_size : 1.0;

	if (pixel_enabled) {
		vec2 pixel_pos = floor(uv * viewport_size / block) * block + vec2(block * 0.5);
		uv = pixel_pos / viewport_size;
	}

	vec3 scene_sample = sample_scene(raw_uv);
	// Fail open if a renderer cannot provide a valid screen capture. A disabled
	// pass is always preferable to hiding gameplay behind an opaque white quad.
	float source_range = max(scene_sample.r, max(scene_sample.g, scene_sample.b))
		- min(scene_sample.r, min(scene_sample.g, scene_sample.b));
	if (luminance(scene_sample) > 0.997 && source_range < 0.003) {
		discard;
	}
	vec3 color = sample_scene(uv);
	if (pixel_enabled) {
		float palette_count = max(pixel_palette_steps - 1.0, 1.0);
		vec3 palette_color = floor(color * palette_count + vec3(0.5)) / palette_count;
		vec3 pixel_color = mix(color, palette_color, pixel_palette_strength);
		vec2 cell_uv = fract(raw_uv * viewport_size / block);
		float edge_distance = min(min(cell_uv.x, 1.0 - cell_uv.x), min(cell_uv.y, 1.0 - cell_uv.y));
		float grid_mask = 1.0 - smoothstep(0.0, 1.0 / block, edge_distance);
		pixel_color *= 1.0 - grid_mask * pixel_grid_strength;
		color = mix(scene_sample, pixel_color, pixel_mix);
	}
	if (toon_enabled) {
		vec3 original = color;
		float source_luma = max(luminance(color), 0.001);
		float shaped_luma = clamp(pow(source_luma, shade_curve) + light_balance, 0.0, 1.0);
		float level_count = max(toon_levels - 1.0, 1.0);
		vec2 dither_pos = raw_uv * viewport_size / max(dither_scale, 0.5);
		float hard_noise = dither_hash(floor(dither_pos));
		float soft_noise = smooth_dither_noise(dither_pos);
		float dither_noise = mix(hard_noise, soft_noise, dither_smoothness);
		dither_noise = clamp((dither_noise - 0.5) * dither_contrast + 0.5, 0.0, 1.0);
		float dither_amount = ((dither_noise - 0.5) + dither_bias) * dither_strength / level_count;
		float quant_luma = clamp(shaped_luma + band_offset / level_count + dither_amount, 0.0, 1.0);
		float scaled_luma = quant_luma * level_count;
		float lower_band = floor(scaled_luma);
		float band_fraction = fract(scaled_luma);
		float blend_width = max(band_smoothness * 0.49, 0.0001);
		float hard_band_step = step(0.5, band_fraction);
		float soft_band_step = smoothstep(0.5 - blend_width, 0.5 + blend_width, band_fraction);
		float use_soft_bands = step(0.0001, band_smoothness);
		float banded_luma = (lower_band + mix(hard_band_step, soft_band_step, use_soft_bands)) / level_count;
		float final_luma = mix(shaped_luma, banded_luma, step_strength);
		vec3 toon_color = clamp(color * (final_luma / source_luma), vec3(0.0), vec3(1.0));

		float shadow_half = shadow_softness * 0.5;
		float shadow_mask = 1.0 - smoothstep(shadow_cutoff - shadow_half, shadow_cutoff + shadow_half, final_luma);
		toon_color *= 1.0 - shadow_mask * shadow_depth;

		vec3 hsv = rgb_to_hsv(clamp(toon_color, vec3(0.0), vec3(1.0)));
		hsv.x = fract(hsv.x + hue_shift_degrees / 360.0);
		hsv.y = clamp(hsv.y * color_saturation, 0.0, 1.0);
		toon_color = hsv_to_rgb(hsv);
		toon_color = pow(max(toon_color, vec3(0.0)), vec3(1.0 / max(color_gamma, 0.05)));
		toon_color = (toon_color - vec3(0.5)) * color_contrast + vec3(0.5);
		toon_color *= color_brightness;
		toon_color += vec3(black_lift);
		toon_color += vec3(0.10, 0.025, -0.10) * warmth;
		toon_color += vec3(-0.045, 0.09, -0.045) * green_magenta;
		toon_color += shadow_mask * vec3(-0.065, 0.01, 0.10) * shadow_color;
		float highlight_half = highlight_softness * 0.5;
		float highlight_mask = smoothstep(highlight_cutoff - highlight_half, highlight_cutoff + highlight_half, final_luma);
		toon_color += highlight_mask * vec3(0.10, 0.035, -0.075) * highlight_color;
		vec3 highlight_excess = max(toon_color - vec3(0.5), vec3(0.0));
		vec3 rolled_highlights = min(toon_color, vec3(0.5)) + highlight_excess / (vec3(1.0) + highlight_excess);
		toon_color = mix(toon_color, rolled_highlights, highlight_rolloff);
		color = mix(original, clamp(toon_color, vec3(0.0), vec3(1.0)), toon_mix);

		if (outlines_enabled && outline_strength > 0.001) {
			vec2 texel = block * outline_thickness / viewport_size;
			vec3 center_color = sample_scene(uv);
			float center_luma = luminance(center_color);
			float edge = 0.0;
			vec3 edge_sample = sample_scene(uv + vec2(texel.x, 0.0));
			edge = max(edge, mix(abs(center_luma - luminance(edge_sample)), max(max(abs(center_color.r - edge_sample.r), abs(center_color.g - edge_sample.g)), abs(center_color.b - edge_sample.b)), outline_color_sensitivity));
			edge_sample = sample_scene(uv - vec2(texel.x, 0.0));
			edge = max(edge, mix(abs(center_luma - luminance(edge_sample)), max(max(abs(center_color.r - edge_sample.r), abs(center_color.g - edge_sample.g)), abs(center_color.b - edge_sample.b)), outline_color_sensitivity));
			edge_sample = sample_scene(uv + vec2(0.0, texel.y));
			edge = max(edge, mix(abs(center_luma - luminance(edge_sample)), max(max(abs(center_color.r - edge_sample.r), abs(center_color.g - edge_sample.g)), abs(center_color.b - edge_sample.b)), outline_color_sensitivity));
			edge_sample = sample_scene(uv - vec2(0.0, texel.y));
			edge = max(edge, mix(abs(center_luma - luminance(edge_sample)), max(max(abs(center_color.r - edge_sample.r), abs(center_color.g - edge_sample.g)), abs(center_color.b - edge_sample.b)), outline_color_sensitivity));
			float ink = smoothstep(outline_threshold, outline_threshold + outline_softness, edge);
			vec3 retained_ink = color * 0.42;
			vec3 ink_color = mix(vec3(0.0), retained_ink, outline_color_retention);
			color = mix(color, ink_color, ink * outline_strength);
		}
	}

	COLOR = vec4(color, 1.0);
}
