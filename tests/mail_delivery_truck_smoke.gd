extends SceneTree
class FakeGame extends Node3D:
	var window_cat: Node3D
	var street_car_active := false
	var supply_delivery_fx: Array = []
	var deliveries: Array = []
	func _street_car_wheel_y() -> float: return -0.077312
	func _street_car_z() -> float: return 7.18
	func _throw_cat_supply_delivery(id: String, pack: int, kind: String) -> void: deliveries.append([id, pack, kind])
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(35).timeout.connect(func(): quit(1))
	assert(load("res://scripts/game.gd") != null)
	var game := FakeGame.new();root.add_child(game);current_scene=game
	game.window_cat=Node3D.new();game.add_child(game.window_cat)
	game.window_cat.set_process(true)
	var actor=load("res://scripts/mail_delivery_truck.gd").new();actor.game=game;game.add_child(actor)
	actor.enqueue("lettuce",8,"stock")
	game.street_car_active=true;actor.advance(3.0)
	assert(actor.phase=="waiting" and not actor.truck.visible,"Traffic must clear before truck arrival")
	game.street_car_active=false
	var phases: Array=[]
	var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(6,3,-4);camera.look_at(Vector3(0,1,6));camera.current=true
	var light:=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-40,-35,0);light.light_energy=1.8
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("6d8092");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;game.add_child(env)
	for i in 1500:
		actor.advance(1.0/60)
		if actor.phase not in phases:
			phases.append(actor.phase)
			if actor.phase=="hop_out" and DisplayServer.get_name()!="headless":
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://output/mail_truck_game_preview.png")
		if actor.finished: break
	assert(actor.finished,"Delivery must complete and release traffic")
	assert(game.deliveries==[["lettuce",8,"stock"]],"Order should be delivered exactly once")
	assert(actor.wheels.size()==4,"Four separate wheels must remain available")
	assert(game.window_cat.is_processing() and game.window_cat.visible,"Original cat restored")
	for phase in ["arrive","hop_out","walk","deliver","return","hop_in","depart"]: assert(phase in phases,phase)
	print("MAIL_DELIVERY_TRUCK_OK ",phases)
	quit()
