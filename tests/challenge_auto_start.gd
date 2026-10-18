extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/challenge_auto_fixture.gd"));root.add_child(g);current_scene=g
 for i in 100:
  g._pick_challenge_size()
  assert(g._challenge_count>=5 and g._challenge_count<=10)
  for recipe in g._challenge_recipes:assert(recipe.count("patty") in [1,2],"Only single or double burgers")
  assert(g._challenge_count==g._challenge_recipes.size())
  assert(g._challenge_time_max==g._challenge_count*10.0)
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
 print("CHALLENGE_AUTO_START_SINGLE_DOUBLE_OK")
 quit()
