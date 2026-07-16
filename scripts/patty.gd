## 3D burger patty on the flat-top. Pink -> grey -> cooked -> black.
extends Area3D

signal flipped
signal clicked(patty: Area3D)

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

enum CookState { RAW, SEARING, COOKED, PERFECT, BURNT }

## ~15 seconds per side before flip / scoop.
const COOK_SEAR := 8.0
const COOK_DONE := 15.0
const COOK_PERFECT := 19.0
const COOK_BURNT := 28.0
const FLIP_READY := 15.0
const FLIP_WINDOW_START := 15.0
const FLIP_WINDOW_END := 21.0
const SCOOP_READY := 15.0 ## second side cook time before scoop

var cook_time: float = 0.0
var flipped_once: bool = false
var first_side_time: float = 0.0 ## cook progress locked in when flipped
var is_held: bool = false
var smash_bonus: float = 0.0
var slot_index: int = -1
var perfect_flip: bool = false
var heating: bool = true
var heat_mul: float = 1.0 ## 1 = full grill · 0 = hold zone (no cook)
var warm_hold_time: float = 0.0 ## seconds parked on the hold strip
const WARM_HOLD_MAX_SEC := 300.0
var base_y: float = 0.9
var _rest_x: float = 0.0
var _rest_z: float = 0.0
## Cheese slice melting on the grill.
var has_cheese: bool = false
var cheese_melt: float = 0.0 ## 0..1 over CHEESE_MELT_TIME
const CHEESE_MELT_TIME := 5.0
var _cheese_root: Node3D
var _cheese_mat: StandardMaterial3D
var _cheese_flaps: Array = [] ## MeshInstance3D flaps whose corners droop
## Dark pepper/seasoning flecks shaken onto raw beef.
var seasoning: float = 0.0 ## 0..1 coverage
var _season_root: Node3D = null
var _season_fleck_count: int = 0
const SEASON_MAX_FLECKS := 36

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _frost: MeshInstance3D
var _frost_mat: StandardMaterial3D
var _frost_top: MeshInstance3D
var _frost_top_mat: StandardMaterial3D
var _frost_haze: MeshInstance3D
var _frost_haze_mat: StandardMaterial3D
var _frost_uv_off: Vector3 = Vector3.ZERO
var _frost_uv_base: Vector3 = Vector3(2.2, 1.4, 1.0)
var _sear_seed: int = 0
var _under_mat: StandardMaterial3D
var _sear_disc: MeshInstance3D
var _sear_mat: StandardMaterial3D
var _meat_top: MeshInstance3D
var _meat_top_mat: StandardMaterial3D
var _hint: Label3D
var _hint_mode: String = "" ## "", cooking, flip, scoop
var _hint_age: float = 0.0
var _hint_focused: bool = false
var _sizzle: float = 0.0
var _bubbles: GPUParticles3D
var _top_bubbles: GPUParticles3D
var _steam: GPUParticles3D
var _announced_flip: bool = false
var _announced_scoop: bool = false
var _cook_img: Image
var _cook_tex: ImageTexture
static var _steam_tex: ImageTexture
## Frost textures are unique per patty (not shared).

## Color beat: frost melt → light red → rich red → brown → black
## Ice lasts nearly until flip; heat climbs from the grill so the top thaws last.
## Ice melts slowly from the grill up — top frost hangs on until near flip.
const FROST_MELT := 17.5
const COOK_LIGHT := 8.0
const COOK_RICH := 12.0
const HEAT_LAG := 5.5 ## top trails the bottom by this many cook-seconds
const COOK_TEX_W := 32
const COOK_TEX_H := 48
const BUBBLE_LEAD := 4.0 ## top grease bubbles start this many seconds before flip/scoop
const HINT_SCALE_FOCUS := 1.0 ## Former "small" size — max when hovered.
const HINT_SCALE_DIM := 0.55 ## Shrink when the cursor isn't on this patty.


func _ready() -> void:
	input_ray_pickable = false
	monitoring = false
	monitorable = false
	collision_layer = 2
	collision_mask = 0
	_rest_x = position.x
	_rest_z = position.z
	_sizzle = randf() * TAU

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	## Fat hit volume — grab / cheese rays forgive near-misses.
	cyl.radius = 0.17
	cyl.height = 0.16
	shape.shape = cyl
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.105
	disk.bottom_radius = 0.11
	disk.height = 0.045
	disk.radial_segments = 28
	_mesh.mesh = disk
	_mesh.position = Vector3(0, 0, 0)

	## Unshaded + vertical cook gradient (bottom sears first, top stays raw/frosty).
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.metallic = 0.0
	_mat.roughness = 1.0
	_cook_img = Image.create(COOK_TEX_W, COOK_TEX_H, false, Image.FORMAT_RGBA8)
	_cook_tex = ImageTexture.create_from_image(_cook_img)
	_mat.albedo_texture = _cook_tex
	_mat.albedo_color = Color.WHITE
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mat.emission_enabled = false
	_mesh.material_override = _mat
	add_child(_mesh)

	## Flat meat top — hides cylinder-cap polar cook UVs under the frost holes.
	_meat_top = MeshInstance3D.new()
	_meat_top.mesh = _make_planar_disc_mesh(0.1045, 28)
	_meat_top.position = Vector3(0, 0.0232, 0)
	_meat_top_mat = StandardMaterial3D.new()
	_meat_top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_meat_top_mat.albedo_color = Color(0.78, 0.38, 0.40)
	_meat_top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_meat_top_mat.render_priority = 0
	_meat_top.material_override = _meat_top_mat
	_mesh.add_child(_meat_top)

	## Darker underside disc for a stronger bottom-heavy meat look.
	var under := MeshInstance3D.new()
	var under_disk := CylinderMesh.new()
	under_disk.top_radius = 0.108
	under_disk.bottom_radius = 0.112
	under_disk.height = 0.012
	under.mesh = under_disk
	under.position = Vector3(0, -0.018, 0)
	_under_mat = StandardMaterial3D.new()
	_under_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_under_mat.albedo_color = Color(0.35, 0.12, 0.14)
	under.material_override = _under_mat
	_mesh.add_child(under)

	_sear_seed = randi()

	## Dark sear-spot disc — planar UVs so spots stay chunky, not polar.
	_sear_disc = MeshInstance3D.new()
	_sear_disc.mesh = _make_planar_disc_mesh(0.106, 28)
	_sear_disc.position = Vector3(0, 0.0245, 0)
	_sear_disc.visible = false
	_sear_mat = StandardMaterial3D.new()
	_sear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sear_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sear_mat.render_priority = 3
	_sear_mat.albedo_texture = _make_sear_spot_texture()
	_sear_mat.albedo_color = Color(1, 1, 1, 0.0)
	_sear_disc.material_override = _sear_mat
	_sear_disc.rotation_degrees.y = randf() * 360.0
	_mesh.add_child(_sear_disc)

	## Icy shell on the sides — tube only (no caps) so top face never gets polar UVs.
	var frost_tex := _make_frost_texture(randi())
	_frost = MeshInstance3D.new()
	_frost.mesh = _make_tube_mesh(0.106, 0.111, 0.046, 28)
	_frost.position = Vector3(0, 0.0, 0)
	_frost_mat = StandardMaterial3D.new()
	_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frost_uv_off = Vector3(randf() * 4.0, randf() * 4.0, 0.0)
	_frost_uv_base = Vector3(1.4 + randf() * 1.2, 1.0 + randf() * 0.8, 1.0)
	_frost_mat.albedo_texture = frost_tex
	_frost_mat.uv1_offset = _frost_uv_off
	_frost_mat.uv1_scale = _frost_uv_base
	_frost_mat.albedo_color = Color(1, 1, 1, 1)
	_frost_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_frost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frost_mat.render_priority = 1
	_frost.material_override = _frost_mat
	_frost.scale = Vector3(1.0, 1.0, 1.0)
	_frost.rotation_degrees.y = randf() * 360.0
	_mesh.add_child(_frost)

	## Soft even top haze — planar disc (cylinder caps warp textures into polar fans).
	_frost_haze = MeshInstance3D.new()
	_frost_haze.mesh = _make_planar_disc_mesh(0.1055, 24)
	_frost_haze.position = Vector3(0, 0.0235, 0)
	_frost_haze_mat = StandardMaterial3D.new()
	_frost_haze_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frost_haze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frost_haze_mat.albedo_color = Color(0.92, 0.95, 1.0, 0.105)
	_frost_haze_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frost_haze_mat.render_priority = 1
	_frost_haze.material_override = _frost_haze_mat
	_mesh.add_child(_frost_haze)

	## Top-face ice — planar disc so punched frost stays flat, not a starburst.
	_frost_top = MeshInstance3D.new()
	_frost_top.mesh = _make_planar_disc_mesh(0.1055, 28)
	_frost_top.position = Vector3(0, 0.0245, 0)
	_frost_top_mat = StandardMaterial3D.new()
	_frost_top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frost_top_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frost_top_mat.albedo_texture = frost_tex
	_frost_top_mat.albedo_color = Color(1, 1, 1, 1)
	_frost_top_mat.uv1_offset = Vector3(randf() * 3.0, randf() * 3.0, 0.0)
	_frost_top_mat.uv1_scale = Vector3(1.1 + randf() * 0.6, 1.1 + randf() * 0.6, 1.0)
	_frost_top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_frost_top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frost_top_mat.render_priority = 2
	_frost_top.material_override = _frost_top_mat
	_frost_top.rotation_degrees.y = randf() * 360.0
	_mesh.add_child(_frost_top)

	## Tiny frost ice shards on the top disc — irregular, not dice cubes.
	var fleck_n := randi_range(2, 4)
	for i in fleck_n:
		var fleck := MeshInstance3D.new()
		fleck.mesh = _make_ice_chunk_mesh(randi())
		var ang := randf() * TAU
		var rad := 0.025 + randf() * 0.065
		fleck.position = Vector3(cos(ang) * rad, 0.003 + randf() * 0.004, sin(ang) * rad)
		fleck.rotation_degrees = Vector3(
			randf_range(-35.0, 35.0),
			randf() * 360.0,
			randf_range(-40.0, 40.0)
		)
		var s := 0.55 + randf() * 0.85
		fleck.scale = Vector3(s * (0.7 + randf() * 0.7), s * (0.45 + randf() * 0.55), s * (0.65 + randf() * 0.75))
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fmat.albedo_color = Color(0.92 + randf() * 0.08, 0.96 + randf() * 0.04, 1.0, 0.14 + randf() * 0.14)
		fleck.material_override = fmat
		_frost_top.add_child(fleck)

	_hint = Label3D.new()
	_hint.text = "CLICK TO FLIP!"
	_hint.position = Vector3(0, 0.16, 0)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.modulate = Color("FFEB3B")
	_hint.visible = false
	UiFontsScript.apply_label3d(_hint, true, 72, 0.078)
	add_child(_hint)
	_setup_cook_fx()
	_update_cook_gradient()
	_update_frost_visual()


func _setup_cook_fx() -> void:
	## Grease bubbles popping out from under the patty edge, near the grill surface.
	_bubbles = GPUParticles3D.new()
	_bubbles.amount = 16
	_bubbles.lifetime = 0.35
	_bubbles.explosiveness = 0.0
	_bubbles.randomness = 0.65
	_bubbles.visibility_aabb = AABB(Vector3(-0.3, -0.08, -0.3), Vector3(0.6, 0.2, 0.6))
	_bubbles.emitting = false
	_bubbles.position = Vector3(0, -0.028, 0)
	var bmat := ParticleProcessMaterial.new()
	bmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	bmat.emission_ring_axis = Vector3(0, 1, 0)
	bmat.emission_ring_height = 0.002
	bmat.emission_ring_radius = 0.11
	bmat.emission_ring_inner_radius = 0.08
	## Mostly outward along the pad, tiny lift so they stay near the surface.
	bmat.direction = Vector3(0, 0.35, 0)
	bmat.spread = 55.0
	bmat.initial_velocity_min = 0.02
	bmat.initial_velocity_max = 0.06
	bmat.gravity = Vector3(0, -0.35, 0)
	bmat.damping_min = 1.5
	bmat.damping_max = 2.5
	bmat.scale_min = 0.35
	bmat.scale_max = 0.75
	bmat.color = Color(1.0, 0.92, 0.55, 0.85)
	var bscale := Gradient.new()
	bscale.add_point(0.0, Color(1, 1, 1, 0.95))
	bscale.add_point(0.45, Color(1, 1, 1, 0.7))
	bscale.add_point(1.0, Color(1, 1, 1, 0.0))
	var bscale_tex := GradientTexture1D.new()
	bscale_tex.gradient = bscale
	bmat.color_ramp = bscale_tex
	_bubbles.process_material = bmat
	var bsphere := SphereMesh.new()
	bsphere.radius = 0.006
	bsphere.height = 0.012
	bsphere.radial_segments = 8
	bsphere.rings = 4
	var bdraw := StandardMaterial3D.new()
	bdraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bdraw.albedo_color = Color(1.0, 0.95, 0.65, 0.8)
	bdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bdraw.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_bubbles.draw_pass_1 = bsphere
	_bubbles.material_override = bdraw
	add_child(_bubbles)

	## Top-surface grease bubbles — kick in ~4s before flip / scoop ready.
	_top_bubbles = GPUParticles3D.new()
	_top_bubbles.amount = 14
	_top_bubbles.lifetime = 0.4
	_top_bubbles.explosiveness = 0.0
	_top_bubbles.randomness = 0.7
	_top_bubbles.visibility_aabb = AABB(Vector3(-0.3, -0.05, -0.3), Vector3(0.6, 0.25, 0.6))
	_top_bubbles.emitting = false
	_top_bubbles.position = Vector3(0, 0.028, 0)
	var tmat := ParticleProcessMaterial.new()
	tmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	tmat.emission_ring_axis = Vector3(0, 1, 0)
	tmat.emission_ring_height = 0.002
	tmat.emission_ring_radius = 0.09
	tmat.emission_ring_inner_radius = 0.02
	tmat.direction = Vector3(0, 1.0, 0)
	tmat.spread = 40.0
	tmat.initial_velocity_min = 0.03
	tmat.initial_velocity_max = 0.09
	tmat.gravity = Vector3(0, -0.2, 0)
	tmat.damping_min = 1.2
	tmat.damping_max = 2.2
	tmat.scale_min = 0.3
	tmat.scale_max = 0.7
	tmat.color = Color(0.55, 0.16, 0.1, 0.9)
	var tscale := Gradient.new()
	tscale.add_point(0.0, Color(1, 1, 1, 0.95))
	tscale.add_point(0.4, Color(1, 1, 1, 0.75))
	tscale.add_point(1.0, Color(1, 1, 1, 0.0))
	var tscale_tex := GradientTexture1D.new()
	tscale_tex.gradient = tscale
	tmat.color_ramp = tscale_tex
	_top_bubbles.process_material = tmat
	var tsphere := SphereMesh.new()
	tsphere.radius = 0.0055
	tsphere.height = 0.011
	tsphere.radial_segments = 8
	tsphere.rings = 4
	var tdraw := StandardMaterial3D.new()
	tdraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tdraw.albedo_color = Color(0.48, 0.14, 0.09, 0.88)
	tdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_top_bubbles.draw_pass_1 = tsphere
	_top_bubbles.material_override = tdraw
	add_child(_top_bubbles)

	## Soft steam rising off the top while it cooks.
	_steam = GPUParticles3D.new()
	_steam.amount = 18
	_steam.lifetime = 1.15
	_steam.explosiveness = 0.0
	_steam.randomness = 0.55
	_steam.visibility_aabb = AABB(Vector3(-0.35, -0.05, -0.35), Vector3(0.7, 0.9, 0.7))
	_steam.emitting = false
	_steam.position = Vector3(0, 0.04, 0)
	var smat := ParticleProcessMaterial.new()
	smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smat.emission_sphere_radius = 0.07
	smat.direction = Vector3(0, 1, 0)
	smat.spread = 18.0
	smat.initial_velocity_min = 0.12
	smat.initial_velocity_max = 0.28
	smat.gravity = Vector3(0, 0.08, 0)
	smat.damping_min = 0.4
	smat.damping_max = 0.9
	smat.scale_min = 0.7
	smat.scale_max = 1.6
	smat.color = Color(0.95, 0.96, 0.98, 0.35)
	var sfade := Gradient.new()
	sfade.add_point(0.0, Color(1, 1, 1, 0.0))
	sfade.add_point(0.2, Color(1, 1, 1, 0.45))
	sfade.add_point(0.7, Color(1, 1, 1, 0.2))
	sfade.add_point(1.0, Color(1, 1, 1, 0.0))
	var sfade_tex := GradientTexture1D.new()
	sfade_tex.gradient = sfade
	smat.color_ramp = sfade_tex
	_steam.process_material = smat
	var squad := QuadMesh.new()
	squad.size = Vector2(0.06, 0.06)
	var sdraw := StandardMaterial3D.new()
	sdraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sdraw.albedo_texture = _get_steam_texture()
	sdraw.albedo_color = Color(1, 1, 1, 0.55)
	sdraw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sdraw.cull_mode = BaseMaterial3D.CULL_DISABLED
	sdraw.vertex_color_use_as_albedo = true
	_steam.draw_pass_1 = squad
	_steam.material_override = sdraw
	add_child(_steam)


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("game_audio")


func _update_ready_cues() -> void:
	var audio := _audio()
	if audio == null:
		return
	if can_flip() and not _announced_flip:
		_announced_flip = true
		audio.play_ready()
	elif flipped_once and can_scoop() and not _announced_scoop:
		_announced_scoop = true
		audio.play_ready()


func _get_steam_texture() -> ImageTexture:
	if _steam_tex != null:
		return _steam_tex
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mid := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_steam_tex = ImageTexture.create_from_image(img)
	return _steam_tex


func refresh_cook_visuals() -> void:
	## Call after parking back on the grill from warmer/UI so cook look matches cook_time.
	_update_cook_gradient()
	_update_frost_visual()
	_update_sear_disc()
	_update_meat_top()
	if has_cheese:
		_update_cheese_visual()
	_update_ready_cues()


func _process(delta: float) -> void:
	var cooking := heating and not is_held
	if _bubbles:
		_bubbles.emitting = cooking
	if _top_bubbles:
		## Surface bubbles ~4s before flip, and again ~4s before scoop-ready.
		var top_ready := false
		if cooking:
			if not flipped_once and cook_time >= FLIP_READY - BUBBLE_LEAD:
				top_ready = true
			elif flipped_once and cook_time >= SCOOP_READY - BUBBLE_LEAD:
				top_ready = true
		_top_bubbles.emitting = top_ready
	if _steam:
		_steam.emitting = cooking
	_update_ready_cues()
	## Cheese keeps melting anywhere — grill, HOLD, spatula, or Build board.
	if has_cheese and cheese_melt < 1.0:
		cheese_melt = minf(1.0, cheese_melt + delta / CHEESE_MELT_TIME)
		_update_cheese_visual()
	if is_held:
		if _hint:
			_hint.visible = false
		return
	if heating:
		var rate := (1.0 + smash_bonus) * heat_mul
		smash_bonus = maxf(0.0, smash_bonus - delta * 0.8)
		cook_time += delta * rate
		_sizzle += delta * 10.0 * heat_mul
	_update_cook_gradient()
	_update_frost_visual()
	_update_sear_disc()
	_update_meat_top()
	if _under_mat:
		## Face on the grill: raw underside after flip, seared contact before.
		if flipped_once:
			_under_mat.albedo_color = color_at_cook_time(cook_time).darkened(0.2)
		else:
			_under_mat.albedo_color = color_at_cook_time(cook_time).darkened(0.28)

	if can_flip():
		var flip_txt := "CLICK TO FLIP!" if is_in_flip_window() else "FLIP NOW"
		var flip_col := Color("FFEB3B") if is_in_flip_window() else Color("FFCC80")
		_set_hint_mode("flip", flip_txt, flip_col)
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.01))
	elif flipped_once and has_cheese and cheese_melt < 1.0 and cook_time >= SCOOP_READY:
		_set_hint_mode("melt", "CHEESE MELTING...", Color("FFE082"))
		_hint.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.01))
	elif flipped_once and can_scoop():
		if heat_mul <= 0.001:
			var left := maxi(0, int(ceil(WARM_HOLD_MAX_SEC - warm_hold_time)))
			_set_hint_mode("hold", "HOLD %ds" % left, Color("90CAF9"))
			_hint.modulate.a = 0.75
		else:
			_set_hint_mode("scoop", "CLICK TO SCOOP", Color("A5D6A7"))
			_hint.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.008))
	elif flipped_once:
		if heat_mul <= 0.001:
			var left2 := maxi(0, int(ceil(WARM_HOLD_MAX_SEC - warm_hold_time)))
			_set_hint_mode("hold", "HOLD %ds" % left2, Color("90CAF9"))
			_hint.modulate.a = 0.75
		else:
			_set_hint_mode("cooking", "COOKING...", Color("FFCC80"))
			_hint.modulate.a = 0.7
	else:
		_set_hint_mode("", "", Color.WHITE)

	_update_hint_scale(delta)

	## Keep patty seated on the pad, with a light sizzle shake while cooking.
	position.y = slot_base_y()
	if heating and not is_held:
		var shake := 0.0018
		position.x = _rest_x + sin(_sizzle * 1.7) * shake + cos(_sizzle * 2.3) * shake * 0.5
		position.z = _rest_z + cos(_sizzle * 1.9) * shake
		rotation.y = sin(_sizzle * 1.4) * 0.03
		if _mesh:
			_mesh.rotation_degrees.z = sin(_sizzle * 2.6) * 1.0
			_mesh.position.y = absf(sin(_sizzle * 3.1)) * 0.001
	else:
		position.x = _rest_x
		position.z = _rest_z
		rotation.y = 0.0
		if _mesh:
			_mesh.rotation_degrees.z = 0.0
			_mesh.position.y = 0.0


func slot_base_y() -> float:
	return base_y


func set_hint_focus(on: bool) -> void:
	_hint_focused = on


func _set_hint_mode(mode: String, text: String, color: Color) -> void:
	if _hint == null:
		return
	if mode == "":
		_hint.visible = false
		_hint_mode = ""
		_hint_age = 0.0
		_hint.scale = Vector3(HINT_SCALE_DIM, HINT_SCALE_DIM, HINT_SCALE_DIM)
		return
	_hint.visible = true
	_hint.text = text
	_hint.modulate = color
	if mode != _hint_mode:
		_hint_mode = mode
		_hint_age = 0.0
		## Never pop larger than focus size — start at dim/focus target.
		var start := HINT_SCALE_FOCUS if _hint_focused else HINT_SCALE_DIM
		_hint.scale = Vector3(start, start, start)


func _update_hint_scale(delta: float) -> void:
	if _hint == null or not _hint.visible:
		return
	_hint_age += delta
	var target := HINT_SCALE_FOCUS if _hint_focused else HINT_SCALE_DIM
	## Soft pulse only while focused on an action prompt.
	if _hint_focused and (_hint_mode == "flip" or _hint_mode == "scoop"):
		target *= 1.0 + 0.04 * absf(sin(Time.get_ticks_msec() * 0.01))
	var cur := _hint.scale.x
	var s := lerpf(cur, target, clampf(delta * 10.0, 0.0, 1.0))
	_hint.scale = Vector3(s, s, s)


func frost_amount() -> float:
	## Side/overall ice — clears from the grill up. 1 = frosted, 0 = gone.
	if flipped_once:
		return 0.0
	var t := clampf(cook_time / FROST_MELT, 0.0, 1.0)
	## Slow early drip, then steady melt — never a sudden top wipe.
	return clampf(1.0 - smoothstep(0.08, 0.92, t), 0.0, 1.0)


func frost_haze_amount() -> float:
	## Soft top haze — more transparent and gone well before flip ice.
	if flipped_once:
		return 0.0
	var t := clampf(cook_time / FROST_MELT, 0.0, 1.0)
	## Starts fading early, mostly gone by ~55% of the melt window.
	return clampf(1.0 - smoothstep(0.12, 0.55, t), 0.0, 1.0)


func frost_top_amount() -> float:
	## Top-face ice hangs on until near flip time.
	if flipped_once:
		return 0.0
	var t := clampf(cook_time / FROST_MELT, 0.0, 1.0)
	if t < 0.78:
		return 1.0
	var u := (t - 0.78) / 0.22
	return clampf(1.0 - smoothstep(0.0, 1.0, u), 0.0, 1.0)


func _make_ice_chunk_mesh(chunk_seed: int) -> ArrayMesh:
	## Low-poly irregular ice shard — broken crystal, not a cube.
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed if chunk_seed != 0 else randi()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	## Random tip + uneven base ring → chunky shard silhouette.
	var tip := Vector3(
		rng.randf_range(-0.004, 0.004),
		0.005 + rng.randf() * 0.007,
		rng.randf_range(-0.004, 0.004)
	)
	var base_n := rng.randi_range(4, 6)
	var base: Array = []
	for i in base_n:
		var a := (float(i) / float(base_n)) * TAU + rng.randf_range(-0.35, 0.35)
		var rad := 0.005 + rng.randf() * 0.009
		base.append(Vector3(
			cos(a) * rad * (0.65 + rng.randf() * 0.7),
			rng.randf_range(-0.002, 0.0015),
			sin(a) * rad * (0.55 + rng.randf() * 0.85)
		))
	## Occasional mid bulge so faces aren't flat pyramids.
	var mid_pts: Array = []
	var mid_n := rng.randi_range(1, 3)
	for _m in mid_n:
		var a2 := rng.randf() * TAU
		var rad2 := 0.004 + rng.randf() * 0.007
		mid_pts.append(Vector3(
			cos(a2) * rad2,
			0.0015 + rng.randf() * 0.004,
			sin(a2) * rad2
		))

	verts.append(tip)
	for p in base:
		verts.append(p)
	for p2 in mid_pts:
		verts.append(p2)

	## Fan tip → base edges.
	for i in base_n:
		var i1 := i + 1
		var i2 := 1 if i + 1 >= base_n else i + 2
		indices.append(0)
		indices.append(i1)
		indices.append(i2)
	## Cap the base (fan from first base vert).
	for i in range(1, base_n - 1):
		indices.append(1)
		indices.append(i + 2)
		indices.append(i + 1)
	## Stitch mid bulges to nearby base verts for broken faces.
	var mid_start := 1 + base_n
	for mi in mid_pts.size():
		var mid_i := mid_start + mi
		var b0 := 1 + (mi * 2) % base_n
		var b1 := 1 + (b0 % base_n)
		indices.append(mid_i)
		indices.append(b0)
		indices.append(b1)
		indices.append(0)
		indices.append(mid_i)
		indices.append(b0)

	## Flat normals per triangle for a faceted ice look.
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_i := PackedInt32Array()
	var tri_n := int(indices.size() / 3)
	for t in tri_n:
		var a := verts[indices[t * 3]]
		var b := verts[indices[t * 3 + 1]]
		var c := verts[indices[t * 3 + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			continue
		n = n.normalized()
		var base_idx := out_v.size()
		out_v.append(a)
		out_v.append(b)
		out_v.append(c)
		out_n.append(n)
		out_n.append(n)
		out_n.append(n)
		out_i.append(base_idx)
		out_i.append(base_idx + 1)
		out_i.append(base_idx + 2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_INDEX] = out_i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_planar_disc_mesh(radius: float, segments: int = 28) -> ArrayMesh:
	## Flat circle with planar UVs (0..1 across XZ) — avoids cylinder-cap polar fans.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	for i in segments:
		var a := float(i) / float(segments) * TAU
		var x := cos(a) * radius
		var z := sin(a) * radius
		verts.append(Vector3(x, 0.0, z))
		normals.append(Vector3.UP)
		uvs.append(Vector2(x / (radius * 2.0) + 0.5, z / (radius * 2.0) + 0.5))
	for i in segments:
		var i1 := i + 1
		var i2 := 1 if i + 2 > segments else i + 2
		indices.append(0)
		indices.append(i1)
		indices.append(i2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_tube_mesh(top_r: float, bottom_r: float, height: float, segments: int = 28) -> ArrayMesh:
	## Side wall only — no caps, so frost never gets polar UV on the top face.
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var y0 := -height * 0.5
	var y1 := height * 0.5
	for i in segments + 1:
		var t := float(i) / float(segments)
		var a := t * TAU
		var c := cos(a)
		var s := sin(a)
		var n := Vector3(c, 0.0, s)
		verts.append(Vector3(c * bottom_r, y0, s * bottom_r))
		normals.append(n)
		uvs.append(Vector2(t, 1.0))
		verts.append(Vector3(c * top_r, y1, s * top_r))
		normals.append(n)
		uvs.append(Vector2(t, 0.0))
	for i in segments:
		var b := i * 2
		indices.append(b)
		indices.append(b + 1)
		indices.append(b + 2)
		indices.append(b + 1)
		indices.append(b + 3)
		indices.append(b + 2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_frost_texture(frost_seed: int) -> ImageTexture:
	## White ice with lots of punched meat windows — never a solid overlay.
	var rng := RandomNumberGenerator.new()
	rng.seed = frost_seed if frost_seed != 0 else randi()
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox := rng.randf() * 50.0
	var oy := rng.randf() * 50.0
	## Ice patches
	var blobs: Array[Vector3] = []
	for i in rng.randi_range(6, 10):
		blobs.append(Vector3(rng.randf(), rng.randf(), 0.12 + rng.randf() * 0.22))
	## Many clear punches of varying size
	var clears: Array[Vector3] = []
	for i in rng.randi_range(18, 28):
		clears.append(Vector3(rng.randf(), rng.randf(), 0.05 + rng.randf() * 0.14))
	for y in h:
		for x in w:
			var u := float(x) / float(w)
			var v := float(y) / float(h)
			var n := _frost_noise2(u * 4.0 + ox, v * 4.0 + oy)
			n = n * 0.45 + _frost_noise2(u * 10.0 + ox * 0.4, v * 10.0 - oy) * 0.35
			var n2 := _frost_noise2(u * 26.0 + oy, v * 26.0 + ox)
			n = n + n2 * 0.2
			var ice := 0.0
			for b in blobs:
				var d := Vector2(u - b.x, v - b.y).length() / maxf(0.001, b.z)
				ice = maxf(ice, clampf(1.0 - d * d, 0.0, 1.0))
			var hole := 0.0
			for c in clears:
				var d2 := Vector2(u - c.x, v - c.y).length() / maxf(0.001, c.z)
				hole = maxf(hole, clampf(1.0 - d2, 0.0, 1.0))
			## Extra fine noise punches so it never reads as a flat white sheet.
			var micro_hole := 0.0
			if n2 < 0.38:
				micro_hole = (0.38 - n2) / 0.38
			var cover := ice * 0.85 + n * 0.3 - hole * 1.25 - micro_hole * 0.85
			cover = smoothstep(0.48, 0.82, cover)
			if cover < 0.12:
				continue
			var a := cover * cover * (0.35 + n * 0.25)
			## Chunky ice ~30% more transparent overall.
			a = minf(a, 0.42) * 0.7
			img.set_pixel(x, y, Color(0.92 + cover * 0.06, 0.96 + cover * 0.03, 1.0, a))
	return ImageTexture.create_from_image(img)


func _frost_noise2(x: float, y: float) -> float:
	## Cheap hash-based value noise in 0..1.
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - float(xi)
	var yf := y - float(yi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := _frost_hash(xi, yi)
	var b := _frost_hash(xi + 1, yi)
	var c := _frost_hash(xi, yi + 1)
	var d := _frost_hash(xi + 1, yi + 1)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _frost_hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _update_frost_visual() -> void:
	if _frost == null or _frost_mat == null:
		return
	var a := frost_amount()
	var top_a := frost_top_amount()
	## Side shell: melt from the grill UP — top edge stays put, bottom rises.
	if a <= 0.04:
		_frost.visible = false
	else:
		_frost.visible = true
		var melt := 1.0 - a
		var full_h := 0.046
		## Collapse upward: keep the top lip fixed, shrink height from below.
		var height := lerpf(full_h, 0.01, melt)
		var top_edge := 0.023
		_frost.scale = Vector3(1.0, height / full_h, 1.0)
		_frost.position = Vector3(0, top_edge - height * 0.5, 0)
		## Keep UVs stable so ice doesn't "crawl" off the top — only thin out.
		_frost_mat.uv1_scale = _frost_uv_base
		_frost_mat.uv1_offset = _frost_uv_off
		## Chunky ice opacity ~30% lower than before.
		_frost_mat.albedo_color = Color(1, 1, 1, lerpf(0.385, 0.196, melt))

	## Top punched ice — stays until near flip, then soft fade (not first).
	if _frost_haze != null and _frost_haze_mat != null:
		## Even white haze on the TOP FACE only — light opacity, fades faster than ice.
		## Never bake this into cook UVs — cylinder caps split vertical gradients down the middle.
		var haze_a := frost_haze_amount()
		if haze_a <= 0.04:
			_frost_haze.visible = false
		else:
			_frost_haze.visible = true
			_frost_haze.position.y = 0.0235
			_frost_haze_mat.albedo_color = Color(0.92, 0.95, 1.0, haze_a * 0.105)

	if _frost_top == null or _frost_top_mat == null:
		return
	if top_a <= 0.05:
		_frost_top.visible = false
		return
	_frost_top.visible = true
	var top_melt := 1.0 - top_a
	_frost_top.scale = Vector3(1.0, 1.0, 1.0)
	_frost_top.position.y = 0.0245
	## Gently open holes late by scaling UV a little — never wipe the whole face early.
	_frost_top_mat.uv1_scale = Vector3(
		lerpf(1.15, 1.35, top_melt),
		lerpf(1.15, 1.35, top_melt),
		1.0
	)
	_frost_top_mat.albedo_color = Color(1, 1, 1, lerpf(0.35, 0.154, top_melt))
	for child in _frost_top.get_children():
		if child is MeshInstance3D:
			var fm: StandardMaterial3D = child.material_override
			if fm:
				var fc := fm.albedo_color
				fc.a = top_a * 0.28
				fm.albedo_color = fc


func color_at_cook_time(t: float) -> Color:
	## Raw pink → cooked. No white frost wash (ice meshes handle that).
	var raw := Color(0.78, 0.38, 0.40)
	var light_red := Color(0.82, 0.42, 0.42)
	var rich_red := Color(0.62, 0.18, 0.18)
	var seared := Color(0.55, 0.26, 0.16)
	var brown := Color(0.40, 0.22, 0.12)
	var dark_brown := Color(0.22, 0.11, 0.06)
	var burnt := Color(0.06, 0.04, 0.03)
	t = maxf(0.0, t)

	if not flipped_once and t < 0.35:
		return raw
	if t < COOK_LIGHT * 0.45:
		var u := t / maxf(0.01, COOK_LIGHT * 0.45)
		return (raw if not flipped_once else light_red).lerp(light_red, u)
	if t < COOK_LIGHT:
		return light_red.lerp(rich_red, (t - COOK_LIGHT * 0.45) / (COOK_LIGHT * 0.55))
	if t < COOK_DONE:
		return rich_red.lerp(seared, (t - COOK_LIGHT) / (COOK_DONE - COOK_LIGHT))
	if t < COOK_PERFECT:
		return seared.lerp(brown, (t - COOK_DONE) / (COOK_PERFECT - COOK_DONE))
	if t < COOK_BURNT:
		return brown.lerp(dark_brown, (t - COOK_PERFECT) / (COOK_BURNT - COOK_PERFECT))
	var over := minf(1.0, (t - COOK_BURNT) / 5.0)
	return dark_brown.lerp(burnt, over)


func _update_cook_gradient() -> void:
	## Cylinder UV: v=0 at top, v=1 at bottom. Heat climbs from the grill.
	if _cook_img == null or _cook_tex == null:
		return
	for y in COOK_TEX_H:
		var v := float(y) / float(COOK_TEX_H - 1) ## 0 top → 1 bottom
		var c: Color
		if flipped_once:
			## Flip turns the patty over: former grill side is now the top.
			## Mild cooked bias — browned, not charcoal.
			var cooked_boost := 2.0
			var first_t := first_side_time + cooked_boost - v * HEAT_LAG
			var second_t := cook_time - (1.0 - v) * HEAT_LAG
			c = color_at_cook_time(maxf(first_t, second_t))
			## Soft sear wash on the flipped face.
			if v < 0.35:
				var face_t := first_side_time + cooked_boost + 1.0
				var top_sear := color_at_cook_time(face_t).darkened(0.08)
				var blend := clampf(1.0 - v / 0.35, 0.0, 1.0)
				c = c.lerp(top_sear, blend * 0.55)
				c = c.darkened(0.04 * blend)
		else:
			## Bottom (grill) cooks first; top stays raw longer.
			var local_t := cook_time - (1.0 - v) * HEAT_LAG
			c = color_at_cook_time(local_t)
			## No vertical frost haze in this texture — cylinder top-cap UVs map V
			## across the diameter and caused a left/right haze split.
			## Top haze is a separate even disc; sides clear via the ice shell.
		var grill_side := v if not flipped_once else (1.0 - v)
		c = c.darkened(grill_side * 0.1)
		for x in COOK_TEX_W:
			var px := c
			## After flip: light sear mottling — browned flecks, not burnt crust.
			if flipped_once and v < 0.45:
				var u := float(x) / float(COOK_TEX_W)
				var n := _sear_noise(u * 6.0 + float(_sear_seed % 17), v * 7.5 + float((_sear_seed / 17) % 13))
				n = n * 0.55 + _sear_noise(u * 14.0 + 1.7, v * 12.0) * 0.3
				n += _sear_noise(u * 28.0, v * 22.0) * 0.15
				var top_w := clampf(1.0 - v / 0.45, 0.0, 1.0)
				var cook_w := clampf((first_side_time - 8.0) / 14.0, 0.4, 1.0)
				if n > 0.58:
					var char_amt := ((n - 0.58) / 0.42) * top_w * cook_w
					px = px.darkened(clampf(0.12 + char_amt * 0.28, 0.0, 0.38))
				elif n > 0.45:
					px = px.darkened(0.08 * top_w * cook_w)
			_cook_img.set_pixel(x, y, px)
	_cook_tex.update(_cook_img)


func _sear_noise(x: float, y: float) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - float(xi)
	var yf := y - float(yi)
	var uu := xf * xf * (3.0 - 2.0 * xf)
	var vv := yf * yf * (3.0 - 2.0 * yf)
	var a := _sear_hash(xi, yi)
	var b := _sear_hash(xi + 1, yi)
	var c := _sear_hash(xi, yi + 1)
	var d := _sear_hash(xi + 1, yi + 1)
	return lerpf(lerpf(a, b, uu), lerpf(c, d, uu), vv)


func _sear_hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263 + _sear_seed
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _make_sear_spot_texture() -> ImageTexture:
	## Soft brown grill spots for the flipped top — subtle, not charcoal.
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid := float(w - 1) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var r := sqrt(dx * dx + dy * dy)
			if r > 0.98:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := clampf(1.0 - smoothstep(0.82, 0.98, r), 0.0, 1.0)
			var u := float(x) / float(w)
			var v := float(y) / float(h)
			var n := _sear_noise(u * 7.0, v * 7.0)
			n = n * 0.45 + _sear_noise(u * 16.0 + 2.1, v * 14.0) * 0.35
			n += _sear_noise(u * 32.0, v * 28.0) * 0.2
			var col := Color(0, 0, 0, 0)
			if n > 0.62:
				var k := (n - 0.62) / 0.38
				var a := edge * (0.28 + k * 0.28)
				col = Color(0.18, 0.08, 0.04, a)
			elif n > 0.48:
				var k2 := (n - 0.48) / 0.14
				var a2 := edge * k2 * 0.28
				col = Color(0.32, 0.15, 0.08, a2)
			elif n > 0.38:
				var a3 := edge * ((n - 0.38) / 0.1) * 0.14
				col = Color(0.4, 0.2, 0.1, a3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _update_sear_disc() -> void:
	if _sear_disc == null or _sear_mat == null:
		return
	if not flipped_once:
		_sear_disc.visible = false
		return
	_sear_disc.visible = true
	var cook_w := clampf((first_side_time - 10.0) / 14.0, 0.4, 1.0)
	_sear_mat.albedo_color = Color(1, 1, 1, 0.4 + cook_w * 0.28)
	_sear_disc.position.y = 0.0245


func _update_meat_top() -> void:
	if _meat_top == null or _meat_top_mat == null:
		return
	## Even top color — never the cylinder-cap polar cook map.
	if flipped_once:
		var face_t := first_side_time + 2.5
		_meat_top_mat.albedo_color = color_at_cook_time(face_t).darkened(0.06)
	else:
		## Top stays raw-ish longer while heat climbs from below.
		var local_t := cook_time - HEAT_LAG
		_meat_top_mat.albedo_color = color_at_cook_time(maxf(0.0, local_t))


func get_patty_color() -> Color:
	## Mid-height sample for UI / average look.
	if flipped_once:
		return color_at_cook_time(maxf(first_side_time - HEAT_LAG * 0.5, cook_time - HEAT_LAG * 0.5))
	return color_at_cook_time(cook_time - HEAT_LAG * 0.45)


func get_state() -> CookState:
	if cook_time >= COOK_BURNT:
		return CookState.BURNT
	if cook_time >= COOK_PERFECT:
		return CookState.PERFECT
	if cook_time >= COOK_DONE:
		return CookState.COOKED
	if cook_time >= COOK_LIGHT:
		return CookState.SEARING
	return CookState.RAW


func get_doneness_label() -> String:
	if not flipped_once and frost_amount() > 0.35:
		return "Frozen"
	if not flipped_once and cook_time < COOK_LIGHT:
		return "Thawing"
	match get_state():
		CookState.RAW:
			return "Raw"
		CookState.SEARING:
			return "Searing"
		CookState.COOKED:
			return "Cooked"
		CookState.PERFECT:
			return "Perfect!"
		CookState.BURNT:
			return "Burnt!"
	return ""


func can_flip() -> bool:
	return not flipped_once and cook_time >= FLIP_READY


func can_scoop() -> bool:
	## Only after a flip, and only once the second side has cooked a bit.
	## Cheese must finish melting before the scoop — even if the meat is done.
	if not flipped_once or cook_time < SCOOP_READY:
		return false
	if has_cheese and cheese_melt < 1.0:
		return false
	return true


func is_in_flip_window() -> bool:
	return not flipped_once and cook_time >= FLIP_WINDOW_START and cook_time <= FLIP_WINDOW_END


func flip() -> bool:
	if flipped_once or cook_time < FLIP_READY:
		return false
	## Lock in first-side doneness so the new top stays seared and sides keep their tones.
	first_side_time = cook_time
	flipped_once = true
	perfect_flip = is_in_flip_window()
	## Fresh timer for the second side (~15s to scoop).
	cook_time = 0.0
	_announced_scoop = false
	_update_frost_visual()
	_update_cook_gradient()
	_update_sear_disc()
	_update_meat_top()
	_hint.visible = false
	_hint_mode = ""
	_hint_age = 0.0
	if _hint:
		_hint.scale = Vector3(HINT_SCALE_DIM, HINT_SCALE_DIM, HINT_SCALE_DIM)
	var audio := _audio()
	if audio:
		audio.play_flip()
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.1, 0.08)
	tw.tween_property(self, "scale:x", 1.0, 0.12)
	flipped.emit()
	return true


func smash() -> void:
	smash_bonus = 1.6
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.55, 1.3), 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.1)


func add_cheese() -> bool:
	## Lay a yellow cheese square — melts over ~5s on grill, HOLD, or Build.
	if has_cheese:
		return false
	has_cheese = true
	cheese_melt = 0.0
	## Hold the scoop cue until melt finishes (meat may already be done).
	_announced_scoop = false
	_build_cheese_slice()
	_update_cheese_visual()
	return true


func apply_seasoning(amount: float = 0.07) -> bool:
	## Shake dark seasoning flecks onto the current top face.
	if is_held:
		return false
	if seasoning >= 1.0 and _season_fleck_count >= SEASON_MAX_FLECKS:
		return false
	seasoning = minf(1.0, seasoning + amount)
	_ensure_season_root()
	var to_add := clampi(2 + int(amount * 18.0), 2, 5)
	for _i in to_add:
		if _season_fleck_count >= SEASON_MAX_FLECKS:
			break
		_spawn_season_fleck()
	return true


func _ensure_season_root() -> void:
	if _season_root != null and is_instance_valid(_season_root):
		return
	_season_root = Node3D.new()
	_season_root.name = "Seasoning"
	_season_root.position = Vector3(0, 0.026, 0)
	add_child(_season_root)


func _spawn_season_fleck() -> void:
	if _season_root == null:
		return
	var fleck := MeshInstance3D.new()
	var fm := BoxMesh.new()
	var s := 0.008 + randf() * 0.012
	fm.size = Vector3(s * (0.5 + randf()), 0.0025 + randf() * 0.002, s * (0.4 + randf() * 0.8))
	fleck.mesh = fm
	var ang := randf() * TAU
	var rad := sqrt(randf()) * 0.095
	fleck.position = Vector3(cos(ang) * rad, 0.001 + randf() * 0.002, sin(ang) * rad)
	fleck.rotation_degrees = Vector3(randf() * 25.0 - 12.0, rad_to_deg(ang) + randf() * 40.0, randf() * 30.0 - 15.0)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	## Dark pepper / spice flecks.
	var shade := 0.08 + randf() * 0.14
	fmat.albedo_color = Color(shade, shade * 0.75, shade * 0.55, 0.75 + randf() * 0.2)
	fleck.material_override = fmat
	_season_root.add_child(fleck)
	_season_fleck_count += 1


func cheese_ready() -> bool:
	return has_cheese and cheese_melt >= 1.0


func _build_cheese_slice() -> void:
	if _cheese_root != null and is_instance_valid(_cheese_root):
		_cheese_root.queue_free()
	_cheese_flaps.clear()
	_cheese_root = Node3D.new()
	_cheese_root.name = "CheeseSlice"
	_cheese_root.position = Vector3(0, 0.028, 0)
	add_child(_cheese_root)

	_cheese_mat = StandardMaterial3D.new()
	_cheese_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cheese_mat.albedo_color = Color(1.0, 0.95, 0.32)
	_cheese_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	## One solid square slab (not a cross).
	var center := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.168, 0.006, 0.168)
	center.mesh = cmesh
	center.material_override = _cheese_mat
	_cheese_root.add_child(center)

	## Four corner tips — hinge near each corner so only the tips droop down.
	## Layout stays a square; as it melts the corners fold over the patty sides.
	var half := 0.084
	var tip := 0.028
	var hinge := half - tip
	var corner_defs := [
		{"hx": hinge, "hz": hinge, "sx": 1.0, "sz": 1.0}, ## +X +Z
		{"hx": -hinge, "hz": hinge, "sx": -1.0, "sz": 1.0}, ## -X +Z
		{"hx": hinge, "hz": -hinge, "sx": 1.0, "sz": -1.0}, ## +X -Z
		{"hx": -hinge, "hz": -hinge, "sx": -1.0, "sz": -1.0}, ## -X -Z
	]
	for def in corner_defs:
		var pivot := Node3D.new()
		pivot.position = Vector3(def["hx"], 0.0, def["hz"])
		_cheese_root.add_child(pivot)
		var flap := MeshInstance3D.new()
		var fmesh := BoxMesh.new()
		fmesh.size = Vector3(tip, 0.0055, tip)
		flap.mesh = fmesh
		## Sit just past the hinge so the outer tip is the square's corner.
		flap.position = Vector3(def["sx"] * tip * 0.5, 0.0, def["sz"] * tip * 0.5)
		flap.material_override = _cheese_mat
		pivot.add_child(flap)
		_cheese_flaps.append({
			"pivot": pivot,
			"sx": float(def["sx"]),
			"sz": float(def["sz"]),
		})


func _update_cheese_visual() -> void:
	if _cheese_root == null or _cheese_mat == null:
		return
	var t := clampf(cheese_melt, 0.0, 1.0)
	var drape := smoothstep(0.08, 0.92, t)
	drape = drape * drape * (3.0 - 2.0 * drape)
	## Bright yellow → slightly more orange as it melts.
	var yellow := Color(1.0, 0.95, 0.32)
	var orange := Color(0.98, 0.7, 0.2)
	_cheese_mat.albedo_color = yellow.lerp(orange, drape)
	## Soft corner tip — subtle melt, stays on top of the patty (no clip-through).
	var angle := drape * 12.0
	for item in _cheese_flaps:
		var pivot: Node3D = item["pivot"]
		var sx: float = item["sx"]
		var sz: float = item["sz"]
		pivot.rotation_degrees = Vector3(sz * angle, 0.0, -sx * angle)
	_cheese_root.position.y = lerpf(0.028, 0.026, drape)
	_cheese_root.scale = Vector3(lerpf(1.0, 1.008, drape), 1.0, lerpf(1.0, 1.008, drape))


func quality_multiplier() -> float:
	if not flipped_once:
		return 0.35
	var mul := 1.0
	match get_state():
		CookState.PERFECT:
			mul = 1.35 if perfect_flip else 1.2
		CookState.COOKED:
			mul = 1.1 if perfect_flip else 1.0
		CookState.BURNT:
			mul = 0.25
		CookState.SEARING:
			mul = 0.55
		_:
			mul = 0.3
	if seasoning >= 0.4:
		mul *= 1.06
	elif seasoning >= 0.15:
		mul *= 1.03
	return mul


func cook_rating() -> Dictionary:
	## Grade how well this patty was cooked (flip + second-side doneness).
	if not flipped_once:
		return {
			"score": 15,
			"grade": "F",
			"stars": 0,
			"label": "RAW",
			"detail": "Never flipped",
			"color": Color("EF5350"),
		}
	var score := 40.0
	if perfect_flip:
		score += 25.0
	elif first_side_time >= FLIP_READY:
		score += 12.0
	match get_state():
		CookState.PERFECT:
			score += 35.0
		CookState.COOKED:
			score += 28.0
		CookState.SEARING:
			score += 10.0
		CookState.BURNT:
			score -= 25.0
		_:
			score -= 10.0
	score = clampf(score, 0.0, 100.0)
	var grade := "F"
	var stars := 0
	var label := "BURNT"
	var color := Color("EF5350")
	var detail := "Charred"
	if score >= 92.0:
		grade = "S"
		stars = 5
		label = "PERFECT"
		color = Color("FFEB3B")
		detail = "Chef's kiss"
	elif score >= 82.0:
		grade = "A"
		stars = 4
		label = "GREAT"
		color = Color("A5D6A7")
		detail = "Juicy & done"
	elif score >= 70.0:
		grade = "B"
		stars = 3
		label = "GOOD"
		color = Color("81C784")
		detail = "Solid cook"
	elif score >= 55.0:
		grade = "C"
		stars = 2
		label = "OKAY"
		color = Color("FFCC80")
		detail = "A bit off"
	elif score >= 35.0:
		grade = "D"
		stars = 1
		label = "POOR"
		color = Color("FFA726")
		detail = "Undercooked"
	else:
		grade = "F"
		stars = 0
		label = "BURNT" if get_state() == CookState.BURNT else "RAW"
		color = Color("EF5350")
		detail = "Do over"
	if not perfect_flip and score >= 70.0:
		detail = "Late flip"
	return {
		"score": int(round(score)),
		"grade": grade,
		"stars": stars,
		"label": label,
		"detail": detail,
		"color": color,
	}


func cook_rating_text() -> String:
	var r := cook_rating()
	var star_s := ""
	for i in int(r["stars"]):
		star_s += "★"
	while star_s.length() < 5:
		star_s += "☆"
	return "%s  %s  %s (%d)" % [r["grade"], star_s, r["label"], r["score"]]


func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			smash()
