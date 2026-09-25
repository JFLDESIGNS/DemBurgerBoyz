extends RefCounted
## Shared, engine-validated properties for placed lights and level-light overrides.
const COMMON := ["light_color", "light_energy", "light_specular", "light_size", "light_indirect_energy", "light_volumetric_fog_energy", "light_negative", "shadow_enabled", "shadow_blur", "shadow_bias", "shadow_normal_bias", "shadow_opacity", "shadow_reverse_cull_face", "distance_fade_enabled", "distance_fade_begin", "distance_fade_length", "distance_fade_shadow", "visible"]
const OMNI := ["omni_range", "omni_attenuation", "omni_shadow_mode"]
const SPOT := ["spot_range", "spot_attenuation", "spot_angle", "spot_angle_attenuation"]
const SUN := ["light_angular_distance", "directional_shadow_max_distance", "directional_shadow_fade_start", "directional_shadow_pancake_size", "directional_shadow_mode", "directional_shadow_blend_splits"]

static func properties(light: Light3D) -> Array:
	var result := COMMON.duplicate()
	if light is OmniLight3D: result.append_array(OMNI)
	elif light is SpotLight3D: result.append_array(SPOT)
	elif light is DirectionalLight3D: result.append_array(SUN)
	var available := {}
	for info in light.get_property_list(): available[str(info.name)] = true
	return result.filter(func(key): return available.has(key))

static func snapshot(light: Light3D) -> Dictionary:
	var values := {"transform": light.transform}
	for key in properties(light): values[key] = light.get(key)
	# Runtime light-balance suppression must never overwrite authored visibility.
	if light.has_meta("balance_authored_visible"):
		values["visible"] = bool(light.get_meta("balance_authored_visible"))
	return values

static func apply(light: Light3D, values: Dictionary) -> void:
	var allowed := properties(light)
	allowed.append("transform")
	for key in values:
		if key in allowed and light.get(key) != values[key]: light.set(key, values[key])
