extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(180).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 await g._start_game()
 g.spawn_timer=99999
 var m=g._grubbah
 m.state={"number":1,"items":["bun_bottom","patty","cheese","bun_top"],"phase":"paper","base":15,"quality":1.0};m.age=2
 g._set_phone_app("grubbah");g._set_phone_expanded(true)
 await create_timer(3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/grubbah_kitchen.png")
 m.state.phase="pickup";m.age=8
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/grubbah_pickup.png")
 print("GRUBBAH_KITCHEN_OK")
 quit()
