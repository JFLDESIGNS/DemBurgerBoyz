extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(90).timeout.connect(func(): quit(1))
 var path = "res://scenes/character_creator/character_creator.tscn" if ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn") else "res://scenes/main.tscn"
 var creator = load(path).instantiate()
 root.add_child(creator)
 for i in 12: await process_frame
 creator._studio.select_category("Body")
 creator._studio.select_section("Materials")
 var slider = creator._studio.pages.Materials.find_child("hair_roughness",true,false)
 assert(slider.is_visible_in_tree())
 slider.value = 0.94
 creator.character_name.text = "Material Smoke"
 creator._save_character()
 slider.value = 0.4
 creator._load_character_file("user://characters/material_smoke.json")
 assert(is_equal_approx(creator.character.surface_look.hair_roughness,0.94))
 assert(is_equal_approx(slider.value,0.94))
 for i in 20: await process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("SURFACE_SCREENSHOT"))
 print("SURFACE_CREATOR_OK visible controls and preset save/reload")
 quit()
