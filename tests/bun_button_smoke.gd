extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/bun_button_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var preview=Control.new();g.get_node("UI/Root").add_child(preview)
 var row=Control.new();preview.add_child(row);row.set_meta("station_index",0);row.set_meta("stack_i",0);row.set_meta("item_id","bun_bottom");g.test_row=row
 var items=["bun_bottom","patty","bun_top"]
 g.stations=[{"items":items.duplicate(),"patties":[],"preview":preview,"layer_pool":[row]}]
 assert(g._try_build_burger_click(Vector2(50,50),MOUSE_BUTTON_LEFT))
 assert(not g._build_swipe.is_empty() and g._whole_burger_drag.is_empty())
 g._build_swipe.clear()
 assert(g._try_build_burger_click(Vector2(50,50),MOUSE_BUTTON_RIGHT))
 assert(g._build_swipe.is_empty() and not g._whole_burger_drag.is_empty())
 var top=Control.new();preview.add_child(top);top.position=Vector2(0,-40)
 g._whole_burger_drag.layers.append({"row":top,"home":top.position,"rotation":0.0})
 var origin:Vector2=g._whole_burger_drag.mouse
 var rest:Vector2=g._whole_burger_drag.rest
 var move=InputEventMouseMotion.new();move.position=origin+Vector2(700,350);move.relative=Vector2(25,-20)
 assert(g._handle_whole_burger_drag(move))
 assert(preview.position.distance_to(rest)>650,"Burger can travel beyond the old 260px limit")
 for i in 8:g._update_whole_burger_wobble(1.0/60.0)
 assert(absf(top.position.x)>1.0 and top.position.y < -42,"Sideways wobble and vertical layer separation must be visible")
 for i in 240:g._update_whole_burger_wobble(1.0/60.0)
 assert(top.position.distance_to(Vector2(0,-40))<.1,"Ingredients settle together when movement stops")
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 assert(not g._handle_whole_burger_drag(release),"Left release must not end a right grab")
 release.button_index=MOUSE_BUTTON_RIGHT;assert(g._handle_whole_burger_drag(release))
 assert(g._whole_burger_drag.is_empty() and g.stations[0].items==items,"Shaking never removes food")
 print("BUN_BUTTONS_OK: left drag, right shake, matching release, ingredients retained")
 quit()
