extends SceneTree
func _initialize():call_deferred("run")
func run():
 var packed=load("res://scenes/character_creator/modular_character_base.tscn")
 assert(packed!=null,"Export must include the modern character scene")
 var model=packed.instantiate()
 assert(model.has_method("apply_saved_preset"),"Modern character script must compile inside the EXE")
 model.free()
 var customer_script=load("res://scripts/customer.gd")
 var preset=customer_script.take_next_saved_character_preset()
 assert(not preset.is_empty(),"Character presets must be available")
 for walker_mode in [false,true]:
  var customer=customer_script.new()
  customer.is_street_pedestrian=walker_mode
  customer.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,100,0,0,-1,-1,preset,true)
  root.add_child(customer)
  await process_frame
  assert(customer._uses_custom_character,"Customers and walkers must use modern characters")
  if walker_mode:assert(customer.restyle_street_character(preset,true),"Walker restyling must succeed")
  customer.queue_free();await process_frame
 print("EXPORTED_MODERN_CUSTOMERS_AND_WALKERS_OK");quit()
