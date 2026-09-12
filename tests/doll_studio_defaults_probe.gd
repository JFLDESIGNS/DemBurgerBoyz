extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var c = load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(c)
	for i in 8: await process_frame
	print("DEFAULT_ENUMS ",c._studio.defaults.get("jewelry_style","missing")," ",c._studio.defaults.get("shirt_graphic","missing")," ",c._studio.defaults.get("mouth_style","missing"))
	c._studio.apply_starter(0)
	print("STARTER_ENUMS ",c.character.jewelry_style," ",c.character.shirt_graphic," ",c.character.mouth_style)
	for i in 5: await process_frame
	print("AFTER_ENUMS ",c.character.jewelry_style," ",c.character.shirt_graphic," ",c.character.mouth_style)
	quit()
