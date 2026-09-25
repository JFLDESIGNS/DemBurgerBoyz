extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var surface = load("res://scripts/character_surface_controls.gd")
	var path := "res://scenes/character_creator/modular_character_base.tscn"
	if not ResourceLoader.exists(path): path = "res://scenes/modular_character_base.tscn"
	var actor = load(path).instantiate()
	actor.hair_style = 1
	actor.top_style = 1
	root.add_child(actor)
	await process_frame
	actor.surface_look = {"hair_roughness":0.97,"hair_specular":0.03,"skin_specular":0.25,"clothes_roughness":0.65}
	actor.get_node("SurfaceControls").apply_now()
	assert(is_equal_approx(float(actor._skin_material.get_shader_parameter("surface_specular")),0.25))
	var hairs = actor._hair_root.find_children("*","MeshInstance3D",true,false)
	assert(not hairs.is_empty())
	var hair: StandardMaterial3D = hairs[0].material_override
	assert(hair.cull_mode == BaseMaterial3D.CULL_DISABLED, "Hair must render both sides")
	assert(is_equal_approx(hair.roughness,0.97) and is_equal_approx(hair.metallic_specular,0.03))
	var ui := VBoxContainer.new()
	root.add_child(ui)
	surface.build_ui(ui,actor)
	var slider: HSlider = ui.find_child("hair_roughness",true,false)
	slider.value = 0.85
	assert(is_equal_approx(hair.roughness,0.85))
	actor.gameplay_character = true
	surface.global_enabled = true
	surface.global_values.hair_roughness = 0.72
	surface.save_settings()
	actor.get_node("SurfaceControls").apply_now()
	assert(is_equal_approx(hair.roughness,0.72))
	surface.global_enabled = false
	actor.get_node("SurfaceControls").apply_now()
	assert(is_equal_approx(hair.roughness,0.85),"Disabling override must restore the character preset")
	if actor.has_method("apply_saved_preset"):
		actor.apply_saved_preset({"surface_look":{"hair_roughness":0.91}})
		assert(is_equal_approx(float(actor.surface_look.hair_roughness),0.91))
	print("CHARACTER_SURFACE_OK live UI, skin shader, hair, global override, preset")
	actor.queue_free()
	ui.queue_free()
	await process_frame
	quit()
