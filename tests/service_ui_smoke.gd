extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game);current_scene=game
 await game._start_game()
 game.spawn_timer=99999
 game._record_order_history(20,5,4,null)
 game.perfect_serves=5
 game._check_perfect_rewards()
 game._set_phone_app("orders")
 game._set_phone_expanded(true)
 game._show_challenge_banner("BURGER CHALLENGE — GO!",Color.WHITE,5)
 assert(game.challenge_banner.text.is_empty(),"Only illustrated challenge title")
 assert(game.challenge_banner.get_node("VintageChallengeArt").visible)
 assert(game._order_insights.page.visible)
 assert(game._order_insights.ledger.get_parsed_text().contains("$21.00"))
 game._start_burger_pals_parade("challenge")
 assert(game._parade_presentation.remaining<=5)
 game._parade_presentation._process(5.1)
 assert(not game._parade_presentation.screen.visible)
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/service_polish.png")
 game._stop_burger_pals_parade()
 print("SERVICE_UI_OK")
 game.queue_free()
 for i in 8:await process_frame
 quit()

