## 3D food-truck burger game - cook from inside, looking out the window.
extends Node3D

const GRILL_SLOTS := 10
const STATION_COUNT := 1
const STATION_CRAFT := 0
## Build-board burger art scale (1.0 = prior size).
const STATION_BURGER_SCALE := 0.75
const MAX_HELD := 4
## Grill heat bands screen-left → right: FULL · 1/4 · 1/8 · HOLD
const ZONE_FULL_FRAC := 0.38
const ZONE_QUARTER_FRAC := 0.20
const ZONE_EIGHTH_FRAC := 0.18
const ZONE_HOLD_FRAC := 0.24
const ZONE_FULL_MUL := 1.0
const ZONE_QUARTER_MUL := 0.25
const ZONE_EIGHTH_MUL := 0.125
const ZONE_HOLD_MUL := 0.0
const WARM_HOLD_MAX := 300.0 ## 5 minutes on HOLD before meat goes bad
## Legacy aliases used by hold-zone helpers.
const WARMER_WIDTH_FRAC := ZONE_HOLD_FRAC
const WARMER_COOK_MUL := ZONE_HOLD_MUL
const MAX_CUSTOMERS := 4
const DAY_LENGTH := 480.0 ## 4x longer shifts
const FRESHNESS_FULL := 60.0 ## 1 minute at full freshness
const FRESHNESS_DEGRADE := 30.0 ## then 30s of quality drop before it goes bad
const FRESHNESS_MAX := FRESHNESS_FULL + FRESHNESS_DEGRADE
const GRILL_SURFACE_Y := 1.155
const GRILL_SURFACE_Z := -0.02 ## farther from cook, closer to window
const GRILL_CENTER_X := -0.35
const GRILL_WIDTH := 2.35
const GRILL_DEPTH := 0.95
## Patty must sit fully on the steel — reject clicks near the rim.
const PATTY_FIT_RADIUS := 0.10
const PATTY_MIN_SEP := 0.19
## Screen + world grab radius — generous so cheese / scoop clicks land reliably.
const PATTY_PICK_WORLD := 0.42
const PATTY_PICK_MIN_PX := 62.0
const PATTY_PICK_WORLD_EDGE := 0.17
const PATTY_PICK_PAD_PX := 22.0
const PATTY_SIT_Y := 0.055
## Oil puddles sit above steel (top ~+0.023) but under patties (+0.055).
const OIL_SIT_Y := 0.034
## Held bottle tip-down height above steel (~was 0.14; +12" so it clears the plate).
const OIL_POUR_HEIGHT := 0.445
const PattyScript := preload("res://scripts/patty.gd")
const CustomerScript := preload("res://scripts/customer.gd")
const GameDataScript := preload("res://scripts/game_data.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")
const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const TruckRadioScript := preload("res://scripts/truck_radio.gd")
const GameAudioScript := preload("res://scripts/game_audio.gd")
## Hotkeys 1-9 match ticket topping order (cheese first → top bun last).
## Bottom bar is drawn right→left so you work toward Serve with top bun last.
## Bottom bun is automatic when a patty hits a station — not on the strip.
const INGREDIENT_HOTKEYS: Array[String] = [
	"cheese", "tomato", "lettuce", "onion", "pickle", "bacon", "ketchup", "mustard",
	"bun_top",
]
const HOTKEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

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
@onready var stations_row: VBoxContainer = %StationsRow
@onready var held_row: HBoxContainer = %HeldRow
@onready var flash_label: Label = %FlashLabel
@onready var start_overlay: ColorRect = %StartOverlay
@onready var start_btn: Button = %StartButton
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_label: Label = %GameOverLabel
@onready var restart_btn: Button = %RestartButton
@onready var grill_power_row: HBoxContainer = %GrillPowerRow
@onready var ingredient_legend: HBoxContainer = %IngredientLegend

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
var warmer_root: Node3D = null
var warmer_label: Label3D = null
var warmer_label_quarter: Label3D = null
var warmer_label_eighth: Label3D = null
var warmer_outline_mat: StandardMaterial3D = null
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
var grill_powered: Array = [] ## bool per slot (all share one burner)
var grill_on: bool = false ## single flat-top burner
var grill_glow_meshes: Array = []
var grill_pad_mats: Array = []
var grill_power_labels: Array = []
var grill_heat_lights: Array = []
var grill_ui_buttons: Array = []
var grill_trash_btn: Button = null
var grill_surface_area: Area3D = null
var grill_surface_mat: StandardMaterial3D = null
var grill_glow_root: MeshInstance3D = null
var heat_warp_mesh: MeshInstance3D = null
var heat_warp_mat: ShaderMaterial = null
var grill_drop_zone: Control = null
var service_window_closed: bool = false
var service_break_left: float = 0.0
var window_pause_btn: Button = null
var window_shutter: ColorRect = null
const SERVICE_BREAK_SEC := 28.0
var ingredient_buttons: Dictionary = {} ## id -> Button
var _strip_did_drag: bool = false ## Skip press action after a strip drag.
var grill_ignore_pad_until: float = 0.0
var grill_residue: Array = [] ## 0 clean · 0.5 half-scraped · 1.0 full stuck-on
var grill_residue_meshes: Array = [] ## legacy single mesh slot (unused visually)
var grill_residue_mats: Array = []
var grill_residue_chunks: Array = [] ## per slot: Array of MeshInstance3D pieces
var grill_residue_centers: Array = [] ## Vector3 per slot
var brush_swipe_travel: Array = [] ## movement accum while over each residue
var brush_last_pos: Vector3 = Vector3.ZERO
var brush_swipe_cool: Array = [] ## cooldown after a scrape hit
var brush_held: bool = false
var brush_root: Node3D = null
var brush_area: Area3D = null
var brush_home: Vector3 = Vector3(-2.58, 1.52, 1.15)
var brush_home_rot := Vector3(-172.0, -110.0, 8.0)
var brush_throwing: bool = false
const RESIDUE_SWIPE_DIST := 0.07 ## travel needed to chip a fleck cluster
const RESIDUE_SCRAPE_RATE := 1.35 ## residue cleared per meter of blade travel
const RESIDUE_CHUNK_COUNT := 6 ## Extra flecks on top of the burnt disc.
## Click cheese → ghost → click a grill patty to place.
var cheese_held: bool = false
var cheese_ghost: MeshInstance3D = null
var cheese_ghost_mat: StandardMaterial3D = null
## Seasoning shaker — parked by the scraper (screen-right), clear of UI.
var shaker_held: bool = false
var shaker_root: Node3D = null
var shaker_area: Area3D = null
var shaker_particles: GPUParticles3D = null
var shaker_btn: Button = null
var shaker_home: Vector3 = Vector3(-2.15, 1.32, 1.08)
var shaker_season_cool: float = 0.0
## Oil bottle — next to scraper/shaker; flip upside-down to draw puddle lines.
var oil_held: bool = false
var oil_root: Node3D = null
var oil_area: Area3D = null
var oil_particles: GPUParticles3D = null
var oil_home: Vector3 = Vector3(-1.72, 1.22, 0.88)
var oil_spray_cool: float = 0.0
var oil_last_draw: Vector3 = Vector3.ZERO
var oil_slicks: Array = [] ## {mesh, age, life, radius}
var _oil_blob_tex: ImageTexture = null
var _oil_smoke_tex: ImageTexture = null
## Scraper can shove nearby patties a little while scraping.
const BRUSH_PATTY_PUSH_RADIUS := 0.32
const BRUSH_PATTY_PUSH_SCALE := 0.72
const BRUSH_PATTY_PUSH_MAX := 0.038
## Click-drag to slide patties on the flat-top.
var dragging_patty = null
var drag_start_mouse := Vector2.ZERO
var drag_did_move: bool = false
var drag_pop_accum: float = 0.0
var drag_last_xz := Vector2.ZERO
var drag_last_mouse := Vector2.ZERO
var drag_vel_screen := Vector2.ZERO ## px/sec while sliding (for flick-to-Build)
var flicking_patty = null ## mid air toward Build
var spatula_last_mouse := Vector2.ZERO
var spatula_vel_screen := Vector2.ZERO ## px/sec while carrying (flick throw)
var spatula_carry_travel := 0.0
const DRAG_MOVE_THRESH_PX := 8.0
const DRAG_POP_DIST := 0.032 ## denser grease pops while sliding
## Screen-left flick (negative X) throws a finished patty to Build.
const FLICK_TO_BUILD_VX := -520.0
const FLICK_MIN_SPEED := 620.0
const FLICK_MIN_TRAVEL_PX := 36.0
## Left side of the screen counts as Build drop while carrying a scooped patty.
const BUILD_DROP_SCREEN_FRAC := 0.34
const BUILD_DROP_MIN_PX := 300.0
## Scooped patty floats under the cursor above the steel.
const SPATULA_HOVER_Y := 0.12
const SPATULA_HOVER_BOB := 0.012

var radio: Node = null
var radio_status_label: Label = null
var radio_channel_label: Label = null
var radio_power_btn: Button = null
var radio_dial_mesh: MeshInstance3D = null
var radio_light_mat: StandardMaterial3D = null
var radio_column: VBoxContainer = null
var game_audio: Node = null
## Graphics menu — live Environment + kitchen lights.
var gfx_env: Environment = null
var gfx_sun: DirectionalLight3D = null
var gfx_outside_fill: DirectionalLight3D = null
var gfx_kitchen: OmniLight3D = null
var gfx_grill_lamp: SpotLight3D = null
var gfx_window_wash: SpotLight3D = null
var gfx_sky_mat: PanoramaSkyMaterial = null
var gfx_panel: PanelContainer = null
var gfx_btn: Button = null
var gfx_sliders: Dictionary = {} ## key -> HSlider
var gfx_checks: Dictionary = {} ## key -> CheckButton
const GFX_CFG_PATH := "user://gfx_settings.cfg"
const GFX_DEFAULTS := {
	"bloom": 0.32,
	"glow_intensity": 1.05,
	"glow_strength": 1.35,
	"glow_threshold": 0.55,
	"glow_on": true,
	"exposure": 0.92,
	"ambient": 0.28,
	"sun": 1.55,
	"kitchen": 1.65,
	"grill_lamp": 1.35,
	"window_wash": 1.1,
	"saturation": 1.06,
	"contrast": 1.04,
	"ssao": true,
	"ssil": true,
	"sky_energy": 0.42,
}
## Ingredient strip notes — tracks unique presses toward a full-scale jingle.
var _melody_pressed: Dictionary = {} ## id -> true
## Customer window chat popup.
var dialogue_panel: PanelContainer = null
var dialogue_title: Label = null
var dialogue_body: Label = null
var dialogue_options: VBoxContainer = null
var dialogue_customer = null
var dialogue_queue: Array = []
var complaint_station: int = -1 ## Station held while customer complains about missing items.
var _was_gui_dragging: bool = false


func _ready() -> void:
	randomize()
	UiFontsScript.ensure_loaded()
	var ui_root: Control = get_node("UI/Root")
	ui_root.theme = UiFontsScript.make_theme()
	_style_static_labels()
	grill.resize(GRILL_SLOTS)
	grill.fill(null)
	grill_powered.resize(GRILL_SLOTS)
	grill_powered.fill(false)
	grill_residue.resize(GRILL_SLOTS)
	grill_residue.fill(0.0)
	grill_residue_chunks.resize(GRILL_SLOTS)
	for _i in GRILL_SLOTS:
		grill_residue_chunks[_i] = []
	grill_residue_centers.resize(GRILL_SLOTS)
	grill_residue_centers.fill(Vector3.ZERO)
	brush_swipe_travel.resize(GRILL_SLOTS)
	brush_swipe_travel.fill(0.0)
	brush_swipe_cool.resize(GRILL_SLOTS)
	brush_swipe_cool.fill(0.0)
	_setup_stations_data()
	_build_3d_world()
	_build_grill_burner_ui()
	_build_station_ui()
	_build_grill_drop_zone()
	_build_window_pause_ui()
	_build_ingredient_legend()
	_build_ingredient_buttons()
	_setup_radio()
	_build_pause_button()
	_build_graphics_ui()
	_setup_game_audio()
	_build_dialogue_ui()
	## Hint sits under order tickets; flash stays on top.
	var ticket_rail: Control = get_node_or_null("UI/Root/WindowTicketRail")
	if ticket_rail:
		ticket_rail.z_index = 5
	if hud_hint:
		hud_hint.visible = false
		hud_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flash_label:
		flash_label.z_index = 35
		flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_bar: Control = get_node_or_null("UI/Root/TopBar")
	if top_bar:
		top_bar.z_index = 25
	## Empty chrome passes through; stations + toppings stay clickable.
	var bottom := get_node_or_null("UI/Root/BottomUI")
	if bottom:
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_row.visible = false
	held_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ingredient_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	## Pass-through so left grill clicks aren't blocked by empty Build chrome.
	stations_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ingredient_legend.mouse_filter = Control.MOUSE_FILTER_STOP
	start_btn.pressed.connect(func():
		_sfx_click()
		_start_game()
	)
	restart_btn.pressed.connect(func():
		_sfx_click()
		_restart()
	)
	game_over_panel.visible = false
	flash_label.visible = false
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()


func _style_static_labels() -> void:
	UiFontsScript.apply_label(hud_money, true, 30)
	UiFontsScript.apply_label(hud_combo, true, 22)
	UiFontsScript.apply_label(hud_day, true, 22)
	UiFontsScript.apply_label(hud_hint, false, 13)
	UiFontsScript.apply_label(flash_label, true, 30)
	## Thin outline — thick outlines on MSDF fonts looked chewed-up.
	for lab in [hud_money, hud_combo, hud_day]:
		if lab:
			lab.add_theme_constant_override("outline_size", 2)
			lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if hud_hint:
		hud_hint.add_theme_constant_override("outline_size", 1)
		hud_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	if flash_label:
		flash_label.add_theme_constant_override("outline_size", 3)
		flash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	UiFontsScript.apply_button(start_btn, true, 22)
	UiFontsScript.apply_button(restart_btn, true, 18)
	var title := get_node_or_null("UI/Root/StartOverlay/StartCenter/Title") as Label
	if title:
		UiFontsScript.apply_label(title, true, 48)
	var blurb := get_node_or_null("UI/Root/StartOverlay/StartCenter/Blurb") as Label
	if blurb:
		UiFontsScript.apply_label(blurb, false, 16)
	UiFontsScript.apply_label(game_over_label, true, 22)


func _setup_stations_data() -> void:
	stations.clear()
	for i in STATION_COUNT:
		stations.append({
			"kind": "craft",
			"items": [] as Array[String],
			"patties": [],
			"panel": null,
			"preview": null,
			"title": null,
			"plate": null,
			"drop_hint": null,
			"drop_btn": null,
			"fresh_label": null,
			"fresh_active": false,
			"freshness": FRESHNESS_MAX,
			"spoiled": false,
			"selected_layer": -1,
		})


func _is_warmer_station(_index: int) -> bool:
	## UI warmer removed — hold zone is on the 3D grill far-right.
	return false


func _station_label(_index: int) -> String:
	return "Build"


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
	active_station = STATION_CRAFT
	complaint_station = -1
	_melody_pressed.clear()
	_clear_all_patty()
	_clear_spatula()
	_clear_warmer()
	_cancel_cheese_hold_silent()
	_cancel_shaker_hold_silent()
	_reset_oil_bottle()
	_clear_all_stations()
	_clear_customers()
	_reset_service_window_open()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_flash("Turn the burner ON, then right-click the grill to add patties!", Color("FFEB3B"))


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
	active_station = STATION_CRAFT
	complaint_station = -1
	_clear_all_patty()
	_clear_spatula()
	_clear_warmer()
	_cancel_cheese_hold_silent()
	_cancel_shaker_hold_silent()
	_reset_oil_bottle()
	_clear_all_stations()
	_clear_customers()
	_reset_service_window_open()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_flash("Day %d - it gets busier!" % day, Color("FFEB3B"))


func _process(delta: float) -> void:
	if not playing:
		if game_audio:
			game_audio.set_sizzle_active(false)
		return
	## Sync grill heat to patties (only cook while burner is on + on cook zone).
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p != null and is_instance_valid(p):
			p.heating = grill_on
			p.heat_mul = _warmer_heat_mul(p.position) * _oil_heat_mul(p.position)
			_update_patty_warm_hold(p, delta)
	_update_station_cheese_melt(delta)
	_update_patty_hint_focus()
	_update_kitchen_sizzle()
	_update_heat_warp(delta)
	if dragging_patty != null:
		_update_patty_drag(delta)
	if cheese_held:
		_update_cheese_ghost()
	if spatula_patty != null:
		_update_held_spatula_patty(delta)
	if shaker_held:
		_update_held_shaker(delta)
	if oil_held:
		_update_held_oil(delta)
	_update_oil_slicks(delta)
	if brush_held and not brush_throwing:
		_update_held_brush(delta)
	## Viewport has no gui_drag_ended signal in 4.x — poll instead.
	var gui_dragging := get_viewport().gui_is_dragging()
	if _was_gui_dragging and not gui_dragging:
		_on_gui_drag_ended(get_viewport().gui_is_drag_successful())
	_was_gui_dragging = gui_dragging

	day_time -= delta
	if day_time < 0.0:
		day_time = 0.0
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	var day_boost := clampf((day - 1) * 0.22, 0.0, 0.85)
	difficulty = minf(1.0, day_progress * (0.38 if day == 1 else 0.55) + day_boost)

	## Clock hit zero: no new customers, but finish everyone already waiting.
	var shift_closing := day_time <= 0.0
	if service_window_closed:
		service_break_left = maxf(0.0, service_break_left - delta)
		if window_pause_btn:
			window_pause_btn.text = "OPEN (%ds)" % maxi(1, int(ceil(service_break_left)))
		if service_break_left <= 0.0:
			_open_service_window()
	else:
		spawn_timer -= delta
		var cap := _customer_cap()
		if not shift_closing and spawn_timer <= 0.0 and customers.size() < cap:
			_spawn_customer()
			spawn_timer = _next_spawn_delay()

	rush_mode = customers.size() >= maxi(2, _customer_cap() - 1) and day >= 2

	if shift_closing and customers.is_empty() and not service_window_closed:
		_end_day()
	_update_station_freshness(delta)
	_update_hud()


func _update_station_freshness(delta: float) -> void:
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		if not st.get("fresh_active", false):
			_refresh_freshness_label(i)
			continue
		if st["items"].is_empty():
			_reset_station_freshness(i)
			continue
		st["freshness"] = maxf(0.0, float(st["freshness"]) - delta)
		_refresh_freshness_label(i)
		if float(st["freshness"]) <= 0.0 and not st.get("spoiled", false):
			st["spoiled"] = true
			_clear_station(i)
			_flash("%s went BAD - trash it next time sooner!" % _station_label(i), Color("EF5350"))


func _start_station_freshness(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	var st: Dictionary = stations[index]
	if st["items"].is_empty():
		return
	if not st.get("fresh_active", false):
		st["fresh_active"] = true
		st["freshness"] = FRESHNESS_MAX
		st["spoiled"] = false
	_refresh_freshness_label(index)


func _reset_station_freshness(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	var st: Dictionary = stations[index]
	st["fresh_active"] = false
	st["freshness"] = FRESHNESS_MAX
	st["spoiled"] = false
	_refresh_freshness_label(index)


func _station_freshness_ratio(index: int) -> float:
	var st: Dictionary = stations[index]
	if not st.get("fresh_active", false) or st["items"].is_empty():
		return 1.0
	var rem := float(st["freshness"])
	## First minute stays fully fresh; only the last 30s degrade.
	if rem >= FRESHNESS_DEGRADE:
		return 1.0
	return clampf(rem / FRESHNESS_DEGRADE, 0.0, 1.0)


func _freshness_grade(ratio: float) -> Dictionary:
	## text + color for the freshness meter
	if ratio > 0.7:
		return {"text": "FRESH", "color": Color("66BB6A")}
	if ratio > 0.4:
		return {"text": "GOOD", "color": Color("FFEE58")}
	if ratio > 0.15:
		return {"text": "STALE", "color": Color("FFA726")}
	return {"text": "SPOILING", "color": Color("EF5350")}


func _refresh_freshness_label(index: int) -> void:
	var st: Dictionary = stations[index]
	var lab: Label = st.get("fresh_label", null)
	if lab == null or not is_instance_valid(lab):
		return
	if st["items"].is_empty() or not st.get("fresh_active", false):
		lab.text = "--"
		lab.add_theme_color_override("font_color", Color(0.85, 0.7, 0.65))
		return
	var ratio := _station_freshness_ratio(index)
	var grade: Dictionary = _freshness_grade(ratio)
	var secs := int(ceil(float(st["freshness"])))
	lab.text = "%s %ds" % [grade["text"], secs]
	lab.add_theme_color_override("font_color", grade["color"])


func _first_customer_delay() -> float:
	match day:
		1: return 14.0
		2: return 8.0
		3: return 5.0
		_: return 3.0


func _customer_cap() -> int:
	## One order at a time — next customer only after the current is done.
	return 1


func _next_spawn_delay() -> float:
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	match day:
		1: return lerpf(26.0, 14.0, day_progress) + randf_range(0.0, 5.0)
		2: return lerpf(16.0, 9.0, day_progress) + randf_range(0.0, 4.0)
		3: return lerpf(12.0, 6.5, day_progress) + randf_range(0.0, 3.0)
		_: return lerpf(8.0, 4.0, minf(1.0, day_progress + (day - 4) * 0.1)) + randf_range(0.0, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	## Radio works even on the start screen.
	if event is InputEventKey and event.pressed and not event.echo and radio:
		if event.keycode == KEY_BRACKETLEFT:
			radio.prev_channel()
			_spin_radio_dial(-1)
			return
		if event.keycode == KEY_BRACKETRIGHT:
			radio.next_channel()
			_spin_radio_dial(1)
			return
		if event.keycode == KEY_R:
			radio.toggle_power()
			_flash("Radio %s" % ("ON" if radio.powered else "OFF"), Color("FFCC80"))
			return
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
		if _ui_blocks_world_click(event.position):
			return
		if brush_held or oil_held or shaker_held or dragging_patty != null:
			return
		if cheese_held:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				## Also handled in _input so UI can't eat the cancel click.
				_cancel_cheese_hold()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				_try_place_held_cheese(event.position)
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if spatula_patty != null:
				_handle_spatula_click(event.position)
				return
			if _try_warmer_click(event.position):
				return
			## Left click: flip / scoop / start drag — never spawn a patty.
			_try_grill_raycast(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var smash_target = _pick_patty_at_screen(event.position)
			if smash_target != null:
				smash_target.smash()
			else:
				_try_grill_raycast(event.position, true)



func _input(event: InputEvent) -> void:
	if not playing:
		return
	## Right-click while holding cheese → put it back on the strip (works over UI too).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if cheese_held:
			_cancel_cheese_hold()
			get_viewport().set_input_as_handled()
			return
	## Sliding a patty / oil / shaker: release ends hold and returns tools home.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_patty != null:
			_end_patty_drag()
			get_viewport().set_input_as_handled()
			return
		if oil_held:
			_release_oil_bottle()
			get_viewport().set_input_as_handled()
			return
		if shaker_held:
			_cancel_shaker_hold()
			get_viewport().set_input_as_handled()
			return
		if brush_held:
			_throw_brush_home()
			get_viewport().set_input_as_handled()
			return
	## Wire brush / oil / shaker: hold LMB to use — never steal clicks from UI buttons.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _ui_blocks_world_click(event.position):
				return
			if cheese_held:
				## Place handled in unhandled — don't grab tools mid-hold.
				return
			if brush_held or oil_held or shaker_held or dragging_patty != null:
				get_viewport().set_input_as_handled()
				return
			if _try_grab_nearest_tool(event.position):
				get_viewport().set_input_as_handled()
				return
	## Cancel cheese hold with Escape / open graphics with F10.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_toggle_graphics_menu()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if gfx_panel != null and gfx_panel.visible:
			_set_graphics_menu_open(false)
			get_viewport().set_input_as_handled()
			return
		if cheese_held:
			_cancel_cheese_hold()
			get_viewport().set_input_as_handled()
			return
		if shaker_held:
			_cancel_shaker_hold()
			get_viewport().set_input_as_handled()
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
	## Mouse drop while holding a patty (also works over some UI).
	if spatula_patty == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _handle_spatula_click(event.position):
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
	return ""


func _ui_blocks_world_click(screen_pos: Vector2) -> bool:
	## Buttons / panels on top of the 3D tools — never grab scraper through UI.
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null:
		if node is Control:
			var c := node as Control
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				## Full-screen empty roots pass through; interactive chrome does not.
				var n := String(c.name)
				if n == "Root" or n == "BottomUI" or n == "StationsRow" or n == "GrillDropZone":
					pass
				else:
					return true
		node = node.get_parent()
	## Explicit hit-tests — hovered can miss during the same-frame press.
	for ctrl in [window_pause_btn, gfx_btn, gfx_panel, radio_column]:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.visible:
			if ctrl is Control and (ctrl as Control).get_global_rect().has_point(screen_pos):
				return true
	var top_bar: Control = get_node_or_null("UI/Root/TopBar")
	if top_bar != null and top_bar.get_global_rect().has_point(screen_pos):
		return true
	var ingredient: Control = get_node_or_null("UI/Root/BottomUI/IngredientBar")
	if ingredient == null:
		ingredient = ingredient_bar
	if ingredient != null and is_instance_valid(ingredient) and ingredient.get_global_rect().has_point(screen_pos):
		return true
	if dialogue_panel != null and dialogue_panel.visible and dialogue_panel.get_global_rect().has_point(screen_pos):
		return true
	return false


func _station_index_at(screen_pos: Vector2) -> int:
	## Whole Build column counts — click / drag / flick land anywhere in the zone.
	if stations_row != null and is_instance_valid(stations_row):
		if stations_row.get_global_rect().grow(24).has_point(screen_pos):
			return STATION_CRAFT
	const PAD := 12.0
	for i in STATION_COUNT:
		var plate: Control = stations[i].get("plate", null)
		if plate != null and is_instance_valid(plate) and plate.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
		var drop_btn: Control = stations[i].get("drop_btn", null)
		if drop_btn != null and is_instance_valid(drop_btn) and drop_btn.visible \
				and drop_btn.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
		var panel: Control = stations[i].get("panel", null)
		if panel != null and is_instance_valid(panel) and panel.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
	return -1


func _is_build_drop_at(screen_pos: Vector2) -> bool:
	## Anywhere on the left side of the screen drops a carried patty onto Build.
	if _station_index_at(screen_pos) >= 0:
		return true
	var vr := get_viewport().get_visible_rect()
	var left_w := maxf(BUILD_DROP_MIN_PX, vr.size.x * BUILD_DROP_SCREEN_FRAC)
	return screen_pos.x <= vr.position.x + left_w


func _blocks_grill_pick(screen_pos: Vector2) -> bool:
	## Build UI is drawn over the grill — block 3D patty picks behind it (incl. yellow selection).
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		var panel: Control = st.get("panel", null)
		var plate: Control = st.get("plate", null)
		var preview: Control = st.get("preview", null)
		var zone := Rect2()
		var has_zone := false
		if plate != null and is_instance_valid(plate):
			zone = plate.get_global_rect()
			has_zone = true
		if preview != null and is_instance_valid(preview):
			for child in preview.get_children():
				if child is Control:
					var cr: Rect2 = child.get_global_rect().grow(6)
					zone = cr if not has_zone else zone.merge(cr)
					has_zone = true
		if panel != null and is_instance_valid(panel):
			var pr := panel.get_global_rect()
			## Title + burger stage — widen so selection chrome can't leak scoops to the grill.
			var stage := Rect2(pr.position.x, pr.position.y, pr.size.x, maxf(pr.size.y - 52.0, 200.0))
			zone = stage if not has_zone else zone.merge(stage)
			has_zone = true
		if has_zone and zone.grow(10).has_point(screen_pos):
			return true
	if stations_row != null and is_instance_valid(stations_row):
		if stations_row.get_global_rect().grow(8).has_point(screen_pos):
			return true
	return false


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
	camera.position = Vector3(0.0, 1.65, -1.62)
	camera.look_at(Vector3(0.0, 1.32, 0.55), Vector3.UP)
	camera.fov = 58.0

	_add_box(world, Vector3(16, 0.05, 10), Vector3(0, -0.02, 4.0), Color("3A3A3A"))
	_build_checkered_floor()

	# Truck shell — black interior walls / ceiling.
	_add_box(world, Vector3(6.5, 0.12, 4.0), Vector3(0, 0.06, -0.4), Color("1A1A1A"))
	_add_box(world, Vector3(0.22, 2.7, 4.0), Vector3(-3.25, 1.35, -0.4), Color("080808"))
	_add_box(world, Vector3(0.22, 2.7, 4.0), Vector3(3.25, 1.35, -0.4), Color("080808"))
	_add_box(world, Vector3(6.5, 2.7, 0.22), Vector3(0, 1.35, -2.35), Color("080808"))
	_add_box(world, Vector3(6.5, 0.16, 4.2), Vector3(0, 2.72, -0.4), Color("050505"))

	# Front wall around window
	_add_box(world, Vector3(1.15, 2.7, 0.2), Vector3(-2.95, 1.35, 1.35), Color("080808"))
	_add_box(world, Vector3(1.15, 2.7, 0.2), Vector3(2.95, 1.35, 1.35), Color("080808"))
	_add_box(world, Vector3(4.8, 0.55, 0.2), Vector3(0, 2.45, 1.35), Color("080808"))
	_add_box(world, Vector3(4.8, 0.7, 0.2), Vector3(0, 0.55, 1.35), Color("0A0A0A"))
	_add_box(world, Vector3(4.9, 0.12, 0.18), Vector3(0, 2.12, 1.38), Color("121212"))
	_add_box(world, Vector3(4.9, 0.12, 0.18), Vector3(0, 0.95, 1.38), Color("121212"))
	_add_box(world, Vector3(0.12, 1.3, 0.18), Vector3(-2.4, 1.55, 1.38), Color("121212"))
	_add_box(world, Vector3(0.12, 1.3, 0.18), Vector3(2.4, 1.55, 1.38), Color("121212"))
	_add_box(world, Vector3(4.8, 0.18, 0.65), Vector3(0, 0.88, 1.1), Color("1C1C1C"))

	# Raised flat-top cabinet — black like the truck walls.
	_add_box(world, Vector3(3.5, 0.95, 1.4), Vector3(0, 0.48, 0.30), Color("080808"))
	## Shelf / face under the griddle (front apron + side gap).
	var shelf := _add_box(grill_root, Vector3(3.3, 0.1, 1.55), Vector3(0, 1.0, 0.18), Color("080808"))
	shelf.material_override.metallic = 0.15
	shelf.material_override.roughness = 0.85
	## Extra front apron so the bright under-grill face stays black.
	_add_box(grill_root, Vector3(3.45, 0.85, 0.12), Vector3(0, 0.55, 0.92), Color("050505"))
	## Fill the left/right gaps beside the grill cabinet.
	_add_box(world, Vector3(0.55, 0.95, 1.4), Vector3(-2.05, 0.48, 0.30), Color("080808"))
	_add_box(world, Vector3(0.55, 0.95, 1.4), Vector3(2.05, 0.48, 0.30), Color("080808"))

	slot_positions.clear()
	slot_areas.clear()
	grill_glow_meshes.clear()
	grill_pad_mats.clear()
	grill_power_labels.clear()
	grill_heat_lights.clear()
	grill_residue.clear()
	grill_residue_meshes.clear()
	grill_residue_mats.clear()
	grill_residue_chunks.clear()
	grill_residue_centers.clear()
	brush_swipe_travel.clear()
	brush_swipe_cool.clear()
	grill_surface_area = null
	grill_surface_mat = null
	grill_glow_root = null
	grill_on = false

	_build_flat_top_grill()
	_build_wire_brush()
	_build_oil_bottle()
	_build_meat_warmer()
	_build_truck_radio_prop()
	_build_season_shaker()

	_add_box(world, Vector3(7, 0.04, 2.4), Vector3(0, 0.02, 2.9), Color("455A64"))
	for i in 3:
		_add_box(world, Vector3(0.35, 0.9, 0.35), Vector3(-2.5 + i * 2.2, 0.45, 4.2), Color("6D4C41"))

	_setup_world_lighting()


func _setup_world_lighting() -> void:
	## Outside sun — cooler daylight through the service window.
	gfx_sun = DirectionalLight3D.new()
	gfx_sun.name = "Sun"
	gfx_sun.light_color = Color(1.0, 0.96, 0.88)
	gfx_sun.light_energy = 1.55
	gfx_sun.light_indirect_energy = 1.15
	gfx_sun.shadow_enabled = true
	gfx_sun.shadow_blur = 1.2
	gfx_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	gfx_sun.rotation_degrees = Vector3(-48.0, 35.0, 8.0)
	world.add_child(gfx_sun)

	## Soft outdoor bounce so customers aren't harsh-lit.
	gfx_outside_fill = DirectionalLight3D.new()
	gfx_outside_fill.name = "OutsideFill"
	gfx_outside_fill.light_color = Color(0.55, 0.68, 0.95)
	gfx_outside_fill.light_energy = 0.35
	gfx_outside_fill.shadow_enabled = false
	gfx_outside_fill.rotation_degrees = Vector3(-25.0, -140.0, 0.0)
	world.add_child(gfx_outside_fill)

	## Warm kitchen ceiling fill (inside the truck).
	gfx_kitchen = OmniLight3D.new()
	gfx_kitchen.name = "KitchenFill"
	gfx_kitchen.light_color = Color(1.0, 0.88, 0.72)
	gfx_kitchen.light_energy = 1.65
	gfx_kitchen.omni_range = 5.5
	gfx_kitchen.omni_attenuation = 1.15
	gfx_kitchen.shadow_enabled = true
	gfx_kitchen.position = Vector3(0.0, 2.45, -0.35)
	world.add_child(gfx_kitchen)

	## Focused grill work light — reads heat + metal reflections.
	gfx_grill_lamp = SpotLight3D.new()
	gfx_grill_lamp.name = "GrillLamp"
	gfx_grill_lamp.light_color = Color(1.0, 0.92, 0.78)
	gfx_grill_lamp.light_energy = 1.35
	gfx_grill_lamp.spot_range = 3.2
	gfx_grill_lamp.spot_angle = 42.0
	gfx_grill_lamp.spot_attenuation = 0.9
	gfx_grill_lamp.shadow_enabled = true
	gfx_grill_lamp.position = Vector3(GRILL_CENTER_X, 2.35, GRILL_SURFACE_Z - 0.15)
	gfx_grill_lamp.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	world.add_child(gfx_grill_lamp)

	## Window wash — daylight spilling onto the counter from outside.
	gfx_window_wash = SpotLight3D.new()
	gfx_window_wash.name = "WindowWash"
	gfx_window_wash.light_color = Color(0.75, 0.88, 1.0)
	gfx_window_wash.light_energy = 1.1
	gfx_window_wash.spot_range = 4.0
	gfx_window_wash.spot_angle = 50.0
	gfx_window_wash.shadow_enabled = false
	gfx_window_wash.position = Vector3(0.0, 1.9, 1.55)
	gfx_window_wash.rotation_degrees = Vector3(-25.0, 180.0, 0.0)
	world.add_child(gfx_window_wash)

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.28
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 1.0
	## Ambient occlusion — contact shadows in the kitchen / under patties.
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.35
	env.ssao_power = 1.55
	env.ssao_horizon = 0.06
	env.ssil_enabled = true
	env.ssil_intensity = 0.65
	env.ssil_radius = 1.0
	env.glow_enabled = true
	env.glow_intensity = 1.05
	env.glow_strength = 1.35
	env.glow_bloom = 0.32
	env.glow_hdr_threshold = 0.55
	env.glow_hdr_scale = 1.65
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	gfx_env = env

	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var hdr_tex = load("res://assets/hdri/kloppenheim_06_1k.hdr")
	if hdr_tex != null:
		panorama.panorama = hdr_tex
		panorama.energy_multiplier = 0.42
		gfx_sky_mat = panorama
		sky.sky_material = panorama
	else:
		## Fallback procedural sky if HDRI missing.
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.35, 0.55, 0.92)
		proc.sky_horizon_color = Color(0.78, 0.86, 0.95)
		proc.ground_bottom_color = Color(0.22, 0.24, 0.26)
		proc.ground_horizon_color = Color(0.55, 0.58, 0.62)
		proc.sun_angle_max = 30.0
		sky.sky_material = proc
	env.sky = sky
	env.sky_rotation = Vector3(0.0, deg_to_rad(40.0), 0.0)
	env_node.environment = env
	add_child(env_node)


func _build_flat_top_grill() -> void:
	## One continuous steel top — up to 4 auto-spaced patty slots.
	var surface := Area3D.new()
	surface.position = Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z)
	surface.input_ray_pickable = true
	surface.collision_layer = 1
	surface.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GRILL_WIDTH, 0.12, GRILL_DEPTH)
	shape.shape = box
	surface.add_child(shape)

	## Dark rim
	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(GRILL_WIDTH + 0.06, 0.035, GRILL_DEPTH + 0.06)
	rim.mesh = rim_mesh
	rim.position = Vector3(0, -0.01, 0)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.32, 0.35, 0.38)
	rim_mat.metallic = 0.9
	rim_mat.roughness = 0.28
	rim_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	rim.material_override = rim_mat
	surface.add_child(rim)

	## Heat-zone steel panels — FULL · 1/4 · 1/8 · HOLD (screen-left → right).
	var bands: Array = _grill_zone_bands()
	grill_surface_mat = null
	grill_glow_meshes.clear()
	var heat_tex := _make_grill_heat_texture()
	var cook_x0 := 0.0
	var cook_x1 := 0.0
	var cook_started := false
	for z in bands:
		var local_cx := float(z["cx"]) - GRILL_CENTER_X
		var zw := float(z["w"])
		var mat := _make_grill_zone_metal(z["col"], float(z["rough"]), float(z["emit"]))
		_add_grill_zone_panel(surface, Vector3(local_cx, 0, 0), Vector3(zw, 0.045, GRILL_DEPTH), mat)
		grill_pad_mats.append(mat)
		if str(z["id"]) == "full":
			grill_surface_mat = mat
		if float(z["mul"]) > 0.0:
			if not cook_started:
				cook_x0 = float(z["x0"])
				cook_x1 = float(z["x1"])
				cook_started = true
			else:
				cook_x0 = minf(cook_x0, float(z["x0"]))
				cook_x1 = maxf(cook_x1, float(z["x1"]))
			var glow_w := zw * 0.78
			_add_heat_glow(
				surface,
				Vector3(local_cx, 0.027, 0),
				glow_w,
				GRILL_DEPTH * 0.7,
				float(z["glow"]),
				heat_tex
			)

	if grill_surface_mat == null:
		grill_surface_mat = StandardMaterial3D.new()
		grill_surface_mat.albedo_color = Color(0.28, 0.3, 0.33)
		grill_surface_mat.metallic = 1.0
		grill_surface_mat.roughness = 0.22

	## Big fake brushed-steel shine across the whole flat-top.
	_add_grill_shine(surface, Vector3(0, 0.024, 0), GRILL_WIDTH * 0.98, GRILL_DEPTH * 0.42)

	## Spill omnis kept off — bloom made them look like hot orbs.
	var cook_cx_world := (cook_x0 + cook_x1) * 0.5 if cook_started else GRILL_CENTER_X
	var cook_w := maxf(0.2, cook_x1 - cook_x0) if cook_started else GRILL_WIDTH * 0.7
	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.55, 0.22)
	heat.light_energy = 0.0
	heat.visible = false
	heat.omni_range = 1.0
	heat.position = Vector3(cook_cx_world - GRILL_CENTER_X, 0.14, 0)
	surface.add_child(heat)
	grill_heat_lights.append(heat)

	## Heat shimmer / warp over the three cook bands (not HOLD).
	_build_heat_warp_plane(
		surface,
		Vector3(cook_cx_world - GRILL_CENTER_X, 0.18, 0),
		cook_w * 0.92,
		GRILL_DEPTH * 0.82
	)
	grill_glow_root = grill_glow_meshes[0] if not grill_glow_meshes.is_empty() else null

	## Clicks handled in _unhandled_input → _try_grill_raycast (avoid double spawn).
	grill_root.add_child(surface)
	grill_surface_area = surface
	slot_areas.append(surface)

	## Residue chunk piles (one set per max patty) — chipped away with the scraper.
	for i in GRILL_SLOTS:
		grill_residue.append(0.0)
		grill_residue_chunks.append([])
		grill_residue_centers.append(Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z))
		brush_swipe_travel.append(0.0)
		brush_swipe_cool.append(0.0)
		slot_positions.append(Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z))
		_make_slot_residue(i)


func _grill_place_bounds() -> Rect2:
	## Valid centers where a full patty still sits on the steel (inset from edges).
	var half_w := GRILL_WIDTH * 0.5 - PATTY_FIT_RADIUS
	var half_d := GRILL_DEPTH * 0.5 - PATTY_FIT_RADIUS
	return Rect2(
		GRILL_CENTER_X - half_w,
		GRILL_SURFACE_Z - half_d,
		half_w * 2.0,
		half_d * 2.0
	)


func _cook_place_bounds() -> Rect2:
	## Raw patty spawn area — full steel minus the HOLD strip.
	var b := _grill_place_bounds()
	var warm := _warmer_rect()
	var hold_end := warm.position.x + warm.size.x
	var cook_min_x := maxf(b.position.x, hold_end + 0.02)
	var w := b.end.x - cook_min_x
	if w < 0.08:
		return b
	return Rect2(cook_min_x, b.position.y, w, b.size.y)


func _is_on_grill_surface(world_pos: Vector3) -> bool:
	## Anywhere on the steel plate (including rim) — used for click-on-grill checks.
	return absf(world_pos.x - GRILL_CENTER_X) <= GRILL_WIDTH * 0.5 + 0.02 \
		and absf(world_pos.z - GRILL_SURFACE_Z) <= GRILL_DEPTH * 0.5 + 0.02


func _is_near_grill_for_place(world_pos: Vector3) -> bool:
	## Forgiving right-click — near-misses still snap onto the cook surface.
	return absf(world_pos.x - GRILL_CENTER_X) <= GRILL_WIDTH * 0.5 + 0.42 \
		and absf(world_pos.z - GRILL_SURFACE_Z) <= GRILL_DEPTH * 0.5 + 0.42


func _can_fit_patty_at(world_pos: Vector3) -> bool:
	## Reject rim clicks — patty must fit entirely on the grill.
	return _grill_place_bounds().has_point(Vector2(world_pos.x, world_pos.z))


func _patty_blocked_at(world_pos: Vector3, ignore_idx: int = -1) -> bool:
	for i in GRILL_SLOTS:
		if i == ignore_idx:
			continue
		var p = grill[i]
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		var d := Vector2(world_pos.x - p.position.x, world_pos.z - p.position.z).length()
		if d < PATTY_MIN_SEP:
			return true
	return false


func _make_slot_residue(index: int) -> void:
	## Placeholder so legacy arrays stay sized; real bits spawn per scoop.
	var residue := MeshInstance3D.new()
	residue.visible = false
	grill_root.add_child(residue)
	grill_residue_meshes.append(residue)
	grill_residue_mats.append(StandardMaterial3D.new())


func _clear_residue_chunks(slot: int) -> void:
	if slot < 0 or slot >= grill_residue_chunks.size():
		return
	for ch in grill_residue_chunks[slot]:
		if ch != null and is_instance_valid(ch):
			ch.queue_free()
	grill_residue_chunks[slot] = []


func _spawn_residue_chunks(slot: int, at: Vector3) -> void:
	_clear_residue_chunks(slot)
	if slot >= grill_residue_centers.size():
		return
	grill_residue_centers[slot] = at
	var rng := RandomNumberGenerator.new()
	rng.seed = slot * 917 + int(at.x * 1000.0) + int(at.z * 1000.0)
	var chunks: Array = []

	## Main burnt disc — patty-shaped stain with noisy bite marks.
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var disc_d := 0.195 + rng.randf() * 0.025
	plane.size = Vector2(disc_d, disc_d)
	disc.mesh = plane
	disc.position = at + Vector3(0, 0.0012, 0)
	disc.rotation_degrees = Vector3(0, rng.randf() * 360.0, 0)
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	dmat.albedo_texture = _make_residue_texture(rng.randi())
	dmat.albedo_color = Color(1, 1, 1, 0.92)
	disc.material_override = dmat
	grill_root.add_child(disc)
	chunks.append(disc)

	## A few crumb flecks the scraper can chip off.
	var n := RESIDUE_CHUNK_COUNT + rng.randi_range(-1, 2)
	for _i in n:
		var bit := MeshInstance3D.new()
		var roll := rng.randf()
		var mesh: Mesh
		if roll > 0.45:
			var cyl := CylinderMesh.new()
			var r := 0.008 + rng.randf() * 0.012
			cyl.top_radius = r * (0.65 + rng.randf() * 0.35)
			cyl.bottom_radius = r
			cyl.height = 0.0025 + rng.randf() * 0.003
			cyl.radial_segments = 8
			mesh = cyl
		else:
			var box := BoxMesh.new()
			box.size = Vector3(
				0.01 + rng.randf() * 0.016,
				0.002 + rng.randf() * 0.0025,
				0.008 + rng.randf() * 0.014
			)
			mesh = box
		bit.mesh = mesh
		var ang := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * (disc_d * 0.38)
		bit.position = at + Vector3(cos(ang) * rad, 0.002 + rng.randf() * 0.002, sin(ang) * rad)
		bit.rotation_degrees = Vector3(
			rng.randf_range(-12.0, 12.0),
			rng.randf() * 360.0,
			rng.randf_range(-12.0, 12.0)
		)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var shade := rng.randf()
		if shade > 0.55:
			mat.albedo_color = Color(0.07, 0.03, 0.02, 0.92)
		elif shade > 0.25:
			mat.albedo_color = Color(0.2, 0.09, 0.04, 0.88)
		else:
			mat.albedo_color = Color(0.34, 0.15, 0.07, 0.8)
		bit.material_override = mat
		grill_root.add_child(bit)
		chunks.append(bit)
	grill_residue_chunks[slot] = chunks


func _scrape_residue_hit(slot: int, swipe_dir: Vector2 = Vector2.ZERO) -> void:
	## Chip flecks in the swipe direction; progressive clean uses continuous scrape.
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	var amt: float = float(grill_residue[slot])
	if amt <= 0.04:
		_scrape_finish_clean(slot)
		return
	var dir := swipe_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	dir = dir.normalized()
	var chunks: Array = grill_residue_chunks[slot]
	var survivors: Array = []
	var chipped := 0
	for i in chunks.size():
		var ch = chunks[i]
		if ch == null or not is_instance_valid(ch):
			continue
		## Keep the main disc; fling flecks away along the swipe.
		if i == 0:
			survivors.append(ch)
			continue
		if randf() < 0.55 + (1.0 - amt) * 0.35:
			var kick := Vector3(dir.x, 0.0, dir.y) * (0.07 + randf() * 0.1)
			kick.y = 0.035 + randf() * 0.05
			var fly: Vector3 = ch.position + kick
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(ch, "position", fly, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(ch, "scale", Vector3(0.15, 0.15, 0.15), 0.2)
			tw.tween_property(ch, "rotation_degrees", ch.rotation_degrees + Vector3(randf_range(-80, 80), randf_range(-120, 120), 0), 0.2)
			tw.chain().tween_callback(ch.queue_free)
			chipped += 1
		else:
			survivors.append(ch)
	grill_residue_chunks[slot] = survivors
	_refresh_residue_visual(slot)
	if game_audio:
		if game_audio.has_method("play_grease_pop"):
			game_audio.play_grease_pop()
		else:
			game_audio.play_click()
	if amt <= 0.2 and chipped > 0:
		_flash("Almost clean — keep swiping", Color("FFE082"))


func _scrape_finish_clean(slot: int) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	var chunks: Array = grill_residue_chunks[slot] if slot < grill_residue_chunks.size() else []
	for ch in chunks:
		if ch == null or not is_instance_valid(ch):
			continue
		var fly := ch.position + Vector3(randf_range(-0.1, 0.1), 0.06, randf_range(-0.1, 0.1))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(ch, "position", fly, 0.16)
		tw.tween_property(ch, "scale", Vector3(0.12, 0.12, 0.12), 0.16)
		tw.chain().tween_callback(ch.queue_free)
	grill_residue_chunks[slot] = []
	grill_residue[slot] = 0.0
	if slot < brush_swipe_travel.size():
		brush_swipe_travel[slot] = 0.0
	_flash("Grill spot clean!", Color("A5D6A7"))
	if game_audio:
		game_audio.play_click()


func _build_grill_burner_ui() -> void:
	## HUD burner toggle for the flat-top.
	if grill_power_row == null:
		return
	for child in grill_power_row.get_children():
		child.queue_free()
	grill_ui_buttons.clear()
	grill_trash_btn = null
	grill_power_row.visible = true
	grill_power_row.mouse_filter = Control.MOUSE_FILTER_STOP

	var btn := Button.new()
	btn.text = "BURNER: OFF"
	btn.custom_minimum_size = Vector2(140, 28)
	btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(btn, true, 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.12, 0.1)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.25, 0.15)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.48, 0.16, 0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(1, 0.85, 0.75))
	btn.pressed.connect(func():
		_sfx_click()
		_toggle_grill_power(0)
	)
	grill_power_row.add_child(btn)
	grill_ui_buttons.append(btn)

	var trash := Button.new()
	trash.text = "🗑 GARBAGE"
	trash.tooltip_text = "Drag a patty here to toss it"
	trash.custom_minimum_size = Vector2(120, 28)
	trash.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(trash, true, 13)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.22, 0.22, 0.24)
	tsb.set_corner_radius_all(10)
	tsb.set_border_width_all(2)
	tsb.border_color = Color(0.55, 0.55, 0.58)
	tsb.content_margin_left = 12
	tsb.content_margin_right = 12
	tsb.content_margin_top = 6
	tsb.content_margin_bottom = 6
	trash.add_theme_stylebox_override("normal", tsb)
	var thov := tsb.duplicate()
	thov.bg_color = Color(0.38, 0.18, 0.16)
	thov.border_color = Color(0.9, 0.45, 0.35)
	trash.add_theme_stylebox_override("hover", thov)
	trash.add_theme_color_override("font_color", Color(0.95, 0.92, 0.9))
	trash.pressed.connect(func():
		_sfx_click()
		if spatula_patty != null:
			_trash_spatula_patty()
		else:
			_flash("Drag a patty onto GARBAGE to toss it", Color("FFCC80"))
	)
	trash.set_drag_forwarding(
		Callable(),
		func(_pos, data): return _can_drop_patty_on_garbage(data),
		func(_pos, data): _drop_patty_on_garbage(data)
	)
	grill_power_row.add_child(trash)
	grill_trash_btn = trash

	_refresh_grill_ui_button(0)


func _is_over_garbage(screen_pos: Vector2) -> bool:
	if grill_trash_btn == null or not is_instance_valid(grill_trash_btn):
		return false
	var r := grill_trash_btn.get_global_rect().grow(10.0)
	return r.has_point(screen_pos)


func _can_drop_patty_on_garbage(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = data.get("kind", "")
	return kind == "station_patty" or kind == "reorder"


func _drop_patty_on_garbage(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var kind: String = data.get("kind", "")
	if kind == "station_patty":
		var st_i := int(data.get("station", -1))
		var from_i := int(data.get("from", -1))
		var patty = _extract_station_patty(st_i, from_i)
		if patty != null and is_instance_valid(patty):
			patty.queue_free()
			if game_audio and game_audio.has_method("play_trash"):
				game_audio.play_trash()
			_flash("Trashed a patty", Color("FFAB91"))
		return
	if kind == "reorder":
		var st2 := int(data.get("station", -1))
		var from2 := int(data.get("from", -1))
		if st2 < 0 or st2 >= STATION_COUNT:
			return
		_select_station(st2)
		stations[st2]["selected_layer"] = from2
		_trash_selected_or_top_layer(st2)


func _trash_spatula_patty() -> void:
	if spatula_patty == null:
		_flash("Nothing on the spatula to trash", Color("B0BEC5"))
		return
	if is_instance_valid(spatula_patty):
		spatula_patty.queue_free()
	spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	if game_audio and game_audio.has_method("play_trash"):
		game_audio.play_trash()
	_flash("Trashed scooped patty", Color("FFAB91"))


func _trash_single_grill_patty(patty: Area3D) -> void:
	## Toss one grill patty — does not clear the whole flat-top.
	if patty == null or not is_instance_valid(patty):
		return
	if dragging_patty == patty:
		dragging_patty = null
		drag_did_move = false
		if game_audio:
			game_audio.set_slide_moving(false)
	var idx: int = int(patty.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == patty:
		grill[idx] = null
	patty.queue_free()
	if game_audio and game_audio.has_method("play_trash"):
		game_audio.play_trash()
	_flash("Trashed a patty", Color("FFAB91"))


func _trash_grill_patties() -> void:
	## Legacy no-op — use drag-to-garbage for one patty at a time.
	_flash("Drag a patty onto GARBAGE to toss it", Color("FFCC80"))


func _hide_grill_power_ui() -> void:
	if grill_power_row:
		for child in grill_power_row.get_children():
			child.queue_free()
		grill_power_row.visible = false
	grill_ui_buttons.clear()
	grill_trash_btn = null


func _refresh_grill_ui_button(_index: int) -> void:
	if grill_ui_buttons.is_empty():
		return
	var btn: Button = grill_ui_buttons[0]
	if grill_on:
		btn.text = "BURNER: ON"
		var on_sb := StyleBoxFlat.new()
		on_sb.bg_color = Color(0.75, 0.22, 0.1)
		on_sb.set_corner_radius_all(10)
		on_sb.set_border_width_all(2)
		on_sb.border_color = Color(1.0, 0.55, 0.2)
		on_sb.content_margin_left = 14
		on_sb.content_margin_right = 14
		on_sb.content_margin_top = 6
		on_sb.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", on_sb)
		var hover := on_sb.duplicate()
		hover.bg_color = Color(0.9, 0.3, 0.12)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	else:
		btn.text = "BURNER: OFF"
		var off_sb := StyleBoxFlat.new()
		off_sb.bg_color = Color(0.35, 0.12, 0.1)
		off_sb.set_corner_radius_all(10)
		off_sb.set_border_width_all(2)
		off_sb.border_color = Color(0.7, 0.25, 0.15)
		off_sb.content_margin_left = 14
		off_sb.content_margin_right = 14
		off_sb.content_margin_top = 6
		off_sb.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", off_sb)
		var hover2 := off_sb.duplicate()
		hover2.bg_color = Color(0.48, 0.16, 0.12)
		btn.add_theme_stylebox_override("hover", hover2)
		btn.add_theme_color_override("font_color", Color(1, 0.85, 0.75))


func _toggle_grill_power(_index: int) -> void:
	if not playing:
		return
	grill_ignore_pad_until = Time.get_ticks_msec() / 1000.0 + 0.35
	_sfx_click()
	_set_grill_on(not grill_on)
	if grill_on:
		_flash("Burner ON — right-click the grill where you want each patty", Color("FFCC80"))
	else:
		_flash("Burner OFF", Color("B0BEC5"))


func _set_grill_on(on: bool) -> void:
	grill_on = on
	for i in GRILL_SLOTS:
		grill_powered[i] = on
	if grill_glow_root != null and is_instance_valid(grill_glow_root):
		grill_glow_root.visible = on
	for glow in grill_glow_meshes:
		if is_instance_valid(glow):
			glow.visible = on
	for heat in grill_heat_lights:
		if is_instance_valid(heat):
			heat.light_energy = 0.0
			heat.visible = false
	## Zone steel keeps a warm emission wash when the burner is on.
	for mat in grill_pad_mats:
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			sm.emission_enabled = on and sm.emission_energy_multiplier > 0.01
	_update_kitchen_sizzle()
	_refresh_grill_ui_button(0)


func _set_grill_power(_index: int, on: bool) -> void:
	## Shared burner — any slot toggle sets the whole flat top.
	_set_grill_on(on)


func _on_grill_surface_clicked(place_patty: bool, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not playing:
		return
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	if not place_patty:
		var picked = _pick_patty_at_screen(get_viewport().get_mouse_position())
		if picked != null:
			_begin_patty_drag(picked)
			return
		if hit_pos != Vector3.ZERO:
			var near := _nearest_patty_to(hit_pos, PATTY_PICK_WORLD)
			if near >= 0:
				_begin_patty_drag(grill[near])
				return
		if grill_on:
			_flash("Right-click where you want the patty", Color("FFCC80"))
		else:
			_flash("Turn the BURNER ON first", Color("FFA726"))
		return
	_try_place_patty_at(hit_pos)


func _pick_patty_at_screen(screen_pos: Vector2):
	## Aim at the grill plane, then pick the patty under the cursor — not just the front ray hit.
	if _blocks_grill_pick(screen_pos):
		return null
	if camera == null:
		return null
	var plane_hit := _grill_plane_from_screen(screen_pos)
	var cam_pos := camera.global_position
	var candidates: Array = []
	for p in grill:
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		var lift: Vector3 = p.global_position + Vector3(0, 0.03, 0)
		if camera.is_position_behind(lift):
			continue
		var screen_pt := camera.unproject_position(lift)
		var pick_px := maxf(PATTY_PICK_MIN_PX, _patty_screen_pick_radius_px(lift))
		## Also accept near-misses via world distance on the grill plane.
		var near_plane := false
		if plane_hit != Vector3.ZERO:
			near_plane = Vector2(plane_hit.x - p.position.x, plane_hit.z - p.position.z).length() <= PATTY_PICK_WORLD
		if screen_pos.distance_to(screen_pt) > pick_px and not near_plane:
			continue
		candidates.append(p)
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	candidates.sort_custom(func(a, b):
		var da := 999.0
		var db := 999.0
		if plane_hit != Vector3.ZERO:
			da = Vector2(plane_hit.x - a.position.x, plane_hit.z - a.position.z).length()
			db = Vector2(plane_hit.x - b.position.x, plane_hit.z - b.position.z).length()
		if absf(da - db) > 0.04:
			return da < db
		## Overlapping stack — prefer the patty farther from the camera (click-through).
		return cam_pos.distance_to(a.global_position) > cam_pos.distance_to(b.global_position)
	)
	return candidates[0]


func _patty_screen_pick_radius_px(world_pt: Vector3) -> float:
	var edge := world_pt + Vector3(PATTY_PICK_WORLD_EDGE, 0, 0)
	var c2 := camera.unproject_position(world_pt)
	var e2 := camera.unproject_position(edge)
	return c2.distance_to(e2) + PATTY_PICK_PAD_PX


func _nudge_to_open_grill_spot(desired: Vector3) -> Vector3:
	## Snap to the nearest open cook spot instead of rejecting the click.
	return _find_closest_patty_place(desired)


func _find_closest_patty_place(desired: Vector3) -> Vector3:
	## Closest free cook-zone center to the click (rim / HOLD / crowding all snap).
	var cook := _cook_place_bounds()
	if cook.size.x < 0.05 or cook.size.y < 0.05:
		return Vector3.ZERO
	var aim := Vector3(
		clampf(desired.x, cook.position.x, cook.end.x),
		GRILL_SURFACE_Y,
		clampf(desired.z, cook.position.y, cook.end.y)
	)
	if not _patty_blocked_at(aim):
		return aim
	var best := Vector3.ZERO
	var best_d2 := INF
	## Expanding rings from the aim point — prefer nearer openings.
	for ring_i in 28:
		var ring := 0.035 + float(ring_i) * 0.04
		var segs := mini(28, 10 + ring_i * 2)
		for seg in segs:
			var ang := float(seg) / float(segs) * TAU
			var try := Vector3(
				clampf(aim.x + cos(ang) * ring, cook.position.x, cook.end.x),
				GRILL_SURFACE_Y,
				clampf(aim.z + sin(ang) * ring, cook.position.y, cook.end.y)
			)
			if _patty_blocked_at(try):
				continue
			var d2 := Vector2(try.x - desired.x, try.z - desired.z).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best = try
		## Early out once we found something close on an inner ring.
		if best != Vector3.ZERO and ring > 0.2 and best_d2 < ring * ring * 1.5:
			return best
	if best != Vector3.ZERO:
		return best
	## Whole-area grid fallback — any open cook spot nearest the click.
	var gx := 10
	var gz := 6
	for ix in gx:
		for iz in gz:
			var u := (float(ix) + 0.5) / float(gx)
			var v := (float(iz) + 0.5) / float(gz)
			var try2 := Vector3(
				lerpf(cook.position.x, cook.end.x, u),
				GRILL_SURFACE_Y,
				lerpf(cook.position.y, cook.end.y, v)
			)
			if _patty_blocked_at(try2):
				continue
			var d2b := Vector2(try2.x - desired.x, try2.z - desired.z).length_squared()
			if d2b < best_d2:
				best_d2 = d2b
				best = try2
	return best


func _on_grill_slot_clicked(_index: int, place_patty: bool = false) -> void:
	## Legacy entry — free placement uses surface clicks now.
	if place_patty:
		_try_place_patty_at(Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z))
	else:
		_on_grill_surface_clicked(false, Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z))


func _nearest_patty_to(world_pos: Vector3, max_d: float) -> int:
	var best := -1
	var best_d := max_d
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p):
			continue
		var d := Vector2(world_pos.x - p.position.x, world_pos.z - p.position.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func _try_place_patty_at(world_pos: Vector3) -> void:
	if not playing:
		return
	if not grill_on:
		_flash("Turn the BURNER ON first", Color("FFA726"))
		return
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill is full (%d patties)!" % GRILL_SLOTS, Color("EF5350"))
		return
	## Forgiving: near-miss / rim / HOLD / crowded → snap to closest good cook spot.
	if world_pos == Vector3.ZERO or not _is_near_grill_for_place(world_pos):
		_flash("Click near the grill surface", Color("FFA726"))
		return
	var place_pos := _find_closest_patty_place(world_pos)
	if place_pos == Vector3.ZERO:
		_flash("No open spot — clear some space", Color("EF5350"))
		return
	_spawn_patty_at(idx, place_pos)


func _spawn_patty_at(idx: int, world_pos: Vector3) -> void:
	if not playing:
		return
	if idx < 0 or idx >= GRILL_SLOTS:
		return
	if grill[idx] != null:
		return
	if not grill_on:
		_flash("Burner is OFF", Color("FFA726"))
		return
	var x := world_pos.x
	var z := world_pos.z
	var p = PattyScript.new()
	p.slot_index = idx
	p.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	p.heating = true
	p.position = Vector3(x, p.base_y, z)
	p._rest_x = x
	p._rest_z = z
	patties_root.add_child(p)
	grill[idx] = p
	slot_positions[idx] = Vector3(x, GRILL_SURFACE_Y, z)
	p.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	var n := 0
	for i in GRILL_SLOTS:
		if grill[i] != null:
			n += 1
	if _is_in_warmer_zone(world_pos):
		_flash("HOLD zone — park cooked meat here (up to 5 min)", Color("90CAF9"))
	else:
		var zone := _grill_zone_at(world_pos)
		var lab := str(zone.get("label", "FULL"))
		var mul := float(zone.get("mul", 1.0))
		if mul < 0.99:
			_flash("Cooking on %s heat (%d/%d) — slower sear" % [lab, n, GRILL_SLOTS], Color("FFCC80"))
		else:
			_flash("Cooking on FULL! %d/%d — wait for FLIP" % [n, GRILL_SLOTS], Color("FFAB91"))


func _spawn_patty_in_slot(idx: int) -> void:
	## Fallback: drop near grill center if something still calls slot spawn.
	var bounds := _grill_place_bounds()
	var pos := Vector3(bounds.get_center().x, GRILL_SURFACE_Y, bounds.get_center().y)
	for _try in 8:
		if not _patty_blocked_at(pos):
			break
		pos.x = lerpf(bounds.position.x, bounds.end.x, randf())
		pos.z = lerpf(bounds.position.y, bounds.end.y, randf())
	_spawn_patty_at(idx, pos)


func _begin_patty_drag(patty: Area3D) -> void:
	if not playing or patty == null or not is_instance_valid(patty):
		return
	## Holding a scooped patty: still flip others on the grill; scooping another is blocked.
	if spatula_patty != null:
		_on_patty_clicked(patty)
		return
	if brush_held or cheese_held or shaker_held or oil_held:
		return
	if flicking_patty != null:
		return
	if patty.is_held:
		return
	if dragging_patty == patty:
		return
	dragging_patty = patty
	drag_start_mouse = get_viewport().get_mouse_position()
	drag_last_mouse = drag_start_mouse
	drag_vel_screen = Vector2.ZERO
	drag_did_move = false
	drag_pop_accum = 0.0
	drag_last_xz = Vector2(patty._rest_x, patty._rest_z)


func _grill_plane_from_screen(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return Vector3.ZERO
	var t := (GRILL_SURFACE_Y - from.y) / dir.y
	if t <= 0.0:
		return Vector3.ZERO
	return from + dir * t


func _update_patty_drag(delta: float = 0.016) -> void:
	if dragging_patty == null or not is_instance_valid(dragging_patty):
		dragging_patty = null
		if game_audio:
			game_audio.set_slide_moving(false)
		return
	var mouse := get_viewport().get_mouse_position()
	var dt := maxf(delta, 0.001)
	var instant_vel := (mouse - drag_last_mouse) / dt
	drag_vel_screen = drag_vel_screen.lerp(instant_vel, clampf(dt * 18.0, 0.0, 1.0))
	drag_last_mouse = mouse
	if not drag_did_move and mouse.distance_to(drag_start_mouse) >= DRAG_MOVE_THRESH_PX:
		drag_did_move = true
	if not drag_did_move:
		if game_audio:
			game_audio.set_slide_moving(false)
		return
	## Over Build while dragging a finished patty — keep tracking; drop/flick on release.
	if _station_index_at(mouse) >= 0 and dragging_patty.can_scoop():
		if game_audio:
			game_audio.set_slide_moving(false)
		return
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		if game_audio:
			game_audio.set_slide_moving(false)
		return
	var bounds := _grill_place_bounds()
	var x := clampf(hit.x, bounds.position.x, bounds.end.x)
	var z := clampf(hit.z, bounds.position.y, bounds.end.y)
	var target := Vector3(x, GRILL_SURFACE_Y, z)
	var ignore_idx: int = dragging_patty.slot_index
	if _patty_blocked_at(target, ignore_idx):
		var from := drag_last_xz
		var delta_xz := Vector2(x - from.x, z - from.y)
		var found_slide := false
		if delta_xz.length_squared() > 0.000001:
			for frac in [1.0, 0.85, 0.7, 0.55, 0.4, 0.25]:
				var try := Vector3(
					from.x + delta_xz.x * frac,
					GRILL_SURFACE_Y,
					from.y + delta_xz.y * frac
				)
				try.x = clampf(try.x, bounds.position.x, bounds.end.x)
				try.z = clampf(try.z, bounds.position.y, bounds.end.y)
				if not _patty_blocked_at(try, ignore_idx):
					target = try
					found_slide = true
					break
		if not found_slide:
			var try_x := Vector3(x, GRILL_SURFACE_Y, from.y)
			var try_z := Vector3(from.x, GRILL_SURFACE_Y, z)
			if not _patty_blocked_at(try_x, ignore_idx):
				target = try_x
			elif not _patty_blocked_at(try_z, ignore_idx):
				target = try_z
			else:
				target = Vector3(from.x, GRILL_SURFACE_Y, from.y)
	var move_vec := Vector2(target.x - drag_last_xz.x, target.z - drag_last_xz.y)
	var moved := move_vec.length()
	dragging_patty._rest_x = target.x
	dragging_patty._rest_z = target.z
	dragging_patty.position.x = target.x
	dragging_patty.position.z = target.z
	var idx: int = dragging_patty.slot_index
	if idx >= 0 and idx < slot_positions.size():
		slot_positions[idx] = Vector3(target.x, GRILL_SURFACE_Y, target.z)
	drag_last_xz = Vector2(target.x, target.z)
	if game_audio:
		var speed := moved / dt
		game_audio.set_slide_moving(true, clampf(speed * 0.35, 0.0, 1.2))
	drag_pop_accum += moved
	while drag_pop_accum >= DRAG_POP_DIST:
		drag_pop_accum -= DRAG_POP_DIST
		_smear_oil_along(Vector3(target.x, GRILL_SURFACE_Y + OIL_SIT_Y, target.z), move_vec, moved)
		if game_audio and randf() < 0.45:
			if randf() < 0.5:
				game_audio.play_grease_pop()
			if randf() < 0.25:
				game_audio.play_grease_pop()


func _end_patty_drag() -> void:
	if dragging_patty == null:
		return
	var patty = dragging_patty
	var slid := drag_did_move
	var mouse := get_viewport().get_mouse_position()
	var vel := drag_vel_screen
	var travel := mouse.distance_to(drag_start_mouse)
	dragging_patty = null
	drag_did_move = false
	drag_vel_screen = Vector2.ZERO
	if game_audio:
		game_audio.set_slide_moving(false)
	if not is_instance_valid(patty):
		return
	## Drag onto GARBAGE to toss this one patty.
	if _is_over_garbage(mouse):
		_trash_single_grill_patty(patty)
		return
	## Tap without sliding → flip / scoop as before.
	if not slid:
		_on_patty_clicked(patty)
		return
	## Flick left with a finished patty → jump arc onto Build.
	if _is_flick_to_build(vel, travel) and patty.can_scoop():
		_flick_patty_to_build(patty)
		return
	## Drag onto Build UI / left side of screen → scoop + drop in one motion (if ready).
	if _is_build_drop_at(mouse):
		_try_drag_patty_to_station(patty, STATION_CRAFT)
		return
	if _is_in_warmer_zone(patty.position):
		var left := maxi(0, int(ceil(WARM_HOLD_MAX - float(patty.warm_hold_time))))
		_flash("HOLD — keeps warm %ds left (no cooking)" % left, Color("90CAF9"))
	else:
		var z := _grill_zone_at(patty.position)
		if not z.is_empty() and float(z["mul"]) < 0.99:
			_flash("%s heat — cooks slower" % str(z["label"]), Color("FFCC80"))


func _is_flick_to_build(vel: Vector2, travel_px: float) -> bool:
	if travel_px < FLICK_MIN_TRAVEL_PX:
		return false
	if vel.length() < FLICK_MIN_SPEED:
		return false
	## Screen-left toss (Build lives on the left).
	return vel.x <= FLICK_TO_BUILD_VX and absf(vel.x) >= absf(vel.y) * 0.55


func _reject_second_scoop(msg: String = "Already holding a patty — drop on Build or the Warmer") -> void:
	_flash(msg, Color("EF5350"))
	if game_audio and game_audio.has_method("play_error"):
		game_audio.play_error()


func _flick_patty_to_build(patty: Area3D) -> void:
	if patty == null or not is_instance_valid(patty) or flicking_patty != null:
		return
	if spatula_patty != null:
		_reject_second_scoop("Already holding a patty")
		return
	if not patty.flipped_once or not patty.can_scoop():
		_flash("Finish cooking before flicking to Build", Color("FFA726"))
		return
	var idx: int = patty.slot_index
	if idx >= 0 and idx < grill.size():
		grill[idx] = null
	patty.heating = false
	patty.is_held = true
	_leave_grill_residue(idx, patty, false)
	flicking_patty = patty
	var start: Vector3 = patty.global_position
	## Screen-left = world +X (camera is mirrored).
	var end := Vector3(
		GRILL_CENTER_X + GRILL_WIDTH * 0.62,
		GRILL_SURFACE_Y + 0.22,
		GRILL_SURFACE_Z - 0.08
	)
	var peak_y := maxf(start.y, end.y) + 0.42
	if game_audio:
		game_audio.play_scoop()
	_flash("Flicking to Build!", Color("A5D6A7"))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float):
		if patty == null or not is_instance_valid(patty):
			return
		var xz: Vector3 = start.lerp(end, t)
		## Parabolic jump.
		var y := lerpf(start.y, end.y, t) + 4.0 * t * (1.0 - t) * (peak_y - lerpf(start.y, end.y, 0.5))
		patty.global_position = Vector3(xz.x, y, xz.z)
		patty.rotation_degrees.z = lerpf(0.0, -28.0, t)
	, 0.0, 1.0, 0.38)
	tw.tween_callback(func():
		flicking_patty = null
		if patty == null or not is_instance_valid(patty):
			return
		_commit_patty_to_build(patty)
	)


func _try_drag_patty_to_station(patty: Area3D, station_idx: int) -> void:
	if patty == null or not is_instance_valid(patty):
		return
	if not patty.flipped_once:
		_flash("Flip it before dragging to a station", Color("FFA726"))
		return
	if not patty.can_scoop():
		if patty.has_cheese and not patty.cheese_ready():
			_flash("Wait for the cheese to melt", Color("FFE082"))
		else:
			_flash("Still cooking — wait to scoop, then drag to a station", Color("FFA726"))
		return
	if spatula_patty != null:
		_reject_second_scoop("Already holding a patty")
		return
	_pickup_patty(patty)
	if spatula_patty != null:
		_drop_spatula_on_station(station_idx)


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
		if patty.has_cheese and not patty.cheese_ready():
			_flash("Wait for the cheese to melt", Color("FFE082"))
		else:
			_flash("Other side still cooking - wait to scoop", Color("FFA726"))
		return
	_pickup_patty(patty)


func _pickup_patty(patty: Area3D) -> void:
	if spatula_patty != null:
		_reject_second_scoop()
		return
	if not patty.flipped_once or not patty.can_scoop():
		_flash("Flip and finish cooking before scooping", Color("EF5350"))
		return
	var idx: int = patty.slot_index
	if idx >= 0 and idx < grill.size():
		grill[idx] = null
	patty.is_held = true
	patty.heating = false
	patty.visible = true
	spatula_patty = patty
	spatula_last_mouse = get_viewport().get_mouse_position()
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_leave_grill_residue(idx, patty)
	_refresh_spatula_ui()
	_update_held_spatula_patty(0.016)
	if game_audio:
		game_audio.play_scoop()
	var rating: Dictionary = patty.cook_rating()
	_flash("Scooped! %s — drop on grill, HOLD, Build, or flick left to throw" % patty.cook_rating_text(), rating["color"])


func _update_held_spatula_patty(delta: float = 0.016) -> void:
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		spatula_patty = null
		return
	if flicking_patty == spatula_patty:
		return
	var mouse := get_viewport().get_mouse_position()
	var dt := maxf(delta, 0.001)
	var instant := (mouse - spatula_last_mouse) / dt
	spatula_vel_screen = spatula_vel_screen.lerp(instant, clampf(dt * 16.0, 0.0, 1.0))
	spatula_carry_travel += mouse.distance_to(spatula_last_mouse)
	spatula_last_mouse = mouse
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO and camera != null:
		## Off-plane fallback: keep it in front of the camera.
		var from := camera.project_ray_origin(mouse)
		var dir := camera.project_ray_normal(mouse)
		hit = from + dir * 1.35
		hit.y = maxf(hit.y, GRILL_SURFACE_Y + SPATULA_HOVER_Y)
	if hit == Vector3.ZERO:
		return
	## Soft clamp so it stays near the flat-top / HOLD strip while aiming.
	var pad := 0.35
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.5 - pad, GRILL_CENTER_X + GRILL_WIDTH * 0.5 + pad)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5 - pad, GRILL_SURFACE_Z + GRILL_DEPTH * 0.5 + pad)
	var bob := sin(Time.get_ticks_msec() * 0.007) * SPATULA_HOVER_BOB
	hit.y = GRILL_SURFACE_Y + PATTY_SIT_Y + SPATULA_HOVER_Y + bob
	spatula_patty.global_position = hit
	## Slight tip toward move direction so it feels carried.
	var tip := clampf(spatula_vel_screen.x * 0.008, -18.0, 18.0)
	spatula_patty.rotation_degrees = Vector3(8.0, 0.0, tip)


func _handle_spatula_click(screen_pos: Vector2) -> bool:
	## Returns true if the click was consumed (place / trash / throw / flip).
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		return false
	if _is_over_garbage(screen_pos):
		_trash_spatula_patty()
		return true
	## Left side of the screen (or Build UI) → place on Build — not only the Drop button.
	if _is_build_drop_at(screen_pos):
		## Still allow pause / GFX / top bar to win over the left drop strip.
		if _ui_blocks_world_click(screen_pos) and _station_index_at(screen_pos) < 0:
			var top_bar: Control = get_node_or_null("UI/Root/TopBar")
			var over_chrome := false
			for ctrl in [window_pause_btn, gfx_btn, gfx_panel, radio_column, top_bar]:
				if ctrl != null and is_instance_valid(ctrl) and ctrl.visible \
						and ctrl is Control and (ctrl as Control).get_global_rect().has_point(screen_pos):
					over_chrome = true
					break
			if over_chrome:
				return false
		_drop_spatula_on_station(STATION_CRAFT)
		return true
	if _ui_blocks_world_click(screen_pos):
		return false
	## Flick left while carrying → throw into Build.
	if _is_flick_to_build(spatula_vel_screen, spatula_carry_travel):
		_throw_held_patty_to_build()
		return true
	if _try_warmer_click(screen_pos):
		return true
	## Still free to flip another burger on the grill.
	var other = _pick_patty_at_screen(screen_pos)
	if other != null and other != spatula_patty:
		_on_patty_clicked(other)
		return true
	## Click the steel → place / throw it down.
	if _try_place_spatula_on_grill(screen_pos):
		return true
	_flash("Drop on the grill, HOLD, or click left for Build", Color("FFCC80"))
	return true


func _try_place_spatula_on_grill(screen_pos: Vector2) -> bool:
	if spatula_patty == null:
		return false
	var hit := _grill_plane_from_screen(screen_pos)
	if hit == Vector3.ZERO or not _is_on_grill_surface(hit):
		return false
	if _is_in_warmer_zone(hit):
		_place_spatula_on_warmer(hit)
		return true
	_place_spatula_on_grill(hit)
	return true


func _place_spatula_on_grill(hit_pos: Vector3) -> void:
	if spatula_patty == null:
		return
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill full — clear a spot first", Color("EF5350"))
		return
	var bounds := _grill_place_bounds()
	var x := clampf(hit_pos.x, bounds.position.x, bounds.end.x)
	var z := clampf(hit_pos.z, bounds.position.y, bounds.end.y)
	var pos := Vector3(x, GRILL_SURFACE_Y, z)
	if not _can_fit_patty_at(pos):
		_flash("Too close to the edge — keep the patty on the grill", Color("FFA726"))
		return
	if _patty_blocked_at(pos):
		pos = _nudge_to_open_grill_spot(pos)
		if pos == Vector3.ZERO:
			_flash("Too crowded — clear a spot first", Color("EF5350"))
			return
	var patty = spatula_patty
	spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	patty.is_held = false
	patty.visible = true
	patty.rotation_degrees = Vector3.ZERO
	patty.slot_index = idx
	patty.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	patty.heating = grill_on
	patty.heat_mul = _warmer_heat_mul(pos) * _oil_heat_mul(pos)
	patty.position = Vector3(pos.x, patty.base_y, pos.z)
	patty._rest_x = pos.x
	patty._rest_z = pos.z
	if patty.get_parent() == null:
		patties_root.add_child(patty)
	grill[idx] = patty
	slot_positions[idx] = Vector3(pos.x, GRILL_SURFACE_Y, pos.z)
	_refresh_spatula_ui()
	if game_audio:
		game_audio.play_click()
	if patty.has_method("refresh_cook_visuals"):
		patty.refresh_cook_visuals()
	_flash("Back on the grill", Color("A5D6A7"))


func _throw_held_patty_to_build() -> void:
	## Arc from the hand into Build (same destination as a left flick scoop).
	if spatula_patty == null or not is_instance_valid(spatula_patty) or flicking_patty != null:
		return
	var patty = spatula_patty
	spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	patty.is_held = true
	patty.visible = true
	flicking_patty = patty
	var start: Vector3 = patty.global_position
	var end := Vector3(
		GRILL_CENTER_X + GRILL_WIDTH * 0.62,
		GRILL_SURFACE_Y + 0.22,
		GRILL_SURFACE_Z - 0.08
	)
	var peak_y := maxf(start.y, end.y) + 0.42
	if game_audio:
		game_audio.play_scoop()
	_flash("Thrown to Build!", Color("A5D6A7"))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float):
		if patty == null or not is_instance_valid(patty):
			return
		var xz: Vector3 = start.lerp(end, t)
		var y := lerpf(start.y, end.y, t) + 4.0 * t * (1.0 - t) * (peak_y - lerpf(start.y, end.y, 0.5))
		patty.global_position = Vector3(xz.x, y, xz.z)
		patty.rotation_degrees.z = lerpf(patty.rotation_degrees.z, -28.0, t)
	, 0.0, 1.0, 0.34)
	tw.tween_callback(func():
		flicking_patty = null
		if patty == null or not is_instance_valid(patty):
			return
		## Commit directly — never re-hold on the spatula (that left throws stuck in-hand).
		_commit_patty_to_build(patty)
	)


func _commit_patty_to_build(patty: Area3D) -> void:
	## Land a scooped / thrown patty on Build without requiring spatula_patty.
	if not playing or patty == null or not is_instance_valid(patty):
		return
	if spatula_patty == patty:
		spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	var st: Dictionary = stations[STATION_CRAFT]
	var items: Array = st["items"]
	patty.is_held = true
	patty.heating = false
	patty.visible = false
	patty.rotation_degrees = Vector3.ZERO
	if not st["patties"].has(patty):
		st["patties"].append(patty)
	if not items.has("bun_bottom"):
		items.append("bun_bottom")
	_insert_patty_into_stack(items)
	if patty.has_cheese and patty.cheese_ready():
		items.append("cheese")
	st["items"] = _normalize_burger_stack(items)
	_refresh_spatula_ui()
	_start_station_freshness(STATION_CRAFT)
	_refresh_station(STATION_CRAFT)
	_select_station(STATION_CRAFT)
	if game_audio:
		game_audio.play_ingredient("patty")
	var n: int = st["patties"].size()
	if patty.has_cheese and not patty.cheese_ready():
		_flash("Patty on Build — cheese still melting (%ds)" % maxi(1, int(ceil(5.0 * (1.0 - patty.cheese_melt)))), Color("FFE082"))
	else:
		_flash("Patty #%d on Build" % n, Color("A5D6A7"))


func _leave_grill_residue(slot: int, patty: Area3D, announce: bool = true) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	var at := Vector3(patty._rest_x, GRILL_SURFACE_Y + 0.028, patty._rest_z) if patty else slot_positions[slot] + Vector3(0, 0.028, 0)
	grill_residue[slot] = 1.0
	if slot < brush_swipe_travel.size():
		brush_swipe_travel[slot] = 0.0
	if slot < brush_swipe_cool.size():
		brush_swipe_cool[slot] = 0.0
	_spawn_residue_chunks(slot, at)
	if slot < grill_residue_meshes.size() and is_instance_valid(grill_residue_meshes[slot]):
		grill_residue_meshes[slot].position = at
		grill_residue_meshes[slot].visible = false
	if announce:
		_flash("Grease left on the grill — grab the scraper by the window", Color("BCAAA4"))


func _refresh_residue_visual(slot: int) -> void:
	if slot < 0 or slot >= grill_residue_chunks.size():
		return
	var amt: float = float(grill_residue[slot])
	var chunks: Array = grill_residue_chunks[slot]
	if amt <= 0.04:
		grill_residue[slot] = 0.0
		_clear_residue_chunks(slot)
		return
	## Progressive wear — disc thins and shrinks as you scrape.
	var alpha_mul := clampf(0.28 + amt * 0.72, 0.28, 1.0)
	var shrink := clampf(0.55 + amt * 0.45, 0.55, 1.0)
	for i in chunks.size():
		var ch = chunks[i]
		if ch == null or not is_instance_valid(ch):
			continue
		ch.visible = true
		if i == 0:
			ch.scale = Vector3(shrink, 1.0, shrink)
		var mat: StandardMaterial3D = ch.material_override
		if mat == null:
			continue
		var c := mat.albedo_color
		if i == 0:
			c.a = 0.92 * alpha_mul
		else:
			var base_a := 0.9 if c.r < 0.15 else (0.85 if c.r < 0.28 else 0.8)
			c.a = base_a * alpha_mul
		mat.albedo_color = c


func _build_heat_warp_plane(parent: Node3D, local_pos: Vector3, width: float, depth: float) -> void:
	heat_warp_mesh = MeshInstance3D.new()
	heat_warp_mesh.name = "HeatWarp"
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(0.3, width), maxf(0.25, depth))
	heat_warp_mesh.mesh = plane
	heat_warp_mesh.position = local_pos
	heat_warp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := load("res://shaders/heat_warp.gdshader") as Shader
	heat_warp_mat = ShaderMaterial.new()
	heat_warp_mat.shader = shader
	heat_warp_mat.set_shader_parameter("warp_strength", 0.0058)
	heat_warp_mat.set_shader_parameter("heat", 0.0)
	heat_warp_mat.set_shader_parameter("time_scale", 1.35)
	heat_warp_mesh.material_override = heat_warp_mat
	heat_warp_mesh.visible = false
	parent.add_child(heat_warp_mesh)


func _update_heat_warp(_delta: float) -> void:
	if heat_warp_mat == null or heat_warp_mesh == null or not is_instance_valid(heat_warp_mesh):
		return
	var heat := 0.0
	if grill_on:
		## Idle shimmer when burner is on; cooking pushes it a bit harder.
		heat = 0.34
		for i in GRILL_SLOTS:
			var p = grill[i]
			if p == null or not is_instance_valid(p) or p.is_held:
				continue
			if not p.heating:
				continue
			var cook_t := clampf(float(p.cook_time) / 9.0, 0.2, 1.0)
			heat = maxf(heat, 0.42 + cook_t * 0.28 * clampf(float(p.heat_mul), 0.2, 1.0))
	heat_warp_mat.set_shader_parameter("heat", heat)
	heat_warp_mesh.visible = heat > 0.05


func _add_heat_glow(parent: Node3D, local_pos: Vector3, width: float, depth: float, intensity: float, tex: Texture2D) -> MeshInstance3D:
	## Flat radial heat blot — additive so it always brightens the steel (screen-like).
	var glow := MeshInstance3D.new()
	var glow_mesh := PlaneMesh.new()
	glow_mesh.size = Vector2(maxf(0.2, width), maxf(0.2, depth))
	glow.mesh = glow_mesh
	glow.position = local_pos
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.albedo_texture = tex
	gm.albedo_color = Color(1.0, 0.55, 0.18, clampf(0.85 * intensity + 0.2, 0.45, 1.0))
	gm.emission_enabled = true
	gm.emission_texture = tex
	gm.emission = Color(1.0, 0.48, 0.1)
	gm.emission_energy_multiplier = lerpf(2.2, 4.8, clampf(intensity, 0.0, 1.0))
	gm.render_priority = 6
	glow.material_override = gm
	glow.visible = false
	parent.add_child(glow)
	grill_glow_meshes.append(glow)
	return glow


func _make_grill_heat_texture() -> ImageTexture:
	## Brighter radial orange for burner-ON cue.
	var w := 160
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid := float(w - 1) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var r := sqrt(dx * dx + dy * dy)
			var core := clampf(1.0 - r / 0.4, 0.0, 1.0)
			core = pow(core, 1.15)
			var mid_ring := clampf(1.0 - r / 0.78, 0.0, 1.0)
			mid_ring = pow(mid_ring, 1.55)
			var outer := clampf(1.0 - r / 1.0, 0.0, 1.0)
			outer = pow(outer, 2.2)
			var a := clampf(core * 0.78 + mid_ring * 0.4 + outer * 0.18, 0.0, 0.92)
			if a < 0.02 or r > 0.995:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var hot := Color(1.0, 0.62, 0.22, a)
				var deep := Color(1.0, 0.28, 0.04, a)
				img.set_pixel(x, y, deep.lerp(hot, core))
	return ImageTexture.create_from_image(img)


func _make_residue_texture(seed_i: int) -> ImageTexture:
	## Disc-shaped burnt ring with noise holes eaten through it.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var w := 96
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid := float(w - 1) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var r := sqrt(dx * dx + dy * dy)
			## Soft circular mask — nothing outside the patty disc.
			if r > 0.98:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := clampf((0.98 - r) / 0.12, 0.0, 1.0)
			edge = pow(edge, 0.65)
			## Value noise via cheap hash — eats irregular holes in the disc.
			var n1 := sin(float(x) * 0.37 + float(y) * 0.51 + float(seed_i) * 0.01) * 0.5 + 0.5
			var n2 := sin(float(x) * 0.91 - float(y) * 0.73 + 2.1) * 0.5 + 0.5
			var n3 := sin(float(x + y) * 0.22 + float(seed_i)) * 0.5 + 0.5
			var noise := n1 * 0.45 + n2 * 0.35 + n3 * 0.2
			## Punch holes / chew marks toward the rim and randomly inside.
			var hole := 0.0
			if noise < 0.28 and r > 0.2:
				hole = 1.0
			elif noise < 0.38 and r > 0.55:
				hole = 0.7
			elif rng.randf() < 0.04 and r > 0.15:
				hole = 0.85
			if hole > 0.65:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var density := clampf((1.0 - r * 0.35) * edge * (0.55 + noise * 0.5), 0.0, 1.0)
			density *= 1.0 - hole * 0.5
			if density < 0.08:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var shade := rng.randf()
			var col: Color
			if shade > 0.62:
				col = Color(0.05, 0.02, 0.01, density * 0.95)
			elif shade > 0.28:
				col = Color(0.16, 0.07, 0.03, density * 0.88)
			else:
				col = Color(0.28, 0.12, 0.05, density * 0.72)
			## Slightly darker toward the ring edge.
			if r > 0.7:
				col = col.darkened(0.15)
			img.set_pixel(x, y, col)
	## Extra fleck noise on top for crunchy burnt bits.
	for _f in 55:
		var fx := rng.randi_range(0, w - 1)
		var fy := rng.randi_range(0, h - 1)
		var fdx := (float(fx) - mid) / mid
		var fdy := (float(fy) - mid) / mid
		var fr := sqrt(fdx * fdx + fdy * fdy)
		if fr > 0.92 or fr < 0.08:
			continue
		if rng.randf() < 0.45:
			img.set_pixel(fx, fy, Color(0.04, 0.015, 0.01, 0.9))
	return ImageTexture.create_from_image(img)


func _build_wire_brush() -> void:
	## Paint scraper further screen-right (world −X) — easier to grab clear of oil/shaker.
	brush_home = Vector3(-2.58, 1.52, 1.15)
	brush_root = Node3D.new()
	brush_root.name = "PaintScraper"
	brush_root.position = brush_home
	## Blade faces the grill (not edge-up). Flipped from the old parked pose.
	brush_root.rotation_degrees = brush_home_rot
	brush_root.scale = Vector3(1.28, 1.28, 1.28)
	world.add_child(brush_root)

	brush_area = Area3D.new()
	brush_area.input_ray_pickable = true
	brush_area.collision_layer = 8
	brush_area.collision_mask = 0
	brush_area.monitoring = true
	brush_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Grab volume around handle + blade.
	box.size = Vector3(0.28, 0.55, 0.32)
	shape.shape = box
	shape.position = Vector3(0, 0.02, 0.0)
	brush_area.add_child(shape)
	brush_root.add_child(brush_area)

	## Wooden handle — extends away from the blade (+Y).
	var handle := MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(0.028, 0.22, 0.034)
	handle.mesh = hmesh
	handle.position = Vector3(0, 0.14, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.42, 0.26, 0.13)
	hmat.roughness = 0.72
	handle.material_override = hmat
	brush_root.add_child(handle)

	## Rounded handle butt
	var butt := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.032, 0.028, 0.038)
	butt.mesh = bmesh
	butt.position = Vector3(0, 0.26, 0)
	butt.material_override = hmat
	brush_root.add_child(butt)

	## Metal neck / ferrule
	var neck := MeshInstance3D.new()
	var nmesh := BoxMesh.new()
	nmesh.size = Vector3(0.03, 0.05, 0.022)
	neck.mesh = nmesh
	neck.position = Vector3(0, 0.02, 0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.74, 0.78)
	metal.metallic = 0.95
	metal.roughness = 0.28
	neck.material_override = metal
	brush_root.add_child(neck)

	## Wide flat scraper blade — thin axis = up so the face lays on the steel when tipped.
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.0028, 0.09)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.048, 0.012)
	blade.rotation_degrees.x = 6.0
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.78, 0.8, 0.84)
	blade_mat.metallic = 1.0
	blade_mat.roughness = 0.22
	blade.material_override = blade_mat
	brush_root.add_child(blade)

	## Beveled leading edge (toward +Z when scraping).
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.118, 0.0016, 0.02)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, -0.051, 0.058)
	tip.rotation_degrees.x = 14.0
	tip.material_override = blade_mat
	brush_root.add_child(tip)

	## Blade shoulder where it meets the neck
	var shoulder := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(0.055, 0.008, 0.03)
	shoulder.mesh = smesh
	shoulder.position = Vector3(0, -0.01, -0.012)
	shoulder.material_override = metal
	brush_root.add_child(shoulder)


func _build_season_shaker() -> void:
	## Seasoning by the scraper on screen-right — clear of bottom UI.
	shaker_home = Vector3(-2.15, 1.32, 1.08)
	shaker_root = Node3D.new()
	shaker_root.name = "SeasonShaker"
	shaker_root.position = shaker_home
	shaker_root.rotation_degrees = Vector3(6.0, 25.0, -4.0)
	shaker_root.scale = Vector3(1.85, 1.85, 1.85)
	grill_root.add_child(shaker_root)

	shaker_area = Area3D.new()
	shaker_area.input_ray_pickable = true
	shaker_area.collision_layer = 32
	shaker_area.collision_mask = 0
	shaker_area.monitoring = true
	shaker_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Match the bottle mesh — grab only when the ray hits the model.
	box.size = Vector3(0.078, 0.14, 0.078)
	shape.shape = box
	shape.position = Vector3(0, 0.04, 0)
	shaker_area.add_child(shape)
	shaker_root.add_child(shaker_area)

	var body := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.032
	bcyl.bottom_radius = 0.038
	bcyl.height = 0.11
	bcyl.radial_segments = 12
	body.mesh = bcyl
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.42, 0.22)
	bmat.roughness = 0.55
	body.material_override = bmat
	shaker_root.add_child(body)

	var cap := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.036
	cmesh.bottom_radius = 0.036
	cmesh.height = 0.022
	cap.mesh = cmesh
	cap.position = Vector3(0, 0.062, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.75, 0.72, 0.68)
	cmat.metallic = 0.7
	cmat.roughness = 0.35
	cap.material_override = cmat
	shaker_root.add_child(cap)

	shaker_particles = GPUParticles3D.new()
	shaker_particles.amount = 48
	shaker_particles.lifetime = 0.55
	shaker_particles.explosiveness = 0.05
	shaker_particles.randomness = 0.7
	shaker_particles.emitting = false
	shaker_particles.position = Vector3(0, 0.07, 0)
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.014
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 0.35
	pmat.initial_velocity_max = 0.75
	pmat.gravity = Vector3(0, 3.5, 0)
	pmat.damping_min = 0.5
	pmat.damping_max = 1.2
	pmat.scale_min = 0.3
	pmat.scale_max = 0.75
	pmat.color = Color(0.18, 0.12, 0.08, 0.9)
	shaker_particles.process_material = pmat
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.008, 0.005, 0.006)
	var pdraw := StandardMaterial3D.new()
	pdraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pdraw.albedo_color = Color(0.16, 0.1, 0.06, 0.85)
	pdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaker_particles.draw_pass_1 = pmesh
	shaker_particles.material_override = pdraw
	shaker_root.add_child(shaker_particles)


func _try_grab_nearest_tool(screen_pos: Vector2) -> bool:
	if _ui_blocks_world_click(screen_pos):
		return false
	## Seasoning: must click the 3D shaker mesh (ray hit only).
	if not shaker_held and _ray_hits_tool(screen_pos, 32, shaker_area):
		_begin_shaker_hold()
		return shaker_held
	## Other tools — keep grab tight so radio / GFX clicks don't steal the scraper.
	var best := ""
	var best_d := 70.0
	if brush_root != null and camera != null and not brush_held:
		var tip := brush_root.global_position + brush_root.basis * Vector3(0, 0.12, 0)
		var bd := screen_pos.distance_to(camera.unproject_position(tip))
		if bd < best_d:
			best_d = bd
			best = "brush"
	if oil_root != null and camera != null and not oil_held:
		var od := screen_pos.distance_to(camera.unproject_position(oil_root.global_position + Vector3(0, 0.06, 0)))
		if od <= 36.0 and od < best_d:
			best_d = od
			best = "oil"
	if best == "" or best_d > 55.0:
		if _ray_hits_tool(screen_pos, 8, brush_area):
			best = "brush"
		elif _ray_hits_tool(screen_pos, 16, oil_area):
			best = "oil"
	match best:
		"oil":
			return _begin_oil_hold()
		"brush":
			return _try_grab_brush(screen_pos)
	return false


func _ray_hits_tool(screen_pos: Vector2, layer: int, area: Area3D) -> bool:
	if camera == null or area == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 20.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = layer
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") == area


func _try_grab_shaker(screen_pos: Vector2) -> bool:
	if shaker_held or shaker_root == null or camera == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or oil_held or dragging_patty != null:
		return false
	## Only the 3D model — no screen-proximity grab.
	if not _ray_hits_tool(screen_pos, 32, shaker_area):
		return false
	_begin_shaker_hold()
	return shaker_held


func _begin_shaker_hold() -> void:
	if not playing:
		return
	if brush_held or oil_held or cheese_held or spatula_patty != null or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return
	if shaker_held:
		return
	shaker_held = true
	if shaker_root:
		shaker_root.visible = true
		shaker_root.scale = Vector3(1.85, 1.85, 1.85)
		shaker_root.rotation_degrees = Vector3(180.0, 25.0, 0.0)
	if shaker_area:
		shaker_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Hold over beef to season — release to put back", Color("FFE082"))


func _cancel_shaker_hold() -> void:
	shaker_held = false
	if shaker_particles:
		shaker_particles.emitting = false
	if shaker_root:
		shaker_root.position = shaker_home
		shaker_root.rotation_degrees = Vector3(6.0, 25.0, -4.0)
		shaker_root.scale = Vector3(1.85, 1.85, 1.85)
		shaker_root.visible = true
	if shaker_area:
		shaker_area.input_ray_pickable = true


func _cancel_shaker_hold_silent() -> void:
	shaker_held = false
	if shaker_particles:
		shaker_particles.emitting = false
	if shaker_root:
		shaker_root.position = shaker_home
		shaker_root.rotation_degrees = Vector3(6.0, 25.0, -4.0)
		shaker_root.scale = Vector3(1.85, 1.85, 1.85)
		shaker_root.visible = true
	if shaker_area:
		shaker_area.input_ray_pickable = true


func _update_held_shaker(_delta: float) -> void:
	if shaker_root == null or camera == null:
		return
	shaker_season_cool = maxf(0.0, shaker_season_cool - _delta)
	var mouse := get_viewport().get_mouse_position()
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		return
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.5 + 0.05, GRILL_CENTER_X + GRILL_WIDTH * 0.5 - 0.05)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5 + 0.05, GRILL_SURFACE_Z + GRILL_DEPTH * 0.5 - 0.05)
	hit.y = GRILL_SURFACE_Y + 0.2
	shaker_root.global_position = hit
	shaker_root.rotation_degrees = Vector3(180.0, 25.0, 0.0)
	var target = _nearest_patty_near(Vector3(hit.x, GRILL_SURFACE_Y, hit.z), 0.22)
	var over_beef: bool = target != null
	if shaker_particles:
		shaker_particles.emitting = over_beef
	if over_beef and shaker_season_cool <= 0.0:
		shaker_season_cool = 0.05
		if target.apply_seasoning(0.1):
			if game_audio and randf() < 0.25:
				game_audio.play_click()


func _nearest_patty_near(world_pos: Vector3, max_dist: float):
	var best = null
	var best_d := max_dist
	for p in grill:
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		var d := Vector2(p.position.x - world_pos.x, p.position.z - world_pos.z).length()
		if d <= best_d:
			best_d = d
			best = p
	return best


func _update_held_oil(_delta: float) -> void:
	if oil_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		return
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.5 + 0.04, GRILL_CENTER_X + GRILL_WIDTH * 0.5 - 0.04)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5 + 0.04, GRILL_SURFACE_Z + GRILL_DEPTH * 0.5 - 0.04)
	## Hard snap, straight upside-down — raised so the bottle clears the plate.
	oil_root.global_position = Vector3(hit.x, GRILL_SURFACE_Y + OIL_POUR_HEIGHT, hit.z)
	oil_root.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	if oil_particles:
		oil_particles.emitting = true
		oil_particles.position = Vector3(0, 0.12, 0)
	## Draw ABOVE the steel top (~+0.022), not inside the mesh.
	var cur := Vector3(hit.x, GRILL_SURFACE_Y + OIL_SIT_Y, hit.z)
	if oil_last_draw == Vector3.ZERO:
		oil_last_draw = cur
		_spawn_oil_slick(cur, 0.055)
		return
	var gap := Vector2(cur.x - oil_last_draw.x, cur.z - oil_last_draw.z).length()
	## Wider spacing so soft blobs merge instead of stacking into blocky stairs.
	if gap < 0.028:
		return
	var steps := clampi(int(gap / 0.03), 1, 6)
	for s in steps:
		var u := float(s) / float(steps)
		var p := oil_last_draw.lerp(cur, u)
		_spawn_oil_slick(p, 0.048 + clampf(gap * 0.12, 0.0, 0.02))
	oil_last_draw = cur


func _get_oil_blob_texture() -> ImageTexture:
	if _oil_blob_tex != null:
		return _oil_blob_tex
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var mid := Vector2(w * 0.5, w * 0.5)
	for y in w:
		for x in w:
			var n := (Vector2(x + 0.5, y + 0.5) - mid) / (w * 0.5)
			var r := n.length()
			var ang := atan2(n.y, n.x)
			## Soft irregular blob edge — no hard rectangle corners.
			var edge := 0.78 + 0.14 * sin(ang * 2.0 + 0.4) + 0.08 * cos(ang * 5.0)
			var a := 1.0 - smoothstep(edge * 0.38, edge, r)
			a = a * a * 0.78 ## Readable wet blotch on steel.
			if a < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				## Darker than grill steel (~0.28) — deep amber puddle.
				var shade := lerpf(0.1, 0.2, r * r)
				img.set_pixel(x, y, Color(shade, shade * 0.7, shade * 0.32, a))
	_oil_blob_tex = ImageTexture.create_from_image(img)
	return _oil_blob_tex


func _spawn_oil_slick(pos: Vector3, radius: float = 0.04, _yaw: float = 0.0) -> void:
	var slick := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var rad := radius * (0.9 + randf() * 0.25)
	## Round soft puddle — never a stretched rectangle.
	plane.size = Vector2(rad * 2.15, rad * 2.15)
	slick.mesh = plane
	## Sit on the steel, under patties — high enough to avoid grill z-fight.
	slick.position = Vector3(pos.x, GRILL_SURFACE_Y + OIL_SIT_Y, pos.z)
	slick.rotation_degrees = Vector3(0.0, randf() * 360.0, 0.0)
	slick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slick.sorting_offset = -2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _get_oil_blob_texture()
	## Darker than chrome grill (albedo ~0.28) so puddles read at a glance.
	mat.albedo_color = Color(0.16, 0.11, 0.05, 0.72)
	mat.metallic = 0.85
	mat.roughness = 0.08
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.85
	mat.clearcoat_roughness = 0.06
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	## Below patty transparent layers (sear/frost use 1–3).
	mat.render_priority = -2
	slick.material_override = mat
	grill_root.add_child(slick)
	## Keep puddles under tools/patties in the scene tree draw order.
	grill_root.move_child(slick, 0)
	var smoke := _make_oil_burn_smoke(rad)
	slick.add_child(smoke)
	oil_slicks.append({
		"mesh": slick,
		"smoke": smoke,
		"age": 0.0,
		"life": 22.0 + randf() * 10.0,
		"radius": rad,
		"base_a": 0.72,
	})
	while oil_slicks.size() > 70:
		var old: Dictionary = oil_slicks.pop_front()
		var m = old.get("mesh")
		if m != null and is_instance_valid(m):
			m.queue_free()
	## Hot steel + fresh oil → loud hiss/pop burst for ~1s.
	if grill_on and game_audio and game_audio.has_method("trigger_hot_oil"):
		game_audio.trigger_hot_oil(1.0)


func _make_oil_burn_smoke(radius: float) -> GPUParticles3D:
	## Greasy smoke that ramps up as the puddle cooks off.
	var smoke := GPUParticles3D.new()
	smoke.name = "OilBurnSmoke"
	smoke.amount = 22
	smoke.lifetime = 1.35
	smoke.explosiveness = 0.0
	smoke.randomness = 0.65
	smoke.emitting = false
	smoke.amount_ratio = 0.0
	## Sit above the steel / shine band so wisps aren't buried in the highlight.
	smoke.position = Vector3(0, 0.05, 0)
	smoke.visibility_aabb = AABB(Vector3(-0.4, -0.05, -0.4), Vector3(0.8, 1.2, 0.8))
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Draw after grill shine (prio 2) and heat glow (prio 6).
	smoke.sorting_offset = 5.0
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = maxf(0.02, radius * 0.85)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 0.1
	pmat.initial_velocity_max = 0.28
	pmat.gravity = Vector3(0, 0.12, 0)
	pmat.damping_min = 0.35
	pmat.damping_max = 0.85
	pmat.scale_min = 0.8
	pmat.scale_max = 1.9
	pmat.color = Color(0.55, 0.5, 0.45, 0.4)
	var fade := Gradient.new()
	fade.add_point(0.0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.55))
	fade.add_point(0.55, Color(0.85, 0.8, 0.75, 0.28))
	fade.add_point(1.0, Color(0.6, 0.55, 0.5, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pmat.color_ramp = fade_tex
	smoke.process_material = pmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	draw.albedo_texture = _get_oil_smoke_texture()
	draw.albedo_color = Color(0.75, 0.7, 0.65, 0.7)
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.vertex_color_use_as_albedo = true
	## Above shine (2) and burner glow (6) so smoke isn't washed under the glare.
	draw.render_priority = 12
	draw.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	smoke.draw_pass_1 = quad
	smoke.material_override = draw
	return smoke


func _get_oil_smoke_texture() -> ImageTexture:
	## Soft grey puff — reused for every oil slick.
	if _oil_smoke_tex != null:
		return _oil_smoke_tex
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid := float(w - 1) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = pow(a, 1.65) * 0.85
			if a < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(0.7, 0.68, 0.64, a))
	_oil_smoke_tex = ImageTexture.create_from_image(img)
	return _oil_smoke_tex


func _smear_oil_along(pos: Vector3, move_vec: Vector2, moved: float) -> void:
	## Soft nudge only — no stretch/spin (that made the puddles freak out).
	if oil_slicks.is_empty() or moved < 0.002:
		return
	var dir := move_vec.normalized()
	for item in oil_slicks:
		var mesh = item.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			continue
		var d := Vector2(mesh.position.x - pos.x, mesh.position.z - pos.z).length()
		var reach := 0.1 + float(item.get("radius", 0.04))
		if d > reach:
			continue
		var pull := clampf(1.0 - d / reach, 0.0, 1.0)
		mesh.position.x += dir.x * moved * pull * 0.22
		mesh.position.z += dir.y * moved * pull * 0.22
		mesh.position.y = GRILL_SURFACE_Y + OIL_SIT_Y
		var s: float = mesh.scale.x
		s = clampf(s + moved * 0.35 * pull, 0.95, 1.35)
		mesh.scale = Vector3(s, 1.0, s)


func _update_oil_slicks(delta: float) -> void:
	var i := 0
	## Hot flat-top cooks oil off faster and drives more smoke.
	var burn_rate := 1.55 if grill_on else 0.85
	while i < oil_slicks.size():
		var item: Dictionary = oil_slicks[i]
		item["age"] = float(item["age"]) + delta * burn_rate
		var mesh = item.get("mesh")
		var life := float(item["life"])
		var age := float(item["age"])
		if mesh == null or not is_instance_valid(mesh) or age >= life:
			if mesh != null and is_instance_valid(mesh):
				mesh.queue_free()
			oil_slicks.remove_at(i)
			continue
		var burn := clampf(age / life, 0.0, 1.0)
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			var fade := 1.0 - burn
			fade = smoothstep(0.0, 1.0, fade)
			var base_a := float(item.get("base_a", 0.9))
			## Fresh amber → dark burnt as it cooks off.
			var fresh := Color(0.16, 0.11, 0.05, base_a)
			var scorched := Color(0.08, 0.05, 0.03, base_a * 0.55)
			var c := fresh.lerp(scorched, smoothstep(0.15, 0.85, burn))
			c.a = base_a * fade
			mat.albedo_color = c
			mat.roughness = lerpf(0.08, 0.45, burn)
		## Shrink slightly as it evaporates.
		var shrink := lerpf(1.0, 0.55, smoothstep(0.35, 1.0, burn))
		mesh.scale = Vector3(shrink, 1.0, shrink)
		## Smoke ramps mid-burn, peaks near the end, then trails off.
		var smoke = item.get("smoke")
		if smoke != null and is_instance_valid(smoke):
			var smoke_amt := 0.0
			if burn > 0.18:
				smoke_amt = smoothstep(0.18, 0.45, burn) * (1.0 - smoothstep(0.88, 1.0, burn))
				if grill_on:
					smoke_amt = minf(1.0, smoke_amt * 1.35)
			smoke.emitting = smoke_amt > 0.04
			smoke.amount_ratio = smoke_amt
		i += 1


func _clear_oil_slicks() -> void:
	for item in oil_slicks:
		var mesh = item.get("mesh") if typeof(item) == TYPE_DICTIONARY else null
		if mesh != null and is_instance_valid(mesh):
			mesh.queue_free()
	oil_slicks.clear()


func _build_oil_bottle() -> void:
	## Next to scraper/shaker on screen-right — tip down to draw oil lines.
	oil_home = Vector3(-1.72, 1.22, 0.88)
	oil_root = Node3D.new()
	oil_root.name = "OilBottle"
	oil_root.position = oil_home
	oil_root.rotation_degrees = Vector3(8.0, 40.0, -5.0)
	oil_root.scale = Vector3(1.75, 1.75, 1.75)
	grill_root.add_child(oil_root)

	oil_area = Area3D.new()
	oil_area.input_ray_pickable = true
	oil_area.collision_layer = 16
	oil_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Tight hitbox — have to click the bottle itself.
	box.size = Vector3(0.07, 0.15, 0.07)
	shape.shape = box
	shape.position = Vector3(0, 0.04, 0)
	oil_area.monitoring = true
	oil_area.monitorable = true
	oil_area.add_child(shape)
	oil_root.add_child(oil_area)

	var bottle := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.028
	bcyl.bottom_radius = 0.034
	bcyl.height = 0.12
	bcyl.radial_segments = 14
	bottle.mesh = bcyl
	bottle.position = Vector3(0, 0.04, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.95, 0.88, 0.45, 0.55)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.roughness = 0.25
	bmat.metallic = 0.05
	bottle.material_override = bmat
	oil_root.add_child(bottle)

	var fill := MeshInstance3D.new()
	var fcyl := CylinderMesh.new()
	fcyl.top_radius = 0.022
	fcyl.bottom_radius = 0.026
	fcyl.height = 0.08
	fill.mesh = fcyl
	fill.position = Vector3(0, 0.02, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.92, 0.78, 0.2, 0.85)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.roughness = 0.4
	fill.material_override = fmat
	oil_root.add_child(fill)

	var tip := MeshInstance3D.new()
	var tmesh := CylinderMesh.new()
	tmesh.top_radius = 0.006
	tmesh.bottom_radius = 0.014
	tmesh.height = 0.035
	tip.mesh = tmesh
	tip.position = Vector3(0, 0.115, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.2, 0.2, 0.22)
	tmat.roughness = 0.5
	tip.material_override = tmat
	oil_root.add_child(tip)

	oil_particles = GPUParticles3D.new()
	oil_particles.amount = 56
	oil_particles.lifetime = 0.55
	oil_particles.explosiveness = 0.05
	oil_particles.randomness = 0.45
	oil_particles.emitting = false
	oil_particles.position = Vector3(0, 0.13, 0)
	var op := ParticleProcessMaterial.new()
	op.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	op.emission_sphere_radius = 0.006
	op.direction = Vector3(0, 1, 0)
	op.spread = 12.0
	op.initial_velocity_min = 0.75
	op.initial_velocity_max = 1.35
	op.gravity = Vector3(0, 5.5, 0)
	op.scale_min = 0.35
	op.scale_max = 0.9
	op.color = Color(1.0, 0.88, 0.35, 0.8)
	oil_particles.process_material = op
	var odrop := SphereMesh.new()
	odrop.radius = 0.007
	odrop.height = 0.014
	odrop.radial_segments = 6
	odrop.rings = 3
	var odraw := StandardMaterial3D.new()
	odraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	odraw.albedo_color = Color(1.0, 0.85, 0.3, 0.75)
	odraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	oil_particles.draw_pass_1 = odrop
	oil_particles.material_override = odraw
	oil_root.add_child(oil_particles)


func _try_grab_oil(screen_pos: Vector2) -> bool:
	if oil_held or oil_root == null or camera == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or dragging_patty != null:
		return false
	var tip := oil_root.global_position + Vector3(0, 0.06, 0)
	var screen_pt := camera.unproject_position(tip)
	if screen_pos.distance_to(screen_pt) > 42.0 and not _ray_hits_tool(screen_pos, 16, oil_area):
		return false
	return _begin_oil_hold()


func _begin_oil_hold() -> bool:
	if not playing or oil_held or oil_root == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	oil_held = true
	oil_last_draw = Vector3.ZERO
	oil_root.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	if oil_area:
		oil_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Oil tipped — drag to draw on the grill", Color("FFE082"))
	return true


func _release_oil_bottle() -> void:
	if not oil_held or oil_root == null:
		return
	oil_held = false
	oil_last_draw = Vector3.ZERO
	if oil_particles:
		oil_particles.emitting = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(oil_root, "position", oil_home, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(oil_root, "rotation_degrees", Vector3(8.0, 40.0, -5.0), 0.22)
	tw.tween_property(oil_root, "scale", Vector3(1.75, 1.75, 1.75), 0.22)
	tw.chain().tween_callback(func():
		if oil_area:
			oil_area.input_ray_pickable = true
	)
	if game_audio:
		game_audio.play_click()


func _reset_oil_bottle() -> void:
	oil_held = false
	oil_spray_cool = 0.0
	oil_last_draw = Vector3.ZERO
	if oil_particles:
		oil_particles.emitting = false
	if oil_root:
		oil_root.position = oil_home
		oil_root.rotation_degrees = Vector3(8.0, 40.0, -5.0)
		oil_root.scale = Vector3(1.75, 1.75, 1.75)
	if oil_area:
		oil_area.input_ray_pickable = true
	_clear_oil_slicks()


func _grill_zone_bands() -> Array:
	## Screen-left → right (world +X → −X): FULL · 1/4 · 1/8 · HOLD.
	var half_w := GRILL_WIDTH * 0.5
	var cursor := GRILL_CENTER_X + half_w ## start at screen-left edge
	var defs: Array = [
		{
			"id": "full",
			"frac": ZONE_FULL_FRAC,
			"mul": ZONE_FULL_MUL,
			"label": "FULL",
			"col": Color(0.34, 0.29, 0.26),
			"rough": 0.2,
			"emit": 0.12,
			"glow": 1.0,
			"lab_col": Color(1.0, 0.82, 0.55, 0.95),
		},
		{
			"id": "quarter",
			"frac": ZONE_QUARTER_FRAC,
			"mul": ZONE_QUARTER_MUL,
			"label": "1/4",
			"col": Color(0.27, 0.28, 0.3),
			"rough": 0.26,
			"emit": 0.05,
			"glow": 0.42,
			"lab_col": Color(1.0, 0.9, 0.65, 0.92),
		},
		{
			"id": "eighth",
			"frac": ZONE_EIGHTH_FRAC,
			"mul": ZONE_EIGHTH_MUL,
			"label": "1/8",
			"col": Color(0.22, 0.24, 0.27),
			"rough": 0.32,
			"emit": 0.02,
			"glow": 0.2,
			"lab_col": Color(0.85, 0.9, 1.0, 0.9),
		},
		{
			"id": "hold",
			"frac": ZONE_HOLD_FRAC,
			"mul": ZONE_HOLD_MUL,
			"label": "HOLD",
			"col": Color(0.18, 0.2, 0.24),
			"rough": 0.38,
			"emit": 0.0,
			"glow": 0.0,
			"lab_col": Color(0.75, 0.88, 1.0, 0.95),
		},
	]
	var out: Array = []
	for d in defs:
		var w := GRILL_WIDTH * float(d["frac"])
		var x1 := cursor
		var x0 := cursor - w
		var band: Dictionary = d.duplicate()
		band["x0"] = x0
		band["x1"] = x1
		band["cx"] = (x0 + x1) * 0.5
		band["w"] = w
		out.append(band)
		cursor = x0
	return out


func _grill_zone_at(world_pos: Vector3) -> Dictionary:
	var half_d := GRILL_DEPTH * 0.5
	if absf(world_pos.z - GRILL_SURFACE_Z) > half_d + 0.02:
		return {}
	for z in _grill_zone_bands():
		if world_pos.x >= float(z["x0"]) - 0.001 and world_pos.x <= float(z["x1"]) + 0.001:
			return z
	return {}


func _warmer_rect() -> Rect2:
	## Far-right HOLD strip only.
	for z in _grill_zone_bands():
		if str(z["id"]) == "hold":
			return Rect2(float(z["x0"]), GRILL_SURFACE_Z - GRILL_DEPTH * 0.5, float(z["w"]), GRILL_DEPTH)
	var half_w := GRILL_WIDTH * 0.5
	var warm_w := GRILL_WIDTH * ZONE_HOLD_FRAC
	return Rect2(GRILL_CENTER_X - half_w, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5, warm_w, GRILL_DEPTH)


func _is_in_warmer_zone(world_pos: Vector3) -> bool:
	return _warmer_rect().has_point(Vector2(world_pos.x, world_pos.z))


func _warmer_heat_mul(world_pos: Vector3) -> float:
	var z := _grill_zone_at(world_pos)
	if z.is_empty():
		return ZONE_FULL_MUL
	return float(z["mul"])


func _oil_heat_mul(world_pos: Vector3) -> float:
	## Oil puddles conduct heat hard — cook ~3× faster on that spot (cook zones only).
	if _is_in_warmer_zone(world_pos):
		return 1.0
	if oil_slicks.is_empty():
		return 1.0
	for item in oil_slicks:
		var mesh = item.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			continue
		var rad := float(item.get("radius", 0.05)) * maxf(mesh.scale.x, 1.0)
		var d := Vector2(mesh.position.x - world_pos.x, mesh.position.z - world_pos.z).length()
		if d <= rad + 0.09:
			return 3.0
	return 1.0


func _warmer_speed_label(world_pos: Vector3) -> String:
	var z := _grill_zone_at(world_pos)
	if z.is_empty():
		return ""
	if _oil_heat_mul(world_pos) >= 2.9 and float(z["mul"]) > 0.0:
		return "OILED 3x"
	return str(z["label"])


func _warmer_place_bounds() -> Rect2:
	## Inset so a full patty stays inside the hold strip.
	var r := _warmer_rect()
	var inset := PATTY_FIT_RADIUS + 0.02
	return Rect2(
		r.position.x + inset,
		r.position.y + inset,
		maxf(0.05, r.size.x - inset * 2.0),
		maxf(0.05, r.size.y - inset * 2.0)
	)


func _build_meat_warmer() -> void:
	## Zone labels along the flat-top: FULL · 1/4 · 1/8 · HOLD.
	if warmer_root != null and is_instance_valid(warmer_root):
		warmer_root.queue_free()
	warmer_root = Node3D.new()
	warmer_root.name = "GrillHeatZones"
	grill_root.add_child(warmer_root)
	warmer_root.position = Vector3(0, GRILL_SURFACE_Y + 0.026, GRILL_SURFACE_Z)

	var label_z := -GRILL_DEPTH * 0.42
	warmer_label = null
	warmer_label_quarter = null
	warmer_label_eighth = null
	for z in _grill_zone_bands():
		var lab := _make_warmer_speed_label(
			str(z["label"]),
			Vector3(float(z["cx"]), 0.018, label_z),
			z["lab_col"]
		)
		match str(z["id"]):
			"full":
				warmer_label = lab
			"quarter":
				warmer_label_quarter = lab
			"eighth":
				warmer_label_eighth = lab
			"hold":
				if warmer_label == null:
					warmer_label = lab


func _update_patty_warm_hold(patty: Area3D, delta: float) -> void:
	## Meat on the hold strip stays cooked but spoils after 5 minutes.
	if patty == null or not is_instance_valid(patty) or patty.is_held:
		return
	if not _is_in_warmer_zone(patty.position):
		patty.warm_hold_time = 0.0
		return
	patty.warm_hold_time = float(patty.warm_hold_time) + delta
	if float(patty.warm_hold_time) >= WARM_HOLD_MAX:
		_trash_held_warm_patty(patty)


func _trash_held_warm_patty(patty: Area3D) -> void:
	var idx: int = int(patty.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == patty:
		grill[idx] = null
	if is_instance_valid(patty):
		patty.queue_free()
	_flash("Hold meat went BAD after 5 minutes — tossed", Color("EF5350"))


func _make_warmer_speed_label(text: String, local_pos: Vector3, col: Color) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.position = local_pos
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = col
	UiFontsScript.apply_label3d(lab, true, 64, 0.042)
	lab.outline_modulate = Color(0, 0, 0, 0.7)
	warmer_root.add_child(lab)
	return lab


func _make_grill_zone_metal(albedo: Color, roughness: float, emit: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = 1.0
	mat.roughness = roughness
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.emission_enabled = emit > 0.01
	mat.emission = Color(1.0, 0.45, 0.12).lerp(albedo, 0.35)
	mat.emission_energy_multiplier = emit * 1.15
	return mat


func _add_grill_zone_panel(parent: Node3D, local_pos: Vector3, size: Vector3, mat: Material) -> void:
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	panel.mesh = mesh
	panel.position = local_pos
	panel.material_override = mat
	parent.add_child(panel)


func _add_grill_shine(parent: Node3D, local_pos: Vector3, width: float, depth: float) -> void:
	## Soft highlight band — additive so steel always reads brighter.
	var shine := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(0.2, width), maxf(0.08, depth))
	shine.mesh = plane
	shine.position = local_pos
	shine.rotation_degrees = Vector3(0, -8.0, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _make_grill_shine_texture()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.97, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.render_priority = 2
	shine.material_override = mat
	parent.add_child(shine)


func _make_grill_shine_texture() -> ImageTexture:
	## Soft white bar with feathered edges — long highlight stripe.
	var w := 256
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid_y := float(h - 1) * 0.5
	for y in h:
		for x in w:
			var v := absf(float(y) - mid_y) / mid_y
			var edge_x := minf(float(x), float(w - 1 - x)) / (float(w) * 0.08)
			edge_x = clampf(edge_x, 0.0, 1.0)
			var core := clampf(1.0 - pow(v, 1.6), 0.0, 1.0)
			var a := core * edge_x * 0.42
			if a < 0.01:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(0.95, 0.97, 1.0, a))
	return ImageTexture.create_from_image(img)


func _try_warmer_click(screen_pos: Vector2) -> bool:
	## Drop held cooked meat onto the warmer strip.
	if not playing or spatula_patty == null or camera == null:
		return false
	if brush_held or cheese_held or dragging_patty != null:
		return false
	var hit := _grill_plane_from_screen(screen_pos)
	if hit == Vector3.ZERO or not _is_in_warmer_zone(hit):
		return false
	_place_spatula_on_warmer(hit)
	return true


func _place_spatula_on_warmer(hit_pos: Vector3) -> void:
	if spatula_patty == null:
		return
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill full — clear a spot before using HOLD", Color("EF5350"))
		return
	var bounds := _warmer_place_bounds()
	var x := clampf(hit_pos.x, bounds.position.x, bounds.end.x)
	var z := clampf(hit_pos.z, bounds.position.y, bounds.end.y)
	var pos := Vector3(x, GRILL_SURFACE_Y, z)
	if _patty_blocked_at(pos):
		var placed := false
		for _try in 10:
			pos.x = lerpf(bounds.position.x, bounds.end.x, randf())
			pos.z = lerpf(bounds.position.y, bounds.end.y, randf())
			if not _patty_blocked_at(pos):
				placed = true
				break
		if not placed:
			_flash("HOLD is crowded — move a patty first", Color("FFA726"))
			return
	var patty = spatula_patty
	spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	patty.is_held = false
	patty.visible = true
	patty.rotation_degrees = Vector3.ZERO
	patty.slot_index = idx
	patty.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	patty.heating = grill_on
	patty.heat_mul = _warmer_heat_mul(pos) * _oil_heat_mul(pos)
	patty.warm_hold_time = 0.0
	patty.position = Vector3(pos.x, patty.base_y, pos.z)
	patty._rest_x = pos.x
	patty._rest_z = pos.z
	if patty.get_parent() == null:
		patties_root.add_child(patty)
	grill[idx] = patty
	slot_positions[idx] = Vector3(pos.x, GRILL_SURFACE_Y, pos.z)
	_refresh_spatula_ui()
	if game_audio:
		game_audio.play_click()
	if patty.has_method("refresh_cook_visuals"):
		patty.refresh_cook_visuals()
	_flash("On HOLD — stays warm up to 5 minutes (won't cook more)", Color("90CAF9"))


func _clear_warmer() -> void:
	## Zone is spatial; patties clear with the grill.
	pass


func _try_grab_brush(screen_pos: Vector2) -> bool:
	if brush_held or brush_throwing or brush_area == null or camera == null:
		return false
	if _ui_blocks_world_click(screen_pos):
		return false
	if spatula_patty != null or cheese_held or shaker_held or oil_held:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var to := from + dir * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 8
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var grabbed := false
	if not hit.is_empty() and hit.get("collider") == brush_area:
		grabbed = true
	else:
		## Tight proximity only — fat radius stole radio / GFX clicks.
		var tip := brush_root.global_position + brush_root.basis * Vector3(0, 0.12, 0)
		var screen_pt := camera.unproject_position(tip)
		if screen_pos.distance_to(screen_pt) <= 48.0:
			grabbed = true
	if not grabbed:
		return false
	brush_held = true
	if brush_area:
		brush_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Swipe grease off the steel — keep moving to scrub it clean", Color("B0BEC5"))
	brush_last_pos = brush_root.global_position if brush_root else Vector3.ZERO
	## Snap toward cursor immediately so it doesn't feel stuck.
	_snap_brush_toward_cursor(screen_pos, 0.55)
	return true


func _snap_brush_toward_cursor(screen_pos: Vector2, amount: float = 1.0) -> void:
	if brush_root == null or camera == null:
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane_y := GRILL_SURFACE_Y + 0.045
	if absf(dir.y) < 0.001:
		return
	var t := (plane_y - from.y) / dir.y
	if t <= 0.0:
		return
	var hit := from + dir * t
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.7, GRILL_CENTER_X + GRILL_WIDTH * 0.7)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.7, GRILL_SURFACE_Z + GRILL_DEPTH * 0.55)
	hit.y = plane_y + 0.02
	brush_root.global_position = brush_root.global_position.lerp(hit, clampf(amount, 0.0, 1.0))
	brush_root.rotation_degrees = Vector3(-84.0, 18.0, 180.0)


func _update_held_brush(delta: float) -> void:
	if brush_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	## Project onto a plane just above the grill.
	var plane_y := GRILL_SURFACE_Y + 0.045
	if absf(dir.y) < 0.001:
		return
	var t := (plane_y - from.y) / dir.y
	if t <= 0.0:
		return
	var hit := from + dir * t
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.7, GRILL_CENTER_X + GRILL_WIDTH * 0.7)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.7, GRILL_SURFACE_Z + GRILL_DEPTH * 0.55)
	hit.y = plane_y + 0.02
	var prev := brush_root.global_position
	## Snappier follow so scraping feels responsive.
	var blend := clampf(delta * 32.0, 0.0, 1.0)
	brush_root.global_position = brush_root.global_position.lerp(hit, blend)
	var move_xz := Vector2(
		brush_root.global_position.x - prev.x,
		brush_root.global_position.z - prev.z
	)
	var moved := move_xz.length()
	## Blade face-down on the steel, handle tipped back toward the cook.
	var yaw := 18.0
	if move_xz.length_squared() > 0.00001:
		## Nudge yaw toward swipe direction so the blade leads the stroke.
		yaw = rad_to_deg(atan2(move_xz.x, move_xz.y)) * 0.25 + 18.0
	var target_rot := Vector3(
		-84.0 + sin(Time.get_ticks_msec() * 0.02) * 2.0,
		yaw + sin(Time.get_ticks_msec() * 0.012) * 2.5,
		180.0 + sin(Time.get_ticks_msec() * 0.016) * 2.0
	)
	brush_root.rotation_degrees = brush_root.rotation_degrees.lerp(target_rot, clampf(delta * 14.0, 0.0, 1.0))
	## Nudge burgers when the blade shoves into them.
	if moved > 0.0008:
		_brush_nudge_patties(brush_root.global_position, move_xz, moved)
	## Continuous scrape — wear residue down while the blade is moving over it.
	var scraping := false
	for i in GRILL_SLOTS:
		if i < brush_swipe_cool.size():
			brush_swipe_cool[i] = maxf(0.0, float(brush_swipe_cool[i]) - delta)
		if float(grill_residue[i]) <= 0.0:
			continue
		var pad_pos: Vector3 = grill_residue_centers[i] if i < grill_residue_centers.size() else slot_positions[i]
		var d := Vector2(brush_root.global_position.x - pad_pos.x, brush_root.global_position.z - pad_pos.z).length()
		if d < 0.34 and moved > 0.0005:
			scraping = true
			var before := float(grill_residue[i])
			grill_residue[i] = maxf(0.0, before - moved * RESIDUE_SCRAPE_RATE)
			_refresh_residue_visual(i)
			if i < brush_swipe_travel.size():
				brush_swipe_travel[i] = float(brush_swipe_travel[i]) + moved
			## Chip flecks as you work the stain down.
			if float(brush_swipe_cool[i]) <= 0.0 and float(brush_swipe_travel[i]) >= RESIDUE_SWIPE_DIST:
				brush_swipe_travel[i] = 0.0
				brush_swipe_cool[i] = 0.12
				_scrape_residue_hit(i, move_xz)
			if float(grill_residue[i]) <= 0.04:
				_scrape_finish_clean(i)
		elif i < brush_swipe_travel.size():
			brush_swipe_travel[i] = maxf(0.0, float(brush_swipe_travel[i]) - delta * 0.25)
	if game_audio and game_audio.has_method("set_slide_moving"):
		if scraping:
			game_audio.set_slide_moving(true, clampf(moved / maxf(delta, 0.001) * 0.25, 0.3, 1.2))
		else:
			game_audio.set_slide_moving(false)


func _brush_nudge_patties(brush_pos: Vector3, move_xz: Vector2, moved: float) -> void:
	## Scraper slides patties a little — not a full drag, just a shove.
	if move_xz.length_squared() < 0.0000001:
		return
	var dir := move_xz.normalized()
	var push_len := clampf(moved * BRUSH_PATTY_PUSH_SCALE, 0.0, BRUSH_PATTY_PUSH_MAX)
	var bounds := _grill_place_bounds()
	## HOLD strip is also fair game for a nudge.
	var warm := _warmer_place_bounds()
	var min_x := minf(bounds.position.x, warm.position.x)
	var max_x := maxf(bounds.end.x, warm.end.x)
	var min_z := minf(bounds.position.y, warm.position.y)
	var max_z := maxf(bounds.end.y, warm.end.y)
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		if p == dragging_patty or p == flicking_patty:
			continue
		var d := Vector2(brush_pos.x - p.position.x, brush_pos.z - p.position.z).length()
		if d > BRUSH_PATTY_PUSH_RADIUS:
			continue
		var falloff := 1.0 - d / BRUSH_PATTY_PUSH_RADIUS
		falloff *= falloff
		var nx: float = float(p._rest_x) + dir.x * push_len * falloff
		var nz: float = float(p._rest_z) + dir.y * push_len * falloff
		nx = clampf(nx, min_x, max_x)
		nz = clampf(nz, min_z, max_z)
		var try := Vector3(nx, GRILL_SURFACE_Y, nz)
		if _patty_blocked_at(try, i):
			## Try axis-separated shove so it can slide along neighbors.
			var try_x := Vector3(nx, GRILL_SURFACE_Y, p._rest_z)
			var try_z := Vector3(p._rest_x, GRILL_SURFACE_Y, nz)
			if not _patty_blocked_at(try_x, i):
				try = try_x
			elif not _patty_blocked_at(try_z, i):
				try = try_z
			else:
				continue
		p._rest_x = try.x
		p._rest_z = try.z
		p.position.x = try.x
		p.position.z = try.z
		p.position.y = p.base_y
		slot_positions[i] = Vector3(try.x, GRILL_SURFACE_Y, try.z)
		p.heat_mul = _warmer_heat_mul(p.position) * _oil_heat_mul(p.position)
		if game_audio and moved > 0.012 and randf() < 0.18:
			game_audio.play_grease_pop()


func _throw_brush_home() -> void:
	if not brush_held or brush_root == null:
		return
	brush_held = false
	brush_throwing = true
	if game_audio:
		game_audio.play_click()
		if game_audio.has_method("set_slide_moving"):
			game_audio.set_slide_moving(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(brush_root, "position", brush_home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(brush_root, "rotation_degrees", brush_home_rot, 0.28)
	tw.chain().tween_callback(func():
		brush_throwing = false
		if brush_area:
			brush_area.input_ray_pickable = true
		_flash("Scraper put away", Color("B0BEC5"))
	)


func _clear_all_residue() -> void:
	for i in GRILL_SLOTS:
		if i < grill_residue.size():
			grill_residue[i] = 0.0
			_clear_residue_chunks(i)
			if i < brush_swipe_travel.size():
				brush_swipe_travel[i] = 0.0
			if i < brush_swipe_cool.size():
				brush_swipe_cool[i] = 0.0
	if brush_held:
		brush_held = false
		brush_throwing = false
		if brush_root:
			brush_root.position = brush_home
			brush_root.rotation_degrees = brush_home_rot
		if brush_area:
			brush_area.input_ray_pickable = true


func _station_cook_rating(station_index: int) -> Dictionary:
	## Average cook rating across patties on a station.
	var st: Dictionary = stations[station_index]
	var patties: Array = st["patties"]
	var sum := 0.0
	var n := 0
	var best: Dictionary = {}
	for p in patties:
		if p != null and is_instance_valid(p) and p.has_method("cook_rating"):
			var r: Dictionary = p.cook_rating()
			sum += float(r["score"])
			n += 1
			if best.is_empty() or int(r["score"]) > int(best.get("score", 0)):
				best = r
	if n <= 0:
		return {
			"score": 0,
			"grade": "-",
			"stars": 0,
			"label": "NO PATTY",
			"detail": "Missing meat",
			"color": Color("B0BEC5"),
			"text": "No patty",
		}
	var avg := int(round(sum / float(n)))
	## Rebuild a grade from the average score for multi-patty burgers.
	var grade := "F"
	var stars := 0
	var label := "POOR"
	var color := Color("EF5350")
	if avg >= 92:
		grade = "S"; stars = 5; label = "PERFECT"; color = Color("FFEB3B")
	elif avg >= 82:
		grade = "A"; stars = 4; label = "GREAT"; color = Color("A5D6A7")
	elif avg >= 70:
		grade = "B"; stars = 3; label = "GOOD"; color = Color("81C784")
	elif avg >= 55:
		grade = "C"; stars = 2; label = "OKAY"; color = Color("FFCC80")
	elif avg >= 35:
		grade = "D"; stars = 1; label = "POOR"; color = Color("FFA726")
	var star_s := ""
	for i in stars:
		star_s += "★"
	while star_s.length() < 5:
		star_s += "☆"
	return {
		"score": avg,
		"grade": grade,
		"stars": stars,
		"label": label,
		"detail": str(best.get("detail", "")),
		"color": color,
		"text": "%s  %s  %s (%d)" % [grade, star_s, label, avg],
	}


func _clear_all_patty() -> void:
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p:
			p.queue_free()
		grill[i] = null
		if i < slot_areas.size() and is_instance_valid(slot_areas[i]):
			slot_areas[i].input_ray_pickable = true
	_clear_all_residue()


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


func _setup_radio() -> void:
	radio = TruckRadioScript.new()
	radio.name = "TruckRadio"
	add_child(radio)
	radio.status_changed.connect(_on_radio_status)
	radio.channel_changed.connect(_on_radio_channel)
	radio.powered_changed.connect(_on_radio_powered)
	_build_radio_ui()
	radio.set_volume_linear(0.05)
	radio.set_powered(true)
	_refresh_radio_ui()


func _build_truck_radio_prop() -> void:
	## Chunky dash radio on the cook's left (+X / screen-left), away from the grills.
	var root := Node3D.new()
	root.name = "CabRadio"
	root.position = Vector3(1.48, 1.12, -0.42)
	grill_root.add_child(root)

	var body := _add_box(root, Vector3(0.42, 0.22, 0.18), Vector3.ZERO, Color(0.18, 0.16, 0.14))
	body.material_override.metallic = 0.55
	body.material_override.roughness = 0.35

	var face := _add_box(root, Vector3(0.36, 0.12, 0.02), Vector3(0, 0.02, -0.1), Color(0.08, 0.1, 0.09))
	face.material_override.roughness = 0.55

	## Amber LCD strip
	var lcd := MeshInstance3D.new()
	var lcd_mesh := BoxMesh.new()
	lcd_mesh.size = Vector3(0.28, 0.045, 0.008)
	lcd.mesh = lcd_mesh
	lcd.position = Vector3(0.02, 0.035, -0.112)
	radio_light_mat = StandardMaterial3D.new()
	radio_light_mat.albedo_color = Color(0.15, 0.35, 0.18)
	radio_light_mat.emission_enabled = true
	radio_light_mat.emission = Color(0.2, 0.9, 0.35)
	radio_light_mat.emission_energy_multiplier = 0.15
	radio_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lcd.material_override = radio_light_mat
	root.add_child(lcd)

	## Tuning dial
	radio_dial_mesh = MeshInstance3D.new()
	var dial := CylinderMesh.new()
	dial.top_radius = 0.035
	dial.bottom_radius = 0.038
	dial.height = 0.03
	radio_dial_mesh.mesh = dial
	radio_dial_mesh.rotation_degrees = Vector3(90, 0, 0)
	radio_dial_mesh.position = Vector3(-0.13, 0.01, -0.11)
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_color = Color(0.75, 0.55, 0.2)
	dial_mat.metallic = 0.8
	dial_mat.roughness = 0.25
	radio_dial_mesh.material_override = dial_mat
	root.add_child(radio_dial_mesh)

	var speaker := _add_box(root, Vector3(0.12, 0.08, 0.04), Vector3(0.12, -0.02, -0.1), Color(0.12, 0.12, 0.12))
	speaker.material_override.roughness = 0.9

	var tag := Label3D.new()
	tag.text = "AM / FM"
	tag.position = Vector3(0, 0.14, -0.05)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("FFCC80")
	UiFontsScript.apply_label3d(tag, true, 64, 0.062)
	root.add_child(tag)

	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.32, 0.28)
	shape.shape = box
	area.add_child(shape)
	root.add_child(area)
	area.input_event.connect(func(_cam, event, _pos, _n, _s):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if radio:
				radio.toggle_power()
				_flash("Radio %s" % ("ON" if radio.powered else "OFF"), Color("FFCC80"))
	)


func _setup_game_audio() -> void:
	game_audio = GameAudioScript.new()
	game_audio.name = "GameAudio"
	add_child(game_audio)


func _sfx_click() -> void:
	if game_audio:
		game_audio.play_click()


func _update_kitchen_sizzle() -> void:
	if game_audio == null:
		return
	var cooking := false
	var heat := 0.0
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p):
			continue
		if p.heating and not p.is_held:
			cooking = true
			heat = maxf(heat, clampf(float(p.cook_time) / 10.0, 0.25, 1.0))
	## Cooking sizzle is louder; empty hot burner keeps a quieter idle hiss.
	## Hot-oil burst keeps the loud fry going even with no patties.
	var oil_burst: bool = game_audio.has_method("is_hot_oil_bursting") and bool(game_audio.is_hot_oil_bursting())
	game_audio.set_sizzle_active(cooking or oil_burst, maxf(heat, 0.95 if oil_burst else 0.0))
	if game_audio.has_method("set_burner_hiss"):
		game_audio.set_burner_hiss(grill_on and not cooking and not oil_burst)


func _build_radio_ui() -> void:
	var ui_root: Control = get_node("UI/Root")
	radio_column = VBoxContainer.new()
	radio_column.name = "RadioColumn"
	radio_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radio_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	radio_column.offset_left = -220.0
	radio_column.offset_right = -10.0
	radio_column.offset_top = 52.0
	radio_column.offset_bottom = 52.0
	radio_column.custom_minimum_size = Vector2(210, 0)
	radio_column.add_theme_constant_override("separation", 6)
	radio_column.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(radio_column)

	var panel := PanelContainer.new()
	panel.name = "RadioPanel"
	panel.custom_minimum_size = Vector2(210, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.14, 0.9)
	sb.border_color = Color(1.0, 0.75, 0.35, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	radio_column.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	v.add_child(title_row)

	var title := Label.new()
	title.text = "AM/FM"
	UiFontsScript.apply_label(title, true, 12)
	title.add_theme_color_override("font_color", Color("FFCC80"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var band_btn := Button.new()
	band_btn.text = "BAND"
	band_btn.custom_minimum_size = Vector2(48, 24)
	UiFontsScript.apply_button(band_btn, true, 10)
	band_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.toggle_band()
			_spin_radio_dial(1)
			_refresh_radio_ui()
	)
	title_row.add_child(band_btn)

	radio_power_btn = Button.new()
	radio_power_btn.text = "OFF"
	radio_power_btn.custom_minimum_size = Vector2(44, 24)
	UiFontsScript.apply_button(radio_power_btn, true, 11)
	radio_power_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.toggle_power()
	)
	title_row.add_child(radio_power_btn)

	radio_channel_label = Label.new()
	radio_channel_label.text = "FM 88.5"
	radio_channel_label.clip_text = true
	radio_channel_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFontsScript.apply_label(radio_channel_label, true, 11)
	radio_channel_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	v.add_child(radio_channel_label)

	radio_status_label = Label.new()
	radio_status_label.text = "Radio off"
	radio_status_label.clip_text = true
	radio_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFontsScript.apply_label(radio_status_label, false, 10)
	radio_status_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.75))
	v.add_child(radio_status_label)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	v.add_child(nav)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.tooltip_text = "Previous station"
	prev_btn.custom_minimum_size = Vector2(36, 24)
	UiFontsScript.apply_button(prev_btn, true, 12)
	prev_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.prev_channel()
			_spin_radio_dial(-1)
	)
	nav.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.tooltip_text = "Next station"
	next_btn.custom_minimum_size = Vector2(36, 24)
	UiFontsScript.apply_button(next_btn, true, 12)
	next_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.next_channel()
			_spin_radio_dial(1)
	)
	nav.add_child(next_btn)

	var vol_lab := Label.new()
	vol_lab.text = "VOL"
	UiFontsScript.apply_label(vol_lab, true, 10)
	vol_lab.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	nav.add_child(vol_lab)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(70, 16)
	slider.value_changed.connect(func(v: float):
		if radio:
			radio.set_volume_linear(v)
	)
	nav.add_child(slider)


func _build_graphics_ui() -> void:
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return

	## Always-visible button on the money / day bar (top-right).
	var top_bar: Control = get_node_or_null("UI/Root/TopBar")
	if top_bar != null and is_instance_valid(top_bar):
		gfx_btn = Button.new()
		gfx_btn.name = "GfxBtn"
		gfx_btn.text = "GFX"
		gfx_btn.focus_mode = Control.FOCUS_NONE
		gfx_btn.custom_minimum_size = Vector2(56, 28)
		UiFontsScript.apply_button(gfx_btn, true, 12)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0.12, 0.28, 0.42)
		gsb.set_corner_radius_all(6)
		gsb.set_border_width_all(2)
		gsb.border_color = Color(0.55, 0.85, 1.0, 0.95)
		gsb.content_margin_left = 8
		gsb.content_margin_right = 8
		gfx_btn.add_theme_stylebox_override("normal", gsb)
		var gsbh := gsb.duplicate()
		gsbh.bg_color = Color(0.18, 0.4, 0.58)
		gfx_btn.add_theme_stylebox_override("hover", gsbh)
		gfx_btn.add_theme_color_override("font_color", Color.WHITE)
		gfx_btn.pressed.connect(func():
			_sfx_click()
			_toggle_graphics_menu()
		)
		top_bar.add_child(gfx_btn)
		## Sit first so it isn't clipped off the right edge.
		top_bar.move_child(gfx_btn, 0)
		top_bar.offset_left = 820.0

	gfx_panel = PanelContainer.new()
	gfx_panel.name = "GraphicsPanel"
	gfx_panel.visible = false
	gfx_panel.z_index = 40
	gfx_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	gfx_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gfx_panel.offset_left = -320.0
	gfx_panel.offset_right = -16.0
	gfx_panel.offset_top = -220.0
	gfx_panel.offset_bottom = 260.0
	gfx_panel.custom_minimum_size = Vector2(300, 0)
	gfx_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.1, 0.12, 0.94)
	psb.border_color = Color(0.55, 0.78, 1.0, 0.85)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 12
	psb.content_margin_right = 12
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	gfx_panel.add_theme_stylebox_override("panel", psb)
	ui_root.add_child(gfx_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 6)
	gfx_panel.add_child(root_v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_v.add_child(header)

	var title := Label.new()
	title.text = "GRAPHICS"
	UiFontsScript.apply_label(title, true, 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 26)
	UiFontsScript.apply_button(close_btn, true, 12)
	close_btn.pressed.connect(func():
		_sfx_click()
		_set_graphics_menu_open(false)
	)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)

	_gfx_add_section(list, "BLOOM / GLOW")
	_gfx_add_check(list, "glow_on", "Glow / Bloom")
	_gfx_add_slider(list, "bloom", "Bloom", 0.0, 1.0, 0.01)
	_gfx_add_slider(list, "glow_intensity", "Glow Intensity", 0.0, 2.5, 0.01)
	_gfx_add_slider(list, "glow_strength", "Glow Strength", 0.0, 2.5, 0.01)
	_gfx_add_slider(list, "glow_threshold", "Glow Threshold", 0.1, 2.0, 0.01)

	_gfx_add_section(list, "LIGHTING")
	_gfx_add_slider(list, "exposure", "Exposure", 0.4, 1.8, 0.01)
	_gfx_add_slider(list, "ambient", "Ambient", 0.0, 1.2, 0.01)
	_gfx_add_slider(list, "sun", "Sun", 0.0, 3.0, 0.01)
	_gfx_add_slider(list, "kitchen", "Kitchen Light", 0.0, 3.5, 0.01)
	_gfx_add_slider(list, "grill_lamp", "Grill Lamp", 0.0, 3.5, 0.01)
	_gfx_add_slider(list, "window_wash", "Window Wash", 0.0, 3.0, 0.01)
	_gfx_add_slider(list, "sky_energy", "Sky Brightness", 0.05, 1.5, 0.01)

	_gfx_add_section(list, "LOOK")
	_gfx_add_slider(list, "saturation", "Saturation", 0.5, 1.6, 0.01)
	_gfx_add_slider(list, "contrast", "Contrast", 0.7, 1.5, 0.01)
	_gfx_add_check(list, "ssao", "Ambient Occlusion (SSAO)")
	_gfx_add_check(list, "ssil", "Indirect Light (SSIL)")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root_v.add_child(footer)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_button(reset_btn, true, 12)
	reset_btn.pressed.connect(func():
		_sfx_click()
		_reset_graphics_defaults()
	)
	footer.add_child(reset_btn)

	_load_graphics_settings()
	_apply_graphics_settings(_read_graphics_from_ui())
	_sync_graphics_ui_from_world()


func _gfx_add_section(parent: Control, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	UiFontsScript.apply_label(lab, true, 11)
	lab.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	lab.add_theme_constant_override("outline_size", 1)
	parent.add_child(lab)


func _gfx_add_slider(parent: Control, key: String, label_text: String, min_v: float, max_v: float, step: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	parent.add_child(row)

	var top := HBoxContainer.new()
	row.add_child(top)

	var lab := Label.new()
	lab.text = label_text
	UiFontsScript.apply_label(lab, false, 11)
	lab.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lab)

	var val_lab := Label.new()
	val_lab.name = "Val"
	val_lab.custom_minimum_size = Vector2(42, 0)
	val_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFontsScript.apply_label(val_lab, true, 11)
	val_lab.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	top.add_child(val_lab)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(GFX_DEFAULTS.get(key, min_v))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 18)
	slider.value_changed.connect(func(v: float):
		val_lab.text = "%.2f" % v
		_on_graphics_slider_changed()
	)
	row.add_child(slider)
	val_lab.text = "%.2f" % slider.value
	gfx_sliders[key] = slider


func _gfx_add_check(parent: Control, key: String, label_text: String) -> void:
	var btn := CheckButton.new()
	btn.text = label_text
	btn.button_pressed = bool(GFX_DEFAULTS.get(key, true))
	UiFontsScript.apply_button(btn, false, 11)
	btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	btn.toggled.connect(func(_on: bool):
		_on_graphics_slider_changed()
	)
	parent.add_child(btn)
	gfx_checks[key] = btn


func _toggle_graphics_menu() -> void:
	_set_graphics_menu_open(gfx_panel == null or not gfx_panel.visible)


func _set_graphics_menu_open(open: bool) -> void:
	if gfx_panel == null:
		return
	gfx_panel.visible = open
	if gfx_btn:
		gfx_btn.text = "GFX ▾" if open else "GFX"


func _on_graphics_slider_changed() -> void:
	var settings := _read_graphics_from_ui()
	_apply_graphics_settings(settings)
	_save_graphics_settings(settings)


func _read_graphics_from_ui() -> Dictionary:
	var out := GFX_DEFAULTS.duplicate()
	for key in gfx_sliders:
		var s: HSlider = gfx_sliders[key]
		if s != null and is_instance_valid(s):
			out[key] = s.value
	for key in gfx_checks:
		var c: CheckButton = gfx_checks[key]
		if c != null and is_instance_valid(c):
			out[key] = c.button_pressed
	return out


func _sync_graphics_ui_from_world() -> void:
	## Push current values into controls without re-saving.
	if gfx_env == null:
		return
	var map := {
		"bloom": gfx_env.glow_bloom,
		"glow_intensity": gfx_env.glow_intensity,
		"glow_strength": gfx_env.glow_strength,
		"glow_threshold": gfx_env.glow_hdr_threshold,
		"exposure": gfx_env.tonemap_exposure,
		"ambient": gfx_env.ambient_light_energy,
		"saturation": gfx_env.adjustment_saturation,
		"contrast": gfx_env.adjustment_contrast,
		"sun": gfx_sun.light_energy if gfx_sun else float(GFX_DEFAULTS["sun"]),
		"kitchen": gfx_kitchen.light_energy if gfx_kitchen else float(GFX_DEFAULTS["kitchen"]),
		"grill_lamp": gfx_grill_lamp.light_energy if gfx_grill_lamp else float(GFX_DEFAULTS["grill_lamp"]),
		"window_wash": gfx_window_wash.light_energy if gfx_window_wash else float(GFX_DEFAULTS["window_wash"]),
		"sky_energy": gfx_sky_mat.energy_multiplier if gfx_sky_mat else float(GFX_DEFAULTS["sky_energy"]),
	}
	for key in map:
		if gfx_sliders.has(key) and gfx_sliders[key] != null:
			gfx_sliders[key].set_value_no_signal(float(map[key]))
			var row: Node = gfx_sliders[key].get_parent()
			if row:
				var top = row.get_child(0) if row.get_child_count() > 0 else null
				if top:
					var val_lab = top.get_node_or_null("Val")
					if val_lab:
						val_lab.text = "%.2f" % float(map[key])
	if gfx_checks.has("glow_on"):
		gfx_checks["glow_on"].set_pressed_no_signal(gfx_env.glow_enabled)
	if gfx_checks.has("ssao"):
		gfx_checks["ssao"].set_pressed_no_signal(gfx_env.ssao_enabled)
	if gfx_checks.has("ssil"):
		gfx_checks["ssil"].set_pressed_no_signal(gfx_env.ssil_enabled)


func _apply_graphics_settings(s: Dictionary) -> void:
	if gfx_env != null:
		gfx_env.glow_enabled = bool(s.get("glow_on", true))
		gfx_env.glow_bloom = float(s.get("bloom", 0.32))
		gfx_env.glow_intensity = float(s.get("glow_intensity", 1.05))
		gfx_env.glow_strength = float(s.get("glow_strength", 1.35))
		gfx_env.glow_hdr_threshold = float(s.get("glow_threshold", 0.55))
		gfx_env.tonemap_exposure = float(s.get("exposure", 0.92))
		gfx_env.ambient_light_energy = float(s.get("ambient", 0.28))
		gfx_env.adjustment_enabled = true
		gfx_env.adjustment_saturation = float(s.get("saturation", 1.06))
		gfx_env.adjustment_contrast = float(s.get("contrast", 1.04))
		gfx_env.ssao_enabled = bool(s.get("ssao", true))
		gfx_env.ssil_enabled = bool(s.get("ssil", true))
	if gfx_sun:
		gfx_sun.light_energy = float(s.get("sun", 1.55))
	if gfx_kitchen:
		gfx_kitchen.light_energy = float(s.get("kitchen", 1.65))
	if gfx_grill_lamp:
		gfx_grill_lamp.light_energy = float(s.get("grill_lamp", 1.35))
	if gfx_window_wash:
		gfx_window_wash.light_energy = float(s.get("window_wash", 1.1))
	if gfx_sky_mat:
		gfx_sky_mat.energy_multiplier = float(s.get("sky_energy", 0.42))


func _reset_graphics_defaults() -> void:
	for key in GFX_DEFAULTS:
		if gfx_sliders.has(key) and gfx_sliders[key] != null:
			gfx_sliders[key].value = float(GFX_DEFAULTS[key])
		elif gfx_checks.has(key) and gfx_checks[key] != null:
			gfx_checks[key].button_pressed = bool(GFX_DEFAULTS[key])
	var settings := _read_graphics_from_ui()
	_apply_graphics_settings(settings)
	_save_graphics_settings(settings)
	_flash("Graphics reset", Color("90CAF9"))


func _load_graphics_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GFX_CFG_PATH) != OK:
		return
	for key in GFX_DEFAULTS:
		if not cfg.has_section_key("gfx", key):
			continue
		var val = cfg.get_value("gfx", key)
		if gfx_sliders.has(key) and gfx_sliders[key] != null:
			gfx_sliders[key].set_value_no_signal(float(val))
			var row: Node = gfx_sliders[key].get_parent()
			if row and row.get_child_count() > 0:
				var top = row.get_child(0)
				var val_lab = top.get_node_or_null("Val") if top else null
				if val_lab:
					val_lab.text = "%.2f" % float(val)
		elif gfx_checks.has(key) and gfx_checks[key] != null:
			gfx_checks[key].set_pressed_no_signal(bool(val))


func _save_graphics_settings(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(GFX_CFG_PATH) ## keep other sections if any
	for key in s:
		cfg.set_value("gfx", key, s[key])
	cfg.save(GFX_CFG_PATH)


func _build_pause_button() -> void:
	## Top-left pause — closes the service window / customer rush.
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	window_pause_btn = Button.new()
	window_pause_btn.name = "WindowPauseBtn"
	window_pause_btn.text = "PAUSE"
	window_pause_btn.focus_mode = Control.FOCUS_NONE
	window_pause_btn.z_index = 30
	window_pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	window_pause_btn.position = Vector2(12, 10)
	window_pause_btn.custom_minimum_size = Vector2(110, 36)
	UiFontsScript.apply_button(window_pause_btn, true, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.28, 0.42)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(0.55, 0.75, 1.0, 0.7)
	sb.set_border_width_all(2)
	window_pause_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.28, 0.42, 0.6)
	window_pause_btn.add_theme_stylebox_override("hover", sbh)
	window_pause_btn.add_theme_color_override("font_color", Color.WHITE)
	window_pause_btn.pressed.connect(func():
		_sfx_click()
		_toggle_service_window()
	)
	ui_root.add_child(window_pause_btn)


func _spin_radio_dial(dir: int) -> void:
	if radio_dial_mesh == null or not is_instance_valid(radio_dial_mesh):
		return
	var tw := create_tween()
	tw.tween_property(radio_dial_mesh, "rotation_degrees:z", radio_dial_mesh.rotation_degrees.z + dir * 40.0, 0.18)


func _on_radio_status(text: String) -> void:
	if radio_status_label:
		radio_status_label.text = text


func _on_radio_channel(_index: int, _title: String) -> void:
	_refresh_radio_ui()


func _on_radio_powered(on: bool) -> void:
	_refresh_radio_ui()
	if radio_light_mat:
		radio_light_mat.emission_energy_multiplier = 1.8 if on else 0.15
		radio_light_mat.albedo_color = Color(0.25, 0.85, 0.4) if on else Color(0.15, 0.35, 0.18)


func _refresh_radio_ui() -> void:
	if radio == null:
		return
	if radio_power_btn:
		radio_power_btn.text = "ON" if radio.powered else "OFF"
	if radio_channel_label:
		radio_channel_label.text = radio.short_title()


func _try_grill_raycast(screen_pos: Vector2, place_patty: bool) -> void:
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	## Right-click place: don't let Build chrome swallow near-miss grill clicks.
	if not place_patty and _blocks_grill_pick(screen_pos):
		return
	if not place_patty:
		var picked = _pick_patty_at_screen(screen_pos)
		if picked != null:
			_begin_patty_drag(picked)
			return
	var plane_hit := _grill_plane_from_screen(screen_pos)
	if plane_hit != Vector3.ZERO:
		if place_patty:
			_try_place_patty_at(plane_hit)
		else:
			_on_grill_surface_clicked(false, plane_hit)
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
		if place_patty:
			_try_place_patty_at(hit.position)
		else:
			_on_grill_surface_clicked(false, hit.get("position", Vector3.ZERO))
		return
	if place_patty and absf(dir.y) > 0.001:
		var t := (GRILL_SURFACE_Y - from.y) / dir.y
		if t > 0.0:
			_try_place_patty_at(from + dir * t)


func _place_nearest_slot(world_pos: Vector3) -> void:
	## Right-click ray miss fallback — place exactly where the ray hits the grill plane.
	if Time.get_ticks_msec() / 1000.0 < grill_ignore_pad_until:
		return
	_try_place_patty_at(world_pos)


func _spawn_patty_on_grill() -> void:
	## Hotkey fallback: drop near center of the usable grill area.
	var bounds := _grill_place_bounds()
	var pos := Vector3(bounds.get_center().x, GRILL_SURFACE_Y, bounds.get_center().y)
	for _try in 8:
		if not _patty_blocked_at(pos):
			break
		pos.x = lerpf(bounds.position.x, bounds.end.x, randf())
		pos.z = lerpf(bounds.position.y, bounds.end.y, randf())
	_try_place_patty_at(pos)


func _first_empty_slot() -> int:
	for i in GRILL_SLOTS:
		if grill[i] == null:
			return i
	return -1


func _clear_spatula() -> void:
	if spatula_patty != null and is_instance_valid(spatula_patty):
		spatula_patty.queue_free()
	spatula_patty = null
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()


# --- Customers --------------------------------------------------------------

func _spawn_customer() -> void:
	var order: Array[String] = GameDataScript.generate_order(difficulty)
	var c = CustomerScript.new()
	var color: Color = GameDataScript.CUSTOMER_COLORS[randi() % GameDataScript.CUSTOMER_COLORS.size()]
	var patience := lerpf(62.0, 30.0, difficulty) + randf_range(-3, 5)
	if day == 1:
		## Still forgiving, but not endless.
		patience += 32.0
	elif day == 2:
		patience += 20.0
	elif day == 3:
		patience += 10.0
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


func _queue_customer_dialogue(_customer: Node3D) -> void:
	## Dialogue disabled.
	pass


func _build_dialogue_ui() -> void:
	var ui_root: Control = get_node("UI/Root")
	dialogue_panel = PanelContainer.new()
	dialogue_panel.visible = false
	dialogue_panel.z_index = 40
	dialogue_panel.custom_minimum_size = Vector2(420, 0)
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dialogue_panel.offset_left = -210.0
	dialogue_panel.offset_right = 210.0
	dialogue_panel.offset_top = 48.0
	dialogue_panel.offset_bottom = 48.0
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 0.96)
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.78, 0.35)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	dialogue_panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(dialogue_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(v)

	dialogue_title = Label.new()
	dialogue_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_label(dialogue_title, true, 20)
	dialogue_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	dialogue_title.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_title.add_theme_constant_override("outline_size", 4)
	v.add_child(dialogue_title)

	dialogue_body = Label.new()
	dialogue_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_body.custom_minimum_size = Vector2(380, 0)
	UiFontsScript.apply_label(dialogue_body, false, 15)
	dialogue_body.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	v.add_child(dialogue_body)

	dialogue_options = VBoxContainer.new()
	dialogue_options.add_theme_constant_override("separation", 6)
	v.add_child(dialogue_options)


func _open_customer_dialogue(_customer: Node3D) -> void:
	## Dialogue disabled.
	pass


func _resolve_customer_dialogue(_tone: String) -> void:
	## Dialogue disabled.
	if dialogue_panel:
		dialogue_panel.visible = false
	dialogue_customer = null
	dialogue_queue.clear()


func _resolve_order_complaint(cust: Node3D, action: String) -> void:
	var st_i := complaint_station
	complaint_station = -1
	match action:
		"fix":
			if st_i >= 0:
				_select_station(st_i)
			var miss := "the missing items"
			if cust != null and is_instance_valid(cust) and "pending_missing" in cust and not cust.pending_missing.is_empty():
				if cust.has_method("_missing_label_list"):
					miss = cust._missing_label_list()
				cust.pending_missing.clear()
			_flash("They demanded %s — fix Station %d, then Serve" % [miss, st_i + 1], Color("FFE082"))
			_update_hud()
		"refund":
			var refund := 8
			if cust != null and is_instance_valid(cust):
				refund = maxi(4, int(cust.order_value))
			money = maxi(0, money - refund)
			combo = 0
			if st_i >= 0:
				_clear_station(st_i)
			_flash("Refunded $%d — they left without the food" % refund, Color("EF5350"))
			if cust != null and is_instance_valid(cust) and cust.has_method("leave_after_dispute"):
				cust.leave_after_dispute()
			_update_hud()
		"take_food":
			combo = 0
			if st_i >= 0:
				_clear_station(st_i)
			_flash("They took the incomplete burger and left — no pay", Color("FF8A65"))
			if cust != null and is_instance_valid(cust) and cust.has_method("leave_after_dispute"):
				cust.leave_after_dispute()
			_update_hud()
		_:
			pass


func _advance_dialogue_queue() -> void:
	while not dialogue_queue.is_empty():
		var next = dialogue_queue.pop_front()
		if next != null and is_instance_valid(next) and not next.is_leaving and next.needs_dialogue():
			_open_customer_dialogue(next)
			return


func _close_dialogue_if_customer(customer: Node3D) -> void:
	if dialogue_customer == customer:
		dialogue_customer = null
		if dialogue_panel:
			dialogue_panel.visible = false
		if customer != null and is_instance_valid(customer):
			customer.dialogue_open = false
		_advance_dialogue_queue()
	else:
		dialogue_queue = dialogue_queue.filter(func(c): return c != customer and c != null and is_instance_valid(c))


func _on_customer_left(customer: Node3D, angry: bool) -> void:
	_close_dialogue_if_customer(customer)
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
	## Post-it pinned along the top of the window — one ingredient per line.
	var note := PanelContainer.new()
	note.custom_minimum_size = Vector2(220, 0)
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 0.97, 1.0)
	style.border_color = Color(0.88, 0.86, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	note.add_theme_stylebox_override("panel", style)
	note.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_ticket(customer)
			note.accept_event()
	)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	note.add_child(v)

	var pin := ColorRect.new()
	pin.custom_minimum_size = Vector2(8, 8)
	pin.color = Color(0.85, 0.2, 0.22)
	pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pin)

	var title := Label.new()
	title.text = "$%d" % customer.order_value
	UiFontsScript.apply_ticket(title, 24)
	title.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var parts: Array[String] = []
	var patty_count := 0
	for item in customer.order:
		if item == "patty":
			patty_count += 1
	var listed_double := false
	for item in customer.order:
		if item == "bun_bottom" or item == "bun_top":
			continue
		## Single patty is implied — only call out doubles on the note.
		if item == "patty":
			if patty_count >= 2 and not listed_double:
				parts.append("DOUBLE PATTY")
				listed_double = true
			continue
		var label_txt: String = str(GameDataScript.INGREDIENT_LABELS.get(item, item)).to_upper()
		parts.append(label_txt)
	var body := Label.new()
	body.text = ("\n".join(parts) if parts.size() > 0 else "BURGER")
	## Caveat handwriting — marker-on-slip feel.
	UiFontsScript.apply_ticket(body, 28)
	body.add_theme_color_override("font_color", Color(0.14, 0.1, 0.08))
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)

	ticket_box.add_child(note)
	tickets[customer] = note
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
		var note = tickets[cust]
		if not is_instance_valid(note):
			continue
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 10
		style.shadow_color = Color(0, 0, 0, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2(2, 3)
		if cust == selected_customer:
			style.bg_color = Color(1.0, 0.98, 0.82, 1.0)
			style.border_color = Color("F57C00")
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(1.0, 1.0, 0.97, 1.0)
			style.border_color = Color(0.88, 0.86, 0.78)
			style.set_border_width_all(1)
		note.add_theme_stylebox_override("panel", style)


func _clear_customers() -> void:
	dialogue_queue.clear()
	dialogue_customer = null
	if dialogue_panel:
		dialogue_panel.visible = false
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
	ingredient_buttons.clear()
	ingredient_legend.add_theme_constant_override("separation", 6)

	## Compact Serve on the left of the bottom ingredient strip.
	var serve_btn := Button.new()
	serve_btn.text = "SERVE!"
	serve_btn.custom_minimum_size = Vector2(88, 84)
	serve_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(serve_btn, true, 18)
	var serve_sb := StyleBoxFlat.new()
	serve_sb.bg_color = Color(0.2, 0.72, 0.35)
	serve_sb.set_corner_radius_all(12)
	serve_sb.content_margin_left = 8
	serve_sb.content_margin_right = 8
	serve_sb.content_margin_top = 6
	serve_sb.content_margin_bottom = 6
	serve_sb.border_color = Color(0.85, 1.0, 0.55)
	serve_sb.set_border_width_all(2)
	serve_btn.add_theme_stylebox_override("normal", serve_sb)
	var serve_hover := serve_sb.duplicate()
	serve_hover.bg_color = Color(0.32, 0.85, 0.42)
	serve_btn.add_theme_stylebox_override("hover", serve_hover)
	serve_btn.add_theme_color_override("font_color", Color.WHITE)
	serve_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	serve_btn.add_theme_constant_override("outline_size", 4)
	serve_btn.pressed.connect(func():
		_sfx_click()
		_on_serve()
	)
	ingredient_legend.add_child(serve_btn)

	## Horizontal strip of toppings along the bottom.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.12, 0.13, 0.16, 0.94)
	panel_sb.set_corner_radius_all(12)
	panel_sb.content_margin_left = 8
	panel_sb.content_margin_right = 8
	panel_sb.content_margin_top = 6
	panel_sb.content_margin_bottom = 6
	panel_sb.border_color = Color(0.35, 0.38, 0.44)
	panel_sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_sb)
	ingredient_legend.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var strip_bg := Color(0.18, 0.20, 0.24, 1.0)
	var strip_hover := Color(0.24, 0.27, 0.32, 1.0)
	var strip_press := Color(0.28, 0.32, 0.38, 1.0)

	for hi in range(INGREDIENT_HOTKEYS.size() - 1, -1, -1):
		var id: String = INGREDIENT_HOTKEYS[hi]
		var tbtn := Button.new()
		tbtn.custom_minimum_size = Vector2(86, 76)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.focus_mode = Control.FOCUS_NONE
		tbtn.flat = true
		tbtn.tooltip_text = "%s (%s)" % [GameDataScript.INGREDIENT_LABELS[id], HOTKEY_LABELS[hi]]

		var tsb := StyleBoxFlat.new()
		tsb.bg_color = strip_bg
		tsb.set_corner_radius_all(10)
		tsb.content_margin_left = 4
		tsb.content_margin_right = 4
		tsb.content_margin_top = 4
		tsb.content_margin_bottom = 4
		tsb.border_color = Color(0.32, 0.35, 0.4)
		tsb.set_border_width_all(1)
		tbtn.add_theme_stylebox_override("normal", tsb)
		var tsbh := tsb.duplicate()
		tsbh.bg_color = strip_hover
		tsbh.border_color = Color("FFB74D")
		tbtn.add_theme_stylebox_override("hover", tsbh)
		var tsbp := tsb.duplicate()
		tsbp.bg_color = strip_press
		tbtn.add_theme_stylebox_override("pressed", tsbp)

		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tbtn.add_child(col)

		var icon := TextureRect.new()
		icon.texture = FoodSpritesScript.get_tex(id)
		icon.custom_minimum_size = Vector2(64, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)

		var name_lab := Label.new()
		name_lab.text = "%s %s" % [HOTKEY_LABELS[hi], GameDataScript.INGREDIENT_LABELS[id]]
		UiFontsScript.apply_label(name_lab, true, 11)
		name_lab.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
		name_lab.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lab.add_theme_constant_override("outline_size", 2)
		name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_lab)

		var capture: String = id
		tbtn.pressed.connect(func():
			## Drag already handled cheese as a topping — don't also pick it up.
			if capture == "cheese" and _strip_did_drag:
				_strip_did_drag = false
				return
			_strip_did_drag = false
			_add_ingredient(capture)
		)
		tbtn.set_drag_forwarding(
			func(_pos):
				_strip_did_drag = true
				if capture == "cheese":
					_cancel_cheese_hold_silent()
				var drag_preview := TextureRect.new()
				drag_preview.texture = FoodSpritesScript.get_tex(capture)
				drag_preview.custom_minimum_size = Vector2(120, 48)
				drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tbtn.set_drag_preview(drag_preview)
				return {"kind": "ingredient", "id": capture, "station": active_station},
			Callable(),
			Callable()
		)
		row.add_child(tbtn)
		ingredient_buttons[id] = tbtn


func _shake_ingredient_button(btn: Control) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	## Snap size if not laid out yet
	if btn.size.x < 1.0:
		btn.pivot_offset = Vector2(66, 34)
	var tw := create_tween()
	tw.tween_property(btn, "rotation_degrees", 10.0, 0.04)
	tw.tween_property(btn, "rotation_degrees", -10.0, 0.05)
	tw.tween_property(btn, "rotation_degrees", 6.0, 0.04)
	tw.tween_property(btn, "rotation_degrees", 0.0, 0.05)
	var tw2 := create_tween()
	tw2.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.06)
	tw2.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	## Brief gold flash on the strip
	var flash := StyleBoxFlat.new()
	flash.bg_color = Color(0.45, 0.38, 0.18)
	flash.set_corner_radius_all(12)
	flash.border_color = Color("FFEB3B")
	flash.set_border_width_all(3)
	flash.content_margin_left = 6
	flash.content_margin_right = 8
	flash.content_margin_top = 6
	flash.content_margin_bottom = 6
	var prev_normal = btn.get_theme_stylebox("normal")
	btn.add_theme_stylebox_override("normal", flash)
	get_tree().create_timer(0.18).timeout.connect(func():
		if is_instance_valid(btn) and prev_normal:
			btn.add_theme_stylebox_override("normal", prev_normal)
	)


func _pulse_ingredient_feedback(id: String) -> void:
	if ingredient_buttons.has(id):
		_shake_ingredient_button(ingredient_buttons[id])
	if game_audio:
		game_audio.play_ingredient(id)
	var label: String = GameDataScript.INGREDIENT_LABELS.get(id, id)
	_flash("+ %s" % label, Color("FFE082"))
	_note_melody_press(id)


func _note_melody_press(id: String) -> void:
	## Ascending kitchen scale — once every strip note is hit, fire the jingle.
	if not INGREDIENT_HOTKEYS.has(id):
		return
	_melody_pressed[id] = true
	if _melody_pressed.size() < INGREDIENT_HOTKEYS.size():
		return
	_melody_pressed.clear()
	if game_audio and game_audio.has_method("play_scale_jingle"):
		game_audio.play_scale_jingle()
	_flash("Full stack melody! ★", Color("FFEB3B"))


func _build_station_ui() -> void:
	## Sit further screen-left so the far-left grill stays clickable.
	stations_row.offset_left = -70.0
	stations_row.offset_right = 250.0
	stations_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stations_row.custom_minimum_size = Vector2(300, 0)
	stations_row.alignment = BoxContainer.ALIGNMENT_END
	for child in stations_row.get_children():
		child.queue_free()
	for i in STATION_COUNT:
		## Plain Control — no PanelContainer chrome / bounding box.
		var panel := Control.new()
		panel.custom_minimum_size = Vector2(260, 320)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		## Empty panel area passes through to the 3D grill behind.
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var root_v := VBoxContainer.new()
		root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_v.add_theme_constant_override("separation", 2)
		root_v.alignment = BoxContainer.ALIGNMENT_END
		root_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(root_v)

		var title := Label.new()
		title.text = "drag patty here"
		UiFontsScript.apply_label(title, true, 14)
		title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 4)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_v.add_child(title)

		## Stage sized for mid-large burger art — tight hitbox around the board.
		var plate_wrap := Control.new()
		plate_wrap.custom_minimum_size = Vector2(205, 195)
		plate_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
		plate_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		plate_wrap.clip_contents = false
		root_v.add_child(plate_wrap)

		## Catches clicks over the grill behind the burger / yellow selection box.
		var grill_blocker := ColorRect.new()
		grill_blocker.name = "GrillPickBlocker"
		grill_blocker.color = Color(0, 0, 0, 0)
		grill_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		grill_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		grill_blocker.z_index = -1
		plate_wrap.add_child(grill_blocker)

		var board := TextureRect.new()
		board.name = "CuttingBoard"
		board.texture = FoodSpritesScript.get_tex("cutting_board")
		board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.z_as_relative = true
		board.z_index = 0
		## Board under the burger stack (~30% larger).
		board.set_anchors_preset(Control.PRESET_CENTER)
		board.grow_horizontal = Control.GROW_DIRECTION_BOTH
		board.grow_vertical = Control.GROW_DIRECTION_BOTH
		board.custom_minimum_size = Vector2(195, 137)
		board.size = Vector2(195, 137)
		board.position = Vector2(-98, -39)
		plate_wrap.add_child(board)

		## Absolute stack of floating ingredient sprites on top of the board.
		var burger_stack := Control.new()
		burger_stack.name = "BurgerStack"
		burger_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		burger_stack.z_as_relative = true
		burger_stack.z_index = 1
		burger_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate_wrap.add_child(burger_stack)

		var si := i
		var drop_btn := Button.new()
		drop_btn.text = "Drop Patty"
		drop_btn.custom_minimum_size = Vector2(0, 22)
		UiFontsScript.apply_button(drop_btn, true, 12)
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color("E65100")
		dsb.set_corner_radius_all(6)
		drop_btn.add_theme_stylebox_override("normal", dsb)
		var dsbh := dsb.duplicate()
		dsbh.bg_color = Color("FF8A50")
		drop_btn.add_theme_stylebox_override("hover", dsbh)
		drop_btn.add_theme_color_override("font_color", Color.WHITE)
		drop_btn.visible = false
		drop_btn.pressed.connect(func():
			_sfx_click()
			_on_station_plate_clicked(si)
		)
		root_v.add_child(drop_btn)

		var btns := HBoxContainer.new()
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		btns.add_theme_constant_override("separation", 5)
		root_v.add_child(btns)

		var fresh_label := Label.new()
		fresh_label.text = "--"
		fresh_label.custom_minimum_size = Vector2(78, 0)
		UiFontsScript.apply_label(fresh_label, true, 12)
		fresh_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
		fresh_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fresh_label.add_theme_constant_override("outline_size", 3)
		fresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fresh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fresh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btns.add_child(fresh_label)

		var serve_one := Button.new()
		serve_one.text = "Serve"
		serve_one.custom_minimum_size = Vector2(64, 24)
		UiFontsScript.apply_button(serve_one, true, 12)
		serve_one.pressed.connect(func():
			_sfx_click()
			_select_station(si)
			_on_serve()
		)
		btns.add_child(serve_one)

		var trash_one := Button.new()
		trash_one.text = "🗑"
		trash_one.tooltip_text = "Trash selected layer (or top)"
		trash_one.custom_minimum_size = Vector2(32, 24)
		UiFontsScript.apply_button(trash_one, true, 12)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.45, 0.18, 0.16)
		tsb.set_corner_radius_all(6)
		trash_one.add_theme_stylebox_override("normal", tsb)
		var tsbh := tsb.duplicate()
		tsbh.bg_color = Color(0.65, 0.25, 0.2)
		trash_one.add_theme_stylebox_override("hover", tsbh)
		trash_one.add_theme_color_override("font_color", Color.WHITE)
		trash_one.pressed.connect(func():
			_sfx_click()
			_select_station(si)
			_trash_selected_or_top_layer(si)
		)
		btns.add_child(trash_one)

		var clear_one := Button.new()
		clear_one.text = "All"
		clear_one.tooltip_text = "Clear whole burger"
		clear_one.custom_minimum_size = Vector2(36, 24)
		UiFontsScript.apply_button(clear_one, false, 11)
		clear_one.pressed.connect(func():
			_sfx_click()
			_select_station(si)
			_clear_station(si)
			_flash("%s cleared" % _station_label(si), Color("B0BEC5"))
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
		panel.set_drag_forwarding(
			Callable(),
			func(_pos, data): return _can_drop_on_assembly(si, data),
			func(pos, data): _drop_on_assembly(si, pos, data)
		)
		panel.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if cheese_held or spatula_patty != null:
					_on_station_plate_clicked(si)
					panel.accept_event()
				else:
					_select_station(si)
		)

		stations_row.add_child(panel)
		stations[i]["panel"] = panel
		stations[i]["preview"] = burger_stack
		stations[i]["board"] = board
		stations[i]["title"] = title
		stations[i]["plate"] = plate_wrap
		stations[i]["drop_hint"] = null
		stations[i]["drop_btn"] = drop_btn
		stations[i]["fresh_label"] = fresh_label
		_refresh_freshness_label(i)
	## Click anywhere on the Build column while holding a scooped patty.
	if not stations_row.gui_input.is_connected(_on_stations_row_gui_input):
		stations_row.gui_input.connect(_on_stations_row_gui_input)
	_highlight_active_station()


func _on_stations_row_gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if spatula_patty != null or cheese_held:
		_on_station_plate_clicked(STATION_CRAFT)
		stations_row.accept_event()


func _make_reorder_drag(station_index: int, from_index: int, item_id: String) -> Dictionary:
	return {"kind": "reorder", "station": station_index, "from": from_index, "id": item_id}


func _make_station_patty_drag(station_index: int, from_index: int, patty_index: int) -> Dictionary:
	return {
		"kind": "station_patty",
		"station": station_index,
		"from": from_index,
		"patty_index": patty_index,
		"id": "patty",
	}


func _build_grill_drop_zone() -> void:
	## Drop target over the 3D grill (skips the left station column).
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	grill_drop_zone = Control.new()
	grill_drop_zone.name = "GrillDropZone"
	grill_drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	## Leave the left Build column free for station drops.
	grill_drop_zone.offset_left = 260.0
	grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grill_drop_zone.z_index = 8
	ui_root.add_child(grill_drop_zone)
	grill_drop_zone.set_drag_forwarding(
		Callable(),
		func(_pos, data): return _can_drop_station_patty_on_grill(data),
		func(_pos, data): _drop_station_patty_on_grill(data)
	)


func _on_gui_drag_ended(_was_accepted: bool) -> void:
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _arm_grill_drop_zone() -> void:
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
		grill_drop_zone.z_index = 8


func _build_window_pause_ui() -> void:
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	## Dark shutter over the service window view.
	window_shutter = ColorRect.new()
	window_shutter.name = "WindowShutter"
	window_shutter.visible = false
	window_shutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_shutter.color = Color(0.04, 0.045, 0.06, 0.82)
	window_shutter.z_index = 4
	window_shutter.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_shutter.offset_left = 300.0
	window_shutter.offset_top = 40.0
	window_shutter.offset_right = -20.0
	window_shutter.offset_bottom = -120.0
	ui_root.add_child(window_shutter)
	var closed_lab := Label.new()
	closed_lab.text = "WINDOW CLOSED"
	UiFontsScript.apply_label(closed_lab, true, 36)
	closed_lab.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	closed_lab.add_theme_color_override("font_outline_color", Color.BLACK)
	closed_lab.add_theme_constant_override("outline_size", 8)
	closed_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	closed_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	closed_lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	closed_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_shutter.add_child(closed_lab)


func _toggle_service_window() -> void:
	if not playing:
		return
	if service_window_closed:
		_open_service_window()
	else:
		_close_service_window()


func _close_service_window() -> void:
	service_window_closed = true
	service_break_left = SERVICE_BREAK_SEC
	_clear_customers()
	spawn_timer = SERVICE_BREAK_SEC
	if window_shutter:
		window_shutter.visible = true
	if window_pause_btn:
		window_pause_btn.text = "OPEN (%ds)" % int(SERVICE_BREAK_SEC)
	_flash("Paused — customers left for a bit", Color("90CAF9"))


func _open_service_window() -> void:
	service_window_closed = false
	service_break_left = 0.0
	spawn_timer = 4.0
	if window_shutter:
		window_shutter.visible = false
	if window_pause_btn:
		window_pause_btn.text = "PAUSE"
	_flash("Back on — customers on the way", Color("A5D6A7"))


func _reset_service_window_open() -> void:
	service_window_closed = false
	service_break_left = 0.0
	if window_shutter:
		window_shutter.visible = false
	if window_pause_btn:
		window_pause_btn.text = "PAUSE"


func _can_drop_station_patty_on_grill(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if str(data.get("kind", "")) != "station_patty":
		return false
	var mouse := get_viewport().get_mouse_position()
	## Don't steal drops meant for station panels.
	if _station_index_at(mouse) >= 0:
		return false
	var hit := _grill_plane_from_screen(mouse)
	return hit != Vector3.ZERO and _is_on_grill_surface(hit)


func _drop_station_patty_on_grill(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var station_index := int(data.get("station", -1))
	var from_index := int(data.get("from", -1))
	var mouse := get_viewport().get_mouse_position()
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		_flash("Drop on the grill surface", Color("FFCC80"))
		return
	if not _return_station_patty_to_grill(station_index, from_index, hit):
		pass


func _patty_index_for_item_slot(station_index: int, item_index: int) -> int:
	if station_index < 0 or station_index >= STATION_COUNT:
		return -1
	var items: Array = stations[station_index]["items"]
	if item_index < 0 or item_index >= items.size() or str(items[item_index]) != "patty":
		return -1
	var pidx := 0
	for j in range(item_index + 1):
		if str(items[j]) == "patty":
			pidx += 1
	return pidx - 1


func _extract_station_patty(station_index: int, item_index: int):
	## Pull one patty out of a station stack (and its melted cheese entry).
	if station_index < 0 or station_index >= STATION_COUNT:
		return null
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if item_index < 0 or item_index >= items.size() or str(items[item_index]) != "patty":
		return null
	var pidx := _patty_index_for_item_slot(station_index, item_index)
	if pidx < 0 or pidx >= st["patties"].size():
		return null
	var patty = st["patties"][pidx]
	if patty == null or not is_instance_valid(patty):
		return null
	st["patties"].remove_at(pidx)
	items.remove_at(item_index)
	## Melted grill cheese travels with the patty.
	if patty.has_cheese:
		var cidx := items.find("cheese")
		if cidx >= 0:
			items.remove_at(cidx)
	## If only the automatic bottom bun remains, clear the craft station.
	if items.size() == 1 and str(items[0]) == "bun_bottom":
		items.clear()
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	if items.is_empty():
		_reset_station_freshness(station_index)
	else:
		_start_station_freshness(station_index)
	_refresh_station(station_index)
	return patty


func _return_station_patty_to_grill(station_index: int, item_index: int, world_pos: Vector3) -> bool:
	if not playing:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("EF5350"))
		return false
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill is full (%d patties)!" % GRILL_SLOTS, Color("EF5350"))
		return false
	if not _is_on_grill_surface(world_pos):
		_flash("Drop on the grill surface", Color("FFCC80"))
		return false
	var pos := Vector3(world_pos.x, GRILL_SURFACE_Y, world_pos.z)
	if not _can_fit_patty_at(pos):
		_flash("Too close to the edge — keep the patty on the grill", Color("FFA726"))
		return false
	if _patty_blocked_at(pos):
		## Nudge toward an open spot near the drop.
		var placed := false
		var bounds := _grill_place_bounds()
		for _try in 12:
			pos.x = lerpf(bounds.position.x, bounds.end.x, randf())
			pos.z = lerpf(bounds.position.y, bounds.end.y, randf())
			if _can_fit_patty_at(pos) and not _patty_blocked_at(pos):
				placed = true
				break
		if not placed:
			_flash("Too crowded — clear a spot first", Color("EF5350"))
			return false
	var patty = _extract_station_patty(station_index, item_index)
	if patty == null:
		_flash("Couldn't grab that patty", Color("EF5350"))
		return false
	## Same cooked patty returns to the grill — keep cook_time / flip / cheese.
	patty.is_held = false
	patty.visible = true
	patty.slot_index = idx
	patty.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	patty.heating = grill_on
	patty.heat_mul = _warmer_heat_mul(pos) * _oil_heat_mul(pos)
	patty.position = Vector3(pos.x, patty.base_y, pos.z)
	patty._rest_x = pos.x
	patty._rest_z = pos.z
	if patty.get_parent() == null:
		patties_root.add_child(patty)
	grill[idx] = patty
	slot_positions[idx] = Vector3(pos.x, GRILL_SURFACE_Y, pos.z)
	if patty.has_method("refresh_cook_visuals"):
		patty.refresh_cook_visuals()
	if game_audio:
		game_audio.play_click()
	var cook_note: String = str(patty.cook_rating_text()) if patty.has_method("cook_rating_text") else "cooked"
	if patty.has_cheese:
		_flash("Back on grill (%s) — cheese melting" % cook_note, Color("FFE082"))
	else:
		_flash("Back on grill (%s) — same cook level" % cook_note, Color("A5D6A7"))
	return true


func _move_station_patty(from_station: int, from_index: int, to_station: int, at_pos: Vector2) -> void:
	if from_station < 0 or from_station >= STATION_COUNT:
		return
	if to_station < 0 or to_station >= STATION_COUNT:
		return
	## Same station → just reorder like a normal layer drag.
	if from_station == to_station:
		var insert_at := _assembly_insert_index(to_station, at_pos)
		_reorder_station_item(from_station, from_index, insert_at)
		return
	var patty = _extract_station_patty(from_station, from_index)
	if patty == null:
		return
	## Temporarily park on spatula path used by station drop.
	spatula_patty = patty
	_drop_spatula_on_station(to_station)
	if spatula_patty != null:
		## Drop failed — put it back where it came from.
		_drop_spatula_on_station(from_station)
		return
	_flash("Moved patty to %s" % _station_label(to_station), Color("A5D6A7"))


func _can_drop_on_assembly(station_index: int, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = data.get("kind", "")
	return kind == "ingredient" or kind == "reorder" or kind == "station_patty"


func _drop_on_assembly(station_index: int, at_pos: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	_select_station(station_index)
	var kind: String = data.get("kind", "")
	if kind == "ingredient":
		var id := str(data.get("id", ""))
		if id == "cheese":
			_cancel_cheese_hold_silent()
		_add_ingredient_to_station(station_index, id)
		return
	if kind == "station_patty":
		## Dropping back on a station keeps / moves the patty in the stack.
		_move_station_patty(int(data.get("station", -1)), int(data.get("from", -1)), station_index, at_pos)
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
	if cheese_held:
		_cancel_cheese_hold_silent()
		_add_ingredient_to_station(index, "cheese", true)
		return
	if spatula_patty != null:
		_drop_spatula_on_station(index)
	else:
		_flash("Build — drop a patty, then toppings · Serve when ready", Color("FFE082"))


func _select_station(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	active_station = index
	_highlight_active_station()


func _make_station_clear_style(_active: bool) -> StyleBoxEmpty:
	## No fill / border — stations are just the floating board.
	return StyleBoxEmpty.new()


func _make_station_wood_style(active: bool) -> StyleBoxEmpty:
	return _make_station_clear_style(active)


func _highlight_active_station() -> void:
	for i in STATION_COUNT:
		var panel: Control = stations[i]["panel"]
		if panel == null:
			continue
		var active := i == active_station
		var board = stations[i].get("board", null)
		if board != null and is_instance_valid(board):
			board.modulate = Color(1.12, 1.06, 0.95) if active else Color(0.94, 0.92, 0.9)


func _drop_spatula_on_station(index: int) -> void:
	if not playing or spatula_patty == null:
		return
	if index < 0 or index >= STATION_COUNT:
		return
	var patty = spatula_patty
	spatula_patty = null
	_commit_patty_to_build(patty)
	if index != STATION_CRAFT:
		## Only one craft station today — keep API for future multi-station.
		_select_station(index)


func _insert_patty_into_stack(items: Array) -> void:
	## Patties always sit above bottom bun(s), below toppings.
	items.append("patty")


func _normalize_burger_stack(items: Array) -> Array:
	## Canonical order: bottom bun(s) -> patty(s) -> toppings (fixed kitchen order) -> top bun(s).
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
	middles = GameDataScript.sort_toppings(middles)
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
	if id == "bun_bottom":
		return
	_pulse_ingredient_feedback(id)
	## Cheese: pick up a ghost slice, then click a grill patty to place it.
	if id == "cheese":
		_begin_cheese_hold()
		return
	_add_ingredient_to_station(active_station, id, false)


func _begin_cheese_hold() -> void:
	if not playing or brush_held or oil_held or shaker_held or spatula_patty != null:
		return
	if cheese_held:
		_cancel_cheese_hold()
		return
	cheese_held = true
	_ensure_cheese_ghost()
	if cheese_ghost:
		cheese_ghost.visible = true
	if game_audio:
		game_audio.play_ingredient("cheese")
	_flash("Cheese ready — left-click to place · right-click returns to stack", Color("FFE082"))


func _cancel_cheese_hold() -> void:
	cheese_held = false
	if cheese_ghost and is_instance_valid(cheese_ghost):
		cheese_ghost.visible = false
	_flash("Cheese back on the stack", Color("B0BEC5"))


func _cancel_cheese_hold_silent() -> void:
	cheese_held = false
	if cheese_ghost and is_instance_valid(cheese_ghost):
		cheese_ghost.visible = false


func _ensure_cheese_ghost() -> void:
	if cheese_ghost != null and is_instance_valid(cheese_ghost):
		return
	cheese_ghost = MeshInstance3D.new()
	cheese_ghost.name = "CheeseGhost"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.13, 0.006, 0.13)
	cheese_ghost.mesh = mesh
	cheese_ghost_mat = StandardMaterial3D.new()
	cheese_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cheese_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheese_ghost_mat.albedo_color = Color(1.0, 0.95, 0.32, 0.42)
	cheese_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cheese_ghost.material_override = cheese_ghost_mat
	cheese_ghost.visible = false
	world.add_child(cheese_ghost)


func _update_cheese_ghost() -> void:
	if not cheese_held or cheese_ghost == null or not is_instance_valid(cheese_ghost):
		return
	var target = _grill_patty_under_cursor()
	var pulse := 0.38 + 0.12 * absf(sin(Time.get_ticks_msec() * 0.008))
	if target != null and is_instance_valid(target) and not target.has_cheese:
		## Snap ghost onto the hovered patty.
		cheese_ghost.global_position = target.global_position + Vector3(0, 0.055, 0)
		cheese_ghost.rotation = target.rotation
		cheese_ghost.scale = Vector3.ONE
		if cheese_ghost_mat:
			cheese_ghost_mat.albedo_color = Color(1.0, 0.95, 0.32, pulse + 0.12)
	else:
		## Float ghost over the grill plane under the cursor.
		var hit := _grill_plane_from_screen(get_viewport().get_mouse_position())
		if hit != Vector3.ZERO:
			hit.y = GRILL_SURFACE_Y + 0.08
			cheese_ghost.global_position = hit
		cheese_ghost.rotation = Vector3.ZERO
		cheese_ghost.scale = Vector3(0.92, 1.0, 0.92)
		if cheese_ghost_mat:
			## Dimmer when not over a valid patty.
			var blocked: bool = target != null and bool(target.has_cheese)
			cheese_ghost_mat.albedo_color = Color(1.0, 0.55, 0.35, pulse * 0.7) if blocked \
				else Color(1.0, 0.95, 0.32, pulse * 0.75)


func _try_place_held_cheese(screen_pos: Vector2) -> void:
	if not cheese_held:
		return
	## Station click while holding cheese → craft toppings.
	var station_idx := _station_index_at(screen_pos)
	if station_idx >= 0:
		_cancel_cheese_hold()
		_add_ingredient_to_station(station_idx, "cheese", true)
		return
	## Same forgiving screen + plane pick used for scooping burgers.
	var target = _pick_patty_at_screen(screen_pos)
	if target == null:
		var plane := _grill_plane_from_screen(screen_pos)
		if plane != Vector3.ZERO:
			var near := _nearest_patty_to(plane, PATTY_PICK_WORLD)
			if near >= 0:
				target = grill[near]
	if target == null:
		_flash("Click a patty on the grill (or a station)", Color("FFCC80"))
		return
	if target.has_cheese:
		_flash("That patty already has cheese", Color("FFCC80"))
		return
	if target.add_cheese():
		cheese_held = false
		if cheese_ghost and is_instance_valid(cheese_ghost):
			cheese_ghost.visible = false
		if game_audio:
			game_audio.play_ingredient("cheese")
		_flash("Cheese on! Melts in 5s", Color("FFE082"))


func _update_patty_hint_focus() -> void:
	## Hovered patty keeps full (small) hint size; others shrink.
	var focused = _grill_patty_under_cursor()
	if dragging_patty != null and is_instance_valid(dragging_patty):
		focused = dragging_patty
	for p in grill:
		if p == null or not is_instance_valid(p):
			continue
		p.set_hint_focus(p == focused)


func _try_add_cheese_to_grill_patty() -> bool:
	## Legacy path unused — cheese uses hold + click now.
	return false


func _grill_patty_under_cursor():
	## Match scoop / cheese placement — screen-space pick, not a thin physics ray.
	if camera == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var picked = _pick_patty_at_screen(mouse)
	if picked != null:
		return picked
	var plane := _grill_plane_from_screen(mouse)
	if plane != Vector3.ZERO:
		var near := _nearest_patty_to(plane, PATTY_PICK_WORLD)
		if near >= 0:
			return grill[near]
	return null


func _nearest_cooking_patty():
	var best = null
	var best_d := 999.0
	for p in grill:
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		var d := Vector2(p.position.x - GRILL_CENTER_X, p.position.z - GRILL_SURFACE_Z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


func _add_cheese_to_warmer_patty(_station_index: int) -> bool:
	## UI warmer removed — cheese goes on grill patties or the Build stack.
	return false


func _add_ingredient_to_station(station_index: int, id: String, play_sfx: bool = true) -> void:
	if not playing or id == "":
		return
	if id == "bun_bottom":
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	_select_station(station_index)
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if items.size() >= 14:
		_flash("Burger too tall!", Color("EF5350"))
		return
	## Need a bottom bun + patty before toppings / top bun (except empty start).
	if id != "patty" and not items.has("patty") and st["patties"].is_empty():
		_flash("Drop a patty on the build board first", Color("FFCC80"))
		return
	if id == "cheese":
		_start_station_cheese_melt(station_index, play_sfx)
		return
	items.append(id)
	st["items"] = _normalize_burger_stack(items)
	_start_station_freshness(station_index)
	_refresh_station(station_index)
	if play_sfx and game_audio:
		game_audio.play_ingredient(id)
	if play_sfx:
		_note_melody_press(id)


func _start_station_cheese_melt(station_index: int, play_sfx: bool = true) -> void:
	## Cheese melts onto the top patty over 5 seconds on Build (same as grill).
	var st: Dictionary = stations[station_index]
	if st["patties"].is_empty():
		_flash("Drop a patty on the build board first", Color("FFCC80"))
		return
	var patty = st["patties"][st["patties"].size() - 1]
	if patty == null or not is_instance_valid(patty):
		_flash("Drop a patty on the build board first", Color("FFCC80"))
		return
	if patty.has_cheese:
		if patty.cheese_ready():
			_flash("That patty already has melted cheese", Color("FFCC80"))
		else:
			var left := maxi(1, int(ceil(5.0 * (1.0 - float(patty.cheese_melt)))))
			_flash("Cheese still melting — %ds left" % left, Color("FFE082"))
		return
	if not patty.add_cheese():
		_flash("Can't add cheese right now", Color("EF5350"))
		return
	_start_station_freshness(station_index)
	_refresh_station(station_index)
	if play_sfx and game_audio:
		game_audio.play_ingredient("cheese")
	if play_sfx:
		_note_melody_press("cheese")
	_flash("Cheese melting onto the burger — 5 seconds", Color("FFE082"))


func _update_station_cheese_melt(_delta: float) -> void:
	## When melt finishes on Build, add cheese to the stack once.
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		var melted_patties := 0
		for p2 in st["patties"]:
			if p2 != null and is_instance_valid(p2) and p2.has_cheese and p2.cheese_ready():
				melted_patties += 1
		if melted_patties <= 0:
			continue
		var items: Array = st["items"]
		var cheese_count := 0
		for item in items:
			if str(item) == "cheese":
				cheese_count += 1
		var added := 0
		while cheese_count + added < melted_patties:
			items.append("cheese")
			added += 1
		if added > 0:
			st["items"] = _normalize_burger_stack(items)
			_refresh_station(i)
			_flash("Cheese melted!", Color("FFE082"))


func _clear_active_station() -> void:
	_trash_selected_or_top_layer(active_station)


func _select_station_layer(station_index: int, layer_index: int) -> void:
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	_select_station(station_index)
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if layer_index < 0 or layer_index >= items.size():
		st["selected_layer"] = -1
	else:
		st["selected_layer"] = layer_index
	_refresh_station(station_index)
	var id: String = str(items[layer_index]) if layer_index >= 0 and layer_index < items.size() else ""
	if id != "":
		if game_audio:
			game_audio.play_ingredient(id)
		var label: String = GameDataScript.INGREDIENT_LABELS.get(id, id.capitalize())
		_flash("Selected %s - 🗑 to remove" % label, Color("FFE082"))


func _trash_selected_or_top_layer(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	var st: Dictionary = stations[index]
	var items: Array = st["items"]
	if items.is_empty():
		_flash("%s is empty" % _station_label(index), Color("B0BEC5"))
		return
	var remove_i: int = int(st.get("selected_layer", -1))
	if remove_i < 0 or remove_i >= items.size():
		remove_i = items.size() - 1
	var removed: String = str(items[remove_i])
	## Bottom bun stays under the meat — trash other layers only.
	if removed == "bun_bottom" and (items.count("patty") > 0 or st["patties"].size() > 0):
		_flash("Bottom bun stays under the patty", Color("FFCC80"))
		st["selected_layer"] = -1
		_refresh_station(index)
		return
	items.remove_at(remove_i)
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	_sync_patties_with_items(index)
	if items.is_empty():
		_reset_station_freshness(index)
	_refresh_station(index)
	var label: String = GameDataScript.INGREDIENT_LABELS.get(removed, removed.capitalize())
	if game_audio:
		game_audio.play_trash()
	_flash("Trashed %s" % label, Color("FFAB91"))


func _trash_top_layer(index: int) -> void:
	## Kept for compatibility — prefer selected layer when present.
	if index < 0 or index >= STATION_COUNT:
		return
	stations[index]["selected_layer"] = -1
	_trash_selected_or_top_layer(index)


func _clear_station(index: int) -> void:
	var st: Dictionary = stations[index]
	for p in st["patties"]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	st["patties"] = []
	st["items"] = [] as Array[String]
	st["selected_layer"] = -1
	_reset_station_freshness(index)
	_refresh_station(index)


func _clear_all_stations() -> void:
	for i in STATION_COUNT:
		_clear_station(i)


func _refresh_station(index: int) -> void:
	var st: Dictionary = stations[index]
	var preview: Control = st["preview"]
	if preview == null:
		return
	for child in preview.get_children():
		child.queue_free()
	var items: Array = st["items"]
	var selected_layer: int = int(st.get("selected_layer", -1))
	if selected_layer >= items.size():
		selected_layer = -1
		st["selected_layer"] = -1
	var drop_btn: Button = st.get("drop_btn", null)
	var plate: Control = st.get("plate", null)
	if drop_btn and is_instance_valid(drop_btn):
		drop_btn.visible = spatula_patty != null

	if items.is_empty():
		st["selected_layer"] = -1
		return

	## Fake-3D float stack: board is z0; bun/patty/toppings rise above it.
	var layer_scale := _station_layer_scale(items.size())
	var stage_w := 320.0
	var stage_h := 240.0
	if plate != null and plate.size.x > 8.0:
		stage_w = plate.size.x
		stage_h = plate.size.y
	## Bottom bun center sits on the cutting-board center.
	var bun_h0 := _layer_img_height("bun_bottom") * layer_scale
	var origin_x := stage_w * 0.5
	var origin_y := stage_h * 0.5 + bun_h0 * 0.22
	var step_y := 20.0 * layer_scale
	var layer_w := mini(300.0, stage_w * 0.88)
	## Extra lift after bottom bun so meat doesn't sit flush on the crumb.
	var stack_lift := 0.0

	for stack_i in items.size():
		var item: String = items[stack_i]
		var h := _layer_img_height(item) * layer_scale
		var this_w := layer_w * _layer_width_mul(item)
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.z_as_relative = true
		row.z_index = stack_i + 1 ## board is 0; bottom bun is 1
		var row_style := StyleBoxFlat.new()
		row_style.set_content_margin_all(0)
		row_style.set_corner_radius_all(4)
		if stack_i == selected_layer:
			row_style.bg_color = Color(1.0, 0.85, 0.25, 0.28)
			row_style.border_color = Color("FFEB3B")
			row_style.set_border_width_all(2)
		else:
			row_style.bg_color = Color(0, 0, 0, 0)
			row_style.set_border_width_all(0)
		row.add_theme_stylebox_override("panel", row_style)
		row.custom_minimum_size = Vector2(this_w, h)
		row.size = Vector2(this_w, h)
		## Rise upward from centered bottom bun; slight left lean matches iso board.
		row.position = Vector2(
			origin_x - this_w * 0.5 - float(stack_i) * 1.2,
			origin_y - stack_lift - float(stack_i) * step_y - h * 0.72
		)
		if item == "bun_bottom":
			stack_lift += 10.0 * layer_scale

		var tr := TextureRect.new()
		if item == "patty":
			var patty_from_bottom := 0
			for j in range(stack_i + 1):
				if items[j] == "patty":
					patty_from_bottom += 1
			var pidx := patty_from_bottom - 1
			var pcolor := GameDataScript.INGREDIENT_COLORS["patty"]
			if pidx >= 0 and pidx < st["patties"].size() and is_instance_valid(st["patties"][pidx]):
				pcolor = st["patties"][pidx].get_patty_color()
			tr.texture = FoodSpritesScript.patty_tex(pcolor)
		else:
			tr.texture = FoodSpritesScript.get_tex(item)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(this_w, h)
		tr.size = Vector2(this_w, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Soft drop shadow under each float layer.
		tr.modulate = Color(1, 1, 1, 1)
		row.add_child(tr)

		var from_i := stack_i
		var item_id := item
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_station_layer(index, from_i)
				row.accept_event()
		)
		row.set_drag_forwarding(
			func(_pos):
				if item_id == "patty":
					var drag_preview := TextureRect.new()
					drag_preview.texture = tr.texture
					drag_preview.custom_minimum_size = Vector2(140, 48)
					drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					row.set_drag_preview(drag_preview)
					var pidx2 := _patty_index_for_item_slot(index, from_i)
					_arm_grill_drop_zone()
					return _make_station_patty_drag(index, from_i, pidx2)
				var color_preview := ColorRect.new()
				color_preview.custom_minimum_size = Vector2(100, 16)
				color_preview.color = GameDataScript.INGREDIENT_COLORS.get(item_id, Color.GRAY)
				row.set_drag_preview(color_preview)
				return _make_reorder_drag(index, from_i, item_id),
			func(_pos, data): return _can_drop_on_assembly(index, data),
			func(pos, data): _drop_on_assembly(index, pos, data)
		)
		preview.add_child(row)


func _station_layer_scale(layer_count: int) -> float:
	## ~60% of the oversized stack, then STATION_BURGER_SCALE (default −25%).
	var base := 1.86
	if layer_count <= 4:
		base = 1.86
	elif layer_count <= 6:
		base = 1.5
	elif layer_count <= 8:
		base = 1.2
	else:
		base = 0.93
	return base * STATION_BURGER_SCALE


func _layer_width_mul(item: String) -> float:
	## Sheet art has uneven canvas fill — normalize stack silhouette.
	match item:
		"bun_top":
			return 0.82
		"bun_bottom":
			return 1.18
		"patty":
			return 1.081 ## ~15% bigger than previous 0.94
		"cheese", "lettuce", "bacon", "tomato", "onion", "pickle":
			return 1.16
		"ketchup", "mustard":
			return 0.82
		_:
			return 1.0


func _layer_img_height(item: String) -> float:
	match item:
		"bun_top":
			return 48.0
		"bun_bottom":
			return 56.0
		"patty":
			return 55.2 ## ~15% bigger than previous 48
		"bacon":
			return 46.0
		"lettuce":
			return 44.0
		"tomato", "onion", "pickle", "cheese":
			return 46.0
		"ketchup", "mustard":
			return 24.0
		_:
			return 40.0


func _refresh_all_stations() -> void:
	for i in STATION_COUNT:
		_refresh_station(i)
	_highlight_active_station()


func _refresh_spatula_ui() -> void:
	## Spatula status strip removed — stations show Drop Patty when holding.
	if held_row:
		held_row.visible = false
		for child in held_row.get_children():
			child.queue_free()
	## Arm whole Build column to catch drops while holding a scooped patty.
	if stations_row != null and is_instance_valid(stations_row):
		stations_row.mouse_filter = Control.MOUSE_FILTER_STOP if spatula_patty != null \
			else Control.MOUSE_FILTER_IGNORE
	for i in STATION_COUNT:
		var panel: Control = stations[i].get("panel", null) if i < stations.size() else null
		if panel != null and is_instance_valid(panel):
			panel.mouse_filter = Control.MOUSE_FILTER_STOP if spatula_patty != null \
				else Control.MOUSE_FILTER_IGNORE
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
	if selected_customer.dialogue_open:
		selected_customer.dialogue_open = false

	## Use any station that has a burger - prefer active, then best match for the ticket.
	var station_index := _find_station_for_order(selected_customer.order)
	if station_index < 0:
		_flash("Build the burger on any station, then Serve", Color("EF5350"))
		return

	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	active_station = station_index
	_highlight_active_station()

	var result: Dictionary = GameDataScript.compare_orders(items, selected_customer.order)
	var missing: Array = result.get("missing", [])
	## Incomplete / wrong — just reject; no dialogue popup.
	if not missing.is_empty() and float(result.get("quality", 0.0)) >= 0.35:
		combo = 0
		_flash("Missing items — fix the burger, then Serve", Color("FF8A65"))
		_update_hud()
		return

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
	var tip_factor: float = selected_customer.patience_ratio()
	var fresh_r := _station_freshness_ratio(station_index)
	if fresh_r <= 0.15:
		patty_mult *= 0.45
		tip_factor *= 0.25
	elif fresh_r <= 0.4:
		patty_mult *= 0.75
		tip_factor *= 0.6
	var pay: Dictionary = selected_customer.receive_burger(items, patty_mult, combo, tip_factor, fresh_r)
	var payout: int = int(pay.get("total", 0))
	var tip_amt: int = int(pay.get("tip", 0))
	var cook_r := _station_cook_rating(station_index)
	var cook_bit := "  Cook %s" % cook_r["text"]

	if payout > 0:
		money += payout
		total_served += 1
		if game_audio:
			game_audio.play_chaching()
		var was_perfect: bool = bool(pay.get("perfect", false)) and patty_mult >= 1.0 and fresh_r > 0.4
		if was_perfect:
			combo += 1
			perfect_serves += 1
		elif float(result.quality) > 0.85 and fresh_r > 0.4:
			combo += 1
		else:
			combo = 0
		if tip_amt > 0:
			_flash("+$%d  (+$%d tip!)%s%s" % [
				payout, tip_amt,
				"  COMBO x%d" % combo if combo > 1 else "",
				cook_bit
			], cook_r["color"] if int(cook_r["score"]) >= 70 else Color("FFE082"))
		elif was_perfect:
			_flash("+$%d  PERFECT! COMBO x%d%s" % [payout, combo, cook_bit], Color("FFEB3B"))
		else:
			var fresh_note := " (stale)" if fresh_r <= 0.4 else ""
			_flash("+$%d%s%s" % [payout, fresh_note, cook_bit], cook_r["color"])
	else:
		combo = 0
		_flash("Wrong order! Customer is MAD%s" % cook_bit, Color("EF5350"))

	_clear_station(station_index)
	_update_hud()


func _find_station_for_order(order: Array) -> int:
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
	if day_time <= 0.0 and customers.size() > 0:
		hud_day.text = "Day %d  -  CLOSING" % day
	else:
		hud_day.text = "Day %d  -  %ds" % [day, maxi(0, int(ceil(day_time)))]


func _flash(text: String, color: Color) -> void:
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.visible = true
	flash_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(flash_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): flash_label.visible = false)
