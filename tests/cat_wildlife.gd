extends SceneTree
class CatCustomer extends Node:
 var is_disguise_cat:=true
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var cat=load("res://scripts/window_cat.gd").new();g.add_child(cat);cat.set_process(false);g.window_cat=cat
 cat._first_visit_wait=0;cat._fat=.8;cat._giant=.3;cat._state="hidden";cat._timer=20;cat._background_wait=0
 assert(cat._update_wildlife(.1,g));assert(cat._state=="background_walk" and cat.visible)
 cat._apply_visual_scale();var size_before:Vector3=cat._visual.scale
 assert(cat.get_mp_sync().fat==.8 and cat.get_mp_sync().giant==.3)
 var disguise=CatCustomer.new();g.customers.append(disguise)
 cat._update_wildlife(.1,g);assert(cat._state=="hidden" and not cat.visible)
 g.customers.clear();disguise.free()
 g.park_bird_house=load("res://scenes/park_bird.tscn").instantiate();g.add_child(g.park_bird_house);g.park_bird_house.set_process(false);g.park_bird_house._enter(&"Idle")
 cat._state="peek";cat._bird_wait=0;cat._bird_checked=false
 cat._update_wildlife(4.0,g);assert(not cat._bird_checked)
 cat._update_wildlife(.6,g);assert(cat._bird_checked)
 assert(cat.has_meta("social_look"))
 print("CAT_WILDLIFE_OK: one cat role, preserved size, feeding delay before bird encounter")
 quit()
