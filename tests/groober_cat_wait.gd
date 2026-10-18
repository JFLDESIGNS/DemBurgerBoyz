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
 for endpoints in [Vector2(-9,10),Vector2(10,24)]:
  for t in [.1,.3,.5,.75,.95]:
   driver._pose_driver_car(t-.0001,endpoints.x,endpoints.y)
   var before=driver.car.position
   driver._pose_driver_car(t+.0001,endpoints.x,endpoints.y)
   var after=driver.car.position
   driver._pose_driver_car(t,endpoints.x,endpoints.y)
   var forward=driver.car.basis.x;forward.y=0;forward=forward.normalized()
   assert(forward.dot((after-before).normalized())>.999,"Car nose must follow its actual driving direction")
  for t in [0.0,1.0]:
   driver._pose_driver_car(t,endpoints.x,endpoints.y)
   assert(absf(driver.car.rotation.y)<.001 and absf(driver.car.rotation.x)<.001,"Car parks straight")
 driver._pose_driver_car(.3,-9,10)
 assert(absf(driver.car.rotation.y)>.1,"Visible steering through the swerve")
 driver._pose_driver_car(.1,-9,10)
 var first_distance=driver.car.position.x+9
 driver._pose_driver_car(.9,-9,10)
 assert(10-driver.car.position.x<first_distance*.2,"Approach slows before stopping")
 print("GROOBER_CAT_WAIT_OK")
 quit()
