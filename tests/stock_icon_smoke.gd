extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(120).timeout.connect(func(): quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 while not game.menu_ready: await process_frame
 game._build_phone_ui()
 game._set_phone_in_truck(true)
 game._set_phone_app("shop")
 await process_frame
 for id in game.SUPPLY_IDS:
  var icon = game.phone_inventory_box.find_child("IngredientIcon_" + str(id),true,false)
  assert(icon != null and icon.texture != null,"Missing ingredient icon: " + str(id))
 assert(is_equal_approx(game.PATTY_FRIDGE_LID_OPEN_SEC,0.74/3.0))
 assert(game.game_audio.has_method("play_delivery_whoosh"))
 assert(game.game_audio.has_method("play_delivery_impact"))
 print("STOCK_ICONS_OK all supply textures, faster box, delivery audio")
 quit()
