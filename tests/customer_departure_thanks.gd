extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 for id in [3,4]:
  var c=load("res://scripts/customer.gd").new()
  var order:Array[String]=["bun_bottom","patty","bun_top"]
  c.setup(order,Color.WHITE,90,0);g.add_child(c);c.set_process(false);c.set_meta("mp_net_id",id)
  c.is_leaving=true;c._departure_review_shown=true;c._leave_phase="review";c._leave_spin=3.19
  c._update_sidewalk_leave(.02)
  if id==3:
   assert(c._leave_phase=="thanks" and c.speech=="Thank you!")
   assert(c.get_node_or_null("MouthSpeech")!=null,"Thank you has mouth animation")
   c._update_sidewalk_leave(1.3)
   assert(c._leave_phase=="turn_left2","Customer continues leaving after thanks")
  else:assert(c._leave_phase=="turn_left2","Thanks is occasional")
  assert(not c._say_departure_thanks(),"Never repeat the thank you")
 print("CUSTOMER_DEPARTURE_THANKS_OK")
 quit()
