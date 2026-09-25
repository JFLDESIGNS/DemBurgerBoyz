extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,380)
 var game=load("res://scripts/game.gd").new()
 var stage=Control.new()
 root.add_child(stage)
 var background=ColorRect.new()
 background.color=Color("302523")
 background.size=Vector2(1000,380)
 stage.add_child(background)
 for i in 3:
  var burst=game._make_burger_completion_burst()
  stage.add_child(burst)
  burst.position=Vector2(170+330*i,190)
  burst.show()
  game._update_burger_completion_burst(burst,.2+.3*i)
  assert(burst.get_node("FlyingAccents").get_child_count()==14)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/burger_burst_preview.png")
 game.free()
 print("BURGER_BURST_VISUAL_OK")
 quit()
