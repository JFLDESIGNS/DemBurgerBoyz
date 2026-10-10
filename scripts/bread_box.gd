extends Node3D

var game: Node
var door: Node3D
var open_amount := 0.0
var linger := 0.0
var model: Node3D
var door_closed_position := Vector3.ZERO
var bun_sign: Node3D

func setup(owner_game: Node, bun_scale: float) -> void:
	game=owner_game
	# Load the imported scene: exported games contain the .scn remap, not raw GLB bytes.
	model=preload("res://models/bread_box/bread_box.glb").instantiate()
	add_child(model)
	model.scale=Vector3.ONE*1.3*bun_scale
	model.rotation.y=PI
	door=model.find_child("BreadDoorPivot",true,false) as Node3D
	if is_instance_valid(door):door_closed_position=door.position
	# A lightly tinted pane stays readable without hiding the inventory behind it.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(i)
			if original is StandardMaterial3D and "cherry" in original.resource_name.to_lower():
				var steel:=ShaderMaterial.new()
				steel.shader=preload("res://shaders/bread_box_steel.gdshader")
				mesh.set_surface_override_material(i,steel)
			if original is StandardMaterial3D and "glass" in original.resource_name.to_lower():
				var mat:StandardMaterial3D=original.duplicate()
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color=Color(.78,.91,.96,.10)
				mat.cull_mode=BaseMaterial3D.CULL_DISABLED
				mat.roughness=.12
				mesh.set_surface_override_material(i,mat)
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_roof_sign_and_light()

func _add_roof_sign_and_light() -> void:
	bun_sign=Node3D.new()
	bun_sign.name="SpinningBunSign"
	bun_sign.position=Vector3(0,.445,0)
	model.add_child(bun_sign)
	var visual:=Node3D.new();visual.name="BunGeometry";bun_sign.add_child(visual)
	var pack:=preload("res://scripts/burger_pack_models.gd")
	var height:=0.0
	for half in ["Bottom","Top"]:
		var bun:=pack.instantiate_scene("res://models/burgerpack/try2/SM_BurgerBunUntoasted%s.glb" % half)
		if not is_instance_valid(bun):continue
		visual.add_child(bun)
		bun.scale.y *= 1.3 if half=="Bottom" else 1.1
		var bounds:AABB=game._shop_preview_bounds(bun)
		bun.position=Vector3(-bounds.get_center().x,height-bounds.position.y,-bounds.get_center().z)
		height+=bounds.size.y
		for mesh in bun.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in mesh.mesh.get_surface_count():
				var original=mesh.get_active_material(i)
				if original is StandardMaterial3D:
					var gloss:StandardMaterial3D=original.duplicate()
					gloss.roughness=.22;gloss.metallic=0;gloss.metallic_specular=.6
					gloss.clearcoat_enabled=true;gloss.clearcoat=.35;gloss.clearcoat_roughness=.18
					mesh.set_surface_override_material(i,gloss)
	var total:AABB=game._shop_preview_bounds(visual)
	visual.scale=Vector3.ONE*(.32625/maxf(.001,maxf(total.size.x,total.size.z)))
	_add_fresh_lettering()
	var stem:=MeshInstance3D.new()
	stem.name="BunSignStand"
	var pole:=CylinderMesh.new();pole.top_radius=.006;pole.bottom_radius=.009;pole.height=.045;pole.radial_segments=8
	stem.mesh=pole;stem.position=Vector3(0,.4225,0)
	var metal:=StandardMaterial3D.new();metal.albedo_color=Color("A4ADB4");metal.metallic=.65;metal.roughness=.3
	stem.material_override=metal;model.add_child(stem)
	var lamp:=MeshInstance3D.new()
	lamp.name="InteriorLightStrip"
	var strip:=BoxMesh.new();strip.size=Vector3(.34,.006,.015)
	lamp.mesh=strip;lamp.position=Vector3(0,.317,.055)
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color("B6AD96");glow.emission_enabled=true;glow.emission=Color("FFE4AB");glow.emission_energy_multiplier=.12
	lamp.material_override=glow;lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(lamp)
	var light:=OmniLight3D.new();light.name="InteriorBunLight";light.position=Vector3(0,.285,.015)
	light.light_color=Color("FFE8C4");light.light_energy=.012;light.light_specular=.1;light.omni_range=.55;light.omni_attenuation=1.7;light.shadow_enabled=false
	model.add_child(light)

func _add_fresh_lettering() -> void:
	var letters:=MeshInstance3D.new();letters.name="GoldLeafFresh"
	var text:=TextMesh.new();text.text="FRESH";text.font=preload("res://assets/fonts/Pacifico-Regular.ttf")
	text.font_size=96;text.pixel_size=.001;text.depth=.001
	letters.mesh=text
	var gold:=ShaderMaterial.new();gold.shader=preload("res://shaders/fresh_gold_lettering.gdshader")
	letters.material_override=gold
	var bounds=text.get_aabb();var fit=minf(.39/maxf(.001,bounds.size.x),.095/maxf(.001,bounds.size.y)) * .75
	gold.set_shader_parameter("text_left",bounds.position.x);gold.set_shader_parameter("text_width",bounds.size.x)
	letters.scale=Vector3.ONE*fit;letters.position=Vector3(.018-bounds.get_center().x*fit,.220-bounds.get_center().y*fit,.207)
	var ink:=StandardMaterial3D.new();ink.albedo_color=Color("100C08");ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 12:
		var stroke:=MeshInstance3D.new();stroke.name="BlackStroke%d"%i;stroke.mesh=text;stroke.material_override=ink
		stroke.position=Vector3(cos(TAU*i/12.0)*.0017/fit,sin(TAU*i/12.0)*.0017/fit,-.0015/fit)
		stroke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;letters.add_child(stroke)
	letters.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(letters)
	if is_instance_valid(door): letters.reparent(door, true)

func overlaps_door(pointer:Vector2) -> bool:
	if not is_instance_valid(model) or not is_instance_valid(game.camera):return false
	# Exact closed-door face, including glass; no sign, roof, sides or hover padding.
	# Keep this footprint stable as the door swings so buns remain accessible.
	var polygon:=PackedVector2Array()
	for corner in [Vector3(-.253,.079,.20),Vector3(.253,.079,.20),Vector3(.253,.341,.20),Vector3(-.253,.341,.20)]:
		var world_point:Vector3=model.to_global(corner)
		if game.camera.is_position_behind(world_point):return false
		polygon.append(game.camera.unproject_position(world_point))
	return Geometry2D.is_point_in_polygon(pointer,polygon)

func _process(delta:float) -> void:
	if not is_instance_valid(door) or not is_instance_valid(game):return
	var active:bool=game.playing and not game.options_menu_open and not game.shift_paused and is_visible_in_tree()
	if active and is_instance_valid(bun_sign):bun_sign.rotation.y=fposmod(bun_sign.rotation.y+delta*.8,TAU)
	var pointer:Vector2=game._gui_to_camera_screen(get_viewport().get_mouse_position())
	if active and overlaps_door(pointer):linger=.65
	else:linger=maxf(0,linger-delta)
	set_open(linger>0,delta)

func set_open(wanted:bool,delta:float) -> void:
	open_amount=move_toward(open_amount,1.0 if wanted else 0.0,delta*3.4)
	if is_instance_valid(door):
		var tilt := smoothstep(0,.65,open_amount)
		var slide := smoothstep(.65,1,open_amount)
		door.rotation=Vector3(-PI*.5*tilt,0,0)
		door.position=door_closed_position+Vector3(0,.003*tilt,-.29*slide)
