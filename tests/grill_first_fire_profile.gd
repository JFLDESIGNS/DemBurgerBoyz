extends SceneTree
var g
var monitors: Dictionary={}
func _initialize(): call_deferred("run")
func counters()->Dictionary:
 var result:Dictionary={}
 for key in monitors: result[key]=Performance.get_monitor(monitors[key])
 return result
func phase(label:String,action:Callable):
 var before:=counters()
 var start:=Time.get_ticks_usec()
 action.call()
 var call_ms:float=(Time.get_ticks_usec()-start)/1000.0
 var last:=start
 var frames:Array=[]
 for i in 100:
  g._update_grill_fire(1.0/60.0)
  await process_frame
  var now:=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
 frames.sort()
 print("FIRE_PROFILE ",JSON.stringify({"label":label,"call_ms":call_ms,"p95_ms":frames[95],"max_ms":frames.back(),"pipelines_before":before,"pipelines_after":counters()}))
func run():
 create_timer(60).timeout.connect(func():quit(1))
 for key in ClassDB.class_get_integer_constant_list("Performance"):
  if "PIPELINE" in key:monitors[key]=ClassDB.class_get_integer_constant("Performance",key)
 g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
 g.grill.resize(g.GRILL_SLOTS);g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
 var at:Vector3=Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z)
 g.camera.look_at_from_position(at+Vector3(0,1.2,1.7),at)
 g.get_node("UI").hide()
 var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-50,20,0);g.world.add_child(lamp)
 g._ensure_oil_effect_pool()
 for i in 24:g._spawn_oil_slick_local(at+Vector3(float(i%6)*.035-.09,0,float(i/6)*.035-.05),.02)
 await g._prewarm_grill_fire_fx()
 for i in 60:await process_frame
 await phase("idle",func():pass)
 g.grill_on=true
 await phase("first_ignition",func():g._start_grill_fire_local(at))
 g._clear_grill_fire()
 for i in 45:await process_frame
 await phase("second_ignition",func():g._start_grill_fire_local(at))
 print("GRILL_FIRST_FIRE_PROFILE_OK")
 quit()
