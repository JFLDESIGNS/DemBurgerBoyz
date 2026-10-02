extends Area3D

const COOK_SECONDS := 10.0
var game: Node
var chops := 0
var cook_time := 0.0
var portions := 4
var pieces := Node3D.new()
var materials: Array[ShaderMaterial] = []
var label: Label3D
var halo: MeshInstance3D
var steam: CPUParticles3D
var age := 0.0
var motion := Vector3.ZERO
var motion_energy := 0.0
var pressed := false
var slide_velocity := Vector2.ZERO
var layout_seed := randi()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_child(pieces)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = .18
	preload("res://scripts/ui_fonts.gd").apply_label3d(label, true, 42, .035)
	label.outline_size = 3
	add_child(label)
	halo = MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(.12, .12)
	halo.mesh = quad; halo.position = Vector3(0,.12,0)
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://shaders/patty_cook_halo.gdshader")
	halo.material_override = shader
	add_child(halo)
	steam = CPUParticles3D.new()
	steam.amount = 12; steam.lifetime = 1.1
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = .08
	steam.direction = Vector3.UP; steam.spread = 20
	steam.gravity = Vector3(0,.12,0)
	steam.initial_velocity_min = .07; steam.initial_velocity_max = .14
	steam.scale_amount_min = .018; steam.scale_amount_max = .036
	var puff := SphereMesh.new(); puff.radius = .5; puff.height = 1
	var vapor := StandardMaterial3D.new()
	vapor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vapor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vapor.albedo_color = Color(1,.96,.85,.12)
	puff.material = vapor; steam.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1,1,1,0)); fade.add_point(.2, Color.WHITE); fade.set_color(1, Color(1,1,1,0))
	steam.color_ramp = fade; steam.position.y = .035
	add_child(steam)
	rebuild()

func is_ready() -> bool:
	return chops == 2 and cook_time >= COOK_SECONDS

func chop() -> void:
	if chops >= 2: return
	chops += 1
	rebuild()
	pieces.position.y = .025
	create_tween().tween_property(pieces, "position:y", 0.0, .2).set_trans(Tween.TRANS_BOUNCE)

func rebuild() -> void:
	for child in pieces.get_children(): child.free()
	materials.clear()
	var rng := RandomNumberGenerator.new(); rng.seed = layout_seed
	for ring in 4:
		# Loose overlapping slices, with the same arrangement retained through cutting.
		var angle := float(ring)*2.4 + rng.randf_range(-.45,.45)
		var radius := rng.randf_range(.025,.068)
		var center := Vector3(cos(angle)*radius,.012+ring*.005,sin(angle)*radius)
		var ring_scale := rng.randf_range(.80,1.15)
		var ring_yaw := rng.randf()*TAU
		var count := 1 if chops == 0 else (2 if chops == 1 else 8)
		for cut in count:
			var mesh := MeshInstance3D.new()
			mesh.mesh = _arc_mesh(TAU/float(count)-.08)
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/onion_cooking.gdshader")
			mat.set_shader_parameter("patch_seed",rng.randf()*TAU)
			mat.set_shader_parameter("progress",clampf(cook_time/COOK_SECONDS,0,1))
			mesh.material_override = mat; materials.append(mat)
			var cut_angle := TAU * float(cut)/count + ring_yaw
			mesh.rotation.y = cut_angle
			mesh.scale = Vector3.ONE*ring_scale
			mesh.position = center + Vector3(cos(cut_angle),0,sin(cut_angle))*.005*chops
			if chops == 2:
				mesh.position = Vector3(rng.randf_range(-.045,.045),rng.randf_range(.012,.045),rng.randf_range(-.04,.04))
				mesh.rotation = Vector3(rng.randf_range(-.3,.3),rng.randf()*TAU,rng.randf_range(-.25,.25))
			mesh.set_meta("rest_position", mesh.position)
			mesh.set_meta("rest_rotation", mesh.rotation)
			pieces.add_child(mesh)
	pieces.scale = Vector3.ONE * pow(float(portions)/4.0, .33)

func _arc_mesh(sweep: float) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(3, int(sweep*10))
	for a in steps:
		for b in 8:
			var points: Array[Vector3] = []
			for ab in [Vector2(a,b),Vector2(a+1,b),Vector2(a+1,b+1),Vector2(a,b+1)]:
				var u: float = ab.x/steps*sweep; var v: float = ab.y/8.0*TAU
				points.append(Vector3(cos(u)*(.05+.008*cos(v)),.008*sin(v),sin(u)*(.05+.008*cos(v))))
			for index in [0,2,1,0,3,2]:
				st.set_color(Color("E6CFA7") if b in [0,1,6,7] else Color("FFF3DC"))
				st.add_vertex(points[index])
	# Close the freshly cut ends with pale, flat faces.
	for u in [0.0, sweep]:
		var center := Vector3(cos(u)*.05,0,sin(u)*.05)
		for b in 8:
			st.set_color(Color("FFF2DC"))
			st.add_vertex(center)
			for v in [float(b)/8*TAU,float(b+1)/8*TAU]:
				st.add_vertex(center+Vector3(cos(u)*.008*cos(v),.008*sin(v),sin(u)*.008*cos(v)))
	st.generate_normals()
	return st.commit()

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var active: bool = game.playing and not game.options_menu_open and not game.shift_paused and not game._boss_speech_active()
	var hot: bool = active and game.grill_on and not game._is_in_warmer_zone(global_position)
	if hot: cook_time = minf(COOK_SECONDS, cook_time + delta)
	age += delta if active else 0.0
	var progress := clampf(cook_time/COOK_SECONDS,0,1)
	for mat in materials:
		mat.set_shader_parameter("progress",progress)
	steam.emitting = hot
	halo.visible = hot and cook_time < COOK_SECONDS
	halo.material_override.set_shader_parameter("progress",progress)
	var camera := get_viewport().get_camera_3d()
	if camera != null: halo.look_at(camera.global_position,Vector3.UP,true)
	label.visible = not is_ready()
	label.text = "" if is_ready() else (("CHOP %d/2" % chops) if chops < 2 else "COOKING")
	label.modulate = Color("B8EC90") if is_ready() else Color("FFE6B3")
	if active:
		motion_energy = move_toward(motion_energy, 0.0, delta*2.0)
		motion = motion.lerp(Vector3.ZERO, minf(1,delta*6))
		var serving_scale := pow(float(portions)/4.0, .33)
		pieces.scale = pieces.scale.lerp(Vector3(1.13 if pressed else 1.0,.66 if pressed else 1.0,1.13 if pressed else 1.0)*serving_scale,minf(1,delta*14))
		for i in pieces.get_child_count():
			var piece := pieces.get_child(i) as Node3D
			if not piece.has_meta("rest_position"): continue
			var rest: Vector3 = piece.get_meta("rest_position")
			var phase := age*15 + i*2.37
			var scatter := Vector3(sin(i*4.7),0,cos(i*3.1))*motion_energy*.020
			piece.position = rest + scatter - motion*(.22+float(i%4)*.08)
			piece.position.y += absf(sin(phase))*motion_energy*.026 + (maxf(0,sin(phase))*.002 if hot else 0.0)
			piece.rotation = piece.get_meta("rest_rotation") + Vector3(sin(phase),0,cos(phase))*motion_energy*.22

func jostle(displacement: Vector2) -> void:
	motion = Vector3(displacement.x,0,displacement.y).limit_length(.07)
	motion_energy = minf(1.0,motion_energy + displacement.length()*12)

