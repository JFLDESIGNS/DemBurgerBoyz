extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Node3D.new()
	game.name = "Game"
	root.add_child(game)
	var world := Node3D.new()
	world.name = "World"
	game.add_child(world)
	var grill := Node3D.new()
	grill.name = "Grill"
	game.add_child(grill)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	world.add_child(sun)
	var nested := Node3D.new()
	nested.name = "Ceiling"
	game.add_child(nested)
	var spot := SpotLight3D.new()
	spot.name = "CeilingSpot"
	nested.add_child(spot)
	var omni := OmniLight3D.new()
	omni.name = "GrillOmni"
	grill.add_child(omni)
	var preview := SubViewport.new()
	game.add_child(preview)
	var preview_light := OmniLight3D.new()
	preview.add_child(preview_light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,2,5)
	var editor = load("res://scripts/level_editor.gd").new()
	game.add_child(editor)
	editor.setup(game, world, grill, camera)
	editor.set_active(true)
	assert(editor._outliner_nodes.has(spot), "Existing lights outside World/Grill must appear")
	assert(editor._outliner_nodes.has(sun) and editor._outliner_nodes.has(omni))
	assert(not editor._outliner_nodes.has(preview_light), "Preview viewport lights must be excluded")
	editor._select(spot)
	var picker: ColorPickerButton = editor._inspector.get_node("LightColorPicker")
	picker.color_changed.emit(Color("ff6633"))
	assert(spot.light_color.is_equal_approx(Color("ff6633")))
	var row = editor._inspector.get_node("spot_attenuation")
	var spin: SpinBox = row.get_child(1)
	spin.value = 2.5
	assert(is_equal_approx(spot.spot_attenuation, 2.5))
	editor._set_light_property(sun, "light_angular_distance", 2.0)
	editor._set_light_property(sun, "directional_shadow_max_distance", 75.0)
	editor._set_light_property(omni, "light_energy", 4.0)
	editor._set_sel_pos("x", 1.25)
	spot.light_color = Color.BLUE
	omni.light_energy = 0.0
	editor._apply_existing_light_overrides()
	assert(spot.light_color.is_equal_approx(Color("ff6633")))
	assert(is_equal_approx(omni.light_energy, 4.0))
	var placed: SpotLight3D = editor._make_dressing_light("rect_area")
	placed.name = "SavedArea"
	editor._finish_place(placed)
	editor._set_light_property(placed, "light_color", Color("55ffaa"))
	editor._set_light_property(placed, "spot_angle_attenuation", 3.5)
	editor._set_light_property(placed, "distance_fade_enabled", true)
	editor._set_light_property(placed, "light_indirect_energy", 2.2)
	editor._load_dressing()
	var restored: SpotLight3D = editor._dressing.get_node("SavedArea")
	assert(restored.light_color.is_equal_approx(Color("55ffaa")))
	assert(is_equal_approx(restored.spot_angle_attenuation, 3.5) and restored.distance_fade_enabled)
	assert(is_equal_approx(restored.light_indirect_energy, 2.2))
	assert(is_equal_approx(spot.position.x, 1.25))
	var cfg := ConfigFile.new()
	assert(cfg.load(editor.SAVE_PATH) == OK and cfg.has_section_key("level_lights", "overrides"))
	editor._reset_light_override(spot)
	assert(spot.light_color == Color.WHITE and is_zero_approx(spot.position.x))
	assert(is_equal_approx(omni.light_energy, 4.0), "Reset must affect only selected light")
	editor._set_light_property(omni, "light_color", Color.RED)
	omni.light_energy = 1.5
	editor._reset_light_override(omni)
	assert(is_equal_approx(omni.light_energy, 1.0))
	print("LEVEL_LIGHT_EDITING_OK discovery, UI color, per-type properties, overrides, persistence, reset")
	editor._select(spot)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/light_editor_release/inspector.png")
	var color_button: ColorPickerButton = editor._inspector.get_node("LightColorPicker")
	color_button.get_popup().popup_centered()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/light_editor_release/color_picker.png")
	print("LIGHT_EDITOR_VISUAL_OK")
	quit()
