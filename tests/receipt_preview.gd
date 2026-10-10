extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,1000)
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem: child.hide()
 game.total_served=31;game.perfect_serves=14
 game.shift_food_sales=373;game.shift_tips=39;game.shift_ingredient_cost=141.45;game.last_day_cut=186.50;game.shift_restock_spend=35.70
 game.money=287.80
 game.game_over_location_btn=Button.new();game.game_over_panel.add_child(game.game_over_location_btn)
 game.day_social_reviews=[{"who":"Sam","stars":5.0,"text":"Fresh, perfectly cooked and worth coming back for!"},{"who":"Casey","stars":2.0,"text":"The wait was a little long, but the fries were great."}]
 var results=load("res://scripts/shift_results.gd").new()
 game.add_child(results);results.setup(game);results.rebuild()
 game.game_over_panel.show()
 await create_timer(.3).timeout
 assert(game.game_over_panel.size.y<root.size.y)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/customer_polish_qa/receipt_preview.png")
 print("RECEIPT_PREVIEW_OK")
 quit()
