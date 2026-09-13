extends Control
## Shared doll-studio presentation. Reuses the existing creator's state and callbacks.
const INK = Color("f4edf9")
const MUTED = Color("b4a8c2")
const ACCENT = Color("ed887e")
const PAPER = Color("24212e")
const LILAC = Color("514061")
const CATEGORIES = {"Body":["Skin","Starters"],"Face":["Eyes","Sparkle","Opening","Brows","Nose","Mouth","Cheeks","Ears"],"Hair":["Hair","Facial hair"],"Clothes":["Tops","Graphics","Bottoms","Shoes"],"Accessories":["Hats","Glasses","Makeup","Jewelry"],"Voice":["Voice"],"Pose":["Pose"],"Paint":["Paint"],"Collection":["Saved customers"]}
const NODES = {"Eyes":["EyesSelect","EyeAdjustments","EyeRotationAdjustments"],"Sparkle":["EyeSpecularAdjustments"],"Opening":["LashSelect","LashColor","LashAdjustments"],"Brows":["EyebrowSelect","EyebrowColor","EyebrowAdjustments"],"Nose":["NoseSelect","NoseColor","NoseAdjustments"],"Mouth":["MouthSelect","MouthColor","MouthAdjustments"],"Cheeks":["CheekSelect","CheekColor","CheekAdjustments"],"Ears":["EarColor","EarAdjustments"],"Hair":["HairSelect","HairColor","HairAdjustments"],"Facial hair":["FacialHairSelect","FacialHairColor","FacialHairAdjustments"],"Hats":["HatSelect","HatColor","HatAdjustments"],"Glasses":["GlassesSelect","GlassesColor","GlassesAdjustments"],"Makeup":["MakeupSelect","MakeupColor","MakeupAdjustments"],"Jewelry":["JewelrySelect","JewelryColor","JewelryAdjustments"],"Tops":["TopSelect","TopColor","TopAdjustments"],"Graphics":["GraphicSelect","GraphicColor","GraphicAdjustments"],"Bottoms":["BottomSelect","BottomColor","BottomAdjustments"],"Shoes":["ShoeSelect","ShoeColor","ShoeAdjustments"]}
const PREFIX = {"Voice":"customer_voice","Skin":"skin_","Eyes":"eye_","Sparkle":"eye_specular_","Opening":"eyelid_","Brows":"brow_","Nose":"nose_","Mouth":"mouth_","Cheeks":"cheek_","Ears":"ear_","Hair":"hair_","Facial hair":"facial_hair_","Hats":"hat_","Glasses":"glasses_","Makeup":"makeup_","Jewelry":"jewelry_","Tops":"top_","Graphics":"shirt_graphic","Bottoms":"bottom_","Shoes":"shoe_"}
const STYLE_PROPERTIES = {"Opening":"lash_style","Brows":"brow_style","Nose":"nose_style","Mouth":"mouth_style","Cheeks":"cheek_style","Hair":"hair_style","Facial hair":"facial_hair_style","Hats":"hat_style","Glasses":"glasses_style","Makeup":"makeup_style","Jewelry":"jewelry_style","Tops":"top_style","Graphics":"shirt_graphic","Bottoms":"bottom_style","Shoes":"shoe_style"}
var voice_select: OptionButton
var voice_preview: AudioStreamPlayer
var host
var doll
var pages = {}
var selectors = {}
var cards = {}
var nav_buttons = {}
var utility_buttons = []
var spins = {}
var defaults = {}
var locks = {}
var scroll_positions = {}
var category = "Body"
var section = "Skin"
var mode = "Dress"
var linked = true
var syncing = false
var top_bar: PanelContainer
var nav: PanelContainer
var inspector: PanelContainer
var tabs: HFlowContainer
var scroll: ScrollContainer
var page_stack: VBoxContainer
var title_label: Label
var subtitle: Label
var hint: Label
var saved_label: Label
var undo_button: Button
var redo_button: Button
var lock_button: Button
var stage_controls: PanelContainer
var stage_tools: HFlowContainer
var stage_view: SubViewport
var stage_picture: TextureRect
var stage_backdrop: MeshInstance3D
var stage_truck: Node3D
var framed_view = "Full body"
var footer: PanelContainer
var layer_list: VBoxContainer
var layer_toggle: Button
var gallery_search: LineEdit
var history: Array[Dictionary] = []
var future: Array[Dictionary] = []
var saved_signature = ""
var last_signature = ""
var poll_time = 0.0
var paint_changed = false
var stage_rect = Rect2()
var last_layers = ""
var dark_backdrop = true
var recent_colors: Array = []
var favorite_colors: Array = []
var palette_rows: Array = []
var preferences = ConfigFile.new()
var catalog_page = {}
var catalog_query = {}
var catalog_counters = {}
var catalog_arrows = {}
const CATALOG_PAGE_SIZE = 3
var thumbnail_queue: Array = []
var thumbnail_cache = {}
var thumbnail_view: SubViewport
var thumbnail_doll
var thumbnail_camera: Camera3D
var thumbnail_busy = false
var hidden_layers = {}

func setup(controller: Node) -> void:
	host = controller
	doll = host.character
	name = "DollStudio"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	theme = make_theme()
	preferences.load("user://doll_studio.cfg")
	recent_colors = preferences.get_value("colors","recent",[])
	favorite_colors = preferences.get_value("colors","favorites",[])
	var default_doll = doll.get_script().new()
	for info in doll.get_script().get_script_property_list():
		var key = str(info.name)
		if int(info.usage) & PROPERTY_USAGE_STORAGE and not key.begins_with("_") and key != "defer_initial_appearance":
			defaults[key] = default_doll.get(key)
	default_doll.free()
	host.get_node("UI/Sidebar").hide()
	host.get_node("UI/ModulesPanel").hide()
	for child in host.get_node("UI").get_children():
		if "Hint" in str(child.name): child.hide()
	build_shell()
	build_pages()
	build_stage()
	apply_backdrop()
	select_category("Body")
	resized.connect(layout)
	layout()
	call_deferred("initialize_history")

func style(color: Color, border = Color("40374c"), radius = 14) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s

func make_theme() -> Theme:
	var t = Theme.new()
	t.default_font_size = 15
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Noto Sans","Arial"])
	t.default_font = font
	for type in ["Button","OptionButton","CheckButton","CheckBox","LineEdit","SpinBox","Label"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: t.set_color(state,type,INK)
		t.set_color("font_disabled_color",type,Color("aaa0ae"))
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,style(PAPER))
		t.set_stylebox("hover",type,style(Color("39303e"),ACCENT))
		t.set_stylebox("pressed",type,style(LILAC,Color("af8dce")))
		t.set_stylebox("disabled",type,style(Color("292530")))
		var focus = style(Color.TRANSPARENT,Color("9470c1"))
		focus.set_border_width_all(2)
		t.set_stylebox("focus",type,focus)
	t.set_stylebox("normal","LineEdit",style(Color("191721")))
	t.set_stylebox("focus","LineEdit",style(Color("191721"),ACCENT))
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_color("caret_color","LineEdit",INK)
	t.set_color("selection_color","LineEdit",Color("725a89"))
	var track = style(Color("4c4058"),Color("4c4058"),3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider","HSlider",track)
	t.set_stylebox("grabber_area","HSlider",style(ACCENT,ACCENT,3))
	t.set_stylebox("grabber_area_highlight","HSlider",style(Color("b991cd"),Color("b991cd"),3))
	t.set_icon("grabber","HSlider",round_icon(ACCENT))
	t.set_icon("grabber_highlight","HSlider",round_icon(Color("b991cd")))
	t.set_stylebox("panel","PopupMenu",style(PAPER))
	t.set_color("font_color","PopupMenu",INK)
	t.set_color("font_hover_color","PopupMenu",INK)
	t.set_stylebox("hover","PopupMenu",style(LILAC))
	t.set_constant("separation","VBoxContainer",10)
	t.set_constant("separation","HBoxContainer",8)
	t.set_constant("h_separation","HFlowContainer",7)
	t.set_constant("v_separation","HFlowContainer",7)
	return t

func round_icon(color: Color) -> ImageTexture:
	var img = Image.create(20,20,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in 20:
		for x in 20:
			if Vector2(x-9.5,y-9.5).length() < 8.5: img.set_pixel(x,y,color)
	return ImageTexture.create_from_image(img)

func label(text: String, font_size = 15, color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l

func button(text: String, action: Callable, primary = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	b.pressed.connect(action)
	if primary:
		b.add_theme_stylebox_override("normal",style(ACCENT,ACCENT))
		b.add_theme_color_override("font_color",Color("241c2e"))
	return b

func move_control(node: Control, destination: Node) -> void:
	node.reparent(destination)
	node.show()
	node.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	node.custom_minimum_size.x = 0
	for info in node.get_property_list():
		if str(info.name).begins_with("theme_override_"): node.set(info.name,null)
	if node is Label: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if node is Button: node.custom_minimum_size.y = 38

func panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(PAPER))
	add_child(p)
	return p

func build_shell() -> void:
	top_bar = panel()
	var top = HBoxContainer.new()
	top_bar.add_child(top)
	var brand = label("Customer Creator",20)
	brand.custom_minimum_size.x = 185
	top.add_child(brand)
	move_control(host.character_name,top)
	host.character_name.placeholder_text = "Name your customer"
	host.character_name.custom_minimum_size.x = 110
	host.character_name.tooltip_text = "Customer name"
	undo_button = button("↶",undo)
	undo_button.tooltip_text = "Undo • Ctrl+Z"
	top.add_child(undo_button)
	redo_button = button("↷",redo)
	redo_button.tooltip_text = "Redo • Ctrl+Shift+Z"
	top.add_child(redo_button)
	top.add_child(button("Save as",save_as))
	move_control(host.save_button,top)
	host.save_button.size_flags_horizontal = SIZE_SHRINK_END
	host.save_button.text = "Save customer"
	host.save_button.add_theme_stylebox_override("normal",style(ACCENT,ACCENT))
	host.save_button.add_theme_color_override("font_color",Color("241c2e"))
	host.save_button.pressed.connect(mark_saved)
	nav = panel()
	var nav_scroll = ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav.add_child(nav_scroll)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_scroll.add_child(col)
	var icons = ["♡","◡","≈","♧","✧","♫","◇","◌","▦"]
	var i = 0
	for key in CATEGORIES:
		var b = button(icons[i]+"  "+key,select_category.bind(key))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.custom_minimum_size.y = 45
		b.set_meta("full",b.text)
		b.set_meta("icon",icons[i])
		b.tooltip_text = key
		col.add_child(b)
		nav_buttons[key] = b
		i += 1
	for entry in [["SculptModeButton","Sculpt…"],["BackToGameButton","← Back"],["ExitCreatorButton","Exit"]]:
		var control = host.sidebar_controls.get_node_or_null(entry[0])
		if control != null:
			move_control(control,col)
			control.text = entry[1]
			control.set_meta("full",control.text)
			control.tooltip_text = control.text
			utility_buttons.append(control)
	inspector = panel()
	var right = VBoxContainer.new()
	inspector.add_child(right)
	title_label = label("Your customer",25)
	right.add_child(title_label)
	subtitle = label("A little imagination. A lot of personality.",13,MUTED)
	right.add_child(subtitle)
	tabs = HFlowContainer.new()
	right.add_child(tabs)
	var actions = HBoxContainer.new()
	right.add_child(actions)
	var shuffle = button("Surprise me",randomize_section)
	shuffle.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.add_child(shuffle)
	lock_button = button("Lock",toggle_lock)
	lock_button.toggle_mode = true
	lock_button.tooltip_text = "Protect this section from randomization"
	actions.add_child(lock_button)
	actions.add_child(button("Reset",reset_section))
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.follow_focus = true
	right.add_child(scroll)
	page_stack = VBoxContainer.new()
	page_stack.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(page_stack)
	footer = panel()
	var foot = HBoxContainer.new()
	footer.add_child(foot)
	move_control(host.status_label,foot)
	host.status_label.custom_minimum_size.y = 0
	host.status_label.size = Vector2.ZERO
	host.status_label.add_theme_font_size_override("font_size",12)
	host.status_label.max_lines_visible = 2
	saved_label = label("Ready to create",12,MUTED)
	saved_label.custom_minimum_size.x = 116
	saved_label.size_flags_vertical = SIZE_SHRINK_CENTER
	foot.add_child(saved_label)

func page(key: String) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.name = key.replace(" ","")+"Page"
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",14)
	page_stack.add_child(box)
	pages[key] = box
	return box

func build_pages() -> void:
	build_voice_page(page("Voice"))
	var body = page("Skin")
	body.add_child(label("A lovely place to start",20))
	body.add_child(label("Choose a skin tone, then explore face, hair and outfits.",14,MUTED))
	move_control(host.swatches,body)
	host.swatches.columns = 4
	for i in host.swatches.get_child_count():
		var swatch = host.swatches.get_child(i)
		swatch.custom_minimum_size = Vector2(52,44)
		swatch.tooltip_text = "Skin tone %d" % (i+1)
	move_control(host.custom_color,body)
	palette(host.custom_color,body)
	body.add_child(button("Choose a starter customer →",select_section.bind("Starters"),true))
	body.add_child(button("Accessory fitting workspace…",open_fit_room))
	build_starters(page("Starters"))
	for key in NODES:
		var box = page(key)
		for node_name in NODES[key]:
			var node = host.module_controls.get_node_or_null(node_name)
			if node == null: continue
			if node is OptionButton and not node.disabled:
				selectors[key] = node
				style_grid(key,node,box)
			elif node is ColorPickerButton:
				box.add_child(label("COLOR",11,MUTED))
				move_control(node,box)
				node.text = "Custom color…"
				palette(node,box)
			elif node is VBoxContainer: adjustments(node,box,key)
		if key == "Hair" and host.get("_hair_layer_select") != null:
			layer_list = VBoxContainer.new()
			box.add_child(layer_list)
			layer_list.hide()
			layer_toggle = button("Hair layers",func(): layer_list.visible = not layer_list.visible)
			layer_toggle.tooltip_text = "Stack, select or hide hair pieces"
			box.add_child(layer_toggle)
			box.move_child(layer_toggle,4)
			box.move_child(layer_list,5)
			build_layers()
		if key in ["Eyes","Brows"]:
			var symmetry = CheckButton.new()
			symmetry.text = "Match left and right"
			symmetry.button_pressed = true
			symmetry.toggled.connect(func(on): linked = on)
			box.add_child(symmetry)
			box.move_child(symmetry,0)
	var pose = page("Pose")
	pose.add_child(label("Strike a pose",20))
	pose.add_child(label("Drag the customer’s handles, or fine-tune a joint below.",14,MUTED))
	for control in [host.animation_select,host.animation_button,host.control_rig_toggle,host.reset_pose_button]: move_control(control,pose)
	host.control_rig_toggle.text = "Show pose handles"
	adjustments(host.pose_adjustments,pose,"Pose")
	var paint_page = page("Paint")
	paint_page.add_child(label("A little color magic",20))
	paint_page.add_child(label("Paint directly on exposed skin. Right-drag turns your customer.",14,MUTED))
	var paint_column = host._paint_panel.get_child(0)
	move_control(paint_column,paint_page)
	reflow_tools(paint_column)
	var gallery = page("Saved customers")
	gallery_search = LineEdit.new()
	gallery_search.placeholder_text = "Find a saved customer…"
	gallery_search.text_changed.connect(filter_gallery)
	gallery.add_child(gallery_search)
	var save_actions = HFlowContainer.new()
	gallery.add_child(save_actions)
	save_actions.add_child(button("Save as new",save_as))
	save_actions.add_child(button("Duplicate",duplicate_doll))
	move_control(host.load_button,save_actions)
	host.load_button.text = "Load last saved"
	move_control(host.saved_customers,gallery)
	host.saved_customers.child_entered_tree.connect(func(_node): call_deferred("filter_gallery",gallery_search.text))
	filter_gallery("")

func adjustments(old: VBoxContainer, parent: VBoxContainer, key: String) -> void:
	var basic = VBoxContainer.new()
	parent.add_child(basic)
	var advanced = VBoxContainer.new()
	advanced.hide()
	var toggle = button("Fine-tune placement  +",func(): advanced.visible = not advanced.visible)
	toggle.toggle_mode = true
	parent.add_child(toggle)
	parent.add_child(advanced)
	var count = 0
	for row in old.get_children():
		var slider: HSlider
		var old_label: Label
		for child in row.get_children():
			if child is HSlider: slider = child
			if child is Label: old_label = child
		if slider == null:
			if row is HBoxContainer:
				var group = VBoxContainer.new()
				advanced.add_child(group)
				for item in row.get_children(): move_control(item,group)
			else: move_control(row,advanced)
			continue
		var adjustment_key = ""
		for candidate in host._adjustment_sliders:
			if host._adjustment_sliders[candidate] == slider: adjustment_key = candidate
		var text = friendly(old_label.text if old_label else adjustment_key)
		var is_basic = count < 3 and not ("yaw" in adjustment_key or "depth" in adjustment_key)
		if key == "Pose": is_basic = count < 2
		var box = VBoxContainer.new()
		box.set_meta("adjustment_key",adjustment_key)
		(basic if is_basic else advanced).add_child(box)
		var header = HBoxContainer.new()
		box.add_child(header)
		var l = label(text,14)
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		header.add_child(l)
		var value = SpinBox.new()
		value.min_value = slider.min_value
		value.max_value = slider.max_value
		value.step = slider.step
		value.value = slider.value
		value.custom_minimum_size.x = 88
		value.update_on_text_changed = false
		value.tooltip_text = text+" • type an exact value"
		header.add_child(value)
		var reset_value = slider.value
		if defaults.has(adjustment_key) and defaults[adjustment_key] is float: reset_value = defaults[adjustment_key]
		var reset = button("↺",func(): slider.value = reset_value)
		reset.tooltip_text = "Reset "+text
		header.add_child(reset)
		move_control(slider,box)
		slider.custom_minimum_size.y = 26
		value.value_changed.connect(func(v):
			if not syncing: slider.value = v
		)
		slider.value_changed.connect(func(v):
			value.set_value_no_signal(v)
			link_pair(adjustment_key,v)
		)
		spins[adjustment_key] = value
		count += 1
	toggle.visible = advanced.get_child_count() > 0

func friendly(text: String) -> String:
	return {"All":"Overall size","Scale":"Size","Scale X":"Width","Scale Y":"Height","Scale Z":"Depth","Pos X":"Move left / right","Pos Y":"Move up / down","Pos Z":"Move forward / back","Into / out":"Move forward / back","Left yaw":"Left turn","Right yaw":"Right turn","Fit":"Fit / size"}.get(text,text.replace("yaw","turn").replace("Yaw","Turn"))

func link_pair(key: String, value: float) -> void:
	if not linked or syncing: return
	var other = {"left_eye_yaw":"right_eye_yaw","right_eye_yaw":"left_eye_yaw","left_brow_yaw":"right_brow_yaw","right_brow_yaw":"left_brow_yaw"}.get(key,"")
	if other.is_empty() or not host._adjustment_sliders.has(other): return
	syncing = true
	host._adjustment_sliders[other].value = -value
	syncing = false

func style_grid(key: String, selector: OptionButton, parent: VBoxContainer) -> void:
	parent.add_child(label("CHOOSE A STYLE",11,MUTED))
	var search = LineEdit.new()
	search.placeholder_text = "Find a style…"
	search.visible = selector.item_count > 8
	parent.add_child(search)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	parent.add_child(grid)
	cards[key] = []
	for i in selector.item_count:
		var b = button("",select_style.bind(key,i))
		b.toggle_mode = true
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0,158)
		b.tooltip_text = selector.get_item_text(i)
		grid.add_child(b)
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,5)
		margin.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(margin)
		var stack = VBoxContainer.new()
		stack.mouse_filter = MOUSE_FILTER_IGNORE
		margin.add_child(stack)
		var picture = TextureRect.new()
		picture.custom_minimum_size.y = 108
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = MOUSE_FILTER_IGNORE
		stack.add_child(picture)
		var caption = label(selector.get_item_text(i),12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.max_lines_visible = 2
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stack.add_child(caption)
		cards[key].append({"button":b,"picture":picture,"label":caption,"index":i})
	var pagination = HBoxContainer.new()
	parent.add_child(pagination)
	var previous = button("←",catalog_turn.bind(key,-1))
	previous.tooltip_text = "Previous three styles"
	pagination.add_child(previous)
	var counter = label("",12,MUTED)
	counter.size_flags_horizontal = SIZE_EXPAND_FILL
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagination.add_child(counter)
	var next = button("→",catalog_turn.bind(key,1))
	next.tooltip_text = "Next three styles"
	pagination.add_child(next)
	catalog_arrows[key] = [previous,next]
	catalog_counters[key] = counter
	catalog_page[key] = 0
	catalog_query[key] = ""
	search.text_changed.connect(func(query):
		catalog_query[key] = query
		catalog_page[key] = 0
		filter_catalog(key)
		queue_thumbnails(key)
	)
	filter_catalog(key)
	selector.item_selected.connect(func(_i): update_cards())

func catalog_turn(key: String, direction: int) -> void:
	catalog_page[key] += direction
	filter_catalog(key)
	queue_thumbnails(key)

func filter_catalog(key: String) -> void:
	var matches = []
	for card in cards[key]:
		card.button.hide()
		if catalog_query[key].is_empty() or catalog_query[key].to_lower() in selectors[key].get_item_text(card.index).to_lower(): matches.append(card)
	var count = maxi(1, ceili(float(matches.size())/CATALOG_PAGE_SIZE))
	catalog_page[key] = posmod(catalog_page[key],count)
	for i in range(catalog_page[key]*CATALOG_PAGE_SIZE,mini(matches.size(),(catalog_page[key]+1)*CATALOG_PAGE_SIZE)): matches[i].button.show()
	for arrow in catalog_arrows[key]: arrow.disabled = count <= 1
	catalog_counters[key].text = "No matching styles" if matches.is_empty() else "%d / %d  ·  %d styles" % [catalog_page[key]+1,count,matches.size()]

func select_style(key: String, index: int) -> void:
	var selector = selectors[key]
	selector.select(index)
	selector.item_selected.emit(index)
	update_cards()
	checkpoint()
	host._set_status(selector.get_item_text(index)+" selected. Choose a color or adjust the fit below.")
	if key in ["Hair","Hats","Facial hair"]: call_deferred("frame_view","Face")

func update_cards() -> void:
	if voice_select != null: voice_select.select(1 if doll.customer_voice == "female" else 0)
	for key in cards:
		var selector = selectors[key]
		for card in cards[key]:
			card.button.set_pressed_no_signal(card.index == selector.selected)
			card.label.text = ("✓ " if card.index == selector.selected else "")+selector.get_item_text(card.index)

func palette(picker: ColorPickerButton, parent: VBoxContainer) -> void:
	var flow = HFlowContainer.new()
	parent.add_child(flow)
	for hex in ["fffaf1","382b35","b87052","f193a4","a78bcd","77bcb0","8bbbdc","e8c46c"]: swatch(flow,hex,picker)
	var row = HFlowContainer.new()
	parent.add_child(row)
	palette_rows.append({"row":row,"picker":picker})
	parent.add_child(button("♡ Favorite this color",func():
		var hex = picker.color.to_html(true)
		if not favorite_colors.has(hex): favorite_colors.push_front(hex)
		if favorite_colors.size() > 12: favorite_colors.resize(12)
		save_colors()
	))
	picker.color_changed.connect(func(color):
		var hex = color.to_html(true)
		recent_colors.erase(hex)
		recent_colors.push_front(hex)
		if recent_colors.size() > 6: recent_colors.resize(6)
	)
	picker.popup_closed.connect(save_colors)
	refresh_palettes()

func swatch(parent: Node, hex: String, picker: ColorPickerButton, favorite = false) -> void:
	var b = button("",func():
		picker.color = Color(hex)
		picker.color_changed.emit(picker.color)
		checkpoint()
	)
	b.custom_minimum_size = Vector2(30,30)
	b.tooltip_text = ("Favorite " if favorite else "Color ")+"#"+hex
	b.add_theme_stylebox_override("normal",style(Color(hex),Color("d8cddc"),15))
	parent.add_child(b)

func refresh_palettes() -> void:
	for spec in palette_rows:
		for child in spec.row.get_children():
			spec.row.remove_child(child)
			child.queue_free()
		for hex in favorite_colors: swatch(spec.row,hex,spec.picker,true)
		for hex in recent_colors:
			if not favorite_colors.has(hex): swatch(spec.row,hex,spec.picker)

func save_colors() -> void:
	preferences.set_value("colors","recent",recent_colors)
	preferences.set_value("colors","favorites",favorite_colors)
	preferences.save("user://doll_studio.cfg")
	refresh_palettes()

func reflow_tools(node: Node) -> void:
	for child in node.get_children():
		if child is HBoxContainer:
			var flow = VBoxContainer.new()
			node.add_child(flow)
			node.move_child(flow,child.get_index())
			for control in child.get_children(): move_control(control,flow)
			child.queue_free()
		else:
			if child is Control: child.custom_minimum_size.x = 0
			if child is Label:
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				child.add_theme_color_override("font_color",INK)
			reflow_tools(child)

func build_stage() -> void:
	# Give the creator its own world so game skies, lights and geometry cannot leak in.
	var old_world = host.get_node("World")
	host.remove_child(old_world)
	stage_view = SubViewport.new()
	stage_view.name = "World"
	stage_view.own_world_3d = true
	stage_view.size = Vector2i(size)
	stage_view.msaa_3d = Viewport.MSAA_2X
	stage_view.transparent_bg = true
	host.add_child(stage_view)
	for child in old_world.get_children(): child.reparent(stage_view,false)
	old_world.queue_free()
	var ground := stage_view.get_node_or_null("Ground")
	if ground != null:
		ground.queue_free()
	host.camera.current = true
	stage_backdrop = MeshInstance3D.new()
	stage_backdrop.name = "RadialBackdrop"
	var backdrop_mesh := QuadMesh.new()
	backdrop_mesh.size = Vector2(60.0, 40.0)
	stage_backdrop.mesh = backdrop_mesh
	stage_backdrop.position = Vector3(0, 0, -30.0)
	stage_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var backdrop_material := ShaderMaterial.new()
	var backdrop_shader := Shader.new()
	backdrop_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 center_color : source_color = vec4(0.29, 0.20, 0.44, 1.0);
uniform vec4 edge_color : source_color = vec4(0.09, 0.10, 0.26, 1.0);
uniform vec4 accent_color : source_color = vec4(0.93, 0.30, 0.47, 1.0);
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.54, 0.46);
	p.x *= 1.35;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float rays = (0.5 + 0.5 * cos(angle * 14.0)) * smoothstep(0.08, 0.82, radius) * 0.20;
	vec3 radial = mix(center_color.rgb, edge_color.rgb, smoothstep(0.04, 0.78, radius));
	ALBEDO = mix(radial, accent_color.rgb, rays);
}
"""
	backdrop_material.shader = backdrop_shader
	stage_backdrop.material_override = backdrop_material
	host.camera.add_child(stage_backdrop)
	stage_picture = TextureRect.new()
	stage_picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_picture.texture = stage_view.get_texture()
	stage_picture.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage_picture)
	move_child(stage_picture,0)
	var truck_path = "res://assets/menu_truck/burger_pals_truck.glb"
	if ResourceLoader.exists(truck_path):
		stage_truck = load(truck_path).instantiate()
		stage_truck.name = "BurgerPalsBackground"
		stage_view.add_child(stage_truck)
		for player in stage_truck.find_children("*","AnimationPlayer",true,false):
			player.stop()
		var truck_root = stage_truck.find_child("TruckRoot",true,false)
		if truck_root != null:
			truck_root.position = Vector3.ZERO
			truck_root.rotation = Vector3.ZERO
		stage_truck.scale = Vector3.ONE*0.845
		stage_truck.position = Vector3(-0.7,0,-4.0)
		stage_truck.rotation_degrees.y = -18
		# Static background: the optimized mesh is shared; no driving simulation.
		stage_truck.process_mode = Node.PROCESS_MODE_DISABLED
	stage_controls = panel()
	var tool_stack = VBoxContainer.new()
	stage_controls.add_child(tool_stack)
	stage_tools = HFlowContainer.new()
	tool_stack.add_child(stage_tools)
	for view in ["Front","Side","Back","Face","Full body"]: stage_tools.add_child(button(view,frame_view.bind(view)))
	var reset = button("↺",frame_view.bind("Reset"))
	reset.tooltip_text = "Reset view"
	stage_tools.add_child(reset)
	var background = button("◐",func():
		dark_backdrop = not dark_backdrop
		apply_backdrop()
	)
	background.tooltip_text = "Switch light / dark backdrop"
	stage_tools.add_child(background)
	hint = label("Drag to turn • Scroll to zoom • Click a feature to edit",12,MUTED)
	tool_stack.add_child(hint)

func open_fit_room() -> void:
	host._open_fit_room()
	host._fit_room_panel.theme = theme
	host._fit_room_panel.add_theme_stylebox_override("panel",style(PAPER))
	host.get_node("UI").move_child(host._fit_room_panel,host.get_node("UI").get_child_count()-1)

func apply_backdrop() -> void:
	var env = host.get_node("World/WorldEnvironment").environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffebdf")
	env.ambient_light_energy = 0.65
	host.get_node("World/KeyLight").light_energy = 0.85
	if stage_backdrop != null:
		var mat := stage_backdrop.material_override as ShaderMaterial
		if dark_backdrop:
			mat.set_shader_parameter("center_color", Color("49346f"))
			mat.set_shader_parameter("edge_color", Color("171a43"))
			mat.set_shader_parameter("accent_color", Color("ee4d78"))
		else:
			mat.set_shader_parameter("center_color", Color("ffe06b"))
			mat.set_shader_parameter("edge_color", Color("f45172"))
			mat.set_shader_parameter("accent_color", Color("2ab7ca"))
	host.camera.environment = env
	hint.add_theme_color_override("font_color",Color("e1d5ee") if dark_backdrop else MUTED)
	var fill = host.get_node("World/FillLight")
	fill.light_color = Color("e9deff")
	fill.light_energy = 0.35

func layout() -> void:
	if inspector == null: return
	var w = size.x
	var h = size.y
	var compact = w < 1050
	var nav_width = 68.0 if compact else 148.0
	var editor_width = clampf(w*0.33,310,420)
	top_bar.position = Vector2(12,12)
	top_bar.size = Vector2(w-24,62)
	nav.position = Vector2(12,86)
	nav.size = Vector2(nav_width,h-146)
	inspector.position = Vector2(w-editor_width-12,86)
	inspector.size = Vector2(editor_width,h-146)
	footer.position = Vector2(12,h-49)
	footer.size = Vector2(w-24,37)
	stage_rect = Rect2(nav.position.x+nav_width+12,86,w-nav_width-editor_width-60,h-146)
	if stage_view != null: stage_view.size = Vector2i(size)
	stage_controls.position = Vector2(stage_rect.position.x+4,h-177)
	stage_controls.size = Vector2(stage_rect.size.x-8,116)
	for key in nav_buttons: nav_buttons[key].text = nav_buttons[key].get_meta("icon") if compact else nav_buttons[key].get_meta("full")
	for control in utility_buttons: control.text = ("✦" if "Sculpt" in str(control.name) else "←") if compact else control.get_meta("full")
	if host._flat_paint_panel != null:
		host._flat_paint_panel.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
		host._flat_paint_panel.position = stage_rect.position+Vector2(4,72)
		host._flat_paint_panel.size = Vector2(stage_rect.size.x-8,stage_rect.size.y-175)
		fit_flat_canvas(host._flat_paint_panel)
	frame_view(framed_view)

func fit_flat_canvas(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.custom_minimum_size.x = 0
		if child is Label: child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fit_flat_canvas(child)

func center_camera() -> void:
	if host == null or stage_rect.size.x <= 0: return
	var height = 2.0*host._camera_distance*tan(deg_to_rad(host.camera.fov*0.5))
	host.camera.h_offset = (size.x*0.5-stage_rect.get_center().x)/size.y*height
	host.camera.v_offset = (stage_rect.get_center().y-size.y*0.5-52)/size.y*height

func head_bounds(character: Node3D) -> AABB:
	var head = character.feature_world_position("eyes")
	var bounds = AABB(head+Vector3(-0.64,-0.38,-0.55),Vector3(1.28,1.2,1.15))
	for property in ["_hair_root","_hat_root","_facial_hair_root"]:
		var part = character.get(property)
		if part == null: continue
		for mesh in part.find_children("*","MeshInstance3D",true,false):
			if mesh.is_visible_in_tree() and mesh.mesh != null:
				bounds = bounds.merge(mesh.global_transform*mesh.get_aabb())
	return bounds

func frame_view(view: String) -> void:
	if view in ["Front","Side","Back"]:
		host._orbit_y = {"Front":0.0,"Side":PI*0.5,"Back":PI}[view]
	else:
		framed_view = "Full body" if view == "Reset" else view
		host._orbit_y = 0.0
		var bounds = head_bounds(doll)
		if framed_view != "Face":
			bounds = bounds.merge(AABB(Vector3(-1.65,0,-0.5),Vector3(3.3,2.0,1.0)))
		var target = bounds.get_center()
		var available = Vector2(maxf(stage_rect.size.x-36,120),maxf(stage_rect.size.y-142,180))
		var height = maxf(bounds.size.y*size.y/available.y,bounds.size.x*size.y/available.x)*1.12
		host._camera_distance = height/(2.0*tan(deg_to_rad(host.camera.fov*0.5)))+bounds.size.z*0.5
		host._camera_pan = target-Vector3(0,1.05,0)
	host._orbit_x = -0.04
	host._apply_camera()
	center_camera()

func select_category(key: String) -> void:
	category = key
	for k in nav_buttons: nav_buttons[k].set_pressed_no_signal(k == key)
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	for sub in CATEGORIES[key]:
		var b = button(sub,select_section.bind(sub))
		b.toggle_mode = true
		tabs.add_child(b)
	title_label.text = key
	subtitle.text = {"Body":"Every great customer starts with you.","Face":"Tiny details. Big personality.","Hair":"Good hair days, on repeat.","Clothes":"Mix, match, make it yours.","Accessories":"The finishing touches.","Voice":"Give your customer a voice.","Pose":"Ready for your close-up?","Paint":"Make your mark.","Collection":"Your collection of originals."}[key]
	select_section(CATEGORIES[key][0])
	update_mode(key)
	if key != "Collection": frame_view("Face" if key in ["Face","Hair","Accessories"] else "Full body")

func select_section(key: String) -> void:
	# Starter shortcut also updates its visible tab.
	scroll_positions[section] = scroll.scroll_vertical
	section = key
	for k in pages: pages[k].visible = k == key
	for b in tabs.get_children(): b.set_pressed_no_signal(b.text == key)
	lock_button.set_pressed_no_signal(locks.get(key,false))
	lock_button.text = "Locked" if locks.get(key,false) else "Lock"
	call_deferred("restore_scroll",key)
	update_cards()
	queue_thumbnails(key)

func restore_scroll(key: String) -> void:
	if key == section: scroll.scroll_vertical = scroll_positions.get(key,0)

func update_mode(key: String) -> void:
	var painting = key == "Paint"
	if host._paint_mode != painting: host._toggle_paint_mode()
	host._paint_panel.hide()
	mode = "Paint" if painting else ("Pose" if key == "Pose" else "Dress")
	host.control_rig_toggle.set_pressed_no_signal(mode == "Pose")
	doll.set_control_rig_visible(mode == "Pose")
	var hotspots = host.get_node_or_null("UI/FeatureHotspots")
	if hotspots != null: hotspots.hide()
	hint.text = {"Dress":"Drag to turn • Scroll to zoom • Click a feature to edit","Pose":"Drag a pose handle • Fine-tune joints on the right","Paint":"Paint on skin • Right-drag to turn • Ctrl+Z to undo"}[mode]

func focus_feature(id: String) -> void:
	var map = {"hair":["Hair","Hair"],"eyes":["Face","Eyes"],"mouth":["Face","Mouth"],"shirt":["Clothes","Tops"],"pants":["Clothes","Bottoms"],"shoes":["Clothes","Shoes"]}
	if not map.has(id) or mode != "Dress": return
	select_category(map[id][0])
	select_section(map[id][1])
	host._set_status("Editing "+section+". Choose a style or make it your own.")

func toggle_lock() -> void:
	locks[section] = not locks.get(section,false)
	lock_button.text = "Locked" if locks[section] else "Lock"
	lock_button.set_pressed_no_signal(locks[section])

func randomize_section() -> void:
	if locks.get(section,false):
		host._set_status(section+" is locked. Unlock it to try something new.")
		return
	if selectors.has(section): select_style(section,randi_range(0,selectors[section].item_count-1))
	elif section == "Skin":
		var color = host.SKIN_TONES.pick_random()
		host.custom_color.color = color
		host.custom_color.color_changed.emit(color)
		checkpoint()
	elif section == "Starters": apply_starter(randi_range(0,3))
	elif section == "Pose":
		doll.set_pose_control("head_tilt",randf_range(-12,12))
		doll.set_pose_control("left_arm_raise",randf_range(0,60))
		doll.set_pose_control("right_arm_raise",randf_range(0,60))
		host._sync_adjustment_controls()
		checkpoint()
	else: host._set_status("Choose a style category to try a surprise.")

func belongs(key: String, sub: String) -> bool:
	if sub == "Eyes": return (key.begins_with("eye_") and not key.begins_with("eye_specular_")) or key in ["left_eye_yaw","right_eye_yaw"]
	if sub == "Brows": return key.begins_with("brow_") or key in ["left_brow_yaw","right_brow_yaw"]
	if sub == "Opening": return key.begins_with("eyelid_") or key.begins_with("lash_")
	if sub == "Hair" and key == "extra_hairs": return true
	return PREFIX.has(sub) and key.begins_with(PREFIX[sub])

func reset_section() -> void:
	if section == "Pose": host._reset_character_pose()
	elif section == "Paint":
		host._clear_skin_paint()
		paint_changed = true
	else:
		doll.begin_appearance_batch()
		for key in defaults:
			if belongs(key,section): doll.set(key,defaults[key])
		if section == "Hair" and doll.get("extra_hairs") != null:
			doll.extra_hairs = []
			host._hair_layer_index = 0
		doll.end_appearance_batch()
		host._refresh_appearance_controls()
	checkpoint()
	host._set_status(section+" restored. Undo is here if you change your mind.")

func build_starters(parent: VBoxContainer) -> void:
	parent.add_child(label("Meet your starting lineup",20))
	parent.add_child(label("Pick a whole look, then make every detail your own. Locked sections stay yours.",14,MUTED))
	var names = ["Peach picnic","Lilac daydream","Mint explorer","Midnight sparkle"]
	var descriptions = ["Warm blush · soft pastels · weekend energy","Lavender layers · a sweet little smile","Fresh greens · casual classics · curious spirit","Deep plum · golden accents · main-character mood"]
	for i in 4:
		var b = button(names[i]+"\n"+descriptions[i],apply_starter.bind(i))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 86
		parent.add_child(b)

func apply_starter(index: int) -> void:
	var before = capture(false)
	var colors = [["f2c6a0","6d3828","f193a4","87adbb"],["cf895f","382b35","b6a0cf","625c88"],["925035","35231d","8dc4ac","dbc99c"],["d99a83","382b35","625076","393447"]][index]
	doll.begin_appearance_batch()
	for key in defaults: doll.set(key,defaults[key])
	if not locks.get("Paint",false):
		doll.clear_skin_paint()
		paint_changed = true
	doll.skin_color = Color(colors[0])
	doll.hair_color = Color(colors[1])
	doll.top_color = Color(colors[2])
	doll.bottom_color = Color(colors[3])
	doll.cheek_style = 1
	doll.cheek_color = Color(0.94,0.42,0.47,0.45)
	doll.nose_color = Color(colors[0]).darkened(0.08)
	doll.ear_color = Color(colors[0])
	doll.hair_style = [1,4,1,4][index]
	doll.hair_scale = 1.3
	doll.hair_offset = Vector3(0,0.03 if index in [0,2] else 0.45,0)
	doll.top_style = mini(1+index,selectors["Tops"].item_count-1)
	doll.bottom_style = mini(1+index%2,selectors["Bottoms"].item_count-1)
	doll.shoe_style = mini(1+index%3,selectors["Shoes"].item_count-1)
	if doll.get("extra_hairs") != null: doll.extra_hairs = []
	if not locks.get("Pose",false):
		doll.reset_pose_controls()
		doll.set_pose_control("left_arm_raise", -65.0)
		doll.set_pose_control("right_arm_raise", -65.0)
	for locked in locks:
		if locks[locked]:
			for key in before.properties:
				if belongs(key,locked): doll.set(key,before.properties[key])
	doll.end_appearance_batch()
	host._refresh_appearance_controls()
	checkpoint()
	host._set_status("Your new look is ready. Add your own twist!")

func build_layers() -> void:
	if layer_toggle != null: layer_toggle.text = "Hair layers · %d  ▾" % doll.hair_layer_count()
	if layer_list == null: return
	for child in layer_list.get_children():
		layer_list.remove_child(child)
		child.queue_free()
	layer_list.add_child(label("YOUR HAIR LAYERS",11,MUTED))
	for i in doll.hair_layer_count():
		var layer = doll.get_hair_layer(i)
		var row = HBoxContainer.new()
		layer_list.add_child(row)
		var name_text = ("Base · " if i == 0 else "Layer %d · " % (i+1))+selectors["Hair"].get_item_text(int(layer.style))
		var pick = button(name_text,func():
			host._on_hair_layer_picked(i)
			build_layers()
			update_cards()
		)
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pick.size_flags_horizontal = SIZE_EXPAND_FILL
		pick.toggle_mode = true
		pick.button_pressed = host._hair_layer_index == i
		row.add_child(pick)
		var layer_picture = TextureRect.new()
		layer_picture.custom_minimum_size = Vector2(38,38)
		layer_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var cache_key = "Hair:"+str(int(layer.style))
		if thumbnail_cache.has(cache_key): layer_picture.texture = thumbnail_cache[cache_key]
		row.add_child(layer_picture)
		row.move_child(layer_picture,0)
		var visibility = button("●" if layer.get("visible",true) else "○",func():
			doll.set_hair_layer_visible(i,not bool(doll.get_hair_layer(i).get("visible",true)))
			checkpoint()
			build_layers()
		)
		visibility.tooltip_text = "Show / hide this hair layer"
		row.add_child(visibility)
		if i > 0:
			var remove = button("×",func():
				host._on_hair_layer_picked(i)
				host._on_remove_hair_layer()
				hidden_layers.clear()
				checkpoint()
				build_layers()
			)
			remove.tooltip_text = "Remove layer • Undo restores it"
			row.add_child(remove)
	var add = button("+ Add a hair layer",func():
		host._on_add_hair_layer()
		checkpoint()
		build_layers()
	)
	add.disabled = host._hair_add_btn.disabled
	layer_list.add_child(add)

func filter_gallery(query: String) -> void:
	for card in host.saved_customers.get_children():
		if card is Button:
			card.visible = query.is_empty() or query.to_lower() in card.text.to_lower()
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.custom_minimum_size.x = 0
	if host.saved_customers.get_child_count() == 0: host._set_status("Your collection starts here. Name your customer and choose Save customer.")

func save_as() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Save a new customer"
	dialog.ok_button_text = "Save new customer"
	dialog.dialog_text = "Give this version a new name. Your original stays in the collection."
	var input = LineEdit.new()
	input.text = host.character_name.text+" 2"
	input.max_length = 48
	dialog.add_child(input)
	add_child(dialog)
	dialog.register_text_enter(input)
	dialog.confirmed.connect(func():
		var safe = host._safe_file_name(input.text.strip_edges())
		if input.text.strip_edges().is_empty() or FileAccess.file_exists("user://characters/%s.json" % safe):
			host._set_status("Choose a new, unused customer name for a separate copy.",true)
		else:
			host.character_name.text = input.text.strip_edges()
			host._save_character()
			mark_saved()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(430,180))
	input.grab_focus()
	input.select_all()

func duplicate_doll() -> void:
	var original = host.character_name.text
	var i = 2
	var candidate = original+" "+str(i)
	while FileAccess.file_exists("user://characters/%s.json" % host._safe_file_name(candidate)):
		i += 1
		candidate = original+" "+str(i)
	host.character_name.text = candidate
	host._save_character()
	mark_saved()

func capture(include_paint = true) -> Dictionary:
	var properties = {}
	for key in defaults:
		var value = doll.get(key)
		properties[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	if doll.get("extra_hairs") != null: properties["extra_hairs"] = doll.extra_hairs.duplicate(true)
	var data = {"properties":properties,"name":host.character_name.text,"pose":doll.get_pose_controls().duplicate(true),"rig":doll.get_control_rig_targets().duplicate(true)}
	if include_paint:
		data["paint"] = doll.get_skin_paint_snapshot_png() if doll.has_skin_paint() else PackedByteArray()
		data["paint_marks"] = doll.has_skin_paint()
	return data

func signature(data: Dictionary) -> String:
	var copy = data.duplicate(false)
	copy.erase("paint")
	copy.erase("paint_marks")
	return var_to_str(copy)

func initialize_history() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	layout()
	var first = capture()
	history = [first]
	last_signature = signature(first)
	saved_signature = var_to_str(first) if FileAccess.file_exists("user://last_character.json") else ""
	update_history_buttons()
	frame_view("Full body")

func checkpoint() -> void:
	if syncing or history.is_empty(): return
	var data = capture(false)
	var sig = signature(data)
	if sig == last_signature and not paint_changed: return
	if paint_changed:
		data["paint"] = doll.get_skin_paint_snapshot_png() if doll.has_skin_paint() else PackedByteArray()
		data["paint_marks"] = doll.has_skin_paint()
	else:
		data["paint"] = history.back().get("paint",PackedByteArray())
		data["paint_marks"] = history.back().get("paint_marks",false)
	paint_changed = false
	history.append(data)
	if history.size() > 40: history.pop_front()
	future.clear()
	last_signature = sig
	update_cards()
	update_history_buttons()

func paint_checkpoint() -> void:
	paint_changed = true
	call_deferred("checkpoint")

func undo() -> void:
	checkpoint()
	if history.size() < 2: return
	future.append(history.pop_back())
	restore(history.back())
	host._set_status("Undone. Try another idea!")

func redo() -> void:
	if future.is_empty(): return
	var data = future.pop_back()
	history.append(data)
	restore(data)
	host._set_status("Redone.")

func restore(data: Dictionary) -> void:
	syncing = true
	doll.stop_preview_animation()
	doll.begin_appearance_batch()
	for key in data.properties: doll.set(key,data.properties[key])
	doll.end_appearance_batch()
	doll.load_pose_controls(data.pose)
	doll.load_control_rig_targets(data.rig)
	doll.restore_skin_paint_snapshot_png(data.get("paint",PackedByteArray()),data.get("paint_marks",false))
	host.character_name.text = data.name
	if host.get("_hair_layer_index") != null: host._hair_layer_index = 0
	hidden_layers.clear()
	host._reset_paint_history()
	host._refresh_appearance_controls()
	syncing = false
	paint_changed = false
	last_signature = signature(capture(false))
	update_cards()
	build_layers()
	update_history_buttons()

func mark_saved() -> void:
	if not host.status_label.text.begins_with("Saved "): return
	checkpoint()
	saved_signature = var_to_str(capture())
	update_history_buttons()

func loaded() -> void:
	paint_changed = true
	checkpoint()
	saved_signature = var_to_str(capture())
	update_history_buttons()
	update_cards()
	build_layers()

func update_history_buttons() -> void:
	undo_button.disabled = history.size() < 2
	redo_button.disabled = future.is_empty()
	var dirty = not history.is_empty() and var_to_str(history.back()) != saved_signature
	saved_label.text = "● Unsaved changes" if dirty else "✓ Saved"
	saved_label.add_theme_color_override("font_color",Color("f1b1a6") if dirty else Color("91cbb2"))

func _process(delta: float) -> void:
	if host == null or history.is_empty(): return
	poll_time += delta
	if poll_time < 0.4: return
	poll_time = 0.0
	var focus = get_viewport().gui_get_focus_owner()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not doll.is_control_rig_dragging() and not doll.is_preview_animation_playing() and not focus is LineEdit: checkpoint()
	for key in spins:
		if host._adjustment_sliders.has(key) and not spins[key].get_line_edit().has_focus(): spins[key].set_value_no_signal(host._adjustment_sliders[key].value)
	if layer_list != null:
		var sig = var_to_str(doll.extra_hairs)+str(doll.hair_style)+str(doll.hair_visible)+str(host._hair_layer_index)
		if sig != last_layers:
			last_layers = sig
			build_layers()
	if host._paint_mode != (mode == "Paint"): select_category("Paint" if host._paint_mode else "Body")
	host._paint_panel.hide()
	host.get_node("UI/Sidebar").hide()
	host.get_node("UI/ModulesPanel").hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit: return
		if event.keycode == KEY_Z:
			if event.shift_pressed: redo()
			else: undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			redo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S:
			host._save_character()
			mark_saved()
			get_viewport().set_input_as_handled()

func queue_thumbnails(key: String) -> void:
	if not cards.has(key): return
	thumbnail_queue.clear()
	for card in cards[key]:
		var cache_key = key+":"+str(card.index)
		if thumbnail_cache.has(cache_key): card.picture.texture = thumbnail_cache[cache_key]
		elif card.picture.texture == null and card.button.visible: thumbnail_queue.append({"key":key,"index":card.index,"picture":card.picture})
	if not thumbnail_busy: call_deferred("render_thumbnails")

func make_thumbnail_stage() -> void:
	thumbnail_view = SubViewport.new()
	thumbnail_view.size = Vector2i(320,320)
	thumbnail_view.msaa_3d = Viewport.MSAA_2X
	thumbnail_view.own_world_3d = true
	thumbnail_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(thumbnail_view)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("383441")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	thumbnail_view.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.1
	thumbnail_view.add_child(light)
	thumbnail_doll = load("res://scenes/character_creator/modular_character_base.tscn" if ResourceLoader.exists("res://scenes/character_creator/modular_character_base.tscn") else "res://scenes/modular_character_base.tscn").instantiate()
	thumbnail_doll.name = "CatalogDoll"
	thumbnail_view.add_child(thumbnail_doll)
	thumbnail_doll.set_control_rig_visible(false)
	thumbnail_doll.reset_pose_controls()
	thumbnail_doll.clear_skin_paint()
	thumbnail_camera = Camera3D.new()
	thumbnail_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	thumbnail_view.add_child(thumbnail_camera)
	thumbnail_camera.current = true

func render_thumbnails() -> void:
	if thumbnail_busy or DisplayServer.get_name() == "headless": return
	thumbnail_busy = true
	if thumbnail_view == null: make_thumbnail_stage()
	while not thumbnail_queue.is_empty() and is_inside_tree():
		var job = thumbnail_queue.pop_front()
		if not is_instance_valid(job.picture) or not job.picture.is_visible_in_tree(): continue
		var cache_key = job.key+":"+str(job.index)
		if thumbnail_cache.has(cache_key):
			job.picture.texture = thumbnail_cache[cache_key]
			continue
		thumbnail_doll.begin_appearance_batch()
		for property in defaults: thumbnail_doll.set(property,defaults[property])
		if thumbnail_doll.get("extra_hairs") != null: thumbnail_doll.extra_hairs = []
		thumbnail_doll.skin_color = Color("e6aa7a")
		thumbnail_doll.nose_color = Color("ce9070")
		thumbnail_doll.hair_scale = 1.3
		thumbnail_doll.hair_offset = Vector3(0,0.3,0)
		thumbnail_doll.top_color = Color("92bdb1")
		thumbnail_doll.bottom_color = Color("9297c8")
		thumbnail_doll.set(STYLE_PROPERTIES[job.key],job.index)
		thumbnail_doll.end_appearance_batch()
		# Wait for the new skeleton attachment transforms before measuring the item.
		await get_tree().process_frame
		var bounds = head_bounds(thumbnail_doll)
		var target = bounds.get_center()
		var frame_size = maxf(bounds.size.x,bounds.size.y)*1.12
		var distance = 6.0
		if job.key in ["Tops","Graphics"]:
			target = Vector3(0,1.35,0)
			frame_size = 2.35
		elif job.key == "Bottoms":
			target = Vector3(0,0.65,0)
			frame_size = 1.6
		elif job.key == "Shoes":
			target = Vector3(0,0.17,0)
			frame_size = 0.95
		thumbnail_camera.size = frame_size
		thumbnail_camera.position = target+Vector3(0,0,distance)
		thumbnail_camera.look_at(target)
		await get_tree().process_frame
		thumbnail_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		var img = thumbnail_view.get_texture().get_image()
		if img != null and not img.is_empty():
			var tex = ImageTexture.create_from_image(img)
			thumbnail_cache[cache_key] = tex
			if is_instance_valid(job.picture): job.picture.texture = tex
			if job.key == "Hair": build_layers()
		await get_tree().process_frame
	thumbnail_busy = false

func build_voice_page(parent: VBoxContainer) -> void:
	parent.add_child(label("Customer voice",20))
	parent.add_child(label("Choose how this customer talks and enjoys a burger.",14,MUTED))
	voice_select = OptionButton.new()
	voice_select.name = "CustomerVoiceSelect"
	voice_select.add_item("Male")
	voice_select.add_item("Female")
	voice_select.select(1 if doll.customer_voice == "female" else 0)
	voice_select.item_selected.connect(func(index):
		doll.customer_voice = "female" if index == 1 else "male"
		checkpoint()
		host._set_status("Voice selected. Save customer to keep it.")
	)
	parent.add_child(voice_select)
	parent.add_child(button("Preview eating - nom nom",preview_customer_voice.bind(true)))
	parent.add_child(button("Preview talking - wa wa",preview_customer_voice.bind(false)))
	voice_preview = AudioStreamPlayer.new()
	voice_preview.name = "CustomerVoicePreview"
	voice_preview.volume_db = -5.0
	add_child(voice_preview)

func preview_customer_voice(eating: bool) -> void:
	voice_preview.stop()
	voice_preview.stream = preload("res://scripts/customer_voice.gd").stream(doll.customer_voice,eating)
	voice_preview.pitch_scale = 1.0 if eating or doll.customer_voice == "female" else 1.7
	voice_preview.play()
