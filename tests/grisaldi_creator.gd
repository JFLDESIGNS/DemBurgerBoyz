extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(30).timeout.connect(func():quit(1))
 var creator=load("res://scenes/character_creator/character_creator.tscn").instantiate()
 root.add_child(creator);current_scene=creator
 await process_frame
 creator._load_character_file("res://defaults/grisaldi.json")
 await process_frame
 assert(creator.character_name.text=="Grisaldi")
 assert(creator.character.hair_style==18 and creator.character.top_style==16)
 assert(is_equal_approx(creator.character.hair_offset.y,.48))
 assert(creator.saved_customers.get_child(0).text.begins_with("Grisaldi"))
 creator.character.hair_offset.y+=.02
 assert(is_equal_approx(creator.character.hair_offset.y,.50))
 creator.character.hair_offset.y-=.02
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("C:/Users/joe/Desktop/burgergame/output/grisaldi_creator.png")
 print("GRISALDI_CREATOR_EDITABLE_OK");quit()
