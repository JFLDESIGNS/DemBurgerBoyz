extends SceneTree
class Patty extends Node:
 func doneness_multiplier():return 1.0
func _initialize():call_deferred("run")
func run():
 create_timer(35).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.stations=[{"items":[],"patties":[],"fresh_active":false}]
 var ui=g.get_node("UI/Root");var phone=VBoxContainer.new();ui.add_child(phone);phone.position=Vector2(1400,100);phone.size=Vector2(300,500)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.setup(g,phone);m.set_process(false)
 m.build_props();m.state={"number":1,"items":["bun_bottom","patty","bun_top"],"phase":"offered","base":15,"quality":1.0};m.age=0
 m.apply_command("action",1,1);assert(m.state.phase=="accepted")
 m.apply_command("paper",1,1);assert(m.state.phase=="paper")
 m.apply_command("wrap",1,1);assert(m.state.phase=="paper")
 var patty=Patty.new();root.add_child(patty);g.stations[0].patties=[patty];g.stations[0].items=m.state.items.duplicate();g.stations[0].items.erase("bun_top")
 m.apply_command("wrap",1,1);assert(m.state.phase=="wrapping");assert(g.stations[0].items.has("bun_top"))
 m.update_visuals(0);assert(not m.paper3d.visible and m.wrapped.visible,"Loose paper must disappear as soon as the wrapped burger appears")
 m.consume_build();m.set_phase("bagging");m.apply_command("seal",1,1);assert(m.state.phase=="sealed")
 var before=g.money;m.pay_order();m.pay_order();assert(g.money==before+19)
 m.state.phase="paper";m.age=1;m.show_app("grubbah");m.update_visuals(0)
 await create_timer(2).timeout
 if not DisplayServer.get_name()=="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/grubbah_preview.png")
 print("GRUBBAH_FLOW_OK")
 quit()
