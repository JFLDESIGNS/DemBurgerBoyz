extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/challenge_auto_fixture.gd"));root.add_child(g);current_scene=g
 seed(12345)
 var batches=0
 var giants=0
 var ten_patty_stacks=0
 for i in 200:
  g._pick_challenge_size()
  assert(g._challenge_count==g._challenge_recipes.size())
  if g._challenge_count==1:
   giants+=1
   var recipe=g._challenge_recipes[0]
   assert(recipe.count("patty") in [5,10] and recipe.has("cheese"))
   assert(recipe.size()<=14,"Giant stack fits the build limit")
   if recipe.count("patty")==10:ten_patty_stacks+=1
   assert(g._challenge_time_max==recipe.count("patty")*10.0)
   assert(str(recipe.count("patty")) in g._challenge_intro_text())
  else:
   batches+=1
   assert(g._challenge_count>=5 and g._challenge_count<=10)
   var doubles=0
   for recipe in g._challenge_recipes:
    assert(recipe.count("patty") in [1,2])
    if recipe.count("patty")==2:doubles+=1
   assert(doubles in [1,2],"Large batches have only one or two doubles")
   assert(g._challenge_time_max==g._challenge_count*10.0)
 assert(batches>0 and giants>0 and ten_patty_stacks>0)
 g._build_challenge_ui()
 g._show_challenge_offer()
 assert(g._challenge_phase=="offer" and g.spawned==0 and g.challenge_overlay.visible)
 await create_timer(2.8).timeout
 assert(g._challenge_phase=="offer" and g.spawned==0,"Ticket stays for three seconds")
 await create_timer(.3).timeout
 assert(g._challenge_phase=="active" and g.spawned==1,"Challenge starts without an accept prompt")
 var c=load("res://scripts/customer.gd").new()
 var first:Array[String]=["bun_bottom","patty","bun_top"]
 c.setup(first,Color.WHITE,99999,0);g.add_child(c);c.set_process(false);c.is_waiting=true;c.is_challenge_guest=true
 g._challenge_customer=c;g.customers.append(c)
 g._challenge_recipes=[first,["bun_bottom","patty","patty","cheese","bun_top"]]
 g._challenge_count=2;g._challenge_remaining=1
 g._apply_next_challenge_recipe()
 assert(c.order.count("patty")==2 and c.order.has("cheese"),"Next burger gets its own recipe")
 assert(g.tickets.has(c),"Updated recipe has a visible ticket")
 print("CHALLENGE_BATCH_AND_GIANT_STACK_OK")
 quit()
