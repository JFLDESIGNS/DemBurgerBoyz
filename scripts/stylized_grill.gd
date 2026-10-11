extends Node3D
## Visual replacement; cooking, networking, and heat remain owned by game.gd.

var knob: Node3D
var indicator: MeshInstance3D
var off_rotation := Quaternion.IDENTITY
var power_tween: Tween
var lamp_material: StandardMaterial3D
var temperature_digits: Label3D


func configure() -> void:
	_raise_splash_guard()
	_apply_matte_steel(self)
	preload("res://scripts/machine_badges.gd").grill(self)
	_build_control_display()
	knob = find_child("PowerKnob", true, false) as Node3D
	indicator = find_child("PowerIndicator", true, false) as MeshInstance3D
	var plate := find_child("CookingSurface", true, false) as MeshInstance3D
	if plate != null:
		# Existing FULL / HALF / HOLD panels occupy this exact surface.
		plate.hide()
	if knob != null:
		_center_power_knob()
		# Seat the dial against its ring instead of projecting far off the face.
		knob.position.y = .005
		off_rotation = knob.quaternion
	if indicator != null:
		var source := indicator.get_active_material(0) as StandardMaterial3D
		if source != null:
			lamp_material = source.duplicate() as StandardMaterial3D
			indicator.material_override = lamp_material
	set_power(false, true)


func _center_power_knob() -> void:
	if bool(knob.get_meta("pivot_centered", false)): return
	var body := knob.find_child("Rotary_Vermilion",true,false) as MeshInstance3D
	if body == null: body = knob.find_child("KnobBody",true,false) as MeshInstance3D
	if body == null or body.mesh == null: return
	# The batched red mesh retained a small lateral translation during export.
	# Center all rotating pieces together on the dial axis, preserving axial depth.
	var local_transform := body.transform
	var ancestor := body.get_parent()
	while ancestor != knob and ancestor is Node3D:
		local_transform = ancestor.transform * local_transform
		ancestor = ancestor.get_parent()
	var center := local_transform * body.mesh.get_aabb().get_center()
	var offset := Vector3(center.x,0.0,center.z)
	for child in knob.get_children():
		if child is Node3D: child.position -= offset
	knob.set_meta("pivot_centered",true)


func _apply_matte_steel(node: Node) -> void:
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		if part.mesh != null:
			for surface in part.mesh.get_surface_count():
				var source := part.get_active_material(surface) as StandardMaterial3D
				if source == null or not source.resource_name.begins_with("Satin stainless"):
					continue
				var metal := ShaderMaterial.new()
				metal.shader = preload("res://shaders/grill_trim_toon.gdshader")
				metal.set_shader_parameter("base_color", source.albedo_color.darkened(0.12))
				var bounds := part.mesh.get_aabb()
				metal.set_shader_parameter("bounds_min", bounds.position)
				metal.set_shader_parameter("bounds_size", bounds.size)
				if source.albedo_texture != null: metal.set_shader_parameter("base_texture", source.albedo_texture)
				part.set_surface_override_material(surface, metal)
	for child in node.get_children():
		_apply_matte_steel(child)


func _raise_splash_guard() -> void:
	## Stretch the authored stainless splash 2x above the plate — no extra lip.
	var steel := find_child("Housing_Satin_stainless", true, false) as MeshInstance3D
	if steel == null or steel.mesh == null:
		return
	if bool(steel.get_meta("splash_height_scaled", false)):
		return
	steel.mesh = _scale_mesh_height_above(steel.mesh, 0.012, 2.0)
	steel.set_meta("splash_height_scaled", true)


func _scale_mesh_height_above(mesh: Mesh, hinge_y: float, mul: float) -> Mesh:
	var out := ArrayMesh.new()
	for surf in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surf)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			if verts[i].y > hinge_y:
				verts[i].y = hinge_y + (verts[i].y - hinge_y) * mul
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := mesh.surface_get_material(surf)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out if out.get_surface_count() > 0 else mesh


func set_power(on: bool, instant: bool = false) -> void:
	if temperature_digits != null:
		temperature_digits.text = "ON" if on else "OFF"
		temperature_digits.shaded = not on
		temperature_digits.modulate = Color("FFB64D") if on else Color("597067")
	if power_tween != null:
		power_tween.kill()
	if knob != null:
		# glTF converts Blender local Z to Godot local Y.
		var target := off_rotation * Quaternion(Vector3.UP, -PI * 0.5 if on else 0.0)
		if instant:
			knob.quaternion = target
		else:
			power_tween = create_tween()
			power_tween.tween_property(knob, "quaternion", target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if lamp_material != null:
		lamp_material.albedo_color = Color("FFB336") if on else Color("674123")
		lamp_material.emission_enabled = on
		lamp_material.emission = Color("FF7B18")
		lamp_material.emission_energy_multiplier = 0.65 if on else 0.0


func _control_label(parent: Node3D, text: String, pos: Vector3, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.font = preload("res://assets/fonts/Fredoka-SemiBold.ttf")
	label.outline_size = 5
	label.outline_modulate = Color("252335")
	label.shaded = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.render_priority = 10
	label.modulate = Color("FFF0CD")
	label.position = pos
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _build_control_display() -> void:
	var front := find_child("ControlPanelMount", true, false) as Node3D
	if front == null: return
	for layer in 2:
		var panel := MeshInstance3D.new()
		panel.name = "ToonControlInset%d" % layer
		var shape := BoxMesh.new()
		shape.size = Vector3(.35-layer*.012,.004,.085-layer*.012)
		panel.mesh = shape; panel.position = Vector3(0,.019+layer*.004,.043)
		var enamel := StandardMaterial3D.new()
		enamel.albedo_color = Color("20202D") if layer == 0 else Color("426568")
		enamel.roughness = .48; enamel.metallic_specular = .25
		panel.material_override = enamel; front.add_child(panel)
	var screen := MeshInstance3D.new()
	screen.name = "PowerLEDDisplay"
	var glass := BoxMesh.new(); glass.size = Vector3(.135,.004,.043)
	screen.mesh = glass; screen.position = Vector3(.066,.030,.043)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color("11151F"); dark.roughness = .28
	screen.material_override = dark; front.add_child(screen)
	temperature_digits = _control_label(front, "OFF", Vector3(.066,.033,.043), .00055)
	temperature_digits.name = "TemperatureDigits"
	var bezel := MeshInstance3D.new()
	bezel.name = "ToonReadoutBezel"
	var box := BoxMesh.new(); box.size = Vector3(.151,.007,.059)
	bezel.mesh = box; bezel.position = Vector3(.066,.025,.043)
	var rim := StandardMaterial3D.new(); rim.albedo_color = Color("292C40"); rim.roughness = .7
	bezel.material_override = rim; front.add_child(bezel)

func knob_hit(camera: Camera3D, screen_pos: Vector2) -> bool:
	if knob == null or not is_visible_in_tree() or camera == null:
		return false
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var normal := knob.global_basis.y.normalized()
	var denominator := ray_dir.dot(normal)
	if absf(denominator) < 0.0001:
		return false
	var distance := (knob.global_position - ray_origin).dot(normal) / denominator
	if distance <= 0.0:
		return false
	var hit := ray_origin + ray_dir * distance
	return hit.distance_to(knob.global_position) <= 0.057 * knob.global_basis.x.length()
