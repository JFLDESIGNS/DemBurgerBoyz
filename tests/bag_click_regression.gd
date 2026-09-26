extends SceneTree
class TestBag extends "res://scripts/grubbah.gd":
 var requested := ""
 func request(kind: String) -> void:requested=kind
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);g.playing=true;g.get_node("UI").hide()
 var m=TestBag.new();g.add_child(m);m.set_process(false);m.game=g;m.props=Node3D.new();g.add_child(m.props)
 m.bag=Node3D.new();m.props.add_child(m.bag);m.bag.position=Vector3(0,1,0)
 g.camera.position=Vector3(0,1.5,-2);g.camera.look_at(Vector3(0,1.2,0));g.camera.current=true
 m.state={"phase":"bagging"}
 for y in [.04,.2,.38]:
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=g.camera.unproject_position(m.bag.to_global(Vector3(0,y,0)))
  assert(m._bag_finish_hit(click.position));assert(m.handle_input(click));assert(m.requested=="seal")
 m.state.phase="sealed";assert(not m._bag_finish_hit(g.camera.unproject_position(m.bag.global_position)))
 print("BAG_CLICK_REGRESSION_OK");quit()
