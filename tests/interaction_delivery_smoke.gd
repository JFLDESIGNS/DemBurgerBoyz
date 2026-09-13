extends SceneTree
class Patty extends Area3D:
 var slot_index := 0
 var is_slide_drag := true
 var net_id := -1
 var is_held := false
var failures: Array[String] = []
func expect(ok: bool, msg: String) -> void:
 if not ok:
  failures.append(msg)
  push_error(msg)
func _initialize(): call_deferred("run")
func run() -> void:
 create_timer(45).timeout.connect(func(): push_error("INTERACTION_DELIVERY_TIMEOUT");quit(1))
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("interaction_delivery_fixture.gd")))
 root.add_child(game)
 current_scene=game
 game.set_process_input(false)
 game.playing=true
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem: child.hide()
 var button:=Button.new()
 button.position=Vector2(50,50)
 button.size=Vector2(150,100)
 game.add_child(button)
 game.ingredient_buttons["lettuce"]=button
 game.supply_stock["lettuce"]=8
 game.pointer=Vector2(100,80)
 var press:=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT
 press.pressed=true
 game._handle_strip_swipe_input(press)
 expect(game._strip_hold_armed and game.added.is_empty(),"Press must arm a grab without adding food")
 var release:=press.duplicate() as InputEventMouseButton
 release.pressed=false
 game._handle_strip_swipe_input(release)
 expect(game.added==["lettuce"],"A short tap must still add the ingredient once")
 game.added.clear()
 game._handle_strip_swipe_input(press)
 game._try_start_strip_hold_pickup()
 expect(root.gui_is_dragging() and game._pending_ingredient_drag=="lettuce","Hold must start a real ingredient drag")
 expect(game.added.is_empty() and game.supply_stock.lettuce==8,"Picking up must not add or charge stock yet")
 game.over_trash=true
 Input.parse_input_event(release)
 await process_frame
 game._on_gui_drag_ended(false)
 expect(game.supply_stock.lettuce==7 and game._pending_ingredient_drag=="","Dropping ingredient in trash consumes exactly one")
 var patty:=Patty.new()
 game.world.add_child(patty)
 game.grill=[patty]
 game.dragging_patty=patty
 game.drag_did_move=true
 game.drag_press_sec=Time.get_ticks_msec()*.001-1.0
 game._end_patty_drag()
 expect(game.dragging_patty==null and game.grill[0]==null,"Patty drag into trash must clear drag and grill ownership")
 await create_timer(.4).timeout
 expect(not is_instance_valid(patty),"Patty must animate into the bin and be removed")
 var held:=Patty.new()
 game.world.add_child(held)
 game.spatula_patty=held
 game.spatula_lmb_held=true
 game._handle_spatula_release(Vector2.ZERO)
 expect(game.spatula_patty==null and not game.spatula_lmb_held,"Carried patty must drop into trash")
 await create_timer(.4).timeout
 expect(not is_instance_valid(held),"Carried patty was not disposed")
 var bin:=Node3D.new()
 game.world.add_child(bin)
 bin.position=Vector3(2,1,-1)
 game.ingredient_bin_nodes["lettuce"]=bin
 game._begin_cat_supply_delivery("lettuce",8,"stock")
 expect(game.supply_delivery_fx.size()==3,"Delivery should create representative packs")
 var item: Dictionary=game.supply_delivery_fx[0]
 var mesh: MeshInstance3D=item.mesh
 expect((mesh.mesh as QuadMesh).size.is_equal_approx(Vector2(.82,.66)/3.0),"Delivery ingredients should be one-third size")
 expect(mesh.material_override.no_depth_test and mesh.material_override.render_priority==100,"Packs must render over the grill")
 game._update_supply_delivery_fx(1.5)
 expect(game.credits.is_empty(),"Stock must wait until the delivery reaches storage")
 var landing: Vector3=mesh.global_position
 game._update_supply_delivery_fx(.26)
 expect(mesh.global_position.distance_to(bin.global_position)<landing.distance_to(bin.global_position),"Package must lerp toward the correct ingredient bin")
 game._update_supply_delivery_fx(.4)
 expect(game.credits==[["lettuce",8,"stock"]] and game.supply_delivery_fx.is_empty(),"Delivery must credit once and clean up all packs")
 print("INTERACTION_DELIVERY_OK" if failures.is_empty() else "INTERACTION_DELIVERY_FAILED")
 game.queue_free()
 for i in 5: await process_frame
 quit(0 if failures.is_empty() else 1)
