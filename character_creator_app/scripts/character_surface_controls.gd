extends Node
## Shared by the game and standalone creator. Each actor owns its material copies.
const PATH := "user://character_surfaces.cfg"
const DEFAULTS := {"skin_roughness":0.82,"skin_specular":0.12,"skin_metallic":0.0,"skin_clearcoat":0.0,"skin_scatter":0.65,"clothes_roughness":0.88,"clothes_specular":0.12,"clothes_metallic":0.0,"clothes_clearcoat":0.0,"hair_roughness":0.9,"hair_specular":0.1,"hair_metallic":0.0,"hair_clearcoat":0.0}
static var global_values: Dictionary = DEFAULTS.duplicate()
static var global_enabled := false
static var loaded := false
var actor: Node
var clock := 0.0

static func load_settings() -> void:
	if loaded: return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK: return
	global_enabled = bool(cfg.get_value("materials","enabled",false))
	for key in DEFAULTS:
		global_values[key] = clampf(float(cfg.get_value("materials",key,DEFAULTS[key])),0.0,1.0)

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("materials","enabled",global_enabled)
	for key in global_values: cfg.set_value("materials",key,global_values[key])
	cfg.save(PATH)

func setup(target: Node) -> void:
	actor = target
	load_settings()
	apply_now()

func _process(delta: float) -> void:
	clock += delta
	if clock < 0.25: return
	clock = 0.0
	apply_now()

func apply_now() -> void:
	if not is_instance_valid(actor): return
	var settings := DEFAULTS.duplicate()
	var own = actor.get("surface_look")
	if own is Dictionary: settings.merge(own,true)
	if actor.get("gameplay_character") == true and global_enabled:
		settings.merge(global_values,true)
	var skin = actor.get("_skin_material")
	if skin is Material: apply_material(skin,"skin",settings)
	for pair in [["_hair_root","hair"],["_facial_hair_root","hair"],["_clothing_root","clothes"],["_ears_root","skin"],["_nose_root","skin"]]:
		var branch = actor.get(pair[0])
		if is_instance_valid(branch): apply_branch(branch,pair[1],settings)

static func apply_branch(branch: Node, category: String, settings: Dictionary) -> void:
	if branch is MeshInstance3D and branch.mesh != null:
		var mesh := branch as MeshInstance3D
		if mesh.material_override != null:
			apply_material(mesh.material_override,category,settings)
		else:
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_surface_override_material(index)
				if mat == null:
					var original := mesh.get_active_material(index)
					if original == null: continue
					mat = original.duplicate()
					mesh.set_surface_override_material(index,mat)
				apply_material(mat,category,settings)
	for child in branch.get_children(): apply_branch(child,category,settings)

static func apply_material(mat: Material, category: String, settings: Dictionary) -> void:
	if mat is StandardMaterial3D:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.roughness = maxf(0.02,float(settings[category+"_roughness"]))
		mat.metallic_specular = float(settings[category+"_specular"])
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.metallic = float(settings[category+"_metallic"])
		mat.clearcoat = float(settings[category+"_clearcoat"])
		mat.clearcoat_enabled = mat.clearcoat > 0.001
		if category == "hair":
			mat.anisotropy_enabled = false
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if category == "skin":
			mat.subsurf_scatter_strength = float(settings.skin_scatter)
			mat.subsurf_scatter_enabled = mat.subsurf_scatter_strength > 0.001 and RenderingServer.get_current_rendering_method() == "forward_plus"
	elif mat is ShaderMaterial:
		for key in ["roughness","specular","metallic","clearcoat"]:
			mat.set_shader_parameter("surface_"+key,float(settings[category+"_"+key]))
		if category == "skin": mat.set_shader_parameter("skin_scatter",float(settings.skin_scatter))

static func build_ui(parent: Control, target: Node = null) -> void:
	load_settings()
	var root := VBoxContainer.new()
	root.name = "CharacterMaterials"
	parent.add_child(root)
	var title := Label.new()
	title.text = "CHARACTER MATERIALS"
	root.add_child(title)
	if target == null:
		var enabled := CheckButton.new()
		enabled.text = "Override saved character materials"
		enabled.button_pressed = global_enabled
		enabled.toggled.connect(func(value: bool): global_enabled = value; save_settings())
		root.add_child(enabled)
	var note := Label.new()
	note.text = "Higher roughness = less shine. Specular controls highlight strength."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size",12)
	root.add_child(note)
	for category in ["skin","clothes","hair"]:
		var header := Label.new()
		header.text = category.capitalize()
		root.add_child(header)
		var fields := ["roughness","specular","metallic","clearcoat"]
		if category == "skin" and target == null and RenderingServer.get_current_rendering_method() == "forward_plus": fields.append("scatter")
		for field in fields:
			var key: String = category+"_"+field
			var row := HBoxContainer.new()
			root.add_child(row)
			var label := Label.new()
			label.text = "Softness / scattering" if field == "scatter" else field.capitalize()
			label.custom_minimum_size.x = 132
			label.add_theme_font_size_override("font_size",12)
			row.add_child(label)
			var slider := HSlider.new()
			slider.name = key
			slider.max_value = 1.0
			slider.min_value = 0.02 if field == "roughness" else 0.0
			slider.step = 0.01
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.custom_minimum_size = Vector2(85,26)
			var settings: Dictionary = target.surface_look if target != null else global_values
			slider.value = float(settings.get(key,DEFAULTS[key]))
			row.add_child(slider)
			var number := Label.new()
			number.text = "%.2f" % slider.value
			number.custom_minimum_size.x = 36
			row.add_child(number)
			slider.value_changed.connect(func(value: float):
				number.text = "%.2f" % value
				if is_instance_valid(target):
					target.surface_look[key] = value
					target.get_node("SurfaceControls").apply_now()
				else:
					global_values[key] = value
					save_settings()
			)
			var refresh := func():
				var values: Dictionary = target.surface_look if is_instance_valid(target) else global_values
				slider.set_value_no_signal(float(values.get(key,DEFAULTS[key])))
				number.text = "%.2f" % slider.value
			slider.set_meta("refresh_surface_control",refresh)
			slider.visibility_changed.connect(refresh)
	var reset := Button.new()
	reset.text = "Reset material values"
	root.add_child(reset)
	reset.pressed.connect(func():
		if is_instance_valid(target):
			target.surface_look = {}
			target.get_node("SurfaceControls").apply_now()
		else:
			global_values = DEFAULTS.duplicate()
			save_settings()
		refresh_ui(root)
	)

static func refresh_ui(root: Node) -> void:
	if root.has_meta("refresh_surface_control"):
		root.get_meta("refresh_surface_control").call()
	for child in root.get_children(): refresh_ui(child)

