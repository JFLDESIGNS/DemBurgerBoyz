extends Node
## One sunlight direction and colored ambient; a separate grade never quantizes materials.
const SAVE_PATH := "user://light_balance.cfg"
const DEFAULTS := {
	"rays_mode": 1, "rays_strength": 0.35, "rays_density": 0.045, "rays_length": 16.0,
	"rays_reach": 0.85, "rays_blocker_distance": 5.0, "rays_color": Color("ffd58a"),
	"rays_follow_sun": false, "rays_x": 0.78, "rays_y": 0.08,
	"simple": true, "placed_lights": true, "sun_energy": 2.0, "sun_color": Color("ffe08a"),
	"ambient_energy": 0.8, "ambient_color": Color("a3baff"),
	"azimuth": 76.0, "elevation": 24.0, "softness": 0.65,
	"bias": 0.06, "normal_bias": 1.0, "specular": 0.3,
	"post_enabled": true, "exposure": 0.9, "tonemap": 2,
	"bloom_enabled": true, "bloom": 0.06, "bloom_intensity": 0.35,
	"bloom_strength": 0.8, "bloom_threshold": 1.1,
	"grade_mix": 1.0, "brightness": 1.0, "contrast": 1.06, "saturation": 1.12,
	"gamma": 1.0, "temperature": 0.02, "tint": 0.0, "vibrance": 0.12,
	"lift": 0.0, "gain": 1.0, "rolloff": 0.08,
	"shadow_tint": Color("8ca6f0"), "highlight_tint": Color("ffdc78"),
	"shadow_mix": 0.10, "highlight_mix": 0.10, "balance": 0.48,
	"transition_width": 0.18, "transition_saturation": 0.32,
	"vignette": 0.08, "vignette_radius": 0.75, "grain": 0.0,
	"sharpen": 0.0, "aberration": 0.0
}
const GRAPHICS_KEYS := {
	"sun": "sun_energy", "ambient": "ambient_energy", "exposure": "exposure",
	"saturation": "saturation", "contrast": "contrast", "glow_on": "bloom_enabled",
	"bloom": "bloom", "glow_intensity": "bloom_intensity",
	"glow_strength": "bloom_strength", "glow_threshold": "bloom_threshold"
}
var values: Dictionary = DEFAULTS.duplicate()
var game: Node
var rays: Node3D
var sun: DirectionalLight3D
var panel: PanelContainer
var controls := {}
var number_controls := {}
var section_headers := {}
var suppressed := {}
var save_timer: Timer

func setup(owner_game: Node) -> void:
	game = owner_game
	process_priority = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key in DEFAULTS:
			var value = cfg.get_value("balance", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]) or (value is int and DEFAULTS[key] is float):
				values[key] = value
	if not bool(cfg.get_value("meta", "placed_lights_v2", false)):
		values.placed_lights = true
		save()
	# The original low offsets caused shadow-map acne on grazing-angle counters.
	# Migrate only unsafe offsets once; preserve colors, grading and sun direction.
	if not bool(cfg.get_value("meta", "shadow_contact_v2", false)):
		values.bias = maxf(float(values.bias), float(DEFAULTS.bias))
		values.normal_bias = maxf(float(values.normal_bias), float(DEFAULTS.normal_bias))
		save()
	sun = DirectionalLight3D.new()
	sun.name = "BalancedSun"
	game.world.add_child(sun)
	game._style_dir_shadows(sun)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	save_timer.timeout.connect(save)
	add_child(save_timer)
	rays = preload("res://scripts/sun_rays.gd").new()
	rays.name = "SunRays"
	game.world.add_child(rays)
	rays.setup(game, self)

func _exit_tree() -> void:
	if save_timer != null and not save_timer.is_stopped():
		save()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shadow_contact_v2", true)
	cfg.set_value("meta", "placed_lights_v2", true)
	for key in values:
		cfg.set_value("balance", key, values[key])
	cfg.save(SAVE_PATH)

func _process(_delta: float) -> void:
	# Dressing loads after the main rig. Keep authored transforms and colors;
	# restore visibility when the simple rig or placed-light suppression is bypassed.
	if bool(values.simple):
		for light in suppressed.keys():
			if not is_instance_valid(light): suppressed.erase(light)
		var lights: Array = game._classic_rig_lights()
		if is_instance_valid(game._light_profile_root):
			lights.append_array(game._light_profile_root.get_children())
		if is_instance_valid(game.level_editor) and is_instance_valid(game.level_editor._dressing):
			for light in game.level_editor._dressing.get_children():
				if light is Light3D and (not bool(values.placed_lights) or str(light.name) in ["WarmWindowKey", "WarmWindowCustomerFill"]):
					lights.append(light)
		for light in suppressed.keys():
			if is_instance_valid(light) and not lights.has(light):
				light.visible = bool(light.get_meta("balance_authored_visible", suppressed[light]))
				light.remove_meta("balance_authored_visible")
				suppressed.erase(light)
		for light in lights:
			if is_instance_valid(light) and light is Light3D:
				if not suppressed.has(light):
					suppressed[light] = light.visible
					light.set_meta("balance_authored_visible", light.visible)
				light.visible = false

func apply() -> void:
	if not is_instance_valid(sun): return
	sun.visible = bool(values.simple)
	if values.simple:
		sun.light_color = values.sun_color
		sun.light_energy = float(values.sun_energy)
		sun.light_specular = float(values.specular)
		sun.shadow_enabled = game._gfx_bool("shadows", true)
		sun.shadow_bias = float(values.bias)
		sun.shadow_normal_bias = float(values.normal_bias)
		sun.light_angular_distance = float(values.softness)
		sun.shadow_blur = 1.0
		sun.directional_shadow_max_distance = game._sun_shadow_distance()
		game._orient_sun_from_sky(sun, float(values.azimuth), float(values.elevation))
		_process(0.0)
	else:
		for light in suppressed:
			if is_instance_valid(light):
				light.visible = bool(light.get_meta("balance_authored_visible", suppressed[light]))
				light.remove_meta("balance_authored_visible")
		suppressed.clear()
	var env: Environment = game.gfx_env
	if env != null:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if values.simple else Environment.AMBIENT_SOURCE_SKY
		if values.simple:
			env.ambient_light_color = values.ambient_color
			env.ambient_light_sky_contribution = 0.0
			env.ambient_light_energy = float(values.ambient_energy)
		else:
			env.ambient_light_sky_contribution = 1.0
		env.tonemap_exposure = float(values.exposure)
		env.tonemap_mode = int(values.tonemap)
		env.glow_enabled = bool(values.bloom_enabled)
		env.glow_bloom = float(values.bloom)
		env.glow_intensity = float(values.bloom_intensity)
		env.glow_strength = float(values.bloom_strength)
		env.glow_hdr_threshold = float(values.bloom_threshold)
		env.adjustment_enabled = false
	if game.screen_style_mat != null:
		for uniform in game.screen_style_mat.shader.get_shader_uniform_list():
			var key := str(uniform.name).trim_prefix("grade_")
			if str(uniform.name).begins_with("grade_") and values.has(key):
				game.screen_style_mat.set_shader_parameter(uniform.name, values[key])
		game.screen_style_layer.visible = bool(values.post_enabled) or game._gfx_bool("toon_filter", false) or game._gfx_bool("pixel_filter", false)

	if is_instance_valid(rays): rays.apply()

func set_from_graphics(key: String, value: Variant) -> void:
	if GRAPHICS_KEYS.has(key):
		set_value(GRAPHICS_KEYS[key], value)

func set_value(key: String, value: Variant) -> void:
	values[key] = value
	for graphics_key in GRAPHICS_KEYS:
		if GRAPHICS_KEYS[graphics_key] != key: continue
		for collection in [game.gfx_sliders, game.options_graphics_sliders]:
			if collection.has(graphics_key) and is_instance_valid(collection[graphics_key]):
				collection[graphics_key].set_value_no_signal(float(value))
		for collection in [game.gfx_checks, game.options_graphics_checks]:
			if collection.has(graphics_key) and is_instance_valid(collection[graphics_key]):
				collection[graphics_key].set_pressed_no_signal(bool(value))
	if controls.has(key):
		var control: Control = controls[key]
		if control is Range: control.set_value_no_signal(float(value))
		elif control is OptionButton: control.select(int(value))
		elif control is ColorPickerButton: control.color = value
		elif control is BaseButton: control.set_pressed_no_signal(bool(value))
	if number_controls.has(key): number_controls[key].set_value_no_signal(float(value))
	if key == "simple": game._sync_light_profile()
	apply()
	save_timer.start()

func show_panel(parent: Control) -> void:
	if is_instance_valid(panel):
		panel.visible = not panel.visible
		return
	panel = PanelContainer.new()
	panel.name = "LightBalancePanel"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -410
	panel.offset_right = -8
	panel.offset_top = 8
	panel.offset_bottom = -8
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17202a")
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "LIGHT BALANCE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): panel.hide())
	heading.add_child(close)
	var hint := Label.new()
	hint.text = "Live preview · automatically saved\nYellow sun / blue ambient · one shadow direction"
	hint.add_theme_font_size_override("font_size", 12)
	layout.add_child(hint)
	var jumps := HBoxContainer.new()
	layout.add_child(jumps)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)
	for entry in [["Sun", "SUN & SHADOW CONTACT"], ["Rays", "SUN RAYS / 2D & 3D"], ["Bloom", "EXPOSURE & BLOOM"], ["Color", "POST PROCESSING / COLOR GRADE"], ["Lens", "LENS & TEXTURE"]]:
		var jump := Button.new()
		jump.text = entry[0]
		jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jumps.add_child(jump)
		jump.pressed.connect(func(): scroll.scroll_vertical = int(section_headers[entry[1]].position.y))
	check(body, "simple", "Simple sun + ambient")
	check(body, "placed_lights", "Keep placed accent lights")
	section(body, "SUN & SHADOW CONTACT")
	color_control(body, "sun_color", "Sun color")
	slider(body,"sun_energy","Sun intensity",0,5)
	slider(body,"azimuth","Sun direction / window = 90°",-15,110,1)
	slider(body,"elevation","Sun elevation",16,58,1)
	slider(body,"softness","Shadow softness",0,4)
	slider(body,"bias","Shadow depth offset",0,0.2,0.001)
	slider(body,"normal_bias","Shadow surface offset",0,2,0.01)
	slider(body,"specular","Sun specular",0,1)
	section(body,"SUN RAYS / 2D & 3D")
	var modes := OptionButton.new()
	for label in ["Off", "2D · depth occluded", "3D · shadowed volume", "Both"]: modes.add_item(label)
	modes.selected = int(values.rays_mode)
	modes.item_selected.connect(func(index: int): set_value("rays_mode", index))
	body.add_child(modes)
	controls["rays_mode"] = modes
	color_control(body,"rays_color","Ray color")
	slider(body,"rays_strength","Ray intensity",0,2)
	slider(body,"rays_density","3D dust density",0,0.2,0.001)
	slider(body,"rays_length","3D distance",5,40,1)
	slider(body,"rays_reach","2D shaft length",0.1,1.5)
	slider(body,"rays_blocker_distance","2D foreground blocking distance",1,15,0.1)
	check(body,"rays_follow_sun","2D follow sun direction")
	slider(body,"rays_x","2D source horizontal",-0.5,1.5)
	slider(body,"rays_y","2D source vertical",-0.5,1.5)
	var ray_hint := Label.new()
	ray_hint.text = "2D uses visible scene depth. 3D uses sun shadows.\n3D requires Forward+ and sun shadows enabled."
	ray_hint.add_theme_font_size_override("font_size",11)
	body.add_child(ray_hint)
	section(body,"AMBIENT / BLUE SHADOWS")
	color_control(body,"ambient_color","Ambient color")
	slider(body,"ambient_energy","Ambient intensity",0,2)
	section(body,"EXPOSURE & BLOOM")
	slider(body,"exposure","Exposure",0.2,2.5)
	var tone_row := HBoxContainer.new()
	body.add_child(tone_row)
	var tone_label := Label.new()
	tone_label.text = "Tone mapper"
	tone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tone_row.add_child(tone_label)
	var tone := OptionButton.new()
	for label in ["Linear", "Reinhard", "Filmic", "ACES", "AgX"]: tone.add_item(label)
	tone.selected = int(values.tonemap)
	tone.item_selected.connect(func(index: int): set_value("tonemap",index))
	tone_row.add_child(tone)
	controls["tonemap"] = tone
	check(body,"bloom_enabled","Bloom enabled")
	slider(body,"bloom","Bloom amount",0,1)
	slider(body,"bloom_intensity","Bloom intensity",0,2)
	slider(body,"bloom_strength","Bloom strength",0,2)
	slider(body,"bloom_threshold","Bloom threshold",0.1,3)
	section(body,"POST PROCESSING / COLOR GRADE")
	check(body,"post_enabled","Enable color grade & lens effects")
	slider(body,"grade_mix","Grade mix / before–after",0,1)
	for item in [["brightness","Brightness",0.3,2],["contrast","Contrast",0.5,1.8],["saturation","Saturation",0,2],["gamma","Gamma",0.4,2.2],["temperature","Temperature / cool–warm",-1,1],["tint","Tint / green–magenta",-1,1],["vibrance","Vibrance",-1,1],["lift","Black lift",-0.2,0.2],["gain","Highlight gain",0.5,1.5],["rolloff","Highlight rolloff",0,1]]:
		slider(body,item[0],item[1],item[2],item[3])
	section(body,"SHADOW / LIGHT COLOR TRANSITION")
	color_control(body,"shadow_tint","Shadow tint")
	color_control(body,"highlight_tint","Light tint")
	slider(body,"shadow_mix","Shadow color amount",0,1)
	slider(body,"highlight_mix","Light color amount",0,1)
	slider(body,"balance","Transition position",0.1,0.9)
	slider(body,"transition_width","Transition width",0.02,0.6)
	slider(body,"transition_saturation","Transition saturation",0,1.5)
	var note := Label.new()
	note.text = "Color transition follows image brightness. Sun direction\nand shadow offsets control the actual shadow boundary."
	note.add_theme_font_size_override("font_size",11)
	body.add_child(note)
	section(body,"LENS & TEXTURE")
	slider(body,"vignette","Vignette",0,0.8)
	slider(body,"vignette_radius","Vignette radius",0.2,1.2)
	slider(body,"grain","Film grain",0,0.15,0.001)
	slider(body,"sharpen","Sharpen",0,1)
	slider(body,"aberration","Chromatic aberration",0,4,0.1)
	var reset := Button.new()
	reset.text = "Reset Light Balance to sunny blue / gold"
	reset.pressed.connect(func():
		values = DEFAULTS.duplicate()
		game._sync_light_profile()
		apply()
		save()
		panel.get_parent().remove_child(panel)
		panel.queue_free()
		panel = null
		controls.clear()
		number_controls.clear()
		section_headers.clear()
		show_panel(parent)
	)
	layout.add_child(reset)

func section(parent: Control, text: String) -> void:
	parent.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color("ffdb87"))
	parent.add_child(label)
	section_headers[text] = label

func check(parent: Control, key: String, text: String) -> void:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = bool(values[key])
	button.toggled.connect(func(on: bool): set_value(key,on))
	parent.add_child(button)
	controls[key] = button

func color_control(parent: Control, key: String, text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(90,28)
	picker.edit_alpha = false
	picker.color = values[key]
	picker.color_changed.connect(func(color: Color): set_value(key,color))
	row.add_child(picker)
	controls[key] = picker

func slider(parent: Control, key: String, text: String, low: float, high: float, step: float = 0.01) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)
	var top := HBoxContainer.new()
	row.add_child(top)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var number := SpinBox.new()
	number.min_value = low
	number.max_value = high
	number.step = step
	number.value = float(values[key])
	number.custom_minimum_size.x = 92
	top.add_child(number)
	number_controls[key] = number
	var bar := HSlider.new()
	bar.min_value = low
	bar.max_value = high
	bar.step = step
	bar.value = float(values[key])
	bar.custom_minimum_size.y = 22
	row.add_child(bar)
	bar.value_changed.connect(func(value: float):
		number.set_value_no_signal(value)
		set_value(key,value)
	)
	number.value_changed.connect(func(value: float):
		bar.set_value_no_signal(value)
		set_value(key,value)
	)
	controls[key] = bar
