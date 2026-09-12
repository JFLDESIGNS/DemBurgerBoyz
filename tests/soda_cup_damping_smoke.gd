extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var game_script := load("res://scripts/game.gd")
	var game := Node3D.new()
	game.set_script(game_script)
	var machine := Node3D.new()
	root.add_child(machine)
	var near := bool(game.call("_cup_near_machine_face", Vector3(0.0, 0.20, 0.12), machine, 0.58, 1.30, 0.055))
	var far_side := bool(game.call("_cup_near_machine_face", Vector3(1.20, 0.20, 0.12), machine, 0.58, 1.30, 0.055))
	var far_front := bool(game.call("_cup_near_machine_face", Vector3(0.0, 0.20, 1.20), machine, 0.58, 1.30, 0.055))
	if not near or far_side or far_front:
		_fail("Cup machine damping zone bounds are incorrect")
		return
	var constants: Dictionary = game_script.get_script_constant_map()
	if float(constants.get("CUP_MACHINE_FOLLOW_RATE", 999.0)) >= float(constants.get("CUP_FOLLOW_RATE", 0.0)):
		_fail("Machine-zone cup follow is not damped")
		return
	if float(constants.get("CUP_MACHINE_FOLLOW_MAX_SPEED", 999.0)) >= float(constants.get("CUP_FOLLOW_MAX_SPEED", 0.0)):
		_fail("Machine-zone cup speed is not capped")
		return
	if float(constants.get("CUP_SPLASH_SPEED", 0.0)) < 3.0 or float(constants.get("CUP_SPLASH_LEAN", 0.0)) < 38.0:
		_fail("Cup spill tolerance regressed")
		return
	machine.queue_free()
	game.free()
	print("SODA_CUP_DAMPING_SMOKE_OK")
	quit(0)
