extends SceneTree
class TravelGame extends Node:
 var world: Node3D
 var camera: Camera3D
 var street_matte: Node3D
 var street_matte_body: Node3D
 var park_bird_house: Node3D
func _initialize(): call_deferred("run")
func run():
 create_timer(15).timeout.connect(func():quit(1))
 var g=TravelGame.new();root.add_child(g)
 var ui=Node.new();ui.name="UI";g.add_child(ui)
 var control=Control.new();control.name="Root";ui.add_child(control)
 g.world=Node3D.new();g.add_child(g.world)
 g.camera=Camera3D.new();g.world.add_child(g.camera)
 g.street_matte=Node3D.new();g.world.add_child(g.street_matte)
 var travel=load("res://scripts/truck_relocation.gd").new();g.add_child(travel);travel.setup(g)
 travel.sample_departure(.6)
 assert(travel.shutter.scale.y<1.0 and g.street_matte.position.x<0.0,"Background must move before the shutter finishes closing")
 await travel.close_and_depart()
 assert(is_equal_approx(travel.shutter.scale.y,1.0))
 assert(g.street_matte.position.is_equal_approx(Vector3.ZERO))
 await travel.open_at_destination()
 assert(travel.shutter.scale.y<.002)
 travel.queue_free();await process_frame
 assert(not is_instance_valid(travel))
 print("TRUCK_RELOCATION_OK: movement before close, covered destination swap, reopening")
 g.queue_free();await process_frame;await process_frame;quit()
