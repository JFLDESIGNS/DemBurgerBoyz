extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true
 g.owned_machines[g.SHOP_ICECREAM_MACHINE]=true
 g.icecream_spout_marker=Marker3D.new();g.world.add_child(g.icecream_spout_marker);g.icecream_spout_marker.position=Vector3(2,2,2)
 g.icecream_cone_root=Node3D.new();g.world.add_child(g.icecream_cone_root)
 assert(g._dispense_cone_to_fill_station())
 assert(g._dispense_cone_to_fill_station())
 await create_timer(.4).timeout
 assert(g._icecream_parked_filling)
 assert(g._cone_at_fill_seat())
 var loading=load("res://scripts/kitchen_loading_progress.gd").new();loading.game=g;root.add_child(loading)
 loading._process(0);var before=loading.bar.value
 loading.last_tick_ms=Time.get_ticks_msec()-1100;loading._process(0)
 assert(loading.bar.value>before+.9)
 assert(is_equal_approx(loading.bar.anchor_right-loading.bar.anchor_left,1.0/3.0))
 load("res://scripts/soda_order_arrow.gd").new().free()
 g._build_grill_roomba()
 assert(g.grill_roomba_body_mat.albedo_color.r>.1)
 assert(g.grill_roomba_root.get_node_or_null("ToonTopReflection")!=null)
 print("QUICK_SERVICE_OK")
 quit()
