extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var stage:=Control.new();stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(stage)
 var backdrop:=ColorRect.new();backdrop.color=Color("385961");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stage.add_child(backdrop)
 var holder:=Control.new();holder.position=Vector2(360,70);holder.size=Vector2(740,570);stage.add_child(holder)
 var truck=load("res://scripts/truck_cinematic.gd").new();holder.add_child(truck)
 var fade:=ColorRect.new();fade.color=Color(0,0,0,0);fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.z_index=4096;stage.add_child(fade)
 truck.departure_darkness.connect(func(a):fade.color.a=a)
 await process_frame
 truck.play_departure();truck.set_process(false)
 for u in [0.0,.25,.38,.55,.75,.90,1.0]:
  truck.sample_departure(u)
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/truck_departure_%03d.png" % int(u*100))
 truck.departure_finished.emit()
 assert(fade.color.a==1.0);print("TRUCK_DEPARTURE_PREVIEW_OK");quit()
