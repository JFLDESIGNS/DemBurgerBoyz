extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g
 var outside=Node3D.new();g.add_child(outside);g.playing=true
 g._build_background_people(outside)
 g._start_background_person(0)
 assert(g.bg_people_active[0] and g.bg_people[0].get_meta("grisaldi",false))
 var walker=g.bg_people[0]
 var tops=walker.find_children("FittedTop","MeshInstance3D",true,false)
 assert(tops.size()>0 and tops[0].material_override is ShaderMaterial)
 assert(g._ingredient_extra_targets().has(walker))
 g.mp_ingredient_extra_hit(0)
 assert(walker.get_meta("food_stop_until")>Time.get_ticks_msec())
 var before=walker.position
 g._update_background_people(.1)
 assert(walker.position.is_equal_approx(before))
 assert(int(g.get_meta("grisaldi_day"))==g.day)
 print("OUTDOOR_FOOD_GRISALDI_OK outfit, once-per-day mark, target inclusion, stopped hit reaction")
 quit()
