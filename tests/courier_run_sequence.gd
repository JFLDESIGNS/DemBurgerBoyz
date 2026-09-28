extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(90).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.stations=[{"items":[],"patties":[],"fresh_active":false}]
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.setup(g,phone);m.set_process(false);m.build_props()
 var mouth=Vector3(1,2,3);var start=Vector3(-1,1,0)
 assert(m.burger_bag_position(0,start,mouth).is_equal_approx(start))
 for t in [.65,.75,.85,.95,1.0]:
  var pos=m.burger_bag_position(t,start,mouth)
  assert(is_equal_approx(pos.x,mouth.x) and is_equal_approx(pos.z,mouth.z),"Burger drops vertically through bag opening")
 assert(m.burger_bag_position(.65,start,mouth).y>mouth.y)
 assert(m.pickup_bag_position(1,start,mouth).is_equal_approx(mouth))
 g._build_condiment_bottles()
 for bottle in g.condiment_bottle_roots.values():assert(bottle.has_node("SauceSmiley"))
 m.state={"number":1,"items":["bun_bottom","patty","bun_top"],"phase":"bagging","base":15,"quality":1.0}
 m.age=.70;m.update_visuals(0)
 assert(m.wrapped.visible and not m.bag_finish.visible)
 m.apply_command("seal",1,1);assert(m.state.phase=="bagging","Cannot seal before burger enters")
 m.age=.90;m.update_visuals(0);assert(absf(m.bag.rotation.z)>.001 and m.bag_impact_played)
 m.age=1.1;m.update_visuals(0);assert(not m.wrapped.visible and m.bag_finish.visible)
 m.state={"number":1,"items":["bun_bottom","patty","bun_top"],"phase":"pickup","base":15,"quality":1.0}
 m.age=m.DRIVER_APPROACH+.3;m.update_visuals(0)
 assert(m.courier.get_meta("courier_running"))
 m.age=m.DRIVER_APPROACH+(m.DRIVER_WALK-.18)*.85;m.update_visuals(0)
 assert(not m.courier.get_meta("courier_running") and m.courier.get_meta("footstep_sliding"))
 assert(not m.courier._anim_player.is_playing())
 var slide_start=m.courier.position.x
 m.age=m.DRIVER_APPROACH+m.DRIVER_WALK;m.update_visuals(0)
 assert(m.courier.position.x<slide_start)
 m.state.phase="collected";m.age=.1;m.update_visuals(0)
 assert(not m.courier.get_meta("courier_running"))
 m.age=m.DRIVER_TURN+.2;m.update_visuals(0)
 assert(m.courier.get_meta("courier_running") and m.courier._anim_player.is_playing())
 m.age=m.DRIVER_TURN+m.DRIVER_RETURN+.1;m.update_visuals(0)
 assert(not m.courier.visible and not m.bag.visible)
 print("COURIER_RUN_SKID_TURN_RETURN_OK");quit()
