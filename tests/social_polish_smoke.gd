extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(90).timeout.connect(func():quit(1))
 root.size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("social_polish_fixture.gd")))
 root.add_child(game);current_scene=game;game.playing=true
 game._show_boss_caption("BOSS","Protected machine pitch",2.0)
 var caption=game.flash_label.text
 game._flash("Perfect flip!",Color.WHITE)
 game._tutorial_text="Tutorial must not interrupt";game._apply_tutorial_hint_visibility()
 game._set_bts_intro_banner_text("Other announcement")
 assert(game.flash_label.text==caption)
 game._hide_boss_caption();game._flash("Ordinary messages resume",Color.WHITE)
 assert(game.flash_label.text=="Ordinary messages resume")
 game.owned_machines[game.SHOP_FRYER_MACHINE]=true
 game._show_boss_machine(game.SHOP_FRYER_MACHINE,2.0)
 assert(game.get_node_or_null("UI/Root/BossMachineShowcase")==null)
 # The foreground patty can still be smashed while exactly one ready patty behind flips.
 game.camera.look_at_from_position(Vector3(0,3,-4),Vector3.ZERO)
 for i in 3:
  var patty=load("res://scripts/patty.gd").new();game.add_child(patty);patty.set_process(false)
  patty.position=Vector3((i-1)*.10,0,i*.2)
  patty.cook_time=0 if i==0 else 16.0
  game.grill.append(patty)
 game.foreground=game.grill[0]
 game.dragging_patty=game.foreground
 game.drag_start_mouse=game.camera.unproject_position(game.foreground.global_position)
 game.drag_press_sec=Time.get_ticks_msec()*.001
 assert(game._pick_flip_ready_patty_forgiving(game.drag_start_mouse)!=null)
 game._end_patty_drag()
 assert(game.flips==1 and game.smashes==1 and not game.foreground.flipped_once)
 # Draw the product at two distinct turntable angles and burst phases.
 game.owned_machines[game.SHOP_FRYER_MACHINE]=false
 game.fryer_root=load("res://assets/machines/fryer.glb").instantiate();game.add_child(game.fryer_root);game.fryer_root.hide()
 game._show_boss_caption("THE BOSS",game.BOSS_FRYER_ADVICE,30.0)
 game._show_boss_machine(game.SHOP_FRYER_MACHINE,30.0)
 var showcase=game.get_node("UI/Root/BossMachineShowcase")
 assert(showcase.get_child(0).size.x==720 and showcase.price.text=="$100")
 for node in game.get_node("UI/Root").get_children():
  if node is CanvasItem and node!=showcase and node!=game.flash_label: node.hide()
 var burst=game._make_burger_completion_burst();game.get_node("UI/Root").add_child(burst);burst.position=Vector2(220,420);burst.show()
 game._update_burger_completion_burst(burst,.35)
 assert(burst.get_node("WarmGlow").scale.x>3.0)
 game.stations=[{"items":["bun_bottom","patty","cheese","lettuce","bun_top"],"patties":[],"preview":null}]
 game._ensure_serve_fx_pools()
 var fly=game._acquire_serve_fly_root()
 var built=game._build_serve_fly_stack(fly,0)
 var stack=built.stack
 stack.pivot_offset=built.pivot
 game._place_burger_sprite_center(stack,Vector2(220,420))
 if DisplayServer.get_name()!="headless":
  await create_timer(.3).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/social_polish_showcase.png")
  await create_timer(1.0).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/social_polish_showcase_later.png")
 print("SOCIAL_POLISH_OK")
 game.queue_free();await process_frame;quit()
