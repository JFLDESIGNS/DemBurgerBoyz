extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 create_timer(100).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load(get_script().resource_path.get_base_dir().path_join("mobile_packing_fixture.gd")));root.add_child(game);current_scene=game;game.playing=true
 for i in game.STATION_COUNT:game.stations.append({"items":[],"patties":[]})
 game.get_node("UI").hide()
 var light=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=.8
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("38453f");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;game.add_child(environment)
 var phone=VBoxContainer.new();game.get_node("UI/Root").add_child(phone)
 var mobile=load("res://scripts/grubbah.gd").new();game.add_child(mobile);mobile.set_process(false);game._grubbah=mobile;mobile.setup(game,phone)
 mobile.state={"number":3,"items":["bun_bottom","patty","bun_top","fries","soda_cola"],"phase":"accepted","base":20}
 mobile.refresh();mobile.auto_lay_paper();assert(mobile.state.phase=="paper","Selecting the mobile ticket lays paper automatically")
 var owner=mobile.ticket_owner
 # An uncrowned toasted burger must pass the same virtual-crown check as raw buns.
 game.stations[0].items=["bun_bottom","patty"]
 game.stations[0].patties=[Node3D.new()]
 game.stations[0].bun_toast={"bun_bottom":10.0,"bun_top":10.0}
 mobile.state.items=["bun_bottom","patty","bun_top","toasted_bun","fries","soda_cola"]
 assert(mobile.burger_ready(),"Correct toasted mobile burger can wrap before the crown closes")
 game.stations[0].bun_toast.bun_bottom=18.0
 assert(mobile.burger_ready(),"Incorrect toasted buns may now be sent intentionally")
 game.stations[0].patties[0].free();game.stations[0].patties=[];game.stations[0].items=[];game.stations[0].bun_toast={}
 mobile.state.items=["bun_bottom","patty","bun_top","fries","soda_cola"]
 game._remove_ticket(owner);mobile.state.phase="accepted";game.selected_customer=null;mobile.auto_lay_paper()
 assert(game.tickets.has(owner) and mobile.state.phase=="paper","Missing ticket/selection repairs without sticking")
 mobile.build_props();mobile.driver_style=3;mobile.state["driver_skin"]=0;mobile.age=.6;mobile.update_visuals(0);assert(mobile.paper3d.visible and mobile.bag.visible)
 var drink=game._create_drink_cup_node();game.world.add_child(drink);drink.position=Vector3(-1,1.2,0);game.cup_root=drink;game.cup_flavor="cola";game.cup_soda_fill=.9;game.cup_held=true
 mobile.pack_ready_sides();assert(not mobile.state.has("side_packs"),"Partial drinks must finish before packing")
 game.cup_soda_fill=1;game.fryer_ready_servings=1
 game.selected_customer=null
 mobile.pack_ready_sides()
 assert(mobile.state.side_packs.has("fries") and not mobile.state.side_packs.has("soda_cola"),"Fries pack without selecting the mobile ticket")
 game.selected_customer=owner
 game._try_auto_hand_finished_soda()
 assert(game.cup_root==null and game.fryer_ready_servings==0)
 assert(mobile.state.side_packs.size()==2 and mobile.state.phase=="paper")
 assert(not game._serve_fly_busy and not owner.get_meta("side_food_active",false),"Mobile tickets never eat/drink")
 mobile.update_visuals(0);assert(mobile.side_visuals.size()==2)
 var first:Vector3=mobile.side_visuals.values()[0].node.global_position
 mobile.advance_side_packs(.3);mobile.update_visuals(.3)
 assert(mobile.side_visuals.values()[0].node.global_position.distance_to(first)>.05,"Sides move toward the bag")
 if DisplayServer.get_name()!="headless":
  game.camera.position=Vector3(.2,2.2,3);game.camera.look_at(Vector3(.2,1.3,.55))
  await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/mobile_side_flights.png"))
 mobile.pack_ready_sides();assert(mobile.state.side_packs.size()==2 and game.fryer_ready_servings==0,"Packing reserves inventory once")
 mobile.set_phase("bagging");mobile.age=1.1;assert(not mobile.try_seal_bag(),"Wait for sides to land")
 mobile.advance_side_packs(1);assert(mobile.try_seal_bag() and mobile.state.phase=="sealed")
 assert(not owner.is_waiting and game.selected_customer!=owner,"Sealed mobile bags release the active order")
 # A parked completed cup wins over a partially filled working cup, and removing
 # a remote cup must not clear the host's working drink.
 var working=Node3D.new();game.add_child(working);game.cup_root=working;game.cup_flavor="cola";game.cup_soda_fill=.85
 var parked=Node3D.new();game.add_child(parked);parked.set_meta("flavor","cola");parked.set_meta("soda_fill",1.0);game.parked_cups.append(parked)
 assert(mobile.completed_drink("soda_cola")==parked)
 var remote=Node3D.new();game.add_child(remote);remote.set_meta("flavor","cola");remote.set_meta("soda_fill",1.0)
 game._take_drink_for_mobile_pack(remote);assert(game.cup_root==working and game.cup_soda_fill==.85 and game.parked_cups.has(parked))
 game.cup_root=null;working.queue_free()
 # The lever must spring back even when no cup exists, and a click dispenses.
 game.owned_machines[game.SHOP_SODA_MACHINE]=true
 var station=Node3D.new();game.world.add_child(station);game.soda_root=station
 var stick=Node3D.new();stick.name="Stick";station.add_child(stick)
 var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.04,.12,.03);mesh.mesh=box;stick.add_child(mesh)
 var tip=Marker3D.new();station.add_child(tip);tip.position=Vector3(0,.1,0);game.soda_spout_markers={"cola":tip};game.soda_spout_marker=tip
 game._setup_soda_dispense_clips(station);stick.rotation_degrees.x=32
 for i in 60:game._update_soda_trigger(1.0/60.0)
 assert(absf(stick.rotation_degrees.x)<.01,"No-cup idle always resets lever")
 game.camera.position=Vector3(0,.2,1);game.camera.look_at(Vector3.ZERO)
 assert(game._try_soda_trigger_click(game.camera.unproject_position(Vector3.ZERO)))
 game.soda_stream_mesh=MeshInstance3D.new();game.soda_stream_mesh.mesh=CylinderMesh.new();game.world.add_child(game.soda_stream_mesh)
 game.soda_tank_fill["cola"]=1.0
 game._update_soda_trigger(.1);assert(game.soda_stream_mesh.visible,"Click sprays without a cup")
 for i in 90:game._update_soda_trigger(1.0/60.0)
 assert(not game.soda_stream_mesh.visible and absf(stick.rotation_degrees.x)<.01,"Manual shot stops and releases lever")
 if DisplayServer.get_name()!="headless":
  mobile.props.hide();station.hide();parked.hide()
  var rack_station=Node3D.new();game.world.add_child(rack_station);game.soda_root=rack_station
  game.soda_cup_rack_pos=Vector3.ZERO;game.soda_cup_rack_rot=Vector3.ZERO;game.soda_cup_rack_scale=1.0
  game._build_soda_cup_rack(rack_station)
  var arrow=load("res://scripts/soda_order_arrow.gd").new();arrow.game=game;rack_station.add_child(arrow);arrow.set_process(false);arrow.position=Vector3(0,.32,0)
  game.camera.position=Vector3(.3,.27,.7);game.camera.look_at(Vector3(0,.16,0))
  await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/cup_stack_polish.png"))
 # A real customer reserves the same packing station for a multi-burger takeout.
 mobile.state={};mobile.sync_ticket()
 var person=load("res://scripts/customer.gd").new()
 var recipe: Array[String]=["bun_bottom","patty","bun_top"]
 person.setup(recipe,Color.WHITE,90,0);game.add_child(person);person.set_process(false)
 person.is_waiting=true;game.customers.append(person)
 mobile.begin_takeout(person,3)
 assert(mobile.ticket_owner==person and mobile.state.burger_count==3)
 var expected_price=preload("res://scripts/game_data.gd").order_value(mobile.state.takeout_sides)
 for item in mobile.state.recipes:expected_price+=preload("res://scripts/game_data.gd").order_value(item)
 assert(mobile.state.base==expected_price)
 mobile.state.burgers_packed=1;mobile.set_phase("bagging");mobile.age=2
 assert(not mobile.try_seal_bag() and mobile.state.phase=="paper","One burger cannot seal a three-burger order")
 assert(Array(person.order)==Array(mobile.state.recipes[1]+mobile.state.takeout_sides),"Ticket advances to the next burger recipe")
 mobile.state["side_packs"]={}
 for side in mobile.required_sides():mobile.state.side_packs[side]={"elapsed":2.0,"kind":"fries" if side=="fries" else "drink","flavor":"cola","source":Vector3.ZERO}
 mobile.state.burgers_packed=3;mobile.set_phase("bagging");mobile.age=2
 assert(mobile.try_seal_bag() and mobile.state.phase=="sealed")
 mobile.update_visuals(0)
 assert(not mobile.car.visible and not mobile.courier.visible,"Walk-up orders must never summon a driver")
 var before_money=game.money
 mobile.pay_order();var after_money=game.money;mobile.pay_order()
 assert(after_money>before_money and game.money==after_money,"Takeout pays once")
 for burger_count in [1,4]:
  mobile.state={};mobile.begin_takeout(person,burger_count)
  assert(mobile.state.recipes.size()==burger_count and mobile.state.burger_count==burger_count)
 # The mail cat must have a full walking clearance before the customer passes it.
 var mail=Node3D.new();game.add_child(mail)
 var cat=Node3D.new();mail.add_child(cat)
 # Use the actual mail truck script's courier field without its setup.
 mail.set_script(load("res://scripts/mail_delivery_truck.gd"));mail.courier=cat;mail.set_process(false)
 game.mail_delivery_truck=mail
 cat.position=Vector3(0,0,person._wait_z())
 person.position=Vector3(-3,person.STAND_Y,person._wait_z())
 for frame in 180:
  person.position.x+=1.6/60.0
  person.position.z=person._wait_z() # Departure pose resets depth each frame.
  person._avoid_visiting_cat(1.0/60.0)
  if absf(person.position.x)<.5:assert(person.position.z-cat.position.z>1.1,"Customer must clear the cat")
 # Reaching the counter X must not strand a waiting challenge guest behind the cat.
 person.position=Vector3(0,person.STAND_Y,person._wait_z()+1.45)
 person.target_x=0;person.is_waiting=true;person.is_challenge_guest=true;person._cat_detour_depth=1.45
 person._process(1.0/60.0)
 assert(person._cat_detour_depth>1.4,"Hold clearance while cat occupies the counter")
 cat.hide()
 person._process(1.0/60.0)
 assert(person._cat_detour_depth<1.45 and person._cat_detour_depth>0,"Start returning smoothly as soon as cat leaves")
 for frame in 30:person._process(1.0/60.0)
 assert(person._cat_detour_depth>1.0 and person._anim_state=="walk","Return uses a slower uninterrupted walking pose")
 for frame in 150:person._process(1.0/60.0)
 assert(is_zero_approx(person._cat_detour_depth) and is_equal_approx(person.position.z,person._wait_z()),"Waiting challenge guest returns to the counter")
 print("TAKEOUT_AND_CAT_OK")
 game.queue_free();await process_frame;quit()
