extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/swipe_rules_fixture.gd"));root.add_child(g)
 g.playing=true;g._setup_stations_data();g.stations[0].items=["bun_bottom","patty","tomato","bun_top"]
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=Vector2(70,0)
 g._build_swipe={"station":0,"layer":2,"id":"tomato","origin":Vector2.ZERO,"distance":70.0,"items":g.stations[0].items.duplicate()}
 assert(g._handle_build_swipe(release));assert(g.removed=="tomato");assert(g.served==0)
 g.removed=""
 g._build_swipe={"station":0,"layer":1,"id":"patty","origin":Vector2.ZERO,"distance":70.0,"items":g.stations[0].items.duplicate()}
 assert(g._handle_build_swipe(release));assert(g.returned==1);assert(g.removed=="");assert(g.served==0)
 g.room=false;g.returned=-1;g._apply_build_swipe(0,1,"patty");assert(g.returned==-1);assert(g.removed=="")
 print("SWIPE_RULES_OK");quit()
