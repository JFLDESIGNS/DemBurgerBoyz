extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=load("res://scripts/customer.gd").new()
 c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color("E8AC6F"),100,0,2)
 root.add_child(c);c.set_process(false);c.set_physics_process(false)
 c.is_waiting=true
 c.apply_host_snapshot(Vector3(0,c.STAND_Y,2.25),180,true)
 c.leave_happy(false)
 var progressed=false
 for i in 500:
  if not is_instance_valid(c):break
  c._process(.1)
  if c.global_position.x>2.0:progressed=true
  await process_frame
 assert(progressed,"Guest must move beyond its last host snapshot")
 assert(not is_instance_valid(c),"Departed guest must finish offscreen cleanup")
 var m=load("res://scripts/grubbah.gd").new()
 m.state={"number":4,"phase":"pickup","driver_skin":3,"car_style":2,"photo":PackedByteArray([1,2,3])}
 var payload=m.snapshot_payload()
 assert(not payload.has("photo"));assert(payload.driver_skin==3 and payload.car_style==2);assert(m.state.has("photo"))
 m.free()
 print("GUEST_DEPARTURE_REGRESSION_OK")
 quit()
