extends SceneTree
class PattyProbe extends Node3D:
 func doneness_multiplier():return 1.0
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/mobile_packing_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 for i in g.STATION_COUNT:g.stations.append({"items":[],"patties":[]})
 var p=PattyProbe.new();g.add_child(p)
 g.stations[0]={"items":["bun_bottom","patty","bun_top"],"patties":[p]}
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.set_process(false);g._grubbah=m;m.setup(g,phone)
 m.state={"number":1,"phase":"paper","items":["bun_bottom","patty","cheese","bun_top","fries"],"base":20}
 m.refresh()
 assert(m.burger_ready(),"Wrong recipe can still be wrapped")
 m.apply_command("wrap",1,1)
 assert(m.state.phase=="wrapping" and not m.state.recipe_perfect and m.state.quality<1.0,"Wrong burger wraps with reduced quality")
 m.set_phase("bagging");m.age=m.BURGER_BAG_FLIGHT
 assert(not m.try_seal_bag(),"Automatic sealing still waits for ordered sides")
 assert(m.try_seal_bag(1) and m.state.phase=="sealed","Explicit send may omit sides")
 assert(not m.try_seal_bag(1),"Cannot send twice")
 m.state={"number":2,"phase":"paper","items":["bun_bottom","patty","bun_top"],"base":10}
 g.stations[0].patties=[];assert(not m.burger_ready(),"Empty build must not ship")
 print("MOBILE_WRONG_ORDER_OK: mismatched burger, reduced quality, manual missing sides, automatic wait, duplicate protection")
 quit()
