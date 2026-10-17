extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/hotdog_challenge_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.day_time=g._shift_length()-300;g.stations=[{"items":[],"patties":[]}]
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside);g._start_background_person(0)
 var actor=g.bg_people[0]
 var preset=actor.get_custom_character_preset()
 assert(preset.top_style==16 and preset.hat_style==7 and preset.bottom_style==2)
 g._reveal_grisaldi(actor)
 assert(actor._anim_player.current_animation=="burger/Burger_Celebration")
 await create_timer(4.6).timeout
 assert(actor.get_meta("street_hail")=="join_exit")
 g._update_background_hail(0,20)
 g._update_background_hail(0,.1)
 assert(g.customers.size()==1)
 assert(g.customers[0].get_custom_character_preset().top_style==16)
 assert(g.customers[0].get_customer_voice()=="male")
 for fan in g.customers.slice(1):assert(fan.get_meta("grisaldi_referral",false))
 var customer=g.customers[0]
 assert(g.money==0,"Clicking Grisaldi must not give money before a burger")
 var balance: float=g.money
 g._grisaldi_reward(customer,5.0)
 assert(g.money==balance,"No review bonus before serving a burger")
 customer.set_meta("grisaldi_meal_review_ready",true)
 g._grisaldi_reward(customer,3.99)
 assert(g.money==balance and g._grisaldi_bonus_pending==0)
 g._grisaldi_reward(customer,4.0)
 assert(g.money==balance and g.customers.size()==1,"Fans must wait for the published review")
 g._commit_social_review(4.0,"good",0,-1,customer)
 assert(g.money==balance+500 and g.customers.size()==6)
 for fan in g.customers.slice(1):assert(fan.get_meta("grisaldi_referral",false))
 g._grisaldi_reward(customer,5.0)
 assert(g.money==balance+500 and g.customers.size()==6,"Only one referral wave")
 assert(not g._grisaldi_arrival_due(),"Never spawn a second active Grisaldi")
 assert(g.social_reviews[0].who=="Grisaldi" and "viewers" in g.social_reviews[0].text)
 await g._grisaldi_take_photos(customer)
 await create_timer(.4).timeout
 assert(g.shift_tips==500)
 g._commit_social_review(4.0,"good",0,-1,g.customers.back())
 assert("Grisaldi" in g.social_reviews[0].text)
 print("GRISALDI_RECRUIT_OK: five followers only after a positive published review, one active Grisaldi, one $500 tip")
 g.queue_free();await process_frame
 quit()
