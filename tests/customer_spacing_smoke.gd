extends SceneTree
const Customer = preload("res://scripts/customer.gd")
class MovingCustomer extends "res://scripts/customer.gd":
	func _ready() -> void: pass
	func _advance_customer(_delta: float) -> void: position.x += .025
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(60).timeout.connect(func():quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game);current_scene=game
	game.set_process_input(false)
	for i in 3:
		game._spawn_customer_local(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,i,-1,0,0,false,-1,false,{},true)
		var customer = game.customers.back()
		customer.set_process(false)
		customer.global_position.x=customer.target_x
	for i in range(1,3):
		assert(is_equal_approx(game.customers[i-1].target_x-game.customers[i].target_x,1.10),"Queue has slightly wider spacing")
	game._reposition_customers()
	assert(is_equal_approx(game.customers[2].target_x,Customer.lane_x_for(2)))
	var walker = MovingCustomer.new()
	game.customers_root.add_child(walker);walker.set_process(false)
	walker.global_position = game.customers[0].global_position-Vector3(.7,0,0)
	var depth: float = walker.global_position.z
	for frame in 20:
		walker._process(.016)
		assert(is_equal_approx(walker.global_position.z,depth),"Customer depth stays on the authored path even beside another customer")
	walker.free()
	assert(Customer.lane_x_for(5)<Customer.lane_x_for(4),"Overflow queue slots remain distinct")
	print("CUSTOMER_SPACING_OK")
	game.queue_free()
	await process_frame
	quit()
