extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(200).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 await g._start_game()
 g.spawn_timer=99999
 await process_frame;await process_frame
 g.supply_stock["patty"]=0
 g._prepare_fridge_balls_for_launch()
 g._refresh_ingredient_stock_bars()
 for ball in g.patty_fridge_balls_root.get_children():assert(not ball.visible)
 for id in g.ingredient_buttons:
  g.supply_stock[id]=0
 g._refresh_ingredient_stock_bars()
 await process_frame
 for id in g.ingredient_buttons:
  var icon=g.ingredient_buttons[id].get_node_or_null("Stack/IconMargin/StripIcon")
  if icon:assert(not icon.visible)
 assert(not g._empty_stock_controls.markers.is_empty())
 g.supply_stock["patty"]=12;g.supply_stock["bun_bottom"]=12;g.supply_stock["bun_top"]=12
 g._clear_station(0)
 assert(g.stations[0].items.is_empty())
 g._add_ingredient_to_station_local(0,"bun_bottom")
 assert(g.stations[0].items==["bun_bottom","bun_top"])
 assert(g.supply_stock.bun_bottom==11 and g.supply_stock.bun_top==11)
 g._add_ingredient_to_station_local(0,"bun_bottom")
 assert(g.supply_stock.bun_bottom==11)
 await create_timer(.6).timeout
 g.grill_on=true;g._spawn_patty_in_slot(0);g._spawn_patty_in_slot(1)
 var p=g.grill[0];var other=g.grill[1]
 p.cook_time=p.FLIP_READY+.1
 g._begin_patty_drag(p)
 assert(p.flipped_once);assert(g.dragging_patty!=p)
 var old=Vector2(p.position.x,p.position.z)
 var target=Vector2(other.position.x,other.position.z)
 var moved=g._move_grill_patty_slide(p,target,old,true,1)
 assert(not g._patty_blocked_at(moved.target,p.slot_index))
 assert(Vector2(p.position.x,p.position.z).distance_to(Vector2(other.position.x,other.position.z))>=g.PATTY_FIT_RADIUS*2.0)
 assert(other.has_meta("slide_hop_ms"))
 g._clear_station(0)
 var before_base=int(g.supply_stock.bun_bottom)
 var before_top=int(g.supply_stock.bun_top)
 g.grill[0]=null
 g._commit_patty_to_build(p)
 assert(g.stations[0].items==["bun_bottom","patty","bun_top"])
 assert(g.supply_stock.bun_bottom==before_base-1 and g.supply_stock.bun_top==before_top-1)
 g._commit_patty_to_build(p)
 assert(g.supply_stock.bun_bottom==before_base-1)
 var order=load("res://scripts/mobile_ticket_owner.gd").new()
 order.order.assign(["bun_bottom","patty","bun_top"]);order.is_waiting=true
 g.add_child(order);g._create_ticket(order);g.selected_customer=order
 assert(g._station_burger_complete(0))
 g._refresh_station(0)
 await create_timer(.35).timeout
 assert(g.stations[0].crown_ready)
 assert(g.stations[0].layer_hint.text=="CLICK TO SERVE")
 order.order.append("tomato")
 g._try_auto_serve()
 assert(not g.stations[0].crown_ready)
 var crown=g._find_station_top_bun_row(0)
 var floating_y=crown.position.y
 g._begin_whole_burger_drag(0)
 assert(g.stations[0].carried_closed)
 assert(crown.position.y>floating_y+20)
 assert(not g._station_burger_complete(0))
 var move=InputEventMouseMotion.new();move.position=g.get_viewport().get_mouse_position()+Vector2(40,0);move.relative=Vector2(40,0)
 assert(g._handle_whole_burger_drag(move))
 var swayed=false
 for layer in g._whole_burger_drag.layers:
  if layer.row.position.distance_to(layer.home)>1:swayed=true
  assert(layer.row.get_theme_stylebox("panel") is StyleBoxEmpty)
 assert(swayed)
 g._finish_whole_burger_drag()
 await create_timer(.6).timeout
 assert(not g.stations[0].carried_closed)
 var hit_found=false
 for layer in g.stations[0].layer_pool:
  if not layer.visible:continue
  var tr=layer.get_node("LayerTexture")
  for fraction in [.4,.5,.6,.7]:
   var point=tr.get_global_transform_with_canvas()*(tr.size*Vector2(.5,fraction))
   if g._build_layer_at_screen(point)!=null:
    assert(not g._try_bun_pile_click(point));hit_found=true
 assert(hit_found)
 g._remove_ticket(order);g.selected_customer=null;order.queue_free()
 var fries=g._ready_fries_slot_world(0)
 assert(absf(fries.x-g.soda_station_pos.x)<.5)
 assert(fries.z<g.soda_station_pos.z-.4)
 g._set_phone_expanded(true)
 for app in ["home","shop","grubbah","bank","orders","social"]:
  g._set_phone_app(app)
  await create_timer(.5).timeout
  var scroll=g.phone_scroll
  var content=scroll.get_child(0)
  print("PHONE_WIDTH ",app," ",scroll.size.x," / ",content.size.x)
  for control in content.find_children("*","Control",true,false):
   if control.is_visible_in_tree() and control.get_combined_minimum_size().x>210:
    print("WIDE ",control.get_path()," ",control.get_combined_minimum_size())
 g._set_phone_app("shop")
 await create_timer(.3).timeout
 assert(g.phone_scroll.size.x <= 211)
 print("KITCHEN_INTERACTION_REGRESSION_OK")
 quit()
