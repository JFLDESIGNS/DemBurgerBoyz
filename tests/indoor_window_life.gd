extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:=Node3D.new();root.add_child(world)
 var street=load("res://scenes/mill_market_layers.tscn").instantiate();world.add_child(street)
 var life=street._indoor_life
 life.events=[{"key":"Records_Upper_Left","age":0.0,"duration":6.0,"cat":true,"move":false,"direction":1.0},{"key":"Market_Upper_Wide","age":2.0,"duration":6.0,"cat":false,"move":true,"direction":1.0}]
 life.render_events()
 assert(not life.windows.Records_Upper_Left.mesh.visible)
 life.events[0].age=2.0;life.render_events()
 assert(life.windows.Records_Upper_Left.mesh.visible)
 var material=life.windows.Records_Upper_Left.material
 var near_scale=float(material.get_shader_parameter("depth_scale"))
 life.events[0].age=5.0;life.render_events()
 assert(float(material.get_shader_parameter("depth_scale"))<near_scale*.85)
 assert(absf(float(material.get_shader_parameter("drift")))>.15,"Even stationary visitors walk away")
 assert(float(material.get_shader_parameter("opacity"))>.25,"Departure starts moving before fading out")
 life.events[0].age=2.0;life.render_events()
 life.cue_door("motel",1.0)
 assert(life.windows.Motel_Door.mesh.visible)
 var snapshot: Dictionary=street.traffic_snapshot()
 life.events=[];street.apply_traffic_snapshot(snapshot)
 assert(life.events.size()==2)
 life.events.append({"key":"Motel_Door","age":2.0,"duration":6.0,"cat":false,"move":false,"direction":1.0})
 life.render_events()
 assert(life.windows.Motel_Door.mesh.visible)
 assert(life.windows.Motel_Door.mesh.get_parent()==street._hinges.motel,"Silhouette must follow the moving door")
 assert(street._door_reflections.size()==2)
 assert(street._door_reflections[1].get_shader_parameter("reflection_only"))
 var camera:=Camera3D.new();world.add_child(camera)
 camera.position=Vector3(0,-1.1,18);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13.3;camera.current=true
 await process_frame;await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/indoor_silhouettes.png")
 life.tick(8.0,false,true)
 assert(life.events.is_empty())
 life.reset()
 for entry in life.windows.values():assert(not entry.mesh.visible)
 print("INDOOR_WINDOW_LIFE_OK: fades, masked people/cats, doorway cue, replication, expiry")
 world.queue_free();await process_frame;quit()
