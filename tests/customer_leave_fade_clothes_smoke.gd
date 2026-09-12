extends SceneTree

const Customer := preload("res://scripts/customer.gd")

var failures: Array[String] = []


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var customer := Customer.new()
	var preset := {
		"format_version": 8,
		"name": "Leave Fade Clothes",
		"body_type": "kenney_chunky_toon",
		"skin_color": "cf895fff",
		"top_catalog_version": 1,
		"top_style": 1,
		"top_color": "7259d9ff",
		"bottom_catalog_version": 1,
		"bottom_style": 2,
		"bottom_color": "39465cff",
		"shoe_catalog_version": 1,
		"shoe_style": 1,
		"shoe_color": "eeeeeeff",
	}
	customer.setup(["bun_bottom", "patty", "bun_top"], Color.WHITE, 45.0, 0, 0, 0, -1, preset, true)
	root.add_child(customer)
	await process_frame
	var top := customer.find_child("FittedTop", true, false) as MeshInstance3D
	_expect(top != null, "Custom customer is missing fitted clothes")
	if top == null:
		_finish(customer)
		return
	var before := top.get_surface_override_material(0) as ShaderMaterial
	_expect(before != null, "Fitted clothes should use a ShaderMaterial")
	if before == null:
		_finish(customer)
		return
	var fabric_color: Variant = before.get_shader_parameter("fabric_color")
	var fabric_tint: Variant = before.get_shader_parameter("fabric_tint")
	customer.call("_apply_leave_fade_alpha", 1.0)
	var after_leave := top.get_surface_override_material(0)
	_expect(after_leave is ShaderMaterial, "Walking away replaced clothes with a StandardMaterial3D")
	_expect(not (after_leave is StandardMaterial3D), "Walking away turned clothes into a white StandardMaterial3D")
	if after_leave is ShaderMaterial:
		var leave_mat := after_leave as ShaderMaterial
		_expect(leave_mat.get_shader_parameter("fabric_color") == fabric_color, "Leave start lost authored fabric color")
		_expect(leave_mat.get_shader_parameter("fabric_tint") == fabric_tint, "Leave start lost clothing tint")
	customer.call("_apply_leave_fade_alpha", 0.4)
	var after_fade := top.get_surface_override_material(0)
	_expect(after_fade is ShaderMaterial, "Leave fade replaced clothes with a StandardMaterial3D")
	if after_fade is StandardMaterial3D:
		var white := after_fade as StandardMaterial3D
		_expect(white.albedo_color.r < 0.99 or white.albedo_color.g < 0.99 or white.albedo_color.b < 0.99, "Leave fade used a white albedo fallback")
	if after_fade is ShaderMaterial:
		var fade_mat := after_fade as ShaderMaterial
		_expect(fade_mat.get_shader_parameter("fabric_color") == fabric_color, "Leave fade lost authored fabric color")
		_expect(fade_mat.get_shader_parameter("fabric_tint") == fabric_tint, "Leave fade lost clothing tint")
		_expect(is_equal_approx(float(fade_mat.get_shader_parameter("fade_alpha")), 0.4), "Leave fade did not keep clothing opacity")
		_expect(fade_mat.shader != null and fade_mat.shader.code.contains("ALPHA = fade_alpha"), "Leave fade did not add shader opacity")
	_finish(customer)


func _finish(customer: Customer) -> void:
	customer.queue_free()
	if failures.is_empty():
		print("CUSTOMER_LEAVE_FADE_CLOTHES_SMOKE_OK")
		quit(0)
	else:
		quit(1)
