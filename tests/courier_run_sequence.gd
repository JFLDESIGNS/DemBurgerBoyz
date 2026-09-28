extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(90).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.stations=[{"items":[],"patties":[],"fresh_active":false}]
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.setup(g,phone);m.set_process(false);m.build_props()
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
