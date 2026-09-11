extends SceneTree

const CustomerScript = preload("res://scripts/customer.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run_test() -> void:
	var customer_world := Node3D.new()
	root.add_child(customer_world)
	var customer := CustomerScript.new()
	customer_world.add_child(customer)
	await process_frame
	var head_anchor := customer.call("_stuck_food_anchor_local", true) as Vector3
	customer.receive_stuck_food("lettuce", null, Vector3.ZERO, "face")
	customer.receive_stuck_food("pickle", null, Vector3.ZERO, "face")
	var reserved_local := customer.reserve_stuck_food_local_target()
	var reserved_world := customer.to_global(reserved_local)
	customer.receive_stuck_food("tomato", null, reserved_world, "face")
	await process_frame
	var holder := customer.get_node_or_null("StuckFood") as Node3D
	if holder == null or holder.get_child_count() != 3:
		_fail("Expected three attached ingredient cards")
		return
	var first := holder.get_child(0) as MeshInstance3D
	var second := holder.get_child(1) as MeshInstance3D
	var reserved := holder.get_child(2) as MeshInstance3D
	if first == null or second == null:
		_fail("Attached ingredient cards are missing")
		return
	var first_quad := first.mesh as QuadMesh
	var second_quad := second.mesh as QuadMesh
	if first_quad == null or not is_equal_approx(first_quad.size.x, 0.34) \
			or second_quad == null or not is_equal_approx(second_quad.size.x, 0.26):
		_fail("Ingredient cards are still oversized")
		return
	var first_mat := first.material_override as StandardMaterial3D
	var second_mat := second.material_override as StandardMaterial3D
	if first_mat == null or not first_mat.no_depth_test or second_mat == null or not second_mat.no_depth_test:
		_fail("Ingredient cards can still be hidden behind the customer mesh")
		return
	if first.position.distance_to(second.position) < 0.08:
		_fail("Ingredient cards did not scatter across distinct head spots")
		return
	if first.position.y < head_anchor.y + 0.24 or second.position.y < head_anchor.y + 0.24:
		_fail("First ingredient landing spots are not biased toward the top of the head")
		return
	if first.position.z < head_anchor.z + 0.095 or second.position.z < head_anchor.z + 0.095:
		_fail("Ingredient cards are not far enough in front of the head")
		return
	if reserved == null or reserved.position.distance_to(reserved_local) > 0.0001:
		_fail("Attached ingredient did not reuse its reserved flight destination: %s vs %s" % [
			reserved.position if reserved != null else Vector3.INF,
			reserved_local,
		])
		return
	var held_y := first.position.y
	await create_timer(1.75).timeout
	if not is_instance_valid(first) or absf(first.position.y - held_y) > 0.002:
		_fail("Ingredient did not remain fixed for its two-second hold")
		return
	await create_timer(0.75).timeout
	if not is_instance_valid(first) or first.get_parent() != holder or first.position.y >= held_y - 0.025:
		_fail("Ingredient did not slide down the face after holding")
		return
	await create_timer(0.85).timeout
	if not is_instance_valid(first) or first.get_parent() == holder:
		_fail("Ingredient did not detach and begin falling after the one-second slide")
		return
	await create_timer(0.80).timeout
	if is_instance_valid(first):
		_fail("Fallen ingredient was not cleaned up")
		return
	print("CUSTOMER STUCK FOOD test passed: small scattered head hits hold, slide, fall, and clean up")
	customer_world.queue_free()
	await process_frame
	quit(0)
