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
	preload("res://scripts/machine_badges.gd").grill(self)
	_build_control_display()
	knob = find_child("PowerKnob", true, false) as Node3D
	indicator = find_child("PowerIndicator", true, false) as MeshInstance3D
	var plate := find_child("CookingSurface", true, false) as MeshInstance3D
	if plate != null:
		# Existing FULL / HALF / HOLD panels occupy this exact surface.
		plate.hide()
	if knob != null:
		off_rotation = knob.quaternion
	if indicator != null:
		var source := indicator.get_active_material(0) as StandardMaterial3D
		if source != null:
			lamp_material = source.duplicate() as StandardMaterial3D
			indicator.material_override = lamp_material
	set_power(false, true)


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
		temperature_digits.text = "185°" if on else "OFF"
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
	label.outline_size = 0
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
	preload("res://scripts/machine_badges.gd").decal(front, "TemperatureDisplay", "grill_temp_panel.png", Vector2(0.14,0.047), Vector3(0.066,0.019,0.043), Vector3(-90,0,0))
	temperature_digits = _control_label(front, "OFF", Vector3(0.081,0.020,0.043), 0.00038)
	temperature_digits.name = "TemperatureDigits"
	_control_label(front, "OFF", Vector3(-0.132,0.019,0.025), 0.00020)
	_control_label(front, "ON", Vector3(-0.024,0.019,0.025), 0.00020)

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
