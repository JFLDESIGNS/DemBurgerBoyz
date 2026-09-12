extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1100,720)
	root.content_scale_size = Vector2i(1100,720)
	var standalone = not ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn")
	var c = load("res://scenes/main.tscn" if standalone else "res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(c)
	for i in 10: await process_frame
	var had_last = FileAccess.file_exists("user://last_character.json")
	var previous = FileAccess.get_file_as_bytes("user://last_character.json") if had_last else PackedByteArray()
	var name_text = "Studio QA "+str(Time.get_ticks_usec())
	c.character_name.text = name_text
	c._studio.select_category("Hair")
	c._studio.select_style("Hair",1)
	c._on_add_hair_layer()
	c.character.set_hair_layer_visible(0,false)
	c.character.set_hair_layer_visible(1,false)
	c.character.paint_skin_stamp(Vector2(0.4,0.4),2.0,Color.RED,true)
	c._studio.paint_checkpoint()
	c._save_character()
	for i in 20: await process_frame
	var stem = "user://characters/"+c._safe_file_name(name_text)
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(stem+".json"))
	var png_ok = FileAccess.file_exists(stem+"_thumb.png")
	c.character.hair_visible = true
	c.character.extra_hairs = []
	c.character.clear_skin_paint()
	c._load_character_file(stem+".json")
	var restored = not c.character.hair_visible and c.character.hair_layer_count() > 1 and not c.character.get_hair_layer(1).visible and c.character.has_skin_paint()
	# Restore the user's last preset and remove only this uniquely named test design.
	if had_last: FileAccess.open("user://last_character.json",FileAccess.WRITE).store_buffer(previous)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://last_character.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stem+".json"))
	if png_ok: DirAccess.remove_absolute(ProjectSettings.globalize_path(stem+"_thumb.png"))
	c._refresh_saved_customers()
	var passed = persisted is Dictionary and not persisted.hair_visible and not persisted.extra_hairs[0].visible and png_ok and restored
	var output = "C:/Users/joe/Desktop/burgergame/build/studio_save_"+("standalone" if standalone else "foodflip")+".result"
	FileAccess.open(output,FileAccess.WRITE).store_string("PASS" if passed else "FAIL: persisted="+str(persisted is Dictionary)+" portrait="+str(png_ok)+" restored="+str(restored))
	print("STUDIO_SAVE_ROUNDTRIP ",passed)
	quit(0 if passed else 1)
