extends Control
var game: Node
var turntable: Node3D
var age := 0.0
var duration := 10.0
var price: Label

func setup(owner_game: Node, id: String, seconds: float) -> void:
	game = owner_game
	duration = seconds
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	var wrap = SubViewportContainer.new()
	wrap.size = Vector2(300,200)
	wrap.position.y = 44
	wrap.stretch = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(300,200)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wrap.add_child(viewport)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(2,1.5,3),Vector3.ZERO)
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
		turntable.add_child(model)
		var bounds = game._shop_preview_bounds(model)
		var factor = 1.7 / maxf(bounds.size.length(),.01)
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor
	price = Label.new()
	price.text = "$%d" % game._shop_item_cost(id)
	price.size = Vector2(300,48)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
	price.add_theme_font_size_override("font_size",42)
	price.add_theme_color_override("font_color",Color("FFE082"))
	price.add_theme_color_override("font_outline_color",Color("473120"))
	price.add_theme_constant_override("outline_size",8)
	add_child(price)

func _process(delta: float) -> void:
	age += delta
	if age >= duration or not is_instance_valid(game) or not game.playing: queue_free(); return
	position = Vector2((get_viewport_rect().size.x-300)*.5,maxf(8.0,game.flash_label.position.y-252))
	turntable.rotation.y = age * .8
	turntable.position.y = sin(age*2.8)*.09
	queue_redraw()

func _draw() -> void:
	# Four-point toon glints shimmer around the rotating product silhouette.
	for i in 4:
		var phase = age * 2.8 + i*1.7
		var size_value = maxf(0,sin(phase))*12.0
		var center = Vector2(45 if i%2==0 else 255,90+i*35)
		var points = PackedVector2Array([center+Vector2(0,-size_value),center+Vector2(size_value*.23,-size_value*.23),center+Vector2(size_value,0),center+Vector2(size_value*.23,size_value*.23),center+Vector2(0,size_value),center+Vector2(-size_value*.23,size_value*.23),center+Vector2(-size_value,0),center+Vector2(-size_value*.23,-size_value*.23)])
		if size_value > .1: draw_colored_polygon(points,Color(1,1,.82))
