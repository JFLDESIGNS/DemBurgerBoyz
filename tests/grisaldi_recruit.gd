extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/hotdog_challenge_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.day_time=300;g.stations=[{"items":[],"patties":[]}]
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside);g._start_background_person(0)
 var actor=g.bg_people[0]
 var preset=actor.get_custom_character_preset()
 assert(preset.top_style==16 and preset.hat_style==4 and preset.bottom_style==2)
 g._reveal_grisaldi(actor)
 assert(actor._anim_player.current_animation=="burger/Grisaldi_Cartwheel")
 await create_timer(4.5).timeout
 assert(actor.get_meta("street_hail")=="join_exit")
 g._update_background_hail(0,20)
 g._update_background_hail(0,.1)
 assert(g.customers.size()==1)
 assert(g.customers[0].get_custom_character_preset().top_style==16)
 assert(g.customers[0].get_customer_voice()=="male")
 print("GRISALDI_RECRUIT_OK: cartwheel, dance, signature outfit, male voice, customer queue")
 quit()
