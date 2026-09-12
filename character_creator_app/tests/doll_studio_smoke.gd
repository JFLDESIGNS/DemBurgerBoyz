extends SceneTree
var creator
var studio
var failures = []
func _initialize():
	FileAccess.open("C:/Users/joe/Desktop/burgergame/build/studio_"+OS.get_executable_path().get_file()+".result",FileAccess.WRITE).store_string("STARTED")
	call_deferred("run")
func check(condition: bool, message: String):
	if not condition: failures.append(message)
func settle(frames=3):
	for i in frames: await process_frame
func run():
	root.size = Vector2i(1100,720)
	root.content_scale_size = Vector2i(1100,720)
	var path = "res://scenes/character_creator/character_creator.tscn" if ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn") else "res://scenes/main.tscn"
	creator = load(path).instantiate()
	root.add_child(creator)
	await settle(8)
	studio = creator._studio
	check(studio != null, "Studio missing")
	check(studio.defaults.size() > 60, "Snapshot omits appearance properties")
	studio.select_category("Clothes")
	var visible_cards = 0
	for card in studio.cards.Tops:
		if card.button.visible: visible_cards += 1
	check(visible_cards == mini(3,studio.selectors.Tops.item_count), "Empty search must show the first catalog page")
	studio.catalog_turn("Tops",1)
	check(studio.catalog_page.Tops == 1, "Catalog pagination failed")
	var doll = creator.character
	studio.select_category("Hair")
	studio.select_style("Hair",1)
	var old = doll.hair_scale
	creator._adjustment_sliders.hair_scale.value = 1.8
	studio.checkpoint()
	studio.undo()
	check(is_equal_approx(doll.hair_scale,old), "Undo did not restore hair size")
	studio.redo()
	check(is_equal_approx(doll.hair_scale,1.8), "Redo did not restore hair size")
	var before_layers = doll.hair_layer_count()
	creator._on_add_hair_layer()
	studio.checkpoint()
	check(doll.hair_layer_count() == before_layers+1, "Layer was not added")
	studio.undo()
	check(doll.hair_layer_count() == before_layers, "Undo did not remove layer")
	studio.redo()
	check(doll.hair_layer_count() == before_layers+1, "Redo did not restore layer")
	studio.select_category("Face")
	creator._adjustment_sliders.left_eye_yaw.value = -0.35
	check(is_equal_approx(doll.right_eye_yaw,0.35), "Symmetry failed")
	studio.select_category("Hair")
	studio.toggle_lock()
	var locked_style = doll.hair_style
	studio.randomize_section()
	check(doll.hair_style == locked_style, "Locked hair randomized")
	doll.jewelry_style = 2
	doll.shirt_graphic = 7
	studio.apply_starter(2)
	check(doll.jewelry_style == 0 and doll.shirt_graphic == 0, "Starter must reset exported enum defaults")
	check(doll.hair_style == locked_style, "Starter ignored hair lock")
	studio.select_category("Paint")
	await settle()
	check(creator._paint_mode and studio.pages.Paint.is_visible_in_tree(), "Paint mode missing")
	doll.clear_skin_paint()
	studio.paint_changed = true
	studio.checkpoint()
	creator._begin_paint_stroke("Studio regression")
	doll.paint_skin_stamp(Vector2(0.4,0.4),2.0,Color.RED,true)
	creator._paint_stroke_changed = true
	creator._end_paint_stroke()
	await settle()
	check(doll.has_skin_paint(), "Paint not applied")
	studio.undo()
	check(not doll.has_skin_paint(), "Global undo did not restore paint")
	studio.redo()
	check(doll.has_skin_paint(), "Global redo did not restore paint")
	studio.select_category("Pose")
	check(not creator._paint_mode and creator.control_rig_toggle.button_pressed, "Mode transition failed")
	studio.select_category("Clothes")
	check(not creator.control_rig_toggle.button_pressed, "Pose handles visible in Dress")
	studio.focus_feature("mouth")
	check(studio.section == "Mouth", "Direct selection failed")
	for dimensions in [Vector2i(1100,720),Vector2i(900,620),Vector2i(1280,720),Vector2i(1440,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle(4)
		studio.layout()
		await settle(3)
		for cat in studio.CATEGORIES:
			studio.select_category(cat)
			await settle()
			for sub in studio.CATEGORIES[cat]:
				studio.select_section(sub)
				await settle()
				check(studio.page_stack.size.x <= studio.scroll.size.x+1, "Horizontal overflow "+str(dimensions)+" "+sub+" "+str(studio.page_stack.size.x)+"/"+str(studio.scroll.size.x))
				check(studio.inspector.get_global_rect().end.x <= dimensions.x+1, "Inspector clipped")
		check(studio.nav.get_global_rect().end.x <= studio.stage_rect.position.x, "Compact navigation overlaps preview")
		check(studio.footer.get_global_rect().end.y <= dimensions.y+1, "Footer clipped "+str(dimensions))
		check(studio.stage_rect.size.x > 300, "Preview too small")
	studio.select_category("Hair")
	await settle(5)
	studio.checkpoint()
	var history_size = studio.history.size()
	await settle(40)
	studio.checkpoint()
	check(studio.history.size() == history_size, "Idle state creates spurious undo entries")
	if failures.is_empty(): print("DOLL_STUDIO_SMOKE_OK ",path)
	else:
		for failure in failures: push_error(failure)
	FileAccess.open("C:/Users/joe/Desktop/burgergame/build/studio_"+OS.get_executable_path().get_file()+".result",FileAccess.WRITE).store_string("PASS "+path if failures.is_empty() else var_to_str(failures))
	creator.queue_free()
	await settle(2)
	quit(0 if failures.is_empty() else 1)
