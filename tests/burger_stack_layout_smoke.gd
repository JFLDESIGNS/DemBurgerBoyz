extends SceneTree
class Patty extends Node3D:
 var has_cheese:=true
 var cook_time:=30.0
 var cheese_melt:=1.0
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 game._style_static_labels();game._setup_stations_data();game._build_station_ui()
 game.playing=true
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem: child.hide()
 var bg:=ColorRect.new();bg.color=Color("665a42");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 game.get_node("UI/Root").add_child(bg)
 var st:Dictionary=game.stations[game.STATION_CRAFT]
 var preview:Control=st.preview
 preview.reparent(bg)
 preview.position=Vector2(550,490)
 preview.scale=Vector2(1.2,1.2)
 var patty:=Patty.new();game.add_child(patty)
 st.patties=[patty]
 for crown in [false,true]:
  st.items=["bun_bottom","patty","cheese","lettuce","bacon"] as Array[String]
  if crown: st.items.append("bun_top")
  game._refresh_station(game.STATION_CRAFT)
  for row in st.layer_pool:
   if row.visible: print(row.get_meta("item_id")," ",row.position," ",row.size)
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/stack_%s.png"%str(crown))
 assert(is_equal_approx(game.STATION_PATTY_BUILD_SCALE,0.744*1.1))
 assert(game.BUN_PILE_TOWER_COUNT==2)
 print("BURGER_STACK_LAYOUT_OK")
 quit()
