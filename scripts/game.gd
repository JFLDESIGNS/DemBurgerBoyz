## 3D food-truck burger game - cook from inside, looking out the window.
extends Node3D

const GRILL_SLOTS := 4
const STATION_COUNT := 4
const MAX_HELD := 4
const MAX_CUSTOMERS := 4
const DAY_LENGTH := 120.0
const PattyScript := preload("res://scripts/patty.gd")
const CustomerScript := preload("res://scripts/customer.gd")
const GameDataScript := preload("res://scripts/game_data.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")
## Hotkeys 1-9-0 map to these toppings on the active station.
const INGREDIENT_HOTKEYS: Array[String] = [
	"bun_bottom", "bun_top",
	"cheese", "lettuce", "tomato", "onion", "pickle", "bacon",
	"ketchup", "mustard",
]
const HOTKEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

@onready var camera: Camera3D = %Camera3D
@onready var world: Node3D = %World
@onready var grill_root: Node3D = %Grill
@onready var customers_root: Node3D = %Customers
@onready var patties_root: Node3D = %Patties

@onready var hud_money: Label = %MoneyLabel
@onready var hud_combo: Label = %ComboLabel
@onready var hud_day: Label = %DayLabel
@onready var hud_hint: Label = %HintLabel
@onready var ticket_box: HBoxContainer = %TicketBox
@onready var ingredient_bar: HBoxContainer = %IngredientBar
@onready var stations_row: HBoxContainer = %StationsRow
@onready var held_row: HBoxContainer = %HeldRow
@onready var flash_label: Label = %FlashLabel
@onready var start_overlay: ColorRect = %StartOverlay
@onready var start_btn: Button = %StartButton
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_label: Label = %GameOverLabel
@onready var restart_btn: Button = %RestartButton
@onready var grill_power_row: HBoxContainer = %GrillPowerRow
@onready var ingredient_legend: VBoxContainer = %IngredientLegend

var money: int = 0
var combo: int = 0
var day: int = 1
var day_time: float = DAY_LENGTH
var playing: bool = false
var difficulty: float = 0.0
var spawn_timer: float = 2.0
var customers: Array = []
var grill: Array = []
var spatula_patty = null ## one patty on the spatula at a time
var stations: Array = [] ## each: {items, patty, panel, preview, title, plate}
var active_station: int = 0
var selected_customer = null
var tickets: Dictionary = {}
var total_served: int = 0
var perfect_serves: int = 0
var rush_mode: bool = false
var slot_positions: Array[Vector3] = []
var slot_areas: Array = []
var spatula_cursor: Control = null
var spatula_icon: TextureRect = null
var spatula_patty_icon: TextureRect = null
var spatula_3d: Node3D = null
var grill_powered: Array = [] ## bool per grill slot
var grill_glow_meshes: Array = []
var grill_pad_mats: Array = []
var grill_power_labels: Array = []
var grill_heat_lights: Array = []
var grill_power_btn_mats: Array = []
var grill_ui_buttons: Array = []
var grill_ignore_pad_until: float = 0.0


func _ready() -> void:
	randomize()
	grill.resize(GRILL_SLOTS)
	grill.fill(null)
	grill_powered.resize(GRILL_SLOTS)
	grill_powered.fill(false)
	_setup_stations_data()
	_build_3d_world()
	_build_grill_power_ui()
	_build_station_ui()
	_build_ingredient_legend()
	_build_ingredient_buttons()
	## Empty chrome passes through; stations + toppings stay clickable.
	var bottom := get_node_or_null("UI/Root/BottomUI")
	if bottom:
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_row.mouse_filter = Control.MOUSE_FILTER_STOP
	ingredient_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	stations_row.mouse_filter = Control.MOUSE_FILTER_STOP
	grill_power_row.mouse_filter = Control.MOUSE_FILTER_STOP
	ingredient_legend.mouse_filter = Control.MOUSE_FILTER_STOP
	start_btn.pressed.connect(_start_game)
	restart_btn.pressed.connect(_restart)
	game_over_panel.visible = false
	flash_label.visible = false
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()


func _setup_stations_data() -> void:
	stations.clear()
	for i in STATION_COUNT:
		stations.append({
			"items": [] as Array[String],
			"patties": [],
			"panel": null,
			"preview": null,
			"title": null,
			"plate": null,
			"drop_hint": null,
			"drop_btn": null,
		})


func _start_game() -> void:
	start_overlay.visible = false
	playing = true
	money = 0
	combo = 0
	day = 1
	day_time = DAY_LENGTH
	difficulty = 0.0
	total_served = 0
	perfect_serves = 0
	spawn_timer = _first_customer_delay()
	active_station = 0
	_clear_all_patty()
	_clear_spatula()
	_clear_all_stations()
	_clear_customers()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_flash("Turn a grill ON, cook, flip, then scoop!", Color("FFEB3B"))


func _restart() -> void:
	game_over_panel.visible = false
	start_overlay.visible = false
	playing = true
	combo = 0
	day_time = DAY_LENGTH
	difficulty = 0.0
	total_served = 0
	perfect_serves = 0
	spawn_timer = _first_customer_delay()
	active_station = 0
	_clear_all_patty()
	_clear_spatula()
	_clear_all_stations()
	_clear_customers()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_flash("Day %d - it gets busier!" % day, Color("FFEB3B"))


func _process(delta: float) -> void:
	if not playing:
		return
	## Sync grill heat to patties (only cook while powered on).
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p != null and is_instance_valid(p):
			p.heating = grill_powered[i]

	day_time -= delta
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	var day_boost := clampf((day - 1) * 0.22, 0.0, 0.85)
	difficulty = minf(1.0, day_progress * (0.25 if day == 1 else 0.55) + day_boost)

	spawn_timer -= delta
	var cap := _customer_cap()
	if spawn_timer <= 0.0 and customers.size() < cap:
		_spawn_customer()
		spawn_timer = _next_spawn_delay()

	rush_mode = customers.size() >= maxi(2, cap - 1) and day >= 2
	if rush_mode and int(Time.get_ticks_msec() / 400) % 2 == 0:
		hud_hint.text = "RUSH HOUR - keep flipping!"
	elif spatula_patty != null:
		hud_hint.text = "Holding patty - drop on a station, build, click ticket, Serve"
	elif day == 1 and day_progress < 0.4:
		hud_hint.text = "Build on any station -> click ticket -> Serve / Enter"
	else:
		hud_hint.text = "Click ticket to choose order, Serve from any station"

	if day_time <= 0.0:
		_end_day()
	_update_hud()

func _first_customer_delay() -> float:
	match day:
		1: return 10.0
		2: return 5.0
		3: return 3.0
		_: return 1.5


func _customer_cap() -> int:
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	if day == 1:
		return 1 if day_progress < 0.35 else 2
	if day == 2:
		return 2 if day_progress < 0.45 else 3
	if day == 3:
		return 3 if day_progress < 0.4 else 4
	return MAX_CUSTOMERS


func _next_spawn_delay() -> float:
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	match day:
		1: return lerpf(16.0, 9.0, day_progress) + randf_range(0.0, 4.0)
		2: return lerpf(10.0, 5.5, day_progress) + randf_range(0.0, 2.5)
		3: return lerpf(7.0, 3.8, day_progress) + randf_range(0.0, 1.8)
		_: return lerpf(5.0, 2.4, minf(1.0, day_progress + (day - 4) * 0.1)) + randf_range(0.0, 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("new_patty"):
		_spawn_patty_on_grill()
	elif event.is_action_pressed("serve") or _is_enter_pressed(event):
		_on_serve()
	elif event.is_action_pressed("trash"):
		_clear_active_station()
	elif event is InputEventKey and event.pressed and not event.echo:
		var ing := _ingredient_from_hotkey(event.keycode)
		if ing != "":
			_add_ingredient(ing)
			return
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if spatula_patty != null:
				var station_idx := _station_index_at(get_viewport().get_mouse_position())
				if station_idx >= 0:
					_drop_spatula_on_station(station_idx)
					return
			## Left click: flip / scoop only - never spawn a patty.
			_try_grill_raycast(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			## Right click: add a raw patty to a powered grill pad.
			_try_grill_raycast(event.position, true)



func _input(event: InputEvent) -> void:
	if not playing:
		return
	## Enter always serves the active station burger.
	if _is_enter_pressed(event):
		_on_serve()
		get_viewport().set_input_as_handled()
		return
	## Number keys lay toppings on the selected station.
	if event is InputEventKey and event.pressed and not event.echo:
		var ing := _ingredient_from_hotkey(event.keycode)
		if ing != "":
			_add_ingredient(ing)
			get_viewport().set_input_as_handled()
			return
	## Mouse drop while holding a patty.
	if spatula_patty == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var station_idx := _station_index_at(get_viewport().get_mouse_position())
		if station_idx >= 0:
			_drop_spatula_on_station(station_idx)
			get_viewport().set_input_as_handled()


func _is_enter_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _ingredient_from_hotkey(keycode: Key) -> String:
	match keycode:
		KEY_1, KEY_KP_1:
			return INGREDIENT_HOTKEYS[0]
		KEY_2, KEY_KP_2:
			return INGREDIENT_HOTKEYS[1]
		KEY_3, KEY_KP_3:
			return INGREDIENT_HOTKEYS[2]
		KEY_4, KEY_KP_4:
			return INGREDIENT_HOTKEYS[3]
		KEY_5, KEY_KP_5:
			return INGREDIENT_HOTKEYS[4]
		KEY_6, KEY_KP_6:
			return INGREDIENT_HOTKEYS[5]
		KEY_7, KEY_KP_7:
			return INGREDIENT_HOTKEYS[6]
		KEY_8, KEY_KP_8:
			return INGREDIENT_HOTKEYS[7]
		KEY_9, KEY_KP_9:
			return INGREDIENT_HOTKEYS[8]
		KEY_0, KEY_KP_0:
			return INGREDIENT_HOTKEYS[9]
	return ""


func _station_index_at(screen_pos: Vector2) -> int:
	for i in STATION_COUNT:
		var drop_btn: Control = stations[i].get("drop_btn", null)
		if drop_btn != null and is_instance_valid(drop_btn) and drop_btn.visible and drop_btn.get_global_rect().has_point(screen_pos):
			return i
		var plate: Control = stations[i].get("plate", null)
		if plate != null and is_instance_valid(plate) and plate.get_global_rect().has_point(screen_pos):
			return i
		var panel: Control = stations[i].get("panel", null)
		if panel != null and is_instance_valid(panel) and panel.get_global_rect().has_point(screen_pos):
			var r: Rect2 = panel.get_global_rect()
			if screen_pos.y < r.position.y + r.size.y * 0.72:
				return i
	return -1


func _end_day() -> void:
	playing = false
	day += 1
	game_over_label.text = "Day %d over!\n\nServed: %d\nPerfect: %d\nWallet: $%d\n\nReady for the next rush?" % [
		day - 1, total_served, perfect_serves, money
	]
	restart_btn.text = "Start Day %d" % day
	game_over_panel.visible = true


# --- 3D world: inside truck, looking out ------------------------------------

func _build_3d_world() -> void:
	camera.position = Vector3(0.0, 1.65, -1.7)
	camera.look_at(Vector3(0.0, 1.15, 0.35), Vector3.UP)
	camera.fov = 60.0

	_add_box(world, Vector3(16, 0.05, 10), Vector3(0, -0.02, 4.0), Color("3A3A3A"))
	_build_checkered_floor()

	# Truck shell
	_add_box(world, Vector3(6.5, 0.12, 4.0), Vector3(0, 0.06, -0.4), Color("CFD8DC"))
	_add_box(world, Vector3(0.22, 2.7, 4.0), Vector3(-3.25, 1.35, -0.4), Color("90A4AE"))
	_add_box(world, Vector3(0.22, 2.7, 4.0), Vector3(3.25, 1.35, -0.4), Color("90A4AE"))
	_add_box(world, Vector3(6.5, 2.7, 0.22), Vector3(0, 1.35, -2.35), Color("78909C"))
	_add_box(world, Vector3(6.5, 0.16, 4.2), Vector3(0, 2.72, -0.4), Color("607D8B"))

	# Front wall around window
	_add_box(world, Vector3(1.15, 2.7, 0.2), Vector3(-2.95, 1.35, 1.35), Color("78909C"))
	_add_box(world, Vector3(1.15, 2.7, 0.2), Vector3(2.95, 1.35, 1.35), Color("78909C"))
	_add_box(world, Vector3(4.8, 0.55, 0.2), Vector3(0, 2.45, 1.35), Color("607D8B"))
	_add_box(world, Vector3(4.8, 0.7, 0.2), Vector3(0, 0.55, 1.35), Color("546E7A"))
	_add_box(world, Vector3(4.9, 0.12, 0.18), Vector3(0, 2.12, 1.38), Color("ECEFF1"))
	_add_box(world, Vector3(4.9, 0.12, 0.18), Vector3(0, 0.95, 1.38), Color("ECEFF1"))
	_add_box(world, Vector3(0.12, 1.3, 0.18), Vector3(-2.4, 1.55, 1.38), Color("ECEFF1"))
	_add_box(world, Vector3(0.12, 1.3, 0.18), Vector3(2.4, 1.55, 1.38), Color("ECEFF1"))
	_add_box(world, Vector3(4.8, 0.18, 0.65), Vector3(0, 0.88, 1.1), Color("B0BEC5"))

	# Raised metal flat-top (high enough to sit above the bottom UI)
	_add_box(world, Vector3(3.5, 0.95, 1.4), Vector3(0, 0.48, 0.0), Color("546E7A"))
	var shelf := _add_box(grill_root, Vector3(3.3, 0.1, 1.3), Vector3(0, 1.0, 0.0), Color("A8B4BE"))
	shelf.material_override.metallic = 1.0
	shelf.material_override.roughness = 0.12
	shelf.material_override.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	shelf.material_override.specular_mode = BaseMaterial3D.SPECULAR_TOON

	var griddle := _add_box(grill_root, Vector3(3.0, 0.07, 1.0), Vector3(0, 1.1, -0.05), Color("8A959E"))
	griddle.material_override.metallic = 1.0
	griddle.material_override.roughness = 0.06
	griddle.material_override.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	griddle.material_override.specular_mode = BaseMaterial3D.SPECULAR_TOON
	griddle.material_override.emission_enabled = true
	griddle.material_override.emission = Color(0.7, 0.75, 0.82)
	griddle.material_override.emission_energy_multiplier = 0.2

	## 4 metal grill pads + power buttons facing the cook
	slot_positions.clear()
	slot_areas.clear()
	grill_glow_meshes.clear()
	grill_pad_mats.clear()
	grill_power_labels.clear()
	grill_heat_lights.clear()
	grill_power_btn_mats.clear()
	var spacing := 0.72
	## Camera faces +Z, so world +X is screen-left. Put Grill 1 on the left.
	var start_x := spacing * 1.5
	for i in GRILL_SLOTS:
		var pos := Vector3(start_x - i * spacing, 1.18, -0.05)
		slot_positions.append(pos)
		_make_grill_slot(i, pos)

	## Resting spatula on the side
	spatula_3d = Node3D.new()
	spatula_3d.position = Vector3(1.75, 1.15, 0.1)
	spatula_3d.rotation_degrees = Vector3(0, -25, 8)
	var blade := _add_box(spatula_3d, Vector3(0.45, 0.02, 0.28), Vector3(0, 0, 0), Color("CFD8DC"))
	blade.material_override.metallic = 0.95
	blade.material_override.roughness = 0.2
	blade.material_override.specular_mode = BaseMaterial3D.SPECULAR_TOON
	_add_box(spatula_3d, Vector3(0.06, 0.04, 0.55), Vector3(0, 0.02, -0.35), Color("5D4037"))
	grill_root.add_child(spatula_3d)

	_add_box(world, Vector3(7, 0.04, 2.4), Vector3(0, 0.02, 2.9), Color("455A64"))
	for i in 3:
		_add_box(world, Vector3(0.35, 0.9, 0.35), Vector3(-2.5 + i * 2.2, 0.45, 4.2), Color("6D4C41"))

	var fill := OmniLight3D.new()
	fill.light_color = Color("FFE0B2")
	fill.light_energy = 2.2
	fill.omni_range = 10.0
	fill.position = Vector3(0, 2.2, 0.2)
	world.add_child(fill)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 20, 0)
	world.add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5B8DEF")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("DDE7F5")
	env.ambient_light_energy = 0.9
	env_node.environment = env
	add_child(env_node)


func _build_grill_power_ui() -> void:
	for child in grill_power_row.get_children():
		child.queue_free()
	grill_ui_buttons.clear()
	var title := Label.new()
	title.text = "GRILLS:"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("FFCC80"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	grill_power_row.add_child(title)
	for i in GRILL_SLOTS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 36)
		btn.add_theme_font_size_override("font_size", 14)
		var idx := i
		btn.pressed.connect(func(): _toggle_grill_power(idx))
		grill_power_row.add_child(btn)
		grill_ui_buttons.append(btn)
		_refresh_grill_ui_button(i)


func _refresh_grill_ui_button(index: int) -> void:
	if index < 0 or index >= grill_ui_buttons.size():
		return
	var btn: Button = grill_ui_buttons[index]
	if not is_instance_valid(btn):
		return
	var on: bool = grill_powered[index]
	btn.text = "Grill %d: ON" % (index + 1) if on else "Grill %d: OFF" % (index + 1)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if on:
		sb.bg_color = Color("E64A19")
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		sb.bg_color = Color(0.28, 0.32, 0.38)
		btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = sb.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sbh)


func _make_grill_slot(index: int, pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.input_ray_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.58, 0.12, 0.58)
	shape.shape = box
	area.add_child(shape)

	## Metal pad - shiny chrome look (stays metal when ON)
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.52, 0.045, 0.52)
	marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.86, 0.9)
	mat.metallic = 1.0
	mat.roughness = 0.08
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.8, 0.88)
	mat.emission_energy_multiplier = 0.35
	marker.material_override = mat
	area.add_child(marker)
	grill_pad_mats.append(mat)

	## Soft orange radial heat glow in the center (only when ON)
	var glow := MeshInstance3D.new()
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.08
	glow_mesh.bottom_radius = 0.2
	glow_mesh.height = 0.012
	glow_mesh.radial_segments = 20
	glow.mesh = glow_mesh
	glow.position = Vector3(0, 0.028, 0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.45, 0.15, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.4, 0.12)
	gm.emission_energy_multiplier = 1.4
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	glow.visible = false
	area.add_child(glow)
	grill_glow_meshes.append(glow)

	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.4, 0.15)
	heat.light_energy = 0.0
	heat.omni_range = 0.55
	heat.position = Vector3(0, 0.1, 0)
	area.add_child(heat)
	grill_heat_lights.append(heat)

	## Big ON/OFF switch on the cook-facing side of each pad
	var btn := Area3D.new()
	btn.position = Vector3(pos.x, pos.y - 0.22, pos.z - 0.42)
	btn.input_ray_pickable = true
	btn.collision_layer = 1
	btn.collision_mask = 0
	var btn_shape := CollisionShape3D.new()
	var btn_box := BoxShape3D.new()
	btn_box.size = Vector3(0.48, 0.22, 0.22)
	btn_shape.shape = btn_box
	btn.add_child(btn_shape)

	var btn_mesh := MeshInstance3D.new()
	var btn_box_mesh := BoxMesh.new()
	btn_box_mesh.size = Vector3(0.44, 0.18, 0.18)
	btn_mesh.mesh = btn_box_mesh
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.32, 0.36, 0.42)
	bm.metallic = 0.7
	bm.roughness = 0.35
	bm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	bm.emission_enabled = true
	bm.emission = Color(0.2, 0.22, 0.25)
	bm.emission_energy_multiplier = 0.3
	btn_mesh.material_override = bm
	btn.add_child(btn_mesh)
	grill_power_btn_mats.append(bm)

	var lab := Label3D.new()
	lab.text = "OFF"
	lab.font_size = 42
	lab.pixel_size = 0.0032
	lab.position = Vector3(0, 0.0, -0.1)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 1, 1)
	lab.outline_modulate = Color.BLACK
	lab.outline_size = 8
	btn.add_child(lab)
	grill_power_labels.append(lab)

	var idx := index
	area.input_event.connect(func(_cam, event, _pos, _n, _s):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_grill_slot_clicked(idx, false)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_on_grill_slot_clicked(idx, true)
	)
	btn.input_event.connect(func(_cam, event, _pos, _n, _s):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			## Block pad clicks briefly so turning ON never also drops a patty.
			grill_ignore_pad_until = Time.get_ticks_msec() / 1000.0 + 0.35
			_toggle_grill_power(idx)
	)
	grill_root.add_child(area)
	grill_root.add_child(btn)
	slot_areas.append(area)


func _toggle_grill_power(index: int) -> void:
	if not playing:
		return
	## Power toggle only - never spawn a patty here.
	grill_ignore_pad_until = Time.get_ticks_msec() / 1000.0 + 0.35
	_set_grill_power(index, not grill_powered[index])
	if grill_powered[index]:
		_flash("Grill %d ON - right-click pad to add a patty" % (index + 1), Color("FFCC80"))
	else:
		_flash("Grill %d OFF" % (index + 1), Color("B0BEC5"))


func _set_grill_power(index: int, on: bool) -> void:
	if index < 0 or index >= GRILL_SLOTS:
		return
	grill_powered[index] = on
	if index < grill_glow_meshes.size() and is_instance_valid(grill_glow_meshes[index]):
		grill_glow_meshes[index].visible = on
	if index < grill_heat_lights.size() and is_instance_valid(grill_heat_lights[index]):
		grill_heat_lights[index].light_energy = 0.55 if on else 0.0
	if index < grill_pad_mats.size() and grill_pad_mats[index] != null:
		var mat: StandardMaterial3D = grill_pad_mats[index]
		## Stay shiny metal when ON - only a soft warm tint, not full orange.
		mat.albedo_color = Color(0.82, 0.86, 0.9)
		mat.metallic = 1.0
		mat.roughness = 0.08
		if on:
			mat.emission = Color(0.9, 0.75, 0.65)
			mat.emission_energy_multiplier = 0.45
		else:
			mat.emission = Color(0.75, 0.8, 0.88)
			mat.emission_energy_multiplier = 0.35
	if index < grill_power_btn_mats.size() and grill_power_btn_mats[index] != null:
		var bm: StandardMaterial3D = grill_power_btn_mats[index]
		if on:
			bm.albedo_color = Color(0.85, 0.25, 0.1)
			bm.emission = Color(1.0, 0.35, 0.1)
			bm.emission_energy_multiplier = 1.4
		else:
			bm.albedo_color = Color(0.32, 0.36, 0.42)
			bm.emission = Color(0.2, 0.22, 0.25)
			bm.emission_energy_multiplier = 0.3
	if index < grill_power_labels.size() and is_instance_valid(grill_power_labels[index]):
		grill_power_labels[index].text = "ON" if on else "OFF"
		grill_power_labels[index].modulate = Color("FFCC80") if on else Color(0.95, 0.95, 0.97)
	_refresh_grill_ui_button(index)


func _on_grill_slot_clicked(index: int, place_patty: bool = false) -> void:
	if not playing:
		return
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	## Left click on a cooking patty: flip / scoop only.
	if grill[index] != null and is_instance_valid(grill[index]):
		if place_patty:
			_flash("That pad already has a patty", Color("EF5350"))
			return
		_on_patty_clicked(grill[index])
		return
	## Empty pad: only right-click adds a new patty.
	if not place_patty:
		if grill_powered[index]:
			_flash("Right-click the pad to add a patty", Color("FFCC80"))
		else:
			_flash("Turn grill %d ON, then right-click to add a patty" % (index + 1), Color("FFA726"))
		return
	if not grill_powered[index]:
		_flash("Turn grill %d ON first" % (index + 1), Color("FFA726"))
		return
	_spawn_patty_in_slot(index)


func _spawn_patty_in_slot(idx: int) -> void:
	if not playing:
		return
	if grill[idx] != null:
		return
	if not grill_powered[idx]:
		_flash("Grill is OFF", Color("FFA726"))
		return
	var p = PattyScript.new()
	p.slot_index = idx
	p.base_y = slot_positions[idx].y
	p.heating = true
	p.position = slot_positions[idx]
	p.clicked.connect(_on_patty_clicked)
	patties_root.add_child(p)
	grill[idx] = p
	if idx < slot_areas.size() and is_instance_valid(slot_areas[idx]):
		slot_areas[idx].input_ray_pickable = false
	p.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_flash("Cooking! Wait for FLIP, then cook the other side", Color("FFAB91"))


func _on_patty_clicked(patty: Area3D) -> void:
	if not playing:
		return
	## Must flip before scooping - never grab a pre-flip patty.
	if not patty.flipped_once:
		if patty.can_flip():
			var ok: bool = patty.flip()
			if ok:
				_flash("Flipped! Cook the other side, then scoop", Color("FFEB3B") if patty.perfect_flip else Color("B0BEC5"))
		else:
			_flash("Too early - wait for FLIP", Color("FFA726"))
		return
	if not patty.can_scoop():
		_flash("Other side still cooking - wait to scoop", Color("FFA726"))
		return
	_pickup_patty(patty)


func _pickup_patty(patty: Area3D) -> void:
	if spatula_patty != null:
		_flash("Already holding a patty - press 1-4 to drop it", Color("EF5350"))
		return
	if not patty.flipped_once or not patty.can_scoop():
		_flash("Flip and finish cooking before scooping", Color("EF5350"))
		return
	var idx: int = patty.slot_index
	if idx >= 0 and idx < grill.size():
		grill[idx] = null
		if idx < slot_areas.size() and is_instance_valid(slot_areas[idx]):
			slot_areas[idx].input_ray_pickable = true
	patty.is_held = true
	patty.heating = false
	patty.visible = false
	spatula_patty = patty
	_refresh_spatula_ui()
	_flash("Scooped! Press 1-4 or Drop Patty on a station", Color("A5D6A7"))
	if spatula_3d:
		spatula_3d.visible = false


func _clear_all_patty() -> void:
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p:
			p.queue_free()
		grill[i] = null
		if i < slot_areas.size() and is_instance_valid(slot_areas[i]):
			slot_areas[i].input_ray_pickable = true


func _build_checkered_floor() -> void:
	var root := Node3D.new()
	world.add_child(root)
	var tile := 0.4
	for z in range(-5, 2):
		for x in range(-7, 8):
			var dark := ((x + z) % 2 == 0)
			var c := Color("1A1A1A") if dark else Color("F5F5F5")
			_add_box(root, Vector3(tile * 0.98, 0.03, tile * 0.98), Vector3(x * tile, 0.015, z * tile), c)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _try_grill_raycast(screen_pos: Vector2, place_patty: bool) -> void:
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var to := from + dir * 20.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.collider
		## Clicked a patty directly (left = flip/scoop)
		for p in grill:
			if p != null and p == collider:
				if place_patty:
					_flash("That pad already has a patty", Color("EF5350"))
				else:
					_on_patty_clicked(p)
				return
		## Clicked a pad
		for i in slot_areas.size():
			if slot_areas[i] == collider:
				_on_grill_slot_clicked(i, place_patty)
				return
		if place_patty:
			_place_nearest_slot(hit.position)
		return
	if place_patty and absf(dir.y) > 0.001:
		var t := (1.18 - from.y) / dir.y
		if t > 0.0:
			_place_nearest_slot(from + dir * t)


func _place_nearest_slot(world_pos: Vector3) -> void:
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	if slot_positions.is_empty():
		return
	if world_pos.y < 0.4 or world_pos.y > 1.8:
		return
	if absf(world_pos.z + 0.05) > 0.85:
		return
	var best := -1
	var best_d := 0.5
	for i in slot_positions.size():
		var d: float = Vector2(world_pos.x, world_pos.z).distance_to(Vector2(slot_positions[i].x, slot_positions[i].z))
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_on_grill_slot_clicked(best, true)


func _spawn_patty_on_grill() -> void:
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill is full!", Color("EF5350"))
		return
	_spawn_patty_in_slot(idx)


func _first_empty_slot() -> int:
	for i in GRILL_SLOTS:
		if grill[i] == null:
			return i
	return -1


func _clear_spatula() -> void:
	if spatula_patty != null and is_instance_valid(spatula_patty):
		spatula_patty.queue_free()
	spatula_patty = null
	_refresh_spatula_ui()
	if spatula_3d:
		spatula_3d.visible = true


# --- Customers --------------------------------------------------------------

func _spawn_customer() -> void:
	var order: Array[String] = GameDataScript.generate_order(difficulty)
	var c = CustomerScript.new()
	var color: Color = GameDataScript.CUSTOMER_COLORS[randi() % GameDataScript.CUSTOMER_COLORS.size()]
	var patience := lerpf(62.0, 30.0, difficulty) + randf_range(-3, 5)
	if day == 1:
		patience += 18.0
	elif day == 2:
		patience += 8.0
	var lane := customers.size()
	c.setup(order, color, patience, lane)
	## Higher in the window and spread across the opening.
	c.position = Vector3(-6.5, 0.85, 2.25)
	c.target_x = -2.6 + lane * 1.75
	c.rotation_degrees = Vector3(0, 180, 0)
	c.scale = Vector3(1.2, 1.2, 1.2)
	c.arrived.connect(_on_customer_arrived)
	c.patience_expired.connect(_on_customer_left.bind(true))
	c.served.connect(func(cust, _pay): _on_customer_left(cust, false))
	customers_root.add_child(c)
	customers.append(c)


func _on_customer_arrived(customer: Node3D) -> void:
	_create_ticket(customer)
	if selected_customer == null:
		selected_customer = customer
		_highlight_tickets()


func _on_customer_left(customer: Node3D, angry: bool) -> void:
	_remove_ticket(customer)
	customers.erase(customer)
	if selected_customer == customer:
		selected_customer = customers[0] if customers.size() > 0 else null
	_highlight_tickets()
	_reposition_customers()
	if angry:
		combo = 0
		money = maxi(0, money - 2)
		_flash("Customer left angry! -$2", Color("EF5350"))
		_update_hud()


func _reposition_customers() -> void:
	for i in customers.size():
		customers[i].lane = i
		customers[i].target_x = -2.6 + i * 1.75
		customers[i].global_position.y = 0.85


func _create_ticket(customer: Node3D) -> void:
	## Compact white ticket pinned along the top of the window opening.
	var panel := Button.new()
	panel.flat = true
	panel.focus_mode = Control.FOCUS_NONE
	panel.custom_minimum_size = Vector2(124, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.96)
	style.border_color = Color(0.75, 0.75, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("normal", style)
	var style_hover := style.duplicate()
	style_hover.bg_color = Color(1, 0.98, 0.9, 0.98)
	panel.add_theme_stylebox_override("hover", style_hover)
	panel.pressed.connect(func():
		_select_ticket(customer)
	)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 4
	v.offset_right = -4
	v.offset_top = 4
	v.offset_bottom = -4
	panel.add_child(v)

	var title := Label.new()
	title.text = "$%d" % customer.order_value
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var parts: Array[String] = []
	for item in customer.order:
		if item == "bun_bottom" or item == "bun_top":
			continue
		parts.append(GameDataScript.INGREDIENT_LABELS.get(item, item))
	var body := Label.new()
	body.text = " + ".join(parts) if parts.size() > 0 else "Burger"
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color(0.28, 0.28, 0.3))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)

	ticket_box.add_child(panel)
	tickets[customer] = panel
	_highlight_tickets()


func _select_ticket(customer: Node3D) -> void:
	if not is_instance_valid(customer) or not customer.is_waiting:
		_flash("That customer is gone", Color("EF5350"))
		return
	selected_customer = customer
	_highlight_tickets()
	_flash("Order selected - Serve from any station", Color("FFE082"))


func _remove_ticket(customer: Node3D) -> void:
	if tickets.has(customer):
		var p = tickets[customer]
		tickets.erase(customer)
		if is_instance_valid(p):
			p.queue_free()


func _highlight_tickets() -> void:
	for cust in tickets:
		var panel = tickets[cust]
		if not is_instance_valid(panel):
			continue
		var style: StyleBoxFlat = panel.get_theme_stylebox("normal").duplicate()
		if cust == selected_customer:
			style.bg_color = Color(1, 0.98, 0.85, 0.98)
			style.border_color = Color("F57C00")
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(1, 1, 1, 0.96)
			style.border_color = Color(0.75, 0.75, 0.78)
			style.set_border_width_all(1)
		panel.add_theme_stylebox_override("normal", style)
		panel.add_theme_stylebox_override("hover", style)
		panel.add_theme_stylebox_override("pressed", style)


func _clear_customers() -> void:
	for c in customers.duplicate():
		_remove_ticket(c)
		if is_instance_valid(c):
			c.queue_free()
	customers.clear()
	selected_customer = null


# --- Spatula + assembly stations -------------------------------------------

func _build_ingredient_legend() -> void:
	for child in ingredient_legend.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "INGREDIENTS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("FFE082"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ingredient_legend.add_child(title)
	var hint := Label.new()
	hint.text = "keys 1-0 / drag"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ingredient_legend.add_child(hint)
	for hi in INGREDIENT_HOTKEYS.size():
		var id: String = INGREDIENT_HOTKEYS[hi]
		var tbtn := Button.new()
		tbtn.text = "[%s] %s" % [HOTKEY_LABELS[hi], GameDataScript.INGREDIENT_LABELS[id]]
		tbtn.custom_minimum_size = Vector2(0, 26)
		tbtn.add_theme_font_size_override("font_size", 11)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = GameDataScript.INGREDIENT_COLORS[id].darkened(0.28)
		tsb.set_corner_radius_all(6)
		tsb.content_margin_left = 6
		tsb.content_margin_right = 6
		tsb.content_margin_top = 3
		tsb.content_margin_bottom = 3
		tbtn.add_theme_stylebox_override("normal", tsb)
		var tsbh := tsb.duplicate()
		tsbh.bg_color = GameDataScript.INGREDIENT_COLORS[id].darkened(0.08)
		tbtn.add_theme_stylebox_override("hover", tsbh)
		tbtn.add_theme_color_override("font_color", Color.WHITE)
		var capture: String = id
		tbtn.pressed.connect(func(): _add_ingredient(capture))
		tbtn.set_drag_forwarding(
			func(_pos):
				var drag_preview := ColorRect.new()
				drag_preview.custom_minimum_size = Vector2(100, 22)
				drag_preview.color = GameDataScript.INGREDIENT_COLORS.get(capture, Color.WHITE)
				tbtn.set_drag_preview(drag_preview)
				return {"kind": "ingredient", "id": capture, "station": active_station},
			Callable(),
			Callable()
		)
		ingredient_legend.add_child(tbtn)


func _build_station_ui() -> void:
	stations_row.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in stations_row.get_children():
		child.queue_free()
	for i in STATION_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(210, 180)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.11, 0.14, 0.92)
		style.border_color = Color(0.45, 0.5, 0.55)
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)

		var root_v := VBoxContainer.new()
		root_v.add_theme_constant_override("separation", 3)
		panel.add_child(root_v)

		var title := Label.new()
		title.text = "STATION %d" % (i + 1)
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color("FFE082"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_v.add_child(title)

		var assemble_label := Label.new()
		assemble_label.text = "Assemble"
		assemble_label.add_theme_font_size_override("font_size", 10)
		assemble_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		assemble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_v.add_child(assemble_label)

		var plate_wrap := Control.new()
		plate_wrap.custom_minimum_size = Vector2(0, 110)
		plate_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plate_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		root_v.add_child(plate_wrap)

		var stack_bg := ColorRect.new()
		stack_bg.color = Color(0.16, 0.17, 0.2, 0.9)
		stack_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate_wrap.add_child(stack_bg)

		var burger_stack := VBoxContainer.new()
		burger_stack.add_theme_constant_override("separation", -2)
		burger_stack.alignment = BoxContainer.ALIGNMENT_END
		burger_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		burger_stack.offset_left = 18
		burger_stack.offset_right = -18
		burger_stack.offset_top = 2
		burger_stack.offset_bottom = -2
		burger_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate_wrap.add_child(burger_stack)

		var drop_hint := Label.new()
		drop_hint.text = "drop / drag here"
		drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drop_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		drop_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
		drop_hint.add_theme_font_size_override("font_size", 10)
		drop_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 0.65))
		drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate_wrap.add_child(drop_hint)

		var si := i
		var drop_btn := Button.new()
		drop_btn.text = "Drop Patty"
		drop_btn.custom_minimum_size = Vector2(0, 24)
		drop_btn.add_theme_font_size_override("font_size", 11)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color("E65100")
		dsb.set_corner_radius_all(6)
		drop_btn.add_theme_stylebox_override("normal", dsb)
		var dsbh := dsb.duplicate()
		dsbh.bg_color = Color("FF8A50")
		drop_btn.add_theme_stylebox_override("hover", dsbh)
		drop_btn.add_theme_color_override("font_color", Color.WHITE)
		drop_btn.visible = false
		drop_btn.pressed.connect(func(): _on_station_plate_clicked(si))
		root_v.add_child(drop_btn)

		var btns := HBoxContainer.new()
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		btns.add_theme_constant_override("separation", 6)
		root_v.add_child(btns)

		var serve_one := Button.new()
		serve_one.text = "Serve (Enter)"
		serve_one.custom_minimum_size = Vector2(90, 24)
		serve_one.add_theme_font_size_override("font_size", 10)
		serve_one.pressed.connect(func():
			_select_station(si)
			_on_serve()
		)
		btns.add_child(serve_one)

		var clear_one := Button.new()
		clear_one.text = "Clear"
		clear_one.custom_minimum_size = Vector2(50, 24)
		clear_one.add_theme_font_size_override("font_size", 10)
		clear_one.pressed.connect(func():
			_select_station(si)
			_clear_station(si)
			_flash("Station %d cleared" % (si + 1), Color("B0BEC5"))
		)
		btns.add_child(clear_one)

		plate_wrap.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_station_plate_clicked(si)
		)
		plate_wrap.set_drag_forwarding(
			Callable(),
			func(_pos, data): return _can_drop_on_assembly(si, data),
			func(pos, data): _drop_on_assembly(si, pos, data)
		)
		panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_station(si)
		)

		stations_row.add_child(panel)
		stations[i]["panel"] = panel
		stations[i]["preview"] = burger_stack
		stations[i]["title"] = title
		stations[i]["plate"] = plate_wrap
		stations[i]["drop_hint"] = drop_hint
		stations[i]["drop_btn"] = drop_btn
	_highlight_active_station()


func _make_reorder_drag(station_index: int, from_index: int, item_id: String) -> Dictionary:
	return {"kind": "reorder", "station": station_index, "from": from_index, "id": item_id}


func _can_drop_on_assembly(station_index: int, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = data.get("kind", "")
	return kind == "ingredient" or kind == "reorder"


func _drop_on_assembly(station_index: int, at_pos: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	_select_station(station_index)
	var kind: String = data.get("kind", "")
	if kind == "ingredient":
		_add_ingredient_to_station(station_index, str(data.get("id", "")))
		return
	if kind == "reorder":
		var from_station: int = int(data.get("station", -1))
		var from_index: int = int(data.get("from", -1))
		if from_station != station_index or from_index < 0:
			return
		var insert_at := _assembly_insert_index(station_index, at_pos)
		_reorder_station_item(station_index, from_index, insert_at)


func _assembly_insert_index(station_index: int, local_pos: Vector2) -> int:
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if items.is_empty():
		return 0
	var plate: Control = st["plate"]
	if plate == null:
		return items.size()
	## Stack draws bottom-first at the bottom of the plate.
	var h: float = maxf(1.0, plate.size.y)
	var t: float = 1.0 - clampf(local_pos.y / h, 0.0, 1.0)
	return clampi(int(round(t * float(items.size()))), 0, items.size())


func _reorder_station_item(station_index: int, from_index: int, insert_at: int) -> void:
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if from_index < 0 or from_index >= items.size():
		return
	var item = items[from_index]
	items.remove_at(from_index)
	if insert_at > from_index:
		insert_at -= 1
	insert_at = clampi(insert_at, 0, items.size())
	items.insert(insert_at, item)
	## Keep burger physics: bottom bun / patty / toppings / top bun.
	st["items"] = _normalize_burger_stack(items)
	_sync_patties_with_items(station_index)
	_refresh_station(station_index)


func _sync_patties_with_items(station_index: int) -> void:
	## Patties array order follows appearance of "patty" entries in items.
	var st: Dictionary = stations[station_index]
	var count := 0
	for item in st["items"]:
		if item == "patty":
			count += 1
	while st["patties"].size() > count:
		var p = st["patties"].pop_back()
		if p != null and is_instance_valid(p):
			p.queue_free()


func _on_station_plate_clicked(index: int) -> void:
	if not playing:
		return
	_select_station(index)
	if spatula_patty != null:
		_drop_spatula_on_station(index)
	else:
		_flash("Station %d - drag tray items or press 1-0" % (index + 1), Color("FFE082"))


func _select_station(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	active_station = index
	_highlight_active_station()


func _highlight_active_station() -> void:
	for i in STATION_COUNT:
		var panel: PanelContainer = stations[i]["panel"]
		if panel == null:
			continue
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if i == active_station:
			style.bg_color = Color(0.16, 0.24, 0.14, 0.95)
			style.border_color = Color("8BC34A")
			style.set_border_width_all(3)
		else:
			style.bg_color = Color(0.1, 0.11, 0.14, 0.92)
			style.border_color = Color(0.45, 0.5, 0.55)
			style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		var title: Label = stations[i]["title"]
		if title:
			title.text = ("> STATION %d" if i == active_station else "STATION %d") % (i + 1)


func _drop_spatula_on_station(index: int) -> void:
	if not playing or spatula_patty == null:
		return
	if index < 0 or index >= STATION_COUNT:
		return
	var st: Dictionary = stations[index]
	var items: Array = st["items"]
	var patty = spatula_patty
	spatula_patty = null
	st["patties"].append(patty)
	_insert_patty_into_stack(items)
	st["items"] = _normalize_burger_stack(items)
	_refresh_spatula_ui()
	_refresh_station(index)
	_select_station(index)
	var n: int = st["patties"].size()
	_flash("Patty #%d on Station %d" % [n, index + 1], Color("A5D6A7"))
	if spatula_3d:
		spatula_3d.visible = true


func _insert_patty_into_stack(items: Array) -> void:
	## Patties always sit above bottom bun(s), below toppings.
	items.append("patty")


func _normalize_burger_stack(items: Array) -> Array:
	## Canonical order: bottom bun(s) -> patty(s) -> toppings -> top bun(s).
	var bottoms: Array = []
	var patties: Array = []
	var middles: Array = []
	var tops: Array = []
	for item in items:
		match str(item):
			"bun_bottom":
				bottoms.append(item)
			"patty":
				patties.append(item)
			"bun_top":
				tops.append(item)
			_:
				middles.append(item)
	if bottoms.is_empty() and (patties.size() > 0 or middles.size() > 0 or tops.size() > 0):
		bottoms.append("bun_bottom")
	var out: Array = []
	out.append_array(bottoms)
	out.append_array(patties)
	out.append_array(middles)
	out.append_array(tops)
	return out


func _build_ingredient_buttons() -> void:
	if ingredient_bar == null:
		return
	for child in ingredient_bar.get_children():
		child.queue_free()


func _add_ingredient(id: String) -> void:
	_add_ingredient_to_station(active_station, id)


func _add_ingredient_to_station(station_index: int, id: String) -> void:
	if not playing or id == "":
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	_select_station(station_index)
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if items.size() >= 14:
		_flash("Burger too tall!", Color("EF5350"))
		return
	items.append(id)
	st["items"] = _normalize_burger_stack(items)
	_refresh_station(station_index)


func _clear_active_station() -> void:
	_clear_station(active_station)
	_flash("Station %d cleared" % (active_station + 1), Color("B0BEC5"))


func _clear_station(index: int) -> void:
	var st: Dictionary = stations[index]
	for p in st["patties"]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	st["patties"] = []
	st["items"] = [] as Array[String]
	_refresh_station(index)


func _clear_all_stations() -> void:
	for i in STATION_COUNT:
		_clear_station(i)


func _refresh_station(index: int) -> void:
	var st: Dictionary = stations[index]
	var preview: VBoxContainer = st["preview"]
	if preview == null:
		return
	for child in preview.get_children():
		child.queue_free()
	var items: Array = st["items"]
	var drop_hint: Label = st.get("drop_hint", null)
	var drop_btn: Button = st.get("drop_btn", null)
	if drop_btn and is_instance_valid(drop_btn):
		drop_btn.visible = spatula_patty != null
	if drop_hint and is_instance_valid(drop_hint):
		drop_hint.visible = items.is_empty()
		if spatula_patty != null:
			drop_hint.text = "DROP PATTY"
			drop_hint.add_theme_color_override("font_color", Color("FFCC80"))
		else:
			drop_hint.text = "drag tray here"
			drop_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 0.65))

	if items.is_empty():
		return

	var patty_draw_i := 0
	## VBox draws first child at the TOP of the packed block. Add top->bottom
	## so bottom bun ends up at the visual bottom.
	for stack_i in range(items.size() - 1, -1, -1):
		var item: String = items[stack_i]
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0, 0, 0, 0)
		row_style.set_content_margin_all(0)
		row.add_theme_stylebox_override("panel", row_style)

		var tr := TextureRect.new()
		if item == "patty":
			## Count patties from the bottom of the burger upward.
			var patty_from_bottom := 0
			for j in range(stack_i + 1):
				if items[j] == "patty":
					patty_from_bottom += 1
			var pidx := patty_from_bottom - 1
			var pcolor := GameDataScript.INGREDIENT_COLORS["patty"]
			if pidx >= 0 and pidx < st["patties"].size() and is_instance_valid(st["patties"][pidx]):
				pcolor = st["patties"][pidx].get_patty_color()
			tr.texture = FoodSpritesScript.patty_tex(pcolor)
			patty_draw_i += 1
		else:
			tr.texture = FoodSpritesScript.get_tex(item)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(130, _layer_img_height(item))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)

		var from_i := stack_i
		var item_id := item
		row.set_drag_forwarding(
			func(_pos):
				var drag_preview := ColorRect.new()
				drag_preview.custom_minimum_size = Vector2(100, 16)
				drag_preview.color = GameDataScript.INGREDIENT_COLORS.get(item_id, Color.GRAY)
				row.set_drag_preview(drag_preview)
				return _make_reorder_drag(index, from_i, item_id),
			func(_pos, data): return _can_drop_on_assembly(index, data),
			func(pos, data): _drop_on_assembly(index, pos, data)
		)
		preview.add_child(row)


func _layer_img_height(item: String) -> float:
	match item:
		"bun_top":
			return 28.0
		"bun_bottom":
			return 26.0
		"patty":
			return 22.0
		"bacon":
			return 16.0
		"ketchup", "mustard":
			return 12.0
		_:
			return 18.0


func _refresh_all_stations() -> void:
	for i in STATION_COUNT:
		_refresh_station(i)
	_highlight_active_station()


func _refresh_spatula_ui() -> void:
	for child in held_row.get_children():
		child.queue_free()

	var icon := TextureRect.new()
	icon.texture = FoodSpritesScript.get_tex("spatula")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_row.add_child(icon)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("FFCC80"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if spatula_patty != null and is_instance_valid(spatula_patty):
		var ptex := TextureRect.new()
		ptex.texture = FoodSpritesScript.patty_tex(spatula_patty.get_patty_color())
		ptex.custom_minimum_size = Vector2(48, 18)
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		held_row.add_child(ptex)
		label.text = "%s held - click Drop Patty, then 1-0 toppings, Enter serve" % spatula_patty.get_doneness_label()
	else:
		label.text = "Empty spatula - flip, finish cooking, then scoop"
	held_row.add_child(label)

	## Quick drop buttons when holding a patty
	if spatula_patty != null and is_instance_valid(spatula_patty):
		for i in STATION_COUNT:
			var db := Button.new()
			db.text = "->%d" % (i + 1)
			db.custom_minimum_size = Vector2(40, 28)
			db.add_theme_font_size_override("font_size", 12)
			var si := i
			db.pressed.connect(func(): _drop_spatula_on_station(si))
			held_row.add_child(db)

	for i in STATION_COUNT:
		_refresh_station(i)

func _on_serve() -> void:
	if not playing:
		return
	## Selected ticket is the order we serve.
	if selected_customer == null or not is_instance_valid(selected_customer) or not selected_customer.is_waiting:
		selected_customer = null
		_highlight_tickets()
		_flash("Click an order ticket first, then Serve", Color("EF5350"))
		return

	## Use any station that has a burger - prefer active, then best match for the ticket.
	var station_index := _find_station_for_order(selected_customer.order)
	if station_index < 0:
		_flash("Build the burger on any station, then Serve", Color("EF5350"))
		return

	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	active_station = station_index
	_highlight_active_station()

	var patty_mult := 1.0
	var patties: Array = st["patties"]
	if patties.size() > 0:
		var sum := 0.0
		var n := 0
		for p in patties:
			if p != null and is_instance_valid(p):
				sum += p.quality_multiplier()
				n += 1
		if n > 0:
			patty_mult = sum / float(n)
	var tip: float = selected_customer.patience_ratio() * 0.35
	var result: Dictionary = GameDataScript.compare_orders(items, selected_customer.order)
	var payout: int = selected_customer.receive_burger(items, patty_mult, combo, tip)

	if payout > 0:
		money += payout
		total_served += 1
		if result.perfect and patty_mult >= 1.0:
			combo += 1
			perfect_serves += 1
			_flash("+$%d  COMBO x%d!" % [payout, combo], Color("FFEB3B"))
		else:
			if result.quality > 0.85:
				combo += 1
			else:
				combo = 0
			_flash("+$%d (Station %d)" % [payout, station_index + 1], Color("A5D6A7"))
	else:
		combo = 0
		_flash("Wrong order - no pay", Color("EF5350"))

	_clear_station(station_index)
	_update_hud()


func _find_station_for_order(order: Array) -> int:
	## Prefer the active station if it has a patty, otherwise best match, else any ready burger.
	var candidates: Array[int] = []
	for i in STATION_COUNT:
		var items: Array = stations[i]["items"]
		if items.is_empty() or "patty" not in items:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	if active_station in candidates:
		return active_station
	var best := candidates[0]
	var best_q := -1.0
	for i in candidates:
		var q: float = float(GameDataScript.compare_orders(stations[i]["items"], order).get("quality", 0.0))
		if q > best_q:
			best_q = q
			best = i
	return best


func _update_hud() -> void:
	hud_money.text = "$%d" % money
	hud_combo.text = "Combo x%d" % combo if combo > 0 else "Combo -"
	hud_day.text = "Day %d  -  %ds" % [day, maxi(0, int(day_time))]


func _flash(text: String, color: Color) -> void:
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.visible = true
	flash_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(flash_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): flash_label.visible = false)
