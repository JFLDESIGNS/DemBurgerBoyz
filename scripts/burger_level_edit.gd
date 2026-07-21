@tool
extends Node3D

const GRILL_SURFACE_Y := 1.155
const GRILL_SURFACE_Z := -0.02
const GRILL_CENTER_X := -0.068
const GRILL_WIDTH := 1.786
const GRILL_DEPTH := 0.95
const CUTTING_BOARD_SIZE := Vector3(0.48, 0.038, 0.44)
const CUTTING_BOARD_GAP := 0.06
const CUTTING_BOARD_Z_OFFSET := -0.22
const SMOKE2_SCENE_PATH := "res://models/smokecyl/smoke2.fbx"
const SMOKE2_ALPHA_TEX_PATH := "res://models/smokecyl/alpha2.png"
const SMOKE2_BASECOLOR_TEX_PATH := "res://models/smokecyl/smoke2_DefaultMaterial_BaseColor.png"
const SMOKE2_PREVIEW_HEIGHT := 0.55
const SMOKE2_PREVIEW_WIDTH := 0.42
const SMOKE2_PREVIEW_LIFT := 0.28
const SMOKE2_DEBUG_OUTLINE := true
const CHEESE_STATION_OFFSET := Vector3(-0.06, 0.055, 0.28)
const SODA_STATION_POS := Vector3(-1.55, 1.08, 0.52)
const SODA_STATION_ROT := Vector3(0.0, 180.0, 0.0)

var _rebuild_preview := false

@export var rebuild_preview: bool = false:
	get:
		return _rebuild_preview
	set(value):
		_rebuild_preview = false
		if Engine.is_editor_hint():
			call_deferred("_rebuild_editor_preview")


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_rebuild_editor_preview")


func _rebuild_editor_preview() -> void:
	if not is_inside_tree():
		return
	_apply_runtime_lighting_defaults()
	_hide_old_flat_placeholders()
	_clear_generated("World/EditorGeneratedProps")
	_clear_generated("Grill/EditorGeneratedGrillProps")

	var world := get_node_or_null("World") as Node3D
	var grill := get_node_or_null("Grill") as Node3D
	if world == null or grill == null:
		return

	var world_props := Node3D.new()
	world_props.name = "EditorGeneratedProps"
	world.add_child(world_props)
	world_props.owner = owner if owner != null else self

	var grill_props := Node3D.new()
	grill_props.name = "EditorGeneratedGrillProps"
	grill.add_child(grill_props)
	grill_props.owner = owner if owner != null else self

	_build_cutting_board(grill_props)
	_build_cheese_station(grill_props)
	_build_scraper(world_props)
	_build_oil_bottle(world_props)
	_build_season_shaker(world_props)
	_build_fire_extinguisher(world_props)
	_build_glock(world_props)
	_build_soda_station(world_props)
	_build_real_bunting(world_props)


func _apply_runtime_lighting_defaults() -> void:
	## Matches game.gd _setup_world_lighting() after GFX_DEFAULTS are applied.
	var lighting := get_node_or_null("Lighting") as Node3D
	if lighting == null:
		lighting = Node3D.new()
		lighting.name = "Lighting"
		add_child(lighting)
		_assign_owner_recursive(lighting)

	var sun := _ensure_directional_light(lighting, "Sun")
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.53
	sun.light_indirect_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees = Vector3(-48.0, 35.0, 8.0)

	var outside_fill := _ensure_directional_light(lighting, "OutsideFill")
	outside_fill.light_color = Color(0.55, 0.68, 0.95)
	outside_fill.light_energy = 0.35
	outside_fill.shadow_enabled = false
	outside_fill.rotation_degrees = Vector3(-25.0, -140.0, 0.0)

	var kitchen := _ensure_omni_light(lighting, "KitchenFill")
	kitchen.light_color = Color(1.0, 0.88, 0.72)
	kitchen.light_energy = 2.90
	kitchen.omni_range = 5.5
	kitchen.omni_attenuation = 1.15
	kitchen.shadow_enabled = true
	kitchen.position = Vector3(0.0, 2.45, -0.35)

	var grill_lamp := _ensure_spot_light(lighting, "GrillLamp")
	grill_lamp.light_color = Color(1.0, 0.92, 0.78)
	grill_lamp.light_energy = 1.66
	grill_lamp.spot_range = 3.2
	grill_lamp.spot_angle = 42.0
	grill_lamp.spot_attenuation = 0.9
	grill_lamp.shadow_enabled = true
	grill_lamp.position = Vector3(GRILL_CENTER_X, 2.35, GRILL_SURFACE_Z - 0.15)
	grill_lamp.rotation_degrees = Vector3(-72.0, 0.0, 0.0)

	var window_wash := _ensure_spot_light(lighting, "WindowWash")
	window_wash.light_color = Color(0.75, 0.88, 1.0)
	window_wash.light_energy = 0.97
	window_wash.spot_range = 4.0
	window_wash.spot_angle = 50.0
	window_wash.shadow_enabled = false
	window_wash.position = Vector3(0.0, 1.9, 1.55)
	window_wash.rotation_degrees = Vector3(-25.0, 180.0, 0.0)

	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)
		_assign_owner_recursive(env_node)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.33
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.89
	env.tonemap_white = 1.0
	env.ssao_enabled = false
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.35
	env.ssao_power = 1.55
	env.ssao_horizon = 0.06
	env.ssil_enabled = false
	env.ssil_intensity = 0.65
	env.ssil_radius = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.63
	env.glow_strength = 1.07
	env.glow_bloom = 0.18
	env.glow_hdr_threshold = 0.28
	env.glow_hdr_scale = 1.65
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.03
	env.adjustment_contrast = 1.05

	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var hdr_tex := load("res://assets/hdri/kloppenheim_06_1k.hdr")
	if hdr_tex is Texture2D:
		panorama.panorama = hdr_tex
		panorama.energy_multiplier = 0.34
		sky.sky_material = panorama
	else:
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.35, 0.55, 0.92)
		proc.sky_horizon_color = Color(0.78, 0.86, 0.95)
		proc.ground_bottom_color = Color(0.22, 0.24, 0.26)
		proc.ground_horizon_color = Color(0.55, 0.58, 0.62)
		proc.sun_angle_max = 30.0
		sky.sky_material = proc
	env.sky = sky
	env.sky_rotation = Vector3(0.0, deg_to_rad(40.0), 0.0)
	env_node.environment = env


func _ensure_directional_light(parent: Node3D, node_name: String) -> DirectionalLight3D:
	var existing := parent.get_node_or_null(node_name)
	if existing is DirectionalLight3D:
		return existing as DirectionalLight3D
	if existing != null:
		existing.free()
	var light := DirectionalLight3D.new()
	light.name = node_name
	parent.add_child(light)
	_assign_owner_recursive(light)
	return light


func _ensure_omni_light(parent: Node3D, node_name: String) -> OmniLight3D:
	var existing := parent.get_node_or_null(node_name)
	if existing is OmniLight3D:
		return existing as OmniLight3D
	if existing != null:
		existing.free()
	var light := OmniLight3D.new()
	light.name = node_name
	parent.add_child(light)
	_assign_owner_recursive(light)
	return light


func _ensure_spot_light(parent: Node3D, node_name: String) -> SpotLight3D:
	var existing := parent.get_node_or_null(node_name)
	if existing is SpotLight3D:
		return existing as SpotLight3D
	if existing != null:
		existing.free()
	var light := SpotLight3D.new()
	light.name = node_name
	parent.add_child(light)
	_assign_owner_recursive(light)
	return light


func _hide_old_flat_placeholders() -> void:
	var preview := get_node_or_null("World/WallDecals/WindowBuntingPreview") as Node3D
	if preview != null:
		preview.visible = false


func _clear_generated(path: String) -> void:
	var existing := get_node_or_null(path)
	if existing != null:
		existing.free()


func _assign_owner_recursive(node: Node) -> void:
	var scene_owner := owner if owner != null else self
	node.owner = scene_owner
	for child in node.get_children():
		_assign_owner_recursive(child)


func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.65, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if alpha or color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	_assign_owner_recursive(mi)
	return mi


func _add_cylinder(parent: Node3D, name: String, radius: float, height: float, pos: Vector3, material: Material, segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	_assign_owner_recursive(mi)
	return mi


func _add_sphere(parent: Node3D, name: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	_assign_owner_recursive(mi)
	return mi


func _cutting_board_world_center() -> Vector3:
	var grill_left_edge := GRILL_CENTER_X + GRILL_WIDTH * 0.5
	var cx := grill_left_edge + CUTTING_BOARD_GAP + CUTTING_BOARD_SIZE.x * 0.5
	var cy := GRILL_SURFACE_Y - CUTTING_BOARD_SIZE.y * 0.5 + 0.012
	return Vector3(cx, cy, GRILL_SURFACE_Z + CUTTING_BOARD_Z_OFFSET)


func _build_cutting_board(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "BuildCuttingBoard"
	root.position = _cutting_board_world_center()
	parent.add_child(root)
	_assign_owner_recursive(root)

	var rim_mat := _mat(Color(0.30, 0.17, 0.09), 0.0, 0.86)
	var wood_mat := _mat(Color(0.90, 0.74, 0.48), 0.0, 0.72)
	var groove_mat := _mat(Color(0.62, 0.44, 0.26), 0.0, 0.78)
	_add_box(root, "BoardRim", CUTTING_BOARD_SIZE + Vector3(0.05, -0.024, 0.05), Vector3(0.0, -0.025, 0.0), rim_mat)
	_add_box(root, "BoardSlab", CUTTING_BOARD_SIZE, Vector3.ZERO, wood_mat)
	_add_box(root, "BoardGroove", Vector3(CUTTING_BOARD_SIZE.x * 0.82, 0.006, CUTTING_BOARD_SIZE.z * 0.78), Vector3(0.0, CUTTING_BOARD_SIZE.y * 0.5 - 0.004, 0.0), groove_mat)
	_build_smoke2_cutting_board_preview(root)


func _make_smoke2_preview_material(invert_normals: bool = false) -> Material:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	var cull_mode := "cull_front" if invert_normals else "cull_back"
	shader.code = """
shader_type spatial;
render_mode blend_mix, %s, depth_draw_always, specular_disabled;

uniform sampler2D alpha_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint_color : source_color = vec4(0.92, 0.94, 0.98, 0.85);
uniform float alpha_boost : hint_range(0.0, 4.0) = 1.75;
uniform float alpha_floor : hint_range(0.0, 1.0) = 0.18;
uniform bool invert_normals = false;

void vertex() {
	if (invert_normals) {
		NORMAL = -NORMAL;
	}
}

void fragment() {
	vec3 base = texture(base_tex, UV).rgb;
	float mask = texture(alpha_tex, UV).r;
	float a = clamp(mask * alpha_boost * tint_color.a, alpha_floor, 1.0);
	ALBEDO = mix(tint_color.rgb, base, 0.55);
	ALPHA = a;
	ROUGHNESS = 0.72;
	METALLIC = 0.0;
}
""" % cull_mode
	mat.shader = shader
	mat.render_priority = 10
	if ResourceLoader.exists(SMOKE2_ALPHA_TEX_PATH):
		var alpha_tex := load(SMOKE2_ALPHA_TEX_PATH) as Texture2D
		if alpha_tex != null:
			mat.set_shader_parameter("alpha_tex", alpha_tex)
	if ResourceLoader.exists(SMOKE2_BASECOLOR_TEX_PATH):
		var base_tex := load(SMOKE2_BASECOLOR_TEX_PATH) as Texture2D
		if base_tex != null:
			mat.set_shader_parameter("base_tex", base_tex)
	mat.set_shader_parameter("tint_color", Color(0.92, 0.94, 0.98, 0.85))
	mat.set_shader_parameter("alpha_boost", 1.75)
	mat.set_shader_parameter("alpha_floor", 0.18)
	mat.set_shader_parameter("invert_normals", invert_normals)
	return mat


func _make_smoke2_debug_outline_material() -> Material:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, ambient_light_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 0.05, 0.05, 1.0);
uniform float inflate : hint_range(0.0, 0.2) = 0.035;

void vertex() {
	VERTEX += NORMAL * inflate;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
"""
	mat.shader = shader
	mat.render_priority = 127
	mat.set_shader_parameter("outline_color", Color(1.0, 0.05, 0.05, 1.0))
	mat.set_shader_parameter("inflate", 0.04)
	return mat


func _apply_smoke2_preview_materials(node: Node, mat: Material, outline_mat: Material = null) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = mat
		mi.ignore_occlusion_culling = true
		if outline_mat != null:
			mi.material_overlay = outline_mat
			mi.render_priority = 127
		else:
			mi.render_priority = 10
	for child in node.get_children():
		_apply_smoke2_preview_materials(child, mat, outline_mat)


func _combined_mesh_aabb_local(root: Node3D) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	var inv := root.global_transform.affine_inverse()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var rel := inv * mi.global_transform
			var aabb := mi.get_aabb()
			for i in 8:
				var p := rel * aabb.get_endpoint(i)
				if not has_bounds:
					bounds = AABB(p, Vector3.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(p)
		for child in node.get_children():
			stack.append(child)
	return bounds if has_bounds else AABB(Vector3(-0.5, -1.0, -0.5), Vector3(1.0, 2.0, 1.0))


func _build_smoke2_cutting_board_preview(board_root: Node3D) -> void:
	if not FileAccess.file_exists(SMOKE2_SCENE_PATH):
		return
	var packed := load(SMOKE2_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var mat_n := _make_smoke2_preview_material(false)
	var mat_i := _make_smoke2_preview_material(true)
	var outline := _make_smoke2_debug_outline_material() if SMOKE2_DEBUG_OUTLINE else null
	for data in [
		{"name": "Smoke2_Normal", "pos": Vector3(-0.16, CUTTING_BOARD_SIZE.y * 0.5, -0.02), "yaw": 180.0, "inv": false},
		{"name": "Smoke2_Inverted", "pos": Vector3(0.16, CUTTING_BOARD_SIZE.y * 0.5, 0.06), "yaw": 205.0, "inv": true},
	]:
		var visual := packed.instantiate() as Node3D
		if visual == null:
			continue
		var holder := Node3D.new()
		holder.name = str(data["name"])
		holder.position = data["pos"]
		holder.rotation_degrees = Vector3(0.0, float(data["yaw"]), 0.0)
		board_root.add_child(holder)
		visual.name = "Smoke2Mesh"
		holder.add_child(visual)
		var mat: Material = mat_i if bool(data["inv"]) else mat_n
		_apply_smoke2_preview_materials(visual, mat, outline)
		var bounds := _combined_mesh_aabb_local(visual)
		var height := maxf(bounds.size.y, 0.001)
		var widest := maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
		var s := minf(SMOKE2_PREVIEW_HEIGHT / height, SMOKE2_PREVIEW_WIDTH / widest)
		visual.scale = Vector3.ONE * s
		visual.position = Vector3.ZERO
		visual.position -= Vector3(bounds.get_center().x, 0.0, bounds.get_center().z) * s
		visual.position.y = -bounds.position.y * s + SMOKE2_PREVIEW_LIFT
		var tag := Label3D.new()
		tag.name = "Smoke2DebugTag"
		tag.text = str(data["name"])
		tag.font_size = 42
		tag.pixel_size = 0.0022
		tag.modulate = Color(1.0, 0.15, 0.1, 1.0)
		tag.outline_size = 8
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.render_priority = 127
		tag.position = Vector3(0.0, SMOKE2_PREVIEW_HEIGHT + SMOKE2_PREVIEW_LIFT + 0.08, 0.0)
		holder.add_child(tag)
		_assign_owner_recursive(holder)


func _build_cheese_station(parent: Node3D) -> void:
	var board_c := _cutting_board_world_center()
	var root := Node3D.new()
	root.name = "CheeseStation"
	root.position = board_c + Vector3(
		CHEESE_STATION_OFFSET.x,
		CUTTING_BOARD_SIZE.y * 0.5 + CHEESE_STATION_OFFSET.y,
		CHEESE_STATION_OFFSET.z
	)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var rind := _mat(Color(0.78, 0.52, 0.14), 0.0, 0.82)
	var cheese := _mat(Color(0.98, 0.86, 0.28), 0.0, 0.55)
	var wheel := _add_cylinder(root, "CheeseWheel", 0.118, 0.062, Vector3(-0.06, 0.034, 0.08), rind, 32)
	wheel.rotation_degrees.y = 18.0
	var face := _add_cylinder(root, "CheeseTopFace", 0.102, 0.012, Vector3(-0.06, 0.071, 0.08), cheese, 32)
	face.rotation_degrees.y = 18.0
	for i in 7:
		var slice := _add_box(root, "CheeseSlice_%d" % i, Vector3(0.125, 0.008, 0.125), Vector3(-0.028 + float(i) * 0.003, 0.01 + float(i) * 0.009, -0.14 + float(i) * -0.004), cheese)
		slice.rotation_degrees.y = float(i) * 2.5 - 7.0


func _build_scraper(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PaintScraper"
	root.position = Vector3(1.866, 1.99, 1.12)
	root.rotation_degrees = Vector3(-8.0, 18.0, 6.0)
	root.scale = Vector3(1.55, 1.55, 1.55)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var wood := _mat(Color(0.42, 0.26, 0.13), 0.0, 0.72)
	var metal := _mat(Color(0.72, 0.74, 0.78), 0.95, 0.28)
	var blade := _mat(Color(0.78, 0.80, 0.84), 1.0, 0.22)
	_add_box(root, "Handle", Vector3(0.028, 0.22, 0.034), Vector3(0, 0.14, 0), wood)
	_add_box(root, "HandleButt", Vector3(0.032, 0.028, 0.038), Vector3(0, 0.26, 0), wood)
	_add_box(root, "Ferrule", Vector3(0.03, 0.05, 0.022), Vector3(0, 0.02, 0), metal)
	var blade_node := _add_box(root, "Blade", Vector3(0.12, 0.0028, 0.09), Vector3(0, -0.048, -0.012), blade)
	blade_node.rotation_degrees = Vector3(6.0, 180.0, 0.0)
	var tip := _add_box(root, "BladeTip", Vector3(0.118, 0.0016, 0.02), Vector3(0, -0.051, -0.058), blade)
	tip.rotation_degrees = Vector3(14.0, 180.0, 0.0)


func _build_oil_bottle(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "OilBottle"
	root.position = Vector3(1.166, 2.12, 1.12)
	root.rotation_degrees = Vector3(6.0, -18.0, 3.0)
	root.scale = Vector3(2.05, 2.05, 2.05)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var bottle_mat := _mat(Color(0.98, 0.90, 0.35, 0.78), 0.05, 0.25, true)
	var fill_mat := _mat(Color(0.92, 0.78, 0.20, 0.85), 0.0, 0.4, true)
	var tip_mat := _mat(Color(0.20, 0.20, 0.22), 0.0, 0.5)
	_add_cylinder(root, "BottlePlastic", 0.034, 0.12, Vector3(0, 0.04, 0), bottle_mat, 14)
	_add_cylinder(root, "OilFill", 0.026, 0.08, Vector3(0, 0.02, 0), fill_mat, 14)
	var tip := _add_cylinder(root, "Nozzle", 0.012, 0.035, Vector3(0, 0.115, 0), tip_mat, 10)
	tip.scale.x = 0.55


func _build_season_shaker(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SeasonShaker"
	root.position = Vector3(1.526, 2.14, 1.12)
	root.rotation_degrees = Vector3(4.0, -10.0, 2.0)
	root.scale = Vector3(2.15, 2.15, 2.15)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var body := _mat(Color(0.55, 0.42, 0.22), 0.0, 0.55)
	var cap := _mat(Color(0.75, 0.72, 0.68), 0.7, 0.35)
	_add_cylinder(root, "ShakerBody", 0.038, 0.11, Vector3.ZERO, body, 12)
	_add_cylinder(root, "MetalCap", 0.036, 0.022, Vector3(0, 0.062, 0), cap, 12)
	for i in 5:
		_add_sphere(root, "CapHole_%d" % i, 0.0035, Vector3((float(i) - 2.0) * 0.008, 0.076, 0.0), _mat(Color(0.08, 0.08, 0.08), 0.0, 0.8))


func _build_fire_extinguisher(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "FireExtinguisher"
	root.position = Vector3(2.063, 1.72, 0.937)
	root.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var packed := load("res://assets/fire_ext/FireExt.fbx") as PackedScene
	if packed != null:
		var visual := packed.instantiate() as Node3D
		visual.name = "FireExtMesh"
		visual.scale = Vector3(0.034, 0.034, 0.034)
		root.add_child(visual)
		_assign_owner_recursive(visual)
	else:
		_add_cylinder(root, "RedCanFallback", 0.11, 0.45, Vector3.ZERO, _mat(Color(0.65, 0.04, 0.03), 0.2, 0.45), 18)


func _build_glock(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "WallGlock"
	root.position = Vector3(0.0, 2.38, 1.232)
	root.rotation_degrees = Vector3(0.0, 270.0, 0.0)
	parent.add_child(root)
	_assign_owner_recursive(root)

	var packed := load("res://assets/glock/Glock.fbx") as PackedScene
	if packed != null:
		var visual := packed.instantiate() as Node3D
		visual.name = "GlockMesh"
		visual.position = Vector3(0.0, 0.02, 0.0)
		visual.scale = Vector3.ONE * 1.755
		root.add_child(visual)
		_assign_owner_recursive(visual)


func _build_soda_station(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SodaStation"
	root.position = SODA_STATION_POS
	root.rotation_degrees = SODA_STATION_ROT
	parent.add_child(root)
	_assign_owner_recursive(root)

	var dark := _mat(Color(0.16, 0.17, 0.19), 0.92, 0.28)
	var black := _mat(Color(0.08, 0.08, 0.09), 0.9, 0.42)
	var chrome := _mat(Color(0.58, 0.60, 0.64), 0.94, 0.18)
	_add_box(root, "Cabinet", Vector3(0.84, 0.46, 0.42), Vector3(0, 0.26, 0), dark)
	_add_box(root, "Skirt", Vector3(0.86, 0.05, 0.44), Vector3(0, 0.025, 0), black)
	_add_box(root, "TankDeck", Vector3(0.82, 0.03, 0.40), Vector3(0, 0.505, 0), chrome)
	_add_box(root, "PourFace", Vector3(0.72, 0.22, 0.05), Vector3(0, 0.38, 0.225), _mat(Color(0.28, 0.30, 0.34), 0.93, 0.22))
	_add_box(root, "DripTray", Vector3(0.74, 0.028, 0.42), Vector3(-0.02, 0.085, 0.40), black)
	for gi in 6:
		_add_box(root, "TrayGrate_%d" % gi, Vector3(0.70, 0.005, 0.012), Vector3(-0.02, 0.105, 0.24 + float(gi) * 0.045), chrome)

	var flavors := [
		{"id": "Cola", "x": -0.26, "col": Color(0.28, 0.08, 0.05, 0.82)},
		{"id": "Lime", "x": 0.0, "col": Color(0.30, 0.62, 0.14, 0.82)},
		{"id": "Orange", "x": 0.26, "col": Color(0.88, 0.28, 0.02, 0.82)},
	]
	for f in flavors:
		var tank := Node3D.new()
		tank.name = "Tank_%s" % f["id"]
		tank.position = Vector3(float(f["x"]), 0.66, 0.0)
		root.add_child(tank)
		_assign_owner_recursive(tank)
		_add_cylinder(tank, "Glass", 0.128, 0.26, Vector3.ZERO, _mat(Color(0.88, 0.94, 1.0, 0.16), 0.12, 0.04, true), 24)
		_add_cylinder(tank, "Syrup", 0.114, 0.245, Vector3(0.0, -0.005, 0.0), _mat(f["col"], 0.0, 0.18, true), 24)

	_add_box(root, "SodaSpoutArm", Vector3(0.11, 0.11, 0.16), Vector3(-0.28, 0.54, 0.30), chrome)
	_add_box(root, "IceSpoutArm", Vector3(0.11, 0.11, 0.16), Vector3(-0.02, 0.54, 0.30), chrome)
	_add_cylinder(root, "SodaNozzle", 0.022, 0.08, Vector3(-0.28, 0.47, 0.34), chrome, 16)
	_add_cylinder(root, "IceNozzle", 0.026, 0.08, Vector3(-0.02, 0.47, 0.34), chrome, 16)


func _build_real_bunting(parent: Node3D) -> void:
	var packed := load("res://assets/bunting/Bunting.fbx") as PackedScene
	if packed == null:
		return
	var root := packed.instantiate() as Node3D
	root.name = "WindowBunting"
	root.position = Vector3(0.0, 1.791, 1.52)
	root.scale = Vector3(4.164, 2.665, 2.665)
	parent.add_child(root)
	_assign_owner_recursive(root)
