extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var packed := load("res://scenes/character_creator/character_creator.tscn") as PackedScene
	var editor := packed.instantiate()
	root.add_child(editor)
	for _frame in 5:await process_frame
	var menu := editor.find_child("AnimationSelect",true,false) as OptionButton
	assert(menu != null)
	assert(menu.item_count == 30,"Three existing previews plus 27 authored clips")
	assert(menu.get_item_text(11) == "Take Burger Fast")
	assert(menu.get_item_text(19) == "Eat Burger Fast")
	var character := editor.get("character") as Node
	character.start_preview_animation(19)
	await process_frame
	assert(character.is_preview_animation_playing())
	character.stop_preview_animation()
	print("BURGER27_EDITOR_MENU_SMOKE_OK")
	editor.free()
	quit()
