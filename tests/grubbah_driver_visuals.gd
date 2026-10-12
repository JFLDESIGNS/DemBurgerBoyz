extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(20).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.setup(g,phone);m.set_process(false);m.build_props()
 assert(m.car.has_node("GrubbahRoofSign"))
 for model in m.DRIVER_CARS:
  m.car.queue_free();m.car=model.instantiate();m.props.add_child(m.car);m.car.scale=Vector3.ONE*g.STREET_CAR_MODEL_SCALE
  m._add_driver_roof_sign();assert(m.car.has_node("GrubbahRoofSign"))
  m._pose_driver_car(.4,-9.0,10.0)
  assert(m.car.position.z>g.STREET_CAR_Z and absf(m.car.rotation.y)>.001)
  m._pose_driver_car(1.0,-9.0,10.0)
  assert(absf(m.car.rotation.y)<.001)
 print("GRUBBAH_DRIVER_VISUALS_OK: roof sign on three cars, swerve and farther road position")
 g.queue_free();await process_frame;await process_frame;quit()
