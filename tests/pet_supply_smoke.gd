extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(25).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/potato_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var milk=load("res://scripts/milk_refill.gd").new();milk.name="MilkRefill";milk.game=g;g.add_child(milk);milk.set_process(false)
 g.owned_machines[g.SHOP_ICECREAM_MACHINE]=true;g.supply_stock.milk=1
 var cone=Node3D.new();g.add_child(cone)
 assert(not milk.reserve_cone(cone))
 milk.request("refill");assert(g.supply_stock.milk==0 and g.icecream_mix_servings==6)
 for refill in 4:
  if refill > 0: milk.request("refill")
  for n in 6:
   var c=Node3D.new();g.add_child(c);assert(milk.reserve_cone(c));assert(milk.reserve_cone(c))
 assert(g.supply_stock.milk==0 and g.milk_carton_refills==0,"One carton supplies exactly four refills")
 assert(g.icecream_mix_servings==0 and not milk.reserve_cone(cone))
 g.supply_stock.milk=2;g.supply_fresh.milk=.1;g._update_supply_freshness(1000);assert(g.supply_stock.milk==2)
 var cat=load("res://scripts/window_cat.gd").new();g.add_child(cat);cat.set_process(false);cat.pet(true)
 assert(cat._purr_left==4 and cat._purr_player.playing)
 cat._bob=.1;cat._apply_visual_scale();assert(absf(cat._visual.rotation.z)>0 and absf(cat._visual.rotation.z)<.015)
 cat._purr_left=0;cat._apply_visual_scale();assert(is_zero_approx(cat._visual.rotation.z))
 cat.start_purr();cat.pause_for_delivery();assert(not cat._purr_player.playing and cat._purr_left==0)
 var audio=load("res://scripts/game_audio.gd").new();g.add_child(audio)
 audio.play_customer_hit_wa(cat);var voice=cat.get_node("HitWa");assert(voice.stream.get_length()<.34 and voice.playing)
 var sling=g._ensure_ingredient_slingshot();g.game_audio=audio
 sling.remote_pull(8,"tomato",Vector2(.4,.7),Vector2(.4,.8),true)
 assert(sling.remote_pulls[8].sound.playing)
 sling.remote_pull(8,"",Vector2.ZERO,Vector2.ZERO,false);assert(sling.remote_pulls.is_empty())
 var slip=load("res://scripts/returned_order.gd").new();g.get_node("UI/Root").add_child(slip);slip.present({"ordered":["cheese"],"missing":["cheese"]})
 await create_timer(5.2).timeout;assert(not is_instance_valid(slip))
 print("PET_SUPPLY_OK: finite milk, frozen stock, purr/sway, single wa, shared stretch cleanup, five-second notice")
 g.queue_free();await process_frame;quit()
