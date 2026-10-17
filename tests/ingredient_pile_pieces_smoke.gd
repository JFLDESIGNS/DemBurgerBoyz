extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(180).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 await g._start_game()
 g.spawn_timer=99999
 await create_timer(2).timeout
 var btn=g.ingredient_buttons.tomato
 var pieces=btn.get_node("PilePieces")
 pieces.set_process(false)
 var icon=pieces.icon
 g.supply_stock.tomato=4;pieces.previous_stock=-1;pieces._process(.7)
 assert(pieces.visible and icon.self_modulate.a==1.0)
 g._pending_ingredient_drag="tomato";pieces._process(.016)
 assert(icon.self_modulate.a==0.0 and pieces.flight_age==0.0)
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/ingredient_pile_hidden.png")
 g._pending_ingredient_drag="";g.supply_stock.tomato=3
 pieces._process(.3);assert(icon.self_modulate.a==0.0)
 pieces._process(.35);assert(icon.self_modulate.a==1.0)
 g.supply_stock.tomato=0;pieces._process(.016)
 assert(not pieces.visible and icon.self_modulate.a==0.0)
 g.supply_stock.tomato=4;pieces._process(.7)
 assert(pieces.visible and icon.self_modulate.a==1.0)
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/ingredient_pile_pieces.png")
 print("INGREDIENT_PILE_PIECES_OK: drag, use, refill timing, empty stock, restock")
 quit()
