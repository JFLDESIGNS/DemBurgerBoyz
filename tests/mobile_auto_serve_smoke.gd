extends SceneTree
class Mobile extends "res://scripts/grubbah.gd":
	var authoritative = true
	func host() -> bool: return authoritative
	func publish() -> void: pass
	func update_visuals(_delta: float) -> void: pass
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate(); g.set_script(load("res://tests/mobile_auto_serve_fixture.gd"))
	root.add_child(g); current_scene = g; g.playing = true
	var m = Mobile.new(); g.add_child(m); m.game = g; m.set_process(false)
	m.props = Node3D.new(); m.add_child(m.props); m.was_playing = true
	m.state = {"phase":"bagging", "number":1, "items":["bun_bottom","patty","bun_top"]}
	m.age = 0
	m._process(m.BURGER_BAG_FLIGHT - .01)
	assert(m.state.phase == "bagging", "Wait until burger lands in bag")
	m._process(.02)
	assert(m.state.phase == "sealed", "Burger-only order serves without input")
	assert(not m.try_seal_bag(), "Duplicate finish cannot serve twice")
	m._process(m.BAG_PICKUP_FLIGHT + .01)
	assert(m.state.phase == "pickup")
	m.state = {"phase":"bagging", "number":2, "items":["bun_bottom","patty","bun_top","fries","soda_cola"]}
	m.age = m.BURGER_BAG_FLIGHT
	g.fryer_ready_servings = 0
	m._process(.01); assert(m.state.phase == "bagging")
	var drink = Node3D.new(); g.add_child(drink); g.ready_drink = drink
	m._process(.01)
	assert(m.state.phase == "bagging" and g.drinks_consumed == 0, "Do not consume drink while fries missing")
	g.fryer_ready_servings = 1
	m._process(.01)
	assert(m.state.phase == "sealed" and g.fryer_ready_servings == 0 and g.drinks_consumed == 1)
	assert(not m.try_seal_bag() and g.drinks_consumed == 1)
	m.state.phase = "bagging"; m.state.items = ["bun_bottom","patty","bun_top"]
	m.age = m.BURGER_BAG_FLIGHT; m.authoritative = false
	m._process(.1); assert(m.state.phase == "bagging")
	assert(not m.try_seal_bag(), "Guests must wait for the host's seal snapshot")
	g.queue_free(); await process_frame
	print("MOBILE_AUTO_SERVE_OK: bag landing, automatic dispatch, required sides, single consumption, host authority")
	quit()
