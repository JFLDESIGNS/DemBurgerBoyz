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
 assert(tops.size()>0 and tops[0].mesh.get_surface_count()==2)
 assert(g._ingredient_extra_targets().has(walker))
 g.mp_ingredient_extra_hit(0)
 assert(walker.get_meta("food_stop_until")>Time.get_ticks_msec())
 var before=walker.position
 g._update_background_people(.1)
 assert(walker.position.is_equal_approx(before))
 assert(g._grisaldi_visits.has("%s:%d" % [g.current_location_id,g.day]))
 for location in load("res://scripts/truck_locations.gd").LOCATIONS:
  g.current_location_id=location["id"]
  g._grisaldi_visits.erase("%s:%d" % [g.current_location_id,g.day])
  for i in g.bg_people.size():
   g.bg_people_active[i]=false;g.bg_people[i].visible=false;g.bg_people_wait[i]=999.0
  g._update_background_people(1.1)
  assert(g._grisaldi_visits.has("%s:%d" % [g.current_location_id,g.day]), "Missing early visit at " + g.current_location_id)
  assert(g.bg_people[0].get_meta("grisaldi",false))
  for i in g.bg_people.size():
   g.bg_people_active[i]=false;g.bg_people[i].visible=false
  g._start_background_person(0)
  assert(not g.bg_people[0].get_meta("grisaldi",false), "Repeated visit at " + g.current_location_id)
 g.day+=1
 for i in g.bg_people.size():
  g.bg_people_active[i]=false;g.bg_people[i].visible=false
 g._start_background_person(0)
 assert(g.bg_people[0].get_meta("grisaldi",false))
 print("OUTDOOR_FOOD_GRISALDI_OK outfit, hit reaction, all six locations within 1.1 seconds, no repeat, next day visit")
 quit()
