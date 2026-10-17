extends SceneTree
class Game extends Node3D:
 var mp_enabled=false
 var window_cat: Node3D
 var mail_delivery_truck: Node3D
 var STREET_CAR_Z=6.0
func _initialize():call_deferred("run")
func run():
 var g=Game.new();root.add_child(g)
 var driver=load("res://tests/groober_cat_wait_fixture.gd").new();g.add_child(driver);driver.set_process(false);driver.game=g
 driver.props=Node3D.new();g.add_child(driver.props)
 driver.ledge=MeshInstance3D.new();driver.props.add_child(driver.ledge)
 g.window_cat=Node3D.new();g.add_child(g.window_cat);g.window_cat.position=Vector3(0,1,2.45)
 driver.state={"phase":"pickup"}
 var stop=driver.DRIVER_APPROACH+driver.DRIVER_RUN+driver.DRIVER_SLIDE+driver.DRIVER_FACE
 driver.age=stop+.01;driver._update_pickup_block()
 assert(driver.state.cat_blocked and is_equal_approx(driver.age,stop))
 for i in 10:
  driver.age+=.016;driver._update_pickup_block()
  assert(is_equal_approx(driver.age,stop),"Cat must hold the pickup timeline")
 g.window_cat.position.x=4;driver.age+=.016;driver._update_pickup_block()
 assert(not driver.state.cat_blocked and driver.age>stop)
 assert(driver.publications==2,"Only publish block/unblock transitions")
 driver.car=Node3D.new();g.add_child(driver.car)
 driver._pose_driver_car(.3,-9,10)
 assert(absf(driver.car.position.z-(g.STREET_CAR_Z+.45))>.1)
 print("GROOBER_CAT_WAIT_OK")
 quit()
