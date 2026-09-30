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
		_add_moving_shine(model)
		turntable.add_child(model)
		var bounds = game._shop_preview_bounds(model)
		var factor = 1.7 / maxf(bounds.size.length(),.01)
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor
	price = Label.new()
	price.text = "$%d" % game._shop_item_cost(id)
	price.position = Vector2(235, 4)
	price.size = Vector2(250,64)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
	price.add_theme_font_size_override("font_size",52)
	price.add_theme_color_override("font_color",Color("4D291B"))
	price.add_theme_color_override("font_outline_color",Color("FFF0A6"))
	price.add_theme_constant_override("outline_size",3)
	add_child(price)

func _process(delta: float) -> void:
	age += delta
	if age >= duration or not is_instance_valid(game) or not game.playing: queue_free(); return
	var screen = get_viewport_rect().size
	game.flash_label.position.y = maxf(240.0, screen.y - game.flash_label.size.y - 28.0)
	var fit = minf(1.0, minf(screen.x / 900.0, (game.flash_label.position.y - 12.0) / DISPLAY_SIZE.y))
	fit = maxf(.5, fit)
	scale = Vector2.ONE * fit
	position = Vector2((screen.x-DISPLAY_SIZE.x*fit)*.5,maxf(4.0,game.flash_label.position.y-DISPLAY_SIZE.y*fit))
	turntable.rotation.y = age * .8
	turntable.position.y = sin(age*2.8)*.09
	queue_redraw()

func _draw() -> void:
	# Tilted golden retail tag with a punched corner and warm offset shadow.
	var tag = PackedVector2Array([Vector2(228,0),Vector2(478,6),Vector2(503,36),Vector2(473,72),Vector2(225,64)])
	var shadow = PackedVector2Array()
	for point in tag: shadow.append(point + Vector2(4,5))
	draw_colored_polygon(shadow,Color("71371C"))
	draw_colored_polygon(tag,Color("FFCA39"))
	draw_circle(Vector2(479,36),6,Color("71371C"))
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
