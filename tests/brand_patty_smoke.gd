extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game);current_scene=game
 await game._start_game()
 game.spawn_timer=99999
 game._set_phone_app("home");game._set_phone_expanded(true)
 var st:Dictionary=game.stations[game.STATION_CRAFT]
 st.items=["bun_bottom","patty","lettuce","tomato"]
 st.patties=[]
 game._refresh_station(game.STATION_CRAFT)
 game.fryer_ready_servings=2
 game._refresh_ready_fries_visuals()
 var effects: Array=st.preview.find_children("PattyHeatOverlay","",true,false)
 assert(effects.size()==1)
 var fx=effects[0]
 assert(fx.bubbles.is_empty() and fx.steam!=null)
 assert(st.preview.find_children("PattyBubbles","",true,false).size()==1)
 assert(fx.z_index==100 and not fx.z_as_relative)
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/brand_patty_preview.png")
 fx.age=15.1;fx._process(.016)
 for bubble in fx.bubbles:assert(not bubble.visible)
 game._show_gameplay_loading_screen()
 game.set_meta("loading_phase","runtime_pools")
 await create_timer(.2).timeout
 var progress=game._gameplay_load_overlay.get_node("KitchenLoadingProgress")
 assert(progress.bar.value>=84)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/loading_progress_preview.png")
 game._hide_gameplay_loading_screen()
 game._show_customer_review_ui(4.5,"Nice browning, fresh toppings, and just the right seasoning.")
 game._shift_events.show_profit(18,7.5)
 game.order_history=[{"day":game.day,"perfect":true}]
 await create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/presentation_hud.png")
 game.challenge_overlay.show()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/presentation_challenge.png")
 print("BRAND_PATTY_OK")
 quit()
