extends Control
var game: Node
var turntable: Node3D
var age := 0.0
var duration := 10.0
var price: Label
var preview_camera: Camera3D
const DISPLAY_SIZE := Vector2(720, 500)

func setup(owner_game: Node, id: String, seconds: float) -> void:
	game = owner_game
	duration = seconds
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	tree_exiting.connect(func():
		if is_instance_valid(game): game._layout_flash_label())
	var wrap = SubViewportContainer.new()
	wrap.size = Vector2(720,440)
	wrap.position.y = 60
	wrap.stretch = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(720,440)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wrap.add_child(viewport)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.2
	preview_camera = camera
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0,1.5,3.6),Vector3.ZERO)
	camera.current = true
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,140,0)
	fill.light_energy = .9
	viewport.add_child(fill)
	turntable = Node3D.new()
	viewport.add_child(turntable)
	var source = game._shop_product_source(id)
	if is_instance_valid(source):
		var model = source.duplicate(0)
		model.transform = Transform3D.IDENTITY
		model.show()
		model.process_mode = Node.PROCESS_MODE_DISABLED
		_add_moving_shine(model)
		turntable.add_child(model)
		var bounds = game._shop_preview_bounds(model)
		var factor = 1.7 / maxf(bounds.size.length(),.01)
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor
	price = Label.new()
	price.text = "$%d" % game._shop_item_cost(id)
	price.position = Vector2(26, 237)
	price.size = Vector2(146,52)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
	price.add_theme_font_size_override("font_size",36)
	price.add_theme_color_override("font_color",Color("4D291B"))
	price.add_theme_color_override("font_outline_color",Color("FFF0A6"))
	price.add_theme_constant_override("outline_size",3)
	add_child(price)
	var caption := Label.new()
	caption.text = "UPGRADE"
	caption.position = Vector2(26, 218)
	caption.size = Vector2(146,22)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
	caption.add_theme_font_size_override("font_size",13)
	caption.add_theme_color_override("font_color",Color("8A5828"))
	add_child(caption)

func _process(delta: float) -> void:
	age += delta
	if age >= duration or not is_instance_valid(game) or not game.playing: queue_free(); return
	var screen = get_viewport_rect().size
	var fit = minf(1.0, minf(screen.x / 900.0, (screen.y - 260.0) / DISPLAY_SIZE.y))
	fit = maxf(.5, fit)
	scale = Vector2.ONE * fit
	position = Vector2((screen.x-DISPLAY_SIZE.x*fit)*.5, maxf(130.0,screen.y-DISPLAY_SIZE.y*fit-136.0))
	turntable.rotation.y = maxf(0.0, age - 1.2) * .38
	turntable.position.y = sin(age*2.8)*.09
	queue_redraw()

func _draw() -> void:
	# Compact cream-and-gold retail tag beside the product.
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color("FFF0C8")
	tag.border_color = Color("D9A441")
	tag.set_border_width_all(2)
	tag.set_corner_radius_all(12)
	tag.shadow_color = Color(0.18,0.10,0.04,0.3)
	tag.shadow_size = 5
	tag.shadow_offset = Vector2(2,3)
	draw_style_box(tag, Rect2(16,208,170,88))
	draw_line(Vector2(36,240),Vector2(162,240),Color("E5C583"),1.0,true)
	draw_line(Vector2(185,252),Vector2(222,265),Color("D9A441"),2.0,true)
	draw_circle(Vector2(176,252),4,Color("D9A441"))
	draw_circle(Vector2(176,252),2,Color("FFF9E9"))
	# Sparkles travel with the product's rotating surface, rather than screen corners.
	for i in 4:
		var phase = age * 2.8 + i*1.7
		var size_value = maxf(0,sin(phase))*12.0
		var anchor = Vector3(cos(i*1.9)*.6, .5-i*.28, sin(i*1.9)*.6)
		var center = preview_camera.unproject_position(turntable.to_global(anchor)) + Vector2(0,60)
		var points = PackedVector2Array([center+Vector2(0,-size_value),center+Vector2(size_value*.23,-size_value*.23),center+Vector2(size_value,0),center+Vector2(size_value*.23,size_value*.23),center+Vector2(0,size_value),center+Vector2(-size_value*.23,size_value*.23),center+Vector2(-size_value,0),center+Vector2(-size_value*.23,-size_value*.23)])
		if size_value > .1: draw_colored_polygon(points,Color(1,1,.82))

func _add_moving_shine(node: Node) -> void:
	if node is MeshInstance3D:
		var shine = ShaderMaterial.new()
		shine.shader = preload("res://shaders/machine_showcase_shine.gdshader")
		node.material_overlay = shine
	for child in node.get_children(): _add_moving_shine(child)
