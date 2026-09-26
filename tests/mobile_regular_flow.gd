extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(180).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 await g._start_game()
 g.spawn_timer=99999
 var m=g._grubbah
 await process_frame;await process_frame
 assert(not m.knife.visible)
 var cash=g.money
 g._buy_shop_item_local("chef_knife")
 assert(g.money==cash-50)
 await process_frame;await process_frame
 assert(m.knife.visible)
 m.request("knife");assert(m.holding_knife())
 g._update_hand_spatula_cursor(.016);assert(not g.hand_spatula_root.visible)
 m.update_visuals(.016);assert(is_equal_approx(m.knife.rotation.y,PI*.5+.30))
 m.request("knife");assert(not m.holding_knife())
 var regular=load("res://scripts/mobile_ticket_owner.gd").new();regular.order.assign(["bun_bottom","patty","bun_top"]);regular.is_waiting=true;regular.patience=100;regular.patience_max=100;g.add_child(regular);g._create_ticket(regular);g._select_ticket_local(regular)
 m.new_order();assert(m.state.phase=="accepted");assert(g.selected_customer==regular);assert(g.tickets.keys().find(m.ticket_owner)>g.tickets.keys().find(regular))
 m.request("cancel");assert(m.state.is_empty());assert(g.selected_customer==regular)
 m.state={"number":1,"items":["bun_bottom","patty","bun_top"],"phase":"accepted","base":15,"quality":1.0,"selected":true};m.age=0;m.refresh()
 assert(m.is_selected());assert(g.tickets.has(m.ticket_owner))
 assert(str(g.tickets[m.ticket_owner].get_meta("title_label").text).begins_with("M"))
 await process_frame
 await process_frame
 assert(m.state.phase=="paper")
 assert(not regular.queue_timer_active)
 assert(not regular._order_clock_on)
 m.car.show()
 assert(is_equal_approx(m.car_ground_y+g._shop_preview_bounds(m.car).position.y*m.car.scale.y,-.06))
 m.car.hide()
 assert(is_equal_approx(m.ledge.position.x,.1144))
 g.grill_on=true;g._spawn_patty_in_slot(0)
 var patty=g.grill[0];assert(is_instance_valid(patty));g.grill[0]=null;patty.is_held=true;patty.visible=false
 g.stations[0].patties=[patty];g.stations[0].items=["bun_bottom","patty"];g._refresh_station(0)
 assert(m.burger_ready())
 g._try_auto_serve();assert(g.stations[0].items.has("bun_top"));assert(m.state.phase=="paper")
 g._set_phone_app("grubbah");g._set_phone_expanded(true)
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/mobile_regular_ticket.png")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=g.camera.unproject_position(m.paper3d.global_position)
 assert(m.handle_input(click));assert(m.state.phase=="wrapping")
 await process_frame;await process_frame
 assert(g.stations[0].preview.modulate.a==0.0)
 await create_timer(1.5).timeout
 assert(m.state.phase=="bagging");assert(m.bag.visible);assert(g.stations[0].patties.is_empty())
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/mobile_visible_bag.png")
 m.request("seal");assert(m.state.phase=="sealed")
 await create_timer(1.0).timeout
 assert(m.bag_ticket.visible);assert(is_instance_valid(m.ticket_view))
 var at=Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z)
 g._spawn_condiment_spline_segment(at-Vector3(.13,0,0),at+Vector3(.13,0,0),.008,"ketchup")
 assert(g._scrape_local_sauce(at,Vector2(.04,0),.07))
 for item in g.soda_slicks:
  if item.get("smeared",false):
   assert(item.mesh.position.y-g._grill_steel_top_y()<=.0031)
   assert(item.mesh.mesh.get_aabb().size.z>.045)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/mobile_packed_ticket_smear.png")
 print("MOBILE_REGULAR_FLOW_OK")
 quit()
