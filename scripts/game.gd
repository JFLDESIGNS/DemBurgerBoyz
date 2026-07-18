## 3D food-truck burger game - cook from inside, looking out the window.
extends Node3D

const GRILL_SLOTS := 10
const STATION_COUNT := 1
const STATION_CRAFT := 0
## Build-board burger art scale (1.0 = prior size).
const STATION_BURGER_SCALE := 1.18 ## wider stack so the build reads on the board
## Patties / toppings on the build board — buns stay full size.
const STATION_INGREDIENT_SCALE := 0.48 ## toppings — dialed down vs left-column overshoot
const STATION_PATTY_BUILD_SCALE := 0.744 ## bare meat (10% smaller than 0.827)
const STATION_PATTY_CHEESE_BUILD_SCALE := 0.768 ## melt art (10% smaller than 0.853)
## Mild finished-stack nest — heel tucks under meat; crown stays clear of patty.
const BUILD_BUN_NEST_BOTTOM_PX := 2.0
const BUILD_BUN_NEST_TOP_PX := -6.0 ## negative = lift crown off meat (was +7 glue)
const MAX_HELD := 4
## Grill heat bands screen-left → right: FULL · 1/2 · HOLD
const ZONE_FULL_FRAC := 0.50
const ZONE_HALF_FRAC := 0.263
const ZONE_HOLD_FRAC := 0.237 ## former 1/4 strip — warm hold only (no cook)
const ZONE_FULL_MUL := 1.0
const ZONE_HALF_MUL := 0.5
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
const GRILL_CENTER_X := -0.068 ## keep left edge — grill shortened on the right
const GRILL_WIDTH := 1.786 ## was 2.35; removed separate far-right hold strip
const GRILL_DEPTH := 0.95
## Patty must sit fully on the steel — reject clicks near the rim.
const PATTY_FIT_RADIUS := 0.10
const PATTY_MIN_SEP := 0.19
## Screen + world grab radius — generous so cheese / scoop clicks land reliably.
const PATTY_PICK_WORLD := 0.42
const PATTY_PICK_MIN_PX := 62.0
const PATTY_PICK_WORLD_EDGE := 0.17
const PATTY_PICK_PAD_PX := 22.0
## Cheese hover/drop — very forgiving so drag-to-burger lands easily.
const CHEESE_PICK_WORLD := 0.85
const CHEESE_PICK_MIN_PX := 140.0
const CHEESE_PICK_PAD_PX := 64.0
const CHEESE_PICK_WORLD_EDGE := 0.32
## Near-miss drop snaps onto the closest cheesable burger within this radius.
const CHEESE_SNAP_WORLD := 1.35
const CHEESE_STICKY_PX := 160.0
## Smash: hit the visible meat (screen) or the steel disc under it.
## Tight enough to place beside burgers; loose enough for top-surface clicks.
const PATTY_SMASH_WORLD := 0.125
const PATTY_SMASH_MIN_PX := 24.0
const PATTY_SMASH_PAD_PX := 6.0
const PATTY_SMASH_MAX_PX := 42.0
## Sample heights above patty origin — slight lift for cheese, not the hold ring.
const PATTY_SMASH_Y_LO := 0.02
const PATTY_SMASH_Y_HI := 0.072
const PATTY_SIT_Y := 0.055
## Oil puddles sit above steel (top ~+0.023) but under patties (+0.055).
const OIL_SIT_Y := 0.038
## Too many puddles → warn only (fire needs a sustained pour — see OIL_POUR_FIRE_SEC).
## Only ignites while the burner is ON.
const OIL_FIRE_WARN_COUNT := 40
## Continuous grease pour (LMB held) this long on a lit grill → fire.
const OIL_POUR_FIRE_SEC := 5.0
## Held bottle tip-down height above steel (~was 0.14; +12" so it clears the plate).
const OIL_POUR_HEIGHT := 0.445
## Held shaker tip-down height — +1 ft from prior 0.2 so flakes don't clip the steel.
const SHAKER_POUR_HEIGHT := 0.505
const PattyScript := preload("res://scripts/patty.gd")
const BunToastScript := preload("res://scripts/bun_toast.gd")
const SocialReviewsScript := preload("res://scripts/social_reviews.gd")
const CustomerScript := preload("res://scripts/customer.gd")
## DISABLED — set true later to restore grill-toastable bun pairs (see bun_toast.gd).
const BUN_TOAST_ENABLED := false
## DISABLED — armed hostiles backed up under GREAT IDEA THAT NOBODY LIKES/
const TERRORISTS_ENABLED := false
# const TerroristCustomerScript := preload("res://GREAT IDEA THAT NOBODY LIKES/terrorist_customer.gd")
const WindowCatScript := preload("res://scripts/window_cat.gd")
const GameDataScript := preload("res://scripts/game_data.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")
const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const TruckRadioScript := preload("res://scripts/truck_radio.gd")
const GameAudioScript := preload("res://scripts/game_audio.gd")
## Hotkeys 1-8 match ticket toppings (cheese → mustard). Top bun auto-caps.
## Bottom bar left→right: cheese … mustard, then Serve on the right.
## Bottom bun is automatic when a patty hits a station — not on the strip.
const INGREDIENT_HOTKEYS: Array[String] = [
	"cheese", "tomato", "lettuce", "onion", "pickle", "bacon", "ketchup", "mustard",
]
const HOTKEY_LABELS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8"]
## Operating costs — waste & supplies cut into tips.
const COST_DROP_BURGER := 3.00
const COST_OIL_USE := 0.0 ## Stocked tools are free to use
const COST_SEASON_USE := 0.0
const COST_INGREDIENT := 0.25 ## Phone restock unit baseline (using fridge stock is free)
const COST_BACON := 0.50
const START_MONEY := 200.0
const BACON_PATIENCE_RESTORE := 0.10
const BACON_MOUTH_PICK_PX := 130.0

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

var money: float = 0.0
var combo: int = 0
var day: int = 1
var day_time: float = DAY_LENGTH
var playing: bool = false
## Start tutorial: 1 = turn burner on · 2 = right-click patty · 0 = done.
var _tutorial_step: int = 0
var _tutorial_text: String = ""
var _flash_tween: Tween = null
var difficulty: float = 0.0
var spawn_timer: float = 2.0
var customers: Array = []
## Occasional armed hostile wave — spawns far back with guns.
var terrorist_wave_active: bool = false
const TERRORIST_WAVE_CHANCE := 0.34
const TERRORIST_MIN_DAY := 2
const TERRORIST_KILL_BOUNTY := 12.0
const OPENING_TERR_COUNT := 8
const OPENING_TERR_WINDOW := 20.0
const OPENING_TERR_AT: Array[float] = [0.5, 2.8, 5.2, 7.5, 10.0, 12.5, 15.5, 18.0]
const OPENING_TERR_SPECS: Array[Dictionary] = [
	{"role": "gun", "tier": "distant"},
	{"role": "gun", "tier": "distant"},
	{"role": "gun", "tier": "distant"},
	{"role": "gun", "tier": "far"},
	{"role": "gun", "tier": "far"},
	{"role": "bomber", "tier": "distant"},
	{"role": "bomber", "tier": "far"},
	{"role": "bomber", "tier": "mid"},
]
var _opening_terr_active: bool = false
var _opening_terr_timer: float = 0.0
var _opening_terr_spawned: int = 0
var grill: Array = []
var spatula_patty = null ## LOCAL scoop only (each cook can carry their own in co-op)
var spatula_owner_id: int = 0 ## multiplayer: peer that owns spatula_patty (always local id when set)
var mp_held_net: Dictionary = {} ## peer_id -> patty net_id (who is carrying what)
var drag_owner_id: int = 0 ## multiplayer: who is sliding a grill patty
var stations: Array = [] ## each: {items, patty, panel, preview, title, plate}
var warmer_root: Node3D = null
var warmer_label: Label3D = null
var warmer_label_half: Label3D = null
var warmer_label_hold: Label3D = null
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
var grill_steel_tex: Texture2D = null
## Meters per brushed-steel tile repeat on the flat-top.
const GRILL_STEEL_TILE_M := 1.15 ## Larger tiles so the brushed grain reads on the flat-top.
const GRILL_STEEL_TEX_PATH := "res://assets/grill/stainless_steel.png"
var grill_glow_root: MeshInstance3D = null
const GRILL_GLOW_DELAY_SEC := 0.15
const GRILL_GLOW_FADE_SEC := 4.0
const GRILL_GLOW_BRIGHT_MULT := 1.18
var _grill_glow_tween: Tween = null
var _grill_glow_gen: int = 0
## Little flame triangles under the griddle when the burner is on.
var burner_flame_root: Node3D = null
var burner_flame_tris: Array = [] ## MeshInstance3D
var burner_flame_data: Array = [] ## {phase, spd, amp, lean, base}
var burner_flame_lights: Array = [] ## SpotLight3D strip under the lip
var burner_strip_root: Node3D = null
var burner_strip_cook_w: float = 0.0
var burner_strip_energy: float = 0.18
var heat_warp_mesh: MeshInstance3D = null
var heat_warp_mat: ShaderMaterial = null
var heat_warp_base_size := Vector2(1.0, 0.6)
var heat_warp_enabled: bool = true
var grill_drop_zone: Control = null
var build_column_root: Control = null ## Left 15% parent for Build / DROP_L (not grill)
var build_drop_zone: Control = null ## Tall left catcher while holding a scooped patty
var build_debug_root: Control = null
var build_area_debug_outline: bool = false
var _pending_station_patty_drag = null ## Dictionary while dragging a Build patty
var _pending_cheese_drag: bool = false ## Strip cheese drag → drop on grill burger
var _pending_ingredient_drag: String = "" ## Strip topping drag → Build / cat
var _pending_reorder_drag = null ## Dictionary while dragging a Build stack layer
var _reorder_drag_origin: Vector2 = Vector2.ZERO ## Screen pos when Build layer drag began
const BUILD_SWIPE_TRASH_RIGHT_PX := 56.0 ## Swipe right this far + release off Build → trash
var service_window_closed: bool = false
var service_break_left: float = 0.0
var window_pause_btn: Button = null
var window_shutter: ColorRect = null
var master_vol_row: Control = null
var master_vol_slider: HSlider = null
## Slider 0–1; 1.0 = old ~20% bus level (comfortable game max).
var master_volume_linear: float = 1.0
const MASTER_VOL_MAX := 0.20
const AUDIO_CFG_PATH := "user://audio_settings.cfg"
const AUDIO_MASTER_KEY := "master_ui"
const SERVICE_BREAK_SEC := 28.0
var ingredient_buttons: Dictionary = {} ## id -> Button
var _strip_did_drag: bool = false ## Skip press action after a paint-swipe.
var _strip_swipe_active: bool = false ## LMB paint across topping buttons.
var _strip_swipe_added: Dictionary = {} ## id -> true for this swipe
var _strip_gesture_added: bool = false ## Already applied a topping this LMB gesture.
const STRIP_SWIPE_THRESH_PX := 28.0
var _auto_serving: bool = false
var _serve_fly_busy: bool = false
var _ingredient_fly_busy: bool = false
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
## Parked on the left window lintel, hanging into the opening (toward the cook).
var brush_home: Vector3 = Vector3(1.866, 1.99, 1.12)
var brush_home_rot := Vector3(-8.0, 18.0, 6.0)
## Held pose — blade tipped on steel, handle toward the cook.
var brush_held_rot := Vector3(-96.0, 0.0, 0.0)
var brush_throwing: bool = false
const RESIDUE_SWIPE_DIST := 0.07 ## travel needed to chip a fleck cluster
const RESIDUE_SCRAPE_RATE := 1.35 ## residue cleared per meter of blade travel
const RESIDUE_CHUNK_COUNT := 6 ## Extra flecks on top of the burnt disc.
## Click cheese → ghost → click a grill patty to place.
var cheese_held: bool = false
var cheese_ghost: MeshInstance3D = null
var cheese_ghost_mat: StandardMaterial3D = null
var _cheese_hover_patty = null ## Last burger the cheese ghost snapped to
## Seasoning shaker — clustered with oil + scraper on the left window beam.
var shaker_held: bool = false
var shaker_root: Node3D = null
var shaker_area: Area3D = null
var shaker_particles: GPUParticles3D = null
var shaker_btn: Button = null
var shaker_home: Vector3 = Vector3(1.526, 2.14, 1.12)
var shaker_season_cool: float = 0.0
## Oil bottle — next to scraper/shaker; flip upside-down to draw puddle lines.
var oil_held: bool = false
var oil_root: Node3D = null
var oil_area: Area3D = null
var oil_particles: GPUParticles3D = null
var oil_home: Vector3 = Vector3(1.166, 2.12, 1.12)
var oil_spray_cool: float = 0.0
var oil_last_draw: Vector3 = Vector3.ZERO
var oil_pour_hold_t: float = 0.0 ## Seconds continuously pouring while held.
var oil_slicks: Array = [] ## {mesh, age, life, radius}
var _oil_blob_tex: ImageTexture = null
var _oil_smoke_tex: ImageTexture = null
## Grease fire from over-oiling the flat-top.
var grill_on_fire: bool = false
var fire_health: float = 0.0
## Which heat band the blaze started in (FULL / 1/2 / HOLD) — fire stays there.
var fire_zone_id: String = ""
var fire_root: Node3D = null
var fire_light: OmniLight3D = null
var fire_light_rim: OmniLight3D = null
## Real OmniLight energies (~10% of the old values) — particles carry the look.
const FIRE_LIGHT_CORE := 0.045
const FIRE_LIGHT_RIM := 0.018
const FIRE_LIGHT_CORE_SET := 0.055
const FIRE_LIGHT_RIM_SET := 0.022
var fire_particles: GPUParticles3D = null
var fire_particles_red: GPUParticles3D = null
var fire_embers: GPUParticles3D = null
var fire_smoke: GPUParticles3D = null
var _oil_fire_warned: bool = false
var _fire_flicker_t: float = 0.0
## Fire extinguisher — hang-mounted left of the tools; hold LMB to carry.
var ext_held: bool = false
var ext_root: Node3D = null
var ext_visual: Node3D = null
var ext_area: Area3D = null
var ext_home: Vector3 = Vector3(2.063, 1.72, 0.937)
var ext_home_rot := Vector3(0.0, 200.0, 0.0)
var ext_held_rot := Vector3(-18.0, 200.0, 8.0)
var ext_spraying: bool = false
var ext_powder: GPUParticles3D = null
var ext_powder_blobs: Array = [] ## {mesh, mat, life, max_life, start_scale}
var ext_blob_spawn_cool: float = 0.0
var _fire_killed_by_powder: bool = false ## Flames already snuffed; blobs finishing the job.
const EXT_HOLD_HEIGHT := 0.16 ## Lower hold so the can sits nearer the grill.
const EXT_COLLISION_LAYER := 64
var window_cat: Node3D = null
## Wall Glock — hidden behind the First Sale plaque; LMB hold, RMB shoots.
var glock_held: bool = false
var glock_root: Node3D = null
var glock_visual: Node3D = null
var glock_area: Area3D = null
## Screen-right of First Sale (camera looks +Z → −X is right).
## Hung sideways on the wall (barrel along wall, not aimed at the cook).
var glock_home: Vector3 = Vector3(0.0, 2.38, 1.232) ## Behind First Sale plaque (toward wall)
var glock_home_rot := Vector3(0.0, 270.0, 0.0) ## 90° CCW from facing-cook (180)
var glock_flash: OmniLight3D = null
var glock_muzzle: GPUParticles3D = null
var glock_laser_beam: MeshInstance3D = null
var glock_laser_dot: MeshInstance3D = null
var glock_laser_module: MeshInstance3D = null
var glock_rear_sight_l: MeshInstance3D = null
var glock_rear_sight_r: MeshInstance3D = null
var glock_cooldown: float = 0.0
var glock_recoil: float = 0.0
var glock_aim_roll: float = 0.0 ## Smoothed left/right lean while aiming.
var glock_aim_yaw: float = 0.0
var glock_prev_mouse_x: float = -1.0
const GLOCK_HOLD_HEIGHT := 0.213 ## ~5 inches lower than prior 0.34 for easier aiming.
const GLOCK_HOLD_DIST := 1.24 ## Push grip toward camera along the sight line.
const GLOCK_HOLD_DROP := 0.10 ## Nudge lower while tracking the cursor.
const GLOCK_AIM_REACH := 30.0
const GLOCK_COLLISION_LAYER := 256
const GLOCK_FIRE_COOLDOWN := 0.10
const GLOCK_MESH_SCALE := 1.755 ## ~30% larger on the wall mount.
const GLOCK_MUZZLE_LOCAL := Vector3(0.0, 0.015, 0.12)
## Laser under the rail — nudged up 4" / forward 1" from the old low hang.
const GLOCK_LASER_LOCAL := Vector3(0.0, 0.09, 0.08)
const GLOCK_LASER_MAX := 14.0
## Twin night-sight dots on the rear sight posts (left / right of the notch).
const GLOCK_REAR_SIGHT_Y := 0.048
const GLOCK_REAR_SIGHT_Z := -0.042
const GLOCK_REAR_SIGHT_X := 0.011
const GLOCK_REAR_SIGHT_R := 0.0048
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
## Build-station pickup: hold LMB to carry, release to drop (grill / Build / flick).
var spatula_from_build: bool = false
var spatula_lmb_held: bool = false
const DRAG_MOVE_THRESH_PX := 8.0
const DRAG_POP_DIST := 0.032 ## denser grease pops while sliding
## Screen-left flick (negative X) throws a finished patty to Build.
const FLICK_TO_BUILD_VX := -520.0
## Screen-right flick throws a held patty onto the grill.
const FLICK_TO_GRILL_VX := 520.0
const FLICK_MIN_SPEED := 620.0
const FLICK_MIN_TRAVEL_PX := 36.0
## Build UI + DROP_L live in a left column (not grill hitboxes).
const BUILD_COLUMN_SCREEN_FRAC := 0.185 ## wider left Build column
const BUILD_COLUMN_LEFT_MARGIN := 15.0 ## screen-left pad for Build chrome / 🔔·🗑·All
const BUILD_COLUMN_BOTTOM_CLEAR := 100.0 ## keep clear of ingredient strip (was 118)
## Legacy aliases — drop catcher no longer expands across half the screen.
const BUILD_DROP_SCREEN_FRAC := BUILD_COLUMN_SCREEN_FRAC
const BUILD_DROP_MIN_PX := 160.0
## Flash toast placement — original top + 15% of screen height downward.
const FLASH_LABEL_TOP_FRAC := 236.0 / 720.0 + 0.10
const FLASH_LABEL_HEIGHT_FRAC := 74.0 / 720.0
const FLASH_LABEL_SIDE_FRAC := 280.0 / 1280.0
## Extra screen pixels past the grill's left edge that still count as Build.
const BUILD_DROP_GRILL_PAD_PX := 110.0
## Scooped patty floats under the cursor above the steel.
const SPATULA_HOVER_Y := 0.12
const SPATULA_HOVER_BOB := 0.012

var radio: Node = null
var radio_root: Node3D = null
var radio_ui_anchor: Node3D = null
var radio_status_label: Label = null
var radio_channel_label: Label = null
var radio_power_btn: Button = null
var radio_dial_mesh: MeshInstance3D = null
var radio_light_mat: StandardMaterial3D = null
var radio_column: VBoxContainer = null
var phone_column: Control = null
var hud_chrome_collapsed: bool = false
var hud_chrome_toggle: Button = null
var prep_ui_overlay: TextureRect = null
var phone_ui_anchor: Node3D = null
var phone_rating_stars: Label = null
var phone_rating_value: Label = null
var phone_review_label: Label = null
var phone_feed_box: VBoxContainer = null
var phone_inventory_box: VBoxContainer = null
var phone_scroll: ScrollContainer = null
var _phone_scroll_dragging: bool = false
var _phone_scroll_drag_pending: bool = false
var _phone_scroll_drag_start_y: float = 0.0
var _phone_scroll_drag_start_offset: int = 0
var _phone_scroll_vel: float = 0.0
var _phone_scroll_last_mouse_y: float = 0.0
var _phone_scroll_last_msec: int = 0
## Soda fountain + wall cups (orders later).
var soda_root: Node3D = null
var soda_selected_flavor: String = "cola"
var soda_flavor_areas: Dictionary = {} ## flavor id -> Area3D
var soda_flavor_mats: Dictionary = {} ## flavor id -> StandardMaterial3D
var soda_spout_marker: Marker3D = null
var ice_spout_marker: Marker3D = null
var cup_root: Node3D = null
var cup_area: Area3D = null
var cup_shell_mesh: MeshInstance3D = null
var cup_liquid_mesh: MeshInstance3D = null
var cup_liquid_mat: StandardMaterial3D = null
var cup_liquid_pivot: Node3D = null ## tilts so soda sloshes
var cup_liquid_surface: MeshInstance3D = null ## top disc rides the slosh
var cup_ice_root: Node3D = null ## stacked cubes inside the clear cup
var cup_held: bool = false
var cup_home: Vector3 = Vector3.ZERO
var cup_home_rot: Vector3 = Vector3.ZERO ## upright cup in world space
var cup_flavor: String = ""
var cup_soda_fill: float = 0.0
var cup_ice_fill: float = 0.0
var soda_stream_mesh: MeshInstance3D = null
var soda_stream_mat: StandardMaterial3D = null
var _cup_ice_spawn_cd: float = 0.0
var _cup_prev_pos: Vector3 = Vector3.ZERO
var _cup_vel: Vector3 = Vector3.ZERO
var _cup_slosh: Vector2 = Vector2.ZERO ## x = tilt Z, y = tilt X (degrees)
var _cup_splash_cd: float = 0.0
var social_rating_sum: float = 0.0
var social_review_count: int = 0
## Newest-first feed posts: {stars, who, text, pic?}
var social_reviews: Array = []
const SOCIAL_REVIEW_CHANCE := 0.70
const SOCIAL_FEED_MAX := 10
## Roughly 1 in 8 posts attach a 2D snapshot of the Build burger.
const SOCIAL_REVIEW_PIC_CHANCE := 0.125
const SOCIAL_REVIEWER_NAMES: Array[String] = [
	"Maya", "Chris", "Jordan", "Sam", "Alex", "Riley", "Casey", "Morgan",
	"Taylor", "Jamie", "Quinn", "Avery", "Drew", "Parker", "Reese", "Skyler",
	"Nova", "Kai", "Remy", "Sage", "Frankie", "Harper", "Elliot", "Rowan",
]
var supply_stock: Dictionary = {}
var supply_fresh: Dictionary = {}
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
var _build_zone_cfg: Dictionary = {} ## live build-zone layout (GFX menu + hitboxes)
var options_root: Control = null
var options_panel: PanelContainer = null
var options_menu_open: bool = false
var options_vol_slider: HSlider = null
var options_lobby_btn: Button = null
var options_layer: CanvasLayer = null
var options_dim: ColorRect = null
var street_matte: MeshInstance3D = null
var street_matte_body: StaticBody3D = null
var first_sale_decal: MeshInstance3D = null
var menu_board_decal: MeshInstance3D = null
var prep_ingredients_prop: MeshInstance3D = null
var build_cutting_board: Node3D = null
var burger_pals_decal: MeshInstance3D = null
var wall_paper_decals: Node3D = null
var start_logo: TextureRect = null
var start_logo_wrap: Control = null
var start_logo_tween: Tween = null
## Cached order-slip paper (vignette) textures.
var _ticket_paper_tex: ImageTexture = null
var _ticket_paper_tex_sel: ImageTexture = null
const STREET_MATTE_BASE_SIZE := Vector2(18.2, 9.1)
## Far enough that sidewalk NPCs always sit in front of the paint.
const STREET_MATTE_BASE_Z := 11.5
## Default Y: prior 2.55 minus ~3 ft (0.91 m).
const STREET_MATTE_DEFAULT_Y := 1.64
## Backdrop wall — blocks bodies/ragdolls; bullet rays exclude this layer.
const STREET_MATTE_COLLISION_LAYER := 2048
## First Sale plaque on the lintel above the service window (interior).
## Slide it aside to reveal the wall Glock tucked behind.
const FIRST_SALE_BASE_SIZE := Vector2(1.15, 0.74)
const FIRST_SALE_DEFAULT_X := 0.0
const FIRST_SALE_DEFAULT_Y := 2.391
const FIRST_SALE_DEFAULT_Z := 1.18
const FIRST_SALE_DEFAULT_SCALE := 0.44 ## 20% smaller than prior 0.55
const SALE_COLLISION_LAYER := 512
var sale_held: bool = false
var sale_area: Area3D = null
var sale_home: Vector3 = Vector3(FIRST_SALE_DEFAULT_X, FIRST_SALE_DEFAULT_Y, FIRST_SALE_DEFAULT_Z)
## Menu board on the front wall (camera-right = world −X when looking out the window).
const MENU_BOARD_BASE_SIZE := Vector2(0.72, 0.90)
const MENU_BOARD_DEFAULT_X := -2.91
const MENU_BOARD_DEFAULT_Y := 1.62
const MENU_BOARD_DEFAULT_Z := 1.20
const MENU_BOARD_DEFAULT_SCALE := 1.15
const MENU_BOARD_DEFAULT_YAW := 180.0
## Wire baskets + produce on the counter left of the grill / Build board.
const PREP_INGREDIENTS_TEX_PATH := "res://assets/props/prep_ingredients.png"
const PREP_INGREDIENTS_SIZE := Vector2(1.17, 0.36) ## 50% larger wire-basket art
const PREP_INGREDIENTS_POS := Vector3(0.74, 1.714, 0.46) ## nudged right on counter
const PREP_INGREDIENTS_ROT := Vector3(-74.0, 168.0, 0.0)
const PREP_INGREDIENTS_ALBEDO := Color(0.616, 0.616, 0.616, 1.0) ## 30% darker than prior 0.88 tint
## Build-station cutting board — flat on the counter, left of the grill steel (+X = screen-left).
const CUTTING_BOARD_SIZE := Vector3(0.48, 0.038, 0.44)
const CUTTING_BOARD_GAP := 0.06
const CUTTING_BOARD_Z_OFFSET := -0.22 ## toward the cook (negative Z = back from the window)
const CUTTING_BOARD_WOOD_TINT := Color(0.90, 0.74, 0.48, 1.0)
const CUTTING_BOARD_RIM_TINT := Color(0.30, 0.17, 0.09, 1.0)
const PREP_UI_MODULATE := Color(0.7, 0.7, 0.7, 1.0)
const PREP_UI_SIZE := Vector2(420.0, 252.0)
const PREP_UI_BEHIND_X := -125.0 ## legacy offset when prep lived inside BuildZone
const PREP_UI_BEHIND_Y := -165.0 ## legacy offset when prep lived inside BuildZone
const BUILD_STATIONS_ROW_LEFT := 0.0 ## flush to Build column (column already has 15px screen pad)
const BUILD_STATIONS_ROW_RIGHT := 0.0
const BUILD_PANEL_SIZE := Vector2(210, 320)
const BUILD_ZONE_SIZE := Vector2(210, 280)
const BUILD_UI_LEFT := 0.0 ## bun stack fills the left Build column
const BUILD_PLATE_SHIFT_X := 12.0 ## nudge stack right for left margin
const BUILD_UI_LIFT_BOTTOM := 8.0 ## column already clears the ingredient strip
const PREP_UI_PANEL_X := BUILD_UI_LEFT + PREP_UI_BEHIND_X ## panel-left — independent of build zone
const PREP_UI_PANEL_BOTTOM := BUILD_UI_LIFT_BOTTOM + BUILD_ZONE_SIZE.y - (PREP_UI_BEHIND_Y + PREP_UI_SIZE.y)
const PREP_UI_PANEL_TOP := BUILD_PANEL_SIZE.y - PREP_UI_PANEL_BOTTOM - PREP_UI_SIZE.y
const BUILD_ZONE_PANEL_TOP := BUILD_PANEL_SIZE.y - BUILD_UI_LIFT_BOTTOM - BUILD_ZONE_SIZE.y
const BUILD_HIT_PAD_LEFT := 10.0
const BUILD_HIT_PAD_TOP := 28.0 ## was 180 — only a little above the plate
const BUILD_HIT_PAD_RIGHT := 10.0
const BUILD_HIT_PAD_BOTTOM := 8.0
const BUILD_TITLE_TEXT := "DRAG PATTY HERE"
## Keys in GFX_DEFAULTS / gfx menu — red outlines + prep backdrop.
const BUILD_ZONE_GFX_KEYS: Array[String] = [
	"bz_row_left", "bz_row_right", "bz_row_top", "bz_row_bottom",
	"bz_panel_w", "bz_panel_h", "bz_zone_w", "bz_zone_h",
	"bz_zone_left", "bz_zone_top", "bz_lift_bottom",
	"bz_plate_w", "bz_plate_h", "bz_plate_shift", "bz_plate_y", "bz_plate_pad",
	"bz_title_y", "bz_title_x",
	"bz_hit_l", "bz_hit_t", "bz_hit_r", "bz_hit_b", "bz_hit_shift_x",
	"bz_drop_left", "bz_drop_right", "bz_drop_top", "bz_drop_bottom",
	"bz_grill_pad", "bz_lim_top", "bz_lim_bot",
	"bz_grill_drop_left", "bz_grill_drop_top", "bz_grill_drop_bottom",
]
const PREP_GFX_KEYS: Array[String] = [
	"prep_ui_x", "prep_ui_top", "prep_ui_y", "prep_ui_w", "prep_ui_h", "prep_img_y",
]
const STRIP_GFX_KEYS: Array[String] = [
	"strip_icon_w", "strip_icon_h", "strip_icon_x", "strip_icon_y",
	"strip_bar_left", "strip_bar_top", "strip_bar_right", "strip_bar_bottom",
]
const BUILD_GFX_KEYS: Array[String] = BUILD_ZONE_GFX_KEYS + PREP_GFX_KEYS + STRIP_GFX_KEYS
const BUILD_DEBUG_OUTLINE_COLOR := Color(1.0, 0.1, 0.1, 0.95)
const GRILL_POWER_ROW_BOTTOM := 112.0 ## px above screen bottom — centered on grill
const GRILL_POWER_ROW_WIDTH := 214.0 ## burner + gap + garbage (~20% smaller)
## Kenney / Sketchfab truck radio — replaces procedural CabRadio mesh.
const RADIO_MESH_PATH := "res://models/RADIO/source/RADIO SCETC FAB.obj"
const RADIO_TEX_ALBEDO := "res://models/RADIO/textures/RADIO_SCETC_FAB_albedo.tga.png"
const RADIO_TEX_NORMAL := "res://models/RADIO/textures/RADIO_SCETC_FAB_normal.tga.png"
const RADIO_TEX_METAL := "res://models/RADIO/textures/RADIO_SCETC_FAB_metalness.tga.png"
const RADIO_TEX_AO := "res://models/RADIO/textures/RADIO_SCETC_FAB_ao.tga.png"
const RADIO_HOME_POS := Vector3(-2.84, 2.05, 1.08) ## fallback — usually synced to 2D HUD
const RADIO_HOME_ROT := Vector3(0.0, -90.0, 0.0) ## right wall, facing the cook
const RADIO_WALL_X := -2.84
const RADIO_WORLD_NUDGE := Vector3(0.07, 0.0, 0.0)
const RADIO_UI_ANCHOR := Vector2(0.54, 0.38) ## point on 2D panel the 3D model tracks
const RADIO_TARGET_SIZE := 0.52
const RADIO_UI_PANEL_SIZE := Vector2(200.0, 0.0) ## width locked; height hugs content
const RADIO_UI_TOP := 82.0 ## was 52 — nudged down 30px with phone
const RADIO_UI_RIGHT := 10.0
const RADIO_UI_LEFT := 210.0 ## panel width + right margin
## Android phone HUD — floats under the truck radio.
const PHONE_UI_BASE_H := 278.0
const PHONE_UI_SIZE := Vector2(200.0, PHONE_UI_BASE_H * 1.15 * 1.05 * 1.10 * 1.10) ## +15% +5% +10% +10% taller
const PHONE_LOGO_INNER_W := PHONE_UI_SIZE.x - 28.0 ## fit inside screen + section margins
const PHONE_LOGO_WRAP_H := 86.0 ## ~2× old logo band height (was 52)
const PHONE_LOGO_DISPLAY_H := 80.0
const PHONE_SCROLL_DRAG_THRESH := 8.0
const PHONE_SCROLL_FRICTION := 7.5
const PHONE_SCROLL_MIN_VEL := 18.0
const PHONE_SCROLL_WHEEL_KICK := 520.0
const PHONE_CORNER_OUTER := 10
const PHONE_CORNER_INNER := 6
const PHONE_BELOW_RADIO_GAP := 5.0
## Soda fountain — right counter, nudged in so the face isn't clipped.
## Yaw 180: face on local +Z points at the camera (same as menu board / First Sale).
const SODA_STATION_POS := Vector3(-1.55, 1.08, 0.52)
const SODA_STATION_ROT := Vector3(0.0, 180.0, 0.0)
const CUP_COLLISION_LAYER := 1024
const SODA_FLAVOR_COLLISION_LAYER := 4096
const SODA_FLAVORS: Array[String] = ["cola", "lemon_lime", "orange"]
const SODA_FLAVOR_LABELS: Dictionary = {
	"cola": "COLA",
	"lemon_lime": "LIME",
	"orange": "ORANGE",
}
const SODA_FLAVOR_COLORS: Dictionary = {
	"cola": Color(0.42, 0.14, 0.10),
	"lemon_lime": Color(0.55, 0.82, 0.22),
	"orange": Color(0.95, 0.48, 0.12),
}
const CUP_HOLD_HEIGHT := 0.22
const CUP_FILL_RATE := 0.95 ## fill units per second while under spout
const CUP_SPOUT_REACH := 0.55 ## world meters — forgiving aim under nozzle
const CUP_ICE_CUBE_INTERVAL := 0.11
const CUP_SLOSH_FOLLOW := 14.0
const CUP_SLOSH_RETURN := 5.5
const CUP_SPLASH_SPEED := 2.35 ## world m/s — whip hard enough and soda flies out
const CUP_SPLASH_LOSS := 0.07
const CUP_HOLD_DIST := 1.12 ## meters along camera ray while carrying
const CUP_SPOUT_HORIZ := 0.30 ## horizontal fill radius under a nozzle
const CUP_SPOUT_VERT := 0.38 ## vertical forgiveness under a nozzle
const SUPPLY_IDS: Array[String] = [
	"bun_bottom", "patty", "cheese", "lettuce", "tomato", "onion",
	"pickle", "bacon", "ketchup", "mustard", "bun_top",
]
const SUPPLY_FRESH_MAX := 360.0
const SUPPLY_BUY_PACK := 8
## Burger Pals brand mark — left front wall (camera-left = world +X).
const LOGO_TEX_PATH := "res://assets/decal/burger_pals_logo.png"
const LOGO_BASE_SIZE := Vector2(0.95, 0.95)
const LOGO_DEFAULT_X := 2.88
const LOGO_DEFAULT_Y := 2.05
const LOGO_DEFAULT_Z := 1.20
const LOGO_DEFAULT_SCALE := 0.92
const LOGO_DEFAULT_YAW := 180.0
## Wall art tint — darker so they sit into the truck lighting.
const DECAL_ALBEDO := Color(0.34, 0.34, 0.34, 1.0)
## License / health / photo cluster — 20% darker than prior 0.35 tint.
const WALL_PAPER_ALBEDO := Color(0.28, 0.28, 0.28, 1.0)
const WALL_PAPER_Z := FIRST_SALE_DEFAULT_Z
const GFX_CFG_PATH := "user://gfx_settings.cfg"
const GFX_DEFAULTS := {
	"bloom": 0.18,
	"glow_intensity": 0.63,
	"glow_strength": 1.07,
	"glow_threshold": 0.28,
	"glow_on": true,
	"exposure": 0.89,
	"ambient": 0.33,
	"sun": 1.53,
	"kitchen": 2.90,
	"grill_lamp": 1.66,
	"window_wash": 0.97,
	"saturation": 1.03,
	"contrast": 1.05,
	"ssao": false,
	"ssil": false,
	"sky_energy": 0.34,
	"heat_warp_on": false,
	"heat_warp_size": 0.83,
	"heat_warp_speed": 1.00,
	"heat_warp_strength": 0.00,
	"heat_warp_tight": 1.70,
	"bg_y": STREET_MATTE_DEFAULT_Y,
	"bg_scale": 1.0,
	"sale_x": FIRST_SALE_DEFAULT_X,
	"sale_y": FIRST_SALE_DEFAULT_Y,
	"sale_z": FIRST_SALE_DEFAULT_Z,
	"sale_scale": FIRST_SALE_DEFAULT_SCALE,
	"menu_x": MENU_BOARD_DEFAULT_X,
	"menu_y": MENU_BOARD_DEFAULT_Y,
	"menu_z": MENU_BOARD_DEFAULT_Z,
	"menu_scale": MENU_BOARD_DEFAULT_SCALE,
	"menu_yaw": MENU_BOARD_DEFAULT_YAW,
	## Orange strip under the grill lip (burner on only).
	"strip_x": 0.0,
	"strip_y": -0.008,
	"strip_z": 0.06,
	"strip_pitch": 58.0,
	"strip_yaw": 180.0,
	"strip_roll": 0.0,
	"strip_energy": 0.18,
	"strip_range": 1.45,
	"strip_angle": 76.0,
	"strip_size": 0.55,
	"strip_width": 0.99,
	## Build zone hitboxes — tune in GFX → BUILD ZONES (red outlines update live).
	"bz_row_left": BUILD_STATIONS_ROW_LEFT,
	"bz_row_right": BUILD_STATIONS_ROW_RIGHT,
	"bz_row_top": 0.0,
	"bz_row_bottom": 0.0,
	"bz_panel_w": BUILD_PANEL_SIZE.x,
	"bz_panel_h": BUILD_PANEL_SIZE.y,
	"bz_zone_w": BUILD_ZONE_SIZE.x,
	"bz_zone_h": BUILD_ZONE_SIZE.y,
	"bz_zone_left": 0.0,
	"bz_zone_top": 8.0,
	"bz_lift_bottom": BUILD_UI_LIFT_BOTTOM,
	"bz_plate_w": 0.0, ## 0 = stretch to full Build column / panel width
	"bz_plate_h": 230.0,
	"bz_plate_shift": BUILD_PLATE_SHIFT_X,
	"bz_plate_y": 40.0, ## sit lower on the cutting board
	"bz_plate_pad": 8.0,
	"bz_title_y": -2.0,
	"bz_title_x": 0.0,
	"bz_hit_l": BUILD_HIT_PAD_LEFT,
	"bz_hit_t": BUILD_HIT_PAD_TOP,
	"bz_hit_r": BUILD_HIT_PAD_RIGHT,
	"bz_hit_b": BUILD_HIT_PAD_BOTTOM,
	"bz_hit_shift_x": 0.0,
	"bz_drop_left": 0.0,
	"bz_drop_right": 0.0,
	"bz_drop_top": 0.0,
	"bz_drop_bottom": 0.0,
	"bz_grill_pad": BUILD_DROP_GRILL_PAD_PX,
	"bz_lim_top": 280.0,
	"bz_lim_bot": 120.0,
	"bz_grill_drop_left": 140.0,
	"bz_grill_drop_top": 48.0,
	"bz_grill_drop_bottom": -110.0,
	"prep_ui_x": 34.0,
	"prep_ui_top": 343.0,
	"prep_ui_y": 153.0,
	"prep_ui_w": 321.6,
	"prep_ui_h": 215.2,
	"prep_img_y": -71.0,
	"strip_icon_w": 64.0,
	"strip_icon_h": 44.0,
	"strip_icon_x": 0.0,
	"strip_icon_y": 0.0,
	"strip_bar_left": 8.0,
	"strip_bar_top": -100.0,
	"strip_bar_right": -8.0,
	"strip_bar_bottom": -6.0,
	"bz_debug_outline": false,
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

## --- Multiplayer co-op -------------------------------------------------------
var mp_enabled: bool = false
var _mp_applying: bool = false ## true while applying a remote/local RPC action
var _mp_cursor_accum: float = 0.0
var _mp_drag_accum: float = 0.0
var _mp_lobby_root: Control = null
var _mp_room_list: VBoxContainer = null
var _mp_status_label: Label = null
var _mp_name_edit: LineEdit = null
var _mp_relay_edit: LineEdit = null
var _mp_host_btn: Button = null
var _mp_ready_btn: Button = null
var _mp_start_coop_btn: Button = null
var _mp_back_btn: Button = null
var _mp_join_local_btn: Button = null
var _mp_refresh_btn: Button = null
var _mp_code_edit: LineEdit = null
var _mp_code_join_btn: Button = null
var _mp_host_addr_label: Label = null
var _mp_remote_cursors: Dictionary = {} ## peer_id -> Control
var _mp_cursor_layer: Control = null
var _mp_next_customer_net_id: int = 1
var _mp_customer_net_ids: Dictionary = {} ## customer instance_id -> net_id
var _mp_cat_accum: float = 0.0
var _mp_econ_accum: float = 0.0
var _mp_cust_accum: float = 0.0
var _mp_grill_accum: float = 0.0
var _mp_oil_sync_cool: float = 0.0
var _mp_residue_sync_cool: float = 0.0
var _mp_ext_sync_cool: float = 0.0
var _mp_season_sync_cool: float = 0.0
var _mp_tool_pose_cool: float = 0.0
var _serve_fly_watch: float = 0.0
## peer_id -> ghost Node3D so partners see held tools in-hand
var _mp_remote_oil: Dictionary = {}
var _mp_remote_shaker: Dictionary = {}
var _mp_remote_ext: Dictionary = {}
var _mp_remote_glock: Dictionary = {}
## True while a co-op serve is in flight (fly tween) so peers share one outcome.
var _mp_serve_sync: bool = false
var multiplayer_btn: Button = null


func _ready() -> void:
	randomize()
	## Always boot fullscreen — no windowed chrome / minimize-on-launch.
	## Multiplayer lobby switches to windowed so two instances can share a PC.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	## Soft edges on 3D characters / steel; FXAA helps Label3D + UI text a bit too.
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_setup_glove_cursor()
	UiFontsScript.ensure_loaded()
	var ui_root: Control = get_node("UI/Root")
	ui_root.theme = UiFontsScript.make_theme()
	_style_static_labels()
	if vp:
		vp.size_changed.connect(_layout_flash_label)
		call_deferred("_layout_flash_label")
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
	_build_prep_ui_overlay()
	_build_grill_drop_zone()
	_build_build_drop_zone()
	_build_window_pause_ui()
	_build_ingredient_legend()
	_build_ingredient_buttons()
	_setup_radio()
	if vp:
		vp.size_changed.connect(_layout_phone_ui_overlay)
		vp.size_changed.connect(_apply_prep_ui_overlay_layout)
		vp.size_changed.connect(_layout_build_column_root)
		vp.size_changed.connect(_refresh_build_debug_outlines)
	call_deferred("_layout_phone_ui_overlay")
	_build_pause_button()
	_build_master_volume_ui()
	_build_graphics_ui()
	_build_options_menu()
	_layout_top_bar_hud()
	_setup_game_audio()
	_build_dialogue_ui()
	## Hint sits under order tickets; flash stays on top.
	## Empty rail must IGNORE — it covers the hanging tools (oil/scraper/season).
	var ticket_rail: Control = get_node_or_null("UI/Root/WindowTicketRail")
	if ticket_rail:
		ticket_rail.z_index = 5
		ticket_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ticket_box:
		ticket_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	stations_row.z_index = 10
	ingredient_legend.mouse_filter = Control.MOUSE_FILTER_STOP
	ingredient_legend.z_index = 30 ## above GrillDropZone while holding cheese
	start_btn.pressed.connect(func():
		_sfx_click()
		_start_game()
	)
	restart_btn.pressed.connect(func():
		_sfx_click()
		if mp_enabled and not _mp_applying:
			mp_restart_day.rpc()
			return
		_restart()
	)
	_setup_multiplayer_ui()
	game_over_panel.visible = false
	flash_label.visible = false
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()


func _setup_glove_cursor() -> void:
	## Cartoon glove pointer — replaces the OS arrow everywhere.
	var tex: Texture2D = load("res://assets/ui/cursor_glove.png") as Texture2D
	if tex == null:
		return
	## Hotspot at the pointing fingertip (upper-left of the glove art).
	var tip := Vector2(0, 3)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, tip)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, tip)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_MOVE, tip)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_DRAG, tip)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_CAN_DROP, tip)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_FORBIDDEN, tip)


func _style_static_labels() -> void:
	UiFontsScript.apply_label(hud_money, true, 30)
	UiFontsScript.apply_label(hud_combo, true, 11)
	UiFontsScript.apply_label(hud_day, true, 11)
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
		## Toon caption plate — semi-transparent black so text pops over the window BG.
		var flash_plate := StyleBoxFlat.new()
		flash_plate.bg_color = Color(0.04, 0.05, 0.07, 0.32)
		flash_plate.set_corner_radius_all(16)
		flash_plate.content_margin_left = 28
		flash_plate.content_margin_right = 28
		flash_plate.content_margin_top = 14
		flash_plate.content_margin_bottom = 14
		flash_plate.border_color = Color(0.18, 0.2, 0.24, 0.35)
		flash_plate.set_border_width_all(2)
		flash_plate.shadow_color = Color(0, 0, 0, 0.12)
		flash_plate.shadow_size = 4
		flash_plate.shadow_offset = Vector2(0, 2)
		flash_label.add_theme_stylebox_override("normal", flash_plate)
		flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layout_flash_label()
	UiFontsScript.apply_button(start_btn, true, 22)
	UiFontsScript.apply_button(restart_btn, true, 18)
	_setup_start_logo()
	var blurb := get_node_or_null("UI/Root/StartOverlay/StartCenter/Blurb") as Label
	if blurb:
		UiFontsScript.apply_label(blurb, false, 16)
	UiFontsScript.apply_label(game_over_label, true, 22)


func _layout_flash_label() -> void:
	if flash_label == null:
		return
	var vr := get_viewport().get_visible_rect()
	var vw := vr.size.x
	var vh := vr.size.y
	var top := vh * FLASH_LABEL_TOP_FRAC
	var height := maxf(64.0, vh * FLASH_LABEL_HEIGHT_FRAC)
	var side := vw * FLASH_LABEL_SIDE_FRAC
	flash_label.offset_left = side
	flash_label.offset_top = top
	flash_label.offset_right = vw - side
	flash_label.offset_bottom = top + height


func _setup_start_logo() -> void:
	## Swap the text title for the Burger Pals brand mark on the open screen.
	var center := get_node_or_null("UI/Root/StartOverlay/StartCenter") as VBoxContainer
	if center == null:
		return
	var title := center.get_node_or_null("Title") as Label
	if title:
		title.visible = false
	if start_logo != null and is_instance_valid(start_logo):
		_stop_logo_hover()
		start_logo.position.y = 8.0
		return
	if not ResourceLoader.exists(LOGO_TEX_PATH):
		if title:
			title.visible = true
		return
	var tex := load(LOGO_TEX_PATH) as Texture2D
	if tex == null:
		if title:
			title.visible = true
		return
	## Extra vertical room so layout stays stable (no bob).
	start_logo_wrap = Control.new()
	start_logo_wrap.name = "BurgerPalsLogoWrap"
	start_logo_wrap.custom_minimum_size = Vector2(220, 236)
	start_logo_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(start_logo_wrap)
	center.move_child(start_logo_wrap, 0)

	start_logo = TextureRect.new()
	start_logo.name = "BurgerPalsLogo"
	start_logo.texture = tex
	start_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	start_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	start_logo.custom_minimum_size = Vector2(220, 220)
	start_logo.size = Vector2(220, 220)
	start_logo.position = Vector2(0, 8)
	start_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_logo_wrap.add_child(start_logo)
	## Tall enough for logo + blurb + Solo + Multiplayer.
	center.offset_top = -300.0
	center.offset_bottom = 300.0
	center.offset_left = -380.0
	center.offset_right = 380.0
	_stop_logo_hover()


func _start_logo_hover() -> void:
	## Hover disabled — keep logo still on the home screen.
	_stop_logo_hover()
	if start_logo != null and is_instance_valid(start_logo):
		start_logo.position.y = 8.0


func _stop_logo_hover() -> void:
	if start_logo_tween != null and is_instance_valid(start_logo_tween):
		start_logo_tween.kill()
		start_logo_tween = null


func _setup_stations_data() -> void:
	stations.clear()
	for i in STATION_COUNT:
		stations.append({
			"kind": "craft",
			"items": [] as Array[String],
			"patties": [],
			"bun_toast": {}, ## bun_bottom / bun_top -> cook_time seconds
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
	## UI warmer removed — HOLD is the rightmost grill band.
	return false


func _station_label(_index: int) -> String:
	return "Build"


func _start_game() -> void:
	_stop_logo_hover()
	start_overlay.visible = false
	playing = true
	money = START_MONEY
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
	_reset_fire_extinguisher()
	_reset_glock()
	if window_cat != null and window_cat.has_method("reset_shift"):
		window_cat.reset_shift()
	_clear_all_stations()
	_seed_cutting_board_buns()
	_clear_customers()
	_reset_service_window_open()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_begin_start_tutorial()
	_reset_supplies()
	_start_radio_fade_in()
	# _begin_opening_terror_ambush()


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
	_reset_fire_extinguisher()
	_reset_glock()
	if window_cat != null and window_cat.has_method("reset_shift"):
		window_cat.reset_shift()
	_clear_all_stations()
	_seed_cutting_board_buns()
	_clear_customers()
	_reset_service_window_open()
	for i in GRILL_SLOTS:
		_set_grill_power(i, false)
	_update_hud()
	_refresh_spatula_ui()
	_refresh_all_stations()
	_begin_start_tutorial()
	_reset_supplies()
	_start_radio_fade_in()
	_flash("Day %d - it gets busier!" % day, Color("FFEB3B"))
	# _begin_opening_terror_ambush()


func _process(delta: float) -> void:
	_mp_update_cursors(delta)
	_update_phone_scroll_inertia(delta)
	if not playing:
		if game_audio:
			game_audio.set_sizzle_active(false)
		return
	## Options freezes the shift clock / cook sim until Resume / Esc.
	if options_menu_open:
		if game_audio:
			game_audio.set_sizzle_active(false)
		return
	## Sync grill heat to patties / toasting buns (only cook while burner is on + on cook zone).
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p != null and is_instance_valid(p):
			p.heating = grill_on
			p.heat_mul = _warmer_heat_mul(p.position) * _oil_heat_mul(p.position)
			if not _is_bun_toast(p):
				_update_patty_warm_hold(p, delta)
			elif BUN_TOAST_ENABLED:
				_update_bun_toast_hold(p, delta)
	_update_station_cheese_melt(delta)
	_update_supply_freshness(delta)
	_update_patty_hint_focus()
	_update_kitchen_sizzle()
	_update_heat_warp(delta)
	_update_burner_flames(delta)
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
	if cup_held:
		_update_held_cup(delta)
	if ext_held:
		_update_held_fire_ext(delta)
	if glock_held:
		_update_held_glock(delta)
	if sale_held:
		_update_held_sale(delta)
	if glock_cooldown > 0.0:
		glock_cooldown = maxf(0.0, glock_cooldown - delta)
	if glock_recoil > 0.0:
		glock_recoil = maxf(0.0, glock_recoil - delta * 8.0)
	if window_cat != null and is_instance_valid(window_cat) and window_cat.has_method("set_customer_gap"):
		## Peek with an empty window or a single customer (cat sits screen-left).
		window_cat.set_customer_gap(customers.size() <= 1)
	_update_oil_slicks(delta)
	_update_grill_fire(delta)
	_update_ext_powder_blobs(delta)
	if brush_held and not brush_throwing:
		_update_held_brush(delta)
	## Viewport has no gui_drag_ended signal in 4.x — poll instead.
	var gui_dragging := get_viewport().gui_is_dragging()
	if _was_gui_dragging and not gui_dragging:
		_on_gui_drag_ended(get_viewport().gui_is_drag_successful())
	_was_gui_dragging = gui_dragging

	## Recover stuck input blockers (cheese drop arm / serve fly / build catcher).
	if not cheese_held and grill_drop_zone != null and is_instance_valid(grill_drop_zone) \
			and grill_drop_zone.mouse_filter == Control.MOUSE_FILTER_STOP:
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spatula_patty == null and build_drop_zone != null and is_instance_valid(build_drop_zone) \
			and build_drop_zone.mouse_filter == Control.MOUSE_FILTER_STOP:
		_arm_build_drop_zone(false)
	if _serve_fly_busy:
		_serve_fly_watch += delta
		if _serve_fly_watch > 6.5:
			_serve_fly_busy = false
			_serve_fly_watch = 0.0
			_auto_serving = false
			_mp_serve_sync = false
	else:
		_serve_fly_watch = 0.0

	## Shared shift clock — host owns it in co-op (synced via economy packets).
	if not mp_enabled or NetManager.is_host():
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
		# _update_opening_terror_ambush(delta)
		## In co-op, only the host spawns customers (then replicates).
		if not mp_enabled or NetManager.is_host():
			spawn_timer -= delta
			var cap := _customer_cap()
			var waiting_n := _waiting_customer_count()
			if not shift_closing and spawn_timer <= 0.0 and waiting_n < cap:
				# if TERRORISTS_ENABLED and not terrorist_wave_active and day >= TERRORIST_MIN_DAY and randf() < TERRORIST_WAVE_CHANCE:
				# 	_spawn_terrorist_wave()
				# 	spawn_timer = _next_spawn_delay()
				_spawn_customer()
				spawn_timer = _next_spawn_delay()

	rush_mode = _waiting_customer_count() >= maxi(2, _customer_cap() - 1) and day >= 2

	if shift_closing and customers.is_empty() and not service_window_closed:
		if mp_enabled:
			if NetManager.is_host():
				mp_end_day.rpc()
		else:
			_end_day()
	_update_station_freshness(delta)
	_update_hud()
	if mp_enabled and dragging_patty != null and is_instance_valid(dragging_patty):
		_mp_drag_accum += delta
		if _mp_drag_accum >= 0.05:
			_mp_drag_accum = 0.0
			_mp_send_patty_pose(dragging_patty)
	if mp_enabled and spatula_patty != null and is_instance_valid(spatula_patty):
		if spatula_owner_id == 0 or spatula_owner_id == NetManager.my_id():
			_mp_send_patty_pose(spatula_patty, true)
	if mp_enabled and NetManager.is_host() and window_cat != null and is_instance_valid(window_cat):
		_mp_cat_accum += delta
		if _mp_cat_accum >= 0.1:
			_mp_cat_accum = 0.0
			_mp_send_cat_sync()
	if mp_enabled:
		_mp_oil_sync_cool = maxf(0.0, _mp_oil_sync_cool - delta)
		_mp_residue_sync_cool = maxf(0.0, _mp_residue_sync_cool - delta)
		_mp_ext_sync_cool = maxf(0.0, _mp_ext_sync_cool - delta)
		_mp_season_sync_cool = maxf(0.0, _mp_season_sync_cool - delta)
		_mp_tool_pose_cool = maxf(0.0, _mp_tool_pose_cool - delta)
		if oil_held or shaker_held or ext_held or glock_held:
			_mp_send_held_tool_pose(false)
	if mp_enabled and NetManager.is_host():
		_mp_econ_accum += delta
		if _mp_econ_accum >= 0.45:
			_mp_econ_accum = 0.0
			_mp_broadcast_economy()
		_mp_cust_accum += delta
		if _mp_cust_accum >= 0.2:
			_mp_cust_accum = 0.0
			_mp_broadcast_customers()
		_mp_grill_accum += delta
		if _mp_grill_accum >= 0.28:
			_mp_grill_accum = 0.0
			_mp_broadcast_grill()
			## Build board absolute repair every cook tick too.
			for si in STATION_COUNT:
				_mp_broadcast_station(si)


func _update_station_freshness(delta: float) -> void:
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		if not st.get("fresh_active", false):
			_refresh_freshness_label(i)
			continue
		if st["items"].is_empty():
			_reset_station_freshness(i)
			continue
		## Co-op guests take absolute freshness from host snapshots — don't local-tick.
		if mp_enabled and not NetManager.is_host():
			_refresh_freshness_label(i)
			continue
		st["freshness"] = maxf(0.0, float(st["freshness"]) - delta)
		_refresh_freshness_label(i)
		if float(st["freshness"]) <= 0.0 and not st.get("spoiled", false):
			st["spoiled"] = true
			if mp_enabled:
				mp_clear_station.rpc(i)
			else:
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
		1: return 19.0
		2: return 13.0
		3: return 10.0
		_: return 8.0


func _customer_cap() -> int:
	## Day 1: one at a time. Day 2+: a growing line (up to 4 lanes).
	match day:
		1:
			return 1
		2:
			return 2
		3:
			return 3
		_:
			return MAX_CUSTOMERS


func _waiting_customer_count() -> int:
	var n := 0
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get("is_leaving")):
			continue
		n += 1
	return n


func _next_spawn_delay() -> float:
	var day_progress := 1.0 - clampf(day_time / DAY_LENGTH, 0.0, 1.0)
	match day:
		1: return lerpf(26.0, 14.0, day_progress) + randf_range(0.0, 5.0)
		2: return lerpf(12.0, 6.5, day_progress) + randf_range(0.0, 2.5)
		3: return lerpf(9.0, 4.5, day_progress) + randf_range(0.0, 2.0)
		_: return lerpf(6.5, 3.0, minf(1.0, day_progress + (day - 4) * 0.1)) + randf_range(0.0, 1.5)


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
	if options_menu_open:
		return
	if not playing:
		return
	if event.is_action_pressed("toggle_burner"):
		_toggle_grill_power(0)
		return
	elif event.is_action_pressed("serve") or _is_enter_pressed(event):
		_on_serve()
	elif event.is_action_pressed("trash"):
		_clear_active_station()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE):
		## Backspace = trash selected / top Build layer (same as trash key).
		_clear_active_station()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var ing := _ingredient_from_hotkey(event.keycode)
		if ing != "":
			_add_ingredient(ing)
			return
	elif event is InputEventMouseButton and event.pressed:
		var grill_place: bool = event.button_index == MOUSE_BUTTON_RIGHT
		if not cheese_held and _ui_blocks_world_click(event.position, grill_place):
			return
		if brush_held or oil_held or shaker_held or ext_held or glock_held or sale_held or cup_held or dragging_patty != null:
			return
		if cheese_held:
			if _is_ingredient_strip_click(event.global_position):
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				## Also handled in _input so UI can't eat the cancel click.
				_cancel_cheese_hold()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				if _try_window_cat_click(event.global_position):
					get_viewport().set_input_as_handled()
					return
				_try_place_held_cheese(event.global_position)
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _try_window_cat_click(event.position):
				return
			if spatula_patty != null:
				## Our scoop only — partner carries separately in co-op.
				if spatula_lmb_held and spatula_from_build:
					return
				_handle_spatula_click(event.position)
				return
			if mp_enabled and _try_steal_held_patty_at(event.position):
				get_viewport().set_input_as_handled()
				return
			if _try_warmer_click(event.position):
				return
			## Left click: flip / scoop / start drag — never spawn a patty.
			_try_grill_raycast(event.position, false)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			## Squish burger under cursor; empty steel places a new patty.
			var smash_target = _pick_patty_for_smash(event.position)
			if smash_target != null:
				_smash_grill_patty(smash_target)
				get_viewport().set_input_as_handled()
			else:
				_try_grill_raycast(event.position, true)



func _input(event: InputEvent) -> void:
	if not playing:
		return
	## Options owns the mouse — never let kitchen grabs see clicks while it's open.
	if options_menu_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_F10:
				if gfx_panel != null and gfx_panel.visible:
					_set_graphics_menu_open(false)
				else:
					_set_options_menu_open(false)
				get_viewport().set_input_as_handled()
			return
		## Leave mouse/keys alone so CanvasLayer Options buttons receive them.
		return
	## Paint toppings by dragging across the bottom strip (great for EVERYTHING).
	if _handle_strip_swipe_input(event):
		return
	## Cheese pick-up / placement — run before UI, but never steal the topping strip.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if cheese_held:
			if _is_ingredient_strip_click(event.global_position):
				return
			if _try_window_cat_click(event.global_position):
				get_viewport().set_input_as_handled()
				return
			_try_place_held_cheese(event.global_position)
			get_viewport().set_input_as_handled()
			return
	## Right-click while holding extinguisher → spray white powder (hold to keep spraying).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if cheese_held:
				_cancel_cheese_hold()
				get_viewport().set_input_as_handled()
				return
			if ext_held:
				ext_spraying = true
				if game_audio and game_audio.has_method("set_ext_spray"):
					game_audio.set_ext_spray(true)
				if mp_enabled:
					var aim0 := _grill_plane_from_screen(event.position)
					mp_ext_spray.rpc(true, aim0.x, aim0.z, false)
				get_viewport().set_input_as_handled()
				return
			if glock_held:
				_fire_glock()
				get_viewport().set_input_as_handled()
				return
			if playing and _try_grill_right_click(event.position):
				get_viewport().set_input_as_handled()
				return
		else:
			if ext_spraying:
				ext_spraying = false
				if ext_powder:
					ext_powder.emitting = false
				if game_audio and game_audio.has_method("set_ext_spray"):
					game_audio.set_ext_spray(false)
				if mp_enabled:
					mp_ext_spray.rpc(false, 0.0, 0.0, false)
				get_viewport().set_input_as_handled()
				return
	## Sliding a patty / oil / shaker: release ends hold and returns tools home.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if spatula_patty != null and spatula_lmb_held:
			spatula_lmb_held = false
			_handle_spatula_release(event.position)
			get_viewport().set_input_as_handled()
			return
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
		if ext_held:
			_release_fire_extinguisher()
			get_viewport().set_input_as_handled()
			return
		if glock_held:
			_release_glock()
			get_viewport().set_input_as_handled()
			return
		if sale_held:
			_release_sale_plaque()
			get_viewport().set_input_as_handled()
			return
		if cup_held:
			_put_cup_down()
			get_viewport().set_input_as_handled()
			return
	## Wire brush / oil / shaker / extinguisher: hold LMB to use — never steal clicks from UI buttons.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _ui_blocks_world_click(event.position):
				return
			if cheese_held:
				## Place handled in unhandled — don't grab tools mid-hold.
				return
			if cup_held:
				## Still holding LMB from the grab — flavor pick while carrying.
				if _try_soda_flavor_click(event.position):
					get_viewport().set_input_as_handled()
				return
			if brush_held or oil_held or shaker_held or ext_held or glock_held or sale_held or dragging_patty != null:
				get_viewport().set_input_as_handled()
				return
			if _try_soda_flavor_click(event.position):
				get_viewport().set_input_as_handled()
				return
			if _try_grab_nearest_tool(event.position):
				get_viewport().set_input_as_handled()
				return
	## Escape / F10 → Options (or cancel held tools first).
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_toggle_options_menu()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if cup_held:
			_put_cup_down()
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
		if ext_held:
			_release_fire_extinguisher()
			get_viewport().set_input_as_handled()
			return
		if glock_held:
			_release_glock()
			get_viewport().set_input_as_handled()
			return
		if oil_held:
			_reset_oil_bottle()
			get_viewport().set_input_as_handled()
			return
		if brush_held:
			_throw_brush_home()
			get_viewport().set_input_as_handled()
			return
		if playing:
			if _mp_lobby_root != null and _mp_lobby_root.visible:
				return
			_toggle_options_menu()
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
	## Skip while still holding LMB from a Build pickup — release handles the drop.
	if spatula_patty == null:
		return
	if spatula_lmb_held and spatula_from_build:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _handle_spatula_click(event.position):
			get_viewport().set_input_as_handled()


func _is_enter_pressed(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _handle_strip_swipe_input(event: InputEvent) -> bool:
	## Drag across topping buttons to stack them in order — one pass for EVERYTHING.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id := _strip_ingredient_at(event.position)
			if id == "":
				_strip_swipe_active = false
				return false
			## Fresh press — never inherit a stale skip flag from a prior drag.
			_strip_did_drag = false
			_strip_gesture_added = false
			_strip_swipe_active = true
			_strip_swipe_added.clear()
			_strip_swipe_added["_start"] = event.position
			_strip_swipe_added["_start_id"] = id
			_strip_swipe_added["_moved"] = false
			return false
		## Release ends a paint swipe.
		if _strip_swipe_active:
			var moved: bool = bool(_strip_swipe_added.get("_moved", false))
			_strip_swipe_active = false
			if moved:
				_strip_did_drag = true
			_strip_swipe_added.clear()
		return false
	if event is InputEventMouseMotion and _strip_swipe_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var start_pos: Vector2 = _strip_swipe_added.get("_start", event.position)
		if not bool(_strip_swipe_added.get("_moved", false)):
			if start_pos.distance_to(event.position) >= STRIP_SWIPE_THRESH_PX:
				_strip_swipe_added["_moved"] = true
				_strip_did_drag = true
				var start_id: String = str(_strip_swipe_added.get("_start_id", ""))
				if start_id != "":
					_strip_swipe_add(start_id)
		if bool(_strip_swipe_added.get("_moved", false)):
			var id2 := _strip_ingredient_at(event.position)
			if id2 != "":
				_strip_swipe_add(id2)
		return true
	return false


func _strip_ingredient_at(screen_pos: Vector2) -> String:
	for id in ingredient_buttons:
		var btn: Control = ingredient_buttons[id]
		if btn != null and is_instance_valid(btn) and btn.get_global_rect().has_point(screen_pos):
			return str(id)
	return ""


func _is_ingredient_strip_click(screen_pos: Vector2) -> bool:
	if _strip_ingredient_at(screen_pos) != "":
		return true
	if ingredient_legend != null and is_instance_valid(ingredient_legend) \
			and ingredient_legend.get_global_rect().has_point(screen_pos):
		return true
	return false


func _cheese_targets_build_at(screen_pos: Vector2) -> bool:
	## Overlapping build + grill hits prefer the patty on the steel.
	if _cheese_prefers_grill_at(screen_pos):
		return false
	return _build_plate_index_at(screen_pos) >= 0


func _cheese_prefers_grill_at(screen_pos: Vector2) -> bool:
	return _is_grill_screen_point(screen_pos)


func _strip_swipe_add(id: String) -> void:
	if id == "" or _strip_swipe_added.has(id):
		return
	_strip_swipe_added[id] = true
	if active_station < 0 or active_station >= STATION_COUNT:
		return
	var items: Array = stations[active_station]["items"]
	## Skip if already on the burger (one of each topping per swipe pass).
	if id != "bun_top" and items.has(id):
		return
	if id == "bun_top" and items.has("bun_top"):
		return
	_pulse_ingredient_feedback(id)
	## Swipe cheese goes straight onto Build (no ghost hold interrupting the drag).
	if id == "cheese":
		_add_ingredient_to_station(active_station, id, false)
		_strip_gesture_added = true
		return
	var station := active_station
	_play_ingredient_fly_to_build(id, station, func():
		_add_ingredient_to_station(station, id, false)
	)
	_strip_gesture_added = true


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
	return ""


func _is_grill_screen_point(screen_pos: Vector2) -> bool:
	var hit := _grill_plane_from_screen(screen_pos)
	if hit == Vector3.ZERO:
		return false
	return _is_on_grill_surface(hit)


func _try_grill_right_click(screen_pos: Vector2) -> bool:
	## Runs in _input (before UI) so Build chrome never eats grill right-clicks.
	if brush_held or oil_held or shaker_held or ext_held or glock_held or sale_held:
		return false
	if spatula_patty != null or dragging_patty != null or cheese_held:
		return false
	if not _is_grill_screen_point(screen_pos):
		return false
	if _ui_blocks_world_click(screen_pos, true):
		return false
	var smash_target = _pick_patty_for_smash(screen_pos)
	if smash_target != null:
		_smash_grill_patty(smash_target)
	else:
		_try_grill_raycast(screen_pos, true)
	return true


func _ui_blocks_world_click(screen_pos: Vector2, for_grill_place: bool = false) -> bool:
	## Buttons / panels on top of the 3D tools — never grab scraper through UI.
	if for_grill_place and _is_grill_screen_point(screen_pos):
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null:
		if node is Control:
			var c := node as Control
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				## Full-screen empty roots pass through; interactive chrome does not.
				var n := String(c.name)
				if n == "Root" or n == "BottomUI" or n == "StationsRow" or n == "GrillDropZone" \
						or n == "WindowTicketRail" or n == "TicketBox" or n == "PrepUiOverlay" \
						or n == "BuildTitle" or n == "GrillPickBlocker" \
						or n == "BuildColumn" or n == "BuildZone" or n == "BuildDebugRoot" \
						or n.begins_with("DebugOutline"):
					pass
				else:
					return true
		node = node.get_parent()
	## Explicit hit-tests — hovered can miss during the same-frame press.
	for ctrl in [window_pause_btn, master_vol_row, gfx_btn, gfx_panel, options_root, radio_column, phone_column, hud_chrome_toggle]:
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


func _build_plate_index_at(screen_pos: Vector2) -> int:
	## Tight build-plate hitbox — must not swallow grill cheese drops.
	const PAD := 12.0
	for i in STATION_COUNT:
		var plate: Control = stations[i].get("plate", null)
		if plate != null and is_instance_valid(plate) and plate.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
		var drop_btn: Control = stations[i].get("drop_btn", null)
		if drop_btn != null and is_instance_valid(drop_btn) and drop_btn.visible \
				and drop_btn.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
	return -1


func _init_build_zone_cfg() -> void:
	if not _build_zone_cfg.is_empty():
		return
	for key in BUILD_GFX_KEYS:
		_build_zone_cfg[key] = float(GFX_DEFAULTS.get(key, 0.0))


func _bz(key: String) -> float:
	_init_build_zone_cfg()
	return float(_build_zone_cfg.get(key, GFX_DEFAULTS.get(key, 0.0)))


func _build_station_hit_rect(panel: Control) -> Rect2:
	## Match BuildZone + plate on the left — not the empty right side of the panel.
	if panel == null or not is_instance_valid(panel):
		return Rect2()
	var zone := panel.get_node_or_null("BuildZone") as Control
	var base: Rect2
	if zone != null and is_instance_valid(zone):
		base = zone.get_global_rect()
	else:
		base = panel.get_global_rect()
	var hit := base.grow_individual(
		_bz("bz_hit_l"),
		_bz("bz_hit_t"),
		_bz("bz_hit_r"),
		_bz("bz_hit_b")
	)
	hit.position.x += _bz("bz_hit_shift_x")
	return hit


func _make_build_debug_outline_style(fill_alpha: float = 0.06) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BUILD_DEBUG_OUTLINE_COLOR.r, BUILD_DEBUG_OUTLINE_COLOR.g, BUILD_DEBUG_OUTLINE_COLOR.b, fill_alpha)
	sb.border_color = BUILD_DEBUG_OUTLINE_COLOR
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(2)
	return sb


func _refresh_build_debug_outlines() -> void:
	if build_debug_root != null and is_instance_valid(build_debug_root):
		build_debug_root.queue_free()
		build_debug_root = null
	if not build_area_debug_outline:
		return
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	build_debug_root = Control.new()
	build_debug_root.name = "BuildDebugRoot"
	build_debug_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	build_debug_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_debug_root.z_index = 18
	ui_root.add_child(build_debug_root)
	## Parent column for all non-grill build boxes.
	if build_column_root != null and is_instance_valid(build_column_root):
		_draw_build_debug_rect(build_column_root.get_global_rect(), "BUILD_COL", 0.03)
	## Left-column patty drop catcher (fills BUILD_COL).
	if build_drop_zone != null and is_instance_valid(build_drop_zone):
		_draw_build_debug_rect(build_drop_zone.get_global_rect(), "DROP_L", 0.04)
	## Grill-left fuzzy drop line — only over the counter band (stays outside BUILD_COL).
	var grill_x := _grill_left_screen_x() + _bz("bz_grill_pad")
	var vr := get_viewport().get_visible_rect()
	_draw_build_debug_vline(
		grill_x, "GRILL_LIM",
		vr.position.y + _bz("bz_lim_top"),
		vr.position.y + vr.size.y - _bz("bz_lim_bot")
	)
	## Per-station build hitboxes (children of BUILD_COL).
	for i in STATION_COUNT:
		if i >= stations.size():
			continue
		var panel: Control = stations[i].get("panel", null)
		var plate: Control = stations[i].get("plate", null)
		if panel != null and is_instance_valid(panel):
			_draw_build_debug_rect(panel.get_global_rect(), "PANEL", 0.03)
			_draw_build_debug_rect(_build_station_hit_rect(panel), "BUILD_HIT", 0.05)
		if plate != null and is_instance_valid(plate):
			var pad := _bz("bz_plate_pad")
			_draw_build_debug_rect(plate.get_global_rect().grow_individual(pad, pad, pad, pad), "PLATE+12", 0.07)
		var build_zone := panel.get_node_or_null("BuildZone") if panel != null else null
		if build_zone is Control and is_instance_valid(build_zone):
			_draw_build_debug_rect((build_zone as Control).get_global_rect(), "ZONE", 0.08)
	if prep_ui_overlay != null and is_instance_valid(prep_ui_overlay):
		_draw_build_debug_rect(prep_ui_overlay.get_global_rect(), "INGREDIENTS", 0.06)
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		_draw_build_debug_rect(grill_drop_zone.get_global_rect(), "GRILL_DROP", 0.04)


func _ensure_build_column_root() -> Control:
	## Left ~15% parent for DROP_L / stations / plate / BUILD_HIT — not grill zones.
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return null
	if build_column_root != null and is_instance_valid(build_column_root):
		_layout_build_column_root()
		return build_column_root
	build_column_root = Control.new()
	build_column_root.name = "BuildColumnRoot"
	build_column_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_column_root.z_index = 10
	ui_root.add_child(build_column_root)
	_layout_build_column_root()
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout_build_column_root):
		view.size_changed.connect(_layout_build_column_root)
	return build_column_root


func _layout_build_column_root() -> void:
	if build_column_root == null or not is_instance_valid(build_column_root):
		return
	build_column_root.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	build_column_root.anchor_left = 0.0
	build_column_root.anchor_right = BUILD_COLUMN_SCREEN_FRAC
	build_column_root.anchor_top = 0.0
	build_column_root.anchor_bottom = 1.0
	build_column_root.offset_left = BUILD_COLUMN_LEFT_MARGIN
	build_column_root.offset_right = 0.0
	build_column_root.offset_top = 8.0
	build_column_root.offset_bottom = -BUILD_COLUMN_BOTTOM_CLEAR
	build_column_root.grow_horizontal = Control.GROW_DIRECTION_END
	build_column_root.grow_vertical = Control.GROW_DIRECTION_BOTH


func _adopt_into_build_column(node: Control) -> void:
	var col := _ensure_build_column_root()
	if col == null or node == null or not is_instance_valid(node):
		return
	if node.get_parent() == col:
		return
	var gp := node.global_position
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	col.add_child(node)
	node.global_position = gp


func _layout_build_column_children() -> void:
	## Stations + DROP_L fill the left column parent (grill zones stay outside).
	_layout_build_column_root()
	if stations_row != null and is_instance_valid(stations_row):
		_adopt_into_build_column(stations_row)
		stations_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		stations_row.anchor_left = 0.0
		stations_row.anchor_right = 1.0
		stations_row.anchor_top = 0.0
		stations_row.anchor_bottom = 1.0
		stations_row.offset_left = _bz("bz_row_left")
		stations_row.offset_right = _bz("bz_row_right")
		stations_row.offset_top = _bz("bz_row_top")
		stations_row.offset_bottom = _bz("bz_row_bottom")
		stations_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
		stations_row.grow_vertical = Control.GROW_DIRECTION_BOTH
		stations_row.custom_minimum_size = Vector2(0, 0)
		stations_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stations_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		stations_row.z_index = 1
		stations_row.z_as_relative = true
	if build_drop_zone != null and is_instance_valid(build_drop_zone):
		_adopt_into_build_column(build_drop_zone)
		build_drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		build_drop_zone.anchor_left = 0.0
		build_drop_zone.anchor_right = 1.0
		build_drop_zone.anchor_top = 0.0
		build_drop_zone.anchor_bottom = 1.0
		build_drop_zone.offset_left = _bz("bz_drop_left")
		build_drop_zone.offset_right = _bz("bz_drop_right")
		build_drop_zone.offset_top = _bz("bz_drop_top")
		build_drop_zone.offset_bottom = _bz("bz_drop_bottom")
		build_drop_zone.grow_horizontal = Control.GROW_DIRECTION_BOTH
		build_drop_zone.grow_vertical = Control.GROW_DIRECTION_BOTH
		build_drop_zone.z_index = 0
		build_drop_zone.z_as_relative = true
	call_deferred("_refresh_build_debug_outlines")


func _build_column_screen_rect() -> Rect2:
	if build_column_root != null and is_instance_valid(build_column_root):
		return build_column_root.get_global_rect()
	var vr := get_viewport().get_visible_rect()
	return Rect2(
		vr.position.x + BUILD_COLUMN_LEFT_MARGIN,
		vr.position.y + 8.0,
		maxf(80.0, vr.size.x * BUILD_COLUMN_SCREEN_FRAC - BUILD_COLUMN_LEFT_MARGIN),
		vr.size.y - 8.0 - BUILD_COLUMN_BOTTOM_CLEAR
	)


func _draw_build_debug_rect(global_rect: Rect2, tag: String, fill_alpha: float) -> void:
	if build_debug_root == null or not is_instance_valid(build_debug_root):
		return
	if global_rect.size.x < 2.0 or global_rect.size.y < 2.0:
		return
	var local := build_debug_root.get_global_transform_with_canvas().affine_inverse() * global_rect.position
	var box := PanelContainer.new()
	box.name = "DebugOutline_%s" % tag
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = local
	box.size = global_rect.size
	box.add_theme_stylebox_override("panel", _make_build_debug_outline_style(fill_alpha))
	build_debug_root.add_child(box)
	var lab := Label.new()
	lab.text = tag
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", BUILD_DEBUG_OUTLINE_COLOR)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 3)
	UiFontsScript.apply_label(lab, true, 10)
	lab.position = Vector2(3, 1)
	box.add_child(lab)


func _draw_build_debug_vline(screen_x: float, tag: String, y0: float = -1.0, y1: float = -1.0) -> void:
	if build_debug_root == null or not is_instance_valid(build_debug_root):
		return
	var vr := get_viewport().get_visible_rect()
	var top_y := y0 if y0 >= 0.0 else vr.position.y
	var bot_y := y1 if y1 >= 0.0 else vr.position.y + vr.size.y
	var local_x := screen_x - build_debug_root.global_position.x
	var line := ColorRect.new()
	line.name = "DebugOutline_%s" % tag
	line.color = BUILD_DEBUG_OUTLINE_COLOR
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(local_x - 1.0, top_y - build_debug_root.global_position.y)
	line.size = Vector2(2.0, maxf(8.0, bot_y - top_y))
	build_debug_root.add_child(line)
	var lab := Label.new()
	lab.text = tag
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", BUILD_DEBUG_OUTLINE_COLOR)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 3)
	UiFontsScript.apply_label(lab, true, 9)
	lab.position = Vector2(local_x + 4.0, 52.0)
	build_debug_root.add_child(lab)


func _station_index_at(screen_pos: Vector2) -> int:
	## Build column only — prep overlay + grill steel must stay clickable.
	const PAD := 48.0
	for i in STATION_COUNT:
		var plate: Control = stations[i].get("plate", null)
		if plate != null and is_instance_valid(plate) and plate.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
		var drop_btn: Control = stations[i].get("drop_btn", null)
		if drop_btn != null and is_instance_valid(drop_btn) and drop_btn.visible \
				and drop_btn.get_global_rect().grow(PAD).has_point(screen_pos):
			return i
		var panel: Control = stations[i].get("panel", null)
		if panel != null and is_instance_valid(panel) \
				and _build_station_hit_rect(panel).has_point(screen_pos):
			return i
	return -1


func _grill_left_screen_x() -> float:
	## Screen X of the cook-surface's left edge (toward the cutting board).
	if camera == null:
		return _bz("bz_drop_right")
	var y := GRILL_SURFACE_Y + 0.04
	var z := GRILL_SURFACE_Z
	var a := camera.unproject_position(Vector3(GRILL_CENTER_X - GRILL_WIDTH * 0.5, y, z))
	var b := camera.unproject_position(Vector3(GRILL_CENTER_X + GRILL_WIDTH * 0.5, y, z))
	return minf(a.x, b.x)


func _is_build_drop_at(screen_pos: Vector2) -> bool:
	## Left Build column (BUILD_COL) — not the grill / GRILL_LIM stretch.
	if _station_index_at(screen_pos) >= 0:
		return true
	return _build_column_screen_rect().has_point(screen_pos)


func _blocks_grill_pick(screen_pos: Vector2) -> bool:
	## Build UI is drawn over the grill — block 3D patty picks behind it (incl. yellow selection).
	if _is_grill_screen_point(screen_pos):
		for i in STATION_COUNT:
			var plate: Control = stations[i].get("plate", null)
			if plate != null and is_instance_valid(plate):
				if plate.get_global_rect().grow_individual(8, 34, 8, 8).has_point(screen_pos):
					return true
		return false
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		var panel: Control = st.get("panel", null)
		var plate: Control = st.get("plate", null)
		var preview: Control = st.get("preview", null)
		var zone := Rect2()
		var has_zone := false
		if plate != null and is_instance_valid(plate):
			zone = plate.get_global_rect().grow_individual(8, 34, 8, 8)
			has_zone = true
		if preview != null and is_instance_valid(preview):
			for child in preview.get_children():
				if child is Control:
					var cr: Rect2 = child.get_global_rect().grow(6)
					zone = cr if not has_zone else zone.merge(cr)
					has_zone = true
		if has_zone and zone.grow(6).has_point(screen_pos):
			return true
	if stations_row != null and is_instance_valid(stations_row):
		## Only block when carrying a patty — empty chrome passes grill picks through.
		if spatula_patty != null and stations_row.get_global_rect().grow(8).has_point(screen_pos):
			return true
	return false


func _end_day() -> void:
	playing = false
	day += 1
	game_over_label.text = "Day %d over!\n\nServed: %d\nPerfect: %d\nWallet: %s\n\nReady for the next rush?" % [
		day - 1, total_served, perfect_serves, _format_money(money)
	]
	restart_btn.text = "Start Day %d" % day
	game_over_panel.visible = true


# --- 3D world: inside truck, looking out ------------------------------------

func _build_3d_world() -> void:
	camera.position = Vector3(0.0, 1.65, -1.62)
	camera.look_at(Vector3(0.0, 1.32, 0.55), Vector3.UP)
	camera.fov = 58.0

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
	burner_flame_root = null
	burner_flame_tris.clear()
	burner_flame_data.clear()
	burner_flame_lights.clear()
	burner_strip_root = null
	burner_strip_cook_w = 0.0

	_build_flat_top_grill()
	_build_burner_flames()
	_build_cutting_board_prop()
	_build_wire_brush()
	_build_oil_bottle()
	_build_meat_warmer()
	_build_truck_radio_prop()
	_build_season_shaker()
	_build_fire_extinguisher()
	_build_glock()
	_build_window_cat()
	_build_outdoor_street()
	_build_first_sale_decal()
	_build_wall_paper_decals()
	_build_menu_board_decal()
	_build_soda_station()
	## Wall Burger Pals logo removed — was crowding the tool rack / extinguisher.
	_build_window_bunting()

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

	## Heat-zone steel panels — FULL · 1/2 · HOLD (screen-left → right).
	var bands: Array = _grill_zone_bands()
	grill_surface_mat = null
	grill_glow_meshes.clear()
	_ensure_grill_steel_texture()
	var heat_tex := _make_grill_heat_texture()
	var cook_x0 := 0.0
	var cook_x1 := 0.0
	var cook_started := false
	for z in bands:
		var local_cx := float(z["cx"]) - GRILL_CENTER_X
		var zw := float(z["w"])
		var mat := _make_grill_zone_metal(z["col"], float(z["rough"]), float(z["emit"]), zw, GRILL_DEPTH)
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
		grill_surface_mat = _make_grill_zone_metal(Color(0.28, 0.3, 0.33), 0.22, 0.0, GRILL_WIDTH, GRILL_DEPTH)

	## Soft specular band on top of the tiled steel (kept subtle).
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

	## Heat shimmer / warp over FULL + 1/2 cook bands (not HOLD).
	_build_heat_warp_plane(
		surface,
		Vector3(cook_cx_world - GRILL_CENTER_X, 0.12, 0.07),
		cook_w * 0.82,
		GRILL_DEPTH * 0.92
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


func _build_burner_flames() -> void:
	## Compact flame triangles tucked under the cook-facing grill lip.
	if burner_flame_root != null and is_instance_valid(burner_flame_root):
		burner_flame_root.queue_free()
	burner_flame_root = null
	burner_flame_tris.clear()
	burner_flame_data.clear()
	burner_flame_lights.clear()
	burner_strip_root = null
	burner_strip_cook_w = 0.0

	var root := Node3D.new()
	root.name = "BurnerFlames"
	## ~12% up from last pass; thickness restored.
	const TRI_H := 0.043
	const TRI_W := 0.030
	var gap_y := GRILL_SURFACE_Y - 0.045
	## Under the cook lip, nudged ~2" toward the player (was 3").
	var gap_z := GRILL_SURFACE_Z - GRILL_DEPTH * 0.48 - 0.051
	root.position = Vector3(GRILL_CENTER_X, gap_y, gap_z)
	world.add_child(root)
	burner_flame_root = root

	var max_tip_y := GRILL_SURFACE_Y + 0.002
	var tip_budget := max_tip_y - gap_y
	var cook_w := GRILL_WIDTH * 0.92
	var mesh := _make_burner_flame_triangle_mesh(TRI_W, TRI_H)
	var count := 70
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_receive_shadows = true
		mat.render_priority = 12
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		mi.material_override = mat
		var nx := (float(i) + 0.5) / float(count) - 0.5
		var row := i % 3
		var base := Vector3(
			nx * cook_w + randf_range(-0.008, 0.008),
			randf_range(0.0, 0.006) + float(row) * 0.003,
			randf_range(-0.008, 0.012) - float(row) * 0.008
		)
		mi.position = base
		mi.scale = Vector3.ONE * randf_range(0.65, 0.94)
		## Mild pitch toward camera — enough to read, not lean into the player.
		mi.rotation_degrees = Vector3(-22.0 + randf_range(-4.0, 4.0), 180.0 + randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))
		mi.visible = false
		root.add_child(mi)
		burner_flame_tris.append(mi)
		burner_flame_data.append({
			"base": base,
			"phase": randf() * TAU,
			"spd": randf_range(4.5, 8.5),
			"amp": randf_range(0.0025, 0.0055),
			"lean": randf_range(-3.5, 3.5),
			"pulse": randf_range(0.7, 1.05),
			"sc": mi.scale.x,
			"tri_h": TRI_H,
			"tip_budget": tip_budget,
			"pitch": -22.0 + randf_range(-4.0, 4.0),
		})

	## Orange strip — spans cook width, pitched down onto the lip / apron (+Z, −Y).
	var strip_root := Node3D.new()
	strip_root.name = "BurnerStripLight"
	burner_strip_root = strip_root
	burner_strip_cook_w = cook_w
	const STRIP_COUNT := 11
	for i in STRIP_COUNT:
		var sl := SpotLight3D.new()
		sl.name = "BurnerStripSeg"
		sl.light_color = Color(1.0, 0.46, 0.12)
		sl.light_indirect_energy = 0.35
		sl.spot_attenuation = 0.48
		sl.shadow_enabled = false
		var t := (float(i) + 0.5) / float(STRIP_COUNT) - 0.5
		sl.position = Vector3(t * cook_w * float(GFX_DEFAULTS["strip_width"]), 0.0, 0.0)
		strip_root.add_child(sl)
		burner_flame_lights.append(sl)
	root.add_child(strip_root)
	_apply_burner_strip_settings(GFX_DEFAULTS)

	root.visible = false


func _make_burner_strip_projector() -> Texture2D:
	## Unused — kept so older gfx presets don't break if referenced.
	const W := 128
	const H := 32
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _make_burner_flame_triangle_mesh(w: float, h: float) -> ArrayMesh:
	## Dark purple base → yellow → orange → modest red tip. No pale/white.
	var mesh := ArrayMesh.new()
	var n := Vector3(0, 0, 1)
	var y0 := -h * 0.45 ## deep purple (tiny bottom)
	var y1 := -h * 0.28 ## yellow
	var y2 := h * 0.08 ## orange (bulk)
	var y3 := h * 0.32 ## soft red
	var y4 := h * 0.55 ## tip
	var c_purp := Color(0.28, 0.06, 0.55, 1.0) ## darker — won't bloom white
	var c_yel := Color(1.0, 0.68, 0.04, 1.0)
	var c_org := Color(1.0, 0.38, 0.02, 1.0)
	var c_red := Color(0.95, 0.12, 0.0, 1.0)
	var c_tip := Color(0.88, 0.08, 0.0, 1.0)

	var rows: Array = [
		{"y": y0, "hw": w * 0.52, "c": c_purp},
		{"y": y1, "hw": w * 0.44, "c": c_yel},
		{"y": y2, "hw": w * 0.34, "c": c_org},
		{"y": y3, "hw": w * 0.20, "c": c_red},
		{"y": y4, "hw": 0.0, "c": c_tip},
	]
	for r in range(rows.size() - 1):
		var a: Dictionary = rows[r]
		var b: Dictionary = rows[r + 1]
		var ay: float = float(a["y"])
		var by: float = float(b["y"])
		var aw: float = float(a["hw"])
		var bw: float = float(b["hw"])
		var ca: Color = a["c"]
		var cb: Color = b["c"]
		var al := Vector3(-aw, ay, 0.0)
		var ar := Vector3(aw, ay, 0.0)
		var bl := Vector3(-bw, by, 0.0)
		var br := Vector3(bw, by, 0.0)
		if bw <= 0.0001:
			var tip := Vector3(0.0, by, 0.0)
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([tip, al, ar])
			arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n])
			arr[Mesh.ARRAY_COLOR] = PackedColorArray([cb, ca, ca])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		else:
			var arr1: Array = []
			arr1.resize(Mesh.ARRAY_MAX)
			arr1[Mesh.ARRAY_VERTEX] = PackedVector3Array([bl, al, ar])
			arr1[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n])
			arr1[Mesh.ARRAY_COLOR] = PackedColorArray([cb, ca, ca])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr1)
			var arr2: Array = []
			arr2.resize(Mesh.ARRAY_MAX)
			arr2[Mesh.ARRAY_VERTEX] = PackedVector3Array([bl, ar, br])
			arr2[Mesh.ARRAY_NORMAL] = PackedVector3Array([n, n, n])
			arr2[Mesh.ARRAY_COLOR] = PackedColorArray([cb, ca, cb])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	return mesh


func _set_burner_flames_visible(on: bool) -> void:
	if burner_flame_root == null or not is_instance_valid(burner_flame_root):
		return
	burner_flame_root.visible = on
	for mi in burner_flame_tris:
		if is_instance_valid(mi):
			mi.visible = on
	for light in burner_flame_lights:
		if is_instance_valid(light):
			light.visible = on
			if light is SpotLight3D:
				(light as SpotLight3D).light_energy = burner_strip_energy if on else 0.0
			elif light is OmniLight3D:
				(light as OmniLight3D).light_energy = 0.22 if on else 0.0


func _update_burner_flames(delta: float) -> void:
	if not grill_on or burner_flame_root == null or not burner_flame_root.visible:
		return
	for i in burner_flame_tris.size():
		var mi: MeshInstance3D = burner_flame_tris[i]
		if not is_instance_valid(mi):
			continue
		var d: Dictionary = burner_flame_data[i]
		d["phase"] = float(d["phase"]) + delta * float(d["spd"])
		var ph: float = float(d["phase"])
		var amp: float = float(d["amp"])
		var base: Vector3 = d["base"]
		var tip_budget: float = float(d["tip_budget"])
		var tri_h: float = float(d["tri_h"])
		var pitch: float = float(d.get("pitch", -22.0))
		var wob_x := sin(ph) * amp + sin(ph * 1.7 + 0.4) * amp * 0.28
		var wob_z := cos(ph * 0.9 + 0.6) * amp * 0.18
		var wob_y := absf(sin(ph * 1.35)) * amp * 0.22
		var pos := base + Vector3(wob_x, wob_y, wob_z)
		pos.z = clampf(pos.z, -0.03, 0.02)
		var pulse := 0.96 + 0.07 * absf(sin(ph * float(d["pulse"])))
		var sc: float = float(d["sc"]) * pulse
		## Soft tip clamp under the steel lip.
		var tip_y := pos.y + tri_h * 0.55 * sc * cos(deg_to_rad(absf(pitch)))
		if tip_y > tip_budget:
			pos.y -= (tip_y - tip_budget) * 0.55
		mi.position = pos
		mi.scale = Vector3(sc * (0.97 + 0.04 * sin(ph * 1.6)), sc, sc)
		mi.rotation_degrees = Vector3(
			pitch + sin(ph * 1.1) * 1.4,
			180.0 + float(d["lean"]) + sin(ph * 0.8) * 2.2,
			cos(ph * 1.3) * 1.6
		)
		burner_flame_data[i] = d


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
	if mp_enabled and not _mp_applying:
		mp_residue_clean.rpc(slot)
		return
	_scrape_finish_clean_local(slot)


func _scrape_finish_clean_local(slot: int) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	var chunks: Array = grill_residue_chunks[slot] if slot < grill_residue_chunks.size() else []
	for ch in chunks:
		if ch == null or not is_instance_valid(ch):
			continue
		var fly: Vector3 = ch.position + Vector3(randf_range(-0.1, 0.1), 0.06, randf_range(-0.1, 0.1))
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
	btn.custom_minimum_size = Vector2(112, 22)
	btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(btn, true, 10)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.12, 0.1)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.25, 0.15)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.48, 0.16, 0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(1, 0.85, 0.75))
	btn.pressed.connect(func():
		_toggle_grill_power(0)
	)
	grill_power_row.add_child(btn)
	grill_ui_buttons.append(btn)

	var trash := Button.new()
	trash.text = "🗑 GARBAGE"
	trash.tooltip_text = "Drag a Build topping or patty here to toss it"
	trash.custom_minimum_size = Vector2(96, 22)
	trash.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(trash, true, 10)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.22, 0.22, 0.24)
	tsb.set_corner_radius_all(8)
	tsb.set_border_width_all(2)
	tsb.border_color = Color(0.55, 0.55, 0.58)
	tsb.content_margin_left = 10
	tsb.content_margin_right = 10
	tsb.content_margin_top = 5
	tsb.content_margin_bottom = 5
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
	_layout_grill_power_row_centered()
	_refresh_grill_ui_button(0)


func _layout_grill_power_row_centered() -> void:
	## BottomUI is right-aligned for toppings — pin burner/garbage to screen center.
	if grill_power_row == null:
		return
	var ui_root: Control = get_node_or_null("UI/Root") as Control
	if ui_root == null:
		return
	if grill_power_row.get_parent() != ui_root:
		var old_parent := grill_power_row.get_parent()
		if old_parent != null:
			old_parent.remove_child(grill_power_row)
		ui_root.add_child(grill_power_row)
	grill_power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	grill_power_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grill_power_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	grill_power_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var half_w := GRILL_POWER_ROW_WIDTH * 0.5
	grill_power_row.offset_left = -half_w
	grill_power_row.offset_right = half_w
	grill_power_row.offset_bottom = -GRILL_POWER_ROW_BOTTOM
	grill_power_row.offset_top = grill_power_row.offset_bottom - 26.0
	grill_power_row.z_index = 8


func _is_over_garbage(screen_pos: Vector2) -> bool:
	if grill_trash_btn == null or not is_instance_valid(grill_trash_btn):
		return false
	## Generous catch pad — Build toppings are dragged from across the screen.
	var r := grill_trash_btn.get_global_rect().grow(28.0)
	return r.has_point(screen_pos)


func _can_drop_patty_on_garbage(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = data.get("kind", "")
	## Build layers, Build patties, or strip toppings dragged to trash.
	return kind == "station_patty" or kind == "reorder" or kind == "ingredient"


func _drop_patty_on_garbage(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var kind: String = data.get("kind", "")
	if kind == "station_patty":
		var st_i := int(data.get("station", -1))
		var from_i := int(data.get("from", -1))
		_pending_station_patty_drag = null
		if mp_enabled and not _mp_applying:
			mp_trash_station_patty.rpc(st_i, from_i)
			return
		var patty = _extract_station_patty(st_i, from_i)
		if patty != null and is_instance_valid(patty):
			patty.queue_free()
			if game_audio and game_audio.has_method("play_trash"):
				game_audio.play_trash()
			_spend(COST_DROP_BURGER, "Trashed a burger — %s" % _format_money(COST_DROP_BURGER), Color("FFAB91"))
		return
	if kind == "reorder":
		var st2 := int(data.get("station", -1))
		var from2 := int(data.get("from", -1))
		_pending_reorder_drag = null
		if st2 < 0 or st2 >= STATION_COUNT:
			return
		if mp_enabled and not _mp_applying:
			mp_trash_build_layer.rpc(st2, from2)
			return
		_trash_station_layer(st2, from2)
		return
	if kind == "ingredient":
		## Strip topping tossed before it hit Build — just discard the drag.
		_pending_ingredient_drag = ""
		_pending_cheese_drag = false
		if cheese_held:
			_cancel_cheese_hold_silent()
		var id := str(data.get("id", ""))
		if game_audio and game_audio.has_method("play_trash"):
			game_audio.play_trash()
		var label: String = GameDataScript.INGREDIENT_LABELS.get(id, id.capitalize())
		_flash("Trashed %s" % label, Color("FFAB91"))
		_strip_gesture_added = true
		_strip_did_drag = true


func _trash_station_layer(station_index: int, layer_index: int) -> void:
	## Remove a specific Build stack layer (used by drag-to-garbage).
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if layer_index < 0 or layer_index >= items.size():
		_flash("%s is empty" % _station_label(station_index), Color("B0BEC5"))
		return
	_select_station(station_index)
	st["selected_layer"] = layer_index
	_trash_selected_or_top_layer(station_index)


func _trash_spatula_patty() -> void:
	if spatula_patty == null:
		_flash("Nothing on the spatula to trash", Color("B0BEC5"))
		return
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id() and not _mp_applying:
		return
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_trash_patty.rpc(int(spatula_patty.net_id))
		return
	_trash_spatula_patty_local()


func _trash_spatula_patty_local() -> void:
	if spatula_patty == null:
		_flash("Nothing on the spatula to trash", Color("B0BEC5"))
		return
	var was_bun := _is_bun_toast(spatula_patty)
	if is_instance_valid(spatula_patty):
		spatula_patty.queue_free()
	spatula_patty = null
	spatula_owner_id = 0
	spatula_from_build = false
	spatula_lmb_held = false
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	if game_audio and game_audio.has_method("play_trash"):
		game_audio.play_trash()
	if was_bun:
		_flash("Trashed bun", Color("FFAB91"))
	else:
		_spend(COST_DROP_BURGER, "Trashed scooped burger — %s" % _format_money(COST_DROP_BURGER), Color("FFAB91"))


func _trash_single_grill_patty(patty: Area3D) -> void:
	## Toss one grill patty — does not clear the whole flat-top.
	if patty == null or not is_instance_valid(patty):
		return
	if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
		mp_trash_patty.rpc(int(patty.net_id))
		return
	_trash_single_grill_patty_local(patty)


func _trash_single_grill_patty_local(patty: Area3D) -> void:
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
	if spatula_patty == patty:
		spatula_patty = null
		spatula_owner_id = 0
	patty.queue_free()
	if game_audio and game_audio.has_method("play_trash"):
		game_audio.play_trash()
	_spend(COST_DROP_BURGER, "Trashed a burger — %s" % _format_money(COST_DROP_BURGER), Color("FFAB91"))


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
	if mp_enabled and not _mp_applying:
		mp_toggle_grill.rpc(not grill_on)
		return
	_toggle_grill_power_local(not grill_on)


func _toggle_grill_power_local(turning_on: bool) -> void:
	grill_ignore_pad_until = Time.get_ticks_msec() / 1000.0 + 0.35
	if not turning_on:
		_sfx_click()
	_set_grill_on(turning_on)
	if grill_on:
		if _tutorial_step == 1:
			_set_tutorial_hint(2, "Right-click to add burger patty on grill")
		else:
			_flash("Burner ON — right-click the grill where you want each patty", Color("FFCC80"))
	else:
		_flash("Burner OFF", Color("B0BEC5"))
		if _tutorial_step == 2:
			_set_tutorial_hint(1, "Turn on grill or burner")


func _set_grill_on(on: bool) -> void:
	var turning_on := on and not grill_on
	grill_on = on
	for i in GRILL_SLOTS:
		grill_powered[i] = on

	# Visual ignition cue: delay+fade radial glows when the burner turns ON.
	_grill_glow_gen += 1
	var glow_gen := _grill_glow_gen
	if _grill_glow_tween != null:
		_grill_glow_tween.kill()
		_grill_glow_tween = null

	if turning_on:
		for glow in grill_glow_meshes:
			if not is_instance_valid(glow):
				continue
			glow.visible = false
			var gm := glow.material_override as StandardMaterial3D
			if gm == null:
				continue
			# Start fully transparent/quiet; tween both alpha and emission after ignition.
			var rgb := gm.albedo_color
			rgb.a = 1.0
			gm.albedo_color = Color(rgb.r, rgb.g, rgb.b, 0.0)
			gm.emission_energy_multiplier = 0.0

		_grill_glow_tween = create_tween()
		_grill_glow_tween.tween_interval(GRILL_GLOW_DELAY_SEC)
		_grill_glow_tween.tween_callback(func() -> void:
			if glow_gen != _grill_glow_gen:
				return
			for glow in grill_glow_meshes:
				if is_instance_valid(glow):
					glow.visible = true
		)
		_grill_glow_tween.set_parallel(true)
		for glow in grill_glow_meshes:
			if not is_instance_valid(glow):
				continue
			var gm := glow.material_override as StandardMaterial3D
			if gm == null:
				continue
			var base_alpha := float(glow.get_meta("base_alpha", gm.albedo_color.a))
			var base_em := float(glow.get_meta("base_emission_energy_multiplier", gm.emission_energy_multiplier))
			var target_alpha := minf(1.0, base_alpha * GRILL_GLOW_BRIGHT_MULT)
			var target_em := base_em * GRILL_GLOW_BRIGHT_MULT
			var rgb := gm.albedo_color
			rgb.a = 1.0
			var target_col := Color(rgb.r, rgb.g, rgb.b, target_alpha)
			_grill_glow_tween.tween_property(
				gm,
				"albedo_color",
				target_col,
				GRILL_GLOW_FADE_SEC
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_grill_glow_tween.tween_property(
				gm,
				"emission_energy_multiplier",
				target_em,
				GRILL_GLOW_FADE_SEC
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_grill_glow_tween.set_parallel(false)
	else:
		for glow in grill_glow_meshes:
			if not is_instance_valid(glow):
				continue
			glow.visible = false
			var gm := glow.material_override as StandardMaterial3D
			if gm == null:
				continue
			var c := gm.albedo_color
			c.a = 0.0
			gm.albedo_color = c
			gm.emission_energy_multiplier = 0.0

	for heat in grill_heat_lights:
		if is_instance_valid(heat):
			heat.light_energy = 0.0
			heat.visible = false
	## Zone steel keeps a warm emission wash when the burner is on.
	for mat in grill_pad_mats:
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			sm.emission_enabled = on and sm.emission_energy_multiplier > 0.01
	if turning_on and game_audio and game_audio.has_method("play_stove_light"):
		game_audio.play_stove_light()
	## Lighting a grill already swimming in grease → it can catch immediately.
	if on:
		_check_oil_fire_risk()
	_set_burner_flames_visible(on)
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


func _pick_patty_at_screen(screen_pos: Vector2, max_world: float = -1.0):
	## Prefer the burger under the cursor on screen — not a plane-hit or back-stack neighbor.
	## max_world < 0 → generous scoop/drag pick; set tighter (e.g. smash) to require a real hit.
	if _blocks_grill_pick(screen_pos):
		return null
	if camera == null:
		return null
	var world_lim := PATTY_PICK_WORLD if max_world < 0.0 else max_world
	var min_px := PATTY_PICK_MIN_PX if max_world < 0.0 else PATTY_SMASH_MIN_PX
	var pad_px := PATTY_PICK_PAD_PX if max_world < 0.0 else PATTY_SMASH_PAD_PX
	var edge_r := PATTY_PICK_WORLD_EDGE if max_world < 0.0 else max_world
	var plane_hit := _grill_plane_from_screen(screen_pos)
	var cam_pos := camera.global_position
	var candidates: Array = [] ## {p, screen_d, cam_d, in_screen}
	for p in grill:
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		var lift: Vector3 = p.global_position + Vector3(0, 0.03, 0)
		if camera.is_position_behind(lift):
			continue
		var screen_pt := camera.unproject_position(lift)
		var pick_px := maxf(min_px, _patty_screen_pick_radius_px(lift, edge_r, pad_px))
		var screen_d := screen_pos.distance_to(screen_pt)
		var in_screen := screen_d <= pick_px
		var near_plane := false
		if plane_hit != Vector3.ZERO:
			near_plane = Vector2(plane_hit.x - p.position.x, plane_hit.z - p.position.z).length() <= world_lim
		if not in_screen and not near_plane:
			continue
		candidates.append({
			"p": p,
			"screen_d": screen_d,
			"cam_d": cam_pos.distance_to(lift),
			"in_screen": in_screen,
		})
	if candidates.is_empty():
		return null
	## If anything sits under the cursor on screen, ignore plane-only far misses.
	var any_screen := false
	for c in candidates:
		if bool(c["in_screen"]):
			any_screen = true
			break
	if any_screen:
		candidates = candidates.filter(func(c): return bool(c["in_screen"]))
	## Closest on screen wins; ties break toward the front (nearer camera).
	candidates.sort_custom(func(a, b):
		var sa: float = float(a["screen_d"])
		var sb: float = float(b["screen_d"])
		if absf(sa - sb) > 2.5:
			return sa < sb
		return float(a["cam_d"]) < float(b["cam_d"])
	)
	return candidates[0]["p"]


func _pick_patty_for_smash(screen_pos: Vector2):
	## Right-click on the burger → smash. Empty steel / near-miss → place.
	## Screen-space first: clicking the raised top projects past the grill-plane disc.
	if _blocks_grill_pick(screen_pos):
		return null
	if camera == null:
		return null
	var plane_hit := _grill_plane_from_screen(screen_pos)
	var best = null
	var best_score := 9999.0
	for p in grill:
		if p == null or not is_instance_valid(p) or p.is_held:
			continue
		## Tall hit column: meat mid → cheese / hold-ring so top clicks still count.
		var screen_d := 9999.0
		var pick_px := PATTY_SMASH_MIN_PX
		var any_front := false
		for i in 4:
			var t := float(i) / 3.0
			var y := lerpf(PATTY_SMASH_Y_LO, PATTY_SMASH_Y_HI, t)
			var sample: Vector3 = p.global_position + Vector3(0, y, 0)
			if camera.is_position_behind(sample):
				continue
			any_front = true
			var screen_pt := camera.unproject_position(sample)
			var d := screen_pos.distance_to(screen_pt)
			if d < screen_d:
				screen_d = d
				pick_px = clampf(
					_patty_screen_pick_radius_px(sample, PATTY_SMASH_WORLD, PATTY_SMASH_PAD_PX),
					PATTY_SMASH_MIN_PX,
					PATTY_SMASH_MAX_PX
				)
		if not any_front:
			continue
		var on_meat := screen_d <= pick_px
		if not on_meat and plane_hit != Vector3.ZERO:
			var world_d := Vector2(plane_hit.x - p.position.x, plane_hit.z - p.position.z).length()
			on_meat = world_d <= PATTY_SMASH_WORLD
		if not on_meat:
			continue
		var score := screen_d
		if plane_hit != Vector3.ZERO:
			score = minf(score, Vector2(plane_hit.x - p.position.x, plane_hit.z - p.position.z).length() * 80.0)
		if score < best_score:
			best_score = score
			best = p
	return best


func _smash_grill_patty(patty: Area3D) -> void:
	if patty == null or not is_instance_valid(patty):
		return
	if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
		mp_patty_smash.rpc(int(patty.net_id))
		return
	patty.smash()


func _patty_screen_pick_radius_px(world_pt: Vector3, edge_r: float = -1.0, pad_px: float = -1.0) -> float:
	var er := PATTY_PICK_WORLD_EDGE if edge_r < 0.0 else edge_r
	var pad := PATTY_PICK_PAD_PX if pad_px < 0.0 else pad_px
	var edge := world_pt + Vector3(er, 0, 0)
	var c2 := camera.unproject_position(world_pt)
	var e2 := camera.unproject_position(edge)
	return c2.distance_to(e2) + pad


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
	if mp_enabled and not _mp_applying:
		if NetManager.is_host():
			var nid := NetManager.alloc_net_id()
			mp_spawn_patty.rpc(nid, idx, place_pos.x, place_pos.z)
		else:
			mp_request_spawn_patty.rpc_id(1, place_pos.x, place_pos.z)
		return
	_spawn_patty_at(idx, place_pos)


func _spawn_patty_at(idx: int, world_pos: Vector3, net_id: int = -1) -> void:
	if not playing and not _mp_applying:
		return
	if idx < 0 or idx >= GRILL_SLOTS:
		return
	if grill[idx] != null:
		## Sync repair: free wrong occupant so the host's net_id can take this slot.
		if _mp_applying and net_id >= 0:
			var old = grill[idx]
			if old != null and is_instance_valid(old) and int(old.get("net_id")) != net_id:
				grill[idx] = null
				if spatula_patty != old and dragging_patty != old:
					old.queue_free()
			else:
				return
		else:
			return
	if not grill_on and not _mp_applying:
		_flash("Burner is OFF", Color("FFA726"))
		return
	var x := world_pos.x
	var z := world_pos.z
	var p = PattyScript.new()
	p.slot_index = idx
	p.net_id = net_id if net_id >= 0 else (-1 if not mp_enabled else NetManager.alloc_net_id())
	p.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	p.heating = true
	p.mp_puppet = mp_enabled and not NetManager.is_host()
	p.position = Vector3(x, p.base_y, z)
	p._rest_x = x
	p._rest_z = z
	patties_root.add_child(p)
	grill[idx] = p
	slot_positions[idx] = Vector3(x, GRILL_SURFACE_Y, z)
	p.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	if _mp_applying:
		## Silent repair spawn during grill sync — no flash spam.
		return
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
	if _tutorial_step == 2:
		_clear_tutorial_hint()


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
	if _is_bun_toast(patty):
		if BUN_TOAST_ENABLED:
			_pickup_bun_from_grill(patty)
		return
	## Holding a scooped patty: still flip others on the grill; scooping another is blocked.
	if spatula_patty != null:
		_on_patty_clicked(patty)
		return
	if brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held:
		return
	if flicking_patty != null:
		return
	if patty.is_held:
		return
	if dragging_patty == patty and (not mp_enabled or drag_owner_id == 0 or drag_owner_id == NetManager.my_id()):
		return
	if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
		mp_claim_drag.rpc(int(patty.net_id))
		return
	_begin_patty_drag_local(patty)


func _begin_patty_drag_local(patty: Area3D) -> void:
	if patty == null or not is_instance_valid(patty):
		return
	dragging_patty = patty
	drag_start_mouse = get_viewport().get_mouse_position()
	drag_last_mouse = drag_start_mouse
	drag_vel_screen = Vector2.ZERO
	drag_did_move = false
	drag_pop_accum = 0.0
	drag_last_xz = Vector2(patty._rest_x, patty._rest_z)
	if mp_enabled:
		drag_owner_id = NetManager.my_id()


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
		drag_owner_id = 0
		if game_audio:
			game_audio.set_slide_moving(false)
		return
	if mp_enabled and drag_owner_id != 0 and drag_owner_id != NetManager.my_id():
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
	if mp_enabled and drag_owner_id != 0 and drag_owner_id != NetManager.my_id():
		dragging_patty = null
		return
	var patty = dragging_patty
	var slid := drag_did_move
	var mouse := get_viewport().get_mouse_position()
	var vel := drag_vel_screen
	var travel := mouse.distance_to(drag_start_mouse)
	dragging_patty = null
	drag_owner_id = 0
	drag_did_move = false
	drag_vel_screen = Vector2.ZERO
	if game_audio:
		game_audio.set_slide_moving(false)
	if mp_enabled and not _mp_applying and is_instance_valid(patty) and int(patty.get("net_id")) >= 0:
		mp_release_drag.rpc(int(patty.net_id))
	if not is_instance_valid(patty):
		return
	## Drag onto the peeking cat → feed (no trash fee).
	if window_cat != null and is_instance_valid(window_cat) and window_cat.hit_test_feed(camera, mouse):
		var idx: int = int(patty.slot_index)
		if idx >= 0 and idx < grill.size() and grill[idx] == patty:
			grill[idx] = null
		if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
			mp_cat_feed.rpc("patty", int(patty.net_id))
			return
		patty.queue_free()
		window_cat.feed("patty")
		_on_window_cat_fed("patty")
		_flash("Cat stole the burger! ♥", Color("FF8A80"))
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


func _is_flick_to_grill(vel: Vector2, travel_px: float) -> bool:
	if travel_px < FLICK_MIN_TRAVEL_PX:
		return false
	if vel.length() < FLICK_MIN_SPEED:
		return false
	## Screen-right toss onto the cook surface.
	return vel.x >= FLICK_TO_GRILL_VX and absf(vel.x) >= absf(vel.y) * 0.55


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
	if _is_bun_toast(patty):
		if not BUN_TOAST_ENABLED:
			return
		## Treat like a ready scoop — no flip gate.
		pass
	elif not patty.flipped_once or not patty.can_scoop():
		_flash("Finish cooking before flicking to Build", Color("FFA726"))
		return
	if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
		mp_commit_patty_build.rpc(int(patty.net_id))
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
		if _is_bun_toast(patty):
			_commit_bun_to_build(patty)
		else:
			_commit_patty_to_build(patty)
	)


func _try_drag_patty_to_station(patty: Area3D, station_idx: int) -> void:
	if patty == null or not is_instance_valid(patty):
		return
	if _is_bun_toast(patty):
		if not BUN_TOAST_ENABLED:
			return
		_pickup_bun_from_grill(patty)
		if spatula_patty != null:
			_drop_spatula_on_station(station_idx)
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
	if mp_enabled and not _mp_applying and int(patty.get("net_id")) >= 0:
		mp_commit_patty_build.rpc(int(patty.net_id))
		return
	_pickup_patty(patty)
	if spatula_patty != null:
		_drop_spatula_on_station(station_idx)


func _on_patty_clicked(patty: Area3D) -> void:
	if not playing:
		return
	if mp_enabled and not _mp_applying and patty != null and int(patty.get("net_id")) >= 0:
		mp_patty_click.rpc(int(patty.net_id))
		return
	_on_patty_clicked_local(patty)


func _on_patty_clicked_local(patty: Area3D) -> void:
	if not playing or patty == null or not is_instance_valid(patty):
		return
	if _is_bun_toast(patty):
		_pickup_bun_from_grill(patty)
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


func _mp_mark_held(peer_id: int, patty) -> void:
	if peer_id == 0:
		return
	if patty == null or not is_instance_valid(patty):
		mp_held_net.erase(peer_id)
		return
	var nid := int(patty.get("net_id"))
	if nid < 0:
		mp_held_net.erase(peer_id)
		return
	## One scoop per peer.
	for k in mp_held_net.keys():
		if int(mp_held_net[k]) == nid and int(k) != peer_id:
			mp_held_net.erase(k)
	mp_held_net[peer_id] = nid


func _mp_clear_held_net(net_id: int) -> void:
	if net_id < 0:
		return
	for k in mp_held_net.keys():
		if int(mp_held_net[k]) == net_id:
			mp_held_net.erase(k)


func _mp_peer_holding_net(net_id: int) -> int:
	if net_id < 0:
		return 0
	for k in mp_held_net.keys():
		if int(mp_held_net[k]) == net_id:
			return int(k)
	return 0


func _mp_release_scoop_if(patty) -> void:
	if patty == null:
		return
	var nid := int(patty.get("net_id")) if patty.get("net_id") != null else -1
	_mp_clear_held_net(nid)
	if spatula_patty == patty:
		spatula_patty = null
		spatula_owner_id = 0
		spatula_from_build = false
		spatula_lmb_held = false
		spatula_vel_screen = Vector2.ZERO
		spatula_carry_travel = 0.0
		_refresh_spatula_ui()


func _mp_apply_remote_scoop(patty: Area3D, peer_id: int) -> void:
	## Partner scooped — show the patty in-air without taking our local spatula.
	if patty == null or not is_instance_valid(patty):
		return
	var idx: int = int(patty.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == patty:
		grill[idx] = null
	patty.is_held = true
	patty.heating = false
	patty.visible = true
	_leave_grill_residue(idx, patty, false)
	_mp_mark_held(peer_id, patty)


func _customer_by_net_id(net_id: int):
	if net_id < 0:
		return null
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if c.has_meta("mp_net_id") and int(c.get_meta("mp_net_id")) == net_id:
			return c
	## Fallback — hostiles / edge cases still under customers_root.
	if customers_root != null:
		for c in customers_root.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if c.has_meta("mp_net_id") and int(c.get_meta("mp_net_id")) == net_id:
				return c
	return null


func _pickup_patty(patty: Area3D) -> void:
	if spatula_patty != null:
		_reject_second_scoop()
		return
	if _is_bun_toast(patty):
		_pickup_bun_from_grill(patty)
		return
	if not patty.flipped_once or not patty.can_scoop():
		_flash("Flip and finish cooking before scooping", Color("EF5350"))
		return
	if mp_enabled:
		var nid := int(patty.get("net_id")) if patty.get("net_id") != null else -1
		var holder := _mp_peer_holding_net(nid)
		if holder != 0 and holder != NetManager.my_id():
			_flash("Partner is carrying that — click it to steal", Color("FFCC80"))
			return
	var idx: int = patty.slot_index
	if idx >= 0 and idx < grill.size():
		grill[idx] = null
	patty.is_held = true
	patty.heating = false
	patty.visible = true
	spatula_patty = patty
	if mp_enabled:
		spatula_owner_id = NetManager.my_id()
		_mp_mark_held(spatula_owner_id, patty)
	else:
		spatula_owner_id = 0
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
		spatula_owner_id = 0
		return
	## Remote scoop — pose is driven by mp_patty_pose, not local mouse.
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id():
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
	if _try_feed_held_patty_to_cat(screen_pos):
		return true
	if _is_over_garbage(screen_pos):
		_trash_spatula_patty()
		return true
	## Flick right while carrying → throw onto the grill.
	if _is_flick_to_grill(spatula_vel_screen, spatula_carry_travel):
		_throw_held_patty_to_grill()
		return true
	## Left side of the screen (or Build UI) → place on Build — not only the Drop button.
	if _is_build_drop_at(screen_pos):
		## Still allow pause / GFX / top bar to win over the left drop strip.
		if _ui_blocks_world_click(screen_pos) and _station_index_at(screen_pos) < 0:
			var top_bar: Control = get_node_or_null("UI/Root/TopBar")
			var over_chrome := false
			for ctrl in [window_pause_btn, gfx_btn, gfx_panel, options_root, radio_column, phone_column, top_bar]:
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


func _handle_spatula_release(screen_pos: Vector2) -> void:
	## Build pickup: release LMB to drop — flick / Build area / grill / cat.
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		spatula_from_build = false
		return
	if _try_feed_held_patty_to_cat(screen_pos):
		return
	if _is_over_garbage(screen_pos):
		_trash_spatula_patty()
		return
	if _is_flick_to_grill(spatula_vel_screen, spatula_carry_travel):
		_throw_held_patty_to_grill()
		return
	if _is_flick_to_build(spatula_vel_screen, spatula_carry_travel):
		_throw_held_patty_to_build()
		return
	if _is_build_drop_at(screen_pos) or _station_index_at(screen_pos) >= 0:
		_drop_spatula_on_station(STATION_CRAFT)
		return
	if _try_warmer_click(screen_pos):
		return
	if _try_place_spatula_on_grill(screen_pos):
		return
	## Soft grill aim — release near the steel still counts.
	var hit := _grill_plane_from_screen(screen_pos)
	if hit != Vector3.ZERO and _is_near_grill_for_place(hit):
		if _is_in_warmer_zone(hit):
			_place_spatula_on_warmer(hit)
		else:
			_place_spatula_on_grill(hit)
		return
	## Missed both — if this came from Build, put it back there.
	if spatula_from_build:
		_drop_spatula_on_station(STATION_CRAFT)
		_flash("Back on Build", Color("B0BEC5"))
		return
	_flash("Drop on the grill, HOLD, or Build", Color("FFCC80"))


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
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id() and not _mp_applying:
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
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_place_spatula.rpc(int(spatula_patty.net_id), idx, pos.x, pos.z)
		return
	_place_spatula_on_grill_local(idx, pos)


func _place_spatula_on_grill_local(idx: int, pos: Vector3, patty: Area3D = null) -> void:
	if patty == null:
		patty = spatula_patty
	if patty == null or not is_instance_valid(patty):
		return
	_mp_release_scoop_if(patty)
	_place_extracted_patty_on_grill(patty, idx, pos)


func _throw_held_patty_to_build() -> void:
	## Arc from the hand into Build (same destination as a left flick scoop).
	if spatula_patty == null or not is_instance_valid(spatula_patty) or flicking_patty != null:
		return
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id() and not _mp_applying:
		return
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_drop_to_build.rpc(int(spatula_patty.net_id), STATION_CRAFT)
		return
	var patty = spatula_patty
	spatula_patty = null
	spatula_owner_id = 0
	spatula_from_build = false
	spatula_lmb_held = false
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
		if _is_bun_toast(patty):
			_commit_bun_to_build(patty)
		else:
			_commit_patty_to_build(patty)
	)


func _throw_held_patty_to_grill() -> void:
	## Arc from the hand onto the grill (screen-right flick).
	if spatula_patty == null or not is_instance_valid(spatula_patty) or flicking_patty != null:
		return
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id() and not _mp_applying:
		return
	var mouse := get_viewport().get_mouse_position()
	var aim := _grill_plane_from_screen(mouse)
	if aim == Vector3.ZERO or not _is_near_grill_for_place(aim):
		aim = Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y, GRILL_SURFACE_Z)
	if _is_in_warmer_zone(aim):
		_place_spatula_on_warmer(aim)
		return
	var place := _find_closest_patty_place(aim)
	if place == Vector3.ZERO:
		_flash("No open spot — clear some space", Color("EF5350"))
		return
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill full — clear a spot first", Color("EF5350"))
		return
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_place_spatula.rpc(int(spatula_patty.net_id), idx, place.x, place.z)
		return
	var patty = spatula_patty
	spatula_patty = null
	spatula_owner_id = 0
	spatula_from_build = false
	spatula_lmb_held = false
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	patty.is_held = true
	patty.visible = true
	flicking_patty = patty
	var start: Vector3 = patty.global_position
	var end := Vector3(place.x, GRILL_SURFACE_Y + PATTY_SIT_Y, place.z)
	var peak_y := maxf(start.y, end.y) + 0.38
	if game_audio:
		game_audio.play_scoop()
	_flash("Thrown on the grill!", Color("A5D6A7"))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float):
		if patty == null or not is_instance_valid(patty):
			return
		var xz: Vector3 = start.lerp(end, t)
		var y := lerpf(start.y, end.y, t) + 4.0 * t * (1.0 - t) * (peak_y - lerpf(start.y, end.y, 0.5))
		patty.global_position = Vector3(xz.x, y, xz.z)
		patty.rotation_degrees.z = lerpf(patty.rotation_degrees.z, 22.0, t)
	, 0.0, 1.0, 0.32)
	tw.tween_callback(func():
		flicking_patty = null
		if patty == null or not is_instance_valid(patty):
			return
		## Slot may have filled during the toss — re-check.
		var land_idx := _first_empty_slot()
		if land_idx < 0 or _patty_blocked_at(place):
			_commit_patty_to_build(patty)
			_flash("No open spot — back on Build", Color("FFA726"))
			return
		_place_extracted_patty_on_grill(patty, land_idx, place)
	)


func _commit_patty_to_build(patty: Area3D) -> void:
	## Land a scooped / thrown patty on Build without requiring spatula_patty.
	if not playing or patty == null or not is_instance_valid(patty):
		return
	if _is_bun_toast(patty):
		_commit_bun_to_build(patty)
		return
	_mp_release_scoop_if(patty)
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	var st: Dictionary = stations[STATION_CRAFT]
	var items: Array = st["items"]
	patty.is_held = true
	patty.heating = false
	patty.visible = false
	patty.rotation_degrees = Vector3.ZERO
	if not st["patties"].has(patty):
		var needs_bun := not items.has("bun_bottom")
		if needs_bun and not _mp_try_use_supply("bun_bottom"):
			patty.is_held = false
			patty.visible = true
			patty.heating = grill_on
			return
		if not _mp_try_use_supply("patty"):
			if needs_bun:
				supply_stock["bun_bottom"] = int(supply_stock.get("bun_bottom", 0)) + 1
				_refresh_phone_ui()
			patty.is_held = false
			patty.visible = true
			patty.heating = grill_on
			return
		st["patties"].append(patty)
		if needs_bun:
			items.append("bun_bottom")
		_insert_patty_into_stack(items)
	## Cheese counts for the order as soon as it's on the meat (melt is visual).
	if patty.has_cheese:
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
		_flash("Patty on Build — cheese melting (%ds)" % maxi(1, int(ceil(3.0 * (1.0 - patty.cheese_melt)))), Color("FFE082"))
	else:
		_flash("Patty #%d on Build" % n, Color("A5D6A7"))
	_mp_broadcast_station(STATION_CRAFT)
	call_deferred("_try_auto_serve")


func _leave_grill_residue(slot: int, patty: Area3D, announce: bool = true) -> void:
	if patty != null and _is_bun_toast(patty):
		return
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	var at := Vector3(patty._rest_x, GRILL_SURFACE_Y + 0.028, patty._rest_z) if patty else slot_positions[slot] + Vector3(0, 0.028, 0)
	if mp_enabled and not _mp_applying:
		mp_residue_leave.rpc(slot, at.x, at.z, announce)
		return
	_leave_grill_residue_local(slot, at, announce)


func _leave_grill_residue_local(slot: int, at: Vector3, announce: bool = true) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
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
	heat_warp_base_size = Vector2(maxf(0.2, width), maxf(0.18, depth))
	plane.size = heat_warp_base_size * float(GFX_DEFAULTS["heat_warp_size"])
	heat_warp_mesh.mesh = plane
	heat_warp_mesh.position = local_pos
	heat_warp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := load("res://shaders/heat_warp.gdshader") as Shader
	heat_warp_mat = ShaderMaterial.new()
	heat_warp_mat.shader = shader
	heat_warp_mat.set_shader_parameter("warp_strength", float(GFX_DEFAULTS["heat_warp_strength"]))
	heat_warp_mat.set_shader_parameter("heat", 0.0)
	heat_warp_mat.set_shader_parameter("time_scale", float(GFX_DEFAULTS["heat_warp_speed"]))
	heat_warp_mat.set_shader_parameter("mask_tight", float(GFX_DEFAULTS["heat_warp_tight"]))
	heat_warp_mesh.material_override = heat_warp_mat
	heat_warp_mesh.visible = false
	heat_warp_enabled = true
	parent.add_child(heat_warp_mesh)


func _update_heat_warp(_delta: float) -> void:
	if heat_warp_mat == null or heat_warp_mesh == null or not is_instance_valid(heat_warp_mesh):
		return
	if not heat_warp_enabled:
		heat_warp_mesh.visible = false
		heat_warp_mat.set_shader_parameter("heat", 0.0)
		return
	var heat := 0.0
	if grill_on:
		## Idle shimmer when burner is on; cooking pushes it a bit harder.
		heat = 0.55
		for i in GRILL_SLOTS:
			var p = grill[i]
			if p == null or not is_instance_valid(p) or p.is_held:
				continue
			if not p.heating:
				continue
			var cook_t := clampf(float(p.cook_time) / 9.0, 0.2, 1.0)
			heat = maxf(heat, 0.62 + cook_t * 0.32 * clampf(float(p.heat_mul), 0.2, 1.0))
	heat_warp_mat.set_shader_parameter("heat", heat)
	heat_warp_mesh.visible = heat > 0.05


func _apply_heat_warp_settings(s: Dictionary) -> void:
	heat_warp_enabled = bool(s.get("heat_warp_on", true))
	if heat_warp_mat == null or heat_warp_mesh == null or not is_instance_valid(heat_warp_mesh):
		return
	var size_mul := clampf(float(s.get("heat_warp_size", 0.83)), 0.25, 1.6)
	var plane := heat_warp_mesh.mesh as PlaneMesh
	if plane != null:
		plane.size = heat_warp_base_size * size_mul
	heat_warp_mat.set_shader_parameter("time_scale", float(s.get("heat_warp_speed", 1.00)))
	heat_warp_mat.set_shader_parameter("warp_strength", float(s.get("heat_warp_strength", 0.00)))
	heat_warp_mat.set_shader_parameter("mask_tight", float(s.get("heat_warp_tight", 1.70)))
	if not heat_warp_enabled:
		heat_warp_mesh.visible = false
		heat_warp_mat.set_shader_parameter("heat", 0.0)


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
	glow.set_meta("base_alpha", gm.albedo_color.a)
	glow.set_meta("base_emission_energy_multiplier", gm.emission_energy_multiplier)
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


func _build_fire_extinguisher() -> void:
	## Mounted on the left window beam, just left of scraper / oil / seasoning.
	const SCENE_PATH := "res://assets/fire_ext/FireExt.fbx"
	const DIFF_PATH := "res://assets/fire_ext/DIFFUSE.jpg"
	const NORM_PATH := "res://assets/fire_ext/NORMAL.jpg"
	if not ResourceLoader.exists(SCENE_PATH):
		push_warning("Fire extinguisher missing: %s" % SCENE_PATH)
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return
	ext_home = Vector3(2.063, 1.72, 0.937)
	ext_root = Node3D.new()
	ext_root.name = "FireExtinguisher"
	ext_root.position = ext_home
	ext_root.rotation_degrees = ext_home_rot
	world.add_child(ext_root)
	## Unscaled root so grab volume stays world-sized; mesh stays tiny.
	visual.name = "FireExtMesh"
	visual.position = Vector3.ZERO
	visual.rotation_degrees = Vector3.ZERO
	visual.scale = Vector3(0.034, 0.034, 0.034)
	var diff: Texture2D = load(DIFF_PATH) as Texture2D if ResourceLoader.exists(DIFF_PATH) else null
	var norm: Texture2D = load(NORM_PATH) as Texture2D if ResourceLoader.exists(NORM_PATH) else null
	_apply_fire_ext_materials(visual, diff, norm)
	ext_root.add_child(visual)
	ext_visual = visual

	ext_area = Area3D.new()
	ext_area.name = "FireExtGrab"
	ext_area.input_ray_pickable = true
	ext_area.collision_layer = EXT_COLLISION_LAYER
	ext_area.collision_mask = 0
	ext_area.monitoring = true
	ext_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 0.62, 0.32)
	shape.shape = box
	shape.position = Vector3(0.0, 0.05, 0.0)
	ext_area.add_child(shape)
	ext_root.add_child(ext_area)


func _build_window_cat() -> void:
	## Peeks under the service window between customer lanes — pet or feed.
	if window_cat != null and is_instance_valid(window_cat):
		window_cat.queue_free()
		window_cat = null
	var cat: Node3D = WindowCatScript.new()
	cat.name = "WindowCat"
	world.add_child(cat)
	window_cat = cat
	## Guest sees host-driven cat (peek / run / chonk) via sync RPCs.
	if mp_enabled and not NetManager.is_host():
		cat.set("mp_puppet", true)
	if cat.has_signal("petted"):
		cat.petted.connect(_on_window_cat_petted)
	if cat.has_signal("fed"):
		cat.fed.connect(_on_window_cat_fed)


func _try_window_cat_click(screen_pos: Vector2) -> bool:
	if not playing or window_cat == null or not is_instance_valid(window_cat):
		return false
	if brush_held or oil_held or shaker_held or ext_held or glock_held or dragging_patty != null:
		return false
	if not window_cat.hit_test(camera, screen_pos):
		return false
	## Holding food → feed; empty hands → pet (arms a short topping-treat window).
	if spatula_patty != null and is_instance_valid(spatula_patty):
		if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id():
			return false
		_feed_window_cat_patty()
		return true
	if cheese_held:
		_feed_window_cat_ingredient("cheese")
		return true
	if mp_enabled and not _mp_applying:
		mp_cat_pet.rpc()
		return true
	window_cat.pet()
	return true


func _feed_window_cat_patty() -> void:
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		return
	if mp_enabled and not _mp_applying:
		var nid := int(spatula_patty.get("net_id")) if spatula_patty.get("net_id") != null else -1
		mp_cat_feed.rpc("patty", nid)
		return
	_feed_window_cat_patty_local()


func _feed_window_cat_patty_local() -> void:
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		return
	var patty = spatula_patty
	spatula_patty = null
	spatula_owner_id = 0
	spatula_from_build = false
	spatula_lmb_held = false
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	if is_instance_valid(patty):
		patty.queue_free()
	if window_cat:
		window_cat.feed("patty", true)
	_flash("Cat stole the burger! ♥", Color("FF8A80"))


func _try_feed_held_patty_to_cat(screen_pos: Vector2) -> bool:
	if spatula_patty == null or not is_instance_valid(spatula_patty):
		return false
	if _is_bun_toast(spatula_patty):
		return false
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id():
		return false
	if window_cat == null or not is_instance_valid(window_cat):
		return false
	if not window_cat.hit_test_feed(camera, screen_pos):
		return false
	_feed_window_cat_patty()
	return true


func _cat_accepts_food(id: String) -> bool:
	## Only cheese, bacon, or a scooped/full patty — no other toppings.
	return id == "cheese" or id == "bacon" or id == "patty"


func _feed_window_cat_ingredient(id: String) -> void:
	if not _cat_accepts_food(id):
		_flash("Cat only wants cheese, bacon, or a patty", Color("FFCC80"))
		return
	if mp_enabled and not _mp_applying:
		mp_cat_feed.rpc(id, -1)
		return
	_feed_window_cat_ingredient_local(id)


func _feed_window_cat_ingredient_local(id: String) -> void:
	if not _cat_accepts_food(id):
		return
	if id == "cheese" and cheese_held:
		_cancel_cheese_hold()
	if not _spend_ingredient(id):
		return
	if window_cat:
		window_cat.feed(id, true)
	var label := id.replace("_", " ")
	_flash("Cat loves the %s!" % label, Color("FFE082"))
	if game_audio:
		game_audio.play_ingredient(id)


func _held_patty_near_screen(patty: Area3D, screen_pos: Vector2, max_px: float = 78.0) -> bool:
	if patty == null or not is_instance_valid(patty) or camera == null:
		return false
	var lift: Vector3 = patty.global_position + Vector3(0, 0.04, 0)
	if camera.is_position_behind(lift):
		return false
	return screen_pos.distance_to(camera.unproject_position(lift)) <= max_px


func _try_steal_held_patty_at(screen_pos: Vector2) -> bool:
	if not mp_enabled or not playing or _mp_applying:
		return false
	if spatula_patty != null:
		return false
	var target = null
	var my_id := NetManager.my_id()
	for peer_id in mp_held_net.keys():
		if int(peer_id) == my_id:
			continue
		var p = _patty_by_net_id(int(mp_held_net[peer_id]))
		if p != null and is_instance_valid(p) and _held_patty_near_screen(p, screen_pos):
			target = p
			break
	if target == null and flicking_patty != null and is_instance_valid(flicking_patty) \
			and _held_patty_near_screen(flicking_patty, screen_pos):
		target = flicking_patty
	if target == null:
		return false
	var nid := int(target.get("net_id")) if target.get("net_id") != null else -1
	if nid < 0:
		return false
	mp_steal_held.rpc(nid)
	return true


func _on_window_cat_petted() -> void:
	if game_audio and game_audio.has_method("play_cat_purr"):
		game_audio.play_cat_purr()
	_flash("Purr… feed cheese, bacon, or a patty!", Color("CE93D8"))


func _on_window_cat_fed(kind: String) -> void:
	if game_audio and game_audio.has_method("play_cat_meow"):
		game_audio.play_cat_meow()
	if kind == "patty" and game_audio and game_audio.has_method("play_cat_purr"):
		game_audio.play_cat_purr()


func _apply_fire_ext_materials(node: Node, diff: Texture2D, norm: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.roughness = 0.42
		mat.metallic = 0.15
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		if diff != null:
			mat.albedo_texture = diff
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.75, 0.12, 0.1)
		if norm != null:
			mat.normal_enabled = true
			mat.normal_texture = norm
			mat.normal_scale = 0.85
		mi.material_override = mat
	for child in node.get_children():
		_apply_fire_ext_materials(child, diff, norm)


func _begin_fire_ext_hold() -> bool:
	if not playing or ext_held or ext_root == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or sale_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	ext_held = true
	ext_spraying = false
	ext_root.rotation_degrees = ext_held_rot
	var seat := _tool_hold_point_from_screen(get_viewport().get_mouse_position(), GRILL_SURFACE_Y + EXT_HOLD_HEIGHT)
	if seat != Vector3.ZERO:
		ext_root.global_position = seat
	if ext_area:
		ext_area.input_ray_pickable = false
	_ensure_ext_powder()
	if game_audio:
		game_audio.play_click()
	if grill_on_fire:
		_flash("Right-click to spray powder on the fire — or the customers…", Color("FF8A80"))
	else:
		_flash("Fire extinguisher — right-click sprays · aim at customers or fire · release LMB to hang up", Color("FF8A80"))
	if mp_enabled:
		_mp_send_held_tool_pose(true)
	return true


func _update_held_fire_ext(delta: float) -> void:
	if ext_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		## Keep following even when aiming high (toward the window beam).
		hit = _tool_hold_point_from_screen(mouse, GRILL_SURFACE_Y + EXT_HOLD_HEIGHT)
		if hit == Vector3.ZERO:
			return
	else:
		hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.75, GRILL_CENTER_X + GRILL_WIDTH * 1.05)
		hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.75, 1.28)
		hit.y = GRILL_SURFACE_Y + EXT_HOLD_HEIGHT
	ext_root.global_position = hit
	## Tip nozzle slightly toward the steel while spraying.
	ext_root.rotation_degrees = Vector3(-28.0, 200.0, 8.0) if ext_spraying else ext_held_rot
	if ext_spraying:
		_spray_extinguisher_powder(delta, hit)


func _release_fire_extinguisher() -> void:
	if not ext_held or ext_root == null:
		return
	ext_held = false
	ext_spraying = false
	if ext_powder:
		ext_powder.emitting = false
	if game_audio and game_audio.has_method("set_ext_spray"):
		game_audio.set_ext_spray(false)
	if ext_area:
		ext_area.input_ray_pickable = false
	_tween_tool_to_wall(
		ext_root,
		ext_home,
		ext_home_rot,
		Vector3.ONE,
		0.34,
		func() -> void:
			if ext_area != null and is_instance_valid(ext_area):
				ext_area.input_ray_pickable = true
	)
	if game_audio:
		game_audio.play_click()
	if mp_enabled:
		mp_tool_pose.rpc(5, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _reset_fire_extinguisher() -> void:
	ext_held = false
	ext_spraying = false
	if game_audio and game_audio.has_method("set_ext_spray"):
		game_audio.set_ext_spray(false)
	if ext_powder != null and is_instance_valid(ext_powder):
		ext_powder.emitting = false
	if ext_root != null and is_instance_valid(ext_root):
		ext_root.position = ext_home
		ext_root.rotation_degrees = ext_home_rot
	if ext_area != null and is_instance_valid(ext_area):
		ext_area.input_ray_pickable = true
	_clear_grill_fire()
	_clear_ext_powder_blobs()


func _build_glock() -> void:
	## Hung on the window lintel, immediately right of the FIRST SALE plaque.
	const SCENE_PATH := "res://assets/glock/Glock.fbx"
	const DIFF_PATH := "res://assets/glock/Low_Explode_Glock_Mat_BaseColor.png"
	const MET_PATH := "res://assets/glock/Low_Explode_Glock_Mat_Metallic.png"
	const NORM_PATH := "res://assets/glock/Low_Explode_Glock_Mat_Normal.png"
	const ROUGH_PATH := "res://assets/glock/Low_Explode_Glock_Mat_Roughness.png"
	const EMIS_PATH := "res://assets/glock/Low_Explode_Glock_Mat_Emissive.png"
	if glock_root != null and is_instance_valid(glock_root):
		glock_root.queue_free()
		glock_root = null
	glock_flash = null
	glock_muzzle = null
	glock_laser_beam = null
	glock_laser_dot = null
	glock_laser_module = null
	glock_rear_sight_l = null
	glock_rear_sight_r = null
	glock_visual = null
	glock_area = null
	## Drop leftover mount key / shadow plate from older builds.
	var old_key := world.get_node_or_null("GlockMountKey")
	if old_key != null and is_instance_valid(old_key):
		old_key.queue_free()
	var old_plate := world.get_node_or_null("GlockShadowPlate")
	if old_plate != null and is_instance_valid(old_plate):
		old_plate.queue_free()
	if not ResourceLoader.exists(SCENE_PATH):
		push_warning("Glock missing: %s" % SCENE_PATH)
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return
	## Tucked behind the First Sale plaque — slide the bill aside to grab it.
	glock_home = Vector3(0.0, 2.38, 1.232)
	glock_home_rot = Vector3(0.0, 270.0, 0.0)
	glock_root = Node3D.new()
	glock_root.name = "WallGlock"
	glock_root.position = glock_home
	glock_root.rotation_degrees = glock_home_rot
	world.add_child(glock_root)
	visual.name = "GlockMesh"
	## New single-gun Display mesh: barrel +Z, grip −Y — hang upright on the beam.
	visual.position = Vector3(0.0, 0.02, 0.0)
	visual.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	## Model is already ~handgun-sized (~20cm); slight upscale so it reads on the wall.
	visual.scale = Vector3.ONE * GLOCK_MESH_SCALE
	var diff: Texture2D = load(DIFF_PATH) as Texture2D if ResourceLoader.exists(DIFF_PATH) else null
	var met: Texture2D = load(MET_PATH) as Texture2D if ResourceLoader.exists(MET_PATH) else null
	var norm: Texture2D = load(NORM_PATH) as Texture2D if ResourceLoader.exists(NORM_PATH) else null
	var rough: Texture2D = load(ROUGH_PATH) as Texture2D if ResourceLoader.exists(ROUGH_PATH) else null
	var emis: Texture2D = load(EMIS_PATH) as Texture2D if ResourceLoader.exists(EMIS_PATH) else null
	_apply_glock_materials(visual, diff, met, norm, rough, emis)
	glock_root.add_child(visual)
	glock_visual = visual

	glock_area = Area3D.new()
	glock_area.name = "GlockGrab"
	glock_area.input_ray_pickable = true
	glock_area.collision_layer = GLOCK_COLLISION_LAYER
	glock_area.collision_mask = 0
	glock_area.monitoring = false
	glock_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.28, 0.32)
	shape.shape = box
	shape.position = Vector3(0.0, 0.0, 0.02)
	glock_area.add_child(shape)
	glock_root.add_child(glock_area)
	_ensure_glock_fx()


func _apply_glock_materials(node: Node, diff: Texture2D, met: Texture2D, norm: Texture2D, rough: Texture2D, emis: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		if diff != null:
			mat.albedo_texture = diff
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color(0.18, 0.18, 0.2)
		if met != null:
			mat.metallic_texture = met
			mat.metallic = 0.28 ## Polymer / phosphate — less mirror chrome.
		else:
			mat.metallic = 0.18
		## Duty matte — ignore glossy roughness map so highlights stay soft.
		mat.roughness = 0.72
		mat.metallic = minf(mat.metallic, 0.32)
		if norm != null:
			mat.normal_enabled = true
			mat.normal_texture = norm
			mat.normal_scale = 1.0
		if emis != null:
			mat.emission_enabled = true
			mat.emission_texture = emis
			mat.emission_energy_multiplier = 0.35
		mi.material_override = mat
	for child in node.get_children():
		_apply_glock_materials(child, diff, met, norm, rough, emis)


func _ensure_glock_fx() -> void:
	if glock_root == null:
		return
	if glock_flash == null or not is_instance_valid(glock_flash):
		glock_flash = OmniLight3D.new()
		glock_flash.name = "GlockMuzzleLight"
		glock_flash.light_color = Color(1.0, 0.85, 0.45)
		glock_flash.light_energy = 0.0
		glock_flash.omni_range = 1.8
		glock_flash.shadow_enabled = false
		glock_flash.position = GLOCK_MUZZLE_LOCAL
		glock_root.add_child(glock_flash)
	if glock_muzzle == null or not is_instance_valid(glock_muzzle):
		glock_muzzle = GPUParticles3D.new()
		glock_muzzle.name = "GlockMuzzleFlash"
		glock_muzzle.amount = 18
		glock_muzzle.lifetime = 0.08
		glock_muzzle.one_shot = true
		glock_muzzle.explosiveness = 1.0
		glock_muzzle.emitting = false
		glock_muzzle.position = GLOCK_MUZZLE_LOCAL
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 1)
		mat.spread = 28.0
		mat.initial_velocity_min = 1.5
		mat.initial_velocity_max = 3.2
		mat.gravity = Vector3.ZERO
		mat.scale_min = 0.02
		mat.scale_max = 0.06
		mat.color = Color(1.0, 0.75, 0.25, 1.0)
		glock_muzzle.process_material = mat
		var dm := SphereMesh.new()
		dm.radius = 0.02
		dm.height = 0.04
		glock_muzzle.draw_pass_1 = dm
		glock_root.add_child(glock_muzzle)
	_ensure_glock_laser()
	_ensure_glock_rear_sights()


func _ensure_glock_rear_sights() -> void:
	## Two glowing night-sight discs on the rear sight posts.
	if glock_root == null:
		return
	if glock_rear_sight_l == null or not is_instance_valid(glock_rear_sight_l):
		glock_rear_sight_l = _make_glock_rear_sight_disc("GlockRearSightL", -1.0)
		glock_root.add_child(glock_rear_sight_l)
	else:
		glock_rear_sight_l.position = Vector3(-GLOCK_REAR_SIGHT_X, GLOCK_REAR_SIGHT_Y, GLOCK_REAR_SIGHT_Z)
	if glock_rear_sight_r == null or not is_instance_valid(glock_rear_sight_r):
		glock_rear_sight_r = _make_glock_rear_sight_disc("GlockRearSightR", 1.0)
		glock_root.add_child(glock_rear_sight_r)
	else:
		glock_rear_sight_r.position = Vector3(GLOCK_REAR_SIGHT_X, GLOCK_REAR_SIGHT_Y, GLOCK_REAR_SIGHT_Z)


func _make_glock_rear_sight_disc(disc_name: String, side: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = disc_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = GLOCK_REAR_SIGHT_R
	cyl.bottom_radius = GLOCK_REAR_SIGHT_R
	cyl.height = 0.0022
	cyl.radial_segments = 16
	disc.mesh = cyl
	## Sit on the rear posts; face the shooter (−Z / back of the slide).
	disc.position = Vector3(side * GLOCK_REAR_SIGHT_X, GLOCK_REAR_SIGHT_Y, GLOCK_REAR_SIGHT_Z)
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 1.0, 0.4)
	mat.emission_energy_multiplier = 5.5
	mat.roughness = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.sorting_offset = 4.0
	return disc


func _ensure_glock_laser() -> void:
	if glock_root == null:
		return
	## Tiny under-barrel laser module.
	if glock_laser_module == null or not is_instance_valid(glock_laser_module):
		glock_laser_module = MeshInstance3D.new()
		glock_laser_module.name = "GlockLaserModule"
		var box := BoxMesh.new()
		box.size = Vector3(0.022, 0.018, 0.048)
		glock_laser_module.mesh = box
		glock_laser_module.position = GLOCK_LASER_LOCAL
		var mod_mat := StandardMaterial3D.new()
		mod_mat.albedo_color = Color(0.12, 0.12, 0.13)
		mod_mat.metallic = 0.7
		mod_mat.roughness = 0.35
		glock_laser_module.material_override = mod_mat
		glock_laser_module.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glock_root.add_child(glock_laser_module)
		## Red emitter lens on the front of the module.
		var lens := MeshInstance3D.new()
		var lens_mesh := SphereMesh.new()
		lens_mesh.radius = 0.006
		lens_mesh.height = 0.012
		lens.mesh = lens_mesh
		lens.position = Vector3(0.0, 0.0, 0.026)
		var lens_mat := StandardMaterial3D.new()
		lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens_mat.albedo_color = Color(1.0, 0.08, 0.05)
		lens_mat.emission_enabled = true
		lens_mat.emission = Color(1.0, 0.12, 0.05)
		lens_mat.emission_energy_multiplier = 2.4
		lens.material_override = lens_mat
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glock_laser_module.add_child(lens)
	else:
		glock_laser_module.position = GLOCK_LASER_LOCAL
	## Thin red beam along +Z from the muzzle / module.
	if glock_laser_beam == null or not is_instance_valid(glock_laser_beam):
		glock_laser_beam = MeshInstance3D.new()
		glock_laser_beam.name = "GlockLaserBeam"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0022
		cyl.bottom_radius = 0.0022
		cyl.height = 1.0
		cyl.radial_segments = 8
		glock_laser_beam.mesh = cyl
		## Cylinder is Y-up — rotate so length runs along +Z.
		glock_laser_beam.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		var beam_mat := StandardMaterial3D.new()
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(1.0, 0.05, 0.05, 0.72)
		beam_mat.emission_enabled = true
		beam_mat.emission = Color(1.0, 0.08, 0.05)
		beam_mat.emission_energy_multiplier = 3.5
		beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam_mat.disable_receive_shadows = true
		glock_laser_beam.material_override = beam_mat
		glock_laser_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glock_root.add_child(glock_laser_beam)
	## Impact dot at the end of the beam.
	if glock_laser_dot == null or not is_instance_valid(glock_laser_dot):
		glock_laser_dot = MeshInstance3D.new()
		glock_laser_dot.name = "GlockLaserDot"
		var sphere := SphereMesh.new()
		sphere.radius = 0.012
		sphere.height = 0.024
		glock_laser_dot.mesh = sphere
		var dot_mat := StandardMaterial3D.new()
		dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.95)
		dot_mat.emission_enabled = true
		dot_mat.emission = Color(1.0, 0.2, 0.1)
		dot_mat.emission_energy_multiplier = 4.5
		dot_mat.disable_receive_shadows = true
		glock_laser_dot.material_override = dot_mat
		glock_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glock_root.add_child(glock_laser_dot)
	_set_glock_laser_visible(glock_held)
	if glock_held:
		_set_glock_laser_length(2.5)


func _set_glock_laser_visible(on: bool) -> void:
	if glock_laser_module != null and is_instance_valid(glock_laser_module):
		glock_laser_module.visible = on
	if glock_laser_beam != null and is_instance_valid(glock_laser_beam):
		glock_laser_beam.visible = on
	if glock_laser_dot != null and is_instance_valid(glock_laser_dot):
		glock_laser_dot.visible = on


func _set_glock_laser_length(length: float) -> void:
	var L := clampf(length, 0.08, GLOCK_LASER_MAX)
	var start_z := GLOCK_LASER_LOCAL.z + 0.028
	var ly := GLOCK_LASER_LOCAL.y
	if glock_laser_beam != null and is_instance_valid(glock_laser_beam):
		var cyl := glock_laser_beam.mesh as CylinderMesh
		if cyl == null:
			cyl = CylinderMesh.new()
			cyl.top_radius = 0.0022
			cyl.bottom_radius = 0.0022
			cyl.radial_segments = 8
			glock_laser_beam.mesh = cyl
		cyl.height = L
		## Beam starts at module lens and extends along +Z.
		glock_laser_beam.position = Vector3(0.0, ly, start_z + L * 0.5)
	if glock_laser_dot != null and is_instance_valid(glock_laser_dot):
		glock_laser_dot.position = Vector3(0.0, ly, start_z + L)
	## Visibility is owned by hold state — never force on while hung up.
	_set_glock_laser_visible(glock_held)


func _glock_muzzle_global() -> Vector3:
	if glock_root == null or not is_instance_valid(glock_root):
		return Vector3.ZERO
	return glock_root.to_global(GLOCK_MUZZLE_LOCAL)


func _glock_sight_ray(mouse: Vector2) -> Dictionary:
	## Crosshair = camera ray; bullets/laser follow the cursor, not muzzle offset.
	if camera == null:
		return {"from": Vector3.ZERO, "dir": Vector3.FORWARD, "cam_from": Vector3.ZERO, "cam_dir": Vector3.FORWARD, "aim": Vector3.FORWARD * 12.0}
	var cam_from := camera.project_ray_origin(mouse)
	var cam_dir := camera.project_ray_normal(mouse).normalized()
	var aim := cam_from + cam_dir * GLOCK_AIM_REACH
	var muzzle := _glock_muzzle_global()
	var from := muzzle if muzzle != Vector3.ZERO else cam_from
	return {"from": from, "dir": cam_dir, "cam_from": cam_from, "cam_dir": cam_dir, "aim": aim}


func _aim_held_glock_at_mouse(mouse: Vector2) -> void:
	if glock_root == null or camera == null:
		return
	var cam_from := camera.project_ray_origin(mouse)
	var cam_dir := camera.project_ray_normal(mouse).normalized()
	var grip := cam_from + cam_dir * GLOCK_HOLD_DIST
	grip.y = maxf(GRILL_SURFACE_Y + GLOCK_HOLD_HEIGHT - GLOCK_HOLD_DROP, grip.y - GLOCK_HOLD_DROP)
	glock_root.global_position = grip
	var barrel_target := grip + cam_dir * 2.4
	if (barrel_target - grip).length_squared() > 0.0001:
		glock_root.look_at(barrel_target, Vector3.UP)
		glock_root.rotate_object_local(Vector3.UP, PI)
		glock_root.rotate_object_local(Vector3.RIGHT, deg_to_rad(-4.0))


func _update_glock_laser_aim() -> void:
	_ensure_glock_laser()
	if not glock_held or glock_root == null or camera == null:
		_set_glock_laser_visible(false)
		return
	_set_glock_laser_visible(true)
	var origin := _glock_muzzle_global()
	if origin == Vector3.ZERO:
		origin = glock_root.global_position
	var mouse := get_viewport().get_mouse_position()
	var sight := _glock_sight_ray(mouse)
	var dir: Vector3 = sight["dir"]
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * GLOCK_LASER_MAX)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = 0xFFFFFFFF & ~STREET_MATTE_COLLISION_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_set_glock_laser_length(GLOCK_LASER_MAX)
	else:
		var dist: float = origin.distance_to(hit.get("position", origin + dir))
		_set_glock_laser_length(maxf(0.12, dist))


func _begin_glock_hold() -> bool:
	if not playing or glock_held or glock_root == null:
		return false
	if _sale_covers_glock():
		_flash("Move the First Sale plaque first", Color("FFCC80"))
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or sale_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	glock_held = true
	glock_cooldown = 0.0
	glock_recoil = 0.0
	glock_aim_roll = 0.0
	glock_aim_yaw = 0.0
	glock_prev_mouse_x = get_viewport().get_mouse_position().x
	var mouse := get_viewport().get_mouse_position()
	_aim_held_glock_at_mouse(mouse)
	if glock_area:
		glock_area.input_ray_pickable = false
	_ensure_glock_fx()
	_set_glock_laser_visible(true)
	_update_glock_laser_aim()
	if game_audio:
		game_audio.play_click()
	_sync_combat_audio()
	_flash("Glock ready — right-click to shoot · laser on · release LMB to hang up", Color("FFCC80"))
	if mp_enabled:
		_mp_send_held_tool_pose(true)
	return true


func _update_held_glock(delta: float) -> void:
	if glock_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_aim_held_glock_at_mouse(mouse)
	if glock_recoil > 0.0 and glock_visual != null and is_instance_valid(glock_visual):
		glock_visual.rotation_degrees = Vector3(-glock_recoil * 11.0, 0.0, 0.0)
		glock_visual.scale = Vector3.ONE * (GLOCK_MESH_SCALE * 1.05)
	elif glock_visual != null and is_instance_valid(glock_visual):
		glock_visual.rotation_degrees = Vector3.ZERO
		glock_visual.scale = Vector3.ONE * (GLOCK_MESH_SCALE * 1.05)
	if glock_flash != null and is_instance_valid(glock_flash):
		glock_flash.light_energy = maxf(0.0, glock_flash.light_energy - delta * 28.0)
		glock_flash.position = GLOCK_MUZZLE_LOCAL
	if glock_muzzle != null and is_instance_valid(glock_muzzle):
		glock_muzzle.position = GLOCK_MUZZLE_LOCAL
	_update_glock_laser_aim()


func _fire_glock() -> void:
	if not glock_held or glock_root == null or camera == null:
		return
	if glock_cooldown > 0.0:
		return
	var mouse := get_viewport().get_mouse_position()
	var sight := _glock_sight_ray(mouse)
	var from: Vector3 = sight["from"]
	var dir: Vector3 = sight["dir"]
	var cam_from: Vector3 = sight["cam_from"]
	var cam_dir: Vector3 = sight["cam_dir"]
	var impact := Vector3.ZERO
	var cust_id := -1
	var hostile := false
	## Cat bolt?
	if window_cat != null and is_instance_valid(window_cat) and window_cat.is_interactable():
		var head: Vector3 = window_cat.head_global()
		var to_cat := head - cam_from
		var along := cam_dir.dot(to_cat)
		if along > 0.4:
			var closest := cam_from + cam_dir * along
			if closest.distance_to(head) < 0.55:
				impact = head
				cust_id = -2
				if mp_enabled and not _mp_applying:
					mp_glock_fire.rpc(impact.x, impact.y, impact.z, cust_id, true, false)
					return
				_apply_glock_shot(impact, cust_id, true, false, from, dir)
				return
	var shot_cust := _find_customer_under_gun_aim(cam_from, cam_dir, mouse)
	if shot_cust != null:
		impact = shot_cust.global_position + Vector3(0.0, 0.85, 0.0)
		cust_id = _customer_net_id(shot_cust)
		hostile = bool(shot_cust.get("is_terrorist"))
		if mp_enabled and not _mp_applying:
			## Co-op needs a net id; solo passes the node below.
			if cust_id < 0:
				_apply_glock_shot(impact, -1, true, hostile, from, dir, shot_cust)
				return
			mp_glock_fire.rpc(impact.x, impact.y, impact.z, cust_id, true, hostile)
			return
		_apply_glock_shot(impact, cust_id, true, hostile, from, dir, shot_cust)
		return
	var q := PhysicsRayQueryParameters3D.create(cam_from, cam_from + cam_dir * 45.0)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = 0xFFFFFFFF & ~STREET_MATTE_COLLISION_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		impact = hit.get("position", Vector3.ZERO)
	else:
		impact = cam_from + cam_dir * 8.0
	if mp_enabled and not _mp_applying:
		mp_glock_fire.rpc(impact.x, impact.y, impact.z, -1, false, false)
		return
	_apply_glock_shot(impact, -1, false, false, from, dir)


func _apply_glock_shot(
	impact: Vector3,
	cust_id: int,
	do_hit: bool,
	hostile: bool,
	from: Vector3 = Vector3.ZERO,
	dir: Vector3 = Vector3.FORWARD,
	hit_customer: Node3D = null
) -> void:
	glock_cooldown = GLOCK_FIRE_COOLDOWN
	glock_recoil = 1.0
	_ensure_glock_fx()
	if glock_muzzle != null:
		glock_muzzle.restart()
		glock_muzzle.emitting = true
	if glock_flash != null:
		glock_flash.light_energy = 6.5
	if game_audio and game_audio.has_method("play_gunshot"):
		game_audio.play_gunshot()
	if cust_id == -2:
		if window_cat != null and is_instance_valid(window_cat):
			window_cat.reset_shift()
		_flash("Cat bolted!", Color("CE93D8"))
		if game_audio and game_audio.has_method("play_cat_meow"):
			game_audio.play_cat_meow()
		return
	_spawn_glock_impact(impact)
	if not do_hit:
		return
	## Solo has no customer net ids — use the aimed node when provided.
	var shot_cust = hit_customer
	if shot_cust == null and cust_id >= 0:
		shot_cust = _customer_by_net_id(cust_id)
	if shot_cust == null or not is_instance_valid(shot_cust) or not shot_cust.has_method("get_shot"):
		return
	var shot_from := from if from != Vector3.ZERO else impact + Vector3(0, 0, 0.5)
	var shot_dir := dir if dir.length_squared() > 0.0001 else Vector3(0, 0, -1)
	var first_hit: bool = bool(shot_cust.get_shot(shot_from, shot_dir))
	if first_hit and game_audio and game_audio.has_method("play_wilhelm_scream"):
		game_audio.play_wilhelm_scream(not hostile)
	if not first_hit:
		return
	## Host resolves leave / bounty so money stays shared.
	if mp_enabled and not NetManager.is_host():
		return
	if hostile:
		money += TERRORIST_KILL_BOUNTY
		_flash("Hostile down! +%s" % _format_money(TERRORIST_KILL_BOUNTY), Color("A5D6A7"))
		_on_customer_left(shot_cust, false)
		_check_terrorist_wave_end()
	else:
		_flash("Wilhelm!", Color("EF5350"))
		_on_customer_left(shot_cust, true)


func _find_customer_under_gun_aim(from: Vector3, dir: Vector3, mouse: Vector2) -> Node3D:
	## Crosshair ray first — screen proximity breaks ties for distant hostiles.
	if customers_root == null or camera == null:
		return null
	var best: Node3D = null
	var best_score := 9999.0
	for c in customers_root.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("get_shot"):
			continue
		var torso: Vector3 = c.global_position + Vector3(0.0, 0.85, 0.0)
		var head: Vector3 = c.global_position + Vector3(0.0, 1.15, 0.0)
		if c.has_method("mouth_global"):
			head = c.mouth_global()
		if camera.is_position_behind(torso):
			continue
		var screen_d := mini(
			mouse.distance_to(camera.unproject_position(torso)),
			mouse.distance_to(camera.unproject_position(head))
		)
		var to_torso := torso - from
		var along := dir.dot(to_torso)
		if along < 0.08:
			continue
		var closest := from + dir * along
		var ray_d := mini(closest.distance_to(torso), closest.distance_to(head))
		var is_hostile: bool = bool(c.get("is_terrorist"))
		var screen_limit := 190.0 if is_hostile else 150.0
		var ray_limit := 1.35 if is_hostile else 1.05
		if screen_d < screen_limit and ray_d < ray_limit:
			var score := screen_d + ray_d * 18.0
			if score < best_score:
				best_score = score
				best = c
	return best


func _spawn_glock_impact(pos: Vector3) -> void:
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.9, 0.5)
	spark.light_energy = 2.2
	spark.omni_range = 0.55
	spark.shadow_enabled = false
	spark.position = pos
	world.add_child(spark)
	var tw := create_tween()
	tw.tween_property(spark, "light_energy", 0.0, 0.12)
	tw.tween_callback(spark.queue_free)


func _release_glock() -> void:
	if not glock_held or glock_root == null:
		return
	glock_held = false
	glock_recoil = 0.0
	glock_aim_roll = 0.0
	glock_aim_yaw = 0.0
	glock_prev_mouse_x = -1.0
	if glock_flash != null and is_instance_valid(glock_flash):
		glock_flash.light_energy = 0.0
	if glock_muzzle != null and is_instance_valid(glock_muzzle):
		glock_muzzle.emitting = false
	if glock_visual != null and is_instance_valid(glock_visual):
		glock_visual.rotation_degrees = Vector3.ZERO
		glock_visual.scale = Vector3.ONE * GLOCK_MESH_SCALE
	_set_glock_laser_visible(false)
	if glock_area:
		glock_area.input_ray_pickable = false
	_tween_tool_to_wall(
		glock_root,
		glock_home,
		glock_home_rot,
		Vector3.ONE,
		0.34,
		func() -> void:
			_refresh_glock_cover_lock()
	)
	if game_audio:
		game_audio.play_click()
	_sync_combat_audio()
	if mp_enabled:
		mp_tool_pose.rpc(6, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _reset_glock() -> void:
	glock_held = false
	glock_cooldown = 0.0
	glock_recoil = 0.0
	glock_aim_roll = 0.0
	glock_aim_yaw = 0.0
	glock_prev_mouse_x = -1.0
	if glock_flash != null and is_instance_valid(glock_flash):
		glock_flash.light_energy = 0.0
	if glock_muzzle != null and is_instance_valid(glock_muzzle):
		glock_muzzle.emitting = false
	if glock_visual != null and is_instance_valid(glock_visual):
		glock_visual.rotation_degrees = Vector3.ZERO
		glock_visual.scale = Vector3.ONE * GLOCK_MESH_SCALE
	if glock_root != null and is_instance_valid(glock_root):
		glock_root.position = glock_home
		glock_root.rotation_degrees = glock_home_rot
	_set_glock_laser_visible(false)
	_refresh_glock_cover_lock()
	_sync_combat_audio()


func _build_wire_brush() -> void:
	## Paint scraper hanging with oil + seasoning on the far-left window beam.
	brush_home = Vector3(1.866, 1.99, 1.12)
	brush_root = Node3D.new()
	brush_root.name = "PaintScraper"
	brush_root.position = brush_home
	## Handle tips up into the lintel; blade hangs into the window opening.
	brush_home_rot = Vector3(-8.0, 18.0, 6.0)
	brush_root.rotation_degrees = brush_home_rot
	brush_root.scale = Vector3(1.55, 1.55, 1.55)
	world.add_child(brush_root)

	brush_area = Area3D.new()
	brush_area.input_ray_pickable = true
	brush_area.collision_layer = 8
	brush_area.collision_mask = 0
	brush_area.monitoring = true
	brush_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Grab volume around handle + blade — generous so hanging tools stay clickable.
	box.size = Vector3(0.34, 0.62, 0.36)
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
	## Rotated 180° around the handle (local Y) so the scrape edge faces the cook surface.
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.0028, 0.09)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, -0.048, -0.012)
	blade.rotation_degrees = Vector3(6.0, 180.0, 0.0)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.78, 0.8, 0.84)
	blade_mat.metallic = 1.0
	blade_mat.roughness = 0.22
	blade.material_override = blade_mat
	brush_root.add_child(blade)

	## Beveled leading edge — toward cook space after the 180° flip.
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.118, 0.0016, 0.02)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, -0.051, -0.058)
	tip.rotation_degrees = Vector3(14.0, 180.0, 0.0)
	tip.material_override = blade_mat
	brush_root.add_child(tip)

	## Blade shoulder where it meets the neck
	var shoulder := MeshInstance3D.new()
	var smesh := BoxMesh.new()
	smesh.size = Vector3(0.055, 0.008, 0.03)
	shoulder.mesh = smesh
	shoulder.position = Vector3(0, -0.01, 0.012)
	shoulder.rotation_degrees.y = 180.0
	shoulder.material_override = metal
	brush_root.add_child(shoulder)


func _build_season_shaker() -> void:
	## Seasoning hanging next to the oil bottle on the far-left window beam.
	shaker_home = Vector3(1.526, 2.14, 1.12)
	shaker_root = Node3D.new()
	shaker_root.name = "SeasonShaker"
	shaker_root.position = shaker_home
	shaker_root.rotation_degrees = Vector3(4.0, -10.0, 2.0)
	shaker_root.scale = Vector3(2.15, 2.15, 2.15)
	world.add_child(shaker_root)

	shaker_area = Area3D.new()
	shaker_area.input_ray_pickable = true
	shaker_area.collision_layer = 32
	shaker_area.collision_mask = 0
	shaker_area.monitoring = true
	shaker_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Roomier than the mesh so hanging tools stay easy to click.
	box.size = Vector3(0.12, 0.2, 0.12)
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
	shaker_particles.name = "SeasonParticles"
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
	## World-space gravity — pull seasoning down onto the patty.
	pmat.gravity = Vector3(0, -6.5, 0)
	pmat.damping_min = 0.5
	pmat.damping_max = 1.2
	pmat.scale_min = 0.22
	pmat.scale_max = 0.55
	pmat.color = Color(0.18, 0.12, 0.08, 0.9)
	shaker_particles.process_material = pmat
	var pmesh := BoxMesh.new()
	pmesh.size = Vector3(0.0055, 0.0035, 0.0045)
	var pdraw := StandardMaterial3D.new()
	pdraw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pdraw.albedo_color = Color(0.16, 0.1, 0.06, 0.85)
	pdraw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaker_particles.draw_pass_1 = pmesh
	shaker_particles.material_override = pdraw
	shaker_root.add_child(shaker_particles)


func _tool_hold_point_from_screen(screen_pos: Vector2, hold_y: float) -> Vector3:
	## Cursor → world point at a hold height. Works even when aiming high at the window tools
	## (grill-plane rays miss upward and left tools frozen until you drag down).
	if camera == null:
		return Vector3.ZERO
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit := Vector3.ZERO
	if absf(dir.y) > 0.002:
		var t := (hold_y - from.y) / dir.y
		if t > 0.05:
			hit = from + dir * t
	if hit == Vector3.ZERO:
		## Upward / grazing aim — park along the ray in front of the cook.
		hit = from + dir * 2.4
		hit.y = hold_y
	## Soft work volume covering grill + window beam.
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.85, GRILL_CENTER_X + GRILL_WIDTH * 0.95)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.85, 1.25)
	hit.y = hold_y
	return hit


func _try_grab_nearest_tool(screen_pos: Vector2) -> bool:
	if _ui_blocks_world_click(screen_pos):
		return false
	## Prefer the nearest hanging tool by screen distance, then ray as fallback.
	var best := ""
	var best_d := 110.0
	## First Sale plaque first — covers the Glock until you slide it aside.
	if first_sale_decal != null and camera != null and not sale_held:
		var sd_sale := screen_pos.distance_to(camera.unproject_position(first_sale_decal.global_position))
		if sd_sale < best_d:
			best_d = sd_sale
			best = "sale"
	if shaker_root != null and camera != null and not shaker_held:
		var sd := screen_pos.distance_to(camera.unproject_position(shaker_root.global_position + Vector3(0, 0.05, 0)))
		if sd < best_d:
			best_d = sd
			best = "shaker"
	if brush_root != null and camera != null and not brush_held and not brush_throwing:
		var tip := brush_root.global_position + brush_root.basis * Vector3(0, 0.12, 0)
		var bd := screen_pos.distance_to(camera.unproject_position(tip))
		if bd < best_d:
			best_d = bd
			best = "brush"
	## Allow grabbing scraper while it's flying home.
	if brush_root != null and camera != null and not brush_held and brush_throwing:
		var tip2 := brush_root.global_position + brush_root.basis * Vector3(0, 0.12, 0)
		var bd2 := screen_pos.distance_to(camera.unproject_position(tip2))
		if bd2 < best_d:
			best_d = bd2
			best = "brush"
	if oil_root != null and camera != null and not oil_held:
		var od := screen_pos.distance_to(camera.unproject_position(oil_root.global_position + Vector3(0, 0.06, 0)))
		if od < best_d:
			best_d = od
			best = "oil"
	if ext_root != null and camera != null and not ext_held:
		var ed := screen_pos.distance_to(camera.unproject_position(ext_root.global_position + Vector3(0, 0.12, 0)))
		if ed < best_d:
			best_d = ed
			best = "ext"
	if glock_root != null and camera != null and not glock_held and not _sale_covers_glock():
		var gd := screen_pos.distance_to(camera.unproject_position(glock_root.global_position + Vector3(0, 0.05, 0)))
		if gd < best_d:
			best_d = gd
			best = "glock"
	if cup_root != null and camera != null and not cup_held:
		var cd := screen_pos.distance_to(camera.unproject_position(cup_root.global_position + Vector3(0, 0.04, 0)))
		if cd < best_d:
			best_d = cd
			best = "cup"
	if best == "" or best_d > 96.0:
		if _ray_hits_tool(screen_pos, SALE_COLLISION_LAYER, sale_area):
			best = "sale"
		elif _ray_hits_tool(screen_pos, 32, shaker_area):
			best = "shaker"
		elif _ray_hits_tool(screen_pos, 8, brush_area):
			best = "brush"
		elif _ray_hits_tool(screen_pos, 16, oil_area):
			best = "oil"
		elif _ray_hits_tool(screen_pos, EXT_COLLISION_LAYER, ext_area):
			best = "ext"
		elif not _sale_covers_glock() and _ray_hits_tool(screen_pos, GLOCK_COLLISION_LAYER, glock_area):
			best = "glock"
		elif _ray_hits_tool(screen_pos, CUP_COLLISION_LAYER, cup_area):
			best = "cup"
		else:
			return false
	match best:
		"sale":
			return _begin_sale_hold()
		"shaker":
			_begin_shaker_hold()
			return shaker_held
		"oil":
			return _begin_oil_hold()
		"brush":
			return _try_grab_brush(screen_pos)
		"ext":
			return _begin_fire_ext_hold()
		"glock":
			return _begin_glock_hold()
		"cup":
			return _begin_cup_hold()
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
	if spatula_patty != null or brush_held or cheese_held or oil_held or ext_held or glock_held or dragging_patty != null:
		return false
	var tip := shaker_root.global_position + Vector3(0, 0.05, 0)
	var near := screen_pos.distance_to(camera.unproject_position(tip)) <= 58.0
	if not near and not _ray_hits_tool(screen_pos, 32, shaker_area):
		return false
	_begin_shaker_hold()
	return shaker_held


func _begin_shaker_hold() -> void:
	if not playing:
		return
	if brush_held or oil_held or cheese_held or ext_held or glock_held or spatula_patty != null or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return
	if shaker_held:
		return
	shaker_held = true
	if shaker_root:
		shaker_root.visible = true
		shaker_root.scale = Vector3(2.15, 2.15, 2.15)
		shaker_root.rotation_degrees = Vector3(180.0, 25.0, 0.0)
		## Instant snap under cursor — no wait for next grill-plane hit.
		var seat := _tool_hold_point_from_screen(get_viewport().get_mouse_position(), GRILL_SURFACE_Y + SHAKER_POUR_HEIGHT)
		if seat != Vector3.ZERO:
			shaker_root.global_position = seat
	if shaker_area:
		shaker_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_spend(COST_SEASON_USE)
	_flash("Hold over beef to season — release to put back", Color("FFE082"))
	if mp_enabled:
		_mp_send_held_tool_pose(true)


func _cancel_shaker_hold() -> void:
	shaker_held = false
	if game_audio:
		game_audio.set_shaker_rattle(false)
	if shaker_particles:
		shaker_particles.emitting = false
	if shaker_root:
		shaker_root.visible = true
		if shaker_area:
			shaker_area.input_ray_pickable = false
		_tween_tool_to_wall(
			shaker_root,
			shaker_home,
			Vector3(6.0, 25.0, -4.0),
			Vector3(2.15, 2.15, 2.15),
			0.3,
			func() -> void:
				if shaker_area != null and is_instance_valid(shaker_area):
					shaker_area.input_ray_pickable = true
		)
	if mp_enabled:
		mp_tool_pose.rpc(4, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _cancel_shaker_hold_silent() -> void:
	shaker_held = false
	if game_audio:
		game_audio.set_shaker_rattle(false)
	if shaker_particles:
		shaker_particles.emitting = false
	if shaker_root:
		shaker_root.position = shaker_home
		shaker_root.rotation_degrees = Vector3(6.0, 25.0, -4.0)
		shaker_root.scale = Vector3(2.15, 2.15, 2.15)
		shaker_root.visible = true
	if shaker_area:
		shaker_area.input_ray_pickable = true
	if mp_enabled:
		mp_tool_pose.rpc(4, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _update_held_shaker(_delta: float) -> void:
	if shaker_root == null or camera == null:
		return
	shaker_season_cool = maxf(0.0, shaker_season_cool - _delta)
	var mouse := get_viewport().get_mouse_position()
	## Drag like before: track the grill plane. Pickup snap still uses _tool_hold_point.
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		return
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.5 + 0.05, GRILL_CENTER_X + GRILL_WIDTH * 0.5 - 0.05)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5 + 0.05, GRILL_SURFACE_Z + GRILL_DEPTH * 0.5 - 0.05)
	hit.y = GRILL_SURFACE_Y + SHAKER_POUR_HEIGHT
	shaker_root.global_position = hit
	shaker_root.rotation_degrees = Vector3(180.0, 25.0, 0.0)
	var target = _nearest_patty_near(Vector3(hit.x, GRILL_SURFACE_Y, hit.z), 0.22)
	var over_beef: bool = target != null
	if shaker_particles:
		shaker_particles.emitting = over_beef
	if game_audio:
		game_audio.set_shaker_rattle(over_beef)
	if over_beef and shaker_season_cool <= 0.0:
		shaker_season_cool = 0.05
		if mp_enabled and not _mp_applying and int(target.get("net_id")) >= 0:
			if _mp_season_sync_cool <= 0.0:
				_mp_season_sync_cool = 0.05
				mp_season_patty.rpc(int(target.net_id), 0.1)
		else:
			target.apply_seasoning(0.1)


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


func _update_held_oil(delta: float) -> void:
	if oil_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	## Drag like before: track the grill plane so back/forth feels free again.
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		return
	hit.x = clampf(hit.x, GRILL_CENTER_X - GRILL_WIDTH * 0.5 + 0.04, GRILL_CENTER_X + GRILL_WIDTH * 0.5 - 0.04)
	hit.z = clampf(hit.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.5 + 0.04, GRILL_SURFACE_Z + GRILL_DEPTH * 0.5 - 0.04)
	oil_root.global_position = Vector3(hit.x, GRILL_SURFACE_Y + OIL_POUR_HEIGHT, hit.z)
	oil_root.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	if oil_particles:
		oil_particles.emitting = true
		oil_particles.position = Vector3(0, 0.12, 0)
	## Holding grease down on a lit grill too long → grease fire.
	oil_pour_hold_t += delta
	if grill_on and not grill_on_fire and oil_pour_hold_t >= OIL_POUR_FIRE_SEC:
		_flash("Grease held too long on a hot grill!", Color("FF5252"))
		_start_grill_fire(hit)
		return
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
	## Local puddle first (responsive pour), then tell the partner.
	_spawn_oil_slick_local(pos, radius)
	if mp_enabled and not _mp_applying:
		## Keep grease trails visible on both cooks — light throttle only.
		if _mp_oil_sync_cool <= 0.0:
			_mp_oil_sync_cool = 0.03
			mp_oil_slick.rpc(pos.x, pos.z, radius)


func _spawn_oil_slick_local(pos: Vector3, radius: float = 0.04) -> void:
	var slick := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var rad := radius * (0.9 + randf() * 0.25)
	## Round soft puddle — never a stretched rectangle.
	plane.size = Vector2(rad * 2.15, rad * 2.15)
	slick.mesh = plane
	## Sit on the steel above the shine band — high enough to avoid grill z-fight.
	slick.position = Vector3(pos.x, GRILL_SURFACE_Y + OIL_SIT_Y, pos.z)
	slick.rotation_degrees = Vector3(0.0, randf() * 360.0, 0.0)
	slick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Draw above grill shine (prio 2); smoke still sits higher (12).
	slick.sorting_offset = 3.0
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
	## Above shine (2), under heat glow (6) / oil smoke (12).
	mat.render_priority = 4
	slick.material_override = mat
	grill_root.add_child(slick)
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
	## Hot steel + fresh oil → loud fry, then a soft fade-out.
	if grill_on and game_audio and game_audio.has_method("trigger_hot_oil"):
		game_audio.trigger_hot_oil(3.0)
	_check_oil_fire_risk()


func _check_oil_fire_risk() -> void:
	if grill_on_fire:
		return
	## Cold grill can't ignite grease — puddles are fine until the burner is on.
	if not grill_on:
		return
	## Puddle count only warns — fire requires holding the pour for OIL_POUR_FIRE_SEC.
	var n := oil_slicks.size()
	if n >= OIL_FIRE_WARN_COUNT and not _oil_fire_warned:
		_oil_fire_warned = true
		_flash("Lots of oil — keep pouring and it'll catch!", Color("FF8A65"))


func _pick_fire_start_zone(hint: Vector3 = Vector3.ZERO) -> Dictionary:
	## Prefer the band under the pour tip / densest oil — fire stays in that section only.
	if hint != Vector3.ZERO:
		var zh := _grill_zone_at(hint)
		if not zh.is_empty():
			return zh
	if oil_last_draw != Vector3.ZERO:
		var zl := _grill_zone_at(oil_last_draw)
		if not zl.is_empty():
			return zl
	var tallies: Dictionary = {} ## id -> count
	var samples: Dictionary = {} ## id -> zone dict
	for item in oil_slicks:
		var m = item.get("mesh")
		if m == null or not is_instance_valid(m):
			continue
		var z := _grill_zone_at(m.position)
		if z.is_empty():
			continue
		var id := str(z.get("id", ""))
		tallies[id] = int(tallies.get(id, 0)) + 1
		samples[id] = z
	var best_id := ""
	var best_n := -1
	for id in tallies.keys():
		var c := int(tallies[id])
		if c > best_n:
			best_n = c
			best_id = str(id)
	if best_id != "" and samples.has(best_id):
		return samples[best_id]
	## Fallback: FULL heat band.
	for z2 in _grill_zone_bands():
		if str(z2.get("id", "")) == "full":
			return z2
	return {}


func _fire_zone_dict() -> Dictionary:
	if fire_zone_id == "":
		return {}
	for z in _grill_zone_bands():
		if str(z.get("id", "")) == fire_zone_id:
			return z
	return {}


func _is_in_fire_zone(world_pos: Vector3) -> bool:
	var z := _fire_zone_dict()
	if z.is_empty():
		return grill_on_fire
	return world_pos.x >= float(z["x0"]) - 0.01 and world_pos.x <= float(z["x1"]) + 0.01 \
		and absf(world_pos.z - GRILL_SURFACE_Z) <= GRILL_DEPTH * 0.55


func _start_grill_fire(origin: Vector3 = Vector3.ZERO) -> void:
	if grill_on_fire:
		return
	## Never flash over on a cold flat-top.
	if not grill_on:
		return
	if mp_enabled and not _mp_applying:
		mp_grill_fire_start.rpc(origin.x, origin.z)
		return
	_start_grill_fire_local(origin)


func _start_grill_fire_local(origin: Vector3 = Vector3.ZERO) -> void:
	if grill_on_fire:
		return
	if not grill_on:
		return
	grill_on_fire = true
	fire_health = 1.0
	_oil_fire_warned = true
	_fire_killed_by_powder = false
	oil_pour_hold_t = 0.0
	var zone := _pick_fire_start_zone(origin)
	fire_zone_id = str(zone.get("id", "full"))
	## Drop the oil bottle so they can grab the extinguisher.
	if oil_held:
		_release_oil_bottle()
	_ensure_grill_fire_fx()
	_sync_fire_to_oil_area()
	_set_fire_fx_emitting(true)
	## Char only patties sitting in the burning section.
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p):
			continue
		if not _is_in_fire_zone(p.position):
			continue
		p.cook_time = maxf(float(p.cook_time), 40.0)
		p.heating = true
		p.heat_mul = 1.4
	if game_audio:
		game_audio.play_error()
	var lab := str(zone.get("label", "grill"))
	_flash("GREASE FIRE on %s! Grab the extinguisher!" % lab, Color("FF5252"))


func _oil_fire_bounds() -> Dictionary:
	## Fire lives only inside the heat band where it started.
	var zone := _fire_zone_dict()
	if zone.is_empty():
		zone = _pick_fire_start_zone()
		fire_zone_id = str(zone.get("id", "full"))
	var x0 := float(zone.get("x0", GRILL_CENTER_X - 0.3))
	var x1 := float(zone.get("x1", GRILL_CENTER_X + 0.3))
	var zw := maxf(0.18, float(zone.get("w", 0.4)))
	var cx := float(zone.get("cx", (x0 + x1) * 0.5))
	var sum_z := 0.0
	var n := 0
	for item in oil_slicks:
		var m = item.get("mesh")
		if m == null or not is_instance_valid(m):
			continue
		var p: Vector3 = m.position
		if p.x < x0 - 0.02 or p.x > x1 + 0.02:
			continue
		sum_z += p.z
		n += 1
	var cz := GRILL_SURFACE_Z
	if n > 0:
		cz = sum_z / float(n)
	cz = clampf(cz, GRILL_SURFACE_Z - GRILL_DEPTH * 0.35, GRILL_SURFACE_Z + GRILL_DEPTH * 0.35)
	var center := Vector3(cx, GRILL_SURFACE_Y + 0.05, cz)
	## Tight box — one section only, not the whole flat-top.
	var half := Vector3(
		clampf(zw * 0.42, 0.14, zw * 0.48),
		0.02,
		clampf(GRILL_DEPTH * 0.38, 0.16, GRILL_DEPTH * 0.42)
	)
	return {"center": center, "half": half}


func _sync_fire_to_oil_area() -> void:
	if fire_root == null or not is_instance_valid(fire_root):
		return
	var b := _oil_fire_bounds()
	var center: Vector3 = b["center"]
	var half: Vector3 = b["half"]
	## Fire lives in grill_root local space — slick positions are already local.
	fire_root.position = center
	for sys in [fire_particles, fire_particles_red, fire_embers]:
		if sys == null or not is_instance_valid(sys):
			continue
		var pmat := sys.process_material as ParticleProcessMaterial
		if pmat == null:
			continue
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pmat.emission_box_extents = half
	if fire_smoke != null and is_instance_valid(fire_smoke):
		var sm := fire_smoke.process_material as ParticleProcessMaterial
		if sm != null:
			sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			sm.emission_box_extents = Vector3(half.x * 0.85, 0.02, half.z * 0.85)
	## Tight, dim omnis — push falloff hard so only that section glows.
	if fire_light != null and is_instance_valid(fire_light):
		fire_light.position = Vector3(0.0, 0.14, 0.0)
		fire_light.omni_range = clampf(0.55 + half.x * 0.35, 0.55, 0.95)
		fire_light.omni_attenuation = 3.4
	if fire_light_rim != null and is_instance_valid(fire_light_rim):
		fire_light_rim.position = Vector3(0.0, 0.08, 0.0)
		fire_light_rim.omni_range = clampf(0.4 + half.x * 0.25, 0.4, 0.7)
		fire_light_rim.omni_attenuation = 3.8


func _set_fire_fx_emitting(on: bool) -> void:
	for sys in [fire_particles, fire_particles_red, fire_embers, fire_smoke]:
		if sys != null and is_instance_valid(sys):
			sys.emitting = on
	if fire_light != null and is_instance_valid(fire_light):
		fire_light.visible = on
		## ~10% of the old core glow.
		fire_light.light_energy = FIRE_LIGHT_CORE_SET if on else 0.0
	if fire_light_rim != null and is_instance_valid(fire_light_rim):
		fire_light_rim.visible = on
		fire_light_rim.light_energy = FIRE_LIGHT_RIM_SET if on else 0.0


func _ensure_grill_fire_fx() -> void:
	if fire_root != null and is_instance_valid(fire_root):
		return
	fire_root = Node3D.new()
	fire_root.name = "GreaseFire"
	fire_root.position = Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y + 0.05, GRILL_SURFACE_Z)
	grill_root.add_child(fire_root)

	## Soft core light — toned way down so particles read, not a room flood.
	fire_light = OmniLight3D.new()
	fire_light.name = "FireCoreLight"
	fire_light.light_color = Color(1.0, 0.35, 0.08)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 1.6
	fire_light.omni_attenuation = 2.2
	fire_light.shadow_enabled = false
	fire_light.position = Vector3(0, 0.18, 0)
	fire_light.visible = false
	fire_root.add_child(fire_light)

	fire_light_rim = OmniLight3D.new()
	fire_light_rim.name = "FireRimLight"
	fire_light_rim.light_color = Color(0.95, 0.18, 0.04)
	fire_light_rim.light_energy = 0.0
	fire_light_rim.omni_range = 1.1
	fire_light_rim.omni_attenuation = 2.6
	fire_light_rim.shadow_enabled = false
	fire_light_rim.position = Vector3(0, 0.1, 0)
	fire_light_rim.visible = false
	fire_root.add_child(fire_light_rim)

	## Fewer, chunkier flame triangles.
	fire_particles = _make_fire_flame_particles("Flames", 28, 0.6, Vector2(0.055, 0.11), 0.4, 1.05, false)
	fire_root.add_child(fire_particles)

	## Extra red triangle shards mixed into the blaze.
	fire_particles_red = _make_fire_flame_particles("FlamesRed", 14, 0.55, Vector2(0.048, 0.098), 0.32, 0.9, true)
	fire_root.add_child(fire_particles_red)

	fire_embers = _make_fire_ember_particles()
	fire_root.add_child(fire_embers)

	fire_smoke = _make_fire_smoke_particles()
	fire_root.add_child(fire_smoke)


func _make_fire_triangle_mesh(w: float, h: float) -> ArrayMesh:
	## Pointy flame shard — tip up, base down (not square quads).
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array([
		Vector3(0.0, h * 0.5, 0.0), ## tip
		Vector3(-w * 0.5, -h * 0.5, 0.0),
		Vector3(w * 0.5, -h * 0.5, 0.0),
	])
	var norms := PackedVector3Array([
		Vector3(0, 0, 1),
		Vector3(0, 0, 1),
		Vector3(0, 0, 1),
	])
	var uvs := PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	])
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_fire_flame_particles(p_name: String, amount: int, life: float, tri_size: Vector2, vel_min: float, vel_max: float, redder: bool = false) -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.name = p_name
	fx.amount = amount
	fx.lifetime = life
	fx.explosiveness = 0.02
	fx.randomness = 0.85
	fx.emitting = false
	fx.position = Vector3(0, 0.01, 0)
	fx.visibility_aabb = AABB(Vector3(-2.0, -0.2, -1.2), Vector3(4.0, 3.0, 2.4))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.28, 0.015, 0.18)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 14.0 if not redder else 18.0
	pmat.initial_velocity_min = vel_min
	pmat.initial_velocity_max = vel_max
	pmat.gravity = Vector3(0, 1.9, 0)
	pmat.damping_min = 0.5
	pmat.damping_max = 1.2
	pmat.scale_min = 0.85 if not redder else 0.75
	pmat.scale_max = 1.65 if not redder else 1.45
	pmat.color = Color(1.0, 0.22, 0.05, 1.0) if redder else Color(1.0, 0.42, 0.08, 1.0)
	var grad := Gradient.new()
	if redder:
		grad.offsets = PackedFloat32Array([0.0, 0.12, 0.4, 0.72, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.35, 0.12, 0.0),
			Color(1.0, 0.18, 0.05, 0.95), ## deep red
			Color(0.92, 0.08, 0.02, 0.8),
			Color(0.55, 0.02, 0.01, 0.4),
			Color(0.12, 0.0, 0.0, 0.0),
		])
	else:
		grad.offsets = PackedFloat32Array([0.0, 0.1, 0.35, 0.7, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.7, 0.25, 0.0),
			Color(1.0, 0.45, 0.08, 0.95),
			Color(1.0, 0.22, 0.04, 0.8), ## more red in the mid flame
			Color(0.85, 0.1, 0.02, 0.4),
			Color(0.18, 0.02, 0.0, 0.0),
		])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	pmat.color_ramp = gtex
	fx.process_material = pmat
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw.albedo_color = Color(1.0, 0.16, 0.04, 0.92) if redder else Color(1.0, 0.4, 0.08, 0.9)
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.disable_receive_shadows = true
	fx.draw_pass_1 = _make_fire_triangle_mesh(tri_size.x, tri_size.y)
	fx.material_override = draw
	return fx


func _make_fire_ember_particles() -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.name = "Embers"
	fx.amount = 14
	fx.lifetime = 0.75
	fx.explosiveness = 0.0
	fx.randomness = 1.0
	fx.emitting = false
	fx.position = Vector3(0, 0.03, 0)
	fx.visibility_aabb = AABB(Vector3(-2.0, -0.2, -1.2), Vector3(4.0, 3.5, 2.4))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.24, 0.015, 0.16)
	pmat.direction = Vector3(0, 1, 0.1)
	pmat.spread = 28.0
	pmat.initial_velocity_min = 0.8
	pmat.initial_velocity_max = 1.8
	pmat.gravity = Vector3(0, 0.5, 0)
	pmat.damping_min = 0.9
	pmat.damping_max = 2.0
	pmat.scale_min = 0.35
	pmat.scale_max = 0.7
	pmat.color = Color(1.0, 0.5, 0.1, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.75, 0.25, 0.0),
		Color(1.0, 0.55, 0.1, 1.0),
		Color(1.0, 0.28, 0.04, 0.65),
		Color(0.25, 0.05, 0.0, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	pmat.color_ramp = gtex
	fx.process_material = pmat
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fx.draw_pass_1 = _make_fire_triangle_mesh(0.034, 0.058)
	fx.material_override = draw
	return fx


func _make_fire_smoke_particles() -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.name = "FireSmoke"
	fx.amount = 36
	fx.lifetime = 1.6
	fx.explosiveness = 0.0
	fx.randomness = 0.7
	fx.emitting = false
	fx.position = Vector3(0, 0.08, 0)
	fx.visibility_aabb = AABB(Vector3(-2.0, -0.2, -1.2), Vector3(4.0, 4.0, 2.4))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.28, 0.02, 0.18)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 0.35
	pmat.initial_velocity_max = 0.85
	pmat.gravity = Vector3(0, 0.55, 0)
	pmat.damping_min = 0.2
	pmat.damping_max = 0.6
	pmat.scale_min = 1.2
	pmat.scale_max = 2.8
	pmat.color = Color(0.15, 0.12, 0.1, 0.45)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.25, 0.18, 0.12, 0.0),
		Color(0.18, 0.14, 0.12, 0.4),
		Color(0.12, 0.11, 0.1, 0.22),
		Color(0.08, 0.08, 0.08, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	pmat.color_ramp = gtex
	fx.process_material = pmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.16)
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	draw.albedo_color = Color(0.2, 0.16, 0.14, 0.5)
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fx.draw_pass_1 = quad
	fx.material_override = draw
	return fx


func _update_grill_fire(delta: float) -> void:
	if not grill_on_fire:
		return
	## Powder already snuffed the visible blaze — don't revive flames/lights.
	if _fire_killed_by_powder:
		_set_fire_fx_emitting(false)
		## Still char meat in the burning section until fully extinguished.
		for i in GRILL_SLOTS:
			var p = grill[i]
			if p != null and is_instance_valid(p) and _is_in_fire_zone(p.position):
				p.heating = true
				p.heat_mul = maxf(float(p.heat_mul), 1.35)
				p.cook_time += delta * 2.8
		return
	_sync_fire_to_oil_area()
	_fire_flicker_t += delta
	var t := Time.get_ticks_msec() * 0.001
	## Uneven flicker so the kitchen reads hot and dangerous.
	var flicker := 0.72 \
		+ 0.22 * sin(t * 17.3) \
		+ 0.12 * sin(t * 31.7 + 1.1) \
		+ 0.08 * sin(t * 53.0 + 0.4) \
		+ randf() * 0.06
	if fire_light != null and is_instance_valid(fire_light):
		fire_light.visible = true
		fire_light.light_energy = FIRE_LIGHT_CORE * flicker
		fire_light.light_color = Color(1.0, lerpf(0.28, 0.4, flicker), lerpf(0.04, 0.08, flicker))
	if fire_light_rim != null and is_instance_valid(fire_light_rim):
		fire_light_rim.visible = true
		fire_light_rim.light_energy = FIRE_LIGHT_RIM * (0.75 + flicker * 0.45)
		fire_light_rim.light_color = Color(0.95, 0.16, 0.03)
	## Oil puddles glow only under the burning section.
	for item in oil_slicks:
		var m = item.get("mesh")
		if m == null or not is_instance_valid(m):
			continue
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		if not _is_in_fire_zone(m.position):
			mat.emission_enabled = false
			continue
		var pulse := 0.55 + 0.45 * sin(t * 9.0 + float(m.get_instance_id() % 7))
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.05)
		mat.emission_energy_multiplier = 1.2 + pulse * 2.4
		mat.albedo_color = Color(0.35, 0.12, 0.04, 0.85)
	## Keep cooking meat only in the blaze section.
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p != null and is_instance_valid(p) and _is_in_fire_zone(p.position):
			p.heating = true
			p.heat_mul = maxf(float(p.heat_mul), 1.35)
			p.cook_time += delta * 2.8


func _ensure_ext_powder_collision() -> void:
	## Kill powder particles the moment they hit the flat-top (no falling through).
	if grill_root == null:
		return
	if grill_root.has_node("ExtPowderCollision"):
		return
	var col := GPUParticlesCollisionBox3D.new()
	col.name = "ExtPowderCollision"
	## Thin pad on the steel — HIDE_ON_CONTACT removes particles that reach it.
	col.size = Vector3(GRILL_WIDTH + 0.35, 0.06, GRILL_DEPTH + 0.35)
	col.position = Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y + 0.01, GRILL_SURFACE_Z)
	grill_root.add_child(col)


func _ensure_ext_powder() -> void:
	_ensure_ext_powder_collision()
	if ext_powder != null and is_instance_valid(ext_powder):
		return
	if ext_root == null:
		return
	ext_powder = GPUParticles3D.new()
	ext_powder.name = "ExtPowder"
	ext_powder.amount = 70
	ext_powder.lifetime = 0.38
	ext_powder.explosiveness = 0.12
	ext_powder.randomness = 0.4
	ext_powder.emitting = false
	ext_powder.position = Vector3(0.0, -0.08, 0.06)
	## Don't draw anything that falls below the grill face.
	ext_powder.visibility_aabb = AABB(Vector3(-0.9, -0.15, -0.9), Vector3(1.8, 1.0, 1.8))
	ext_powder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, -1, 0.2)
	pmat.spread = 14.0
	pmat.initial_velocity_min = 1.6
	pmat.initial_velocity_max = 2.8
	pmat.gravity = Vector3(0, -14.0, 0)
	pmat.damping_min = 2.0
	pmat.damping_max = 4.0
	pmat.scale_min = 0.45
	pmat.scale_max = 0.95
	pmat.color = Color(0.96, 0.96, 0.98, 0.85)
	## Die on contact with the grill collision pad — no punch-through squares.
	pmat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	var fade := Gradient.new()
	fade.add_point(0.0, Color(1, 1, 1, 0.0))
	fade.add_point(0.08, Color(1, 1, 1, 0.9))
	fade.add_point(0.55, Color(0.95, 0.95, 0.97, 0.45))
	fade.add_point(1.0, Color(0.9, 0.9, 0.92, 0.0))
	var gtex := GradientTexture1D.new()
	gtex.gradient = fade
	pmat.color_ramp = gtex
	ext_powder.process_material = pmat
	## Soft spheres — never billboard quads (those read as white squares under the rim).
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = Color(0.97, 0.97, 0.99, 0.75)
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.disable_receive_shadows = true
	ext_powder.draw_pass_1 = sphere
	ext_powder.material_override = draw
	ext_root.add_child(ext_powder)


func _spray_extinguisher_powder(delta: float, aim: Vector3) -> void:
	_ensure_ext_powder()
	## Aiming at a waiting customer through the window?
	var spray_hit := _try_spray_customer_with_powder(delta)
	var sprayed: bool = bool(spray_hit.get("hit", false))
	## White powder blobs only land on the flat-top.
	var on_grill := absf(aim.x - GRILL_CENTER_X) <= GRILL_WIDTH * 0.55 \
		and absf(aim.z - GRILL_SURFACE_Z) <= GRILL_DEPTH * 0.55
	## Nozzle mist on customers or the steel.
	if ext_powder:
		ext_powder.emitting = sprayed or on_grill
	if mp_enabled and not _mp_applying and _mp_ext_sync_cool <= 0.0:
		_mp_ext_sync_cool = 0.05
		mp_ext_spray.rpc(true, aim.x, aim.z, sprayed)
	if sprayed:
		return
	if not on_grill:
		return
	ext_blob_spawn_cool -= delta
	if ext_blob_spawn_cool <= 0.0:
		ext_blob_spawn_cool = 0.045
		_spawn_ext_powder_blob(aim)
	if not grill_on_fire:
		return
	## First hit on the burning section — kill flame particles / lights immediately.
	if not _is_in_fire_zone(aim):
		return
	if not _fire_killed_by_powder:
		_fire_killed_by_powder = true
		_set_fire_fx_emitting(false)
		_flash("Powder on the fire — keep spraying!", Color("E3F2FD"))
	fire_health = maxf(0.0, fire_health - delta * 0.85)
	if fire_health <= 0.0:
		_extinguish_grill_fire()


func _find_customer_under_ext_spray() -> Dictionary:
	## Cursor near a customer's head or torso → they're in the spray cone.
	if camera == null or customers_root == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var best: Dictionary = {}
	var best_d := 108.0
	for c in customers_root.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("receive_ext_powder"):
			continue
		var torso: Vector3 = c.global_position + Vector3(0.0, 0.85, 0.0)
		if camera.is_position_behind(torso):
			continue
		var head: Vector3 = c.global_position + Vector3(0.0, 1.22, 0.0)
		var face: Vector3 = c.global_position + Vector3(0.0, 1.38, 0.06)
		var d_head := mouse.distance_to(camera.unproject_position(head))
		var d_face := mouse.distance_to(camera.unproject_position(face))
		var d_torso := mouse.distance_to(camera.unproject_position(torso))
		var d := mini(mini(d_head, d_face), d_torso)
		if d < best_d:
			best_d = d
			var zone := "face"
			if d_torso + 6.0 < mini(d_head, d_face):
				zone = "body"
			best = {"customer": c, "zone": zone}
	return best


func _try_spray_customer_with_powder(delta: float) -> Dictionary:
	var hit := _find_customer_under_ext_spray()
	if hit.is_empty():
		return {"hit": false}
	var cust: Node = hit.get("customer")
	var zone: String = String(hit.get("zone", "body"))
	if cust == null or not cust.has_method("receive_ext_powder"):
		return {"hit": false}
	if cust.has_method("apply_ext_spray_push"):
		cust.call("apply_ext_spray_push", delta, zone)
	ext_blob_spawn_cool -= delta
	if ext_blob_spawn_cool > 0.0:
		## Keep remotes seeing knock-back even between powder pulses.
		if mp_enabled and not _mp_applying and _mp_ext_sync_cool <= 0.0:
			var nid_push := _customer_net_id(cust as Node3D)
			if nid_push >= 0:
				_mp_ext_sync_cool = 0.08
				mp_ext_customer_push.rpc(nid_push, zone, delta)
		return {"hit": true, "customer": cust, "zone": zone}
	ext_blob_spawn_cool = 0.022
	var first_hit: bool = bool(cust.call("receive_ext_powder", zone))
	if mp_enabled and not _mp_applying:
		var nid := _customer_net_id(cust as Node3D)
		if nid >= 0:
			## Remotes get every powder pulse so clumps build up for everyone.
			## Host also authors ticket leave on first_hit (guests can't).
			mp_ext_customer.rpc(nid, zone, first_hit)
	if first_hit:
		var msg := "Customer: \"Agh! My face!!\"" if zone == "face" else "Customer: \"What the heck?!\""
		_flash(msg, Color("EF9A9A"))
		if game_audio:
			game_audio.play_click()
		## Solo / host: apply leave + forced spray review now.
		## Guest sprayer: host applies leave inside mp_ext_customer(first_hit).
		if not mp_enabled or NetManager.is_host():
			_on_customer_left(cust as Node3D, true)
	return {"hit": true, "customer": cust, "zone": zone}


func _find_customer_under_ext_cursor() -> Node3D:
	var hit := _find_customer_under_ext_spray()
	var c = hit.get("customer")
	return c as Node3D if c != null else null


func _spawn_ext_powder_blob(aim: Vector3) -> void:
	if grill_root == null:
		return
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var rad := 0.055 + randf() * 0.07
	sphere.radius = rad
	sphere.height = rad * 2.0
	blob.mesh = sphere
	## Sit on the steel with a little scatter around the aim point.
	var jitter := Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.07, 0.07))
	blob.position = Vector3(
		clampf(aim.x + jitter.x, GRILL_CENTER_X - GRILL_WIDTH * 0.48, GRILL_CENTER_X + GRILL_WIDTH * 0.48),
		GRILL_SURFACE_Y + rad * 0.55,
		clampf(aim.z + jitter.z, GRILL_SURFACE_Z - GRILL_DEPTH * 0.48, GRILL_SURFACE_Z + GRILL_DEPTH * 0.48)
	)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.sorting_offset = 6.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.96, 0.97, 1.0, 0.88)
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.render_priority = 10
	blob.material_override = mat
	grill_root.add_child(blob)
	var life := 2.4 + randf() * 1.6
	var start_s := 0.85 + randf() * 0.55
	blob.scale = Vector3.ONE * start_s
	ext_powder_blobs.append({
		"mesh": blob,
		"mat": mat,
		"life": life,
		"max_life": life,
		"start_scale": start_s,
	})
	## Cap so a long spray doesn't explode the scene.
	while ext_powder_blobs.size() > 90:
		var old: Dictionary = ext_powder_blobs.pop_front()
		var m = old.get("mesh")
		if m != null and is_instance_valid(m):
			m.queue_free()


func _update_ext_powder_blobs(delta: float) -> void:
	var i := 0
	while i < ext_powder_blobs.size():
		var item: Dictionary = ext_powder_blobs[i]
		var mesh = item.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			ext_powder_blobs.remove_at(i)
			continue
		item["life"] = float(item["life"]) - delta
		var life: float = float(item["life"])
		var max_life: float = maxf(0.05, float(item["max_life"]))
		var t := clampf(life / max_life, 0.0, 1.0)
		## Shrink + fade as the powder settles into the steel.
		var s: float = float(item["start_scale"]) * (0.15 + 0.85 * t)
		mesh.scale = Vector3.ONE * s
		var mat = item.get("mat") as StandardMaterial3D
		if mat != null:
			var c: Color = mat.albedo_color
			c.a = 0.15 + 0.75 * t
			mat.albedo_color = c
		if life <= 0.0:
			mesh.queue_free()
			ext_powder_blobs.remove_at(i)
			continue
		ext_powder_blobs[i] = item
		i += 1


func _clear_ext_powder_blobs() -> void:
	for item in ext_powder_blobs:
		var m = item.get("mesh")
		if m != null and is_instance_valid(m):
			m.queue_free()
	ext_powder_blobs.clear()
	ext_blob_spawn_cool = 0.0


func _extinguish_grill_fire() -> void:
	if not grill_on_fire and not _fire_killed_by_powder:
		return
	if mp_enabled and not _mp_applying:
		mp_grill_fire_end.rpc()
		return
	_extinguish_grill_fire_local()


func _extinguish_grill_fire_local() -> void:
	if not grill_on_fire and not _fire_killed_by_powder:
		return
	grill_on_fire = false
	fire_health = 0.0
	fire_zone_id = ""
	_fire_killed_by_powder = false
	_set_fire_fx_emitting(false)
	## Smother the oil puddles too — powder mess.
	_clear_oil_slicks()
	_oil_fire_warned = false
	if game_audio:
		game_audio.play_chaching()
	_flash("Fire out! …customers: \"What the heck?!\"", Color("B0BEC5"))
	_scare_customers_after_fire()


func _scare_customers_after_fire() -> void:
	## Anyone waiting bolts after the grease-fire scare.
	for c in customers.duplicate():
		if c == null or not is_instance_valid(c):
			continue
		if c.has_method("leave_heck"):
			c.leave_heck()
		elif c.has_method("leave_mad"):
			c.leave_mad()
		## No angry fine — they just freaked out and left.
		_on_customer_left(c, false)


func _clear_grill_fire() -> void:
	grill_on_fire = false
	fire_health = 0.0
	fire_zone_id = ""
	_oil_fire_warned = false
	_fire_killed_by_powder = false
	ext_spraying = false
	_set_fire_fx_emitting(false)
	_clear_ext_powder_blobs()
	if fire_root != null and is_instance_valid(fire_root):
		fire_root.queue_free()
	fire_root = null
	fire_light = null
	fire_light_rim = null
	fire_particles = null
	fire_particles_red = null
	fire_embers = null
	fire_smoke = null


func _make_oil_burn_smoke(radius: float) -> GPUParticles3D:
	## Light steam — mostly white with a few brown flecks, soft alpha.
	var smoke := GPUParticles3D.new()
	smoke.name = "OilBurnSmoke"
	smoke.amount = 22
	smoke.lifetime = 1.45
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
	pmat.color = Color(0.96, 0.97, 0.99, 0.14)
	var fade := Gradient.new()
	fade.add_point(0.0, Color(1, 1, 1, 0.0))
	fade.add_point(0.12, Color(0.98, 0.98, 1.0, 0.20))
	fade.add_point(0.4, Color(0.95, 0.96, 0.98, 0.10))
	fade.add_point(0.72, Color(0.82, 0.72, 0.58, 0.04)) ## faint brown fleck tint late
	fade.add_point(1.0, Color(0.9, 0.9, 0.92, 0.0))
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
	draw.albedo_color = Color(0.97, 0.97, 0.99, 0.24)
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
	## Soft white puff with sparse brown flecks — reused for every oil slick.
	if _oil_smoke_tex != null:
		return _oil_smoke_tex
	var w := 64
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid := float(w - 1) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 41753011
	for y in h:
		for x in w:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = pow(a, 1.75) * 0.28
			if a < 0.015:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				## Mostly white steam; rare brown grease bits.
				if rng.randf() < 0.055 and a > 0.08:
					img.set_pixel(x, y, Color(0.62, 0.48, 0.34, a * 0.55))
				else:
					img.set_pixel(x, y, Color(0.97, 0.98, 1.0, a))
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
	_oil_fire_warned = false


func _build_oil_bottle() -> void:
	## Oil bottle hanging from the far-left window beam.
	oil_home = Vector3(1.166, 2.12, 1.12)
	oil_root = Node3D.new()
	oil_root.name = "OilBottle"
	oil_root.position = oil_home
	oil_root.rotation_degrees = Vector3(6.0, -18.0, 3.0)
	oil_root.scale = Vector3(2.05, 2.05, 2.05)
	world.add_child(oil_root)

	oil_area = Area3D.new()
	oil_area.input_ray_pickable = true
	oil_area.collision_layer = 16
	oil_area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Roomier than the bottle so hanging tools stay easy to click.
	box.size = Vector3(0.12, 0.22, 0.12)
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
	bmat.albedo_color = Color(0.98, 0.9, 0.35, 0.78)
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
	oil_particles.name = "OilParticles"
	oil_particles.amount = 56
	oil_particles.lifetime = 0.55
	oil_particles.explosiveness = 0.05
	oil_particles.randomness = 0.45
	oil_particles.emitting = false
	## Tip sits at local +Y; bottle flips 180 when pouring so that becomes world −Y.
	oil_particles.position = Vector3(0, 0.13, 0)
	var op := ParticleProcessMaterial.new()
	op.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	op.emission_sphere_radius = 0.006
	## Local +Y out the nozzle — with the held 180° flip that shoots toward the steel.
	op.direction = Vector3(0, 1, 0)
	op.spread = 12.0
	op.initial_velocity_min = 0.75
	op.initial_velocity_max = 1.35
	## World-space gravity must pull down (negative Y), not up into the bottle.
	op.gravity = Vector3(0, -9.8, 0)
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
	if spatula_patty != null or brush_held or cheese_held or shaker_held or ext_held or glock_held or dragging_patty != null:
		return false
	var tip := oil_root.global_position + Vector3(0, 0.06, 0)
	var screen_pt := camera.unproject_position(tip)
	if screen_pos.distance_to(screen_pt) > 58.0 and not _ray_hits_tool(screen_pos, 16, oil_area):
		return false
	return _begin_oil_hold()


func _begin_oil_hold() -> bool:
	if not playing or oil_held or oil_root == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or ext_held or glock_held or cup_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	oil_held = true
	oil_last_draw = Vector3.ZERO
	oil_pour_hold_t = 0.0
	oil_root.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	var seat := _tool_hold_point_from_screen(get_viewport().get_mouse_position(), GRILL_SURFACE_Y + OIL_POUR_HEIGHT)
	if seat != Vector3.ZERO:
		oil_root.global_position = seat
	if oil_area:
		oil_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_spend(COST_OIL_USE)
	_flash("Oil tipped — drag to draw on the grill", Color("FFE082"))
	if mp_enabled:
		_mp_send_held_tool_pose(true)
	return true


func _tween_tool_to_wall(
	node: Node3D,
	home_pos: Vector3,
	home_rot: Vector3,
	home_scale: Vector3 = Vector3.ONE,
	duration: float = 0.32,
	on_done: Callable = Callable()
) -> void:
	## Smooth put-away instead of snapping tools back onto the wall.
	if node == null or not is_instance_valid(node):
		if on_done.is_valid():
			on_done.call()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", home_pos, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation_degrees", home_rot, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if home_scale != Vector3.ONE or node.scale.distance_to(home_scale) > 0.01:
		tw.tween_property(node, "scale", home_scale, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on_done.is_valid():
		tw.chain().tween_callback(on_done)


func _release_oil_bottle() -> void:
	if not oil_held or oil_root == null:
		return
	oil_held = false
	oil_last_draw = Vector3.ZERO
	oil_pour_hold_t = 0.0
	if oil_particles:
		oil_particles.emitting = false
	if oil_area:
		oil_area.input_ray_pickable = false
	_tween_tool_to_wall(
		oil_root,
		oil_home,
		Vector3(8.0, 40.0, -5.0),
		Vector3(2.05, 2.05, 2.05),
		0.3,
		func() -> void:
			if oil_area != null and is_instance_valid(oil_area):
				oil_area.input_ray_pickable = true
	)
	if game_audio:
		game_audio.play_click()
	if mp_enabled:
		mp_tool_pose.rpc(2, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _reset_oil_bottle() -> void:
	oil_held = false
	oil_spray_cool = 0.0
	oil_last_draw = Vector3.ZERO
	oil_pour_hold_t = 0.0
	if oil_particles:
		oil_particles.emitting = false
	if oil_root:
		oil_root.position = oil_home
		oil_root.rotation_degrees = Vector3(8.0, 40.0, -5.0)
		oil_root.scale = Vector3(2.05, 2.05, 2.05)
	if oil_area:
		oil_area.input_ray_pickable = true
	_clear_oil_slicks()
	if mp_enabled:
		mp_tool_pose.rpc(2, false, 0.0, 0.0, 0.0, false, 0.0, 0.0, 0.0)


func _grill_zone_bands() -> Array:
	## Screen-left → right (world +X → −X): FULL · 1/2 · HOLD.
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
			"id": "half",
			"frac": ZONE_HALF_FRAC,
			"mul": ZONE_HALF_MUL,
			"label": "1/2",
			"col": Color(0.27, 0.28, 0.3),
			"rough": 0.26,
			"emit": 0.05,
			"glow": 0.42,
			"lab_col": Color(1.0, 0.9, 0.65, 0.92),
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
	## HOLD band (former 1/4 strip).
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
	## Zone labels along the flat-top: FULL · 1/2 · HOLD.
	if warmer_root != null and is_instance_valid(warmer_root):
		warmer_root.queue_free()
	warmer_root = Node3D.new()
	warmer_root.name = "GrillHeatZones"
	grill_root.add_child(warmer_root)
	## Same origin as the steel surface so label X matches zone / heat-glow centers.
	## +~2\" above the steel so FULL / 1/2 / HOLD clear the rim and stay readable.
	warmer_root.position = Vector3(GRILL_CENTER_X, GRILL_SURFACE_Y + 0.077, GRILL_SURFACE_Z)

	## Near-rim depth (not further toward camera) — extra Z skews labels off-band in perspective.
	var label_z := -GRILL_DEPTH * 0.42
	warmer_label = null
	warmer_label_half = null
	warmer_label_hold = null
	for z in _grill_zone_bands():
		var lab := _make_warmer_speed_label(
			str(z["label"]),
			Vector3(float(z["cx"]) - GRILL_CENTER_X, 0.028, label_z),
			z["lab_col"]
		)
		## Slight screen-up nudge so text sits above the steel lip.
		_nudge_label3d_on_screen(lab, Vector2(0.0, -12.0))
		match str(z["id"]):
			"full":
				warmer_label = lab
			"half":
				warmer_label_half = lab
			"hold":
				warmer_label_hold = lab


func _nudge_label3d_on_screen(lab: Label3D, screen_delta: Vector2) -> void:
	## Shift a world Label3D by viewport pixels (e.g. +Y = down on screen).
	if camera == null or lab == null or not is_instance_valid(lab):
		return
	var gp := lab.global_position
	if camera.is_position_behind(gp):
		return
	var sp := camera.unproject_position(gp)
	var depth := camera.global_position.distance_to(gp)
	var target := sp + screen_delta
	lab.global_position = camera.project_ray_origin(target) + camera.project_ray_normal(target) * depth


func _update_patty_warm_hold(patty: Area3D, delta: float) -> void:
	## Meat starts its 5-min clock on first HOLD visit, then keeps aging everywhere
	## (grill / spatula / slide-offs do NOT reset the meter).
	if patty == null or not is_instance_valid(patty):
		return
	if _is_bun_toast(patty):
		return
	## Guest hold-age comes from host grill snapshots — don't double-tick or solo-trash.
	if mp_enabled and not NetManager.is_host():
		return
	var on_hold: bool = (not patty.is_held) and _is_in_warmer_zone(patty.position)
	if on_hold or float(patty.warm_hold_time) > 0.0:
		patty.warm_hold_time = float(patty.warm_hold_time) + delta
		if float(patty.warm_hold_time) >= WARM_HOLD_MAX:
			if mp_enabled and int(patty.get("net_id")) >= 0:
				mp_trash_patty.rpc(int(patty.net_id))
			else:
				_trash_held_warm_patty(patty)


func _update_bun_toast_hold(bun: Area3D, delta: float) -> void:
	## Toasted buns stay fresh on HOLD for 40s, then go stale and get tossed.
	if bun == null or not is_instance_valid(bun) or not _is_bun_toast(bun):
		return
	if mp_enabled and not NetManager.is_host():
		return
	if bun.is_held:
		return
	## Only after done toasting (ready or burnt) — park on HOLD to keep.
	if float(bun.cook_time) < BunToastScript.TOAST_READY:
		return
	var on_hold: bool = _is_in_warmer_zone(bun.position)
	if not on_hold:
		return
	bun.warm_hold_time = float(bun.warm_hold_time) + delta
	if float(bun.warm_hold_time) >= BunToastScript.TOAST_HOLD_MAX:
		if mp_enabled and int(bun.get("net_id")) >= 0:
			mp_trash_patty.rpc(int(bun.net_id))
			_flash("Toasted buns went stale on HOLD (40s) — tossed", Color("EF5350"))
		else:
			_trash_stale_toast_buns(bun)


func _trash_stale_toast_buns(bun: Area3D) -> void:
	if bun == null or not is_instance_valid(bun):
		return
	var idx: int = int(bun.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == bun:
		grill[idx] = null
	if spatula_patty == bun:
		spatula_patty = null
		spatula_owner_id = 0
		spatula_from_build = false
		_refresh_spatula_ui()
	bun.queue_free()
	if game_audio and game_audio.has_method("play_trash"):
		game_audio.play_trash()
	_flash("Toasted buns went stale on HOLD (40s) — tossed", Color("EF5350"))


func _trash_held_warm_patty(patty: Area3D) -> void:
	var idx: int = int(patty.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == patty:
		grill[idx] = null
	if is_instance_valid(patty):
		patty.queue_free()
	_spend(COST_DROP_BURGER, "Hold meat went BAD — tossed (%s)" % _format_money(COST_DROP_BURGER), Color("EF5350"))


func _make_warmer_speed_label(text: String, local_pos: Vector3, col: Color) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.position = local_pos
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.modulate = col
	UiFontsScript.apply_label3d(lab, true, 36, 0.022)
	## No fat outline — it read as a jagged black halo on FULL / HOLD.
	lab.outline_size = 0
	lab.outline_modulate = Color(0, 0, 0, 0)
	warmer_root.add_child(lab)
	return lab


func _ensure_grill_steel_texture() -> void:
	if grill_steel_tex != null and is_instance_valid(grill_steel_tex):
		return
	if ResourceLoader.exists(GRILL_STEEL_TEX_PATH):
		grill_steel_tex = load(GRILL_STEEL_TEX_PATH) as Texture2D


func _make_grill_zone_metal(albedo: Color, roughness: float, emit: float, zone_w: float = 1.0, zone_d: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	_ensure_grill_steel_texture()
	if grill_steel_tex != null:
		mat.albedo_texture = grill_steel_tex
		## Tint the brushed map per heat band (FULL warmer, HOLD cooler).
		mat.albedo_color = Color(
			clampf(albedo.r * 1.35, 0.0, 1.0),
			clampf(albedo.g * 1.35, 0.0, 1.0),
			clampf(albedo.b * 1.35, 0.0, 1.0)
		)
		## Tile across bands — larger tile = more visible brushed grain.
		var tile := GRILL_STEEL_TILE_M
		mat.uv1_scale = Vector3(maxf(0.35, zone_w / tile), maxf(0.35, zone_d / tile), 1.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
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
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.97, 1.0)
	mat.emission_energy_multiplier = 0.7
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
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id() and not _mp_applying:
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
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_place_warmer.rpc(int(spatula_patty.net_id), idx, pos.x, pos.z)
		return
	_place_spatula_on_warmer_local(idx, pos, spatula_patty)


func _place_spatula_on_warmer_local(idx: int, pos: Vector3, patty: Area3D = null) -> void:
	if patty == null:
		patty = spatula_patty
	if patty == null or not is_instance_valid(patty):
		return
	_mp_release_scoop_if(patty)
	patty.is_held = false
	patty.visible = true
	patty.rotation_degrees = Vector3.ZERO
	patty.slot_index = idx
	patty.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	patty.heating = grill_on
	patty.heat_mul = _warmer_heat_mul(pos) * _oil_heat_mul(pos)
	## Keep existing hold age — putting back on HOLD must not refresh the 5-min clock.
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
	if _is_bun_toast(patty):
		if float(patty.cook_time) >= BunToastScript.TOAST_READY:
			var left := int(ceil(BunToastScript.TOAST_HOLD_MAX - float(patty.warm_hold_time)))
			_flash("Buns on HOLD — stay fresh %ds" % maxi(1, left), Color("90CAF9"))
		else:
			_flash("Toast the buns first (2s) — then HOLD keeps them 40s", Color("FFCC80"))
	else:
		_flash("On HOLD — stays warm up to 5 minutes (won't cook more)", Color("90CAF9"))


func _clear_warmer() -> void:
	## Zone is spatial; patties clear with the grill.
	pass


func _try_grab_brush(screen_pos: Vector2) -> bool:
	if brush_held or brush_area == null or camera == null:
		return false
	if _ui_blocks_world_click(screen_pos):
		return false
	if spatula_patty != null or cheese_held or shaker_held or oil_held or ext_held or glock_held:
		return false
	## Interrupt put-away so re-grabs feel instant.
	brush_throwing = false
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
		var tip := brush_root.global_position + brush_root.basis * Vector3(0, 0.12, 0)
		var screen_pt := camera.unproject_position(tip)
		if screen_pos.distance_to(screen_pt) <= 88.0:
			grabbed = true
	if not grabbed:
		return false
	brush_held = true
	brush_throwing = false
	if brush_area:
		brush_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Swipe grease off the steel — keep moving to scrub it clean", Color("B0BEC5"))
	brush_last_pos = brush_root.global_position if brush_root else Vector3.ZERO
	## Full snap under cursor immediately.
	_snap_brush_toward_cursor(screen_pos, 1.0)
	return true


func _snap_brush_toward_cursor(screen_pos: Vector2, amount: float = 1.0) -> void:
	if brush_root == null or camera == null:
		return
	var hit := _tool_hold_point_from_screen(screen_pos, GRILL_SURFACE_Y + 0.065)
	if hit == Vector3.ZERO:
		return
	brush_root.global_position = brush_root.global_position.lerp(hit, clampf(amount, 0.0, 1.0))
	brush_root.rotation_degrees = brush_held_rot


func _update_held_brush(_delta: float) -> void:
	if brush_root == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var hit := _tool_hold_point_from_screen(mouse, GRILL_SURFACE_Y + 0.065)
	if hit == Vector3.ZERO:
		return
	var prev := brush_root.global_position
	## Near-instant follow.
	brush_root.global_position = hit
	var move_xz := Vector2(
		brush_root.global_position.x - prev.x,
		brush_root.global_position.z - prev.z
	)
	var moved := move_xz.length()
	## Handle always toward the cook — never yaw with swipe (that spun the blade).
	var tip := sin(Time.get_ticks_msec() * 0.018) * 1.5
	brush_root.rotation_degrees = Vector3(brush_held_rot.x + tip, brush_held_rot.y, brush_held_rot.z)
	## Nudge burgers when the blade shoves into them.
	if moved > 0.0008:
		_brush_nudge_patties(brush_root.global_position, move_xz, moved)
	## Continuous scrape — wear residue down while the blade is moving over it.
	var scraping := false
	for i in GRILL_SLOTS:
		if i < brush_swipe_cool.size():
			brush_swipe_cool[i] = maxf(0.0, float(brush_swipe_cool[i]) - _delta)
		if float(grill_residue[i]) <= 0.0:
			continue
		var pad_pos: Vector3 = grill_residue_centers[i] if i < grill_residue_centers.size() else slot_positions[i]
		var d := Vector2(brush_root.global_position.x - pad_pos.x, brush_root.global_position.z - pad_pos.z).length()
		if d < 0.34 and moved > 0.0005:
			scraping = true
			var before := float(grill_residue[i])
			grill_residue[i] = maxf(0.0, before - moved * RESIDUE_SCRAPE_RATE)
			_refresh_residue_visual(i)
			if mp_enabled and not _mp_applying and _mp_residue_sync_cool <= 0.0:
				_mp_residue_sync_cool = 0.09
				mp_residue_amt.rpc(i, float(grill_residue[i]))
			if i < brush_swipe_travel.size():
				brush_swipe_travel[i] = float(brush_swipe_travel[i]) + moved
			## Chip flecks as you work the stain down.
			if float(brush_swipe_cool[i]) <= 0.0 and float(brush_swipe_travel[i]) >= RESIDUE_SWIPE_DIST:
				brush_swipe_travel[i] = 0.0
				brush_swipe_cool[i] = 0.12
				_scrape_residue_hit(i, move_xz)
				if mp_enabled and not _mp_applying:
					mp_residue_chip.rpc(i, move_xz.x, move_xz.y)
			if float(grill_residue[i]) <= 0.04:
				_scrape_finish_clean(i)
		elif i < brush_swipe_travel.size():
			brush_swipe_travel[i] = maxf(0.0, float(brush_swipe_travel[i]) - _delta * 0.25)
	if game_audio and game_audio.has_method("set_slide_moving"):
		if scraping:
			game_audio.set_slide_moving(true, clampf(moved / maxf(_delta, 0.001) * 0.25, 0.3, 1.2))
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
	brush_throwing = false
	if game_audio:
		game_audio.play_click()
		if game_audio.has_method("set_slide_moving"):
			game_audio.set_slide_moving(false)
	if brush_area:
		brush_area.input_ray_pickable = false
	_tween_tool_to_wall(
		brush_root,
		brush_home,
		brush_home_rot,
		Vector3.ONE,
		0.3,
		func() -> void:
			if brush_area != null and is_instance_valid(brush_area):
				brush_area.input_ray_pickable = true
	)
	_flash("Scraper put away", Color("B0BEC5"))


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


func _station_cook_rating(station_index: int, customer: Node3D = null) -> Dictionary:
	## Serve-speed grade from the order ticket clock; burnt meat forces Bad.
	var burnt := false
	var st: Dictionary = stations[station_index]
	for p in st["patties"]:
		if p != null and is_instance_valid(p) and p.has_method("is_burnt") and p.is_burnt():
			burnt = true
			break
	var cust: Node3D = customer if customer != null else selected_customer
	if cust != null and is_instance_valid(cust) and cust.has_method("speed_rating"):
		return cust.speed_rating(burnt)
	return {
		"score": 0,
		"grade": "-",
		"stars": 0,
		"label": "—",
		"detail": "",
		"color": Color("B0BEC5"),
		"text": "—",
		"pay_mul": 1.0,
	}


func _station_burgers_seasoned(station_index: int) -> bool:
	## Any Build patty must have been seasoned; empty stack counts as N/A (ok).
	if station_index < 0 or station_index >= stations.size():
		return true
	var patties: Array = stations[station_index]["patties"]
	if patties.is_empty():
		return true
	for p in patties:
		if p == null or not is_instance_valid(p):
			continue
		if p.has_method("is_seasoned") and not bool(p.is_seasoned()):
			return false
		elif "seasoning" in p and float(p.seasoning) < 0.1:
			return false
	return true


func _station_bun_toast_mul(station_index: int) -> float:
	## Shared top+bottom toast clock — peak at 2.0s perfect.
	if not BUN_TOAST_ENABLED:
		return 1.0
	if station_index < 0 or station_index >= stations.size():
		return 1.0
	var cook := maxf(
		_station_bun_cook_time(station_index, "bun_bottom"),
		_station_bun_cook_time(station_index, "bun_top")
	)
	if cook <= 0.05:
		return 1.0
	if cook >= BunToastScript.TOAST_BURNT:
		return 0.72
	if absf(cook - BunToastScript.TOAST_READY) <= BunToastScript.TOAST_PERFECT_SLACK:
		return 1.15
	if cook < BunToastScript.TOAST_READY:
		return lerpf(0.94, 1.15, cook / BunToastScript.TOAST_READY)
	return lerpf(
		1.15,
		0.72,
		(cook - BunToastScript.TOAST_READY) / maxf(0.001, BunToastScript.TOAST_BURNT - BunToastScript.TOAST_READY)
	)


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


## Painted street outside the service window + invisible walk collider for NPCs.
func _build_outdoor_street() -> void:
	var outdoor := Node3D.new()
	outdoor.name = "OutdoorStreet"
	world.add_child(outdoor)

	## Invisible sidewalk / street floor — NPCs keep standing here; no visible mesh.
	var floor_body := StaticBody3D.new()
	floor_body.name = "OutdoorWalkFloor"
	floor_body.position = Vector3(0.0, -0.08, 4.5)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(24.0, 0.16, 14.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	outdoor.add_child(floor_body)

	## Matte painting fills the view beyond the window.
	const BG_PATH := "res://assets/bg/street_window.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(BG_PATH):
		tex = load(BG_PATH) as Texture2D
	if tex == null:
		## Fallback flat sky if the paint isn't imported yet.
		var fallback := _add_box(outdoor, Vector3(28, 14, 0.08), Vector3(0.0, 2.6, 8.5), Color("7EC8E8"))
		fallback.rotation_degrees = Vector3(0, 0, 0)
		return

	var backdrop := MeshInstance3D.new()
	backdrop.name = "StreetMatte"
	var quad := QuadMesh.new()
	## Wide enough to cover the FOV through the service window.
	quad.size = STREET_MATTE_BASE_SIZE
	backdrop.mesh = quad
	## Sit past the sidewalk; face the truck (camera looks +Z through the window).
	backdrop.position = Vector3(0.0, STREET_MATTE_DEFAULT_Y, STREET_MATTE_BASE_Z)
	backdrop.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	## Draw behind characters — never paint over the sidewalk NPCs.
	mat.render_priority = -8
	backdrop.material_override = mat
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.sorting_offset = -20.0
	outdoor.add_child(backdrop)
	street_matte = backdrop

	## Thin wall on the paint — stops ragdolls / bodies clipping behind it.
	## Bullet / laser rays exclude STREET_MATTE_COLLISION_LAYER so shots pass through.
	if street_matte_body != null and is_instance_valid(street_matte_body):
		street_matte_body.queue_free()
	street_matte_body = StaticBody3D.new()
	street_matte_body.name = "StreetMatteWall"
	street_matte_body.collision_layer = STREET_MATTE_COLLISION_LAYER
	street_matte_body.collision_mask = 0
	street_matte_body.position = backdrop.position
	street_matte_body.rotation_degrees = backdrop.rotation_degrees
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(STREET_MATTE_BASE_SIZE.x, STREET_MATTE_BASE_SIZE.y, 0.18)
	wall_shape.shape = wall_box
	street_matte_body.add_child(wall_shape)
	outdoor.add_child(street_matte_body)


func _build_first_sale_decal() -> void:
	## Framed "FIRST SALE!" plaque on the interior lintel — covers the wall Glock.
	if first_sale_decal != null and is_instance_valid(first_sale_decal):
		first_sale_decal.queue_free()
		first_sale_decal = null
	sale_area = null
	sale_held = false
	const TEX_PATH := "res://assets/decal/first_sale.png"
	if not ResourceLoader.exists(TEX_PATH):
		push_warning("First Sale texture missing: %s" % TEX_PATH)
		return
	var tex := load(TEX_PATH) as Texture2D
	if tex == null:
		push_warning("First Sale texture failed to load")
		return
	var plaque := MeshInstance3D.new()
	plaque.name = "FirstSaleDecal"
	var quad := QuadMesh.new()
	quad.size = FIRST_SALE_BASE_SIZE
	plaque.mesh = quad
	sale_home = Vector3(FIRST_SALE_DEFAULT_X, FIRST_SALE_DEFAULT_Y, FIRST_SALE_DEFAULT_Z)
	plaque.position = sale_home
	## Face the cook (camera looks +Z through the window).
	plaque.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	plaque.scale = Vector3(FIRST_SALE_DEFAULT_SCALE, FIRST_SALE_DEFAULT_SCALE, 1.0)
	var mat := StandardMaterial3D.new()
	## Flat/unshaded bill — not a shadow caster. Depth pre-pass still hides the gun behind it.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.albedo_texture = tex
	## ~50% darker than the prior bright (0.72) tint.
	mat.albedo_color = Color(0.30, 0.30, 0.30, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mat.render_priority = 0
	plaque.material_override = mat
	plaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plaque.sorting_offset = 0.5
	world.add_child(plaque)
	first_sale_decal = plaque

	## Grab volume — drag the bill aside to reveal the Glock.
	sale_area = Area3D.new()
	sale_area.name = "FirstSaleGrab"
	sale_area.input_ray_pickable = true
	sale_area.collision_layer = SALE_COLLISION_LAYER
	sale_area.collision_mask = 0
	sale_area.monitoring = false
	sale_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FIRST_SALE_BASE_SIZE.x * 0.95, FIRST_SALE_BASE_SIZE.y * 0.95, 0.08)
	shape.shape = box
	shape.position = Vector3.ZERO
	sale_area.add_child(shape)
	plaque.add_child(sale_area)
	_refresh_glock_cover_lock()


func _sale_covers_glock() -> bool:
	## Gun stays locked until the First Sale plaque is slid clear of the mount.
	if sale_held:
		## Still dragging — only unlock once the bill has cleared the gun.
		pass
	if first_sale_decal == null or not is_instance_valid(first_sale_decal):
		return false
	var sc := first_sale_decal.scale.x
	var half_w := FIRST_SALE_BASE_SIZE.x * sc * 0.52
	var half_h := FIRST_SALE_BASE_SIZE.y * sc * 0.52
	var p := first_sale_decal.global_position
	var g := glock_home
	return absf(p.x - g.x) <= half_w and absf(p.y - g.y) <= half_h


func _refresh_glock_cover_lock() -> void:
	if glock_area == null or not is_instance_valid(glock_area):
		return
	var covered := _sale_covers_glock()
	## Can't ray-pick the gun while the plaque still covers it.
	glock_area.input_ray_pickable = not glock_held and not covered
	## Hide mesh while covered so transparent sorting can't draw it over the bill.
	if not glock_held:
		_set_glock_cover_meshes_visible(not covered)


func _set_glock_cover_meshes_visible(on: bool) -> void:
	if glock_visual != null and is_instance_valid(glock_visual):
		glock_visual.visible = on
	if glock_rear_sight_l != null and is_instance_valid(glock_rear_sight_l):
		glock_rear_sight_l.visible = on
	if glock_rear_sight_r != null and is_instance_valid(glock_rear_sight_r):
		glock_rear_sight_r.visible = on
	if glock_laser_module != null and is_instance_valid(glock_laser_module):
		glock_laser_module.visible = on
	if not on:
		_set_glock_laser_visible(false)


func _begin_sale_hold() -> bool:
	if not playing or sale_held or first_sale_decal == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or cup_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	sale_held = true
	if sale_area:
		sale_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Slide the First Sale plaque — Glock is behind it", Color("FFE082"))
	return true


func _update_held_sale(_delta: float) -> void:
	if first_sale_decal == null or camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	## Slide on the lintel plane (fixed Z toward the cook side of the wall).
	var plane_z := FIRST_SALE_DEFAULT_Z
	if absf(dir.z) < 0.002:
		return
	var t := (plane_z - from.z) / dir.z
	if t < 0.05:
		return
	var hit := from + dir * t
	hit.x = clampf(hit.x, -1.6, 1.6)
	hit.y = clampf(hit.y, 1.85, 2.75)
	hit.z = plane_z
	first_sale_decal.position = hit
	_refresh_glock_cover_lock()


func _release_sale_plaque() -> void:
	if not sale_held or first_sale_decal == null:
		return
	sale_held = false
	## Leave it where you dragged it (gun stays revealed until you cover it again).
	sale_home = first_sale_decal.position
	if sale_area:
		sale_area.input_ray_pickable = true
	_refresh_glock_cover_lock()
	if game_audio:
		game_audio.play_click()
	if _sale_covers_glock():
		_flash("Glock still covered — slide the plaque aside", Color("FFCC80"))
	else:
		_flash("Glock unlocked", Color("FFE082"))


func _build_wall_paper_decals() -> void:
	## Business license, health certificate, and beach photo — camera-right of First Sale.
	if wall_paper_decals != null and is_instance_valid(wall_paper_decals):
		wall_paper_decals.queue_free()
		wall_paper_decals = null
	var root := Node3D.new()
	root.name = "WallPaperDecals"
	world.add_child(root)
	wall_paper_decals = root
	## Camera-right = world −X. Cluster sits just past the First Sale plaque edge.
	## Sheet order left→right: license, health cert, beach polaroid.
	var specs: Array = [
		{
			"name": "BusinessLicense",
			"path": "res://assets/decal/business_license.png",
			"size": Vector2(0.40, 0.333),
			## +6" up, +6" camera-right (−X).
			"pos": Vector3(-0.732, 2.372, WALL_PAPER_Z),
		},
		{
			"name": "HealthCertificate",
			"path": "res://assets/decal/health_certificate.png",
			"size": Vector2(0.30, 0.254),
			"pos": Vector3(-1.112, 2.452, WALL_PAPER_Z),
		},
		{
			"name": "BeachPhoto",
			"path": "res://assets/decal/beach_photo.png",
			"size": Vector2(0.175, 0.163),
			"pos": Vector3(-1.372, 2.292, WALL_PAPER_Z),
		},
	]
	for spec in specs:
		_add_wall_paper_decal(
			root,
			String(spec["name"]),
			String(spec["path"]),
			spec["size"] as Vector2,
			spec["pos"] as Vector3
		)


func _add_wall_paper_decal(
	parent: Node3D, decal_name: String, tex_path: String, size: Vector2, pos: Vector3
) -> void:
	if not ResourceLoader.exists(tex_path):
		push_warning("Wall paper texture missing: %s" % tex_path)
		return
	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_warning("Wall paper texture failed to load: %s" % tex_path)
		return
	var mi := MeshInstance3D.new()
	mi.name = decal_name
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	mi.position = pos
	mi.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = WALL_PAPER_ALBEDO
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 6
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_menu_board_decal() -> void:
	## Full menu poster on the left front wall beside the window (camera-visible).
	if menu_board_decal != null and is_instance_valid(menu_board_decal):
		menu_board_decal.queue_free()
		menu_board_decal = null
	const TEX_PATH := "res://assets/decal/menu_board.png"
	if not ResourceLoader.exists(TEX_PATH):
		push_warning("Menu board texture missing: %s" % TEX_PATH)
		return
	var tex := load(TEX_PATH) as Texture2D
	if tex == null:
		push_warning("Menu board texture failed to load")
		return
	var board := MeshInstance3D.new()
	board.name = "MenuBoardDecal"
	var quad := QuadMesh.new()
	quad.size = MENU_BOARD_BASE_SIZE
	board.mesh = quad
	board.position = Vector3(MENU_BOARD_DEFAULT_X, MENU_BOARD_DEFAULT_Y, MENU_BOARD_DEFAULT_Z)
	## Face the cook from the front wall.
	board.rotation_degrees = Vector3(0.0, MENU_BOARD_DEFAULT_YAW, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = DECAL_ALBEDO
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 8
	board.material_override = mat
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(board)
	menu_board_decal = board


func _build_soda_station() -> void:
	## Compact fountain (~½ old height) with clear flavor tanks on top.
	if soda_root != null and is_instance_valid(soda_root):
		soda_root.queue_free()
	soda_root = null
	if cup_root != null and is_instance_valid(cup_root):
		cup_root.queue_free()
	if soda_stream_mesh != null and is_instance_valid(soda_stream_mesh):
		soda_stream_mesh.queue_free()
	soda_flavor_areas.clear()
	soda_flavor_mats.clear()
	soda_spout_marker = null
	ice_spout_marker = null
	cup_root = null
	cup_area = null
	cup_shell_mesh = null
	cup_liquid_mesh = null
	cup_liquid_mat = null
	cup_liquid_pivot = null
	cup_liquid_surface = null
	cup_ice_root = null
	soda_stream_mesh = null
	soda_stream_mat = null
	_cup_ice_spawn_cd = 0.0
	_cup_prev_pos = Vector3.ZERO
	_cup_vel = Vector3.ZERO
	_cup_slosh = Vector2.ZERO
	_cup_splash_cd = 0.0
	cup_held = false
	cup_flavor = ""
	cup_soda_fill = 0.0
	cup_ice_fill = 0.0
	soda_selected_flavor = "cola"

	var root := Node3D.new()
	root.name = "SodaStation"
	root.position = SODA_STATION_POS
	root.rotation_degrees = SODA_STATION_ROT
	world.add_child(root)
	soda_root = root

	## Short stainless cabinet.
	var body := MeshInstance3D.new()
	body.name = "Cabinet"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.70, 0.46, 0.36)
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.23, 0.0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.82, 0.84, 0.88)
	body_mat.metallic = 0.55
	body_mat.roughness = 0.32
	body.material_override = body_mat
	root.add_child(body)

	## Toe kick / base skirt.
	var skirt := MeshInstance3D.new()
	skirt.name = "Skirt"
	var skirt_mesh := BoxMesh.new()
	skirt_mesh.size = Vector3(0.72, 0.06, 0.38)
	skirt.mesh = skirt_mesh
	skirt.position = Vector3(0.0, 0.03, 0.0)
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.22, 0.24, 0.28)
	skirt_mat.metallic = 0.4
	skirt_mat.roughness = 0.5
	skirt.material_override = skirt_mat
	root.add_child(skirt)

	## Deck plate the tanks sit on.
	var deck := MeshInstance3D.new()
	deck.name = "TankDeck"
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(0.68, 0.03, 0.34)
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, 0.475, 0.0)
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.62, 0.65, 0.70)
	deck_mat.metallic = 0.75
	deck_mat.roughness = 0.25
	deck.material_override = deck_mat
	root.add_child(deck)

	## Chrome pour face.
	var face := MeshInstance3D.new()
	face.name = "Face"
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.62, 0.20, 0.04)
	face.mesh = face_mesh
	face.position = Vector3(0.0, 0.34, 0.19)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.58, 0.60, 0.66)
	face_mat.metallic = 0.85
	face_mat.roughness = 0.22
	face.material_override = face_mat
	root.add_child(face)

	## Clear tinted syrup tanks on top — one per flavor, with rising bubbles.
	var tank_xs: Array[float] = [-0.22, 0.0, 0.22]
	for i in SODA_FLAVORS.size():
		var fid: String = SODA_FLAVORS[i]
		var tank := _add_soda_flavor_tank(root, fid, Vector3(tank_xs[i], 0.62, 0.0))
		soda_flavor_mats[fid] = tank

		## Small lit select pad on the face under each tank.
		var pad := MeshInstance3D.new()
		pad.name = "FlavorPad_%s" % fid
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(0.14, 0.07, 0.03)
		pad.mesh = pad_mesh
		pad.position = Vector3(tank_xs[i], 0.34, 0.22)
		var pmat := StandardMaterial3D.new()
		var base_col: Color = SODA_FLAVOR_COLORS[fid]
		pmat.albedo_color = base_col
		pmat.emission_enabled = true
		pmat.emission = base_col
		pmat.emission_energy_multiplier = 0.55 if fid == soda_selected_flavor else 0.10
		pad.material_override = pmat
		root.add_child(pad)
		## Keep pad mat as secondary key for light refresh (tank liquid is primary).
		soda_flavor_mats["pad_%s" % fid] = pmat

		var lab := Label3D.new()
		lab.text = str(SODA_FLAVOR_LABELS.get(fid, fid.to_upper()))
		lab.position = Vector3(tank_xs[i], 0.34, 0.245)
		lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lab.font_size = 14
		lab.pixel_size = 0.0014
		lab.modulate = Color(1, 1, 1, 0.95)
		lab.outline_size = 2
		lab.outline_modulate = Color(0, 0, 0, 0.8)
		root.add_child(lab)

		var area := Area3D.new()
		area.name = "FlavorArea_%s" % fid
		area.input_ray_pickable = true
		area.collision_layer = SODA_FLAVOR_COLLISION_LAYER
		area.collision_mask = 0
		area.monitoring = false
		area.monitorable = true
		## Tall click volume covering tank + pad.
		area.position = Vector3(tank_xs[i], 0.50, 0.10)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.18, 0.42, 0.28)
		shape.shape = box
		area.add_child(shape)
		root.add_child(area)
		soda_flavor_areas[fid] = area

	## Spouts hang from the pour lip.
	_add_soda_spout(root, "SodaSpout", Vector3(-0.13, 0.26, 0.26), Color(0.85, 0.22, 0.18), true)
	_add_soda_spout(root, "IceSpout", Vector3(0.13, 0.26, 0.26), Color(0.55, 0.82, 1.0), false)

	var tray := MeshInstance3D.new()
	tray.name = "DripTray"
	var tray_mesh := BoxMesh.new()
	tray_mesh.size = Vector3(0.50, 0.03, 0.22)
	tray.mesh = tray_mesh
	tray.position = Vector3(0.0, 0.09, 0.24)
	var tray_mat := StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.24, 0.26, 0.30)
	tray_mat.metallic = 0.6
	tray_mat.roughness = 0.38
	tray.material_override = tray_mat
	root.add_child(tray)

	## Grate lines on the drip tray.
	for gi in 4:
		var grate := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.46, 0.006, 0.012)
		grate.mesh = gm
		grate.position = Vector3(0.0, 0.108, 0.16 + float(gi) * 0.04)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.45, 0.48, 0.52)
		gmat.metallic = 0.7
		grate.material_override = gmat
		root.add_child(grate)

	var soda_lab := Label3D.new()
	soda_lab.text = "SODA"
	soda_lab.position = Vector3(-0.13, 0.40, 0.28)
	soda_lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	soda_lab.font_size = 13
	soda_lab.pixel_size = 0.0013
	soda_lab.modulate = Color(1.0, 0.55, 0.5)
	soda_lab.outline_size = 2
	soda_lab.outline_modulate = Color(0, 0, 0, 0.75)
	root.add_child(soda_lab)
	var ice_lab := Label3D.new()
	ice_lab.text = "ICE"
	ice_lab.position = Vector3(0.13, 0.40, 0.28)
	ice_lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ice_lab.font_size = 13
	ice_lab.pixel_size = 0.0013
	ice_lab.modulate = Color(0.7, 0.9, 1.0)
	ice_lab.outline_size = 2
	ice_lab.outline_modulate = Color(0, 0, 0, 0.75)
	root.add_child(ice_lab)

	var lamp := OmniLight3D.new()
	lamp.name = "SodaLamp"
	lamp.light_color = Color(1.0, 0.96, 0.90)
	lamp.light_energy = 0.7
	lamp.omni_range = 1.1
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 0.85, 0.40)
	root.add_child(lamp)

	_build_soda_cup_rack(root)
	_refresh_soda_flavor_lights()


func _add_soda_flavor_tank(parent: Node3D, flavor_id: String, local_pos: Vector3) -> StandardMaterial3D:
	## Clear cylinder with tinted syrup + rising bubbles. Returns liquid mat for select glow.
	var tank := Node3D.new()
	tank.name = "Tank_%s" % flavor_id
	tank.position = local_pos
	parent.add_child(tank)

	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.085
	glass_mesh.bottom_radius = 0.085
	glass_mesh.height = 0.26
	glass.mesh = glass_mesh
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.18)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.05
	glass_mat.metallic = 0.15
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = glass_mat
	tank.add_child(glass)

	var liquid := MeshInstance3D.new()
	liquid.name = "Syrup"
	var liq_mesh := CylinderMesh.new()
	liq_mesh.top_radius = 0.072
	liq_mesh.bottom_radius = 0.072
	liq_mesh.height = 0.20
	liquid.mesh = liq_mesh
	liquid.position = Vector3(0.0, -0.015, 0.0)
	var liq_mat := StandardMaterial3D.new()
	var col: Color = SODA_FLAVOR_COLORS.get(flavor_id, Color(0.4, 0.2, 0.15))
	col.a = 0.55
	liq_mat.albedo_color = col
	liq_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liq_mat.roughness = 0.12
	liq_mat.metallic = 0.05
	liq_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	liq_mat.emission_enabled = true
	liq_mat.emission = Color(col.r, col.g, col.b)
	liq_mat.emission_energy_multiplier = 0.35 if flavor_id == soda_selected_flavor else 0.12
	liquid.material_override = liq_mat
	tank.add_child(liquid)

	## Chrome lid + neck.
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = 0.088
	lid_mesh.bottom_radius = 0.088
	lid_mesh.height = 0.028
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.14, 0.0)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.72, 0.74, 0.78)
	lid_mat.metallic = 0.9
	lid_mat.roughness = 0.2
	lid.material_override = lid_mat
	tank.add_child(lid)

	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.03
	neck_mesh.bottom_radius = 0.035
	neck_mesh.height = 0.04
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 0.17, 0.0)
	neck.material_override = lid_mat
	tank.add_child(neck)

	var tag := Label3D.new()
	tag.text = str(SODA_FLAVOR_LABELS.get(flavor_id, flavor_id.to_upper()))
	tag.position = Vector3(0.0, 0.02, 0.09)
	tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	tag.font_size = 15
	tag.pixel_size = 0.0015
	tag.modulate = Color(1, 1, 1, 0.95)
	tag.outline_size = 3
	tag.outline_modulate = Color(0, 0, 0, 0.75)
	tank.add_child(tag)

	_add_soda_tank_bubbles(tank, col)
	return liq_mat


func _add_soda_tank_bubbles(tank: Node3D, syrup_col: Color) -> void:
	var fx := GPUParticles3D.new()
	fx.name = "Bubbles"
	fx.amount = 22
	fx.lifetime = 1.5
	fx.preprocess = 0.8
	fx.explosiveness = 0.0
	fx.randomness = 0.35
	fx.emitting = true
	fx.position = Vector3(0.0, -0.08, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.11
	pm.gravity = Vector3(0, 0.015, 0)
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.scale_min = 0.35
	pm.scale_max = 0.85
	var bubble_col := Color(
		lerpf(1.0, syrup_col.r, 0.25),
		lerpf(1.0, syrup_col.g, 0.25),
		lerpf(1.0, syrup_col.b, 0.25),
		0.65
	)
	pm.color = bubble_col
	fx.process_material = pm
	var draw := StandardMaterial3D.new()
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.albedo_color = bubble_col
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 0.007
	sphere.height = 0.014
	sphere.material = draw
	fx.draw_pass_1 = sphere
	## Keep bubbles inside the tank glass.
	fx.visibility_aabb = AABB(Vector3(-0.1, -0.05, -0.1), Vector3(0.2, 0.28, 0.2))
	tank.add_child(fx)


func _add_soda_spout(parent: Node3D, spout_name: String, local_pos: Vector3, col: Color, is_soda: bool) -> void:
	var spout := MeshInstance3D.new()
	spout.name = spout_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.022
	cyl.height = 0.11
	spout.mesh = cyl
	spout.position = local_pos
	var sm := StandardMaterial3D.new()
	sm.albedo_color = col
	sm.metallic = 0.7
	sm.roughness = 0.35
	sm.emission_enabled = true
	sm.emission = col
	sm.emission_energy_multiplier = 0.25
	spout.material_override = sm
	parent.add_child(spout)

	var tip := Marker3D.new()
	tip.name = "%sTip" % spout_name
	tip.position = local_pos + Vector3(0.0, -0.10, 0.04)
	parent.add_child(tip)
	if is_soda:
		soda_spout_marker = tip
	else:
		ice_spout_marker = tip


func _build_soda_cup_rack(station: Node3D) -> void:
	## Peg board + stacked cups beside the fountain — upright, bright, labeled.
	var rack := Node3D.new()
	rack.name = "CupRack"
	## With yaw 180 on the right side, local −X faces the grill (world +X).
	rack.position = Vector3(-0.52, 0.32, 0.18)
	station.add_child(rack)

	var board := MeshInstance3D.new()
	board.name = "CupBoard"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.18, 0.40, 0.04)
	board.mesh = board_mesh
	board.position = Vector3(0.0, 0.0, -0.02)
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.42, 0.32, 0.24)
	board.material_override = board_mat
	rack.add_child(board)

	## Decorative stack of spare clear cups (always visible).
	for i in 3:
		var spare := MeshInstance3D.new()
		spare.name = "SpareCup_%d" % i
		var spare_mesh := CylinderMesh.new()
		spare_mesh.top_radius = 0.040
		spare_mesh.bottom_radius = 0.034
		spare_mesh.height = 0.09
		spare.mesh = spare_mesh
		spare.position = Vector3(0.0, 0.12 - float(i) * 0.038, 0.05)
		spare.material_override = _make_clear_cup_material(0.22)
		rack.add_child(spare)

	var cup_lab := Label3D.new()
	cup_lab.text = "CUPS"
	cup_lab.position = Vector3(0.0, 0.26, 0.07)
	cup_lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	cup_lab.font_size = 14
	cup_lab.pixel_size = 0.0014
	cup_lab.modulate = Color(1.0, 0.95, 0.7)
	cup_lab.outline_size = 2
	cup_lab.outline_modulate = Color(0, 0, 0, 0.75)
	rack.add_child(cup_lab)

	## Grabable cup — upright in world space (not inheriting wall yaw as a sideways peg).
	if cup_root != null and is_instance_valid(cup_root):
		cup_root.queue_free()
	cup_root = Node3D.new()
	cup_root.name = "DrinkCup"
	cup_home = station.to_global(rack.position + Vector3(0.0, -0.06, 0.08))
	cup_home_rot = Vector3.ZERO
	world.add_child(cup_root)
	cup_root.global_position = cup_home
	cup_root.rotation_degrees = cup_home_rot

	var cup_shell := MeshInstance3D.new()
	cup_shell.name = "Shell"
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = 0.055
	shell_mesh.bottom_radius = 0.045
	shell_mesh.height = 0.14
	## Open top — no end caps so you don't get a solid lid / double-wall ghost.
	shell_mesh.cap_top = false
	shell_mesh.cap_bottom = true
	cup_shell.mesh = shell_mesh
	cup_shell.position = Vector3(0.0, 0.07, 0.0)
	cup_shell.material_override = _make_clear_cup_material(0.32)
	cup_root.add_child(cup_shell)
	cup_shell_mesh = cup_shell

	## Thin red band so the clear cup still reads as a grab target.
	var stripe := MeshInstance3D.new()
	stripe.name = "Stripe"
	var stripe_mesh := CylinderMesh.new()
	stripe_mesh.top_radius = 0.0565
	stripe_mesh.bottom_radius = 0.0565
	stripe_mesh.height = 0.016
	stripe_mesh.cap_top = false
	stripe_mesh.cap_bottom = false
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, 0.10, 0.0)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.92, 0.22, 0.18, 0.95)
	stripe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stripe_mat.roughness = 0.4
	stripe_mat.cull_mode = BaseMaterial3D.CULL_BACK
	stripe.material_override = stripe_mat
	cup_root.add_child(stripe)

	cup_liquid_pivot = Node3D.new()
	cup_liquid_pivot.name = "LiquidPivot"
	cup_liquid_pivot.position = Vector3(0.0, 0.02, 0.0)
	cup_root.add_child(cup_liquid_pivot)

	cup_liquid_mesh = MeshInstance3D.new()
	cup_liquid_mesh.name = "Liquid"
	var liq := CylinderMesh.new()
	liq.top_radius = 0.042
	liq.bottom_radius = 0.038
	liq.height = 0.02
	liq.cap_top = true
	liq.cap_bottom = true
	cup_liquid_mesh.mesh = liq
	cup_liquid_mesh.position = Vector3(0.0, 0.01, 0.0)
	cup_liquid_mesh.visible = false
	cup_liquid_mat = StandardMaterial3D.new()
	cup_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cup_liquid_mat.roughness = 0.18
	cup_liquid_mat.metallic = 0.0
	cup_liquid_mat.cull_mode = BaseMaterial3D.CULL_BACK
	cup_liquid_mesh.material_override = cup_liquid_mat
	cup_liquid_pivot.add_child(cup_liquid_mesh)

	cup_liquid_surface = MeshInstance3D.new()
	cup_liquid_surface.name = "LiquidSurface"
	var surf := CylinderMesh.new()
	surf.top_radius = 0.043
	surf.bottom_radius = 0.043
	surf.height = 0.004
	cup_liquid_surface.mesh = surf
	cup_liquid_surface.visible = false
	var surf_mat := StandardMaterial3D.new()
	surf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf_mat.albedo_color = Color(1, 1, 1, 0.35)
	surf_mat.roughness = 0.05
	surf_mat.cull_mode = BaseMaterial3D.CULL_BACK
	cup_liquid_surface.material_override = surf_mat
	cup_liquid_pivot.add_child(cup_liquid_surface)

	cup_ice_root = Node3D.new()
	cup_ice_root.name = "IceStack"
	cup_root.add_child(cup_ice_root)

	soda_stream_mesh = MeshInstance3D.new()
	soda_stream_mesh.name = "SodaStream"
	var stream_cyl := CylinderMesh.new()
	stream_cyl.top_radius = 0.006
	stream_cyl.bottom_radius = 0.009
	stream_cyl.height = 0.1
	stream_cyl.cap_top = false
	stream_cyl.cap_bottom = false
	soda_stream_mesh.mesh = stream_cyl
	soda_stream_mat = StandardMaterial3D.new()
	soda_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soda_stream_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soda_stream_mat.albedo_color = Color(0.45, 0.18, 0.12, 0.75)
	soda_stream_mat.cull_mode = BaseMaterial3D.CULL_BACK
	soda_stream_mesh.material_override = soda_stream_mat
	soda_stream_mesh.visible = false
	soda_stream_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(soda_stream_mesh)

	cup_area = Area3D.new()
	cup_area.name = "CupGrab"
	cup_area.input_ray_pickable = true
	cup_area.collision_layer = CUP_COLLISION_LAYER
	cup_area.collision_mask = 0
	cup_area.monitoring = false
	cup_area.monitorable = true
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(0.12, 0.16, 0.12)
	cshape.shape = cbox
	cshape.position = Vector3(0.0, 0.07, 0.0)
	cup_area.add_child(cshape)
	cup_root.add_child(cup_area)


func _make_clear_cup_material(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.90, 0.98, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.06
	mat.metallic = 0.08
	## Back-face only — dual-sided clear cylinders read as a ghosted double cup.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.refraction_enabled = false
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.75, 0.95)
	mat.emission_energy_multiplier = 0.05
	return mat


func _refresh_soda_flavor_lights() -> void:
	for key in soda_flavor_mats.keys():
		var mat: StandardMaterial3D = soda_flavor_mats[key]
		if mat == null:
			continue
		var fid := str(key)
		if fid.begins_with("pad_"):
			fid = fid.substr(4)
		var selected := fid == soda_selected_flavor
		mat.emission_enabled = true
		if str(key).begins_with("pad_"):
			mat.emission_energy_multiplier = 0.6 if selected else 0.08
		else:
			## Tank syrup — brighter when that flavor is armed.
			mat.emission_energy_multiplier = 0.45 if selected else 0.12
			var col: Color = SODA_FLAVOR_COLORS.get(fid, Color(0.4, 0.2, 0.15))
			col.a = 0.58 if selected else 0.48
			mat.albedo_color = col
			mat.emission = Color(col.r, col.g, col.b)


func _try_soda_flavor_click(screen_pos: Vector2) -> bool:
	if camera == null or soda_flavor_areas.is_empty():
		return false
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 20.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = SODA_FLAVOR_COLLISION_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		## Fallback: nearest pad by screen distance.
		var best_id := ""
		var best_d := 48.0
		for fid in soda_flavor_areas.keys():
			var area: Area3D = soda_flavor_areas[fid]
			if area == null or not is_instance_valid(area):
				continue
			var d := screen_pos.distance_to(camera.unproject_position(area.global_position))
			if d < best_d:
				best_d = d
				best_id = str(fid)
		if best_id == "":
			return false
		_set_soda_flavor(best_id)
		return true
	var col = hit.get("collider")
	for fid in soda_flavor_areas.keys():
		if soda_flavor_areas[fid] == col:
			_set_soda_flavor(str(fid))
			return true
	return false


func _set_soda_flavor(fid: String) -> void:
	if not SODA_FLAVORS.has(fid):
		return
	soda_selected_flavor = fid
	_refresh_soda_flavor_lights()
	if game_audio:
		game_audio.play_click()
	_flash("Flavor: %s" % str(SODA_FLAVOR_LABELS.get(fid, fid)), Color("FFE082"))


func _begin_cup_hold() -> bool:
	if not playing or cup_held or cup_root == null:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held \
			or ext_held or glock_held or sale_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("FFCC80"))
		return false
	cup_held = true
	_cup_prev_pos = cup_root.global_position
	_cup_vel = Vector3.ZERO
	_cup_slosh = Vector2.ZERO
	_cup_splash_cd = 0.0
	if cup_area:
		cup_area.input_ray_pickable = false
	if game_audio:
		game_audio.play_click()
	_flash("Hold under SODA / ICE — release to put down", Color("80DEEA"))
	return true


func _cup_hold_point_from_screen(screen_pos: Vector2) -> Vector3:
	## Carry along the camera ray so the cup tracks the cursor (not stuck on a flat plane).
	if camera == null:
		return Vector3.ZERO
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit := from + dir * CUP_HOLD_DIST
	hit.x = clampf(hit.x, -2.85, 0.55)
	hit.z = clampf(hit.z, -0.35, 1.15)
	hit.y = clampf(hit.y, GRILL_SURFACE_Y + 0.06, GRILL_SURFACE_Y + 0.62)
	## Soft magnet toward a spout tip when close — easier to fill.
	var best_tip: Vector3 = Vector3.ZERO
	var best_d := 0.70
	for tip in [soda_spout_marker, ice_spout_marker]:
		if tip == null or not is_instance_valid(tip):
			continue
		var tpos: Vector3 = tip.global_position + Vector3(0.0, -0.08, 0.0)
		var d := hit.distance_to(tpos)
		if d < best_d:
			best_d = d
			best_tip = tpos
	if best_tip != Vector3.ZERO and best_d < 0.62:
		var pull := clampf(1.0 - best_d / 0.62, 0.0, 1.0) * 0.72
		hit = hit.lerp(best_tip, pull)
	return hit


func _cup_under_spout(tip: Vector3, rim: Vector3) -> bool:
	## Prefer horizontal aim under the nozzle; allow generous vertical slack.
	var horiz := Vector2(tip.x - rim.x, tip.z - rim.z).length()
	var vert := absf(tip.y - rim.y)
	return horiz <= CUP_SPOUT_HORIZ and vert <= CUP_SPOUT_VERT


func _update_held_cup(delta: float) -> void:
	if cup_root == null or camera == null:
		return
	var seat := _cup_hold_point_from_screen(get_viewport().get_mouse_position())
	if seat != Vector3.ZERO:
		## Smooth follow so motion reads as carrying, not teleporting.
		var prev := cup_root.global_position
		cup_root.global_position = prev.lerp(seat, clampf(delta * 18.0, 0.0, 1.0))
		if delta > 0.0001:
			_cup_vel = (cup_root.global_position - _cup_prev_pos) / delta
		_cup_prev_pos = cup_root.global_position
	## Mild cup tilt from motion + resting tip.
	var tip_x := clampf(-_cup_vel.z * 4.0, -18.0, 18.0)
	var tip_z := clampf(_cup_vel.x * 4.0, -18.0, 18.0)
	cup_root.rotation_degrees = Vector3(-8.0 + tip_x * 0.15, 12.0, tip_z * 0.2)
	_update_cup_slosh(delta)
	_try_fill_cup_at_spouts(delta)


func _update_cup_slosh(delta: float) -> void:
	## Liquid leans opposite to lateral acceleration; whip hard → splash & lose soda.
	var target := Vector2(
		clampf(-_cup_vel.x * 3.2, -22.0, 22.0),
		clampf(_cup_vel.z * 3.2, -22.0, 22.0)
	)
	_cup_slosh = _cup_slosh.lerp(target, clampf(delta * CUP_SLOSH_FOLLOW, 0.0, 1.0))
	_cup_slosh = _cup_slosh.lerp(Vector2.ZERO, clampf(delta * CUP_SLOSH_RETURN, 0.0, 1.0))
	if cup_liquid_pivot != null and is_instance_valid(cup_liquid_pivot):
		cup_liquid_pivot.rotation_degrees = Vector3(_cup_slosh.y, 0.0, _cup_slosh.x)
	_cup_splash_cd = maxf(0.0, _cup_splash_cd - delta)
	var speed := _cup_vel.length()
	var lean := _cup_slosh.length()
	if cup_soda_fill > 0.05 and _cup_splash_cd <= 0.0 \
			and (speed > CUP_SPLASH_SPEED or lean > 16.0):
		_cup_splash_cd = 0.22
		var loss := CUP_SPLASH_LOSS * (1.0 + clampf((speed - CUP_SPLASH_SPEED) * 0.35, 0.0, 1.5))
		cup_soda_fill = maxf(0.0, cup_soda_fill - loss)
		if cup_soda_fill < 0.02:
			cup_soda_fill = 0.0
		_spawn_cup_splash_drops()
		_refresh_cup_visuals()
		if cup_soda_fill <= 0.0:
			_flash("Spilled the drink!", Color("FFAB91"))
		elif loss > 0.08:
			_flash("Whoa — spilled some!", Color("FFCC80"))


func _spawn_cup_splash_drops() -> void:
	if cup_root == null or world == null or cup_flavor == "":
		return
	var origin := cup_root.global_position + Vector3(0.0, 0.12, 0.0)
	var col: Color = SODA_FLAVOR_COLORS.get(cup_flavor, Color(0.4, 0.2, 0.15))
	col.a = 0.85
	for i in 7:
		var drop := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = randf_range(0.006, 0.012)
		sph.height = sph.radius * 2.0
		drop.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.material_override = mat
		world.add_child(drop)
		drop.global_position = origin + Vector3(randf_range(-0.03, 0.03), 0.02, randf_range(-0.03, 0.03))
		var fling := _cup_vel.normalized() * randf_range(0.15, 0.45) if _cup_vel.length() > 0.05 \
				else Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
		fling.y = randf_range(0.12, 0.35)
		var end_p := drop.global_position + fling + Vector3(0.0, -0.25, 0.0)
		var life := randf_range(0.28, 0.45)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "global_position", end_p, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(drop, "scale", Vector3.ONE * 0.2, life)
		tw.chain().tween_callback(drop.queue_free)


func _try_fill_cup_at_spouts(delta: float) -> void:
	if cup_root == null:
		_hide_soda_stream()
		return
	var rim := cup_root.global_position + Vector3(0.0, 0.13, 0.0)
	var pouring_soda := false
	var pouring_ice := false
	if soda_spout_marker != null and is_instance_valid(soda_spout_marker):
		var soda_tip: Vector3 = soda_spout_marker.global_position
		if _cup_under_spout(soda_tip, rim):
			var before := cup_soda_fill
			if cup_flavor != "" and cup_flavor != soda_selected_flavor and cup_soda_fill > 0.05:
				_flash("Empty / return cup first — wrong flavor", Color("FFAB91"))
				_hide_soda_stream()
			else:
				cup_flavor = soda_selected_flavor
				cup_soda_fill = minf(1.0, cup_soda_fill + CUP_FILL_RATE * delta)
				pouring_soda = true
				_update_soda_stream(soda_tip, rim, cup_flavor)
				if before < 1.0 and cup_soda_fill >= 1.0:
					_flash("%s filled!" % str(SODA_FLAVOR_LABELS.get(cup_flavor, "SODA")), Color("FF8A65"))
		else:
			_hide_soda_stream()
	else:
		_hide_soda_stream()
	if ice_spout_marker != null and is_instance_valid(ice_spout_marker):
		var ice_tip: Vector3 = ice_spout_marker.global_position
		if _cup_under_spout(ice_tip, rim):
			var before_i := cup_ice_fill
			cup_ice_fill = minf(1.0, cup_ice_fill + CUP_FILL_RATE * delta)
			pouring_ice = cup_ice_fill < 1.0 or before_i < 1.0
			_cup_ice_spawn_cd -= delta
			if pouring_ice and _cup_ice_spawn_cd <= 0.0 and cup_ice_fill < 1.0:
				_cup_ice_spawn_cd = CUP_ICE_CUBE_INTERVAL
				_spawn_flying_ice_cube(ice_tip, rim)
			if before_i < 1.0 and cup_ice_fill >= 1.0:
				_flash("Ice topped off", Color("B3E5FC"))
	if pouring_soda or pouring_ice or cup_soda_fill > 0.0 or cup_ice_fill > 0.0:
		_refresh_cup_visuals()


func _update_soda_stream(from_tip: Vector3, to_rim: Vector3, flavor: String) -> void:
	if soda_stream_mesh == null or not is_instance_valid(soda_stream_mesh):
		return
	var delta_v := to_rim - from_tip
	var length := delta_v.length()
	if length < 0.03 or length > 0.7:
		_hide_soda_stream()
		return
	var mid := (from_tip + to_rim) * 0.5
	soda_stream_mesh.visible = true
	soda_stream_mesh.global_position = mid
	soda_stream_mesh.look_at(to_rim, Vector3.UP)
	soda_stream_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var cyl := soda_stream_mesh.mesh as CylinderMesh
	if cyl:
		cyl.height = length
		cyl.top_radius = 0.005
		cyl.bottom_radius = 0.009
	if soda_stream_mat != null:
		var col: Color = SODA_FLAVOR_COLORS.get(flavor, Color(0.4, 0.2, 0.15))
		col.a = 0.8
		soda_stream_mat.albedo_color = col


func _hide_soda_stream() -> void:
	if soda_stream_mesh != null and is_instance_valid(soda_stream_mesh):
		soda_stream_mesh.visible = false


func _spawn_flying_ice_cube(from_tip: Vector3, to_rim: Vector3) -> void:
	if world == null:
		return
	var cube := MeshInstance3D.new()
	cube.name = "FlyingIce"
	var box := BoxMesh.new()
	var s := randf_range(0.018, 0.028)
	box.size = Vector3(s, s * 0.85, s)
	cube.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.93, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.88, 1.0)
	mat.emission_energy_multiplier = 0.25
	cube.material_override = mat
	world.add_child(cube)
	var start := from_tip + Vector3(randf_range(-0.02, 0.02), 0.0, randf_range(-0.02, 0.02))
	var end := to_rim + Vector3(randf_range(-0.025, 0.025), randf_range(-0.02, 0.01), randf_range(-0.025, 0.025))
	var arc := (start + end) * 0.5 + Vector3(0.0, 0.07, 0.0)
	cube.global_position = start
	var spin := Vector3(randf_range(80, 160), randf_range(60, 140), randf_range(40, 100))
	cube.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
	var tw := create_tween()
	tw.tween_property(cube, "global_position", arc, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cube, "rotation_degrees", cube.rotation_degrees + spin, 0.27)
	tw.chain().tween_property(cube, "global_position", end, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(cube):
			cube.queue_free()
		_refresh_cup_ice_stack()
	)


func _refresh_cup_visuals() -> void:
	if cup_liquid_mesh != null and is_instance_valid(cup_liquid_mesh):
		if cup_soda_fill > 0.02 and cup_flavor != "":
			cup_liquid_mesh.visible = true
			var h := 0.016 + cup_soda_fill * 0.095
			var liq := cup_liquid_mesh.mesh as CylinderMesh
			if liq:
				liq.height = h
				liq.top_radius = 0.040 + cup_soda_fill * 0.004
				liq.bottom_radius = 0.036
			cup_liquid_mesh.position.y = h * 0.5
			if cup_liquid_mat != null:
				var col: Color = SODA_FLAVOR_COLORS.get(cup_flavor, Color(0.4, 0.2, 0.15))
				col.a = 0.82
				cup_liquid_mat.albedo_color = col
				cup_liquid_mat.emission_enabled = true
				cup_liquid_mat.emission = col
				cup_liquid_mat.emission_energy_multiplier = 0.15
			if cup_liquid_surface != null and is_instance_valid(cup_liquid_surface):
				cup_liquid_surface.visible = true
				cup_liquid_surface.position.y = h + 0.001
				var sm := cup_liquid_surface.material_override as StandardMaterial3D
				if sm:
					var sc: Color = SODA_FLAVOR_COLORS.get(cup_flavor, Color(0.4, 0.2, 0.15))
					sc = sc.lightened(0.25)
					sc.a = 0.45
					sm.albedo_color = sc
				var surf := cup_liquid_surface.mesh as CylinderMesh
				if surf:
					surf.top_radius = 0.041 + cup_soda_fill * 0.004
					surf.bottom_radius = surf.top_radius
		else:
			cup_liquid_mesh.visible = false
			if cup_liquid_surface != null and is_instance_valid(cup_liquid_surface):
				cup_liquid_surface.visible = false
	_refresh_cup_ice_stack()


func _refresh_cup_ice_stack() -> void:
	if cup_ice_root == null or not is_instance_valid(cup_ice_root):
		return
	var want := 0
	if cup_ice_fill > 0.05:
		want = clampi(int(ceil(cup_ice_fill * 6.0)), 1, 6)
	var have := cup_ice_root.get_child_count()
	if have != want:
		while cup_ice_root.get_child_count() > 0:
			var old: Node = cup_ice_root.get_child(0)
			cup_ice_root.remove_child(old)
			old.free()
		for i in want:
			var cube := MeshInstance3D.new()
			var box := BoxMesh.new()
			var s := 0.022 - float(i) * 0.001
			box.size = Vector3(s, s * 0.8, s)
			cube.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.92, 1.0, 0.82)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.1
			mat.metallic = 0.12
			cube.material_override = mat
			cup_ice_root.add_child(cube)
	_layout_cup_ice_cubes(want)


func _layout_cup_ice_cubes(count: int) -> void:
	if cup_ice_root == null:
		return
	var base_y := 0.045 + cup_soda_fill * 0.085
	var kids := cup_ice_root.get_children()
	for i in mini(count, kids.size()):
		var cube: Node3D = kids[i]
		var ang := float(i) * TAU / maxf(1.0, float(count))
		var r := 0.012 if count <= 2 else 0.018
		cube.position = Vector3(cos(ang) * r, base_y + float(i % 3) * 0.012, sin(ang) * r)
		cube.rotation_degrees = Vector3(12.0 * float(i), 35.0 * float(i), 8.0)


func _put_cup_down() -> void:
	## Release LMB / Esc — park the cup back on the rack (keeps fill).
	_return_cup_home(true)


func _try_return_cup_to_rack(screen_pos: Vector2) -> bool:
	if not cup_held or cup_root == null or camera == null:
		return false
	var rack_pt := camera.unproject_position(cup_home)
	if screen_pos.distance_to(rack_pt) > 70.0:
		return false
	_return_cup_home(true)
	return true


func _return_cup_home(keep_fill: bool = false) -> void:
	if cup_root == null:
		cup_held = false
		_hide_soda_stream()
		return
	cup_held = false
	_hide_soda_stream()
	_cup_vel = Vector3.ZERO
	_cup_slosh = Vector2.ZERO
	if cup_liquid_pivot != null and is_instance_valid(cup_liquid_pivot):
		cup_liquid_pivot.rotation_degrees = Vector3.ZERO
	if not keep_fill:
		cup_flavor = ""
		cup_soda_fill = 0.0
		cup_ice_fill = 0.0
	_cup_ice_spawn_cd = 0.0
	_refresh_cup_visuals()
	if cup_area:
		cup_area.input_ray_pickable = false
	_tween_tool_to_wall(
		cup_root,
		cup_home,
		cup_home_rot,
		Vector3.ONE,
		0.28,
		func() -> void:
			if cup_area != null and is_instance_valid(cup_area):
				cup_area.input_ray_pickable = true
	)
	if game_audio:
		game_audio.play_click()
	if keep_fill and cup_soda_fill > 0.2:
		_flash("Cup down — drink ready", Color("80CBC4"))
	else:
		_flash("Cup back on the rack", Color("B0BEC5"))


func _build_burger_pals_logo_decal() -> void:
	## Wall brand mark removed (cluttered the extinguisher / tools).
	if burger_pals_decal != null and is_instance_valid(burger_pals_decal):
		burger_pals_decal.queue_free()
		burger_pals_decal = null


func _build_window_bunting() -> void:
	## Party bunting draped across the top of the service window opening.
	const SCENE_PATH := "res://assets/bunting/Bunting.fbx"
	const TEX_PATH := "res://assets/bunting/bunting_red_yellow.png"
	if not ResourceLoader.exists(SCENE_PATH):
		push_warning("Bunting model missing: %s" % SCENE_PATH)
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("Bunting PackedScene failed to load")
		return
	var root := packed.instantiate() as Node3D
	if root == null:
		return
	root.name = "WindowBunting"
	## Just outside the service window (wall slab ~z 1.25–1.45), hanging into the opening view.
	## +3 in raise from prior y=1.715; +25% wider than prior x-scale 3.331.
	root.position = Vector3(0.0, 1.791, 1.52)
	root.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	root.scale = Vector3(4.164, 2.665, 2.665)
	var tex: Texture2D = null
	if ResourceLoader.exists(TEX_PATH):
		tex = load(TEX_PATH) as Texture2D
	_apply_bunting_materials(root, tex)
	world.add_child(root)


func _apply_bunting_materials(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		## Mesh is paper-thin — slight extrude via scale so it doesn't vanish edge-on.
		mi.scale = Vector3(1.0, 1.0, 8.0)
		## Paint each triangle solid yellow/red from its pennant center (no mid-flag splits).
		_paint_bunting_mesh_alternating(mi)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.render_priority = 10
		mi.material_override = mat
	for child in node.get_children():
		_apply_bunting_materials(child, tex)


func _paint_bunting_mesh_alternating(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	## Model-space pennant centers (from FBX triangle histogram).
	var peaks: Array[float] = [
		-0.4457, -0.2750, -0.1612, 0.0095, 0.1802, 0.2940, 0.4078, 0.5216
	]
	var yellow := Color(1.0, 0.84, 0.16)
	var red := Color(0.86, 0.14, 0.13)
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arrs := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
		var norms = arrs[Mesh.ARRAY_NORMAL]
		var uvs = arrs[Mesh.ARRAY_TEX_UV]
		var idx = arrs[Mesh.ARRAY_INDEX]
		## De-index so adjacent flags never share a vertex color.
		var new_v := PackedVector3Array()
		var new_n := PackedVector3Array()
		var new_uv := PackedVector2Array()
		var new_c := PackedColorArray()
		var tris: Array = []
		if idx != null and not idx.is_empty():
			var t := 0
			while t + 2 < idx.size():
				tris.append([int(idx[t]), int(idx[t + 1]), int(idx[t + 2])])
				t += 3
		else:
			var t2 := 0
			while t2 + 2 < verts.size():
				tris.append([t2, t2 + 1, t2 + 2])
				t2 += 3
		for tri in tris:
			var i0: int = tri[0]
			var i1: int = tri[1]
			var i2: int = tri[2]
			var cx := (verts[i0].x + verts[i1].x + verts[i2].x) / 3.0
			var best_i := 0
			var best_d := absf(cx - peaks[0])
			for p in range(1, peaks.size()):
				var d := absf(cx - peaks[p])
				if d < best_d:
					best_d = d
					best_i = p
			var col := yellow if (best_i % 2 == 0) else red
			for ii in [i0, i1, i2]:
				new_v.append(verts[ii])
				if norms != null and ii < norms.size():
					new_n.append(norms[ii])
				else:
					new_n.append(Vector3.UP)
				if uvs != null and ii < uvs.size():
					new_uv.append(uvs[ii])
				else:
					new_uv.append(Vector2.ZERO)
				new_c.append(col)
		var out_arrs := []
		out_arrs.resize(Mesh.ARRAY_MAX)
		out_arrs[Mesh.ARRAY_VERTEX] = new_v
		out_arrs[Mesh.ARRAY_NORMAL] = new_n
		out_arrs[Mesh.ARRAY_TEX_UV] = new_uv
		out_arrs[Mesh.ARRAY_COLOR] = new_c
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrs)
	mi.mesh = out


func _spawn_city_prop(path: String, parent: Node3D, pos: Vector3, yaw_deg: float = 0.0, scale_mul: float = 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.position = pos
	node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	node.scale = Vector3(scale_mul, scale_mul, scale_mul)
	parent.add_child(node)
	return node


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
	_build_phone_ui()
	_build_hud_chrome_toggle()
	_reset_supplies()
	radio.set_volume_linear(0.0)
	radio.set_powered(false)
	_refresh_radio_ui()


func _start_radio_fade_in() -> void:
	if radio == null:
		return
	radio.set_volume_linear(0.0)
	radio.set_powered(true)
	radio.fade_volume_in(3.0, 0.80)
	_refresh_radio_ui()


func _build_prep_ingredients_prop() -> void:
	## Hidden for now — wire baskets / produce art clutters the Build side.
	if prep_ingredients_prop != null and is_instance_valid(prep_ingredients_prop):
		prep_ingredients_prop.queue_free()
		prep_ingredients_prop = null
	return


func _make_toon_wood_material(tex: Texture2D, tint: Color = Color.WHITE, uv_scale: Vector3 = Vector3(1.5, 1.1, 1.0)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.68
	mat.metallic = 0.0
	mat.uv1_scale = uv_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _cutting_board_world_center() -> Vector3:
	## Same plane as the grill top — tucked just screen-left of the steel edge.
	var bw := CUTTING_BOARD_SIZE.x
	var bh := CUTTING_BOARD_SIZE.y
	var grill_left_edge := GRILL_CENTER_X + GRILL_WIDTH * 0.5
	var cx := grill_left_edge + CUTTING_BOARD_GAP + bw * 0.5
	var cy := GRILL_SURFACE_Y - bh * 0.5 + 0.012
	return Vector3(cx, cy, GRILL_SURFACE_Z + CUTTING_BOARD_Z_OFFSET)


func _build_cutting_board_prop() -> void:
	## Procedural wood block — horizontal like the griddle, no billboard art.
	if build_cutting_board != null and is_instance_valid(build_cutting_board):
		build_cutting_board.queue_free()
		build_cutting_board = null
	var wood_tex := FoodSpritesScript.get_tex("wood")
	var root := Node3D.new()
	root.name = "BuildCuttingBoard"
	root.position = _cutting_board_world_center()
	var bw := CUTTING_BOARD_SIZE.x
	var bh := CUTTING_BOARD_SIZE.y
	var bd := CUTTING_BOARD_SIZE.z
	## Dark apron rim — matches the grill steel lip.
	var rim := MeshInstance3D.new()
	rim.name = "BoardRim"
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(bw + 0.05, 0.014, bd + 0.05)
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, -bh * 0.5 - 0.006, 0.0)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = CUTTING_BOARD_RIM_TINT
	rim_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	rim_mat.roughness = 0.86
	rim.material_override = rim_mat
	root.add_child(rim)
	## Main plank block — top face is the chop surface.
	var slab := MeshInstance3D.new()
	slab.name = "BoardSlab"
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = CUTTING_BOARD_SIZE
	slab.mesh = slab_mesh
	if wood_tex != null:
		slab.material_override = _make_toon_wood_material(
			wood_tex, CUTTING_BOARD_WOOD_TINT, Vector3(2.4, 0.35, 2.0)
		)
	else:
		var slab_mat := StandardMaterial3D.new()
		slab_mat.albedo_color = CUTTING_BOARD_WOOD_TINT
		slab_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		slab_mat.roughness = 0.72
		slab.material_override = slab_mat
	root.add_child(slab)
	## Shallow juice groove inset on the top face.
	var groove := MeshInstance3D.new()
	groove.name = "BoardGroove"
	var groove_mesh := BoxMesh.new()
	groove_mesh.size = Vector3(bw * 0.82, 0.006, bd * 0.78)
	groove.mesh = groove_mesh
	groove.position = Vector3(0.0, bh * 0.5 - 0.004, 0.0)
	var groove_mat := StandardMaterial3D.new()
	groove_mat.albedo_color = Color(0.62, 0.44, 0.26)
	groove_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	groove_mat.roughness = 0.78
	groove.material_override = groove_mat
	root.add_child(groove)
	grill_root.add_child(root)
	build_cutting_board = root


func _build_truck_radio_prop() -> void:
	## Wall-mounted cab radio — synced each frame to the top-right 2D HUD.
	if radio_root != null and is_instance_valid(radio_root):
		radio_root.queue_free()
	radio_root = null
	radio_ui_anchor = null
	phone_ui_anchor = null
	radio_dial_mesh = null
	radio_light_mat = null

	var mesh: Mesh = null
	if ResourceLoader.exists(RADIO_MESH_PATH):
		mesh = load(RADIO_MESH_PATH) as Mesh
	if mesh != null and mesh.get_surface_count() > 0:
		_build_truck_radio_from_mesh(mesh)
	else:
		push_warning("Radio OBJ unavailable — using dash radio fallback mesh")
		_build_truck_radio_procedural()


func _build_truck_radio_from_mesh(mesh: Mesh) -> void:
	var aabb := mesh.get_aabb()
	var fit := RADIO_TARGET_SIZE / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	radio_root = Node3D.new()
	radio_root.name = "CabRadio"
	radio_root.position = RADIO_HOME_POS
	radio_root.rotation_degrees = RADIO_HOME_ROT
	world.add_child(radio_root)

	var body := MeshInstance3D.new()
	body.name = "RadioBody"
	body.mesh = mesh
	body.scale = Vector3.ONE * fit
	## Center on wall anchor (synced to the 2D HUD each frame).
	body.position = -aabb.get_center() * fit
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var alb: Texture2D = load(RADIO_TEX_ALBEDO) as Texture2D if ResourceLoader.exists(RADIO_TEX_ALBEDO) else null
	var norm: Texture2D = load(RADIO_TEX_NORMAL) as Texture2D if ResourceLoader.exists(RADIO_TEX_NORMAL) else null
	var met: Texture2D = load(RADIO_TEX_METAL) as Texture2D if ResourceLoader.exists(RADIO_TEX_METAL) else null
	var ao: Texture2D = load(RADIO_TEX_AO) as Texture2D if ResourceLoader.exists(RADIO_TEX_AO) else null
	_apply_radio_materials(body, alb, norm, met, ao)
	radio_root.add_child(body)
	_add_radio_dash_extras(aabb.size * fit)


func _build_truck_radio_procedural() -> void:
	## Original chunky dash radio — reliable fallback if OBJ import fails.
	radio_root = Node3D.new()
	radio_root.name = "CabRadio"
	radio_root.position = RADIO_HOME_POS
	radio_root.rotation_degrees = RADIO_HOME_ROT
	world.add_child(radio_root)

	var body := _add_box(radio_root, Vector3(0.42, 0.22, 0.18), Vector3.ZERO, Color(0.18, 0.16, 0.14))
	body.material_override.metallic = 0.55
	body.material_override.roughness = 0.35

	var face := _add_box(radio_root, Vector3(0.36, 0.12, 0.02), Vector3(0, 0.02, -0.1), Color(0.08, 0.1, 0.09))
	face.material_override.roughness = 0.55

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
	radio_root.add_child(lcd)

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
	radio_root.add_child(radio_dial_mesh)

	var speaker := _add_box(radio_root, Vector3(0.12, 0.08, 0.04), Vector3(0.12, -0.02, -0.1), Color(0.12, 0.12, 0.12))
	speaker.material_override.roughness = 0.9

	var tag := Label3D.new()
	tag.text = "AM / FM"
	tag.position = Vector3(0, 0.14, -0.05)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("FFCC80")
	UiFontsScript.apply_label3d(tag, true, 64, 0.062)
	radio_root.add_child(tag)

	_add_radio_click_area(Vector3(0.5, 0.32, 0.28))


func _add_radio_dash_extras(scaled_size: Vector3) -> void:
	## Tuning dial + LCD glow on imported mesh (same role as procedural radio).
	var lcd := MeshInstance3D.new()
	var lcd_mesh := BoxMesh.new()
	lcd_mesh.size = Vector3(scaled_size.x * 0.55, scaled_size.y * 0.08, 0.008)
	lcd.mesh = lcd_mesh
	lcd.position = Vector3(0.02, scaled_size.y * 0.22, -scaled_size.z * 0.42)
	radio_light_mat = StandardMaterial3D.new()
	radio_light_mat.albedo_color = Color(0.15, 0.35, 0.18)
	radio_light_mat.emission_enabled = true
	radio_light_mat.emission = Color(0.2, 0.9, 0.35)
	radio_light_mat.emission_energy_multiplier = 0.15
	radio_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lcd.material_override = radio_light_mat
	radio_root.add_child(lcd)

	radio_dial_mesh = MeshInstance3D.new()
	var dial := CylinderMesh.new()
	dial.top_radius = 0.022
	dial.bottom_radius = 0.026
	dial.height = 0.014
	radio_dial_mesh.mesh = dial
	radio_dial_mesh.rotation_degrees = Vector3(90, 0, 0)
	radio_dial_mesh.position = Vector3(-scaled_size.x * 0.28, scaled_size.y * 0.08, -scaled_size.z * 0.38)
	var dial_mat := StandardMaterial3D.new()
	dial_mat.albedo_color = Color(0.75, 0.55, 0.2)
	dial_mat.metallic = 0.85
	dial_mat.roughness = 0.28
	radio_dial_mesh.material_override = dial_mat
	radio_root.add_child(radio_dial_mesh)

	_add_radio_click_area(scaled_size * 1.05)


func _add_radio_click_area(hit_size: Vector3) -> void:
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = hit_size
	shape.shape = box
	area.add_child(shape)
	radio_root.add_child(area)
	area.input_event.connect(func(_cam, event, _pos, _n, _s):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if radio:
				radio.toggle_power()
				_flash("Radio %s" % ("ON" if radio.powered else "OFF"), Color("FFCC80"))
	)


func _apply_radio_materials(node: Node, alb: Texture2D, norm: Texture2D, met: Texture2D, ao: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		if alb != null:
			mat.albedo_texture = alb
			mat.albedo_color = Color(1.15, 1.15, 1.12)
		else:
			mat.albedo_color = Color(0.18, 0.16, 0.14)
		if met != null:
			mat.metallic_texture = met
			mat.metallic = 1.0
		else:
			mat.metallic = 0.35
		mat.roughness = 0.58
		if norm != null:
			mat.normal_enabled = true
			mat.normal_texture = norm
		if ao != null:
			mat.ao_enabled = true
			mat.ao_texture = ao
			mat.ao_light_affect = 0.55
		mi.material_override = mat
	for child in node.get_children():
		_apply_radio_materials(child, alb, norm, met, ao)


func _layout_phone_ui_overlay() -> void:
	## Phone stacks under the fixed top-right radio panel.
	if phone_column == null or radio_column == null:
		return
	var radio_rect := radio_column.get_global_rect()
	phone_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	phone_column.position = Vector2(
		radio_rect.position.x + (radio_rect.size.x - PHONE_UI_SIZE.x) * 0.5,
		radio_rect.position.y + radio_rect.size.y + PHONE_BELOW_RADIO_GAP
	)
	var vr := get_viewport().get_visible_rect()
	phone_column.position.x = clampf(
		phone_column.position.x,
		vr.position.x + 6.0,
		vr.position.x + vr.size.x - PHONE_UI_SIZE.x - 6.0
	)
	phone_column.size = PHONE_UI_SIZE
	_layout_hud_chrome_toggle()
	_sync_radio_3d_to_ui()


func _build_hud_chrome_toggle() -> void:
	## ▲ under the phone collapses phone + radio so the soda fountain is clear.
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	if hud_chrome_toggle != null and is_instance_valid(hud_chrome_toggle):
		hud_chrome_toggle.queue_free()
	hud_chrome_toggle = Button.new()
	hud_chrome_toggle.name = "HudChromeToggle"
	hud_chrome_toggle.text = "▲"
	hud_chrome_toggle.tooltip_text = "Hide phone & radio — use soda fountain"
	hud_chrome_toggle.custom_minimum_size = Vector2(44, 28)
	hud_chrome_toggle.focus_mode = Control.FOCUS_NONE
	hud_chrome_toggle.z_index = 22
	UiFontsScript.apply_button(hud_chrome_toggle, true, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 0.94)
	sb.border_color = Color(0.35, 0.38, 0.44, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	hud_chrome_toggle.add_theme_stylebox_override("normal", sb)
	hud_chrome_toggle.pressed.connect(_toggle_hud_chrome_collapsed)
	ui_root.add_child(hud_chrome_toggle)
	_layout_hud_chrome_toggle()


func _layout_hud_chrome_toggle() -> void:
	if hud_chrome_toggle == null or not is_instance_valid(hud_chrome_toggle):
		return
	var vr := get_viewport().get_visible_rect()
	hud_chrome_toggle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if hud_chrome_collapsed or phone_column == null or not phone_column.visible:
		hud_chrome_toggle.position = Vector2(
			vr.position.x + vr.size.x - 54.0,
			RADIO_UI_TOP
		)
	else:
		var pr := phone_column.get_global_rect()
		hud_chrome_toggle.position = Vector2(
			pr.position.x + (pr.size.x - 44.0) * 0.5,
			pr.position.y + pr.size.y + 4.0
		)


func _toggle_hud_chrome_collapsed() -> void:
	hud_chrome_collapsed = not hud_chrome_collapsed
	if radio_column != null and is_instance_valid(radio_column):
		radio_column.visible = not hud_chrome_collapsed
	if phone_column != null and is_instance_valid(phone_column):
		phone_column.visible = not hud_chrome_collapsed
	if hud_chrome_toggle != null and is_instance_valid(hud_chrome_toggle):
		if hud_chrome_collapsed:
			hud_chrome_toggle.text = "▼"
			hud_chrome_toggle.tooltip_text = "Show phone & radio"
			_flash("Phone & radio tucked — soda fountain clear", Color("80CBC4"))
		else:
			hud_chrome_toggle.text = "▲"
			hud_chrome_toggle.tooltip_text = "Hide phone & radio — use soda fountain"
	if game_audio:
		game_audio.play_click()
	_layout_hud_chrome_toggle()
	if not hud_chrome_collapsed:
		_sync_radio_3d_to_ui()


func _sync_radio_3d_to_ui() -> void:
	## Keep the 3D cab radio on the right wall under the top-right HUD.
	if radio_root == null or not is_instance_valid(radio_root) or radio_column == null or camera == null:
		return
	var ui_rect := radio_column.get_global_rect()
	if ui_rect.size.x < 8.0 or ui_rect.size.y < 8.0:
		return
	var screen_pt := ui_rect.position + ui_rect.size * RADIO_UI_ANCHOR
	var hit := _ui_screen_to_wall_point(screen_pt)
	radio_root.global_position = hit + RADIO_WORLD_NUDGE
	radio_root.global_rotation_degrees = RADIO_HOME_ROT


func _ui_screen_to_wall_point(screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.x) > 0.00001:
		var t_wall := (RADIO_WALL_X - from.x) / dir.x
		if t_wall > 0.04:
			return from + dir * t_wall
	## Fallback: intersect a front bulkhead plane if the ray misses the side wall.
	var plane_z := RADIO_HOME_POS.z
	if absf(dir.z) > 0.00001:
		var t_z := (plane_z - from.z) / dir.z
		if t_z > 0.04:
			return from + dir * t_z
	return RADIO_HOME_POS


func _reset_supplies() -> void:
	social_rating_sum = 0.0
	social_review_count = 0
	social_reviews.clear()
	supply_stock.clear()
	supply_fresh.clear()
	for id in SUPPLY_IDS:
		match id:
			"bun_bottom", "bun_top":
				supply_stock[id] = 28
			"patty":
				supply_stock[id] = 22
			_:
				supply_stock[id] = 16
		supply_fresh[id] = SUPPLY_FRESH_MAX
	_refresh_phone_ui()


func _supply_buy_unit_cost(id: String) -> float:
	## Phone restock prices only — pulling from current fridge stock is free.
	match id:
		"patty":
			return 0.35
		"bun_bottom", "bun_top":
			return 0.20
		"bacon":
			return 2.00
		_:
			return 1.00


func _try_use_supply(id: String, amount: int = 1) -> bool:
	if id == "":
		return true
	var have := int(supply_stock.get(id, 0))
	if have < amount:
		var label := str(GameDataScript.INGREDIENT_LABELS.get(id, id))
		_flash("Out of %s — restock on phone!" % label, Color("EF5350"))
		_refresh_phone_ui()
		return false
	supply_stock[id] = have - amount
	_refresh_phone_ui()
	return true


func _spend_ingredient(id: String) -> bool:
	## Using what's already in the fridge is free — only stock counts.
	return _try_use_supply(id)


func _mp_try_use_supply(id: String, amount: int = 1) -> bool:
	## Shared build/grill mutations must not abort because one peer's stock is stale.
	if not mp_enabled or not _mp_applying:
		return _try_use_supply(id, amount)
	if NetManager.is_host() and id != "":
		var have := int(supply_stock.get(id, 0))
		if have >= amount:
			supply_stock[id] = have - amount
			_refresh_phone_ui()
	return true


func _mp_spend_ingredient(id: String) -> bool:
	## Always allow the shared stack change; host alone adjusts stock (no cash charge).
	if not mp_enabled or not _mp_applying:
		return _spend_ingredient(id)
	if NetManager.is_host() and id != "":
		var have := int(supply_stock.get(id, 0))
		if have > 0:
			supply_stock[id] = have - 1
			_refresh_phone_ui()
	return true


func _mp_can_spend_ingredient(id: String) -> bool:
	## Pre-RPC gate so we don't ship adds when host stock is clearly empty.
	if id == "" or id == "patty" or id == "bun_bottom":
		return true
	if int(supply_stock.get(id, 0)) <= 0:
		var label := str(GameDataScript.INGREDIENT_LABELS.get(id, id))
		_flash("Out of %s — restock on phone!" % label, Color("EF5350"))
		_refresh_phone_ui()
		return false
	return true


func _update_supply_freshness(delta: float) -> void:
	if not playing:
		return
	## Guest stock/freshness comes from host economy sync.
	if mp_enabled and not NetManager.is_host():
		return
	var spoiled := false
	for id in SUPPLY_IDS:
		var stock := int(supply_stock.get(id, 0))
		if stock <= 0:
			supply_fresh[id] = 0.0
			continue
		var fresh := float(supply_fresh.get(id, SUPPLY_FRESH_MAX))
		fresh -= delta
		if fresh <= 0.0:
			supply_stock[id] = stock - 1
			spoiled = true
			if int(supply_stock.get(id, 0)) > 0:
				supply_fresh[id] = SUPPLY_FRESH_MAX
			else:
				supply_fresh[id] = 0.0
		else:
			supply_fresh[id] = fresh
	if spoiled:
		_refresh_phone_ui()
		if mp_enabled and NetManager.is_host():
			_mp_broadcast_economy()


func _buy_supply(id: String) -> void:
	if not playing:
		return
	if mp_enabled and not _mp_applying:
		mp_buy_supply.rpc(id)
		return
	_buy_supply_local(id)


func _buy_supply_local(id: String) -> void:
	if not playing:
		return
	var pack := SUPPLY_BUY_PACK
	var unit := _supply_buy_unit_cost(id)
	var cost := unit * float(pack)
	if money + 0.001 < cost:
		_flash("Need %s to restock" % _format_money(cost), Color("EF5350"))
		return
	money -= cost
	supply_stock[id] = int(supply_stock.get(id, 0)) + pack
	supply_fresh[id] = SUPPLY_FRESH_MAX
	_update_hud()
	_refresh_phone_ui()
	var label := str(GameDataScript.INGREDIENT_LABELS.get(id, id))
	_flash("Restocked %s (+%d)" % [label, pack], Color("A5D6A7"))
	_sfx_click()
	if mp_enabled and NetManager.is_host() and not _mp_applying:
		_mp_broadcast_economy()


func _social_rating_display() -> float:
	if social_review_count <= 0:
		return 0.0
	return social_rating_sum / float(social_review_count)


func _star_bar_text(rating: float) -> String:
	var full := int(floor(rating + 0.25))
	full = clampi(full, 0, 5)
	var out := ""
	for i in 5:
		out += "★" if i < full else "☆"
	return out


func _freshness_bar_color(ratio: float) -> Color:
	if ratio > 0.65:
		return Color("66BB6A")
	if ratio > 0.35:
		return Color("FFCA28")
	return Color("EF5350")


func _record_social_review(stars: float) -> void:
	## Legacy entry — prefer _maybe_record_social_review for new posts.
	_maybe_record_social_review(stars, "angry")


func _maybe_record_social_review(
	stars: float,
	kind: String = "serve",
	tip: int = 0,
	station_index: int = -1
) -> void:
	## Host/solo: ~70% of customers leave a visible social post right away.
	if mp_enabled and not NetManager.is_host():
		return
	if randf() >= SOCIAL_REVIEW_CHANCE:
		return
	_commit_social_review(stars, kind, tip, station_index)


func _force_record_social_review(
	stars: float,
	kind: String = "angry",
	tip: int = 0,
	station_index: int = -1
) -> void:
	## Guaranteed feed post (e.g. extinguisher spray victims).
	if mp_enabled and not NetManager.is_host():
		return
	_commit_social_review(stars, kind, tip, station_index)


func _commit_social_review(
	stars: float,
	kind: String,
	tip: int = 0,
	station_index: int = -1
) -> void:
	var who := SOCIAL_REVIEWER_NAMES[randi() % SOCIAL_REVIEWER_NAMES.size()]
	var text := SocialReviewsScript.generate(stars, kind, tip)
	var pic: Texture2D = null
	if station_index >= 0 and randf() < SOCIAL_REVIEW_PIC_CHANCE:
		pic = _make_review_burger_snapshot(station_index)
	var pic_png: PackedByteArray = PackedByteArray()
	if pic != null:
		var img := pic.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			pic_png = img.save_png_to_buffer()
	_apply_social_review(stars, who, text, pic)
	if mp_enabled and NetManager.is_host() and NetManager.is_online():
		mp_social_review.rpc(stars, who, text, pic_png)


func _apply_social_review(stars: float, who: String, text: String, pic: Texture2D = null) -> void:
	social_review_count += 1
	social_rating_sum += clampf(stars, 0.0, 5.0)
	var post := {"stars": clampf(stars, 0.0, 5.0), "who": who, "text": text}
	if pic != null:
		post["pic"] = pic
	social_reviews.push_front(post)
	while social_reviews.size() > SOCIAL_FEED_MAX:
		social_reviews.pop_back()
	_refresh_phone_ui()
	_flash("%s left a review!" % who, Color("90CAF9"))


func _make_review_burger_snapshot(station_index: int) -> Texture2D:
	## Compact 2D stack photo for ~1/8 social posts.
	if station_index < 0 or station_index >= stations.size():
		return null
	var st: Dictionary = stations[station_index]
	var items: Array = st.get("items", [])
	if items.is_empty():
		return null
	const OUT := 112
	var canvas := Image.create(OUT, OUT, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.14, 0.12, 0.10, 0.92))
	## Soft plate disc.
	for y in OUT:
		for x in OUT:
			var dx := (float(x) + 0.5) / float(OUT) - 0.5
			var dy := (float(y) + 0.5) / float(OUT) - 0.5
			if dx * dx + dy * dy < 0.22:
				canvas.set_pixel(x, y, Color(0.22, 0.2, 0.18, 1.0))

	var layer_scale := 0.92
	var layer_w := 78.0
	var step_y := 11.0
	var stack_lift := 0.0
	var layers: Array = [] ## {img, w, h, y}
	for stack_i in items.size():
		var item: String = str(items[stack_i])
		if item == "cheese":
			continue
		var layer_key := item
		var pidx := -1
		if item == "patty":
			var patty_from_bottom := 0
			for j in range(stack_i + 1):
				if str(items[j]) == "patty":
					patty_from_bottom += 1
			pidx = patty_from_bottom - 1
			if _station_patty_has_cheese(st, pidx):
				layer_key = "patty_cheese"
		var build_scale := _station_item_build_scale(layer_key)
		var h_base := _layer_img_height(layer_key) * layer_scale * build_scale
		var this_w := layer_w * _layer_width_mul(layer_key) * build_scale
		var layer_tex: Texture2D = null
		if item == "patty":
			layer_tex = _station_patty_layer_tex(st, pidx, layer_key == "patty_cheese")
		else:
			layer_tex = FoodSpritesScript.get_tex(item)
		if layer_tex == null:
			continue
		var fit := _fit_layer_box_size(layer_tex, this_w, h_base)
		this_w = fit.x
		var h := fit.y
		var y := float(OUT) * 0.62 - stack_lift - float(stack_i) * step_y - h * 0.55
		if item == "bun_bottom":
			stack_lift += 3.0
		elif item == "patty":
			stack_lift += 4.0
		var raw := layer_tex.get_image()
		if raw == null:
			continue
		## Knock out studio-black sheet padding, then alpha-blend (blit stamped black boxes).
		var src := FoodSpritesScript.prep_layer_image_for_composite(raw)
		if src == null:
			continue
		var tw := maxi(4, int(round(this_w)))
		var th := maxi(4, int(round(h)))
		src.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		layers.append({"img": src, "w": tw, "h": th, "y": y})

	for L in layers:
		var src: Image = L["img"]
		var tw: int = int(L["w"])
		var th: int = int(L["h"])
		var px := int(round((float(OUT) - float(tw)) * 0.5))
		var py := clampi(int(round(float(L["y"]))), 0, OUT - th)
		if tw > 0 and th > 0 and px < OUT and py < OUT:
			canvas.blend_rect(src, Rect2i(0, 0, tw, th), Vector2i(px, py))

	return ImageTexture.create_from_image(canvas)


func _generate_review_text(stars: float, kind: String, tip: int = 0) -> String:
	## Kept for callers — writer lives in social_reviews.gd.
	return SocialReviewsScript.generate(stars, kind, tip)


func _review_stars_from_serve(
	payout: int,
	meh: bool,
	wrong: bool,
	cook_r: Dictionary,
	quality: float
) -> float:
	if wrong or payout <= 0:
		return 1.0
	var cook_stars := float(cook_r.get("stars", 3))
	var cook_score := int(cook_r.get("score", 70))
	## Burnt: 80% hate it (1★) · 20% charcoal weirdos leave a good review about it.
	if _cook_rating_is_burnt(cook_r):
		if randf() < 0.20:
			return 5.0 if randf() < 0.45 else 4.0
		return 1.0
	if meh:
		return clampf(cook_stars * 0.55, 1.0, 2.5)
	var stars := cook_stars
	## Order quality can lift a decent cook — not a charcoal puck.
	if cook_score >= 70 and cook_stars >= 3.0:
		if quality >= 0.98:
			stars = maxf(stars, 5.0)
		elif quality >= 0.9:
			stars = maxf(stars, 4.0)
	elif cook_stars <= 1.0:
		stars = minf(stars, 1.5)
	elif cook_stars <= 2.0:
		stars = minf(maxf(stars, 1.0), 2.5)
	return clampf(stars, 1.0, 5.0)


func _cook_rating_is_burnt(cook_r: Dictionary) -> bool:
	return str(cook_r.get("detail", "")) == "Burnt" \
		or (str(cook_r.get("label", "")) == "Bad" and float(cook_r.get("stars", 3)) <= 0.5)


func _refresh_phone_ui() -> void:
	if phone_rating_stars == null or phone_rating_value == null or phone_review_label == null:
		return
	if social_review_count <= 0:
		phone_rating_stars.text = "☆☆☆☆☆"
		phone_rating_value.text = "—"
		phone_review_label.text = "New business · 0 reviews"
	else:
		var avg := _social_rating_display()
		phone_rating_stars.text = _star_bar_text(avg)
		phone_rating_value.text = "%.1f" % avg
		phone_review_label.text = "%d review%s" % [
			social_review_count,
			"s" if social_review_count != 1 else ""
		]
	_refresh_phone_feed()
	if phone_inventory_box == null:
		return
	for child in phone_inventory_box.get_children():
		child.queue_free()
	for id in SUPPLY_IDS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 3)
		row.custom_minimum_size = Vector2(0, 18)
		phone_inventory_box.add_child(row)

		var name_lab := Label.new()
		var short := str(GameDataScript.INGREDIENT_LABELS.get(id, id))
		if short.length() > 10:
			short = short.substr(0, 9) + "…"
		name_lab.text = short
		name_lab.custom_minimum_size = Vector2(40, 0)
		name_lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lab.clip_text = true
		name_lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UiFontsScript.apply_label(name_lab, false, 8)
		name_lab.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		row.add_child(name_lab)

		var stock := int(supply_stock.get(id, 0))
		var fresh_r := clampf(float(supply_fresh.get(id, 0.0)) / SUPPLY_FRESH_MAX, 0.0, 1.0) if stock > 0 else 0.0
		var count_lab := Label.new()
		count_lab.text = str(stock)
		count_lab.custom_minimum_size = Vector2(12, 0)
		count_lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		count_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiFontsScript.apply_label(count_lab, true, 8)
		count_lab.add_theme_color_override("font_color", _freshness_bar_color(fresh_r))
		row.add_child(count_lab)

		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(12, 5)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.value = fresh_r
		bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.10, 0.12, 0.16, 0.95)
		bar_bg.set_corner_radius_all(2)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = _freshness_bar_color(fresh_r)
		bar_fill.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(bar)

		var pack_cost: float = _supply_buy_unit_cost(id) * float(SUPPLY_BUY_PACK)
		var buy := Button.new()
		buy.text = "Buy"
		buy.tooltip_text = "Buy %d for %s" % [SUPPLY_BUY_PACK, _format_money(pack_cost)]
		buy.custom_minimum_size = Vector2(28, 16)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_END
		buy.focus_mode = Control.FOCUS_NONE
		UiFontsScript.apply_button(buy, true, 7)
		_style_phone_buy_button(buy)
		var sid := id
		buy.pressed.connect(func(): _buy_supply(sid))
		row.add_child(buy)


func _style_phone_buy_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.16, 0.32, 0.22, 0.98)
	n.border_color = Color(0.45, 0.78, 0.55, 0.85)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 3
	n.content_margin_right = 3
	n.content_margin_top = 1
	n.content_margin_bottom = 1
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.22, 0.42, 0.28, 1.0)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.12, 0.24, 0.16, 1.0)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color(0.82, 0.96, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.9, 0.75))


func _make_phone_section_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(PHONE_CORNER_INNER)
	sb.content_margin_left = 5
	sb.content_margin_right = 6
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _refresh_phone_feed() -> void:
	if phone_feed_box == null or not is_instance_valid(phone_feed_box):
		return
	for child in phone_feed_box.get_children():
		child.queue_free()
	if social_reviews.is_empty():
		var empty := Label.new()
		empty.text = "No posts yet — serve someone!"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFontsScript.apply_label(empty, false, 8)
		empty.add_theme_color_override("font_color", Color(0.48, 0.55, 0.64))
		phone_feed_box.add_child(empty)
		return
	for post in social_reviews:
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.09, 0.11, 0.16, 0.9)
		card_sb.set_corner_radius_all(4)
		card_sb.content_margin_left = 5
		card_sb.content_margin_right = 5
		card_sb.content_margin_top = 3
		card_sb.content_margin_bottom = 3
		card_sb.border_color = Color(0.28, 0.34, 0.44, 0.55)
		card_sb.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_sb)
		phone_feed_box.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(head)
		var who := Label.new()
		who.text = str(post.get("who", "Guest"))
		UiFontsScript.apply_label(who, true, 8)
		who.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(who)
		var stars := Label.new()
		stars.text = _star_bar_text(float(post.get("stars", 3.0)))
		UiFontsScript.apply_label(stars, true, 7)
		stars.add_theme_color_override("font_color", Color("FFD54F"))
		head.add_child(stars)
		var body := Label.new()
		body.text = str(post.get("text", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFontsScript.apply_label(body, false, 8)
		body.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
		cv.add_child(body)
		var pic = post.get("pic", null)
		if pic is Texture2D and is_instance_valid(pic):
			var shot := TextureRect.new()
			shot.texture = pic
			shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			shot.custom_minimum_size = Vector2(72, 72)
			shot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_child(shot)


func _build_phone_ui() -> void:
	var ui_root: Control = get_node("UI/Root")
	phone_column = Control.new()
	phone_column.name = "PhoneColumn"
	phone_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	phone_column.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_column.custom_minimum_size = PHONE_UI_SIZE
	phone_column.size = PHONE_UI_SIZE
	phone_column.clip_contents = false
	phone_column.z_index = 20
	ui_root.add_child(phone_column)

	var body := PanelContainer.new()
	body.name = "PhoneBody"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	var body_sb := StyleBoxFlat.new()
	body_sb.bg_color = Color(0.11, 0.12, 0.14, 0.98)
	body_sb.border_color = Color(0.28, 0.30, 0.34, 1.0)
	body_sb.set_border_width_all(3)
	body_sb.set_corner_radius_all(PHONE_CORNER_OUTER)
	body_sb.shadow_color = Color(0, 0, 0, 0.45)
	body_sb.shadow_size = 8
	body_sb.content_margin_left = 6
	body_sb.content_margin_right = 8
	body_sb.content_margin_top = 8
	body_sb.content_margin_bottom = 10
	body.add_theme_stylebox_override("panel", body_sb)
	phone_column.add_child(body)

	var phone_stack := VBoxContainer.new()
	phone_stack.add_theme_constant_override("separation", 0)
	phone_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(phone_stack)

	## Screen fills the frame — no solid black forehead/chin bars (those read as bugs).
	var screen := PanelContainer.new()
	screen.name = "PhoneScreen"
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var screen_sb := StyleBoxFlat.new()
	screen_sb.bg_color = Color(0.04, 0.06, 0.11, 0.98)
	screen_sb.border_color = Color(0.55, 0.62, 0.72, 0.35)
	screen_sb.set_border_width_all(1)
	screen_sb.set_corner_radius_all(PHONE_CORNER_INNER)
	screen_sb.content_margin_left = 4
	screen_sb.content_margin_right = 7
	screen_sb.content_margin_top = 5
	screen_sb.content_margin_bottom = 5
	screen.add_theme_stylebox_override("panel", screen_sb)
	phone_stack.add_child(screen)

	## PanelContainer needs a single content host for the scrollable screen.
	var screen_host := Control.new()
	screen_host.name = "PhoneScreenHost"
	screen_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_host.clip_contents = true
	screen.add_child(screen_host)

	var scroll := ScrollContainer.new()
	phone_scroll = scroll
	scroll.name = "PhoneScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER ## drag scroll — no bar
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.gui_input.connect(_on_phone_scroll_gui_input)
	screen_host.add_child(scroll)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var logo_wrap := CenterContainer.new()
	logo_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_wrap.custom_minimum_size = Vector2(PHONE_LOGO_INNER_W, PHONE_LOGO_WRAP_H)
	logo_wrap.clip_contents = false
	logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo_wrap)
	if ResourceLoader.exists(LOGO_TEX_PATH):
		var logo := TextureRect.new()
		logo.name = "BurgerPalsLogo"
		logo.texture = load(LOGO_TEX_PATH) as Texture2D
		logo.custom_minimum_size = Vector2(PHONE_LOGO_INNER_W, PHONE_LOGO_DISPLAY_H)
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_wrap.add_child(logo)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 4)
	v.add_child(status_row)
	var status_dot := Label.new()
	status_dot.text = "●"
	UiFontsScript.apply_label(status_dot, true, 9)
	status_dot.add_theme_color_override("font_color", Color("66BB6A"))
	status_row.add_child(status_dot)
	var status_lab := Label.new()
	status_lab.text = "BizPhone"
	UiFontsScript.apply_label(status_lab, true, 9)
	status_lab.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	status_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_lab)

	## Social app card — rating + feed
	var social_panel := PanelContainer.new()
	social_panel.name = "SocialApp"
	social_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	social_panel.add_theme_stylebox_override("panel", _make_phone_section_style(Color("90CAF9")))
	v.add_child(social_panel)
	var social_v := VBoxContainer.new()
	social_v.add_theme_constant_override("separation", 3)
	social_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	social_panel.add_child(social_v)

	var feed_title := Label.new()
	feed_title.text = "SOCIAL"
	UiFontsScript.apply_label(feed_title, true, 9)
	feed_title.add_theme_color_override("font_color", Color("90CAF9"))
	social_v.add_child(feed_title)

	phone_rating_stars = Label.new()
	phone_rating_stars.text = "☆☆☆☆☆"
	UiFontsScript.apply_label(phone_rating_stars, true, 14)
	phone_rating_stars.add_theme_color_override("font_color", Color("FFD54F"))
	social_v.add_child(phone_rating_stars)

	var rating_row := HBoxContainer.new()
	rating_row.add_theme_constant_override("separation", 4)
	rating_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	social_v.add_child(rating_row)
	phone_rating_value = Label.new()
	phone_rating_value.text = "—"
	UiFontsScript.apply_label(phone_rating_value, true, 12)
	phone_rating_value.add_theme_color_override("font_color", Color.WHITE)
	rating_row.add_child(phone_rating_value)
	var out_of := Label.new()
	out_of.text = "/ 5"
	UiFontsScript.apply_label(out_of, false, 9)
	out_of.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	rating_row.add_child(out_of)

	phone_review_label = Label.new()
	phone_review_label.text = "New business · 0 reviews"
	UiFontsScript.apply_label(phone_review_label, false, 8)
	phone_review_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	social_v.add_child(phone_review_label)

	var feed_sub := Label.new()
	feed_sub.text = "FEED"
	UiFontsScript.apply_label(feed_sub, true, 8)
	feed_sub.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	social_v.add_child(feed_sub)

	phone_feed_box = VBoxContainer.new()
	phone_feed_box.add_theme_constant_override("separation", 3)
	phone_feed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	social_v.add_child(phone_feed_box)

	## Inventory app card
	var inv_panel := PanelContainer.new()
	inv_panel.name = "InventoryApp"
	inv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_panel.add_theme_stylebox_override("panel", _make_phone_section_style(Color("A5D6A7")))
	v.add_child(inv_panel)
	var inv_v := VBoxContainer.new()
	inv_v.add_theme_constant_override("separation", 3)
	inv_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_panel.add_child(inv_v)

	var inv_title := Label.new()
	inv_title.text = "INVENTORY"
	UiFontsScript.apply_label(inv_title, true, 9)
	inv_title.add_theme_color_override("font_color", Color("A5D6A7"))
	inv_v.add_child(inv_title)

	var inv_hint := Label.new()
	inv_hint.text = "Freshness · restock packs of %d" % SUPPLY_BUY_PACK
	UiFontsScript.apply_label(inv_hint, false, 7)
	inv_hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.48))
	inv_v.add_child(inv_hint)

	phone_inventory_box = VBoxContainer.new()
	phone_inventory_box.add_theme_constant_override("separation", 2)
	phone_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_inventory_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_v.add_child(phone_inventory_box)

	_refresh_phone_ui()


func _on_phone_scroll_gui_input(ev: InputEvent) -> void:
	## LMB drag + flick inertia — no visible scrollbar; small movement still clicks Buy.
	if phone_scroll == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_phone_scroll_vel -= PHONE_SCROLL_WHEEL_KICK
		phone_scroll.accept_event()
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_phone_scroll_vel += PHONE_SCROLL_WHEEL_KICK
		phone_scroll.accept_event()
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_phone_scroll_vel = 0.0
			_phone_scroll_drag_pending = true
			_phone_scroll_dragging = false
			_phone_scroll_drag_start_y = ev.global_position.y
			_phone_scroll_drag_start_offset = phone_scroll.scroll_vertical
			_phone_scroll_last_mouse_y = ev.global_position.y
			_phone_scroll_last_msec = Time.get_ticks_msec()
		else:
			_phone_scroll_drag_pending = false
			_phone_scroll_dragging = false
	elif ev is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_phone_scroll_drag_pending = false
			_phone_scroll_dragging = false
			return
		if _phone_scroll_drag_pending:
			if absf(ev.global_position.y - _phone_scroll_drag_start_y) >= PHONE_SCROLL_DRAG_THRESH:
				_phone_scroll_dragging = true
				_phone_scroll_drag_pending = false
		if _phone_scroll_dragging:
			var now_ms: int = Time.get_ticks_msec()
			var dt: float = maxf(float(now_ms - _phone_scroll_last_msec) / 1000.0, 0.001)
			var dy_frame: float = ev.global_position.y - _phone_scroll_last_mouse_y
			var inst_vel: float = -dy_frame / dt
			_phone_scroll_vel = lerpf(_phone_scroll_vel, inst_vel, 0.55)
			_phone_scroll_last_mouse_y = ev.global_position.y
			_phone_scroll_last_msec = now_ms
			var dy: float = ev.global_position.y - _phone_scroll_drag_start_y
			phone_scroll.scroll_vertical = int(_phone_scroll_drag_start_offset - dy)
			phone_scroll.accept_event()


func _update_phone_scroll_inertia(delta: float) -> void:
	if phone_scroll == null or not is_instance_valid(phone_scroll):
		return
	if _phone_scroll_dragging:
		return
	if absf(_phone_scroll_vel) < PHONE_SCROLL_MIN_VEL:
		_phone_scroll_vel = 0.0
		return
	phone_scroll.scroll_vertical = int(round(float(phone_scroll.scroll_vertical) - _phone_scroll_vel * delta))
	_phone_scroll_vel *= exp(-PHONE_SCROLL_FRICTION * delta)


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
	radio_column.offset_left = -RADIO_UI_LEFT
	radio_column.offset_right = -RADIO_UI_RIGHT
	radio_column.offset_top = RADIO_UI_TOP
	radio_column.offset_bottom = RADIO_UI_TOP
	radio_column.custom_minimum_size = Vector2(RADIO_UI_PANEL_SIZE.x, 0.0)
	radio_column.add_theme_constant_override("separation", 0)
	radio_column.mouse_filter = Control.MOUSE_FILTER_STOP
	radio_column.z_index = 20
	ui_root.add_child(radio_column)

	## Match BizPhone outer frame (same border / corners / shadow language).
	var panel := PanelContainer.new()
	panel.name = "RadioPanel"
	panel.custom_minimum_size = Vector2(RADIO_UI_PANEL_SIZE.x, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 0.98)
	sb.border_color = Color(0.28, 0.30, 0.34, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(PHONE_CORNER_OUTER)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	radio_column.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	outer.add_child(title_row)

	var title_dot := Label.new()
	title_dot.text = "●"
	UiFontsScript.apply_label(title_dot, true, 9)
	title_dot.add_theme_color_override("font_color", Color("FFCC80"))
	title_row.add_child(title_dot)

	var title := Label.new()
	title.text = "Cab Radio"
	UiFontsScript.apply_label(title, true, 10)
	title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var band_btn := Button.new()
	band_btn.text = "BAND"
	band_btn.custom_minimum_size = Vector2(44, 22)
	band_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(band_btn, true, 9)
	_style_radio_chrome_button(band_btn)
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
	radio_power_btn.custom_minimum_size = Vector2(40, 22)
	radio_power_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(radio_power_btn, true, 9)
	_style_radio_chrome_button(radio_power_btn)
	radio_power_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.toggle_power()
	)
	title_row.add_child(radio_power_btn)

	## Inner screen — same inset look as the phone display.
	var screen := PanelContainer.new()
	screen.name = "RadioScreen"
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var screen_sb := StyleBoxFlat.new()
	screen_sb.bg_color = Color(0.04, 0.06, 0.11, 0.98)
	screen_sb.border_color = Color(0.55, 0.62, 0.72, 0.35)
	screen_sb.set_border_width_all(1)
	screen_sb.set_corner_radius_all(PHONE_CORNER_INNER)
	screen_sb.content_margin_left = 5
	screen_sb.content_margin_right = 5
	screen_sb.content_margin_top = 4
	screen_sb.content_margin_bottom = 4
	screen.add_theme_stylebox_override("panel", screen_sb)
	outer.add_child(screen)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	screen.add_child(v)

	radio_channel_label = Label.new()
	radio_channel_label.text = "FM 92.1 Smooth Jazz"
	radio_channel_label.clip_text = true
	radio_channel_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFontsScript.apply_label(radio_channel_label, true, 11)
	radio_channel_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	v.add_child(radio_channel_label)

	radio_status_label = Label.new()
	radio_status_label.text = "Radio off"
	radio_status_label.clip_text = true
	radio_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFontsScript.apply_label(radio_status_label, false, 9)
	radio_status_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.62))
	v.add_child(radio_status_label)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	v.add_child(nav)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.tooltip_text = "Previous station"
	prev_btn.custom_minimum_size = Vector2(32, 22)
	prev_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(prev_btn, true, 11)
	_style_radio_chrome_button(prev_btn)
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
	next_btn.custom_minimum_size = Vector2(32, 22)
	next_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(next_btn, true, 11)
	_style_radio_chrome_button(next_btn)
	next_btn.pressed.connect(func():
		_sfx_click()
		if radio:
			radio.next_channel()
			_spin_radio_dial(1)
	)
	nav.add_child(next_btn)

	var vol_lab := Label.new()
	vol_lab.text = "VOL"
	UiFontsScript.apply_label(vol_lab, true, 9)
	vol_lab.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	nav.add_child(vol_lab)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.80
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(70, 14)
	slider.value_changed.connect(func(v: float):
		if radio:
			radio.set_volume_linear(v)
	)
	nav.add_child(slider)


func _style_radio_chrome_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.16, 0.18, 0.22, 0.98)
	n.border_color = Color(0.40, 0.44, 0.50, 0.9)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 4
	n.content_margin_right = 4
	n.content_margin_top = 2
	n.content_margin_bottom = 2
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.22, 0.25, 0.30, 1.0)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.12, 0.14, 0.17, 1.0)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.8, 0.86))


func _build_graphics_ui() -> void:
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return

	## Top-left OPTIONS (replaces old GFX) — opens the Escape menu.
	gfx_btn = Button.new()
	gfx_btn.name = "OptionsBtn"
	gfx_btn.text = "OPTIONS"
	gfx_btn.focus_mode = Control.FOCUS_NONE
	gfx_btn.z_index = 30
	gfx_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gfx_btn.position = Vector2(98, 10)
	gfx_btn.custom_minimum_size = Vector2(72, 26)
	_style_quiet_hud_button(gfx_btn, 10)
	gfx_btn.pressed.connect(func():
		_sfx_click()
		_toggle_options_menu()
	)
	ui_root.add_child(gfx_btn)

	## Advanced graphics panel — opened from Options → Graphics.
	gfx_panel = PanelContainer.new()
	gfx_panel.name = "GraphicsPanel"
	gfx_panel.visible = false
	gfx_panel.z_index = 95
	gfx_panel.set_anchors_preset(Control.PRESET_CENTER)
	gfx_panel.offset_left = -180.0
	gfx_panel.offset_right = 180.0
	gfx_panel.offset_top = -280.0
	gfx_panel.offset_bottom = 280.0
	gfx_panel.custom_minimum_size = Vector2(340, 0)
	gfx_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.1, 0.12, 0.96)
	psb.border_color = Color(0.45, 0.55, 0.65, 0.9)
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

	_gfx_add_section(list, "HEAT WARP")
	_gfx_add_check(list, "heat_warp_on", "Heat Shimmer")
	_gfx_add_slider(list, "heat_warp_size", "Warp Size", 0.3, 1.6, 0.01)
	_gfx_add_slider(list, "heat_warp_speed", "Warp Speed", 0.5, 10.0, 0.05)
	_gfx_add_slider(list, "heat_warp_strength", "Warp Strength", 0.0, 0.03, 0.0005)
	_gfx_add_slider(list, "heat_warp_tight", "Warp Tightness", 0.5, 2.2, 0.05)

	_gfx_add_section(list, "WINDOW BG")
	_gfx_add_slider(list, "bg_y", "BG Height", 0.2, 4.5, 0.02)
	_gfx_add_slider(list, "bg_scale", "BG Scale", 0.4, 2.2, 0.01)

	_gfx_add_section(list, "FIRST SALE DECAL")
	_gfx_add_slider(list, "sale_x", "Sale X", -2.5, 2.5, 0.01)
	_gfx_add_slider(list, "sale_y", "Sale Y", 1.5, 2.8, 0.01)
	_gfx_add_slider(list, "sale_z", "Sale Z", 0.9, 1.5, 0.01)
	_gfx_add_slider(list, "sale_scale", "Sale Scale", 0.25, 2.5, 0.01)

	_gfx_add_section(list, "MENU BOARD")
	_gfx_add_slider(list, "menu_x", "Menu X", -3.2, 3.2, 0.01)
	_gfx_add_slider(list, "menu_y", "Menu Y", 0.8, 2.6, 0.01)
	_gfx_add_slider(list, "menu_z", "Menu Z", 0.9, 1.5, 0.01)
	_gfx_add_slider(list, "menu_scale", "Menu Scale", 0.25, 2.5, 0.01)
	_gfx_add_slider(list, "menu_yaw", "Menu Yaw", -180.0, 180.0, 1.0)

	_gfx_add_section(list, "GRILL STRIP LIGHT")
	_gfx_add_slider(list, "strip_x", "Strip X", -1.5, 1.5, 0.005)
	_gfx_add_slider(list, "strip_y", "Strip Y", -0.25, 0.25, 0.005)
	_gfx_add_slider(list, "strip_z", "Strip Z", -0.5, 0.5, 0.005)
	_gfx_add_slider(list, "strip_pitch", "Strip Pitch", -90.0, 90.0, 1.0)
	_gfx_add_slider(list, "strip_yaw", "Strip Yaw", -180.0, 180.0, 1.0)
	_gfx_add_slider(list, "strip_roll", "Strip Roll", -45.0, 45.0, 1.0)
	_gfx_add_slider(list, "strip_energy", "Strip Brightness", 0.0, 2.0, 0.01)
	_gfx_add_slider(list, "strip_range", "Strip Range", 0.3, 4.0, 0.01)
	_gfx_add_slider(list, "strip_angle", "Strip Cone", 20.0, 120.0, 1.0)
	_gfx_add_slider(list, "strip_size", "Strip Size", 0.05, 2.0, 0.01)
	_gfx_add_slider(list, "strip_width", "Strip Width", 0.2, 1.5, 0.01)

	_gfx_add_section(list, "DRAG PATTY HERE")
	_gfx_add_check(list, "bz_debug_outline", "Show Build Zone Outlines")
	_gfx_add_slider(list, "bz_row_left", "PANEL Row Left", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_row_right", "PANEL Row Right", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_row_top", "PANEL Row Top", -40.0, 80.0, 1.0)
	_gfx_add_slider(list, "bz_row_bottom", "PANEL Row Bottom", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_panel_w", "PANEL Width", 80.0, 360.0, 1.0)
	_gfx_add_slider(list, "bz_panel_h", "PANEL Height", 120.0, 500.0, 1.0)
	_gfx_add_slider(list, "bz_zone_w", "ZONE Width", 80.0, 260.0, 1.0)
	_gfx_add_slider(list, "bz_zone_h", "ZONE Height", 80.0, 400.0, 1.0)
	_gfx_add_slider(list, "bz_zone_left", "ZONE Left In Panel", -200.0, 200.0, 1.0)
	_gfx_add_slider(list, "bz_zone_top", "ZONE Top", -400.0, 400.0, 1.0)
	_gfx_add_slider(list, "bz_lift_bottom", "ZONE Bottom", 40.0, 260.0, 1.0)
	_gfx_add_slider(list, "bz_plate_w", "PLATE Width (0=full)", 0.0, 400.0, 1.0)
	_gfx_add_slider(list, "bz_plate_h", "PLATE Height", 80.0, 400.0, 1.0)
	_gfx_add_slider(list, "bz_plate_shift", "PLATE Shift X", -120.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_plate_y", "PLATE Shift Y", -200.0, 200.0, 1.0)
	_gfx_add_slider(list, "bz_title_y", "DRAG PATTY HERE Y", -80.0, 200.0, 1.0)
	_gfx_add_slider(list, "bz_title_x", "DRAG PATTY HERE X", -120.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_plate_pad", "PLATE+12 Pad", 0.0, 60.0, 1.0)
	_gfx_add_slider(list, "bz_hit_l", "BUILD_HIT Pad Left", 0.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_hit_t", "BUILD_HIT Pad Top", 0.0, 200.0, 1.0)
	_gfx_add_slider(list, "bz_hit_r", "BUILD_HIT Pad Right", 0.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_hit_b", "BUILD_HIT Pad Bottom", 0.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_hit_shift_x", "BUILD_HIT Shift X", -120.0, 120.0, 1.0)
	_gfx_add_slider(list, "bz_drop_left", "DROP_L Left", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_drop_right", "DROP_L Right", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_drop_top", "DROP_L Top", -40.0, 80.0, 1.0)
	_gfx_add_slider(list, "bz_drop_bottom", "DROP_L Bottom", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "bz_grill_pad", "GRILL_LIM Pad", 0.0, 300.0, 1.0)
	_gfx_add_slider(list, "bz_lim_top", "GRILL_LIM Top", 0.0, 600.0, 1.0)
	_gfx_add_slider(list, "bz_lim_bot", "GRILL_LIM Bot Inset", 0.0, 300.0, 1.0)
	_gfx_add_slider(list, "bz_grill_drop_left", "GRILL_DROP Left", 0.0, 600.0, 1.0)
	_gfx_add_slider(list, "bz_grill_drop_top", "GRILL_DROP Top", 0.0, 300.0, 1.0)
	_gfx_add_slider(list, "bz_grill_drop_bottom", "GRILL_DROP Bottom", -300.0, 0.0, 1.0)

	_gfx_add_section(list, "INGREDIENTS IMAGE")
	_gfx_add_slider(list, "prep_ui_x", "INGREDIENTS Left", -200.0, 450.0, 1.0)
	_gfx_add_slider(list, "prep_ui_top", "INGREDIENTS Top", -400.0, 500.0, 1.0)
	_gfx_add_slider(list, "prep_ui_y", "INGREDIENTS Bottom", 0.0, 520.0, 1.0)
	_gfx_add_slider(list, "prep_ui_w", "INGREDIENTS Width", 100.0, 700.0, 1.0)
	_gfx_add_slider(list, "prep_ui_h", "INGREDIENTS Height", 80.0, 500.0, 1.0)
	_gfx_add_slider(list, "prep_img_y", "INGREDIENTS Image Up/Down", -200.0, 200.0, 1.0)

	_gfx_add_section(list, "BOTTOM STRIP ICONS")
	_gfx_add_slider(list, "strip_icon_w", "Icon Width", 24.0, 160.0, 1.0)
	_gfx_add_slider(list, "strip_icon_h", "Icon Height", 20.0, 120.0, 1.0)
	_gfx_add_slider(list, "strip_icon_x", "Icon Offset X", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "strip_icon_y", "Icon Offset Y", -40.0, 40.0, 1.0)
	_gfx_add_slider(list, "strip_bar_left", "Strip Bar Left", -200.0, 200.0, 1.0)
	_gfx_add_slider(list, "strip_bar_top", "Strip Bar Top", -200.0, 0.0, 1.0)
	_gfx_add_slider(list, "strip_bar_right", "Strip Bar Right", -200.0, 200.0, 1.0)
	_gfx_add_slider(list, "strip_bar_bottom", "Strip Bar Bottom", -200.0, 50.0, 1.0)

	var zone_btns := HBoxContainer.new()
	zone_btns.add_theme_constant_override("separation", 6)
	list.add_child(zone_btns)
	var copy_zones_btn := Button.new()
	copy_zones_btn.text = "Copy Build GFX Values"
	copy_zones_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_button(copy_zones_btn, true, 11)
	copy_zones_btn.pressed.connect(func():
		_sfx_click()
		_copy_build_zone_values()
	)
	zone_btns.add_child(copy_zones_btn)

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
	## Belt-and-suspenders — heat warp must match the tuned defaults on boot.
	_apply_heat_warp_settings({
		"heat_warp_on": true,
		"heat_warp_size": float(GFX_DEFAULTS["heat_warp_size"]),
		"heat_warp_speed": float(GFX_DEFAULTS["heat_warp_speed"]),
		"heat_warp_strength": float(GFX_DEFAULTS["heat_warp_strength"]),
		"heat_warp_tight": float(GFX_DEFAULTS["heat_warp_tight"]),
	})
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
	if open:
		## Parent under Options layer so it sits above the dim + panel.
		var host: Node = options_root if options_root != null else get_node_or_null("UI/Root")
		if host != null and is_instance_valid(host):
			if gfx_panel.get_parent() != host:
				gfx_panel.reparent(host)
			host.move_child(gfx_panel, host.get_child_count() - 1)
		gfx_panel.z_index = 30
		gfx_panel.set_anchors_preset(Control.PRESET_CENTER)
		gfx_panel.offset_left = -210.0
		gfx_panel.offset_right = 210.0
		gfx_panel.offset_top = -310.0
		gfx_panel.offset_bottom = 310.0
		_flash("Graphics settings", Color("90CAF9"))


func _build_options_menu() -> void:
	## Own CanvasLayer so kitchen HUD / _input never blocks these buttons.
	if master_vol_row != null and is_instance_valid(master_vol_row):
		master_vol_row.visible = false

	options_layer = CanvasLayer.new()
	options_layer.name = "OptionsLayer"
	options_layer.layer = 100
	add_child(options_layer)

	options_root = Control.new()
	options_root.name = "OptionsMenu"
	options_root.visible = false
	options_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_root.mouse_filter = Control.MOUSE_FILTER_STOP
	options_root.process_mode = Node.PROCESS_MODE_ALWAYS
	options_layer.add_child(options_root)

	options_dim = ColorRect.new()
	options_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_dim.color = Color(0.02, 0.03, 0.05, 0.72)
	options_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	options_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if gfx_panel != null and gfx_panel.visible:
				return
			## Only close when clicking the dim itself (not the panel).
			_set_options_menu_open(false)
	)
	options_root.add_child(options_dim)

	options_panel = PanelContainer.new()
	options_panel.name = "OptionsPanel"
	options_panel.z_index = 2
	options_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	options_panel.custom_minimum_size = Vector2(400, 0)
	options_panel.set_anchors_preset(Control.PRESET_CENTER)
	options_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	## Size from content; pin center.
	options_panel.offset_left = -200.0
	options_panel.offset_right = 200.0
	options_panel.offset_top = -280.0
	options_panel.offset_bottom = 280.0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.11, 0.14, 0.98)
	psb.border_color = Color(1.0, 0.72, 0.28, 0.95)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 18
	psb.content_margin_right = 18
	psb.content_margin_top = 16
	psb.content_margin_bottom = 16
	options_panel.add_theme_stylebox_override("panel", psb)
	options_root.add_child(options_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	options_panel.add_child(v)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFontsScript.apply_label(title, true, 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	v.add_child(title)

	var hint := Label.new()
	hint.text = "Esc to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFontsScript.apply_label(hint, false, 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	v.add_child(hint)

	var vol_lab := Label.new()
	vol_lab.text = "MASTER VOLUME"
	vol_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFontsScript.apply_label(vol_lab, true, 13)
	vol_lab.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	v.add_child(vol_lab)

	options_vol_slider = HSlider.new()
	options_vol_slider.min_value = 0.0
	options_vol_slider.max_value = 1.0
	options_vol_slider.step = 0.01
	options_vol_slider.value = master_volume_linear
	options_vol_slider.custom_minimum_size = Vector2(0, 28)
	options_vol_slider.focus_mode = Control.FOCUS_ALL
	options_vol_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	options_vol_slider.value_changed.connect(func(val: float):
		_set_master_volume_linear(val, true)
	)
	v.add_child(options_vol_slider)

	_options_add_btn(v, "Graphics Settings…", func():
		_set_graphics_menu_open(true)
	)
	v.add_child(HSeparator.new())
	_options_add_btn(v, "Resume", func():
		_set_options_menu_open(false)
	)
	_options_add_btn(v, "Restart Day", func():
		_options_restart_day()
	)
	options_lobby_btn = _options_add_btn(v, "Back to Lobby", func():
		_options_back_to_lobby()
	)
	_options_add_btn(v, "Exit Game", func():
		_options_exit_game()
	)


func _options_add_btn(parent: Control, text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFontsScript.apply_button(btn, true, 15)
	## button_down fires even if something eats the release — more reliable than pressed alone.
	btn.button_down.connect(func():
		_sfx_click()
		action.call()
	)
	parent.add_child(btn)
	return btn


func _toggle_options_menu() -> void:
	_set_options_menu_open(not options_menu_open)


func _set_options_menu_open(open: bool) -> void:
	options_menu_open = open
	if options_root != null and is_instance_valid(options_root):
		options_root.visible = open
	if options_layer != null and is_instance_valid(options_layer):
		options_layer.visible = open
	if not open:
		_set_graphics_menu_open(false)
	else:
		if options_vol_slider != null and is_instance_valid(options_vol_slider):
			options_vol_slider.set_value_no_signal(master_volume_linear)
		if options_lobby_btn != null and is_instance_valid(options_lobby_btn):
			if mp_enabled or NetManager.is_online() or NetManager.role != NetManager.Role.NONE:
				options_lobby_btn.text = "Back to Lobby"
			else:
				options_lobby_btn.text = "Main Menu"
	if gfx_btn != null and is_instance_valid(gfx_btn):
		gfx_btn.text = "OPTIONS ▾" if open else "OPTIONS"


func _options_restart_day() -> void:
	_set_options_menu_open(false)
	if not playing and game_over_panel != null and game_over_panel.visible:
		if mp_enabled:
			mp_restart_day.rpc()
		else:
			_restart()
		return
	if mp_enabled:
		mp_restart_day.rpc()
	else:
		_restart()
	_flash("Day restarted", Color("90CAF9"))


func _options_back_to_lobby() -> void:
	_set_options_menu_open(false)
	playing = false
	if game_audio:
		game_audio.set_sizzle_active(false)
	if game_over_panel:
		game_over_panel.visible = false
	_clear_all_patty()
	_clear_spatula()
	_clear_warmer()
	_clear_customers()
	_clear_all_stations()
	_cancel_cheese_hold_silent()
	_cancel_shaker_hold_silent()
	_reset_oil_bottle()
	_reset_fire_extinguisher()
	_reset_glock()
	var was_mp := mp_enabled or NetManager.is_online() or NetManager.role != NetManager.Role.NONE
	if was_mp:
		NetManager.stop_browse()
		NetManager.leave()
		mp_enabled = false
		_open_mp_lobby()
		if start_overlay:
			start_overlay.visible = true
		_flash("Back in the lobby — host or join again", Color("90CAF9"))
	else:
		if start_overlay:
			start_overlay.visible = true
		_flash("Main menu", Color("90CAF9"))


func _options_exit_game() -> void:
	_set_options_menu_open(false)
	if mp_enabled or NetManager.is_online():
		NetManager.leave(false)
	get_tree().quit()


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
	## Heat warp lives on the grill shader, not the Environment.
	var hw_map := {
		"heat_warp_size": float(GFX_DEFAULTS["heat_warp_size"]),
		"heat_warp_speed": float(GFX_DEFAULTS["heat_warp_speed"]),
		"heat_warp_strength": float(GFX_DEFAULTS["heat_warp_strength"]),
		"heat_warp_tight": float(GFX_DEFAULTS["heat_warp_tight"]),
	}
	if heat_warp_mat != null:
		hw_map["heat_warp_speed"] = float(heat_warp_mat.get_shader_parameter("time_scale"))
		hw_map["heat_warp_strength"] = float(heat_warp_mat.get_shader_parameter("warp_strength"))
		hw_map["heat_warp_tight"] = float(heat_warp_mat.get_shader_parameter("mask_tight"))
	if heat_warp_mesh != null and is_instance_valid(heat_warp_mesh):
		var plane := heat_warp_mesh.mesh as PlaneMesh
		if plane != null and heat_warp_base_size.x > 0.001:
			hw_map["heat_warp_size"] = plane.size.x / heat_warp_base_size.x
	for key in hw_map:
		if gfx_sliders.has(key) and gfx_sliders[key] != null:
			gfx_sliders[key].set_value_no_signal(float(hw_map[key]))
			var row2: Node = gfx_sliders[key].get_parent()
			if row2 and row2.get_child_count() > 0:
				var top2 = row2.get_child(0)
				var val_lab2 = top2.get_node_or_null("Val") if top2 else null
				if val_lab2:
					val_lab2.text = "%.2f" % float(hw_map[key])
	if gfx_checks.has("heat_warp_on"):
		gfx_checks["heat_warp_on"].set_pressed_no_signal(heat_warp_enabled)
	## Window backdrop — read live transform so the menu matches the matte.
	if street_matte != null and is_instance_valid(street_matte):
		var bg_map := {
			"bg_y": street_matte.position.y,
			"bg_scale": street_matte.scale.x,
		}
		for key in bg_map:
			if gfx_sliders.has(key) and gfx_sliders[key] != null:
				gfx_sliders[key].set_value_no_signal(float(bg_map[key]))
				var row3: Node = gfx_sliders[key].get_parent()
				if row3:
					var top3 = row3.get_child(0) if row3.get_child_count() > 0 else null
					if top3:
						var val_lab3 = top3.get_node_or_null("Val")
						if val_lab3:
							val_lab3.text = "%.2f" % float(bg_map[key])
	if first_sale_decal != null and is_instance_valid(first_sale_decal):
		var sale_map := {
			"sale_x": first_sale_decal.position.x,
			"sale_y": first_sale_decal.position.y,
			"sale_z": first_sale_decal.position.z,
			"sale_scale": first_sale_decal.scale.x,
		}
		for key in sale_map:
			if gfx_sliders.has(key) and gfx_sliders[key] != null:
				gfx_sliders[key].set_value_no_signal(float(sale_map[key]))
				var row4: Node = gfx_sliders[key].get_parent()
				if row4:
					var top4 = row4.get_child(0) if row4.get_child_count() > 0 else null
					if top4:
						var val_lab4 = top4.get_node_or_null("Val")
						if val_lab4:
							val_lab4.text = "%.2f" % float(sale_map[key])
	if menu_board_decal != null and is_instance_valid(menu_board_decal):
		var menu_map := {
			"menu_x": menu_board_decal.position.x,
			"menu_y": menu_board_decal.position.y,
			"menu_z": menu_board_decal.position.z,
			"menu_scale": menu_board_decal.scale.x,
			"menu_yaw": menu_board_decal.rotation_degrees.y,
		}
		for key in menu_map:
			if gfx_sliders.has(key) and gfx_sliders[key] != null:
				gfx_sliders[key].set_value_no_signal(float(menu_map[key]))
				var row5: Node = gfx_sliders[key].get_parent()
				if row5:
					var top5 = row5.get_child(0) if row5.get_child_count() > 0 else null
					if top5:
						var val_lab5 = top5.get_node_or_null("Val")
						if val_lab5:
							val_lab5.text = "%.2f" % float(menu_map[key])
	if burner_strip_root != null and is_instance_valid(burner_strip_root) and not burner_flame_lights.is_empty():
		var probe: SpotLight3D = burner_flame_lights[0] as SpotLight3D
		var strip_map := {
			"strip_x": burner_strip_root.position.x,
			"strip_y": burner_strip_root.position.y,
			"strip_z": burner_strip_root.position.z,
			"strip_energy": burner_strip_energy,
		}
		if probe != null:
			strip_map["strip_pitch"] = probe.rotation_degrees.x
			strip_map["strip_yaw"] = probe.rotation_degrees.y
			strip_map["strip_roll"] = probe.rotation_degrees.z
			strip_map["strip_range"] = probe.spot_range
			strip_map["strip_angle"] = probe.spot_angle
			strip_map["strip_size"] = probe.light_size
		if burner_strip_cook_w > 0.001 and probe != null and burner_flame_lights.size() > 1:
			var edge: SpotLight3D = burner_flame_lights[burner_flame_lights.size() - 1] as SpotLight3D
			if edge != null:
				strip_map["strip_width"] = absf(edge.position.x) * 2.0 / burner_strip_cook_w
		for key in strip_map:
			if gfx_sliders.has(key) and gfx_sliders[key] != null:
				gfx_sliders[key].set_value_no_signal(float(strip_map[key]))
				var row6: Node = gfx_sliders[key].get_parent()
				if row6:
					var top6 = row6.get_child(0) if row6.get_child_count() > 0 else null
					if top6:
						var val_lab6 = top6.get_node_or_null("Val")
						if val_lab6:
							val_lab6.text = "%.2f" % float(strip_map[key])
	for key in BUILD_GFX_KEYS:
		if gfx_sliders.has(key) and gfx_sliders[key] != null:
			var val := float(_build_zone_cfg.get(key, GFX_DEFAULTS.get(key, 0.0)))
			gfx_sliders[key].set_value_no_signal(val)
			var row7: Node = gfx_sliders[key].get_parent()
			if row7:
				var top7 = row7.get_child(0) if row7.get_child_count() > 0 else null
				if top7:
					var val_lab7 = top7.get_node_or_null("Val")
					if val_lab7:
						val_lab7.text = "%.1f" % val


func _apply_burner_strip_settings(s: Dictionary) -> void:
	if burner_strip_root == null or not is_instance_valid(burner_strip_root):
		return
	burner_strip_energy = float(s.get("strip_energy", GFX_DEFAULTS["strip_energy"]))
	burner_strip_root.position = Vector3(
		float(s.get("strip_x", GFX_DEFAULTS["strip_x"])),
		float(s.get("strip_y", GFX_DEFAULTS["strip_y"])),
		float(s.get("strip_z", GFX_DEFAULTS["strip_z"]))
	)
	var pitch := float(s.get("strip_pitch", GFX_DEFAULTS["strip_pitch"]))
	var yaw := float(s.get("strip_yaw", GFX_DEFAULTS["strip_yaw"]))
	var roll := float(s.get("strip_roll", GFX_DEFAULTS["strip_roll"]))
	var rng := float(s.get("strip_range", GFX_DEFAULTS["strip_range"]))
	var angle := float(s.get("strip_angle", GFX_DEFAULTS["strip_angle"]))
	var size := float(s.get("strip_size", GFX_DEFAULTS["strip_size"]))
	var width_mul := float(s.get("strip_width", GFX_DEFAULTS["strip_width"]))
	var count := burner_flame_lights.size()
	var strip_on := grill_on and burner_flame_root != null and is_instance_valid(burner_flame_root) and burner_flame_root.visible
	for i in count:
		var light = burner_flame_lights[i]
		if light == null or not is_instance_valid(light) or not light is SpotLight3D:
			continue
		var sl := light as SpotLight3D
		if count > 0 and burner_strip_cook_w > 0.001:
			var t := (float(i) + 0.5) / float(count) - 0.5
			sl.position = Vector3(t * burner_strip_cook_w * width_mul, 0.0, 0.0)
		sl.rotation_degrees = Vector3(pitch, yaw, roll)
		sl.light_energy = burner_strip_energy if strip_on else 0.0
		sl.spot_range = rng
		sl.spot_angle = angle
		sl.light_size = size


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
	_apply_heat_warp_settings(s)
	_apply_street_matte_settings(s)
	_apply_first_sale_decal_settings(s)
	_apply_menu_board_decal_settings(s)
	_apply_burner_strip_settings(s)
	_apply_build_zone_settings(s)


func _apply_prep_ui_overlay_layout() -> void:
	if prep_ui_overlay == null or not is_instance_valid(prep_ui_overlay):
		return
	var top := _bz("prep_ui_top")
	var w := _bz("prep_ui_w")
	var h := _bz("prep_ui_h")
	prep_ui_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	prep_ui_overlay.position = Vector2(_bz("prep_ui_x"), top + _bz("prep_img_y"))
	prep_ui_overlay.custom_minimum_size = Vector2(w, h)
	prep_ui_overlay.size = Vector2(w, h)


func _build_prep_ui_overlay() -> void:
	## Hidden for now — tomatoes/onions/buns art over the Build counter.
	if prep_ui_overlay != null and is_instance_valid(prep_ui_overlay):
		prep_ui_overlay.queue_free()
		prep_ui_overlay = null


func _apply_build_zone_settings(s: Dictionary) -> void:
	for key in BUILD_GFX_KEYS:
		_build_zone_cfg[key] = float(s.get(key, GFX_DEFAULTS.get(key, 0.0)))
	_layout_build_column_children()
	for i in STATION_COUNT:
		if i >= stations.size():
			continue
		var panel: Control = stations[i].get("panel", null)
		if panel == null or not is_instance_valid(panel):
			continue
		panel.custom_minimum_size = Vector2(_bz("bz_panel_w"), _bz("bz_panel_h"))
		var build_zone := panel.get_node_or_null("BuildZone") as Control
		if build_zone != null and is_instance_valid(build_zone):
			build_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
			build_zone.grow_horizontal = Control.GROW_DIRECTION_BOTH
			build_zone.grow_vertical = Control.GROW_DIRECTION_BOTH
			build_zone.offset_left = int(_bz("bz_zone_left"))
			build_zone.offset_top = int(_bz("bz_zone_top"))
			build_zone.offset_right = 0
			build_zone.offset_bottom = -int(_bz("bz_lift_bottom"))
			build_zone.custom_minimum_size = Vector2.ZERO
		var plate_wrap: Control = stations[i].get("plate", null)
		if plate_wrap != null and is_instance_valid(plate_wrap):
			var plate_w := _bz("bz_plate_w")
			if plate_w <= 1.0:
				plate_w = _bz("bz_panel_w")
			plate_wrap.custom_minimum_size = Vector2(plate_w, _bz("bz_plate_h"))
			plate_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plate_wrap.position = Vector2(_bz("bz_plate_shift"), _bz("bz_plate_y"))
			var title := plate_wrap.get_node_or_null("BuildTitle") as Label
			if title != null and is_instance_valid(title):
				title.offset_top = int(_bz("bz_title_y"))
				title.offset_left = int(_bz("bz_title_x"))
	_apply_prep_ui_overlay_layout()
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.offset_left = _bz("bz_grill_drop_left")
		grill_drop_zone.offset_top = _bz("bz_grill_drop_top")
		grill_drop_zone.offset_bottom = _bz("bz_grill_drop_bottom")
	_apply_ingredient_strip_settings(s)
	build_area_debug_outline = bool(s.get("bz_debug_outline", GFX_DEFAULTS["bz_debug_outline"]))
	call_deferred("_refresh_build_debug_outlines")


func _apply_ingredient_strip_settings(s: Dictionary) -> void:
	if ingredient_legend != null and is_instance_valid(ingredient_legend):
		ingredient_legend.offset_left = float(s.get("strip_bar_left", GFX_DEFAULTS["strip_bar_left"]))
		ingredient_legend.offset_top = float(s.get("strip_bar_top", GFX_DEFAULTS["strip_bar_top"]))
		ingredient_legend.offset_right = float(s.get("strip_bar_right", GFX_DEFAULTS["strip_bar_right"]))
		ingredient_legend.offset_bottom = float(s.get("strip_bar_bottom", GFX_DEFAULTS["strip_bar_bottom"]))
	var iw := float(s.get("strip_icon_w", GFX_DEFAULTS["strip_icon_w"]))
	var ih := float(s.get("strip_icon_h", GFX_DEFAULTS["strip_icon_h"]))
	var ix := float(s.get("strip_icon_x", GFX_DEFAULTS["strip_icon_x"]))
	var iy := float(s.get("strip_icon_y", GFX_DEFAULTS["strip_icon_y"]))
	for id in ingredient_buttons:
		var btn: Control = ingredient_buttons[id]
		if btn == null or not is_instance_valid(btn):
			continue
		var margin := btn.get_node_or_null("IconMargin") as MarginContainer
		if margin == null or not is_instance_valid(margin):
			continue
		margin.add_theme_constant_override("margin_left", int(ix))
		margin.add_theme_constant_override("margin_top", int(iy))
		var icon := margin.get_node_or_null("StripIcon") as TextureRect
		if icon != null and is_instance_valid(icon):
			icon.custom_minimum_size = Vector2(iw, ih)
			icon.size = Vector2(iw, ih)


func _copy_build_zone_values() -> void:
	var s := _read_graphics_from_ui()
	var lines: PackedStringArray = []
	lines.append("DRAG PATTY HERE / build zone:")
	for key in BUILD_ZONE_GFX_KEYS:
		lines.append("%s = %.1f" % [key, float(s.get(key, GFX_DEFAULTS.get(key, 0.0)))])
	lines.append("")
	lines.append("Ingredients image:")
	for key in PREP_GFX_KEYS:
		lines.append("%s = %.1f" % [key, float(s.get(key, GFX_DEFAULTS.get(key, 0.0)))])
	lines.append("")
	lines.append("Bottom strip icons:")
	for key in STRIP_GFX_KEYS:
		lines.append("%s = %.1f" % [key, float(s.get(key, GFX_DEFAULTS.get(key, 0.0)))])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	_flash("Build GFX copied — paste in chat", Color("90CAF9"))


func _apply_street_matte_settings(s: Dictionary) -> void:
	if street_matte == null or not is_instance_valid(street_matte):
		return
	var y := float(s.get("bg_y", STREET_MATTE_DEFAULT_Y))
	var sc := float(s.get("bg_scale", 1.0))
	street_matte.position = Vector3(0.0, y, STREET_MATTE_BASE_Z)
	street_matte.scale = Vector3(sc, sc, 1.0)
	if street_matte_body != null and is_instance_valid(street_matte_body):
		street_matte_body.position = street_matte.position
		street_matte_body.rotation_degrees = street_matte.rotation_degrees
		street_matte_body.scale = Vector3(sc, sc, 1.0)


func _apply_first_sale_decal_settings(s: Dictionary) -> void:
	if first_sale_decal == null or not is_instance_valid(first_sale_decal):
		return
	var x := float(s.get("sale_x", FIRST_SALE_DEFAULT_X))
	var y := float(s.get("sale_y", FIRST_SALE_DEFAULT_Y))
	var z := float(s.get("sale_z", FIRST_SALE_DEFAULT_Z))
	var sc := float(s.get("sale_scale", FIRST_SALE_DEFAULT_SCALE))
	first_sale_decal.position = Vector3(x, y, z)
	first_sale_decal.scale = Vector3(sc, sc, 1.0)
	sale_home = first_sale_decal.position
	_refresh_glock_cover_lock()


func _apply_menu_board_decal_settings(s: Dictionary) -> void:
	if menu_board_decal == null or not is_instance_valid(menu_board_decal):
		return
	var x := float(s.get("menu_x", MENU_BOARD_DEFAULT_X))
	var y := float(s.get("menu_y", MENU_BOARD_DEFAULT_Y))
	var z := float(s.get("menu_z", MENU_BOARD_DEFAULT_Z))
	var sc := float(s.get("menu_scale", MENU_BOARD_DEFAULT_SCALE))
	var yaw := float(s.get("menu_yaw", MENU_BOARD_DEFAULT_YAW))
	menu_board_decal.position = Vector3(x, y, z)
	menu_board_decal.rotation_degrees = Vector3(0.0, yaw, 0.0)
	menu_board_decal.scale = Vector3(sc, sc, 1.0)


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
	## One-shot: apply full tuned graphics look (bloom + lighting + look + AO off).
	if not cfg.has_section_key("gfx", "gfx_preset_v7"):
		for hk in [
			"bloom", "glow_intensity", "glow_strength", "glow_threshold", "glow_on",
			"exposure", "ambient", "sun", "kitchen", "grill_lamp", "window_wash",
			"saturation", "contrast", "ssao", "ssil", "sky_energy",
			"heat_warp_on", "heat_warp_size", "heat_warp_speed", "heat_warp_strength", "heat_warp_tight",
		]:
			cfg.set_value("gfx", hk, GFX_DEFAULTS[hk])
		cfg.set_value("gfx", "gfx_preset_v7", true)
		cfg.save(GFX_CFG_PATH)
	## One-shot: snap wall decals into the camera frustum (were off-screen / broken).
	if not cfg.has_section_key("gfx", "gfx_decal_v2"):
		for hk in [
			"sale_x", "sale_y", "sale_z", "sale_scale",
			"menu_x", "menu_y", "menu_z", "menu_scale", "menu_yaw",
		]:
			cfg.set_value("gfx", hk, GFX_DEFAULTS[hk])
		cfg.set_value("gfx", "gfx_decal_v2", true)
		cfg.save(GFX_CFG_PATH)
	## Half-size First Sale, nudge up; menu +0.5 ft right.
	if not cfg.has_section_key("gfx", "gfx_decal_v3"):
		for hk in [
			"sale_x", "sale_y", "sale_z", "sale_scale",
			"menu_x", "menu_y", "menu_z", "menu_scale", "menu_yaw",
		]:
			cfg.set_value("gfx", hk, GFX_DEFAULTS[hk])
		cfg.set_value("gfx", "gfx_decal_v3", true)
		cfg.save(GFX_CFG_PATH)
	## Menu further right.
	if not cfg.has_section_key("gfx", "gfx_decal_v4"):
		cfg.set_value("gfx", "menu_x", GFX_DEFAULTS["menu_x"])
		cfg.set_value("gfx", "gfx_decal_v4", true)
		cfg.save(GFX_CFG_PATH)
	## Menu +2 ft right; First Sale +1 ft up.
	if not cfg.has_section_key("gfx", "gfx_decal_v5"):
		cfg.set_value("gfx", "menu_x", GFX_DEFAULTS["menu_x"])
		cfg.set_value("gfx", "sale_y", GFX_DEFAULTS["sale_y"])
		cfg.set_value("gfx", "gfx_decal_v5", true)
		cfg.save(GFX_CFG_PATH)
	## Fix: camera-right is world −X; bill down 7 in.
	if not cfg.has_section_key("gfx", "gfx_decal_v6"):
		cfg.set_value("gfx", "menu_x", GFX_DEFAULTS["menu_x"])
		cfg.set_value("gfx", "sale_y", GFX_DEFAULTS["sale_y"])
		cfg.set_value("gfx", "gfx_decal_v6", true)
		cfg.save(GFX_CFG_PATH)
	## Bill −2 in; menu +6 in camera-right.
	if not cfg.has_section_key("gfx", "gfx_decal_v7"):
		cfg.set_value("gfx", "menu_x", GFX_DEFAULTS["menu_x"])
		cfg.set_value("gfx", "sale_y", GFX_DEFAULTS["sale_y"])
		cfg.set_value("gfx", "gfx_decal_v7", true)
		cfg.save(GFX_CFG_PATH)
	## First Sale 15% smaller.
	if not cfg.has_section_key("gfx", "gfx_decal_v8"):
		cfg.set_value("gfx", "sale_scale", GFX_DEFAULTS["sale_scale"])
		cfg.set_value("gfx", "gfx_decal_v8", true)
		cfg.save(GFX_CFG_PATH)
	## First Sale slightly bigger again (covers the hidden Glock).
	if not cfg.has_section_key("gfx", "gfx_decal_v9"):
		cfg.set_value("gfx", "sale_scale", GFX_DEFAULTS["sale_scale"])
		cfg.set_value("gfx", "sale_x", GFX_DEFAULTS["sale_x"])
		cfg.set_value("gfx", "sale_y", GFX_DEFAULTS["sale_y"])
		cfg.set_value("gfx", "sale_z", GFX_DEFAULTS["sale_z"])
		cfg.set_value("gfx", "gfx_decal_v9", true)
		cfg.save(GFX_CFG_PATH)
	## Pull plaque toward cook so the Glock sits clearly behind it.
	if not cfg.has_section_key("gfx", "gfx_decal_v10"):
		cfg.set_value("gfx", "sale_z", GFX_DEFAULTS["sale_z"])
		cfg.set_value("gfx", "gfx_decal_v10", true)
		cfg.save(GFX_CFG_PATH)
	## First Sale down 1 in.
	if not cfg.has_section_key("gfx", "gfx_decal_v11"):
		cfg.set_value("gfx", "sale_y", GFX_DEFAULTS["sale_y"])
		cfg.set_value("gfx", "gfx_decal_v11", true)
		cfg.save(GFX_CFG_PATH)
	## First Sale 20% smaller.
	if not cfg.has_section_key("gfx", "gfx_decal_v12"):
		cfg.set_value("gfx", "sale_scale", GFX_DEFAULTS["sale_scale"])
		cfg.set_value("gfx", "gfx_decal_v12", true)
		cfg.save(GFX_CFG_PATH)
	## Restore prep-ingredient row layout after hitbox tuning pass.
	if not cfg.has_section_key("gfx", "gfx_bz_layout_v1"):
		for key in BUILD_GFX_KEYS:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_layout_v1", true)
		cfg.save(GFX_CFG_PATH)
	## Shift build row right so the floating burger stays visible on screen.
	if not cfg.has_section_key("gfx", "gfx_bz_layout_v2"):
		for key in BUILD_GFX_KEYS:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_layout_v2", true)
		cfg.save(GFX_CFG_PATH)
	## New plate / prep / strip GFX keys — add defaults without resetting tuned bz_* row.
	if not cfg.has_section_key("gfx", "gfx_bz_layout_v3"):
		for key in ["bz_plate_w", "bz_plate_h", "bz_plate_shift", "bz_plate_y", "bz_plate_pad", "bz_drop_left",
				"bz_grill_drop_left", "bz_grill_drop_top", "bz_grill_drop_bottom",
				"prep_ui_x", "prep_ui_top", "prep_ui_y", "prep_ui_w", "prep_ui_h", "prep_img_y",
				"strip_icon_w", "strip_icon_h", "strip_icon_x", "strip_icon_y",
				"strip_bar_left", "strip_bar_top", "strip_bar_right", "strip_bar_bottom"]:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_layout_v3", true)
		cfg.save(GFX_CFG_PATH)
	## Prep image is panel-relative — convert old BuildZone-relative saved offsets.
	if not cfg.has_section_key("gfx", "gfx_prep_panel_v1"):
		var py_old := float(cfg.get_value("gfx", "prep_ui_y", GFX_DEFAULTS["prep_ui_y"]))
		if py_old < 100.0:
			var px_old := float(cfg.get_value("gfx", "prep_ui_x", GFX_DEFAULTS["prep_ui_x"]))
			var ph := float(cfg.get_value("gfx", "prep_ui_h", GFX_DEFAULTS["prep_ui_h"]))
			var zl := float(cfg.get_value("gfx", "bz_zone_left", GFX_DEFAULTS["bz_zone_left"]))
			var lift := float(cfg.get_value("gfx", "bz_lift_bottom", GFX_DEFAULTS["bz_lift_bottom"]))
			var zh := float(cfg.get_value("gfx", "bz_zone_h", GFX_DEFAULTS["bz_zone_h"]))
			cfg.set_value("gfx", "prep_ui_x", zl + px_old)
			cfg.set_value("gfx", "prep_ui_y", lift + zh - (py_old + ph))
		cfg.set_value("gfx", "gfx_prep_panel_v1", true)
		cfg.save(GFX_CFG_PATH)
	## Up/down box edges + image nudge — add defaults without resetting tuned layout.
	if not cfg.has_section_key("gfx", "gfx_bz_layout_v4"):
		var panel_h := float(cfg.get_value("gfx", "bz_panel_h", GFX_DEFAULTS["bz_panel_h"]))
		var prep_bot := float(cfg.get_value("gfx", "prep_ui_y", GFX_DEFAULTS["prep_ui_y"]))
		var prep_h := float(cfg.get_value("gfx", "prep_ui_h", GFX_DEFAULTS["prep_ui_h"]))
		cfg.set_value("gfx", "prep_ui_top", panel_h - prep_bot - prep_h)
		var zone_bot := float(cfg.get_value("gfx", "bz_lift_bottom", GFX_DEFAULTS["bz_lift_bottom"]))
		var zone_h := float(cfg.get_value("gfx", "bz_zone_h", GFX_DEFAULTS["bz_zone_h"]))
		cfg.set_value("gfx", "bz_zone_top", panel_h - zone_bot - zone_h)
		cfg.set_value("gfx", "bz_plate_y", GFX_DEFAULTS["bz_plate_y"])
		cfg.set_value("gfx", "prep_img_y", GFX_DEFAULTS["prep_img_y"])
		cfg.set_value("gfx", "gfx_bz_layout_v4", true)
		cfg.save(GFX_CFG_PATH)
	## Wider / lower Build stack with left margin.
	if not cfg.has_section_key("gfx", "gfx_bz_layout_v5"):
		for key in [
			"bz_row_left", "bz_panel_w", "bz_panel_h", "bz_zone_w", "bz_zone_h",
			"bz_plate_h", "bz_plate_shift", "bz_plate_y",
		]:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_layout_v5", true)
		cfg.save(GFX_CFG_PATH)
	## Prep image is screen-absolute on UI/Root — snap tuned placement.
	if not cfg.has_section_key("gfx", "gfx_prep_screen_v1"):
		cfg.set_value("gfx", "prep_ui_x", GFX_DEFAULTS["prep_ui_x"])
		cfg.set_value("gfx", "prep_ui_top", GFX_DEFAULTS["prep_ui_top"])
		cfg.set_value("gfx", "prep_ui_y", GFX_DEFAULTS["prep_ui_y"])
		cfg.set_value("gfx", "gfx_prep_screen_v1", true)
		cfg.save(GFX_CFG_PATH)
	## User-tuned ingredients placement — snap as new defaults.
	if not cfg.has_section_key("gfx", "gfx_prep_screen_v2"):
		for key in PREP_GFX_KEYS:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_prep_screen_v2", true)
		cfg.save(GFX_CFG_PATH)
	## Nudge ingredients up and shrink 20%.
	if not cfg.has_section_key("gfx", "gfx_prep_screen_v3"):
		for key in PREP_GFX_KEYS:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_prep_screen_v3", true)
		cfg.save(GFX_CFG_PATH)
	## Nudge ingredients down 22px.
	if not cfg.has_section_key("gfx", "gfx_prep_screen_v4"):
		cfg.set_value("gfx", "prep_ui_top", GFX_DEFAULTS["prep_ui_top"])
		cfg.set_value("gfx", "gfx_prep_screen_v4", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "bz_debug_outline"):
		cfg.set_value("gfx", "bz_debug_outline", GFX_DEFAULTS["bz_debug_outline"])
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "bz_hit_shift_x"):
		cfg.set_value("gfx", "bz_hit_shift_x", GFX_DEFAULTS["bz_hit_shift_x"])
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_zone_nudge_v1"):
		cfg.set_value("gfx", "bz_zone_left", GFX_DEFAULTS["bz_zone_left"])
		cfg.set_value("gfx", "bz_zone_top", GFX_DEFAULTS["bz_zone_top"])
		cfg.set_value("gfx", "gfx_bz_zone_nudge_v1", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_title_board_v1"):
		cfg.set_value("gfx", "bz_zone_top", GFX_DEFAULTS["bz_zone_top"])
		cfg.set_value("gfx", "bz_title_y", GFX_DEFAULTS["bz_title_y"])
		cfg.set_value("gfx", "gfx_bz_title_board_v1", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_build_nudge_v1"):
		cfg.set_value("gfx", "bz_zone_left", GFX_DEFAULTS["bz_zone_left"])
		cfg.set_value("gfx", "bz_zone_top", GFX_DEFAULTS["bz_zone_top"])
		cfg.set_value("gfx", "bz_title_x", GFX_DEFAULTS["bz_title_x"])
		cfg.set_value("gfx", "gfx_bz_build_nudge_v1", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_build_nudge_v2"):
		cfg.set_value("gfx", "bz_zone_left", GFX_DEFAULTS["bz_zone_left"])
		cfg.set_value("gfx", "bz_zone_top", GFX_DEFAULTS["bz_zone_top"])
		cfg.set_value("gfx", "gfx_bz_build_nudge_v2", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_build_nudge_v3"):
		cfg.set_value("gfx", "bz_zone_left", GFX_DEFAULTS["bz_zone_left"])
		cfg.set_value("gfx", "bz_zone_top", GFX_DEFAULTS["bz_zone_top"])
		cfg.set_value("gfx", "bz_title_y", GFX_DEFAULTS["bz_title_y"])
		cfg.set_value("gfx", "gfx_bz_build_nudge_v3", true)
		cfg.save(GFX_CFG_PATH)
	if not cfg.has_section_key("gfx", "gfx_bz_build_nudge_v4"):
		cfg.set_value("gfx", "bz_title_y", GFX_DEFAULTS["bz_title_y"])
		cfg.set_value("gfx", "gfx_bz_build_nudge_v4", true)
		cfg.save(GFX_CFG_PATH)
	## Left Build column parent (~15% width) — reset row / plate / drop into the column.
	if not cfg.has_section_key("gfx", "gfx_bz_build_column_v1"):
		for key in [
			"bz_row_left", "bz_row_right", "bz_row_top", "bz_row_bottom",
			"bz_panel_w", "bz_panel_h", "bz_zone_w", "bz_zone_h",
			"bz_zone_left", "bz_zone_top", "bz_lift_bottom",
			"bz_plate_w", "bz_plate_h", "bz_plate_shift", "bz_plate_y", "bz_plate_pad",
			"bz_title_y", "bz_title_x", "bz_hit_shift_x",
			"bz_drop_left", "bz_drop_right", "bz_drop_top", "bz_drop_bottom",
		]:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_build_column_v1", true)
		cfg.save(GFX_CFG_PATH)
	## Full-width plate in Build column + rebalanced layer sizes.
	if not cfg.has_section_key("gfx", "gfx_bz_build_column_v2"):
		for key in [
			"bz_zone_w", "bz_zone_left", "bz_zone_top",
			"bz_plate_w", "bz_plate_h", "bz_plate_shift", "bz_plate_y",
		]:
			cfg.set_value("gfx", key, GFX_DEFAULTS[key])
		cfg.set_value("gfx", "gfx_bz_build_column_v2", true)
		cfg.save(GFX_CFG_PATH)
	## Pin 🔔/🗑/All to screen-left (15px) — clear old centered strip pads.
	if not cfg.has_section_key("gfx", "gfx_bz_build_column_v3"):
		cfg.set_value("gfx", "bz_row_left", GFX_DEFAULTS["bz_row_left"])
		cfg.set_value("gfx", "gfx_bz_build_column_v3", true)
		cfg.save(GFX_CFG_PATH)
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


func _style_quiet_hud_button(btn: Button, font_size: int = 12) -> void:
	## Black chrome + grey text — stays out of the way of the cook view.
	UiFontsScript.apply_button(btn, true, font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.26, 0.26, 0.28, 0.65)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.13, 0.13, 0.14, 0.92)
	sbh.border_color = Color(0.38, 0.38, 0.4, 0.75)
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(0.04, 0.04, 0.05, 0.94)
	btn.add_theme_stylebox_override("pressed", sbp)
	var grey := Color(0.58, 0.58, 0.62)
	btn.add_theme_color_override("font_color", grey)
	btn.add_theme_color_override("font_hover_color", Color(0.78, 0.78, 0.82))
	btn.add_theme_color_override("font_pressed_color", Color(0.5, 0.5, 0.54))


func _layout_top_bar_hud() -> void:
	## Day + money stay top-right; combo sits above the order ticket rail.
	var top_bar: HBoxContainer = get_node_or_null("UI/Root/TopBar") as HBoxContainer
	if top_bar == null:
		return
	top_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_bar.offset_left = -320.0
	top_bar.offset_right = -12.0
	top_bar.offset_top = 33.0
	top_bar.offset_bottom = 73.0
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	if hud_day != null and is_instance_valid(hud_day):
		top_bar.move_child(hud_day, 0)
	if hud_money != null and is_instance_valid(hud_money):
		top_bar.move_child(hud_money, top_bar.get_child_count() - 1)
	_layout_combo_above_tickets()


func _layout_combo_above_tickets() -> void:
	if hud_combo == null or not is_instance_valid(hud_combo):
		return
	var ticket_rail: Control = get_node_or_null("UI/Root/WindowTicketRail")
	if ticket_rail == null:
		return
	if hud_combo.get_parent() != ticket_rail:
		hud_combo.reparent(ticket_rail)
	ticket_rail.move_child(hud_combo, 0)
	hud_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_combo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hud_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_combo.custom_minimum_size = Vector2(0, 18)
	UiFontsScript.apply_label(hud_combo, true, 13)
	hud_combo.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	hud_combo.add_theme_constant_override("outline_size", 2)
	hud_combo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))


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
	window_pause_btn.custom_minimum_size = Vector2(78, 26)
	_style_quiet_hud_button(window_pause_btn, 11)
	window_pause_btn.pressed.connect(func():
		_sfx_click()
		_toggle_service_window()
	)
	ui_root.add_child(window_pause_btn)


func _build_master_volume_ui() -> void:
	## Top bar master volume — sits beside Pause + GFX.
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	_load_audio_settings()

	master_vol_row = HBoxContainer.new()
	master_vol_row.name = "MasterVolumeRow"
	master_vol_row.z_index = 30
	master_vol_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	master_vol_row.position = Vector2(204, 12)
	master_vol_row.custom_minimum_size = Vector2(210, 36)
	master_vol_row.add_theme_constant_override("separation", 8)
	master_vol_row.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(master_vol_row)

	var lab := Label.new()
	lab.text = "MASTER"
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFontsScript.apply_label(lab, true, 12)
	lab.add_theme_color_override("font_color", Color(0.58, 0.58, 0.62))
	lab.add_theme_constant_override("outline_size", 2)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	master_vol_row.add_child(lab)

	master_vol_slider = HSlider.new()
	master_vol_slider.min_value = 0.0
	master_vol_slider.max_value = 1.0
	master_vol_slider.step = 0.01
	master_vol_slider.value = master_volume_linear
	master_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_vol_slider.custom_minimum_size = Vector2(140, 22)
	master_vol_slider.focus_mode = Control.FOCUS_NONE
	master_vol_slider.value_changed.connect(func(v: float):
		_set_master_volume_linear(v, true)
	)
	master_vol_row.add_child(master_vol_slider)
	_set_master_volume_linear(master_volume_linear, false)


func _set_master_volume_linear(v: float, save: bool = true) -> void:
	master_volume_linear = clampf(v, 0.0, 1.0)
	var effective := master_volume_linear * MASTER_VOL_MAX
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		if effective <= 0.0001:
			AudioServer.set_bus_volume_db(bus, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus, linear_to_db(effective))
	if master_vol_slider != null and is_instance_valid(master_vol_slider):
		if absf(master_vol_slider.value - master_volume_linear) > 0.0005:
			master_vol_slider.set_value_no_signal(master_volume_linear)
	if options_vol_slider != null and is_instance_valid(options_vol_slider):
		if absf(options_vol_slider.value - master_volume_linear) > 0.0005:
			options_vol_slider.set_value_no_signal(master_volume_linear)
	if save:
		_save_audio_settings()


func _load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(AUDIO_CFG_PATH) != OK:
		return
	if cfg.has_section_key("audio", AUDIO_MASTER_KEY):
		master_volume_linear = clampf(float(cfg.get_value("audio", AUDIO_MASTER_KEY)), 0.0, 1.0)
	elif cfg.has_section_key("audio", "master"):
		## Legacy absolute bus linear → remap so old 0.20 ≈ full slider.
		var old := clampf(float(cfg.get_value("audio", "master")), 0.0, 1.0)
		master_volume_linear = clampf(old / MASTER_VOL_MAX, 0.0, 1.0)


func _save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(AUDIO_CFG_PATH)
	cfg.set_value("audio", AUDIO_MASTER_KEY, master_volume_linear)
	cfg.save(AUDIO_CFG_PATH)


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
	spatula_owner_id = 0
	spatula_from_build = false
	spatula_lmb_held = false
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()


# --- Customers --------------------------------------------------------------

func _spawn_terrorist_wave() -> void:
	if not TERRORISTS_ENABLED:
		return
	# terrorist_wave_active = true
	# _sync_combat_audio()
	# var count := randi_range(3, 5)
	# _flash("ARMED HOSTILES — GRAB THE GLOCK!", Color("EF5350"))
	# if game_audio and game_audio.has_method("play_gunshot"):
	# 	game_audio.play_gunshot()
	# for i in count:
	# 	var role := "bomber" if randf() < 0.38 else "gun"
	# 	var roll := randf()
	# 	var tier := "distant" if roll < 0.4 else ("far" if roll < 0.75 else "mid")
	# 	var pose: Dictionary = TerroristCustomerScript.opening_pose(i, tier, role)
	# 	_spawn_terrorist_unit(
	# 		i % TerroristCustomerScript.TERR_LANE_X.size(),
	# 		pose["pos"],
	# 		float(pose["target_x"]),
	# 		float(pose["target_z"]),
	# 		role,
	# 		role == "gun",
	# 		role == "gun"
	# 	)


func _begin_opening_terror_ambush() -> void:
	if not TERRORISTS_ENABLED:
		return
	_opening_terr_active = true
	_opening_terr_timer = 0.0
	_opening_terr_spawned = 0
	terrorist_wave_active = true
	_sync_combat_audio()


func _update_opening_terror_ambush(delta: float) -> void:
	if not TERRORISTS_ENABLED:
		return
	if not _opening_terr_active:
		return
	_opening_terr_timer += delta
	while _opening_terr_spawned < OPENING_TERR_COUNT:
		if _opening_terr_timer < OPENING_TERR_AT[_opening_terr_spawned]:
			break
		_spawn_opening_terrorist(_opening_terr_spawned)
		_opening_terr_spawned += 1
	if _opening_terr_spawned >= OPENING_TERR_COUNT and _opening_terr_timer >= OPENING_TERR_WINDOW:
		_opening_terr_active = false


func _spawn_opening_terrorist(slot: int) -> void:
	if not TERRORISTS_ENABLED:
		return
	# var spec: Dictionary = OPENING_TERR_SPECS[clampi(slot, 0, OPENING_TERR_SPECS.size() - 1)]
	# var role: String = str(spec.get("role", "gun"))
	# var tier: String = str(spec.get("tier", "far"))
	# var lane := slot % TerroristCustomerScript.TERR_LANE_X.size()
	# var pose: Dictionary = TerroristCustomerScript.opening_pose(slot, tier, role)
	# if slot == 0:
	# 	_flash("ARMED HOSTILES — GRAB THE GLOCK!", Color("EF5350"))
	# 	if game_audio and game_audio.has_method("play_gunshot"):
	# 		game_audio.play_gunshot()
	# _spawn_terrorist_unit(
	# 	lane,
	# 	pose["pos"],
	# 	float(pose["target_x"]),
	# 	float(pose["target_z"]),
	# 	role,
	# 	role == "gun",
	# 	role == "gun"
	# )


func _spawn_terrorist_unit(
	lane: int,
	spawn_pos: Vector3,
	hold_x: float,
	hold_z: float,
	role: String,
	guns_out: bool,
	combat_ready: bool = false
) -> void:
	if not TERRORISTS_ENABLED:
		return
	# var c = TerroristCustomerScript.new()
	# if role == "bomber":
	# 	c.setup_bomber(lane)
	# else:
	# 	c.setup_terrorist(lane)
	# c.position = spawn_pos
	# c.target_x = hold_x
	# c.target_z = hold_z
	# c.rotation_degrees = Vector3(
	# 	0.0,
	# 	CustomerScript.FACE_TRUCK_YAW if combat_ready else CustomerScript.WALK_PLUS_X_YAW,
	# 	0.0
	# )
	# if role == "bomber" and c.has_signal("detonated"):
	# 	c.detonated.connect(func(damage: float, at: Vector3) -> void:
	# 		_on_terrorist_detonated(c, damage, at)
	# 	)
	# elif c.has_signal("shot_player"):
	# 	c.shot_player.connect(_on_terrorist_shot_player)
	# customers_root.add_child(c)
	# customers.append(c)
	# if guns_out and c.has_method("present_weapon"):
	# 	c.call_deferred("present_weapon", combat_ready)


func _spawn_terror_explosion(at: Vector3) -> void:
	if world == null:
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.55, 0.18)
	flash.light_energy = 14.0
	flash.omni_range = 4.2
	flash.shadow_enabled = false
	flash.position = at
	world.add_child(flash)
	var burst := GPUParticles3D.new()
	burst.amount = 48
	burst.lifetime = 0.55
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	burst.position = at
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 6.5
	pmat.gravity = Vector3(0, -9.0, 0)
	pmat.scale_min = 0.08
	pmat.scale_max = 0.22
	pmat.color = Color(1.0, 0.45, 0.12, 0.95)
	burst.process_material = pmat
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	burst.draw_pass_1 = sphere
	world.add_child(burst)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
		if is_instance_valid(burst):
			burst.queue_free()
	)


func _on_terrorist_detonated(terr: Node, damage: float, at: Vector3) -> void:
	if not playing:
		return
	customers.erase(terr)
	_spawn_terror_explosion(at)
	_spend(damage, "BOMBER! -%s" % _format_money(damage), Color("FF7043"))
	_flash("SUICIDE BOMBER!", Color("FF5722"))
	if game_audio and game_audio.has_method("play_gunshot"):
		game_audio.play_gunshot()
	_check_terrorist_wave_end()


func _on_terrorist_shot_player(damage: float) -> void:
	if not playing:
		return
	## Every muzzle flash reports here (0 damage = miss) so gunshots always play.
	if game_audio and game_audio.has_method("play_gunshot"):
		game_audio.play_gunshot()
	if damage > 0.0:
		_spend(damage, "Under fire! -%s" % _format_money(damage), Color("EF5350"))


func _check_terrorist_wave_end() -> void:
	if not terrorist_wave_active:
		return
	for c in customers:
		if c != null and is_instance_valid(c) and bool(c.get("is_terrorist")) and not bool(c.get("is_ragdoll")):
			return
	terrorist_wave_active = false
	_flash("Threat cleared.", Color("A5D6A7"))
	_sync_combat_audio()


func _any_living_terrorist() -> bool:
	for c in customers:
		if c != null and is_instance_valid(c) and bool(c.get("is_terrorist")) and not bool(c.get("is_ragdoll")):
			return true
	return false


func _sync_combat_audio() -> void:
	## Double Agent theme + mute truck radio while fighting or holding the glock.
	var hostiles := terrorist_wave_active or _any_living_terrorist()
	var want_theme := hostiles or glock_held
	## Radio stays muted while the glock is out, or while the combat theme is up.
	var mute_radio := glock_held or want_theme
	if game_audio:
		if want_theme:
			if game_audio.has_method("play_combat_theme"):
				game_audio.play_combat_theme()
		elif game_audio.has_method("stop_combat_theme"):
			game_audio.stop_combat_theme()
	if radio and radio.has_method("set_combat_silence"):
		radio.set_combat_silence(mute_radio)


func _spawn_customer() -> void:
	var order: Array[String] = GameDataScript.generate_order(difficulty)
	var color: Color = GameDataScript.CUSTOMER_COLORS[randi() % GameDataScript.CUSTOMER_COLORS.size()]
	var patience := lerpf(62.0, 30.0, difficulty) + randf_range(-3, 5)
	if day == 1:
		## Still forgiving, but not endless.
		patience += 32.0
	elif day == 2:
		patience += 20.0
	elif day == 3:
		patience += 10.0
	var lane := clampi(_waiting_customer_count(), 0, CustomerScript.LANE_X.size() - 1)
	var skin_idx := randi() % CustomerScript.CHAR_SKINS.size()
	var face_style := randi() % 3
	if mp_enabled:
		if not NetManager.is_host() and not _mp_applying:
			return
		var nid := _mp_next_customer_net_id
		_mp_next_customer_net_id += 1
		var order_packed: Array = []
		for o in order:
			order_packed.append(str(o))
		if NetManager.is_host():
			mp_spawn_customer.rpc(
				nid, order_packed, color.r, color.g, color.b, patience, lane, skin_idx, face_style
			)
			return
	_spawn_customer_local(order, color, patience, lane, -1, skin_idx, face_style)


func _spawn_customer_local(
	order: Array,
	color: Color,
	patience: float,
	lane: int,
	net_id: int = -1,
	skin_idx: int = -1,
	face_style: int = -1
) -> void:
	var typed_order: Array[String] = []
	for o in order:
		typed_order.append(str(o))
	var c = CustomerScript.new()
	c.setup(typed_order, color, patience, lane, skin_idx, face_style)
	## Guest customers are puppets — host owns patience expiry + leave.
	if mp_enabled and not NetManager.is_host():
		c.mp_host_driven = true
	## Stand on the sidewalk — raised so more torso shows in the window.
	c.position = Vector3(-6.5, CustomerScript.STAND_Y, 2.25)
	c.target_x = CustomerScript.lane_x_for(lane)
	## Face along the sidewalk (+X) while walking in; they turn to the truck on arrival.
	c.rotation_degrees = Vector3(0, CustomerScript.WALK_PLUS_X_YAW, 0)
	c.scale = Vector3(1.0, 1.0, 1.0)
	c.arrived.connect(_on_customer_arrived)
	c.patience_expired.connect(_on_customer_left.bind(true))
	c.served.connect(func(cust, _pay): _on_customer_left(cust, false))
	if net_id >= 0:
		c.set_meta("mp_net_id", net_id)
		_mp_customer_net_ids[c.get_instance_id()] = net_id
	customers_root.add_child(c)
	customers.append(c)


func _on_customer_arrived(customer: Node3D) -> void:
	if customer != null and bool(customer.get("is_terrorist")):
		return
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
			_spend(float(refund), "Refunded %s — they left without the food" % _format_money(float(refund)), Color("EF5350"))
			combo = 0
			if st_i >= 0:
				_clear_station(st_i)
			if cust != null and is_instance_valid(cust) and cust.has_method("leave_after_dispute"):
				cust.leave_after_dispute()
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
	## Co-op: host alone authors leave so tickets / line stay identical.
	if mp_enabled and not _mp_applying:
		if not NetManager.is_host():
			return
		var nid := _customer_net_id(customer)
		if nid < 0:
			_customer_leave_apply(customer, angry)
			_mp_broadcast_economy()
			return
		mp_customer_leave.rpc(nid, angry)
		return
	_customer_leave_apply(customer, angry)
	if mp_enabled and NetManager.is_host() and not _mp_applying:
		_mp_broadcast_economy()


func _customer_net_id(customer: Node3D) -> int:
	if customer == null or not is_instance_valid(customer):
		return -1
	if customer.has_meta("mp_net_id"):
		return int(customer.get_meta("mp_net_id"))
	return int(_mp_customer_net_ids.get(customer.get_instance_id(), -1))


func _customer_leave_apply(customer: Node3D, angry: bool) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	## Idempotent — ignore if already removed from the line.
	if not customers.has(customer) and not tickets.has(customer):
		return
	_close_dialogue_if_customer(customer)
	_remove_ticket(customer)
	customers.erase(customer)
	if selected_customer == customer:
		selected_customer = null
		for c in customers:
			if c != null and is_instance_valid(c) and bool(c.get("is_waiting")):
				selected_customer = c
				break
	_highlight_tickets()
	_reposition_customers()
	if bool(customer.get("is_terrorist")):
		_check_terrorist_wave_end()
		return
	if angry:
		combo = 0
		## Extinguisher victims always roast you on the feed.
		if bool(customer.get("_powder_hit")):
			_force_record_social_review(1.0, "spray")
		else:
			_maybe_record_social_review(1.0, "angry")
		_spend(2.0, "Customer left angry! -$2.00", Color("EF5350"))


func _reposition_customers() -> void:
	for i in customers.size():
		var c = customers[i]
		if c == null or not is_instance_valid(c):
			continue
		## Hostiles manage their own patrol waypoints — don't yank them into customer lanes.
		if bool(c.get("is_terrorist")):
			c.global_position.y = CustomerScript.STAND_Y
			continue
		c.lane = i
		c.target_x = CustomerScript.lane_x_for(i)
		c.global_position.y = CustomerScript.STAND_Y


func _create_ticket(customer: Node3D) -> void:
	## Torn guest-check slip pinned on the window — handwriting + paper feel.
	var note := PanelContainer.new()
	note.custom_minimum_size = Vector2(168, 0)
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	## Slight crooked pin so slips don't look like UI cards.
	var rot_seed := _customer_net_id(customer)
	if rot_seed < 0:
		rot_seed = customer.get_instance_id()
	note.rotation_degrees = float((rot_seed * 37) % 100) / 100.0 * 10.0 - 5.0
	note.pivot_offset = Vector2(84, 10)
	note.set_meta("paper_rot", note.rotation_degrees)
	## Outer shell: drop shadow + border (StyleBoxTexture can't cast shadows).
	note.add_theme_stylebox_override("panel", _make_ticket_shell_style(false))
	## Serve-speed clock starts when this slip is pinned — not when meat is scoop-ready.
	if customer.has_method("start_order_clock"):
		customer.start_order_clock()
	note.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_ticket(customer)
			note.accept_event()
	)

	var paper := PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", _make_ticket_paper_style(false))
	note.add_child(paper)
	note.set_meta("paper_panel", paper)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	paper.add_child(v)

	## Pushpin head — round metal pin, not a UI square.
	var pin_wrap := CenterContainer.new()
	pin_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin_wrap.custom_minimum_size = Vector2(0, 12)
	v.add_child(pin_wrap)
	var pin := Panel.new()
	pin.custom_minimum_size = Vector2(13, 13)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pin_sb := StyleBoxFlat.new()
	## Light cork/wood pushpin — readable on the darker slip.
	pin_sb.bg_color = Color(0.78, 0.58, 0.36)
	pin_sb.set_corner_radius_all(7)
	pin_sb.border_color = Color(0.52, 0.34, 0.18)
	pin_sb.set_border_width_all(1)
	pin_sb.shadow_color = Color(0, 0, 0, 0.45)
	pin_sb.shadow_size = 3
	pin_sb.shadow_offset = Vector2(1, 2)
	pin.add_theme_stylebox_override("panel", pin_sb)
	pin_wrap.add_child(pin)

	var title := Label.new()
	## Order code = strip hotkeys for requested toppings (ketchup → 7, everything → 12345678).
	var order_code := GameDataScript.order_number_code(customer.order)
	title.text = order_code if order_code != "" else "—"
	var title_size := 30
	if order_code.length() >= 7:
		title_size = 22
	elif order_code.length() >= 5:
		title_size = 26
	UiFontsScript.apply_ticket(title, title_size)
	title.add_theme_color_override("font_color", Color(0.22, 0.14, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	## Faint rule under the order number — like a real guest check.
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.55, 0.42, 0.32, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)

	var lines_box := VBoxContainer.new()
	lines_box.name = "TicketLines"
	lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_box.add_theme_constant_override("separation", 1)
	v.add_child(lines_box)
	note.set_meta("lines_box", lines_box)
	note.set_meta("order_customer", customer)

	for spec in _ticket_line_specs(customer.order):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		row.set_meta("line_id", str(spec.get("id", "")))
		lines_box.add_child(row)

		var mark := Label.new()
		mark.name = "Check"
		mark.text = "○"
		mark.custom_minimum_size = Vector2(18, 0)
		UiFontsScript.apply_ticket(mark, 18)
		mark.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35, 0.55))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)

		var lab := Label.new()
		lab.name = "Item"
		lab.text = str(spec.get("label", ""))
		UiFontsScript.apply_ticket(lab, 21)
		lab.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lab)

	ticket_box.add_child(note)
	tickets[customer] = note
	_highlight_tickets()
	_refresh_ticket_checkmarks()


func _ticket_line_specs(order: Array) -> Array:
	## One slip line per checkable ask (toppings expand even on EVERYTHING).
	var lines: Array = []
	var patty_count := 0
	for item in order:
		if item == "patty":
			patty_count += 1
	if patty_count >= 2:
		lines.append({"id": "double_patty", "label": "DOUBLE PATTY"})
	if GameDataScript.is_plain_patty_order(order):
		lines.append({"id": "plain", "label": "PLAIN"})
	else:
		for item in order:
			if item == "bun_bottom" or item == "bun_top" or item == "patty":
				continue
			var label_txt: String = str(GameDataScript.INGREDIENT_LABELS.get(item, item)).to_upper()
			lines.append({"id": str(item), "label": label_txt})
	if lines.is_empty():
		lines.append({"id": "burger", "label": "BURGER"})
	return lines


func _ticket_line_is_done(line_id: String, built: Array) -> bool:
	match line_id:
		"double_patty":
			var n := 0
			for x in built:
				if str(x) == "patty":
					n += 1
			return n >= 2
		"plain", "burger":
			return built.has("patty")
		_:
			return built.has(line_id)


func _refresh_ticket_checkmarks() -> void:
	## Tick off slip lines as matching ingredients land on Build.
	var built: Array = []
	if STATION_CRAFT >= 0 and STATION_CRAFT < stations.size():
		_sync_station_cheese_items(STATION_CRAFT)
		built = stations[STATION_CRAFT]["items"]
	for cust in tickets:
		var note = tickets[cust]
		if not is_instance_valid(note) or not note.has_meta("lines_box"):
			continue
		var lines_box = note.get_meta("lines_box")
		if not is_instance_valid(lines_box):
			continue
		for row in lines_box.get_children():
			if not (row is Control) or not row.has_meta("line_id"):
				continue
			var line_id := str(row.get_meta("line_id"))
			var done := _ticket_line_is_done(line_id, built)
			var mark = row.get_node_or_null("Check")
			var lab = row.get_node_or_null("Item")
			if mark is Label:
				mark.text = "✓" if done else "○"
				mark.add_theme_color_override(
					"font_color",
					Color(0.18, 0.52, 0.28) if done else Color(0.55, 0.45, 0.35, 0.55)
				)
			if lab is Label:
				lab.add_theme_color_override(
					"font_color",
					Color(0.14, 0.38, 0.22) if done else Color(0.18, 0.12, 0.08)
				)


func _make_ticket_shell_style(selected: bool) -> StyleBoxFlat:
	## Transparent plate — only shadow, border, and torn-slip corners.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.72, 0.48, 0.18, 0.85) if selected else Color(0.62, 0.52, 0.38, 0.5)
	style.set_border_width_all(2 if selected else 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(0.08, 0.05, 0.02, 0.42)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 4)
	return style


func _make_ticket_paper_style(selected: bool) -> StyleBoxTexture:
	## Darker aged receipt paper with soft vignette (edges browner than center).
	var style := StyleBoxTexture.new()
	style.texture = _ticket_paper_texture(selected)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	if selected:
		style.modulate_color = Color(1.06, 1.0, 0.9)
	return style


func _ticket_paper_texture(selected: bool) -> ImageTexture:
	## Cache two paper plates so we don't rebuild per ticket.
	if selected:
		if _ticket_paper_tex_sel != null:
			return _ticket_paper_tex_sel
	elif _ticket_paper_tex != null:
		return _ticket_paper_tex
	var w := 128
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	## A step darker than the old flat cream.
	var base := Color(0.90, 0.84, 0.68) if selected else Color(0.86, 0.80, 0.64)
	var edge := Color(0.58, 0.48, 0.34) if selected else Color(0.52, 0.43, 0.30)
	## Invalidate any prior cache if we rebuild (fresh process on export).
	for y in h:
		for x in w:
			var nx := (float(x) / float(w - 1) - 0.5) * 2.0
			var ny := (float(y) / float(h - 1) - 0.5) * 2.0
			## Elliptical vignette — stronger at corners, gentle mid edges.
			var d := sqrt(nx * nx * 0.85 + ny * ny * 1.05)
			var vig := clampf((d - 0.25) / 1.15, 0.0, 1.0)
			vig = pow(vig, 1.25)
			var c := base.lerp(edge, vig * 0.55)
			c.a = 1.0
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	if selected:
		_ticket_paper_tex_sel = tex
	else:
		_ticket_paper_tex = tex
	return tex


func _select_ticket(customer: Node3D) -> void:
	if not is_instance_valid(customer) or not customer.is_waiting:
		_flash("That customer is gone", Color("EF5350"))
		return
	if mp_enabled and not _mp_applying:
		var nid := _customer_net_id(customer)
		if nid >= 0:
			mp_select_customer.rpc(nid)
			return
	_select_ticket_local(customer)


func _select_ticket_local(customer: Node3D) -> void:
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
		var selected: bool = cust == selected_customer
		note.add_theme_stylebox_override("panel", _make_ticket_shell_style(selected))
		if note.has_meta("paper_panel"):
			var paper = note.get_meta("paper_panel")
			if is_instance_valid(paper):
				paper.add_theme_stylebox_override("panel", _make_ticket_paper_style(selected))
		if note.has_meta("paper_rot"):
			note.rotation_degrees = float(note.get_meta("paper_rot"))
		## Selected slip sits a hair more upright / forward.
		note.modulate = Color(1.05, 1.02, 0.95) if selected else Color.WHITE


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
	terrorist_wave_active = false
	_opening_terr_active = false
	_opening_terr_timer = 0.0
	_opening_terr_spawned = 0
	_sync_combat_audio()


# --- Spatula + assembly stations -------------------------------------------

func _build_ingredient_legend() -> void:
	for child in ingredient_legend.get_children():
		child.queue_free()
	ingredient_buttons.clear()
	ingredient_legend.add_theme_constant_override("separation", 6)

	## Compact Order-Up bell on the right of the bottom ingredient strip.
	var serve_btn := Button.new()
	serve_btn.text = "🔔"
	serve_btn.tooltip_text = "Order up! — Serve"
	serve_btn.custom_minimum_size = Vector2(88, 84)
	serve_btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(serve_btn, true, 36)
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
	serve_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45))
	serve_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	serve_btn.add_theme_constant_override("outline_size", 4)
	serve_btn.pressed.connect(func():
		_sfx_click()
		_on_serve()
	)

	## Horizontal strip of toppings along the bottom (1 cheese → 8 mustard).
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
	ingredient_legend.add_child(serve_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var strip_bg := Color(0.18, 0.20, 0.24, 1.0)
	var strip_hover := Color(0.24, 0.27, 0.32, 1.0)
	var strip_press := Color(0.28, 0.32, 0.38, 1.0)

	for hi in range(INGREDIENT_HOTKEYS.size()):
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

		var icon_margin := MarginContainer.new()
		icon_margin.name = "IconMargin"
		icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_theme_constant_override("margin_left", int(GFX_DEFAULTS["strip_icon_x"]))
		icon_margin.add_theme_constant_override("margin_top", int(GFX_DEFAULTS["strip_icon_y"]))
		col.add_child(icon_margin)

		var icon := TextureRect.new()
		icon.name = "StripIcon"
		icon.texture = FoodSpritesScript.get_tex(id)
		icon.custom_minimum_size = Vector2(GFX_DEFAULTS["strip_icon_w"], GFX_DEFAULTS["strip_icon_h"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_margin.add_child(icon)

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
			## Skip if this LMB already painted toppings (swipe) or dropped one.
			if _strip_did_drag or _strip_gesture_added:
				_strip_did_drag = false
				_strip_gesture_added = false
				return
			_add_ingredient(capture)
		)
		tbtn.set_drag_forwarding(
			func(_pos):
				## If paint-swipe already applied this topping, don't also start a UI drag
				## that would drop a second copy on Build.
				if _strip_gesture_added or _strip_did_drag:
					return null
				if capture == "cheese":
					## Same ghost hold as a click — drop on a grill burger or Build.
					_begin_cheese_hold(true)
					_pending_cheese_drag = true
					_pending_ingredient_drag = ""
					_arm_grill_drop_zone()
				else:
					_pending_cheese_drag = false
					_pending_ingredient_drag = capture
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
	## Brief soft pulse on the strip — no loud yellow box.
	var flash := StyleBoxFlat.new()
	flash.bg_color = Color(0.28, 0.26, 0.22, 0.55)
	flash.set_corner_radius_all(12)
	flash.border_color = Color(1.0, 1.0, 1.0, 0.2)
	flash.set_border_width_all(1)
	flash.content_margin_left = 6
	flash.content_margin_right = 8
	flash.content_margin_top = 6
	flash.content_margin_bottom = 6
	var prev_normal = btn.get_theme_stylebox("normal")
	btn.add_theme_stylebox_override("normal", flash)
	get_tree().create_timer(0.14).timeout.connect(func():
		if is_instance_valid(btn) and prev_normal:
			btn.add_theme_stylebox_override("normal", prev_normal)
	)


func _pulse_ingredient_feedback(id: String) -> void:
	if ingredient_buttons.has(id):
		_shake_ingredient_button(ingredient_buttons[id])
	if game_audio:
		game_audio.play_ingredient(id)


func _ingredient_button_screen_center(id: String) -> Vector2:
	if ingredient_buttons.has(id):
		var btn: Control = ingredient_buttons[id]
		if btn != null and is_instance_valid(btn):
			var r := btn.get_global_rect()
			return r.position + r.size * 0.5
	var vr := get_viewport().get_visible_rect()
	return vr.position + Vector2(vr.size.x * 0.5, vr.size.y - 52.0)


func _station_ingredient_land_screen(station_index: int) -> Vector2:
	## Land on the current top of the Build stack (not the plate center).
	var st: Dictionary = stations[station_index]
	var preview: Control = st.get("preview", null)
	if preview != null and is_instance_valid(preview):
		var kids := preview.get_children()
		if not kids.is_empty():
			var top_y := INF
			var sum_x := 0.0
			var n := 0
			for c in kids:
				if c is Control and is_instance_valid(c):
					var r: Rect2 = (c as Control).get_global_rect()
					if r.size.x < 2.0 or r.size.y < 2.0:
						continue
					top_y = minf(top_y, r.position.y)
					sum_x += r.position.x + r.size.x * 0.5
					n += 1
			if n > 0 and top_y < INF:
				return Vector2(sum_x / float(n), top_y + 6.0)
		var pr := preview.get_global_rect()
		return pr.position + Vector2(pr.size.x * 0.5, pr.size.y * 0.32)
	var land := _station_stack_screen_center(station_index)
	var items: Array = st.get("items", [])
	land.y -= 28.0 + mini(float(items.size()) * 8.0, 48.0)
	return land


func _ingredient_fly_icon_size(station_index: int, id: String) -> Vector2:
	var items: Array = []
	if station_index >= 0 and station_index < STATION_COUNT:
		items = stations[station_index].get("items", [])
	var layer_w := 320.0 * 0.96 * _layer_width_mul(id) * _station_item_build_scale(id)
	var h := _layer_img_height(id) * _station_layer_scale(maxi(1, items.size() + 1)) \
		* _station_item_build_scale(id)
	return Vector2(mini(110.0, layer_w * 0.42), mini(84.0, h * 0.42))


func _play_ingredient_fly_to_build(id: String, station_index: int, on_done: Callable) -> void:
	var ui_root: Control = get_node_or_null("UI/Root") as Control
	if ui_root == null or station_index < 0 or station_index >= STATION_COUNT:
		on_done.call()
		return
	var tex := FoodSpritesScript.get_tex(id)
	if tex == null:
		on_done.call()
		return
	var fly_root := Control.new()
	fly_root.name = "IngredientFlyLayer"
	fly_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_root.z_index = 240
	ui_root.add_child(fly_root)
	var icon := TextureRect.new()
	icon.name = "FlyIcon"
	icon.texture = tex
	var icon_size := _ingredient_fly_icon_size(station_index, id)
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.pivot_offset = icon_size * 0.5
	fly_root.add_child(icon)
	var start := _ingredient_button_screen_center(id)
	## Capture land point at start; re-sample near the end so it tracks a growing stack.
	var end0 := _station_ingredient_land_screen(station_index)
	icon.global_position = start - icon_size * 0.5
	icon.scale = Vector2(1.15, 1.15)
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_ingredient_fly_busy = true
	var arc_h := 56.0
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(icon):
				return
			var eased := t * t * (3.0 - 2.0 * t)
			var end_now := end0
			if t > 0.55:
				end_now = end0.lerp(_station_ingredient_land_screen(station_index), (t - 0.55) / 0.45)
			var pos := start.lerp(end_now, eased)
			pos.y -= arc_h * 4.0 * t * (1.0 - t)
			icon.global_position = pos - icon_size * 0.5
			icon.scale = Vector2(1.15, 1.15).lerp(Vector2(0.78, 0.78), eased)
			icon.modulate.a = lerpf(1.0, 0.95, eased),
		0.0,
		1.0,
		0.42
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fly_root):
			fly_root.queue_free()
		_ingredient_fly_busy = false
		on_done.call()
	)
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
	_init_build_zone_cfg()
	_ensure_build_column_root()
	## Screen-left column (~15%) — over the cutting board, clear of ingredients.
	_layout_build_column_children()
	stations_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stations_row.z_index = 1
	stations_row.z_as_relative = true
	stations_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for child in stations_row.get_children():
		child.queue_free()
	for i in STATION_COUNT:
		## Plain Control — no PanelContainer chrome / bounding box.
		var panel := Control.new()
		panel.custom_minimum_size = Vector2(_bz("bz_panel_w"), _bz("bz_panel_h"))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_END
		## Empty panel area passes through to the 3D grill behind.
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var build_zone := Control.new()
		build_zone.name = "BuildZone"
		build_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		build_zone.grow_horizontal = Control.GROW_DIRECTION_BOTH
		build_zone.grow_vertical = Control.GROW_DIRECTION_BOTH
		build_zone.offset_left = int(_bz("bz_zone_left"))
		build_zone.offset_top = int(_bz("bz_zone_top"))
		build_zone.offset_right = 0
		build_zone.offset_bottom = -int(_bz("bz_lift_bottom"))
		build_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		build_zone.z_index = 2
		build_zone.z_as_relative = true
		panel.add_child(build_zone)

		var root_v := VBoxContainer.new()
		root_v.name = "BuildColumn"
		root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_v.add_theme_constant_override("separation", 2)
		root_v.alignment = BoxContainer.ALIGNMENT_END
		root_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_v.z_index = 1
		root_v.z_as_relative = true
		build_zone.add_child(root_v)

		## Stage fills the left Build column width — burger art uses the full plate.
		var plate_wrap := Control.new()
		var plate_w := _bz("bz_plate_w")
		if plate_w <= 1.0:
			plate_w = _bz("bz_panel_w")
		plate_wrap.custom_minimum_size = Vector2(plate_w, _bz("bz_plate_h"))
		plate_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
		plate_wrap.position = Vector2(_bz("bz_plate_shift"), _bz("bz_plate_y"))
		plate_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		plate_wrap.clip_contents = false
		root_v.add_child(plate_wrap)

		var title := Label.new()
		title.name = "BuildTitle"
		title.text = BUILD_TITLE_TEXT
		UiFontsScript.apply_label(title, true, 14)
		title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 4)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.set_anchors_preset(Control.PRESET_CENTER_TOP)
		title.offset_top = int(_bz("bz_title_y"))
		title.offset_left = int(_bz("bz_title_x"))
		title.z_index = 3
		title.z_as_relative = true
		plate_wrap.add_child(title)

		## Catches left-clicks over the grill behind the burger / yellow selection box.
		var grill_blocker := ColorRect.new()
		grill_blocker.name = "GrillPickBlocker"
		grill_blocker.color = Color(0, 0, 0, 0)
		grill_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grill_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		grill_blocker.z_index = -1
		plate_wrap.add_child(grill_blocker)

		## Absolute stack of floating ingredient sprites (cutting board art removed for now).
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

		## 🔔 · 🗑 · All — pinned to screen-left (Build column already has 15px pad).
		var actions := VBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_BEGIN
		actions.add_theme_constant_override("separation", 2)
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_v.add_child(actions)

		var btns := HBoxContainer.new()
		btns.alignment = BoxContainer.ALIGNMENT_BEGIN
		btns.add_theme_constant_override("separation", 8)
		btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(btns)

		var serve_one := Button.new()
		serve_one.text = "🔔"
		serve_one.tooltip_text = "Order up! — Serve"
		serve_one.custom_minimum_size = Vector2(40, 30)
		serve_one.focus_mode = Control.FOCUS_NONE
		serve_one.clip_text = true
		UiFontsScript.apply_button(serve_one, true, 16)
		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.14, 0.16, 0.18, 0.92)
		ssb.set_corner_radius_all(6)
		ssb.content_margin_left = 4
		ssb.content_margin_right = 4
		ssb.content_margin_top = 2
		ssb.content_margin_bottom = 2
		serve_one.add_theme_stylebox_override("normal", ssb)
		var ssbh := ssb.duplicate()
		ssbh.bg_color = Color(0.22, 0.24, 0.28, 0.95)
		serve_one.add_theme_stylebox_override("hover", ssbh)
		serve_one.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
		serve_one.pressed.connect(func():
			_sfx_click()
			_select_station(si)
			_on_serve()
		)
		btns.add_child(serve_one)

		var trash_one := Button.new()
		trash_one.text = "🗑"
		trash_one.tooltip_text = "Trash selected layer (or top)"
		trash_one.custom_minimum_size = Vector2(40, 30)
		trash_one.focus_mode = Control.FOCUS_NONE
		trash_one.clip_text = true
		UiFontsScript.apply_button(trash_one, true, 14)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.45, 0.18, 0.16)
		tsb.set_corner_radius_all(6)
		tsb.content_margin_left = 4
		tsb.content_margin_right = 4
		tsb.content_margin_top = 2
		tsb.content_margin_bottom = 2
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
		clear_one.custom_minimum_size = Vector2(40, 30)
		clear_one.focus_mode = Control.FOCUS_NONE
		UiFontsScript.apply_button(clear_one, false, 11)
		clear_one.pressed.connect(func():
			_sfx_click()
			_select_station(si)
			_request_clear_station(si)
		)
		btns.add_child(clear_one)

		var fresh_label := Label.new()
		fresh_label.text = "--"
		fresh_label.custom_minimum_size = Vector2(128, 18)
		UiFontsScript.apply_label(fresh_label, true, 11)
		fresh_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
		fresh_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fresh_label.add_theme_constant_override("outline_size", 3)
		fresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		fresh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fresh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actions.add_child(fresh_label)

		plate_wrap.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT:
					if _try_grill_right_click(ev.global_position):
						plate_wrap.accept_event()
					return
				if ev.button_index == MOUSE_BUTTON_LEFT:
					if cheese_held and _cheese_prefers_grill_at(ev.global_position):
						_try_place_held_cheese(ev.global_position)
						plate_wrap.accept_event()
						return
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
				if cheese_held:
					if _cheese_prefers_grill_at(ev.global_position):
						_try_place_held_cheese(ev.global_position)
						panel.accept_event()
						return
					_on_station_plate_clicked(si)
					panel.accept_event()
				elif spatula_patty != null:
					_on_station_plate_clicked(si)
					panel.accept_event()
				else:
					_select_station(si)
		)

		stations_row.add_child(panel)
		stations[i]["panel"] = panel
		stations[i]["preview"] = burger_stack
		stations[i]["board"] = null
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
	call_deferred("_refresh_build_debug_outlines")


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


func _build_build_drop_zone() -> void:
	## Fills the left Build column — click here while holding a scooped patty.
	var col := _ensure_build_column_root()
	if col == null:
		return
	if build_drop_zone != null and is_instance_valid(build_drop_zone):
		_layout_build_column_children()
		return
	build_drop_zone = Control.new()
	build_drop_zone.name = "BuildDropZone"
	build_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_drop_zone.z_index = 0
	build_drop_zone.z_as_relative = true
	col.add_child(build_drop_zone)
	_layout_build_column_children()
	build_drop_zone.gui_input.connect(func(ev: InputEvent):
		if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		if spatula_patty == null:
			return
		_drop_spatula_on_station(STATION_CRAFT)
		build_drop_zone.accept_event()
	)


func _arm_build_drop_zone(armed: bool) -> void:
	if build_drop_zone == null or not is_instance_valid(build_drop_zone):
		return
	## Stay inside BUILD_COL — never stretch across the grill.
	_layout_build_column_children()
	build_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP if armed else Control.MOUSE_FILTER_IGNORE
	call_deferred("_refresh_build_debug_outlines")


func _build_grill_drop_zone() -> void:
	## Drop target over the 3D grill (skips the far-left Build chrome).
	var ui_root: Control = get_node_or_null("UI/Root")
	if ui_root == null:
		return
	grill_drop_zone = Control.new()
	grill_drop_zone.name = "GrillDropZone"
	grill_drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	## Leave Build column + bottom topping strip clickable.
	grill_drop_zone.offset_left = _bz("bz_grill_drop_left")
	grill_drop_zone.offset_top = _bz("bz_grill_drop_top")
	grill_drop_zone.offset_bottom = _bz("bz_grill_drop_bottom")
	grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grill_drop_zone.z_index = 12
	ui_root.add_child(grill_drop_zone)
	grill_drop_zone.gui_input.connect(_on_grill_drop_zone_gui_input)
	grill_drop_zone.set_drag_forwarding(
		Callable(),
		func(_pos, data): return _can_drop_on_grill_zone(data),
		func(_pos, data): _drop_on_grill_zone(data)
	)


func _on_grill_drop_zone_gui_input(ev: InputEvent) -> void:
	## GrillDropZone is STOP while cheese is armed — GUI gets the click before _unhandled_input.
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and cheese_held:
		_cancel_cheese_hold()
		grill_drop_zone.accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and cheese_held:
		if _try_window_cat_click(mb.global_position):
			grill_drop_zone.accept_event()
			return
		_try_place_held_cheese(mb.global_position)
		grill_drop_zone.accept_event()
		return


func _can_drop_on_grill_zone(data: Variant) -> bool:
	if _can_drop_station_patty_on_grill(data):
		return true
	return _can_drop_cheese_on_grill(data)


func _drop_on_grill_zone(data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "station_patty":
		_drop_station_patty_on_grill(data)
		return
	if _can_drop_cheese_on_grill(data):
		_drop_cheese_on_grill(data)


func _can_drop_cheese_on_grill(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if str(data.get("kind", "")) != "ingredient":
		return false
	if str(data.get("id", "")) != "cheese":
		return false
	## Don't steal drops meant for the Build plate — grill still accepts cheese on the steel.
	var mouse := get_viewport().get_mouse_position()
	if _cheese_targets_build_at(mouse):
		return false
	return true


func _drop_cheese_on_grill(data: Variant) -> void:
	_pending_cheese_drag = false
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not cheese_held:
		_begin_cheese_hold(true)
	var mouse := get_viewport().get_mouse_position()
	_try_place_held_cheese(mouse)
	## Near-miss: still snap onto the closest cheesable burger.
	if cheese_held:
		_try_snap_cheese_to_nearest(mouse)
	if cheese_held:
		_cancel_cheese_hold_silent()
		_flash("Drop cheese on a burger", Color("FFCC80"))


func _nearest_cheesable_grill_patty(screen_pos: Vector2 = Vector2.ZERO, max_world: float = -1.0):
	## Closest grill burger that can take cheese (screen + world).
	var max_d := CHEESE_SNAP_WORLD if max_world < 0.0 else max_world
	var plane := Vector3.ZERO
	if screen_pos != Vector2.ZERO:
		plane = _grill_plane_from_screen(screen_pos)
	var best = null
	var best_score := INF
	for p in grill:
		if not _can_put_cheese_on_grill_patty(p):
			continue
		var lift: Vector3 = p.global_position + Vector3(0, 0.03, 0)
		var world_d := 0.0
		if plane != Vector3.ZERO:
			world_d = Vector2(plane.x - p.position.x, plane.z - p.position.z).length()
		else:
			world_d = 0.0
		if world_d > max_d:
			continue
		var screen_d := 0.0
		if camera != null and screen_pos != Vector2.ZERO and not camera.is_position_behind(lift):
			screen_d = screen_pos.distance_to(camera.unproject_position(lift))
		var score := world_d * 80.0 + screen_d
		if score < best_score:
			best_score = score
			best = p
	## Single burger on the grill → always allow a generous snap.
	if best == null:
		var only = null
		var count := 0
		for p2 in grill:
			if _can_put_cheese_on_grill_patty(p2):
				only = p2
				count += 1
		if count == 1:
			return only
	return best


func _try_snap_cheese_to_nearest(screen_pos: Vector2) -> bool:
	if not cheese_held:
		return false
	var target = _nearest_cheesable_grill_patty(screen_pos, CHEESE_SNAP_WORLD)
	if target == null or not target.add_cheese():
		return false
	cheese_held = false
	_cheese_hover_patty = null
	_pending_cheese_drag = false
	if cheese_ghost and is_instance_valid(cheese_ghost):
		cheese_ghost.visible = false
	if not _spend_ingredient("cheese"):
		target.has_cheese = false
		return false
	if game_audio:
		game_audio.play_ingredient("cheese")
	_flash("Cheese on! Melts in 3s", Color("FFE082"))
	return true


func _on_gui_drag_ended(was_accepted: bool) -> void:
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mouse := get_viewport().get_mouse_position()
	## Bacon strip → waiting customer's mouth (+10% patience).
	if _try_feed_bacon_to_customer(mouse):
		_pending_reorder_drag = null
		return
	## Drag toppings / cheese / Build patties onto the peeking cat.
	if _try_drop_dragged_food_on_cat(mouse):
		_pending_reorder_drag = null
		return
	## Fallback: missed the GARBAGE Control but released over it.
	if not was_accepted and _is_over_garbage(mouse):
		if _pending_reorder_drag != null and typeof(_pending_reorder_drag) == TYPE_DICTIONARY:
			_drop_patty_on_garbage(_pending_reorder_drag)
			_pending_reorder_drag = null
			return
		if _pending_station_patty_drag != null and typeof(_pending_station_patty_drag) == TYPE_DICTIONARY:
			_drop_patty_on_garbage(_pending_station_patty_drag)
			_pending_station_patty_drag = null
			return
		if _pending_ingredient_drag != "" or _pending_cheese_drag or cheese_held:
			var id := _pending_ingredient_drag
			if id == "" and (_pending_cheese_drag or cheese_held):
				id = "cheese"
			_drop_patty_on_garbage({"kind": "ingredient", "id": id})
			return
	## Build topping: swipe right + release outside Build → remove layer.
	if not was_accepted and _pending_reorder_drag != null and typeof(_pending_reorder_drag) == TYPE_DICTIONARY:
		var reorder_data = _pending_reorder_drag
		if str(reorder_data.get("kind", "")) == "reorder":
			var swipe_right := mouse.x - _reorder_drag_origin.x >= BUILD_SWIPE_TRASH_RIGHT_PX
			if swipe_right and not _is_build_drop_at(mouse):
				_drop_patty_on_garbage(reorder_data)
				_pending_reorder_drag = null
				return
	## If the drop missed a Control target, still try to land on the grill under the cursor.
	if not was_accepted and _pending_station_patty_drag != null:
		var data = _pending_station_patty_drag
		_pending_station_patty_drag = null
		_pending_cheese_drag = false
		_pending_ingredient_drag = ""
		_pending_reorder_drag = null
		if typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "station_patty":
			## Don't yank it if they dropped back on Build.
			if _station_index_at(mouse) < 0:
				var hit := _grill_plane_from_screen(mouse)
				if hit != Vector3.ZERO and _is_near_grill_for_place(hit):
					_return_station_patty_to_grill(int(data.get("station", -1)), int(data.get("from", -1)), hit)
		return
	if not was_accepted and _pending_cheese_drag:
		_pending_cheese_drag = false
		_pending_ingredient_drag = ""
		_pending_reorder_drag = null
		var mouse2 := mouse
		var build_i := _build_plate_index_at(mouse2)
		if build_i >= 0 and _cheese_targets_build_at(mouse2):
			## Dropped on Build plate without a Control accept — add as topping.
			if cheese_held:
				_cancel_cheese_hold_silent()
			_add_ingredient_to_station(build_i, "cheese", true)
			return
		if cheese_held:
			_try_place_held_cheese(mouse2)
			if cheese_held:
				_try_snap_cheese_to_nearest(mouse2)
			if cheese_held:
				_cancel_cheese_hold_silent()
				_flash("Drop cheese on a burger", Color("FFCC80"))
		return
	if not was_accepted and _pending_ingredient_drag != "":
		if _pending_ingredient_drag == "bacon" and _try_feed_bacon_to_customer(mouse):
			_pending_reorder_drag = null
			return
		## Missed Build and cat — cancel the ghost drag.
		_pending_ingredient_drag = ""
		_pending_reorder_drag = null
		return
	_pending_station_patty_drag = null
	_pending_cheese_drag = false
	_pending_ingredient_drag = ""
	_pending_reorder_drag = null


func _try_drop_dragged_food_on_cat(screen_pos: Vector2) -> bool:
	if not playing or window_cat == null or not is_instance_valid(window_cat):
		return false
	if not window_cat.hit_test_feed(camera, screen_pos):
		return false
	## Build-stack patty drag → feed whole burger piece.
	if _pending_station_patty_drag != null and typeof(_pending_station_patty_drag) == TYPE_DICTIONARY:
		var data = _pending_station_patty_drag
		if str(data.get("kind", "")) == "station_patty":
			var st_i := int(data.get("station", -1))
			var from_i := int(data.get("from", -1))
			_pending_station_patty_drag = null
			_pending_cheese_drag = false
			_pending_ingredient_drag = ""
			var patty = _extract_station_patty(st_i, from_i)
			if patty != null and is_instance_valid(patty):
				patty.queue_free()
			window_cat.feed("patty")
			_on_window_cat_fed("patty")
			_flash("Cat stole the burger! ♥", Color("FF8A80"))
			return true
	## Cheese ghost drag.
	if _pending_cheese_drag or cheese_held:
		_pending_cheese_drag = false
		_pending_ingredient_drag = ""
		_feed_window_cat_ingredient("cheese")
		return true
	## Strip topping drag — cat only takes cheese / bacon (patties via scoop/drag).
	if _pending_ingredient_drag != "":
		var id := _pending_ingredient_drag
		if not _cat_accepts_food(id):
			_flash("Cat only wants cheese, bacon, or a patty", Color("FFCC80"))
			return false
		_pending_ingredient_drag = ""
		_pending_cheese_drag = false
		_feed_window_cat_ingredient(id)
		_strip_gesture_added = true
		_strip_did_drag = true
		return true
	return false


func _arm_grill_drop_zone() -> void:
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.offset_left = _bz("bz_grill_drop_left")
		grill_drop_zone.offset_top = _bz("bz_grill_drop_top")
		grill_drop_zone.offset_bottom = _bz("bz_grill_drop_bottom")
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
		grill_drop_zone.z_index = 12


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
	## Don't steal drops meant for station panels / Build board.
	if _station_index_at(mouse) >= 0:
		return false
	var hit := _grill_plane_from_screen(mouse)
	return hit != Vector3.ZERO and _is_near_grill_for_place(hit)


func _drop_station_patty_on_grill(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	_pending_station_patty_drag = null
	var station_index := int(data.get("station", -1))
	var from_index := int(data.get("from", -1))
	var mouse := get_viewport().get_mouse_position()
	var hit := _grill_plane_from_screen(mouse)
	if hit == Vector3.ZERO:
		_flash("Drop on the grill surface", Color("FFCC80"))
		return
	_return_station_patty_to_grill(station_index, from_index, hit)


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
	## Keep leftover buns on the board (toast / rebuild).
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	if items.is_empty():
		_reset_station_freshness(station_index)
	else:
		_start_station_freshness(station_index)
	_after_station_edit(station_index)
	return patty


func _extract_station_patty_by_net_id(station_index: int, net_id: int):
	if station_index < 0 or station_index >= STATION_COUNT or net_id < 0:
		return null
	var st: Dictionary = stations[station_index]
	var pidx := -1
	for i in range(st["patties"].size()):
		var p = st["patties"][i]
		if p != null and is_instance_valid(p) and int(p.get("net_id")) == net_id:
			pidx = i
			break
	if pidx < 0:
		return null
	var seen := 0
	var item_index := -1
	var items: Array = st["items"]
	for j in range(items.size()):
		if str(items[j]) == "patty":
			if seen == pidx:
				item_index = j
				break
			seen += 1
	if item_index < 0:
		return null
	return _extract_station_patty(station_index, item_index)


func _is_bun_toast(node) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("is_bun_toast") and bool(node.is_bun_toast())


func _seed_cutting_board_buns(station_index: int = STATION_CRAFT) -> void:
	## Empty Build board always starts with a toastable top + bottom bun.
	if not BUN_TOAST_ENABLED:
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	var patties: Array = st.get("patties", [])
	if not items.is_empty() or not patties.is_empty():
		return
	st["items"] = ["bun_bottom", "bun_top"]
	st["bun_toast"] = {}
	st["selected_layer"] = -1
	_refresh_station(station_index)
	_mp_broadcast_station(station_index)


func _station_bun_cook_time(station_index: int, bun_id: String) -> float:
	if station_index < 0 or station_index >= STATION_COUNT:
		return 0.0
	var toast: Dictionary = stations[station_index].get("bun_toast", {})
	return float(toast.get(bun_id, 0.0))


func _set_station_bun_cook_time(station_index: int, bun_id: String, cook: float) -> void:
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	var toast: Dictionary = st.get("bun_toast", {})
	if cook <= 0.001:
		toast.erase(bun_id)
	else:
		toast[bun_id] = cook
	st["bun_toast"] = toast


func _bun_layer_modulate(cook_time: float) -> Color:
	var raw := Color(1, 1, 1, 1)
	var toasted := Color(0.82, 0.62, 0.42, 1)
	var burnt := Color(0.35, 0.22, 0.16, 1)
	if cook_time <= BunToastScript.TOAST_READY:
		return raw.lerp(toasted, cook_time / BunToastScript.TOAST_READY)
	var t := clampf(
		(cook_time - BunToastScript.TOAST_READY) / maxf(0.001, BunToastScript.TOAST_BURNT - BunToastScript.TOAST_READY),
		0.0, 1.0
	)
	return toasted.lerp(burnt, t)


func _extract_station_bun(station_index: int, item_index: int) -> String:
	if station_index < 0 or station_index >= STATION_COUNT:
		return ""
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if item_index < 0 or item_index >= items.size():
		return ""
	var bun_id := str(items[item_index])
	if bun_id != "bun_bottom" and bun_id != "bun_top":
		return ""
	items.remove_at(item_index)
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	if items.is_empty():
		_reset_station_freshness(station_index)
	else:
		_start_station_freshness(station_index)
	_after_station_edit(station_index)
	return bun_id


func _make_held_bun(_kind: String = "bun_pair", cook_time: float = 0.0) -> Area3D:
	if not BUN_TOAST_ENABLED:
		return null
	var bun = BunToastScript.new()
	bun.setup("bun_pair", cook_time)
	bun.is_held = true
	bun.heating = false
	bun.base_y = GRILL_SURFACE_Y + PATTY_SIT_Y
	bun.visible = true
	if patties_root != null:
		patties_root.add_child(bun)
	bun.clicked.connect(_on_patty_clicked)
	return bun


func _pickup_station_bun_to_hand(station_index: int, item_index: int) -> void:
	## Click either bun half → lift the whole pair (top + bottom toast together).
	if not BUN_TOAST_ENABLED or not playing:
		return
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("EF5350"))
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if item_index < 0 or item_index >= items.size():
		return
	var bun_id := str(items[item_index])
	if bun_id != "bun_bottom" and bun_id != "bun_top":
		return
	## Shared toast progress — max of either half already on the board.
	var cook := maxf(
		_station_bun_cook_time(station_index, "bun_bottom"),
		_station_bun_cook_time(station_index, "bun_top")
	)
	## Pull every bun half off the stack (toast both at once on the grill).
	var removed_any := false
	for _pass in 4:
		var found := -1
		for i in range(items.size()):
			var id := str(items[i])
			if id == "bun_bottom" or id == "bun_top":
				found = i
				break
		if found < 0:
			break
		items.remove_at(found)
		removed_any = true
	if not removed_any:
		_flash("Couldn't grab that bun", Color("EF5350"))
		return
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	_set_station_bun_cook_time(station_index, "bun_bottom", 0.0)
	_set_station_bun_cook_time(station_index, "bun_top", 0.0)
	if items.is_empty():
		_reset_station_freshness(station_index)
	else:
		_start_station_freshness(station_index)
	_after_station_edit(station_index)
	var bun := _make_held_bun("bun_pair", cook)
	spatula_patty = bun
	spatula_from_build = true
	spatula_owner_id = 0
	spatula_lmb_held = true
	spatula_last_mouse = get_viewport().get_mouse_position()
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	_update_held_spatula_patty(0.016)
	if game_audio:
		game_audio.play_scoop()
	_flash("Buns ready — grill toast (2s perfect · 4.2s burns)", Color("FFCC80"))


func _pickup_bun_from_grill(bun: Area3D) -> void:
	if not BUN_TOAST_ENABLED or not playing or bun == null or not is_instance_valid(bun) or not _is_bun_toast(bun):
		return
	if spatula_patty != null and spatula_patty != bun:
		_reject_second_scoop("Already holding something")
		return
	if brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("EF5350"))
		return
	var idx: int = int(bun.slot_index)
	if idx >= 0 and idx < grill.size() and grill[idx] == bun:
		grill[idx] = null
	bun.is_held = true
	bun.heating = false
	bun.visible = true
	spatula_patty = bun
	spatula_from_build = false
	spatula_owner_id = 0
	spatula_lmb_held = false
	spatula_last_mouse = get_viewport().get_mouse_position()
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	_update_held_spatula_patty(0.016)
	if game_audio:
		game_audio.play_scoop()
	var note: String = bun.cook_rating_text() if bun.has_method("cook_rating_text") else "bun"
	var col: Color = Color("FFCC80")
	if bun.has_method("cook_rating"):
		col = bun.cook_rating().get("color", col)
	_flash("Scooped buns (%s) — grill, Build, or trash" % note, col)


func _commit_bun_to_build(bun: Area3D) -> void:
	if not playing or bun == null or not is_instance_valid(bun) or not _is_bun_toast(bun):
		return
	if not BUN_TOAST_ENABLED:
		## Feature parked — free any leftover toast node instead of rebuilding toast flow.
		if spatula_patty == bun:
			spatula_patty = null
			spatula_owner_id = 0
			spatula_from_build = false
			spatula_lmb_held = false
			_refresh_spatula_ui()
		bun.queue_free()
		return
	var cook := float(bun.cook_time)
	var st: Dictionary = stations[STATION_CRAFT]
	var items: Array = st["items"]
	if not items.has("bun_bottom"):
		items.append("bun_bottom")
	if not items.has("bun_top"):
		items.append("bun_top")
	st["items"] = _normalize_burger_stack(items)
	_set_station_bun_cook_time(STATION_CRAFT, "bun_bottom", cook)
	_set_station_bun_cook_time(STATION_CRAFT, "bun_top", cook)
	if spatula_patty == bun:
		spatula_patty = null
		spatula_owner_id = 0
		spatula_from_build = false
		spatula_lmb_held = false
		spatula_vel_screen = Vector2.ZERO
		spatula_carry_travel = 0.0
	bun.queue_free()
	_refresh_spatula_ui()
	_start_station_freshness(STATION_CRAFT)
	_refresh_station(STATION_CRAFT)
	_select_station(STATION_CRAFT)
	if game_audio:
		game_audio.play_ingredient("bun_top")
	var note := "raw"
	if cook >= BunToastScript.TOAST_BURNT:
		note = "burnt"
	elif absf(cook - BunToastScript.TOAST_READY) <= BunToastScript.TOAST_PERFECT_SLACK:
		note = "perfect toast"
	elif cook >= BunToastScript.TOAST_READY:
		note = "toasted"
	_flash("Buns on Build (%s)" % note, Color("A5D6A7"))
	_mp_broadcast_station(STATION_CRAFT)


func _pickup_station_patty_to_hand(station_index: int, item_index: int) -> void:
	## Click a Build patty → turn it back into a held 3D patty (same as scoop).
	if not playing:
		return
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("EF5350"))
		return
	var pidx := _patty_index_for_item_slot(station_index, item_index)
	if pidx < 0 or station_index < 0 or station_index >= STATION_COUNT:
		_flash("Couldn't grab that patty", Color("EF5350"))
		return
	var preview = stations[station_index]["patties"][pidx] if pidx < stations[station_index]["patties"].size() else null
	if preview == null or not is_instance_valid(preview):
		_flash("Couldn't grab that patty", Color("EF5350"))
		return
	## Solo patties keep net_id -1; only co-op needs a real id for the RPC.
	if mp_enabled:
		if int(preview.get("net_id")) < 0:
			_flash("Couldn't grab that patty", Color("EF5350"))
			return
		if not _mp_applying:
			mp_pickup_build_patty.rpc(int(preview.net_id), station_index)
			return
	var patty = _extract_station_patty(station_index, item_index)
	if patty == null:
		_flash("Couldn't grab that patty", Color("EF5350"))
		return
	patty.is_held = true
	patty.heating = false
	patty.visible = true
	patty.rotation_degrees = Vector3.ZERO
	if patty.get_parent() == null:
		patties_root.add_child(patty)
	spatula_patty = patty
	spatula_from_build = true
	spatula_lmb_held = true
	spatula_last_mouse = get_viewport().get_mouse_position()
	spatula_vel_screen = Vector2.ZERO
	spatula_carry_travel = 0.0
	_refresh_spatula_ui()
	_update_held_spatula_patty(0.016)
	if game_audio:
		game_audio.play_scoop()
	_flash("Drag to grill & release · flick right to throw · Build to put back", Color("90CAF9"))


func _return_station_patty_to_grill(station_index: int, item_index: int, world_pos: Vector3) -> bool:
	if not playing:
		return false
	if spatula_patty != null or brush_held or cheese_held or shaker_held or oil_held or ext_held or glock_held or dragging_patty != null:
		_flash("Hands full — put that down first", Color("EF5350"))
		return false
	var idx := _first_empty_slot()
	if idx < 0:
		_flash("Grill is full (%d patties)!" % GRILL_SLOTS, Color("EF5350"))
		return false
	if world_pos == Vector3.ZERO or not _is_near_grill_for_place(world_pos):
		_flash("Drop on the grill surface", Color("FFCC80"))
		return false
	var pidx := _patty_index_for_item_slot(station_index, item_index)
	if pidx < 0 or station_index < 0 or station_index >= STATION_COUNT:
		_flash("Couldn't grab that patty", Color("EF5350"))
		return false
	var preview = stations[station_index]["patties"][pidx] if pidx < stations[station_index]["patties"].size() else null
	if preview == null or not is_instance_valid(preview):
		_flash("Couldn't grab that patty", Color("EF5350"))
		return false
	if mp_enabled:
		if int(preview.get("net_id")) < 0:
			_flash("Couldn't grab that patty", Color("EF5350"))
			return false
		if not _mp_applying:
			mp_return_build_to_grill.rpc(int(preview.net_id), station_index, world_pos.x, world_pos.z)
			return true
	## HOLD strip is fine for cooked meat pulled off Build.
	if _is_in_warmer_zone(world_pos):
		var patty_w = _extract_station_patty(station_index, item_index)
		if patty_w == null:
			_flash("Couldn't grab that patty", Color("EF5350"))
			return false
		spatula_patty = patty_w
		_place_spatula_on_warmer(world_pos)
		if spatula_patty == null:
			return true
		## Warmer was crowded — snap onto cook steel instead.
		var fallback := _find_closest_patty_place(world_pos)
		var held = spatula_patty
		spatula_patty = null
		if fallback == Vector3.ZERO:
			_commit_patty_to_build(held)
			_flash("No open spot — back on Build", Color("FFA726"))
			return false
		idx = _first_empty_slot()
		if idx < 0:
			_commit_patty_to_build(held)
			_flash("Grill is full — back on Build", Color("EF5350"))
			return false
		_place_extracted_patty_on_grill(held, idx, fallback)
		return true
	var place_pos := _find_closest_patty_place(world_pos)
	if place_pos == Vector3.ZERO:
		_flash("No open spot — clear some space", Color("EF5350"))
		return false
	var patty = _extract_station_patty(station_index, item_index)
	if patty == null:
		_flash("Couldn't grab that patty", Color("EF5350"))
		return false
	_place_extracted_patty_on_grill(patty, idx, place_pos)
	return true


func _place_extracted_patty_on_grill(patty: Area3D, idx: int, pos: Vector3) -> void:
	## Same cooked patty / toasting bun returns to the grill — keep cook_time / flip / cheese.
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
	if patty.has_method("refresh_cook_visuals"):
		patty.refresh_cook_visuals()
	if game_audio:
		game_audio.play_click()
	if _is_bun_toast(patty):
		if not grill_on:
			_flash("Buns on grill — turn BURNER ON (2s perfect · 4.2s burns)", Color("FFA726"))
		elif patty.has_method("is_burnt") and patty.is_burnt():
			_flash("Burnt buns back on grill", Color("EF5350"))
		elif patty.has_method("is_perfect_toast") and patty.is_perfect_toast():
			_flash("Perfect toast — scoop when ready", Color("FFE082"))
		elif patty.has_method("is_ready") and patty.is_ready():
			_flash("Toasted buns on grill — scoop when you want", Color("FFCC80"))
		else:
			_flash("Toasting both buns — 2s perfect, burns at 4.2s", Color("FFE082"))
		return
	var cook_note: String = str(patty.cook_rating_text()) if patty.has_method("cook_rating_text") else "cooked"
	if patty.has_cheese:
		_flash("Back on grill (%s) — cheese melting" % cook_note, Color("FFE082"))
	else:
		_flash("Back on grill (%s) — same cook level" % cook_note, Color("A5D6A7"))


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
		_pending_cheese_drag = false
		_pending_ingredient_drag = ""
		if id == "cheese":
			_cancel_cheese_hold_silent()
		## Swipe may have already painted this topping — don't stack a second copy.
		var cur: Array = stations[station_index]["items"]
		if id != "patty" and cur.has(id):
			_strip_gesture_added = true
			_strip_did_drag = true
			return
		_add_ingredient_to_station(station_index, id)
		_strip_gesture_added = true
		_strip_did_drag = true
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
	if mp_enabled and not _mp_applying:
		mp_reorder_station.rpc(station_index, from_index, insert_at)
		return
	_reorder_station_item_local(station_index, from_index, insert_at)


func _reorder_station_item_local(station_index: int, from_index: int, insert_at: int) -> void:
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
	_after_station_edit(station_index)


func _strip_cheese_from_station_patty(station_index: int) -> void:
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	for j in range(st["patties"].size() - 1, -1, -1):
		var p = st["patties"][j]
		if p != null and is_instance_valid(p) and p.has_cheese:
			if p.has_method("remove_cheese"):
				p.remove_cheese()
			else:
				p.has_cheese = false
			break


func _after_station_edit(station_index: int) -> void:
	## Re-sync stack vs order after any add/remove/reorder — may auto-serve when fixed.
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	_sync_station_cheese_items(station_index)
	_refresh_station(station_index)
	_mp_broadcast_station(station_index)
	call_deferred("_try_auto_serve")


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
	if mp_enabled and spatula_owner_id != 0 and spatula_owner_id != NetManager.my_id():
		return
	if mp_enabled and not _mp_applying and int(spatula_patty.get("net_id")) >= 0:
		mp_drop_to_build.rpc(int(spatula_patty.net_id), index)
		return
	_drop_spatula_on_station_local(index)


func _drop_spatula_on_station_local(index: int) -> void:
	if not playing or spatula_patty == null:
		return
	if index < 0 or index >= STATION_COUNT:
		return
	if _is_bun_toast(spatula_patty):
		_commit_bun_to_build(spatula_patty)
		return
	var patty = spatula_patty
	_mp_release_scoop_if(patty)
	_commit_patty_to_build(patty)
	if index != STATION_CRAFT:
		## Only one craft station today — keep API for future multi-station.
		_select_station(index)


func _insert_patty_into_stack(items: Array) -> void:
	## Patties always sit above bottom bun(s), below toppings.
	items.append("patty")


func _normalize_burger_stack(items: Array) -> Array:
	## Canonical order: bottom bun(s) -> patty(s) -> toppings (fixed kitchen order) -> top bun(s).
	## Does not auto-inject a heel — board can hold toastable buns alone, or meat without a heel
	## while that bun is toasting on the grill. Heel still auto-adds when a patty first lands.
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
		_begin_cheese_hold(false, true)
		return
	var station := active_station
	_play_ingredient_fly_to_build(id, station, func():
		_add_ingredient_to_station(station, id, false)
	)


func _begin_cheese_hold(from_drag: bool = false, skip_sfx: bool = false) -> void:
	if not playing or brush_held or oil_held or shaker_held or ext_held or glock_held or spatula_patty != null:
		return
	if cheese_held:
		## Drag re-arms an existing hold; click toggles it off.
		if from_drag:
			if cheese_ghost and is_instance_valid(cheese_ghost):
				cheese_ghost.visible = true
			return
		_cancel_cheese_hold()
		return
	cheese_held = true
	_ensure_cheese_ghost()
	_arm_grill_drop_zone()
	if cheese_ghost:
		cheese_ghost.visible = true
	if not skip_sfx and game_audio:
		game_audio.play_ingredient("cheese")
	if from_drag:
		_flash("Drop cheese on grill, HOLD, or Build", Color("FFE082"))
	else:
		_flash("Cheese ready — grill / HOLD / Build · right-click cancels", Color("FFE082"))


func _cancel_cheese_hold() -> void:
	_pending_cheese_drag = false
	cheese_held = false
	_cheese_hover_patty = null
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cheese_ghost and is_instance_valid(cheese_ghost):
		cheese_ghost.visible = false
	_flash("Cheese back on the stack", Color("B0BEC5"))


func _cancel_cheese_hold_silent() -> void:
	_pending_cheese_drag = false
	cheese_held = false
	_cheese_hover_patty = null
	if grill_drop_zone != null and is_instance_valid(grill_drop_zone):
		grill_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cheese_ghost and is_instance_valid(cheese_ghost):
		cheese_ghost.visible = false


func _ensure_cheese_ghost() -> void:
	if cheese_ghost != null and is_instance_valid(cheese_ghost):
		return
	cheese_ghost = MeshInstance3D.new()
	cheese_ghost.name = "CheeseGhost"
	var mesh := BoxMesh.new()
	## Match real slice footprint (half≈0.084 → ~0.168 across).
	mesh.size = Vector3(0.15, 0.005, 0.15)
	cheese_ghost.mesh = mesh
	cheese_ghost_mat = StandardMaterial3D.new()
	cheese_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cheese_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheese_ghost_mat.albedo_color = Color(1.0, 0.82, 0.26, 0.42)
	cheese_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cheese_ghost.material_override = cheese_ghost_mat
	cheese_ghost.visible = false
	world.add_child(cheese_ghost)


func _update_cheese_ghost() -> void:
	if not cheese_held or cheese_ghost == null or not is_instance_valid(cheese_ghost):
		return
	var target = _cheese_grill_target_under_cursor()
	var pulse := 0.38 + 0.12 * absf(sin(Time.get_ticks_msec() * 0.008))
	if target != null and is_instance_valid(target) and _can_put_cheese_on_grill_patty(target):
		## Seat on the meat mesh (same spot as a real slice) — not floating high.
		_cheese_hover_patty = target
		cheese_ghost.global_position = target.get_cheese_seat_global()
		cheese_ghost.global_basis = target.get_cheese_seat_basis()
		cheese_ghost.scale = Vector3.ONE
		if cheese_ghost_mat:
			cheese_ghost_mat.albedo_color = Color(1.0, 0.82, 0.26, pulse + 0.12)
	else:
		_cheese_hover_patty = null
		## Float ghost over the grill plane under the cursor.
		var hit := _grill_plane_from_screen(get_viewport().get_mouse_position())
		if hit != Vector3.ZERO:
			hit.y = GRILL_SURFACE_Y + 0.045
			cheese_ghost.global_position = hit
		cheese_ghost.rotation = Vector3.ZERO
		cheese_ghost.scale = Vector3(0.92, 1.0, 0.92)
		if cheese_ghost_mat:
			## Dimmer when not over a valid patty.
			var blocked: bool = target != null and not _can_put_cheese_on_grill_patty(target)
			cheese_ghost_mat.albedo_color = Color(1.0, 0.55, 0.35, pulse * 0.7) if blocked \
				else Color(1.0, 0.82, 0.26, pulse * 0.75)


func _can_put_cheese_on_grill_patty(patty) -> bool:
	## Cheese melts on any flat-top burger (cook zones + HOLD) or via Build — not spatula/drag.
	if patty == null or not is_instance_valid(patty):
		return false
	if patty.is_held or patty == spatula_patty or patty == dragging_patty:
		return false
	if bool(patty.has_cheese):
		return false
	if not grill.has(patty):
		return false
	return true


func _pick_cheese_patty_at_screen(screen_pos: Vector2):
	## Extra-forgiving screen/world pick shared by ghost + drop.
	if camera == null:
		return null
	## Cheese onto grill — only block when pointer is on build plate, not overlapping steel.
	if _cheese_targets_build_at(screen_pos):
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
		var pick_px := maxf(CHEESE_PICK_MIN_PX, _patty_screen_pick_radius_px(lift, CHEESE_PICK_WORLD_EDGE, CHEESE_PICK_PAD_PX))
		## Sticky: once hovered, keep a wider grab until you leave it.
		if _cheese_hover_patty == p:
			pick_px = maxf(pick_px, CHEESE_STICKY_PX)
		var screen_d := screen_pos.distance_to(screen_pt)
		var in_screen := screen_d <= pick_px
		var near_plane := false
		if plane_hit != Vector3.ZERO:
			near_plane = Vector2(plane_hit.x - p.position.x, plane_hit.z - p.position.z).length() <= CHEESE_PICK_WORLD
		if not in_screen and not near_plane:
			continue
		candidates.append({
			"p": p,
			"screen_d": screen_d,
			"cam_d": cam_pos.distance_to(lift),
			"in_screen": in_screen,
		})
	if candidates.is_empty():
		return null
	var any_screen := false
	for c in candidates:
		if bool(c["in_screen"]):
			any_screen = true
			break
	if any_screen:
		candidates = candidates.filter(func(c): return bool(c["in_screen"]))
	candidates.sort_custom(func(a, b):
		var sa: float = float(a["screen_d"])
		var sb: float = float(b["screen_d"])
		if absf(sa - sb) > 2.5:
			return sa < sb
		return float(a["cam_d"]) < float(b["cam_d"])
	)
	return candidates[0]["p"]


func _cheese_grill_target_under_cursor():
	## Ghost + click use the same forgiving pick.
	var mouse := get_viewport().get_mouse_position()
	var target = _pick_cheese_patty_at_screen(mouse)
	if target != null:
		return target
	var plane := _grill_plane_from_screen(mouse)
	if plane != Vector3.ZERO:
		var near := _nearest_patty_to(plane, CHEESE_PICK_WORLD)
		if near >= 0 and _can_put_cheese_on_grill_patty(grill[near]):
			return grill[near]
		## Wider snap so the ghost sticks while dragging near burgers.
		var snap = _nearest_cheesable_grill_patty(mouse, CHEESE_SNAP_WORLD)
		if snap != null:
			return snap
	## Keep sticky hover so a tiny mouse jitter doesn't lose the burger.
	if _cheese_hover_patty != null and is_instance_valid(_cheese_hover_patty) \
			and _can_put_cheese_on_grill_patty(_cheese_hover_patty):
		if camera != null:
			var lift2: Vector3 = _cheese_hover_patty.global_position + Vector3(0, 0.03, 0)
			if not camera.is_position_behind(lift2):
				var d := mouse.distance_to(camera.unproject_position(lift2))
				if d <= CHEESE_STICKY_PX:
					return _cheese_hover_patty
		else:
			return _cheese_hover_patty
	return null


func _try_place_held_cheese(screen_pos: Vector2) -> void:
	if not cheese_held:
		return
	if window_cat != null and is_instance_valid(window_cat) and window_cat.hit_test_feed(camera, screen_pos):
		_feed_window_cat_ingredient("cheese")
		return
	## Build plate click → melt cheese onto the Build stack patty.
	if _cheese_targets_build_at(screen_pos):
		var station_idx := _build_plate_index_at(screen_pos)
		if station_idx >= 0:
			_cancel_cheese_hold()
			_add_ingredient_to_station(station_idx, "cheese", true)
			return
	## Same pick as the ghost — plus sticky hover / wide snap if click lands off.
	var target = _pick_cheese_patty_at_screen(screen_pos)
	if target == null:
		var plane := _grill_plane_from_screen(screen_pos)
		if plane != Vector3.ZERO:
			var near := _nearest_patty_to(plane, CHEESE_SNAP_WORLD)
			if near >= 0:
				target = grill[near]
	if target == null and _cheese_hover_patty != null and is_instance_valid(_cheese_hover_patty):
		target = _cheese_hover_patty
	if target == null:
		target = _nearest_cheesable_grill_patty(screen_pos, CHEESE_SNAP_WORLD)
	if target == null:
		_flash("Drop cheese on a grill / HOLD burger or Build", Color("FFCC80"))
		return
	if target.is_held or target == spatula_patty:
		_flash("Put the burger on the grill, HOLD, or Build first", Color("FFCC80"))
		return
	if not grill.has(target):
		_flash("Drop cheese on a grill / HOLD burger or Build", Color("FFCC80"))
		return
	if target.has_cheese:
		_flash("That patty already has cheese", Color("FFCC80"))
		return
	if mp_enabled and not _mp_applying and int(target.get("net_id")) >= 0:
		cheese_held = false
		_cheese_hover_patty = null
		_pending_cheese_drag = false
		if cheese_ghost and is_instance_valid(cheese_ghost):
			cheese_ghost.visible = false
		mp_cheese_patty.rpc(int(target.net_id))
		return
	if target.add_cheese():
		cheese_held = false
		_cheese_hover_patty = null
		_pending_cheese_drag = false
		if cheese_ghost and is_instance_valid(cheese_ghost):
			cheese_ghost.visible = false
		if not _spend_ingredient("cheese"):
			target.has_cheese = false
			return
		if game_audio:
			game_audio.play_ingredient("cheese")
		_flash("Cheese on! Melts in 3s", Color("FFE082"))


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
	if mp_enabled and not _mp_applying:
		if not _mp_can_spend_ingredient(id):
			return
		mp_add_ingredient.rpc(station_index, id)
		return
	_add_ingredient_to_station_local(station_index, id, play_sfx)


func _add_ingredient_to_station_local(station_index: int, id: String, play_sfx: bool = true) -> void:
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
	## One of each topping / bun — stops swipe+click / swipe+drop double-adds.
	## (Patties stay stackable for doubles.)
	if id != "patty" and items.has(id):
		return
	if id == "cheese":
		_start_station_cheese_melt(station_index, play_sfx)
		return
	if not _mp_spend_ingredient(id):
		return
	items.append(id)
	st["items"] = _normalize_burger_stack(items)
	_start_station_freshness(station_index)
	_refresh_station(station_index)
	if play_sfx and game_audio:
		game_audio.play_ingredient(id)
	_note_melody_press(id)
	_mp_broadcast_station(station_index)
	call_deferred("_try_auto_serve")


func _start_station_cheese_melt(station_index: int, play_sfx: bool = true) -> void:
	## Cheese melts onto the top patty over 3 seconds on Build (same as grill).
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
			var left := maxi(1, int(ceil(3.0 * (1.0 - float(patty.cheese_melt)))))
			_flash("Cheese still melting — %ds left" % left, Color("FFE082"))
		return
	if not patty.add_cheese():
		_flash("Can't add cheese right now", Color("EF5350"))
		return
	## Count cheese in the stack immediately so Serve / matching aren't blocked by melt time.
	var items: Array = st["items"]
	items.append("cheese")
	st["items"] = _normalize_burger_stack(items)
	if not _mp_spend_ingredient("cheese"):
		items.erase("cheese")
		patty.has_cheese = false
		st["items"] = _normalize_burger_stack(items)
		return
	_start_station_freshness(station_index)
	_refresh_station(station_index)
	if play_sfx and game_audio:
		game_audio.play_ingredient("cheese")
	_note_melody_press("cheese")
	_flash("Cheese on — melting 3s (order already counts it)", Color("FFE082"))
	_mp_broadcast_station(station_index)


func _update_station_cheese_melt(_delta: float) -> void:
	## Keep cheese item count in sync with cheesed patties; flash when melt finishes.
	var did_melt := false
	for i in STATION_COUNT:
		var st: Dictionary = stations[i]
		var cheesed := 0
		var melted := 0
		for p2 in st["patties"]:
			if p2 == null or not is_instance_valid(p2) or not p2.has_cheese:
				continue
			cheesed += 1
			if p2.cheese_ready():
				melted += 1
		if cheesed <= 0:
			continue
		var items: Array = st["items"]
		var cheese_count := 0
		for item in items:
			if str(item) == "cheese":
				cheese_count += 1
		var added := 0
		while cheese_count + added < cheesed:
			items.append("cheese")
			added += 1
		if added > 0:
			st["items"] = _normalize_burger_stack(items)
			_refresh_station(i)
		## Flash once when every cheesed patty on this board has finished melting.
		if melted >= cheesed and melted > 0:
			## Use a light flag on the station dict so we don't spam.
			if not bool(st.get("cheese_melt_flashed", false)):
				st["cheese_melt_flashed"] = true
				_flash("Cheese melted!", Color("FFE082"))
				did_melt = true
		else:
			st["cheese_melt_flashed"] = false
	if did_melt:
		call_deferred("_try_auto_serve")


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
	if mp_enabled and not _mp_applying:
		mp_trash_build_layer.rpc(index, remove_i)
		return
	_trash_build_layer_local(index, remove_i)


func _trash_build_layer_local(index: int, remove_i: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	var st: Dictionary = stations[index]
	var items: Array = st["items"]
	if items.is_empty():
		_flash("%s is empty" % _station_label(index), Color("B0BEC5"))
		return
	if remove_i < 0 or remove_i >= items.size():
		remove_i = items.size() - 1
	var removed: String = str(items[remove_i])
	## Buns (and other layers) can always be trashed — including heel under meat.
	items.remove_at(remove_i)
	if removed == "bun_bottom" or removed == "bun_top":
		_set_station_bun_cook_time(index, removed, 0.0)
	st["items"] = _normalize_burger_stack(items)
	st["selected_layer"] = -1
	_sync_patties_with_items(index)
	if removed == "cheese":
		_strip_cheese_from_station_patty(index)
	if items.is_empty():
		_reset_station_freshness(index)
	_after_station_edit(index)
	var label: String = GameDataScript.INGREDIENT_LABELS.get(removed, removed.capitalize())
	if game_audio:
		game_audio.play_trash()
	if removed == "patty":
		_spend(COST_DROP_BURGER, "Trashed burger — %s" % _format_money(COST_DROP_BURGER), Color("FFAB91"))
	else:
		_flash("Trashed %s" % label, Color("FFAB91"))


func _trash_top_layer(index: int) -> void:
	## Kept for compatibility — prefer selected layer when present.
	if index < 0 or index >= STATION_COUNT:
		return
	stations[index]["selected_layer"] = -1
	_trash_selected_or_top_layer(index)


func _request_clear_station(index: int) -> void:
	if index < 0 or index >= STATION_COUNT:
		return
	if mp_enabled and not _mp_applying:
		mp_clear_station.rpc(index)
		return
	_clear_station(index)
	_flash("%s cleared" % _station_label(index), Color("B0BEC5"))


func _clear_station(index: int) -> void:
	var st: Dictionary = stations[index]
	for p in st["patties"]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	st["patties"] = []
	st["items"] = [] as Array[String]
	st["bun_toast"] = {}
	st["selected_layer"] = -1
	_reset_station_freshness(index)
	_refresh_station(index)
	_mp_broadcast_station(index)
	## Empty board gets a fresh toastable bun pair.
	if playing:
		_seed_cutting_board_buns(index)


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
		_refresh_ticket_checkmarks()
		return

	## Fake-3D float stack: board is z0; bun/patty/toppings rise above it.
	var layer_scale := _station_layer_scale(items.size())
	var stage_w := 320.0
	var stage_h := 240.0
	if plate != null and plate.size.x > 8.0:
		stage_w = plate.size.x
		stage_h = plate.size.y
	## Bottom bun sits lower on the plate so the stack meets the cutting board.
	var bun_h0 := _layer_img_height("bun_bottom") * layer_scale
	var origin_x := stage_w * 0.52 ## slight right bias for left margin
	var origin_y := stage_h * 0.66 + bun_h0 * 0.18
	## Stack step — room between layers without floating the meat.
	var step_y := 18.0 * layer_scale
	var layer_w := mini(360.0, stage_w * 0.94)
	## Small gap above heel so patty sits on the bottom bun (not glued to the crown).
	var stack_lift := 0.0
	var bottom_row: Control = null
	var top_row: Control = null

	for stack_i in items.size():
		var item: String = items[stack_i]
		if item == "cheese":
			continue ## Shown on the patty via burger_cheese art.
		var layer_key := item
		var pidx := -1
		if item == "patty":
			var patty_from_bottom := 0
			for j in range(stack_i + 1):
				if items[j] == "patty":
					patty_from_bottom += 1
			pidx = patty_from_bottom - 1
			if _station_patty_has_cheese(st, pidx):
				layer_key = "patty_cheese"
		var h_base := _layer_img_height(layer_key) * layer_scale
		var build_scale := _station_item_build_scale(layer_key)
		h_base *= build_scale
		var this_w := layer_w * _layer_width_mul(layer_key) * build_scale
		var layer_tex: Texture2D = null
		if item == "patty":
			layer_tex = _station_patty_layer_tex(st, pidx, layer_key == "patty_cheese")
		else:
			layer_tex = FoodSpritesScript.get_tex(item)
		var fit := _fit_layer_box_size(layer_tex, this_w, h_base)
		this_w = fit.x
		var h := fit.y
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.z_as_relative = true
		row.z_index = stack_i + 1 ## board is 0; bottom bun is 1
		var row_style := StyleBoxFlat.new()
		row_style.set_content_margin_all(0)
		row_style.set_corner_radius_all(4)
		if stack_i == selected_layer:
			## Soft select — no loud yellow box.
			row_style.bg_color = Color(1.0, 1.0, 1.0, 0.10)
			row_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
			row_style.set_border_width_all(1)
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
			## Modest lift so meat rests on the heel with a little air.
			stack_lift += 4.0 * layer_scale
			bottom_row = row
		elif item == "patty":
			## Keep crown from sitting on the meat.
			stack_lift += 6.0 * layer_scale
		elif item == "bun_top":
			top_row = row

		var tr := TextureRect.new()
		tr.texture = layer_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(this_w, h)
		tr.size = Vector2(this_w, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Soft drop shadow under each float layer.
		var bun_cook := 0.0
		if item == "bun_bottom" or item == "bun_top":
			bun_cook = _station_bun_cook_time(index, item)
		tr.modulate = _bun_layer_modulate(bun_cook) if bun_cook > 0.001 else Color(1, 1, 1, 1)
		row.add_child(tr)

		var from_i := stack_i
		var item_id := item
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if item_id == "patty":
					## Click → held 3D patty so you can place it back on the grill.
					_pickup_station_patty_to_hand(index, from_i)
				elif BUN_TOAST_ENABLED and (item_id == "bun_bottom" or item_id == "bun_top"):
					_pickup_station_bun_to_hand(index, from_i)
				else:
					_select_station_layer(index, from_i)
				row.accept_event()
		)
		row.set_drag_forwarding(
			func(_pos):
				if item_id == "patty" or (BUN_TOAST_ENABLED and (item_id == "bun_bottom" or item_id == "bun_top")):
					## Patties / toastable buns use click-to-hand; toppings stay Control-drag.
					return null
				var color_preview := ColorRect.new()
				color_preview.custom_minimum_size = Vector2(100, 16)
				color_preview.color = GameDataScript.INGREDIENT_COLORS.get(item_id, Color.GRAY)
				row.set_drag_preview(color_preview)
				_pending_station_patty_drag = null
				_reorder_drag_origin = get_viewport().get_mouse_position()
				var drag_data := _make_reorder_drag(index, from_i, item_id)
				_pending_reorder_drag = drag_data
				return drag_data,
			func(_pos, data): return _can_drop_on_assembly(index, data),
			func(pos, data):
				_pending_station_patty_drag = null
				_pending_reorder_drag = null
				_drop_on_assembly(index, pos, data)
		)
		preview.add_child(row)
	## Nest: heel tucks slightly; crown lifts clear of the patty.
	if bottom_row != null and is_instance_valid(bottom_row):
		bottom_row.position.y -= BUILD_BUN_NEST_BOTTOM_PX * layer_scale
	if top_row != null and is_instance_valid(top_row):
		top_row.position.y += BUILD_BUN_NEST_TOP_PX * layer_scale
	_refresh_ticket_checkmarks()


func _station_patty_has_cheese(st: Dictionary, pidx: int) -> bool:
	var patties: Array = st.get("patties", [])
	if pidx >= 0 and pidx < patties.size():
		var p = patties[pidx]
		if p != null and is_instance_valid(p) and bool(p.get("has_cheese")):
			return true
	var cheese_n := 0
	for item in st.get("items", []):
		if str(item) == "cheese":
			cheese_n += 1
	return pidx < cheese_n


func _station_patty_layer_tex(st: Dictionary, pidx: int, with_cheese: bool) -> Texture2D:
	## Build-board meat (and melt art) follow grill cook / burn.
	var pcolor: Color = GameDataScript.INGREDIENT_COLORS.get("patty", Color(0.45, 0.24, 0.14))
	var char_amt := 0.0
	var patties: Array = st.get("patties", [])
	if pidx >= 0 and pidx < patties.size() and is_instance_valid(patties[pidx]):
		var p = patties[pidx]
		if p.has_method("get_patty_color"):
			pcolor = p.get_patty_color()
		if p.has_method("build_char_amount"):
			char_amt = float(p.build_char_amount())
	if with_cheese:
		return FoodSpritesScript.burger_cheese_tex(pcolor, char_amt)
	return FoodSpritesScript.patty_tex(pcolor, char_amt)


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


func _station_item_build_scale(item: String) -> float:
	## Buns define the plate footprint; toppings scale relative to STATION_INGREDIENT_SCALE.
	if item == "bun_top":
		return 1.05
	if item == "bun_bottom":
		return 0.92
	if item == "patty_cheese":
		return STATION_PATTY_CHEESE_BUILD_SCALE
	if item == "patty":
		return STATION_PATTY_BUILD_SCALE
	if item == "onion":
		return STATION_INGREDIENT_SCALE * 0.595 ## −30%
	if item == "tomato":
		return STATION_INGREDIENT_SCALE * 0.98
	if item == "pickle":
		return STATION_INGREDIENT_SCALE * 0.56 ## −30%
	if item == "bacon":
		return STATION_INGREDIENT_SCALE * 0.88
	if item == "lettuce":
		return STATION_INGREDIENT_SCALE * 0.92
	if item == "cheese":
		return STATION_INGREDIENT_SCALE * 0.9
	if item == "ketchup":
		return STATION_INGREDIENT_SCALE * 1.12
	if item == "mustard":
		return STATION_INGREDIENT_SCALE * 0.9 ## −10%
	return STATION_INGREDIENT_SCALE


func _layer_width_mul(item: String) -> float:
	## Buns define the plate footprint — keep them wide enough to read.
	match item:
		"bun_top":
			return 0.88
		"bun_bottom":
			return 0.98
		"patty":
			return 1.20
		"patty_cheese":
			return 1.22
		"cheese", "lettuce", "bacon", "tomato", "onion", "pickle":
			return 1.18
		"ketchup", "mustard":
			return 1.05
		_:
			return 1.15


func _layer_img_height(item: String) -> float:
	match item:
		"bun_top":
			return 38.0
		"bun_bottom":
			return 44.0
		"patty":
			return 72.0
		"patty_cheese":
			return 74.0
		"bacon":
			return 58.0
		"lettuce":
			return 60.0
		"tomato", "onion", "pickle", "cheese":
			return 58.0
		"ketchup", "mustard":
			return 40.0
		_:
			return 56.0


func _fit_layer_box_size(tex: Texture2D, target_w: float, min_h: float) -> Vector2:
	## Size box from opaque art bounds so padded sheets (cheese patty) don't shrink.
	if tex == null:
		return Vector2(target_w, min_h)
	var aspect := FoodSpritesScript.texture_content_aspect(tex)
	var aspect_h := target_w * aspect
	return Vector2(target_w, maxf(min_h, aspect_h))


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
	## Arm whole Build column + tall left catcher while holding a scooped patty.
	_arm_build_drop_zone(spatula_patty != null)
	if stations_row != null and is_instance_valid(stations_row):
		stations_row.mouse_filter = Control.MOUSE_FILTER_STOP if spatula_patty != null \
			else Control.MOUSE_FILTER_IGNORE
	for i in STATION_COUNT:
		var panel: Control = stations[i].get("panel", null) if i < stations.size() else null
		if panel != null and is_instance_valid(panel):
			panel.mouse_filter = Control.MOUSE_FILTER_STOP if spatula_patty != null \
				else Control.MOUSE_FILTER_IGNORE
		_refresh_station(i)

func _try_auto_serve() -> void:
	## Hand off as soon as a station matches a waiting ticket perfectly.
	if not playing or _auto_serving or _serve_fly_busy:
		return
	## Co-op: only host auto-serves so we don't double-fire RPCs.
	if mp_enabled and not NetManager.is_host():
		return
	var waiting: Array = []
	if selected_customer != null and is_instance_valid(selected_customer) and selected_customer.is_waiting:
		waiting.append(selected_customer)
	for c in customers:
		if c == null or not is_instance_valid(c) or not c.is_waiting:
			continue
		if c == selected_customer:
			continue
		waiting.append(c)
	for cust in waiting:
		var si := _find_perfect_station_for(cust.order)
		if si < 0:
			continue
		if _station_has_melting_cheese(si):
			continue
		_auto_serving = true
		selected_customer = cust
		active_station = si
		_highlight_tickets()
		_highlight_active_station()
		_on_serve()
		if not _serve_fly_busy:
			_auto_serving = false
		return


func _maybe_auto_top_bun() -> void:
	## Legacy hook — top bun is auto-crowned at serve time with a left-board drop anim.
	pass


func _station_only_needs_top_bun(items: Array, order: Array) -> bool:
	## True when adding bun_top would make a perfect ticket match.
	if items.has("bun_top") or not order.has("bun_top"):
		return false
	var trial: Array = items.duplicate()
	trial.append("bun_top")
	trial = _normalize_burger_stack(trial)
	return bool(GameDataScript.compare_orders(trial, order).get("perfect", false))


func _find_perfect_station_for(order: Array) -> int:
	var best := -1
	var best_q := -1.0
	for i in STATION_COUNT:
		_sync_station_cheese_items(i)
		var items: Array = stations[i]["items"]
		if items.is_empty() or not items.has("patty"):
			continue
		var result: Dictionary = GameDataScript.compare_orders(items, order)
		var ready := bool(result.get("perfect", false)) or _station_only_needs_top_bun(items, order)
		if not ready:
			continue
		## Prefer the active station when several match.
		var q := 2.0 if i == active_station else 1.0
		if q > best_q:
			best_q = q
			best = i
	return best


func _station_has_melting_cheese(station_index: int) -> bool:
	if station_index < 0 or station_index >= STATION_COUNT:
		return false
	for p in stations[station_index]["patties"]:
		if p != null and is_instance_valid(p) and p.has_cheese and not p.cheese_ready():
			return true
	return false


func _sync_station_cheese_items(station_index: int) -> void:
	## Order matching counts cheese as soon as it's on a patty (melt is visual only).
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	var st: Dictionary = stations[station_index]
	var cheesed := 0
	for p in st["patties"]:
		if p != null and is_instance_valid(p) and p.has_cheese:
			cheesed += 1
	var items: Array = st["items"]
	var cheese_count := 0
	for item in items:
		if str(item) == "cheese":
			cheese_count += 1
	if cheese_count >= cheesed:
		return
	for _i in range(cheesed - cheese_count):
		items.append("cheese")
	st["items"] = _normalize_burger_stack(items)
	_refresh_station(station_index)


func _missing_items_label(missing: Array) -> String:
	var labels: Array[String] = []
	var seen := {}
	for id in missing:
		var key := str(id)
		if seen.has(key):
			continue
		seen[key] = true
		labels.append(str(GameDataScript.INGREDIENT_LABELS.get(key, key)))
	if labels.is_empty():
		return "items"
	return ", ".join(labels)


func _crown_serve_burger(station_index: int) -> bool:
	## Crown the build stack before the serve fly — returns true if bun_top was added.
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	if items.has("bun_top") or not items.has("patty"):
		return false
	if not _mp_spend_ingredient("bun_top"):
		return false
	items.append("bun_top")
	st["items"] = _normalize_burger_stack(items)
	_mp_broadcast_station(station_index)
	return true


func _find_station_top_bun_row(station_index: int) -> Control:
	var st: Dictionary = stations[station_index]
	var preview: Control = st.get("preview", null)
	var items: Array = st["items"]
	if preview == null or not is_instance_valid(preview) or not items.has("bun_top"):
		return null
	var kids := preview.get_children()
	if kids.is_empty():
		return null
	return kids[kids.size() - 1] as Control


func _animate_top_bun_on_station(station_index: int, on_done: Callable) -> void:
	## Drop the crown onto the left Build board before squash / fly.
	var row := _find_station_top_bun_row(station_index)
	if row == null or not is_instance_valid(row):
		on_done.call()
		return
	_serve_fly_busy = true
	var final_y: float = row.position.y
	row.position.y = final_y - 46.0
	if game_audio:
		game_audio.play_ingredient("bun_top")
	var tw := create_tween()
	tw.tween_property(row, "position:y", final_y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.04)
	tw.tween_callback(on_done)


func _station_stack_screen_center(index: int) -> Vector2:
	var st: Dictionary = stations[index]
	var preview: Control = st.get("preview", null)
	if preview != null and is_instance_valid(preview):
		var r := preview.get_global_rect()
		return r.position + r.size * 0.5
	var plate: Control = st.get("plate", null)
	if plate != null and is_instance_valid(plate):
		var pr := plate.get_global_rect()
		return pr.position + Vector2(pr.size.x * 0.5, pr.size.y * 0.38)
	return get_viewport().get_visible_rect().size * Vector2(0.18, 0.72)


func _customer_mouth_screen(customer: Node3D) -> Vector2:
	if camera == null or customer == null:
		return Vector2.ZERO
	var mouth: Vector3 = customer.global_position + Vector3(0.0, 1.18, 0.06)
	if customer.has_method("mouth_global"):
		mouth = customer.mouth_global()
	var screen_pt := camera.unproject_position(mouth)
	return screen_pt + Vector2(0.0, -42.0)


func _find_waiting_customer_at_mouth(screen_pos: Vector2) -> Node3D:
	if customers_root == null or camera == null:
		return null
	var best: Node3D = null
	var best_d := BACON_MOUTH_PICK_PX
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if not bool(c.get("is_waiting")):
			continue
		if bool(c.get("is_leaving")) or bool(c.get("is_ragdoll")):
			continue
		var mouth: Vector3 = c.global_position + Vector3(0.0, 1.18, 0.06)
		if c.has_method("mouth_global"):
			mouth = c.mouth_global()
		if camera.is_position_behind(mouth):
			continue
		var mouth_pt := camera.unproject_position(mouth)
		var d := screen_pos.distance_to(mouth_pt)
		if d < best_d:
			best_d = d
			best = c
	return best


func _try_feed_bacon_to_customer(screen_pos: Vector2) -> bool:
	if not playing or _pending_ingredient_drag != "bacon":
		return false
	var cust := _find_waiting_customer_at_mouth(screen_pos)
	if cust == null:
		return false
	if not cust.has_method("feed_bacon_snack"):
		return false
	if mp_enabled and not _mp_applying:
		var nid := _customer_net_id(cust)
		if nid < 0:
			return false
		if not _mp_can_spend_ingredient("bacon"):
			return true
		## Peek: only RPC if they can still take a snack.
		if cust.patience >= cust.patience_max - 0.05:
			_pending_ingredient_drag = ""
			_pending_cheese_drag = false
			_strip_did_drag = true
			_flash("They're not hungry for more bacon", Color("FFCC80"))
			return true
		mp_bacon_customer.rpc(nid)
		_pending_ingredient_drag = ""
		_pending_cheese_drag = false
		_strip_did_drag = true
		_strip_gesture_added = true
		return true
	if not bool(cust.feed_bacon_snack(BACON_PATIENCE_RESTORE)):
		_pending_ingredient_drag = ""
		_pending_cheese_drag = false
		_strip_did_drag = true
		_flash("They're not hungry for more bacon", Color("FFCC80"))
		return true
	if not _spend_ingredient("bacon"):
		return true
	_pending_ingredient_drag = ""
	_pending_cheese_drag = false
	_strip_did_drag = true
	_strip_gesture_added = true
	if game_audio:
		game_audio.play_ingredient("bacon")
	var pct := int(round(BACON_PATIENCE_RESTORE * 100.0))
	_flash("Bacon snack! +%d%% patience" % pct, Color("FFAB91"))
	return true


func _build_serve_fly_stack(parent: Control, station_index: int) -> Dictionary:
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	var plate: Control = st.get("plate", null)
	## Compact toss burger — smaller than Build art so it fits the mouth.
	var layer_scale := _station_layer_scale(items.size()) * 0.62
	var stage_w := 220.0
	var stage_h := 180.0
	if plate != null and plate.size.x > 8.0:
		stage_w = mini(240.0, plate.size.x * 0.72)
		stage_h = mini(200.0, plate.size.y * 0.72)
	var bun_h0 := _layer_img_height("bun_bottom") * layer_scale
	var origin_x := stage_w * 0.5
	var origin_y := stage_h * 0.55 + bun_h0 * 0.18
	## Pressed stack — tight layers so the handoff reads as one smash.
	var step_y := 5.4 * layer_scale
	var layer_w := mini(200.0, stage_w * 0.9)
	var stack_lift := 0.0

	var stack := Control.new()
	stack.name = "ServeFlyStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stack)

	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var top_row: Control = null
	var bottom_row: Control = null
	var bun_rows: Array[Control] = []
	var patty_rows: Array[Control] = []
	var topping_rows: Array[Control] = []
	## Condiment / thin toppings get pressed flat on the way to the mouth.
	const FLY_SQUASH_IDS: Array[String] = ["mustard", "ketchup", "bacon", "pickle", "onion", "lettuce", "tomato"]
	const FLY_TOPPING_SQUISH := 0.28
	## Patties were oversized vs buns in the toss — keep meat tucked in the stack.
	const FLY_PATTY_W := 0.48
	const FLY_PATTY_H := 0.40

	for stack_i in items.size():
		var item: String = items[stack_i]
		if item == "cheese":
			continue ## Shown on the patty via burger_cheese art.
		var layer_key := item
		var pidx := -1
		if item == "patty":
			var patty_from_bottom := 0
			for j in range(stack_i + 1):
				if items[j] == "patty":
					patty_from_bottom += 1
			pidx = patty_from_bottom - 1
			if _station_patty_has_cheese(st, pidx):
				layer_key = "patty_cheese"
		var is_bun := item == "bun_bottom" or item == "bun_top"
		var is_patty := item == "patty"
		var squash_flat := FLY_SQUASH_IDS.has(item)
		## Don't vertically squash buns; flatten sauces / thin toppings after fit.
		var h_squish := 1.0 if (is_bun or squash_flat) else 0.9
		var build_scale := _station_item_build_scale(layer_key)
		if is_patty:
			build_scale *= FLY_PATTY_H
		var h_base := _layer_img_height(layer_key) * layer_scale * h_squish * build_scale
		var this_w := layer_w * _layer_width_mul(layer_key) * build_scale
		if is_patty:
			this_w *= FLY_PATTY_W / maxf(FLY_PATTY_H, 0.01)
		var layer_tex: Texture2D = null
		if item == "patty":
			layer_tex = _station_patty_layer_tex(st, pidx, layer_key == "patty_cheese")
		else:
			layer_tex = FoodSpritesScript.get_tex(item)
		var fit := _fit_layer_box_size(layer_tex, this_w, h_base)
		this_w = fit.x
		var h := fit.y
		## Force flat toppings into a shorter box (aspect fit alone won't squash).
		if squash_flat:
			h = maxf(6.0, h * FLY_TOPPING_SQUISH)
		var row := Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.custom_minimum_size = Vector2(this_w, h)
		row.size = Vector2(this_w, h)
		row.position = Vector2(
			origin_x - this_w * 0.5 - float(stack_i) * 0.8,
			origin_y - stack_lift - float(stack_i) * step_y - h * 0.72
		)
		if item == "bun_bottom":
			stack_lift += 5.5 * layer_scale
			bottom_row = row
			bun_rows.append(row)
		if item == "bun_top":
			row.position.y += 3.5 * layer_scale
			top_row = row
			bun_rows.append(row)
		if is_patty:
			stack_lift += 3.5 * layer_scale
			patty_rows.append(row)
		elif not is_bun:
			topping_rows.append(row)

		var tr := TextureRect.new()
		tr.texture = layer_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		## SCALE fills the squashed box; aspect-centered would ignore the short height.
		tr.stretch_mode = TextureRect.STRETCH_SCALE if squash_flat \
			else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(this_w, h)
		tr.size = Vector2(this_w, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
		stack.add_child(row)

		min_x = minf(min_x, row.position.x)
		max_x = maxf(max_x, row.position.x + this_w)
		min_y = minf(min_y, row.position.y)
		max_y = maxf(max_y, row.position.y + h)

	var pivot := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	return {
		"stack": stack,
		"top_row": top_row,
		"bottom_row": bottom_row,
		"pivot": pivot,
		"bun_rows": bun_rows,
		"patty_rows": patty_rows,
		"topping_rows": topping_rows,
	}


func _play_serve_fly_to_mouth(station_index: int, customer: Node3D, on_done: Callable) -> void:
	_serve_fly_busy = true
	var ui_root: Control = get_node_or_null("UI/Root") as Control
	if ui_root == null or camera == null:
		_serve_fly_busy = false
		on_done.call()
		return

	var st: Dictionary = stations[station_index]
	var preview: Control = st.get("preview", null)

	var fly_root := Control.new()
	fly_root.name = "ServeFlyLayer"
	fly_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_root.z_index = 250
	ui_root.add_child(fly_root)

	var built: Dictionary = _build_serve_fly_stack(fly_root, station_index)
	var stack: Control = built["stack"]
	var bun_rows: Array = built.get("bun_rows", [])
	var patty_rows: Array = built.get("patty_rows", [])
	var topping_rows: Array = built.get("topping_rows", [])
	var top_row: Control = built.get("top_row", null)
	var bottom_row: Control = built.get("bottom_row", null)
	stack.pivot_offset = built["pivot"]
	stack.scale = Vector2.ONE
	stack.rotation = 0.0
	stack.modulate = Color.WHITE

	var start_pos := _station_stack_screen_center(station_index)
	stack.global_position = start_pos
	var mouth_pos := _customer_mouth_screen(customer)

	if preview != null and is_instance_valid(preview):
		preview.modulate = Color(1.0, 1.0, 1.0, 0.0)

	## Customer hands up + open mouth while the toss is in flight.
	if customer != null and is_instance_valid(customer) and customer.has_method("begin_catch_burger"):
		customer.begin_catch_burger()

	var bun_pinch_px := 8.0
	var topping_crush_px := 6.0
	var bottom_base_y := bottom_row.position.y if bottom_row != null else 0.0
	var top_base_y := top_row.position.y if top_row != null else 0.0
	var topping_base_y: Array[float] = []
	for tr in topping_rows:
		topping_base_y.append((tr as Control).position.y if tr != null else 0.0)

	var apply_bun_pinch := func(amount: float) -> void:
		if bottom_row != null and is_instance_valid(bottom_row):
			bottom_row.position.y = bottom_base_y - amount
		if top_row != null and is_instance_valid(top_row):
			top_row.position.y = top_base_y + amount

	var apply_topping_crush := func(amount: float) -> void:
		var mid := (bottom_base_y + top_base_y) * 0.5 if top_row != null else bottom_base_y - 16.0
		for i in topping_rows.size():
			var row: Control = topping_rows[i]
			if row == null or not is_instance_valid(row):
				continue
			var base_y: float = topping_base_y[i] if i < topping_base_y.size() else row.position.y
			row.position.y = lerpf(base_y, mid, clampf(amount / maxf(topping_crush_px, 0.01), 0.0, 1.0))

	var apply_stack_scale := func(s: Vector2) -> void:
		if not is_instance_valid(stack):
			return
		## Uniform stack scale — patties stay nested (no counter-scale that pops meat out).
		stack.scale = s
		for row in bun_rows:
			if row != null and is_instance_valid(row):
				(row as Control).scale = Vector2.ONE
		for row in patty_rows:
			if row != null and is_instance_valid(row):
				(row as Control).scale = Vector2.ONE
		for row in topping_rows:
			if row != null and is_instance_valid(row):
				(row as Control).scale = Vector2.ONE

	var finish_serve := func() -> void:
		if customer != null and is_instance_valid(customer) and customer.has_method("finish_catch_burger"):
			customer.finish_catch_burger()
		if preview != null and is_instance_valid(preview):
			preview.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if is_instance_valid(fly_root):
			fly_root.queue_free()
		_serve_fly_busy = false
		if _auto_serving:
			_auto_serving = false
		on_done.call()

	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_interval(0.01)

	## A · Seal — quick press into one smash.
	var seal_step := func(t: float) -> void:
		apply_stack_scale.call(Vector2.ONE.lerp(Vector2(1.06, 0.86), t))
		apply_bun_pinch.call(lerpf(0.0, bun_pinch_px * 0.5, t))
		apply_topping_crush.call(lerpf(0.0, topping_crush_px * 0.45, t))
	tw.tween_method(seal_step, 0.0, 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	## B · Windup — dip back before the toss.
	var windup_step := func(t: float) -> void:
		if not is_instance_valid(stack):
			return
		var crouch := Vector2(1.08, 0.8).lerp(Vector2(0.88, 1.08), t)
		apply_stack_scale.call(crouch)
		stack.rotation = deg_to_rad(lerpf(0.0, -14.0, t))
		stack.global_position = start_pos + Vector2(lerpf(0.0, -8.0, t), lerpf(0.0, 12.0, t))
		apply_bun_pinch.call(bun_pinch_px * 0.6)
		apply_topping_crush.call(topping_crush_px * 0.55)
	tw.tween_method(windup_step, 0.0, 1.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tw.tween_callback(func() -> void:
		if game_audio and game_audio.has_method("play_serve_whoosh"):
			game_audio.play_serve_whoosh()
	)

	## C · Arc to the mouth — shrink in flight so it doesn't eat the face.
	var fly_step := func(t: float) -> void:
		if not is_instance_valid(stack):
			return
		var end_pos := mouth_pos
		if customer != null and is_instance_valid(customer):
			end_pos = _customer_mouth_screen(customer)
		var mid := start_pos.lerp(end_pos, 0.45) + Vector2(0.0, -96.0)
		var eased := t * t * (3.0 - 2.0 * t)
		var launch := 1.0 - pow(1.0 - t, 2.4)
		var path_t := lerpf(launch, eased, 0.5)
		var u := 1.0 - path_t
		stack.global_position = u * u * start_pos + 2.0 * u * path_t * mid + path_t * path_t * end_pos
		## Soft flip through the toss, settle near upright.
		stack.rotation = deg_to_rad(lerpf(-14.0, 8.0, sin(t * PI * 0.85)))
		## Midair shrink → arrive bite-sized at the lips.
		var mid_s := Vector2(0.38, 0.42)
		var near_s := Vector2(0.40, 0.36)
		var s: Vector2
		if t < 0.4:
			s = Vector2(0.86, 1.02).lerp(mid_s, t / 0.4)
		else:
			s = mid_s.lerp(near_s, (t - 0.4) / 0.6)
		apply_stack_scale.call(s)
		apply_bun_pinch.call(bun_pinch_px)
		apply_topping_crush.call(topping_crush_px)
	tw.tween_method(fly_step, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	## D · Impact — bite squash + crumbs + chomp.
	tw.tween_callback(func() -> void:
		if customer != null and is_instance_valid(customer):
			if customer.has_method("chomp_burger"):
				customer.chomp_burger()
		if game_audio and game_audio.has_method("play_burger_chomp"):
			game_audio.play_burger_chomp()
		_spawn_serve_crumb_burst(
			fly_root,
			_customer_mouth_screen(customer) if customer != null and is_instance_valid(customer) else mouth_pos
		)
	)

	var impact_step := func(t: float) -> void:
		if not is_instance_valid(stack):
			return
		var end_pos := mouth_pos
		if customer != null and is_instance_valid(customer):
			end_pos = _customer_mouth_screen(customer)
		## Nudge slightly into the face as they bite.
		stack.global_position = end_pos + Vector2(0.0, lerpf(0.0, 4.0, t))
		stack.rotation = deg_to_rad(lerpf(8.0, -4.0, t))
		## Stay compact at the lips — don't balloon width on bite.
		var s := Vector2(0.40, 0.36).lerp(Vector2(0.44, 0.24), t)
		apply_stack_scale.call(s)
		apply_bun_pinch.call(bun_pinch_px * (1.0 + t * 0.8))
		apply_topping_crush.call(topping_crush_px * (1.0 + t))
	tw.tween_method(impact_step, 0.0, 1.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	## E · Vanish into the mouth.
	var eat_step := func(t: float) -> void:
		if not is_instance_valid(stack):
			return
		var end_pos := mouth_pos
		if customer != null and is_instance_valid(customer):
			end_pos = _customer_mouth_screen(customer)
		stack.global_position = end_pos + Vector2(0.0, lerpf(4.0, 10.0, t))
		stack.rotation = deg_to_rad(lerpf(-4.0, 0.0, t))
		var s := Vector2(0.44, 0.24).lerp(Vector2(0.08, 0.04), ease(t, 2.2))
		apply_stack_scale.call(s)
		stack.modulate.a = 1.0 - ease(t, 1.6)
		apply_bun_pinch.call(bun_pinch_px * (1.6 + t))
		apply_topping_crush.call(topping_crush_px * (1.4 + t * 0.4))
	tw.tween_method(eat_step, 0.0, 1.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.tween_callback(finish_serve)


func _spawn_serve_crumb_burst(parent: Control, at: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var colors: Array[Color] = [
		Color("FFE0B2"), Color("A5D6A7"), Color("FFCC80"), Color("EF9A9A"), Color("FFF59D"),
	]
	for i in 10:
		var crumb := ColorRect.new()
		crumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crumb.color = colors[i % colors.size()]
		var sz := randf_range(3.0, 7.0)
		crumb.size = Vector2(sz, sz)
		crumb.pivot_offset = crumb.size * 0.5
		crumb.global_position = at - crumb.size * 0.5
		crumb.z_index = 260
		parent.add_child(crumb)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.15, -0.15)).normalized()
		var dist := randf_range(28.0, 72.0)
		var end_p := at + dir * dist - crumb.size * 0.5
		var life := randf_range(0.28, 0.48)
		var ctw := create_tween()
		ctw.set_parallel(true)
		ctw.tween_property(crumb, "global_position", end_p, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ctw.tween_property(crumb, "modulate:a", 0.0, life)
		ctw.tween_property(crumb, "rotation", randf_range(-2.5, 2.5), life)
		ctw.chain().tween_callback(crumb.queue_free)


func _complete_serve(station_index: int) -> void:
	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	var result: Dictionary = GameDataScript.compare_orders(items, selected_customer.order)

	var patty_mult := 1.0
	var patties: Array = st["patties"]
	if patties.size() > 0:
		var sum := 0.0
		var n := 0
		for p in patties:
			if p != null and is_instance_valid(p):
				sum += p.doneness_multiplier() if p.has_method("doneness_multiplier") else 1.0
				n += 1
		if n > 0:
			patty_mult = sum / float(n)
	var tip_factor: float = selected_customer.patience_ratio()
	var fresh_r := _station_freshness_ratio(station_index)
	var cook_r := _station_cook_rating(station_index, selected_customer)
	var seasoned := _station_burgers_seasoned(station_index)
	patty_mult *= float(cook_r.get("pay_mul", 1.0))
	## Perfect toasted buns (~2s) bump payout; burnt toast hurts it.
	patty_mult *= _station_bun_toast_mul(station_index)
	if fresh_r <= 0.15:
		patty_mult *= 0.45
		tip_factor *= 0.25
	elif fresh_r <= 0.4:
		patty_mult *= 0.75
		tip_factor *= 0.6
	if not seasoned:
		patty_mult *= 0.92
		## Don't erase a Burnt grade — charcoal still counts as charcoal.
		if not _cook_rating_is_burnt(cook_r):
			cook_r = {
				"score": 48,
				"grade": "C",
				"stars": 2,
				"label": "Meh",
				"detail": "No seasoning",
				"color": Color("B0BEC5"),
				"pay_mul": float(cook_r.get("pay_mul", 1.0)),
				"text": "Meh… OK",
			}
	var guest_mp := mp_enabled and not NetManager.is_host()
	var pay: Dictionary = selected_customer.receive_burger(
		items, patty_mult, combo, tip_factor, fresh_r, seasoned
	)
	var payout: int = int(pay.get("total", 0))
	var tip_amt: int = int(pay.get("tip", 0))
	var was_meh: bool = bool(pay.get("meh", false)) or not seasoned
	var cook_bit := "  %s" % cook_r["text"]
	if selected_customer.has_method("stop_order_clock"):
		selected_customer.stop_order_clock()

	## Host/solo owns money + combo; guests keep FX/flashes then take economy sync.
	if payout > 0:
		if not guest_mp:
			money += payout
			total_served += 1
		if game_audio:
			var grade_lab := str(cook_r.get("label", ""))
			## Order-up bell already rang at serve start — grade tunes only here.
			if not was_meh and grade_lab in ["Wow!", "Perfect!", "Great!", "Good"]:
				game_audio.play_grade_tune(grade_lab)
		var speed_top: bool = str(cook_r.get("label", "")) in ["Wow!", "Perfect!"]
		var was_perfect: bool = (
			not was_meh
			and ((bool(pay.get("perfect", false)) and patty_mult >= 1.0 and fresh_r > 0.4) or speed_top)
		)
		if not guest_mp:
			if was_perfect:
				combo += 1
				perfect_serves += 1
			elif not was_meh and float(result.quality) > 0.85 and fresh_r > 0.4 and int(cook_r["score"]) >= 70:
				combo += 1
			else:
				combo = 0
		if was_meh:
			_flash(
				"+%s  Meh… OK — needs seasoning (no tip)%s" % [
					_format_money(float(payout)), cook_bit
				],
				Color("B0BEC5")
			)
		elif tip_amt > 0:
			_flash("+%s  (+%s tip!)%s%s" % [
				_format_money(float(payout)), _format_money(float(tip_amt)),
				"  COMBO x%d" % combo if combo > 1 else "",
				cook_bit
			], cook_r["color"] if int(cook_r["score"]) >= 70 else Color("FFE082"))
		elif str(cook_r.get("label", "")) == "Wow!":
			_flash("+%s  Wow! COMBO x%d%s" % [_format_money(float(payout)), combo, cook_bit], Color("FFD54F"))
		elif speed_top:
			_flash("+%s  Perfect! COMBO x%d%s" % [_format_money(float(payout)), combo, cook_bit], Color("FFEB3B"))
		else:
			var fresh_note := " (stale)" if fresh_r <= 0.4 else ""
			_flash("+%s%s%s" % [_format_money(float(payout)), fresh_note, cook_bit], cook_r["color"])
	else:
		if not guest_mp:
			combo = 0
		_flash("Wrong order! Customer is MAD%s" % cook_bit, Color("EF5350"))

	if not guest_mp:
		var review_stars := _review_stars_from_serve(
			payout,
			was_meh,
			payout <= 0,
			cook_r,
			float(result.quality)
		)
		var review_kind := "good"
		if payout <= 0:
			review_kind = "wrong"
		elif _cook_rating_is_burnt(cook_r):
			## Keep kind=burnt so the text can brag about liking ash (or trash it).
			review_kind = "burnt"
		elif was_meh or review_stars < 2.75:
			review_kind = "meh"
		elif review_stars <= 1.5:
			review_kind = "angry"
		_maybe_record_social_review(review_stars, review_kind, tip_amt, station_index)
	_clear_station(station_index)
	_update_hud()
	_mp_serve_sync = false
	if mp_enabled and NetManager.is_host() and not _mp_applying:
		_mp_broadcast_economy()
		_mp_broadcast_customers()
		_mp_broadcast_grill()
		_mp_broadcast_station(station_index)


func _serve_reject_hint(order: Array, station_index: int) -> void:
	if station_index < 0 or station_index >= STATION_COUNT:
		_flash("Build the burger on Build, then Serve", Color("EF5350"))
		return
	_sync_station_cheese_items(station_index)
	var items: Array = stations[station_index]["items"]
	var result: Dictionary = GameDataScript.compare_orders(items, order)
	var missing: Array = result.get("missing", [])
	var extra: Array = result.get("extra", [])
	if not extra.is_empty():
		_flash("Remove: %s" % _missing_items_label(extra), Color("FF8A65"))
	elif _station_has_melting_cheese(station_index) and missing.has("cheese"):
		_flash("Cheese still melting — wait a sec, then Serve", Color("FFE082"))
	elif not missing.is_empty():
		_flash("Need: %s" % _missing_items_label(missing), Color("FF8A65"))
	else:
		_flash("Fix the burger on Build, then Serve", Color("FF8A65"))


func _on_serve() -> void:
	if not playing or _serve_fly_busy:
		return
	## Resolve customer + perfect Build station before RPCing so peers share one outcome.
	var cust = _resolve_serve_customer()
	if cust == null:
		if not _auto_serving:
			_flash("Click an order ticket first, then Serve", Color("EF5350"))
		return
	var order: Array = cust.order
	var station_index := _find_perfect_station_for(order)
	if station_index < 0:
		combo = 0
		if not _auto_serving:
			_serve_reject_hint(order, _find_station_for_order(order))
		_update_hud()
		return
	if mp_enabled and not _mp_applying:
		var cid := _customer_net_id(cust)
		mp_serve.rpc(cid, station_index)
		return
	_begin_serve_at(cust, station_index, false)


func _resolve_serve_customer():
	if selected_customer != null and is_instance_valid(selected_customer) and selected_customer.is_waiting:
		return selected_customer
	selected_customer = null
	for c in customers:
		if c != null and is_instance_valid(c) and c.is_waiting:
			if selected_customer != null:
				selected_customer = null
				break
			selected_customer = c
	_highlight_tickets()
	return selected_customer


func _begin_serve_at(customer: Node3D, station_index: int, force_mp: bool) -> void:
	if not playing or _serve_fly_busy:
		return
	if customer == null or not is_instance_valid(customer) or not customer.is_waiting:
		if force_mp:
			return
		if not _auto_serving:
			_flash("Click an order ticket first, then Serve", Color("EF5350"))
		return
	selected_customer = customer
	_highlight_tickets()
	if customer.dialogue_open:
		customer.dialogue_open = false

	if station_index < 0 or station_index >= STATION_COUNT:
		if force_mp:
			_mp_force_finish_customer(customer)
		return

	var st: Dictionary = stations[station_index]
	var items: Array = st["items"]
	## Remote peer already validated — if our Build drifted empty, still clear the order.
	if force_mp and (items.is_empty() or not items.has("patty")):
		_mp_force_finish_customer(customer)
		_clear_station(station_index)
		_update_hud()
		return

	if not force_mp:
		var order_check: Array = customer.order
		if _find_perfect_station_for(order_check) != station_index \
			and not _station_only_needs_top_bun(items, order_check) \
			and not bool(GameDataScript.compare_orders(items, order_check).get("perfect", false)):
			## Safety: local path should have validated already.
			pass

	_sync_station_cheese_items(station_index)
	items = st["items"]
	active_station = station_index
	_highlight_active_station()

	var order: Array = customer.order
	var crowned_for_serve := false
	if items.has("patty") and not items.has("bun_top") and order.has("bun_top"):
		crowned_for_serve = _crown_serve_burger(station_index)
		if crowned_for_serve:
			_start_station_freshness(station_index)
			_refresh_station(station_index)
			items = st["items"]

	if game_audio and game_audio.has_method("play_order_up"):
		game_audio.play_order_up()

	if station_index == STATION_CRAFT:
		var cust: Node3D = customer
		var si := station_index
		if crowned_for_serve:
			_animate_top_bun_on_station(si, func() -> void:
				_play_serve_fly_to_mouth(si, cust, func() -> void: _complete_serve(si))
			)
		else:
			_play_serve_fly_to_mouth(si, cust, func() -> void: _complete_serve(si))
		return

	_complete_serve(station_index)


func _mp_force_finish_customer(customer: Node3D) -> void:
	## Build drifted on this peer — still dismiss the shared order.
	if customer == null or not is_instance_valid(customer):
		return
	if customer.has_method("complete_serve"):
		customer.complete_serve(0)
	elif customer.has_method("leave_happy"):
		customer.leave_happy()
		_on_customer_left(customer, false)


func _on_serve_local() -> void:
	## Kept for older call sites — prefer _begin_serve_at.
	var cust = _resolve_serve_customer()
	if cust == null:
		if not _auto_serving:
			_flash("Click an order ticket first, then Serve", Color("EF5350"))
		return
	var station_index := _find_perfect_station_for(cust.order)
	if station_index < 0:
		combo = 0
		if not _auto_serving:
			_serve_reject_hint(cust.order, _find_station_for_order(cust.order))
		_update_hud()
		return
	_begin_serve_at(cust, station_index, false)


func _find_station_for_order(order: Array) -> int:
	## Perfect match wins (auto-serve + manual Serve with a finished burger).
	var perfect := _find_perfect_station_for(order)
	if perfect >= 0:
		return perfect
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


func _ingredient_cost(id: String) -> float:
	if id == "bacon":
		return COST_BACON
	if id == "bun_bottom" or id == "patty" or id == "":
		return 0.0
	return COST_INGREDIENT


func _format_money(amount: float) -> String:
	return "$%.2f" % amount


func _spend(amount: float, note: String = "", col: Color = Color("FFAB91")) -> void:
	if amount <= 0.001:
		return
	money = maxf(0.0, money - amount)
	_update_hud()
	if note != "":
		_flash(note, col)
	if mp_enabled and NetManager.is_host() and not _mp_applying:
		_mp_broadcast_economy()


func _update_hud() -> void:
	hud_money.text = _format_money(money)
	hud_combo.text = "Combo x%d" % combo if combo > 0 else "Combo -"
	if day_time <= 0.0 and customers.size() > 0:
		hud_day.text = "Day %d  -  CLOSING" % day
	else:
		hud_day.text = "Day %d  -  %ds" % [day, maxi(0, int(ceil(day_time)))]


func _begin_start_tutorial() -> void:
	_set_tutorial_hint(1, "Turn on grill or burner")


func _set_tutorial_hint(step: int, text: String) -> void:
	_tutorial_step = step
	_tutorial_text = text
	if flash_label == null:
		return
	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
		_flash_tween = null
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", Color("FFEB3B"))
	flash_label.visible = true
	flash_label.modulate.a = 1.0


func _clear_tutorial_hint() -> void:
	_tutorial_step = 0
	_tutorial_text = ""
	if flash_label == null:
		return
	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
		_flash_tween = null
	flash_label.visible = false
	flash_label.modulate.a = 1.0


func _flash(text: String, color: Color) -> void:
	if flash_label == null:
		return
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	flash_label.visible = true
	flash_label.modulate.a = 1.0
	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(1.1)
	_flash_tween.tween_property(flash_label, "modulate:a", 0.0, 0.4)
	_flash_tween.tween_callback(func():
		if _tutorial_text != "":
			flash_label.text = _tutorial_text
			flash_label.add_theme_color_override("font_color", Color("FFEB3B"))
			flash_label.visible = true
			flash_label.modulate.a = 1.0
		else:
			flash_label.visible = false
			flash_label.modulate.a = 1.0
	)

# =============================================================================
func _setup_start_menu_chrome() -> void:
	## Dark title wash + black CTA card; logo sits in front of the card.
	if start_overlay != null and is_instance_valid(start_overlay):
		start_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
		start_overlay.z_index = 40
		start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := get_node_or_null("UI/Root/StartOverlay/StartCenter") as VBoxContainer
	if center == null:
		return
	if center.get_node_or_null("StartMenuCard") != null:
		return

	var card := PanelContainer.new()
	card.name = "StartMenuCard"
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.z_index = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 72 ## room for logo overlap
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)

	var card_col := VBoxContainer.new()
	card_col.name = "StartMenuCol"
	card_col.alignment = BoxContainer.ALIGNMENT_CENTER
	card_col.add_theme_constant_override("separation", 16)
	card.add_child(card_col)

	var blurb := center.get_node_or_null("Blurb") as Control
	var mode_row := center.get_node_or_null("StartModeRow") as Control
	## Fallback: start button still on center if row wasn't built yet.
	if mode_row == null and start_btn != null and start_btn.get_parent() == center:
		mode_row = start_btn

	center.add_child(card)
	## Card sits under logo in the stack; pull it up so the mark overlays the panel.
	if start_logo_wrap != null and is_instance_valid(start_logo_wrap):
		start_logo_wrap.z_index = 5
		center.move_child(start_logo_wrap, 0)
		center.move_child(card, 1)
		center.add_theme_constant_override("separation", -56)
	else:
		center.move_child(card, 0)

	if blurb != null and is_instance_valid(blurb):
		blurb.reparent(card_col)
		blurb.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.95))
	if mode_row != null and is_instance_valid(mode_row):
		mode_row.reparent(card_col)

	## Title label stays hidden / unused.
	var title := center.get_node_or_null("Title") as Control
	if title != null:
		center.move_child(title, center.get_child_count() - 1)


# Multiplayer co-op (P2P via NetManager)
# =============================================================================

func _setup_multiplayer_ui() -> void:
	var center := get_node_or_null("UI/Root/StartOverlay/StartCenter") as VBoxContainer
	if center == null:
		return
	## Make sure the home panel is tall enough for both buttons.
	center.offset_top = minf(center.offset_top, -300.0)
	center.offset_bottom = maxf(center.offset_bottom, 300.0)
	center.offset_left = minf(center.offset_left, -380.0)
	center.offset_right = maxf(center.offset_right, 380.0)

	## Solo + Multiplayer row directly under OPEN THE TRUCK.
	var start_mode_row := HBoxContainer.new()
	start_mode_row.name = "StartModeRow"
	start_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	start_mode_row.add_theme_constant_override("separation", 14)
	start_mode_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	## Re-parent the existing start button into the row if possible.
	if start_btn and start_btn.get_parent() == center:
		center.remove_child(start_btn)
		start_mode_row.add_child(start_btn)
		start_btn.custom_minimum_size = Vector2(220, 56)

	multiplayer_btn = Button.new()
	multiplayer_btn.name = "MultiplayerButton"
	multiplayer_btn.text = "MULTIPLAYER"
	multiplayer_btn.custom_minimum_size = Vector2(220, 56)
	multiplayer_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiFontsScript.apply_button(multiplayer_btn, true, 20)
	## Warm accent so it reads as a second primary CTA.
	var mp_normal := StyleBoxFlat.new()
	mp_normal.bg_color = Color(0.85, 0.45, 0.12, 0.95)
	mp_normal.set_corner_radius_all(10)
	mp_normal.content_margin_left = 16
	mp_normal.content_margin_right = 16
	mp_normal.content_margin_top = 10
	mp_normal.content_margin_bottom = 10
	var mp_hover := mp_normal.duplicate() as StyleBoxFlat
	mp_hover.bg_color = Color(1.0, 0.55, 0.18, 1.0)
	var mp_pressed := mp_normal.duplicate() as StyleBoxFlat
	mp_pressed.bg_color = Color(0.7, 0.35, 0.08, 1.0)
	multiplayer_btn.add_theme_stylebox_override("normal", mp_normal)
	multiplayer_btn.add_theme_stylebox_override("hover", mp_hover)
	multiplayer_btn.add_theme_stylebox_override("pressed", mp_pressed)
	multiplayer_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	start_mode_row.add_child(multiplayer_btn)

	center.add_child(start_mode_row)
	## Keep buttons under the blurb (after Title/Logo/Blurb).
	var blurb := center.get_node_or_null("Blurb")
	if blurb:
		center.move_child(start_mode_row, blurb.get_index() + 1)
	elif start_btn and start_btn.get_parent() == start_mode_row:
		## Already structured.
		pass

	multiplayer_btn.pressed.connect(func():
		_sfx_click()
		_open_mp_lobby()
	)

	_setup_start_menu_chrome()

	_mp_lobby_root = Control.new()
	_mp_lobby_root.name = "MpLobby"
	_mp_lobby_root.visible = false
	_mp_lobby_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mp_lobby_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_mp_lobby_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "LobbyPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360.0
	panel.offset_right = 360.0
	panel.offset_top = -300.0
	panel.offset_bottom = 300.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.14, 0.97)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.72, 0.28, 0.9)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_mp_lobby_root.add_child(panel)

	## Scroll so Ready / Start never fall below the window on short displays.
	var panel_scroll := ScrollContainer.new()
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 7)
	panel_scroll.add_child(v)

	var title := Label.new()
	title.text = "ROOM BROWSER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_label(title, true, 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	v.add_child(title)

	var tip := Label.new()
	tip.text = "2–4 cooks. Host → code → everyone Ready → host Start Co-op (or wait for more)."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_label(tip, false, 12)
	v.add_child(tip)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	v.add_child(name_row)
	var name_lab := Label.new()
	name_lab.text = "Your name"
	name_lab.custom_minimum_size = Vector2(88, 0)
	UiFontsScript.apply_label(name_lab, false, 13)
	name_row.add_child(name_lab)
	_mp_name_edit = LineEdit.new()
	_mp_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_name_edit.text = NetManager.player_name
	_mp_name_edit.max_length = 12
	_mp_name_edit.placeholder_text = "Cook"
	name_row.add_child(_mp_name_edit)

	var relay_row := HBoxContainer.new()
	relay_row.add_theme_constant_override("separation", 8)
	v.add_child(relay_row)
	var relay_lab := Label.new()
	relay_lab.text = "Online relay"
	relay_lab.custom_minimum_size = Vector2(88, 0)
	UiFontsScript.apply_label(relay_lab, false, 13)
	relay_row.add_child(relay_lab)
	_mp_relay_edit = LineEdit.new()
	_mp_relay_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_relay_edit.text = NetManager.get_relay_url()
	_mp_relay_edit.placeholder_text = "wss://your-app.up.railway.app"
	_mp_relay_edit.focus_exited.connect(func():
		if _mp_relay_edit:
			NetManager.set_relay_url(_mp_relay_edit.text)
	)
	relay_row.add_child(_mp_relay_edit)

	var lobby_actions := HBoxContainer.new()
	lobby_actions.add_theme_constant_override("separation", 8)
	lobby_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(lobby_actions)

	_mp_host_btn = Button.new()
	_mp_host_btn.text = "Host Room"
	_mp_host_btn.custom_minimum_size = Vector2(140, 40)
	UiFontsScript.apply_button(_mp_host_btn, true, 15)
	lobby_actions.add_child(_mp_host_btn)
	_mp_host_btn.pressed.connect(_mp_on_host_pressed)

	_mp_refresh_btn = Button.new()
	_mp_refresh_btn.text = "Refresh"
	_mp_refresh_btn.custom_minimum_size = Vector2(110, 40)
	UiFontsScript.apply_button(_mp_refresh_btn, true, 15)
	lobby_actions.add_child(_mp_refresh_btn)
	_mp_refresh_btn.pressed.connect(func():
		_sfx_click()
		NetManager.refresh_rooms()
		_mp_rebuild_room_list()
		_flash("Scanning for rooms...", Color("90CAF9"))
	)

	_mp_join_local_btn = Button.new()
	_mp_join_local_btn.text = "Quick Join"
	_mp_join_local_btn.custom_minimum_size = Vector2(120, 40)
	UiFontsScript.apply_button(_mp_join_local_btn, true, 14)
	lobby_actions.add_child(_mp_join_local_btn)
	_mp_join_local_btn.pressed.connect(_mp_on_join_localhost)

	_mp_host_addr_label = Label.new()
	_mp_host_addr_label.visible = false
	_mp_host_addr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_host_addr_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(_mp_host_addr_label, true, 28)
	_mp_host_addr_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	v.add_child(_mp_host_addr_label)

	## Ready / Start sit under the room code so they stay on-screen (not under the room list).
	var ready_row := HBoxContainer.new()
	ready_row.name = "ReadyRow"
	ready_row.add_theme_constant_override("separation", 10)
	ready_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(ready_row)

	_mp_ready_btn = Button.new()
	_mp_ready_btn.text = "Ready"
	_mp_ready_btn.custom_minimum_size = Vector2(140, 44)
	_mp_ready_btn.visible = false
	UiFontsScript.apply_button(_mp_ready_btn, true, 17)
	ready_row.add_child(_mp_ready_btn)
	_mp_ready_btn.pressed.connect(func():
		_sfx_click()
		var me := NetManager.my_id()
		var now_ready := not bool(NetManager.peers_ready.get(me, false))
		NetManager.set_ready(now_ready)
		_mp_refresh_lobby_status()
	)

	_mp_start_coop_btn = Button.new()
	_mp_start_coop_btn.text = "Start Co-op"
	_mp_start_coop_btn.custom_minimum_size = Vector2(180, 44)
	_mp_start_coop_btn.visible = false
	UiFontsScript.apply_button(_mp_start_coop_btn, true, 17)
	ready_row.add_child(_mp_start_coop_btn)
	_mp_start_coop_btn.pressed.connect(func():
		_sfx_click()
		NetManager.request_start_session()
	)

	var rooms_header := HBoxContainer.new()
	rooms_header.add_theme_constant_override("separation", 8)
	v.add_child(rooms_header)
	var rooms_lab := Label.new()
	rooms_lab.text = "Open rooms"
	rooms_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_label(rooms_lab, true, 14)
	rooms_header.add_child(rooms_lab)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_mp_room_list = VBoxContainer.new()
	_mp_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_room_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_mp_room_list)

	var manual_lab := Label.new()
	manual_lab.text = "Join with room code"
	UiFontsScript.apply_label(manual_lab, true, 13)
	v.add_child(manual_lab)

	var manual_row := HBoxContainer.new()
	manual_row.add_theme_constant_override("separation", 8)
	manual_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(manual_row)
	_mp_code_edit = LineEdit.new()
	_mp_code_edit.custom_minimum_size = Vector2(140, 40)
	_mp_code_edit.placeholder_text = "1234"
	_mp_code_edit.max_length = 4
	_mp_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_code_edit.text = ""
	_mp_code_edit.secret = false
	manual_row.add_child(_mp_code_edit)
	_mp_code_join_btn = Button.new()
	_mp_code_join_btn.text = "Join Code"
	_mp_code_join_btn.custom_minimum_size = Vector2(120, 40)
	UiFontsScript.apply_button(_mp_code_join_btn, true, 15)
	manual_row.add_child(_mp_code_join_btn)
	_mp_code_join_btn.pressed.connect(_mp_on_code_join)
	_mp_code_edit.text_submitted.connect(func(_t: String): _mp_on_code_join())

	_mp_status_label = Label.new()
	_mp_status_label.text = "Scanning for open rooms..."
	_mp_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mp_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_label(_mp_status_label, false, 12)
	v.add_child(_mp_status_label)

	_mp_back_btn = Button.new()
	_mp_back_btn.text = "Back"
	_mp_back_btn.custom_minimum_size = Vector2(120, 36)
	_mp_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiFontsScript.apply_button(_mp_back_btn, false, 15)
	v.add_child(_mp_back_btn)
	_mp_back_btn.pressed.connect(func():
		_sfx_click()
		_close_mp_lobby()
	)

	var ui_root: Control = get_node("UI/Root")
	ui_root.add_child(_mp_lobby_root)
	_mp_lobby_root.z_index = 80

	_mp_cursor_layer = Control.new()
	_mp_cursor_layer.name = "MpRemoteCursors"
	_mp_cursor_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mp_cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mp_cursor_layer.z_index = 90
	ui_root.add_child(_mp_cursor_layer)

	NetManager.rooms_updated.connect(_mp_rebuild_room_list)
	NetManager.connection_changed.connect(_mp_on_connection_changed)
	NetManager.peer_ready_changed.connect(_mp_refresh_lobby_status)
	NetManager.session_start_requested.connect(_mp_on_session_start)
	NetManager.chat_flash.connect(func(t: String, c: Color): _flash(t, c))


func _open_mp_lobby() -> void:
	_mp_enter_windowed_for_coop()
	_fit_mp_lobby_panel()
	if _mp_lobby_root:
		_mp_lobby_root.visible = true
	NetManager.begin_browse()
	NetManager.refresh_rooms()
	_mp_rebuild_room_list()
	_mp_refresh_lobby_status()


func _fit_mp_lobby_panel() -> void:
	## Dual windowed clients often have a short client area — keep Ready/Start on screen.
	if _mp_lobby_root == null:
		return
	var panel := _mp_lobby_root.get_node_or_null("LobbyPanel") as PanelContainer
	if panel == null:
		return
	var vr := get_viewport().get_visible_rect()
	var half_w := mini(360.0, vr.size.x * 0.48)
	var half_h := clampf(vr.size.y * 0.46, 200.0, 300.0)
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.offset_top = -half_h
	panel.offset_bottom = half_h


func _close_mp_lobby() -> void:
	if not NetManager.is_online():
		NetManager.stop_browse()
		NetManager.leave()
	if _mp_lobby_root:
		_mp_lobby_root.visible = false


func _mp_enter_windowed_for_coop() -> void:
	## Two instances on one PC need windowed mode.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1100, 720))
	var idx := DisplayServer.get_primary_screen()
	var screen := DisplayServer.screen_get_usable_rect(idx)
	var offset := Vector2i(40, 40)
	if NetManager.role == NetManager.Role.CLIENT or OS.get_process_id() % 2 == 0:
		offset = Vector2i(120, 80)
	DisplayServer.window_set_position(screen.position + offset)


func _mp_on_host_pressed() -> void:
	_sfx_click()
	if _mp_name_edit:
		NetManager.player_name = _mp_name_edit.text.strip_edges()
	if _mp_relay_edit:
		NetManager.set_relay_url(_mp_relay_edit.text)
	_mp_enter_windowed_for_coop()
	var err := NetManager.host_room(NetManager.player_name)
	if err != OK:
		_flash("Could not host — try again", Color("EF5350"))
		return
	mp_enabled = true
	if _mp_code_edit:
		_mp_code_edit.text = NetManager.room_code
	_mp_refresh_lobby_status()
	if NetManager.has_relay_url():
		_flash("Hosting online — share the room code", Color("81C784"))
	else:
		_flash("No relay URL — LAN / same Wi‑Fi only", Color("FFA726"))


func _mp_on_join_localhost() -> void:
	_sfx_click()
	if _mp_name_edit:
		NetManager.player_name = _mp_name_edit.text.strip_edges()
	## Join first open room with space (prefer this PC).
	for r in NetManager.discovered_rooms:
		var players := int(r.get("players", 1))
		var max_p := int(r.get("max", NetManager.MAX_PLAYERS))
		if players >= max_p:
			continue
		var code := str(r.get("code", ""))
		if code == "":
			continue
		var ip := str(r.get("ip", ""))
		if ip in ["127.0.0.1", "localhost"]:
			_mp_join_by_code(code)
			return
	for r in NetManager.discovered_rooms:
		if int(r.get("players", 1)) < int(r.get("max", NetManager.MAX_PLAYERS)):
			_mp_join_by_code(str(r.get("code", "")))
			return
	_flash("No open room found — Host one, or enter a code", Color("FFA726"))


func _mp_on_code_join() -> void:
	_sfx_click()
	if _mp_name_edit:
		NetManager.player_name = _mp_name_edit.text.strip_edges()
	var raw := ""
	if _mp_code_edit:
		raw = _mp_code_edit.text.strip_edges()
	if raw == "":
		_flash("Enter the 4-digit room code", Color("FFA726"))
		return
	_mp_join_by_code(raw)


func _mp_join_by_code(code: String) -> void:
	if _mp_relay_edit:
		NetManager.set_relay_url(_mp_relay_edit.text)
	_mp_enter_windowed_for_coop()
	var pname := NetManager.player_name
	if _mp_name_edit:
		pname = _mp_name_edit.text.strip_edges()
	var normalized := NetManager.normalize_code(code)
	if _mp_code_edit:
		_mp_code_edit.text = normalized
	var err := NetManager.join_by_code(normalized, pname)
	if err != OK:
		_flash("Join failed", Color("EF5350"))
		return
	mp_enabled = true
	_mp_status_label.text = "Joining room %s..." % normalized
	_mp_refresh_lobby_status()


func _mp_join_room(ip: String, port: int) -> void:
	## Legacy helper — route through room code.
	_mp_join_by_code(NetManager.code_from_port(port))


func _mp_on_connection_changed() -> void:
	mp_enabled = NetManager.is_online() or NetManager.role == NetManager.Role.HOST or NetManager.role == NetManager.Role.CLIENT
	_mp_refresh_lobby_status()
	_mp_rebuild_room_list()


func _mp_refresh_lobby_status() -> void:
	if _mp_status_label == null:
		return
	var online := NetManager.is_online()
	_mp_ready_btn.visible = online
	_mp_start_coop_btn.visible = online and NetManager.is_host()
	if _mp_host_addr_label:
		if NetManager.role == NetManager.Role.HOST and online:
			_mp_host_addr_label.visible = true
			_mp_host_addr_label.text = "ROOM CODE  %s" % NetManager.room_code
		elif NetManager.is_online() and NetManager.is_client():
			_mp_host_addr_label.visible = true
			_mp_host_addr_label.text = "Joined  %s" % NetManager.room_code
			_mp_host_addr_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		else:
			_mp_host_addr_label.visible = false
			_mp_host_addr_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	if not online:
		if NetManager.is_seeking_room() or NetManager.role == NetManager.Role.CLIENT:
			var seek := NetManager.seeking_code()
			if seek == "":
				seek = NetManager.room_code
			_mp_status_label.text = "Looking for room %s..." % NetManager.normalize_code(seek)
		elif NetManager.role == NetManager.Role.HOST:
			_mp_status_label.text = "Share code %s — waiting for a cook to join..." % NetManager.room_code
		else:
			var n := NetManager.discovered_rooms.size()
			if n > 0:
				_mp_status_label.text = "Found %d open room%s — Join, or type a code." % [n, "s" if n != 1 else ""]
			else:
				_mp_status_label.text = "Host a room for a code, or enter a friend's 4-digit code."
		return
	var n := NetManager.peer_count()
	var who := "Host" if NetManager.is_host() else "Guest"
	var me_ready := bool(NetManager.peers_ready.get(NetManager.my_id(), false))
	if _mp_ready_btn:
		_mp_ready_btn.text = "Unready" if me_ready else "Ready"
	var ready_line := NetManager.ready_summary()
	if NetManager.session_active:
		_mp_status_label.text = "%s · room %s — shift live · %d/%d (code joins OK)" % [
			who, NetManager.room_code, n, NetManager.MAX_PLAYERS
		]
	else:
		_mp_status_label.text = "%s · room %s — %d/%d cooks\n%s\nAll Ready → host taps Start Co-op (works with 2, 3, or 4)" % [
			who, NetManager.room_code, n, NetManager.MAX_PLAYERS, ready_line
		]
	var can_start := n >= 2 and n <= NetManager.MAX_PLAYERS and NetManager.all_peers_ready()
	_mp_start_coop_btn.disabled = not can_start
	if n < 2:
		_mp_start_coop_btn.text = "Need 2+ cooks"
	elif n > NetManager.MAX_PLAYERS:
		_mp_start_coop_btn.text = "Too many cooks"
	elif not NetManager.all_peers_ready():
		_mp_start_coop_btn.text = "Waiting for Ready"
	elif n >= NetManager.MAX_PLAYERS:
		_mp_start_coop_btn.text = "Start Co-op (4)"
	else:
		_mp_start_coop_btn.text = "Start Co-op (%d)" % n
	if can_start:
		_mp_start_coop_btn.modulate = Color(1.0, 1.0, 0.85)
	else:
		_mp_start_coop_btn.modulate = Color(1, 1, 1)


func _mp_rebuild_room_list() -> void:
	if _mp_room_list == null:
		return
	for c in _mp_room_list.get_children():
		c.queue_free()
	if NetManager.discovered_rooms.is_empty():
		var empty := Label.new()
		empty.text = "No open rooms yet.\nHost in one window, then Join with the code (or Quick Join) in the other."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFontsScript.apply_label(empty, false, 12)
		_mp_room_list.add_child(empty)
		_mp_refresh_lobby_status()
		return
	for r in NetManager.discovered_rooms:
		var players := int(r.get("players", 1))
		var max_p := int(r.get("max", NetManager.MAX_PLAYERS))
		var full := players >= max_p
		var code := str(r.get("code", NetManager.code_from_port(int(r.get("port", 0)))))

		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.14, 0.16, 0.2, 0.95)
		row_style.set_corner_radius_all(8)
		row_style.set_border_width_all(1)
		row_style.border_color = Color(0.35, 0.4, 0.48, 0.9) if full else Color(0.45, 0.7, 0.45, 0.85)
		row_style.content_margin_left = 10
		row_style.content_margin_right = 8
		row_style.content_margin_top = 6
		row_style.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", row_style)
		_mp_room_list.add_child(row)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)

		var code_lab := Label.new()
		code_lab.text = code
		code_lab.custom_minimum_size = Vector2(72, 0)
		UiFontsScript.apply_label(code_lab, true, 22)
		code_lab.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		h.add_child(code_lab)

		var lab := Label.new()
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.text = "%s\n%s · %d/%d cooks" % [
			str(r.get("name", "Truck")),
			str(r.get("host", "Cook")),
			players,
			max_p,
		]
		UiFontsScript.apply_label(lab, false, 12)
		h.add_child(lab)

		var join := Button.new()
		join.custom_minimum_size = Vector2(78, 36)
		if full:
			join.text = "Full"
			join.disabled = true
		else:
			join.text = "Join"
		UiFontsScript.apply_button(join, true, 13)
		var join_code := code
		join.pressed.connect(func():
			_sfx_click()
			if _mp_name_edit:
				NetManager.player_name = _mp_name_edit.text.strip_edges()
			if _mp_code_edit:
				_mp_code_edit.text = join_code
			_mp_join_by_code(join_code)
		)
		h.add_child(join)
	_mp_refresh_lobby_status()


func _mp_on_session_start(session_seed: int) -> void:
	seed(session_seed)
	mp_enabled = true
	mp_held_net.clear()
	drag_owner_id = 0
	if _mp_lobby_root:
		_mp_lobby_root.visible = false
	NetManager.stop_browse()
	NetManager.announce_player_name()
	var mid_join := playing and NetManager.is_host()
	if mid_join:
		## Host already mid-shift — late joiner gets catch-up via bootstrap request.
		return
	if playing and not NetManager.is_host():
		## Rare: guest already playing; still request a fresh host snapshot.
		mp_request_bootstrap.rpc_id(1)
		return
	_flash("Co-op shift — up to 4 cooks! Match glove colors", Color("FFEB3B"))
	_start_game()
	## Host owns cat AI; guest follows sync so peeks / hearts match.
	if window_cat != null and is_instance_valid(window_cat):
		window_cat.set("mp_puppet", not NetManager.is_host())
		if NetManager.is_host():
			_mp_send_cat_sync()
			call_deferred("_mp_broadcast_economy")
		else:
			## Late join / first start: pull absolute kitchen state from host.
			call_deferred("_mp_request_bootstrap_deferred")


func _mp_request_bootstrap_deferred() -> void:
	if not mp_enabled or NetManager.is_host():
		return
	if not NetManager.is_online():
		return
	mp_request_bootstrap.rpc_id(1)


@rpc("any_peer", "reliable")
func mp_request_bootstrap() -> void:
	if not NetManager.is_host():
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		return
	_mp_send_bootstrap_to(sid)


func _mp_send_bootstrap_to(peer_id: int) -> void:
	## Full mid-round catch-up: economy, customers, patties, grill, Build.
	if not NetManager.is_host() or not playing:
		return
	mp_bootstrap_meta.rpc_id(peer_id, NetManager.peek_next_net_id(), _mp_next_customer_net_id, day, day_time)
	_mp_broadcast_economy()
	## Respawn every living customer with order + look so tickets match.
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get("is_leaving")):
			continue
		var nid := _customer_net_id(c)
		if nid < 0:
			continue
		var order_packed: Array = []
		for o in c.order:
			order_packed.append(str(o))
		var col: Color = c.body_color if "body_color" in c else Color(0.8, 0.4, 0.3)
		var patience := float(c.patience) if "patience" in c else 40.0
		var lane := int(c.lane) if "lane" in c else 0
		var skin_i := int(c.skin_idx) if "skin_idx" in c else 0
		var face_i := int(c.face_style) if "face_style" in c else 0
		mp_spawn_customer.rpc_id(
			peer_id, nid, order_packed, col.r, col.g, col.b, patience, lane, skin_i, face_i
		)
	## Grill + Build patties.
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p):
			continue
		var pnid := int(p.get("net_id"))
		if pnid < 0:
			continue
		mp_spawn_patty.rpc_id(peer_id, pnid, i, float(p.position.x), float(p.position.z))
	for st in stations:
		for bp in st.get("patties", []):
			if bp == null or not is_instance_valid(bp):
				continue
			var bnid := int(bp.get("net_id"))
			if bnid < 0:
				continue
			## Spawn into a free grill slot on joiner, then station sync seats on Build.
			var slot := _first_empty_slot()
			if slot < 0:
				slot = 0
			mp_spawn_patty.rpc_id(peer_id, bnid, slot, float(bp.position.x), float(bp.position.z))
	_mp_broadcast_grill()
	for si in STATION_COUNT:
		_mp_broadcast_station(si)
	_mp_broadcast_customers()
	if window_cat != null and is_instance_valid(window_cat):
		_mp_send_cat_sync()


@rpc("any_peer", "reliable")
func mp_bootstrap_meta(next_patty_id: int, next_cust_id: int, d: int, dtime: float) -> void:
	if NetManager.is_host():
		return
	NetManager.bump_net_id_floor(next_patty_id)
	_mp_next_customer_net_id = maxi(_mp_next_customer_net_id, next_cust_id)
	day = d
	day_time = dtime
	_update_hud()


func _mp_send_held_tool_pose(force: bool = false) -> void:
	## Stream held tool world pose so the partner sees oil / shaker / ext / glock in-hand.
	if not mp_enabled or not NetManager.is_online():
		return
	if not force and _mp_tool_pose_cool > 0.0:
		return
	_mp_tool_pose_cool = 0.04
	if oil_held and oil_root != null and is_instance_valid(oil_root):
		var p: Vector3 = oil_root.global_position
		var r: Vector3 = oil_root.global_rotation_degrees
		var emitting := oil_particles != null and oil_particles.emitting
		mp_tool_pose.rpc(2, true, p.x, p.y, p.z, emitting, r.x, r.y, r.z)
	elif shaker_held and shaker_root != null and is_instance_valid(shaker_root):
		var sp: Vector3 = shaker_root.global_position
		var sr: Vector3 = shaker_root.global_rotation_degrees
		var semitting := shaker_particles != null and shaker_particles.emitting
		mp_tool_pose.rpc(4, true, sp.x, sp.y, sp.z, semitting, sr.x, sr.y, sr.z)
	elif ext_held and ext_root != null and is_instance_valid(ext_root):
		var ep: Vector3 = ext_root.global_position
		var er: Vector3 = ext_root.global_rotation_degrees
		var eemit := ext_spraying or (ext_powder != null and ext_powder.emitting)
		mp_tool_pose.rpc(5, true, ep.x, ep.y, ep.z, eemit, er.x, er.y, er.z)
	elif glock_held and glock_root != null and is_instance_valid(glock_root):
		var gp: Vector3 = glock_root.global_position
		var gr: Vector3 = glock_root.global_rotation_degrees
		mp_tool_pose.rpc(6, true, gp.x, gp.y, gp.z, true, gr.x, gr.y, gr.z)


func _mp_strip_tool_pickable(node: Node) -> void:
	if node == null:
		return
	if node is Area3D:
		(node as Area3D).input_ray_pickable = false
		(node as Area3D).collision_layer = 0
		(node as Area3D).monitoring = false
		(node as Area3D).monitorable = false
	for child in node.get_children():
		_mp_strip_tool_pickable(child)


func _mp_ensure_remote_tool(store: Dictionary, peer_id: int, source: Node3D, ghost_name: String) -> Node3D:
	if store.has(peer_id):
		var existing: Node3D = store[peer_id]
		if existing != null and is_instance_valid(existing):
			return existing
	if source == null or world == null:
		return null
	var ghost: Node3D = source.duplicate() as Node3D
	ghost.name = "%s_%d" % [ghost_name, peer_id]
	_mp_strip_tool_pickable(ghost)
	ghost.visible = false
	world.add_child(ghost)
	store[peer_id] = ghost
	return ghost


func _mp_ensure_remote_oil(peer_id: int) -> Node3D:
	return _mp_ensure_remote_tool(_mp_remote_oil, peer_id, oil_root, "RemoteOil")


func _mp_ensure_remote_shaker(peer_id: int) -> Node3D:
	return _mp_ensure_remote_tool(_mp_remote_shaker, peer_id, shaker_root, "RemoteShaker")


func _mp_ensure_remote_ext(peer_id: int) -> Node3D:
	return _mp_ensure_remote_tool(_mp_remote_ext, peer_id, ext_root, "RemoteExt")


func _mp_ensure_remote_glock(peer_id: int) -> Node3D:
	return _mp_ensure_remote_tool(_mp_remote_glock, peer_id, glock_root, "RemoteGlock")


func _mp_set_remote_tool_fx(root: Node3D, fx_name: String, emitting: bool) -> void:
	if root == null:
		return
	var fx = root.find_child(fx_name, true, false)
	if fx is GPUParticles3D:
		(fx as GPUParticles3D).emitting = emitting


func _mp_set_remote_glock_laser(root: Node3D, on: bool) -> void:
	if root == null:
		return
	for n in ["GlockLaserModule", "GlockLaserBeam", "GlockLaserDot"]:
		var node = root.find_child(n, true, false)
		if node != null and is_instance_valid(node):
			node.visible = on


func _mp_hide_remote_tools(peer_id: int, except_kind: int = -1) -> void:
	if except_kind != 2 and _mp_remote_oil.has(peer_id):
		var oil: Node3D = _mp_remote_oil[peer_id]
		if oil != null and is_instance_valid(oil):
			oil.visible = false
			_mp_set_remote_tool_fx(oil, "OilParticles", false)
	if except_kind != 4 and _mp_remote_shaker.has(peer_id):
		var sh: Node3D = _mp_remote_shaker[peer_id]
		if sh != null and is_instance_valid(sh):
			sh.visible = false
			_mp_set_remote_tool_fx(sh, "SeasonParticles", false)
	if except_kind != 5 and _mp_remote_ext.has(peer_id):
		var ex: Node3D = _mp_remote_ext[peer_id]
		if ex != null and is_instance_valid(ex):
			ex.visible = false
			_mp_set_remote_tool_fx(ex, "ExtPowder", false)
	if except_kind != 6 and _mp_remote_glock.has(peer_id):
		var gl: Node3D = _mp_remote_glock[peer_id]
		if gl != null and is_instance_valid(gl):
			gl.visible = false
			_mp_set_remote_glock_laser(gl, false)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_tool_pose(
	kind: int,
	active: bool,
	x: float,
	y: float,
	z: float,
	emitting: bool,
	rx: float = 0.0,
	ry: float = 0.0,
	rz: float = 0.0
) -> void:
	## kind: 2 oil · 4 shaker · 5 extinguisher · 6 glock
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0 or sid == multiplayer.get_unique_id():
		return
	if not active:
		_mp_hide_remote_tools(sid, -1)
		return
	_mp_hide_remote_tools(sid, kind)
	var pos := Vector3(x, y, z)
	var rot := Vector3(rx, ry, rz)
	match kind:
		2:
			var oil := _mp_ensure_remote_oil(sid)
			if oil == null:
				return
			oil.visible = true
			oil.global_position = pos
			oil.global_rotation_degrees = rot
			oil.scale = Vector3(2.05, 2.05, 2.05)
			_mp_set_remote_tool_fx(oil, "OilParticles", emitting)
		4:
			var shaker := _mp_ensure_remote_shaker(sid)
			if shaker == null:
				return
			shaker.visible = true
			shaker.global_position = pos
			shaker.global_rotation_degrees = rot
			shaker.scale = Vector3(2.15, 2.15, 2.15)
			_mp_set_remote_tool_fx(shaker, "SeasonParticles", emitting)
		5:
			var ext := _mp_ensure_remote_ext(sid)
			if ext == null:
				return
			ext.visible = true
			ext.global_position = pos
			ext.global_rotation_degrees = rot
			_mp_set_remote_tool_fx(ext, "ExtPowder", emitting)
		6:
			var glock := _mp_ensure_remote_glock(sid)
			if glock == null:
				return
			glock.visible = true
			glock.global_position = pos
			glock.global_rotation_degrees = rot
			_mp_set_remote_glock_laser(glock, true)
		_:
			pass


func _mp_update_cursors(delta: float) -> void:
	if not mp_enabled or not NetManager.is_online():
		for k in _mp_remote_cursors.keys():
			var node: Control = _mp_remote_cursors[k]
			if node and is_instance_valid(node):
				node.visible = false
		return
	_mp_cursor_accum += delta
	if _mp_cursor_accum >= 0.033:
		_mp_cursor_accum = 0.0
		var vp := get_viewport().get_visible_rect().size
		if vp.x > 1.0 and vp.y > 1.0:
			var m := get_viewport().get_mouse_position()
			var held := 1 if spatula_patty != null else 0
			var tool := 0
			if cheese_held:
				tool = 1
			elif oil_held:
				tool = 2
			elif brush_held:
				tool = 3
			elif shaker_held:
				tool = 4
			elif ext_held:
				tool = 5
			elif glock_held:
				tool = 6
			mp_cursor_pos.rpc(m.x / vp.x, m.y / vp.y, held, tool)


func _mp_ensure_remote_cursor(peer_id: int) -> Control:
	if _mp_remote_cursors.has(peer_id):
		var existing: Control = _mp_remote_cursors[peer_id]
		if existing != null and is_instance_valid(existing):
			return existing
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.z_index = 90
	var tex: Texture2D = load("res://assets/ui/cursor_glove.png") as Texture2D
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size = Vector2(48, 48)
	if tex:
		icon.texture = tex
	icon.modulate = NetManager.color_for_peer(peer_id)
	wrap.add_child(icon)
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(4, 44)
	tag.text = NetManager.name_for_peer(peer_id)
	tag.add_theme_color_override("font_color", NetManager.color_for_peer(peer_id))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.add_theme_constant_override("outline_size", 3)
	UiFontsScript.apply_label(tag, true, 12)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(tag)
	var badge := Label.new()
	badge.name = "Badge"
	badge.position = Vector2(36, -2)
	badge.text = ""
	badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	badge.add_theme_constant_override("outline_size", 3)
	UiFontsScript.apply_label(badge, true, 11)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(badge)
	_mp_cursor_layer.add_child(wrap)
	_mp_remote_cursors[peer_id] = wrap
	return wrap


func _mp_send_patty_pose(patty: Area3D, held: bool = false) -> void:
	if patty == null or not is_instance_valid(patty):
		return
	var nid := int(patty.get("net_id"))
	if nid < 0:
		return
	mp_patty_pose.rpc(nid, patty.position.x, patty.position.y, patty.position.z, held)


func _patty_by_net_id(net_id: int):
	if net_id < 0:
		return null
	for p in grill:
		if p != null and is_instance_valid(p) and int(p.get("net_id")) == net_id:
			return p
	if spatula_patty != null and is_instance_valid(spatula_patty) and int(spatula_patty.get("net_id")) == net_id:
		return spatula_patty
	for st in stations:
		for p in st.get("patties", []):
			if p != null and is_instance_valid(p) and int(p.get("net_id")) == net_id:
				return p
	for child in patties_root.get_children():
		if child != null and is_instance_valid(child) and int(child.get("net_id")) == net_id:
			return child
	return null


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_cursor_pos(nx: float, ny: float, held: int = 0, tool: int = 0) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0 or sid == multiplayer.get_unique_id():
		return
	var wrap := _mp_ensure_remote_cursor(sid)
	wrap.visible = true
	var vp := get_viewport().get_visible_rect().size
	## Hotspot matches local glove tip (~0, 3).
	wrap.position = Vector2(nx * vp.x, ny * vp.y) - Vector2(0, 3)
	var tag: Label = wrap.get_node_or_null("Tag") as Label
	if tag:
		tag.text = NetManager.name_for_peer(sid)
	var badge: Label = wrap.get_node_or_null("Badge") as Label
	if badge:
		if held != 0:
			badge.text = "●"
		elif tool == 1:
			badge.text = "C"
		elif tool == 2:
			badge.text = "O"
		elif tool == 3:
			badge.text = "B"
		elif tool == 4:
			badge.text = "S"
		elif tool == 5:
			badge.text = "E"
		elif tool == 6:
			badge.text = "G"
		else:
			badge.text = ""
	var icon: TextureRect = wrap.get_node_or_null("Icon") as TextureRect
	if icon:
		var col := NetManager.color_for_peer(sid)
		if held != 0:
			icon.modulate = col.lightened(0.25)
		else:
			icon.modulate = col


@rpc("any_peer", "call_local", "reliable")
func mp_toggle_grill(on: bool) -> void:
	_mp_applying = true
	_toggle_grill_power_local(on)
	_mp_applying = false


@rpc("any_peer", "reliable")
func mp_request_spawn_patty(x: float, z: float) -> void:
	if not NetManager.is_host():
		return
	var idx := _first_empty_slot()
	if idx < 0 or not grill_on:
		return
	var place_pos := _find_closest_patty_place(Vector3(x, GRILL_SURFACE_Y, z))
	if place_pos == Vector3.ZERO:
		place_pos = Vector3(x, GRILL_SURFACE_Y, z)
	var nid := NetManager.alloc_net_id()
	mp_spawn_patty.rpc(nid, idx, place_pos.x, place_pos.z)


@rpc("any_peer", "call_local", "reliable")
func mp_spawn_patty(net_id: int, idx: int, x: float, z: float) -> void:
	if net_id >= 0 and _patty_by_net_id(net_id) != null:
		return
	_mp_applying = true
	_spawn_patty_at(idx, Vector3(x, GRILL_SURFACE_Y, z), net_id)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_patty_click(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = NetManager.my_id()
	var holder := _mp_peer_holding_net(net_id)
	if holder != 0 and holder != sid:
		## Someone else is carrying it — use steal instead of click.
		return
	_mp_applying = true
	if sid == NetManager.my_id():
		spatula_owner_id = sid
		_on_patty_clicked_local(p)
		if spatula_patty != null:
			_mp_mark_held(sid, spatula_patty)
		else:
			spatula_owner_id = 0
	else:
		## Partner flip / scoop — never assign to our local spatula.
		if not p.flipped_once:
			if p.can_flip():
				p.flip()
		elif p.can_scoop():
			_mp_apply_remote_scoop(p, sid)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_patty_smash(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	_mp_applying = true
	p.smash()
	_mp_applying = false


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_patty_pose(net_id: int, x: float, y: float, z: float, held: bool) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	## Don't fight local drag / scoop ownership.
	if dragging_patty == p and drag_owner_id == NetManager.my_id():
		return
	if spatula_patty == p:
		return
	p.position = Vector3(x, y, z)
	p._rest_x = x
	p._rest_z = z
	if held:
		p.is_held = true
		p.heating = false
	## Never assign spatula_patty here — each cook keeps their own scoop.


@rpc("any_peer", "call_local", "reliable")
func mp_claim_drag(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null or not is_instance_valid(p):
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = NetManager.my_id()
	_mp_applying = true
	## Transfer drag claim.
	if dragging_patty == p and drag_owner_id != sid:
		dragging_patty = null
	drag_owner_id = sid
	if sid == NetManager.my_id():
		_begin_patty_drag_local(p)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_release_drag(net_id: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = NetManager.my_id()
	if drag_owner_id == sid or drag_owner_id == 0:
		drag_owner_id = 0
	var p = _patty_by_net_id(net_id)
	if p != null and dragging_patty == p and sid != NetManager.my_id():
		dragging_patty = null


@rpc("any_peer", "call_local", "reliable")
func mp_add_ingredient(station_index: int, id: String) -> void:
	_mp_applying = true
	_add_ingredient_to_station_local(station_index, id, true)
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()


@rpc("any_peer", "call_local", "reliable")
func mp_cheese_patty(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null or p.has_cheese:
		return
	_mp_applying = true
	if p.add_cheese():
		_mp_spend_ingredient("cheese")
		if game_audio:
			game_audio.play_ingredient("cheese")
		_flash("Cheese on! Melts in 3s", Color("FFE082"))
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()


@rpc("any_peer", "call_local", "reliable")
func mp_drop_to_build(net_id: int, index: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	_mp_applying = true
	_mp_release_scoop_if(p)
	if flicking_patty == p:
		flicking_patty = null
	if dragging_patty == p:
		dragging_patty = null
		drag_owner_id = 0
	var gidx: int = int(p.slot_index)
	if gidx >= 0 and gidx < grill.size() and grill[gidx] == p:
		grill[gidx] = null
	p.is_held = false
	_commit_patty_to_build(p)
	if index != STATION_CRAFT:
		_select_station(index)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_serve(cust_net_id: int = -1, station_index: int = -1) -> void:
	_mp_serve_sync = true
	_mp_applying = true
	var cust = _customer_by_net_id(cust_net_id) if cust_net_id >= 0 else null
	if cust != null:
		selected_customer = cust
		_highlight_tickets()
	if station_index >= 0 and station_index < STATION_COUNT:
		active_station = station_index
	## Force path: don't re-validate Build — initiator already had a perfect match.
	_begin_serve_at(
		cust if cust != null else selected_customer,
		station_index if station_index >= 0 else active_station,
		true
	)
	_mp_applying = false
	## Fly tween may still be running; leave authority stays host via _on_customer_left.


## any_peer (host-only callers): authority can drop on relay peers.
@rpc("any_peer", "call_local", "reliable")
func mp_spawn_customer(
	net_id: int,
	order: Array,
	cr: float,
	cg: float,
	cb: float,
	patience: float,
	lane: int,
	skin_idx: int = -1,
	face_style: int = -1
) -> void:
	if net_id >= 0 and _customer_by_net_id(net_id) != null:
		return
	_mp_applying = true
	_spawn_customer_local(order, Color(cr, cg, cb), patience, lane, net_id, skin_idx, face_style)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_end_day() -> void:
	_end_day()


@rpc("any_peer", "call_local", "reliable")
func mp_restart_day() -> void:
	## Both peers must start day 2 together — local Restart alone desyncs cook/build.
	_mp_applying = true
	_restart()
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()
		_mp_broadcast_customers()
		_mp_broadcast_grill()
		for si in STATION_COUNT:
			_mp_broadcast_station(si)


func _mp_append_patty_snap(
	p,
	slot: int,
	held_snap: bool,
	ids: Array,
	slots: Array,
	xs: Array,
	ys: Array,
	zs: Array,
	cooks: Array,
	flipped: Array,
	firsts: Array,
	smashs: Array,
	heatings: Array,
	heat_muls: Array,
	holds: Array,
	cheeses: Array,
	melts: Array,
	seasons: Array,
	helds: Array,
	perfects: Array
) -> void:
	var nid := int(p.get("net_id"))
	if nid < 0 or ids.has(nid):
		return
	ids.append(nid)
	slots.append(slot)
	xs.append(float(p.position.x))
	ys.append(float(p.position.y))
	zs.append(float(p.position.z))
	cooks.append(float(p.cook_time))
	flipped.append(bool(p.flipped_once))
	firsts.append(float(p.first_side_time))
	smashs.append(float(p.smash_bonus))
	heatings.append(bool(p.heating) and not held_snap)
	heat_muls.append(float(p.heat_mul))
	holds.append(float(p.warm_hold_time))
	cheeses.append(bool(p.has_cheese))
	melts.append(float(p.cheese_melt))
	seasons.append(float(p.seasoning))
	helds.append(held_snap)
	perfects.append(bool(p.perfect_flip))


func _mp_broadcast_grill() -> void:
	## Absolute cook-state snapshot so guests never drift on color / HOLD / flip.
	if not mp_enabled or not NetManager.is_host() or not NetManager.is_online():
		return
	if not playing:
		return
	var ids: Array = []
	var slots: Array = []
	var xs: Array = []
	var ys: Array = []
	var zs: Array = []
	var cooks: Array = []
	var flipped: Array = []
	var firsts: Array = []
	var smashs: Array = []
	var heatings: Array = []
	var heat_muls: Array = []
	var holds: Array = []
	var cheeses: Array = []
	var melts: Array = []
	var seasons: Array = []
	var helds: Array = []
	var perfects: Array = []
	for i in GRILL_SLOTS:
		var p = grill[i]
		if p == null or not is_instance_valid(p):
			continue
		_mp_append_patty_snap(
			p, i, bool(p.is_held),
			ids, slots, xs, ys, zs, cooks, flipped, firsts, smashs,
			heatings, heat_muls, holds, cheeses, melts, seasons, helds, perfects
		)
	## Spatula meat still needs cook/HOLD age even while scooped.
	if spatula_patty != null and is_instance_valid(spatula_patty):
		_mp_append_patty_snap(
			spatula_patty, int(spatula_patty.slot_index), true,
			ids, slots, xs, ys, zs, cooks, flipped, firsts, smashs,
			heatings, heat_muls, holds, cheeses, melts, seasons, helds, perfects
		)
	## Build-board patties need the same cook/cheese/season parity for pay grades.
	for st in stations:
		for bp in st.get("patties", []):
			if bp == null or not is_instance_valid(bp):
				continue
			_mp_append_patty_snap(
				bp, int(bp.slot_index), true,
				ids, slots, xs, ys, zs, cooks, flipped, firsts, smashs,
				heatings, heat_muls, holds, cheeses, melts, seasons, helds, perfects
			)
	mp_sync_grill.rpc(
		ids, slots, xs, ys, zs, cooks, flipped, firsts, smashs,
		heatings, heat_muls, holds, cheeses, melts, seasons, helds, perfects
	)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_sync_grill(
	ids: Array,
	slots: Array,
	xs: Array,
	ys: Array,
	zs: Array,
	cooks: Array,
	flipped: Array,
	firsts: Array,
	smashs: Array,
	heatings: Array,
	heat_muls: Array,
	holds: Array,
	cheeses: Array,
	melts: Array,
	seasons: Array,
	helds: Array,
	perfects: Array = []
) -> void:
	if NetManager.is_host():
		return
	if not playing:
		return
	_mp_applying = true
	var seen: Dictionary = {}
	for i in ids.size():
		var nid := int(ids[i])
		seen[nid] = true
		var slot := int(slots[i]) if i < slots.size() else 0
		var px := float(xs[i]) if i < xs.size() else 0.0
		var py := float(ys[i]) if i < ys.size() else (GRILL_SURFACE_Y + PATTY_SIT_Y)
		var pz := float(zs[i]) if i < zs.size() else 0.0
		var is_held_snap := bool(helds[i]) if i < helds.size() else false
		var p = _patty_by_net_id(nid)
		if p == null or not is_instance_valid(p):
			## Missing on guest — spawn into host slot (or first empty).
			var spawn_slot := slot
			if spawn_slot < 0 or spawn_slot >= GRILL_SLOTS or grill[spawn_slot] != null:
				spawn_slot = _first_empty_slot()
			if spawn_slot < 0:
				continue
			_spawn_patty_at(spawn_slot, Vector3(px, GRILL_SURFACE_Y, pz), nid)
			p = _patty_by_net_id(nid)
			if p == null:
				continue
		## Don't yank local scoop / drag ownership mid-gesture.
		var local_scoop := spatula_patty == p and (spatula_owner_id == 0 or spatula_owner_id == NetManager.my_id())
		var local_drag := dragging_patty == p and drag_owner_id == NetManager.my_id()
		var perfect_snap := bool(perfects[i]) if i < perfects.size() else bool(p.perfect_flip)
		if local_scoop or local_drag:
			## Still repair absolute cook / HOLD / cheese so day-2 desync heals.
			if p.has_method("apply_mp_state"):
				p.apply_mp_state(
					float(cooks[i]) if i < cooks.size() else float(p.cook_time),
					bool(flipped[i]) if i < flipped.size() else bool(p.flipped_once),
					float(firsts[i]) if i < firsts.size() else float(p.first_side_time),
					float(smashs[i]) if i < smashs.size() else float(p.smash_bonus),
					false,
					float(heat_muls[i]) if i < heat_muls.size() else float(p.heat_mul),
					float(holds[i]) if i < holds.size() else float(p.warm_hold_time),
					bool(cheeses[i]) if i < cheeses.size() else bool(p.has_cheese),
					float(melts[i]) if i < melts.size() else float(p.cheese_melt),
					float(seasons[i]) if i < seasons.size() else float(p.seasoning),
					true,
					p.position.x, p.position.y, p.position.z,
					int(p.slot_index),
					perfect_snap
				)
			p.mp_puppet = true
			continue
		## Seat into grill slot if host still has it on the flat-top.
		if not is_held_snap and slot >= 0 and slot < GRILL_SLOTS:
			var gidx: int = int(p.slot_index)
			if gidx >= 0 and gidx < grill.size() and grill[gidx] == p and gidx != slot:
				grill[gidx] = null
			if grill[slot] != null and grill[slot] != p:
				var usurped = grill[slot]
				if usurped != null and is_instance_valid(usurped) and usurped != spatula_patty and usurped != dragging_patty:
					var uid := int(usurped.get("net_id"))
					if uid < 0 or not seen.has(uid):
						grill[slot] = null
						usurped.queue_free()
			grill[slot] = p
			## Pull off Build if it drifted there alone.
			for st in stations:
				var arr: Array = st.get("patties", [])
				if arr.has(p):
					arr.erase(p)
					st["patties"] = arr
			p.visible = true
		if p.has_method("apply_mp_state"):
			p.apply_mp_state(
				float(cooks[i]) if i < cooks.size() else 0.0,
				bool(flipped[i]) if i < flipped.size() else false,
				float(firsts[i]) if i < firsts.size() else 0.0,
				float(smashs[i]) if i < smashs.size() else 0.0,
				bool(heatings[i]) if i < heatings.size() else false,
				float(heat_muls[i]) if i < heat_muls.size() else 1.0,
				float(holds[i]) if i < holds.size() else 0.0,
				bool(cheeses[i]) if i < cheeses.size() else false,
				float(melts[i]) if i < melts.size() else 0.0,
				float(seasons[i]) if i < seasons.size() else 0.0,
				is_held_snap,
				px, py, pz,
				slot,
				perfect_snap
			)
		## Build / scooped meat stays hidden until station refresh seats it.
		if is_held_snap:
			var on_build := false
			for st_chk in stations:
				if st_chk.get("patties", []).has(p):
					on_build = true
					break
			if on_build or p == spatula_patty:
				p.visible = p == spatula_patty
		p.mp_puppet = true
	## Cull grill ghosts the host no longer has (keep Build / local scoop).
	for gi in GRILL_SLOTS:
		var gp = grill[gi]
		if gp == null or not is_instance_valid(gp):
			continue
		var gnid := int(gp.get("net_id"))
		if gnid >= 0 and seen.has(gnid):
			continue
		if gp == spatula_patty or gp == dragging_patty or gp == flicking_patty:
			continue
		var on_build := false
		for st2 in stations:
			if st2.get("patties", []).has(gp):
				on_build = true
				break
		if on_build:
			grill[gi] = null
			continue
		grill[gi] = null
		gp.queue_free()
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_trash_patty(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	_mp_applying = true
	_mp_clear_held_net(net_id)
	if spatula_patty == p:
		_trash_spatula_patty_local()
	else:
		_trash_single_grill_patty_local(p)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_place_spatula(net_id: int, idx: int, x: float, z: float) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	_mp_applying = true
	_place_spatula_on_grill_local(idx, Vector3(x, GRILL_SURFACE_Y, z), p)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_place_warmer(net_id: int, idx: int, x: float, z: float) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null:
		return
	_mp_applying = true
	_place_spatula_on_warmer_local(idx, Vector3(x, GRILL_SURFACE_Y, z), p)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_commit_patty_build(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null or not is_instance_valid(p):
		return
	if not p.flipped_once or not p.can_scoop():
		return
	_mp_applying = true
	var gidx: int = int(p.slot_index)
	if gidx >= 0 and gidx < grill.size() and grill[gidx] == p:
		grill[gidx] = null
	_mp_release_scoop_if(p)
	if dragging_patty == p:
		dragging_patty = null
		drag_owner_id = 0
	p.is_held = false
	p.heating = false
	_leave_grill_residue(gidx, p, false)
	_commit_patty_to_build(p)
	_mp_applying = false


func _mp_send_cat_sync() -> void:
	if window_cat == null or not is_instance_valid(window_cat):
		return
	if not window_cat.has_method("get_mp_sync"):
		return
	var d: Dictionary = window_cat.get_mp_sync()
	mp_cat_sync.rpc(
		str(d.get("state", "hidden")),
		float(d.get("timer", 0.0)),
		float(d.get("x", 0.0)),
		float(d.get("y", 0.0)),
		float(d.get("z", 0.0)),
		float(d.get("yaw", 180.0)),
		bool(d.get("vis", false)),
		float(d.get("fat", 0.0)),
		float(d.get("giant", 0.0)),
		float(d.get("treat", 0.0)),
		float(d.get("eat_w", 0.0)),
		float(d.get("bob", 0.0))
	)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_cat_sync(
	state: String,
	timer: float,
	x: float,
	y: float,
	z: float,
	yaw: float,
	vis: bool,
	fat: float,
	giant: float,
	treat: float,
	eat_w: float,
	bob: float
) -> void:
	if NetManager.is_host():
		return
	if window_cat == null or not is_instance_valid(window_cat):
		return
	if not window_cat.has_method("apply_mp_sync"):
		return
	window_cat.apply_mp_sync({
		"state": state,
		"timer": timer,
		"x": x,
		"y": y,
		"z": z,
		"yaw": yaw,
		"vis": vis,
		"fat": fat,
		"giant": giant,
		"treat": treat,
		"eat_w": eat_w,
		"bob": bob,
	})


@rpc("any_peer", "call_local", "reliable")
func mp_cat_pet() -> void:
	_mp_applying = true
	if window_cat != null and is_instance_valid(window_cat):
		window_cat.pet(true)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_cat_feed(kind: String, patty_net_id: int) -> void:
	if not _cat_accepts_food(kind):
		return
	_mp_applying = true
	if kind == "patty":
		var p = _patty_by_net_id(patty_net_id) if patty_net_id >= 0 else null
		if p == null and spatula_patty != null and is_instance_valid(spatula_patty):
			p = spatula_patty
		if p != null:
			if spatula_patty == p:
				spatula_patty = null
				spatula_owner_id = 0
				spatula_from_build = false
				spatula_lmb_held = false
				spatula_vel_screen = Vector2.ZERO
				spatula_carry_travel = 0.0
				_refresh_spatula_ui()
			var gidx: int = int(p.slot_index)
			if gidx >= 0 and gidx < grill.size() and grill[gidx] == p:
				grill[gidx] = null
			if flicking_patty == p:
				flicking_patty = null
			if dragging_patty == p:
				dragging_patty = null
			if is_instance_valid(p):
				p.queue_free()
		if window_cat != null and is_instance_valid(window_cat):
			window_cat.feed("patty", true)
		_flash("Cat stole the burger! ♥", Color("FF8A80"))
	else:
		_feed_window_cat_ingredient_local(kind)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_steal_held(net_id: int) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null or not is_instance_valid(p):
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = NetManager.my_id()
	_mp_applying = true
	if flicking_patty == p:
		flicking_patty = null
	if dragging_patty == p:
		dragging_patty = null
		drag_owner_id = 0
	var gidx: int = int(p.slot_index)
	if gidx >= 0 and gidx < grill.size() and grill[gidx] == p:
		grill[gidx] = null
	## Victim loses their scoop if this was theirs.
	if spatula_patty == p:
		spatula_patty = null
		spatula_owner_id = 0
		spatula_from_build = false
		spatula_lmb_held = false
		spatula_vel_screen = Vector2.ZERO
		spatula_carry_travel = 0.0
		_refresh_spatula_ui()
	_mp_clear_held_net(net_id)
	p.is_held = true
	p.heating = false
	p.visible = true
	_mp_mark_held(sid, p)
	if sid == NetManager.my_id():
		spatula_patty = p
		spatula_owner_id = sid
		spatula_from_build = false
		spatula_lmb_held = false
		spatula_vel_screen = Vector2.ZERO
		spatula_carry_travel = 0.0
		spatula_last_mouse = get_viewport().get_mouse_position()
		_refresh_spatula_ui()
		_flash("Yoink! Stole the scoop", Color("FF8A80"))
	_mp_applying = false


func _mp_broadcast_economy() -> void:
	if not mp_enabled or not NetManager.is_host() or not NetManager.is_online():
		return
	var stock_ids: Array = []
	var stock_vals: Array = []
	var fresh_vals: Array = []
	for id in SUPPLY_IDS:
		stock_ids.append(str(id))
		stock_vals.append(int(supply_stock.get(id, 0)))
		fresh_vals.append(float(supply_fresh.get(id, 0.0)))
	mp_sync_economy.rpc(
		money,
		combo,
		day_time,
		day,
		total_served,
		perfect_serves,
		social_rating_sum,
		social_review_count,
		stock_ids,
		stock_vals,
		fresh_vals
	)


@rpc("any_peer", "call_remote", "reliable")
func mp_sync_economy(
	m: float,
	cmb: int,
	dtime: float,
	d: int,
	served: int,
	perfect: int,
	rating_sum: float,
	rating_count: int,
	stock_ids: Array,
	stock_vals: Array,
	fresh_vals: Array
) -> void:
	## Guest applies host world economy as absolute truth.
	if NetManager.is_host():
		return
	money = m
	combo = cmb
	day_time = dtime
	day = d
	total_served = served
	perfect_serves = perfect
	social_rating_sum = rating_sum
	social_review_count = rating_count
	for i in stock_ids.size():
		var id := str(stock_ids[i])
		var stock := int(stock_vals[i]) if i < stock_vals.size() else 0
		var fresh := float(fresh_vals[i]) if i < fresh_vals.size() else 0.0
		supply_stock[id] = stock
		supply_fresh[id] = fresh
	_update_hud()
	_refresh_phone_ui()


@rpc("any_peer", "call_local", "reliable")
func mp_buy_supply(id: String) -> void:
	_mp_applying = true
	_buy_supply_local(id)
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()


@rpc("any_peer", "call_local", "reliable")
func mp_customer_leave(net_id: int, angry: bool) -> void:
	_mp_applying = true
	var c = _customer_by_net_id(net_id)
	if c != null and is_instance_valid(c):
		## Ensure walk-off anim if they were still waiting (guest ticket clear).
		if bool(c.get("is_waiting")) and not bool(c.get("is_leaving")):
			if angry and c.has_method("leave_mad"):
				c.leave_mad()
			elif (not angry) and c.has_method("leave_happy"):
				c.leave_happy()
		_customer_leave_apply(c, angry)
	elif angry:
		combo = 0
		_maybe_record_social_review(1.0, "angry")
		_spend(2.0, "Customer left angry! -$2.00", Color("EF5350"))
	_mp_applying = false
	_mp_serve_sync = false
	if NetManager.is_host():
		_mp_broadcast_economy()


@rpc("any_peer", "call_remote", "reliable")
func mp_social_review(stars: float, who: String, text: String, pic_png: PackedByteArray = PackedByteArray()) -> void:
	## Guest mirrors a host feed post (chance already rolled on host).
	if NetManager.is_host():
		return
	var pic: Texture2D = null
	if pic_png != null and pic_png.size() > 32:
		var img := Image.new()
		if img.load_png_from_buffer(pic_png) == OK:
			pic = ImageTexture.create_from_image(img)
	_apply_social_review(stars, who, text, pic)


func _mp_broadcast_customers() -> void:
	if not mp_enabled or not NetManager.is_host() or not NetManager.is_online():
		return
	var ids: Array = []
	var pats: Array = []
	var xs: Array = []
	var zs: Array = []
	var waits: Array = []
	var leaves: Array = []
	var clocks: Array = []
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		var nid := _customer_net_id(c)
		if nid < 0:
			continue
		ids.append(nid)
		pats.append(float(c.patience))
		xs.append(float(c.global_position.x))
		zs.append(float(c.global_position.z))
		waits.append(bool(c.is_waiting))
		leaves.append(bool(c.is_leaving))
		clocks.append(float(c.get("order_elapsed_sec")) if "order_elapsed_sec" in c else 0.0)
	mp_sync_customers.rpc(ids, pats, xs, zs, waits, leaves, clocks)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_sync_customers(
	ids: Array,
	pats: Array,
	xs: Array,
	zs: Array,
	waits: Array,
	leaves: Array,
	clocks: Array
) -> void:
	if NetManager.is_host():
		return
	var seen: Dictionary = {}
	for i in ids.size():
		var nid := int(ids[i])
		seen[nid] = true
		var c = _customer_by_net_id(nid)
		if c == null or not is_instance_valid(c):
			continue
		c.mp_host_driven = true
		if i < pats.size():
			c.patience = float(pats[i])
			if c.has_method("_refresh_patience_bar"):
				c._refresh_patience_bar()
		if i < clocks.size() and "order_elapsed_sec" in c:
			c.order_elapsed_sec = float(clocks[i])
		if i < xs.size():
			c.global_position.x = float(xs[i])
			c.target_x = float(xs[i])
		if i < zs.size():
			c.global_position.z = float(zs[i])
		var host_waiting := bool(waits[i]) if i < waits.size() else false
		var host_leaving := bool(leaves[i]) if i < leaves.size() else false
		## Host already dismissed them — clear our ticket even if serve FX lagged.
		if host_leaving:
			if not bool(c.is_leaving) and c.has_method("leave_happy"):
				c.leave_happy()
			_customer_leave_apply(c, false)
			continue
		## Host ticket is up — pin ours if arrival timing drifted.
		if host_waiting:
			if not bool(c.is_waiting):
				c.is_waiting = true
				c.rotation_degrees.y = CustomerScript.FACE_TRUCK_YAW
			if not tickets.has(c):
				_create_ticket(c)
	## Drop ghosts the host no longer has.
	for c in customers.duplicate():
		if c == null or not is_instance_valid(c):
			continue
		var nid2 := _customer_net_id(c)
		if nid2 >= 0 and not seen.has(nid2):
			if not bool(c.get("is_leaving")) and c.has_method("leave_happy"):
				c.leave_happy()
			_customer_leave_apply(c, false)


@rpc("any_peer", "call_local", "reliable")
func mp_select_customer(net_id: int) -> void:
	var c = _customer_by_net_id(net_id)
	if c == null:
		return
	_mp_applying = true
	_select_ticket_local(c)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_bacon_customer(net_id: int) -> void:
	var c = _customer_by_net_id(net_id)
	if c == null or not is_instance_valid(c):
		return
	_mp_applying = true
	if c.has_method("feed_bacon_snack"):
		if bool(c.feed_bacon_snack(BACON_PATIENCE_RESTORE)):
			_mp_spend_ingredient("bacon")
			if game_audio:
				game_audio.play_ingredient("bacon")
			var pct := int(round(BACON_PATIENCE_RESTORE * 100.0))
			_flash("Bacon snack! +%d%% patience" % pct, Color("FFAB91"))
		else:
			_flash("They're not hungry for more bacon", Color("FFCC80"))
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()
		_mp_broadcast_customers()


@rpc("any_peer", "call_local", "reliable")
func mp_trash_build_layer(station_index: int, layer_index: int) -> void:
	_mp_applying = true
	_trash_build_layer_local(station_index, layer_index)
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()


@rpc("any_peer", "call_local", "reliable")
func mp_trash_station_patty(station_index: int, from_index: int) -> void:
	_mp_applying = true
	var patty = _extract_station_patty(station_index, from_index)
	if patty != null and is_instance_valid(patty):
		patty.queue_free()
		if game_audio and game_audio.has_method("play_trash"):
			game_audio.play_trash()
		_spend(COST_DROP_BURGER, "Trashed a burger — %s" % _format_money(COST_DROP_BURGER), Color("FFAB91"))
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_economy()
		_mp_broadcast_station(station_index)


@rpc("any_peer", "call_local", "reliable")
func mp_clear_station(station_index: int) -> void:
	_mp_applying = true
	_clear_station(station_index)
	_flash("%s cleared" % _station_label(station_index), Color("B0BEC5"))
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_reorder_station(station_index: int, from_index: int, insert_at: int) -> void:
	_mp_applying = true
	_reorder_station_item_local(station_index, from_index, insert_at)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_season_patty(net_id: int, amount: float) -> void:
	var p = _patty_by_net_id(net_id)
	if p == null or not is_instance_valid(p):
		return
	_mp_applying = true
	p.apply_seasoning(amount)
	_mp_applying = false


func _mp_broadcast_station(station_index: int) -> void:
	## Host pushes absolute Build stack so toppings never diverge after stock races.
	if not mp_enabled or not NetManager.is_host() or not NetManager.is_online():
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	if not playing:
		return
	var st: Dictionary = stations[station_index]
	var item_ids: Array = []
	for it in st["items"]:
		item_ids.append(str(it))
	var patty_ids: Array = []
	for p in st["patties"]:
		if p != null and is_instance_valid(p) and int(p.get("net_id")) >= 0:
			patty_ids.append(int(p.net_id))
		else:
			patty_ids.append(-1)
	mp_sync_station.rpc(
		station_index,
		item_ids,
		patty_ids,
		bool(st.get("fresh_active", false)),
		float(st.get("freshness", FRESHNESS_MAX)),
		bool(st.get("spoiled", false))
	)


@rpc("any_peer", "call_remote", "reliable")
func mp_sync_station(
	station_index: int,
	item_ids: Array,
	patty_net_ids: Array,
	fresh_active: bool = false,
	freshness: float = -1.0,
	spoiled: bool = false
) -> void:
	if NetManager.is_host():
		return
	if station_index < 0 or station_index >= STATION_COUNT:
		return
	_mp_applying = true
	var st: Dictionary = stations[station_index]
	var new_patties: Array = []
	for nid_v in patty_net_ids:
		var nid := int(nid_v)
		var p = _patty_by_net_id(nid) if nid >= 0 else null
		if p == null or not is_instance_valid(p):
			continue
		## Seat on Build for display — don't free extras; place/scoop/serve RPCs own lifetime.
		if not grill.has(p) and p != spatula_patty and p != dragging_patty and p != flicking_patty:
			_mp_release_scoop_if(p)
			p.is_held = true
			p.heating = false
			p.visible = false
			p.rotation_degrees = Vector3.ZERO
			var gidx: int = int(p.slot_index)
			if gidx >= 0 and gidx < grill.size() and grill[gidx] == p:
				grill[gidx] = null
		if not new_patties.has(p):
			new_patties.append(p)
	st["patties"] = new_patties
	var items: Array = []
	for id_v in item_ids:
		items.append(str(id_v))
	st["items"] = items
	st["selected_layer"] = -1
	if items.is_empty():
		_reset_station_freshness(station_index)
	else:
		st["fresh_active"] = fresh_active if freshness >= 0.0 else true
		if freshness >= 0.0:
			st["freshness"] = freshness
		elif not bool(st.get("fresh_active", false)):
			st["freshness"] = FRESHNESS_MAX
		st["spoiled"] = spoiled
	_sync_station_cheese_items(station_index)
	_refresh_station(station_index)
	_refresh_freshness_label(station_index)
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_pickup_build_patty(net_id: int, station_index: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = NetManager.my_id()
	_mp_applying = true
	var patty = _extract_station_patty_by_net_id(station_index, net_id)
	if patty == null:
		patty = _patty_by_net_id(net_id)
	if patty == null or not is_instance_valid(patty):
		_mp_applying = false
		return
	patty.is_held = true
	patty.heating = false
	patty.visible = true
	patty.rotation_degrees = Vector3.ZERO
	if patty.get_parent() == null and patties_root != null:
		patties_root.add_child(patty)
	_mp_mark_held(sid, patty)
	if sid == NetManager.my_id():
		spatula_patty = patty
		spatula_owner_id = sid
		spatula_from_build = true
		spatula_lmb_held = true
		spatula_last_mouse = get_viewport().get_mouse_position()
		spatula_vel_screen = Vector2.ZERO
		spatula_carry_travel = 0.0
		_refresh_spatula_ui()
		_update_held_spatula_patty(0.016)
		if game_audio:
			game_audio.play_scoop()
		_flash("Drag to grill & release · flick right to throw · Build to put back", Color("90CAF9"))
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_station(station_index)


@rpc("any_peer", "call_local", "reliable")
func mp_return_build_to_grill(net_id: int, station_index: int, x: float, z: float) -> void:
	_mp_applying = true
	var world_pos := Vector3(x, GRILL_SURFACE_Y, z)
	var patty = _extract_station_patty_by_net_id(station_index, net_id)
	if patty == null:
		patty = _patty_by_net_id(net_id)
	if patty == null or not is_instance_valid(patty):
		_mp_applying = false
		return
	_mp_release_scoop_if(patty)
	if _is_in_warmer_zone(world_pos):
		var widx := _first_empty_slot()
		if widx < 0:
			_commit_patty_to_build(patty)
			_mp_applying = false
			return
		_place_spatula_on_warmer_local(widx, world_pos, patty)
	else:
		var place_pos := _find_closest_patty_place(world_pos)
		if place_pos == Vector3.ZERO:
			_commit_patty_to_build(patty)
			_mp_applying = false
			return
		var gidx := _first_empty_slot()
		if gidx < 0:
			_commit_patty_to_build(patty)
			_mp_applying = false
			return
		_place_extracted_patty_on_grill(patty, gidx, place_pos)
	_mp_applying = false
	if NetManager.is_host():
		_mp_broadcast_station(station_index)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_oil_slick(x: float, z: float, radius: float) -> void:
	_spawn_oil_slick_local(Vector3(x, GRILL_SURFACE_Y + OIL_SIT_Y, z), radius)


@rpc("any_peer", "call_local", "reliable")
func mp_grill_fire_start(x: float, z: float) -> void:
	_mp_applying = true
	_start_grill_fire_local(Vector3(x, GRILL_SURFACE_Y, z))
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_grill_fire_end() -> void:
	_mp_applying = true
	_extinguish_grill_fire_local()
	_mp_applying = false


@rpc("any_peer", "call_local", "reliable")
func mp_residue_leave(slot: int, x: float, z: float, announce: bool) -> void:
	_mp_applying = true
	_leave_grill_residue_local(slot, Vector3(x, GRILL_SURFACE_Y + 0.028, z), announce)
	_mp_applying = false


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_residue_amt(slot: int, amt: float) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	grill_residue[slot] = clampf(amt, 0.0, 1.0)
	_refresh_residue_visual(slot)


@rpc("any_peer", "call_remote", "unreliable")
func mp_residue_chip(slot: int, dx: float, dz: float) -> void:
	if slot < 0 or slot >= GRILL_SLOTS:
		return
	_scrape_residue_hit(slot, Vector2(dx, dz))


@rpc("any_peer", "call_local", "reliable")
func mp_residue_clean(slot: int) -> void:
	_mp_applying = true
	_scrape_finish_clean_local(slot)
	_mp_applying = false


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_ext_spray(spraying: bool, ax: float, az: float, on_customer: bool) -> void:
	_ensure_ext_powder()
	if ext_powder:
		ext_powder.emitting = spraying
	if spraying and not on_customer:
		var on_grill := absf(ax - GRILL_CENTER_X) <= GRILL_WIDTH * 0.55 \
			and absf(az - GRILL_SURFACE_Z) <= GRILL_DEPTH * 0.55
		if on_grill:
			_spawn_ext_powder_blob(Vector3(ax, GRILL_SURFACE_Y, az))
		if grill_on_fire and _is_in_fire_zone(Vector3(ax, GRILL_SURFACE_Y, az)):
			if not _fire_killed_by_powder:
				_fire_killed_by_powder = true
				_set_fire_fx_emitting(false)
			fire_health = maxf(0.0, fire_health - 0.05)
			if fire_health <= 0.0:
				_extinguish_grill_fire_local()


@rpc("any_peer", "call_remote", "reliable")
func mp_ext_customer(net_id: int, zone: String, first_hit: bool = true) -> void:
	## Remote peers only — sprayer already applied powder locally.
	var c = _customer_by_net_id(net_id)
	if c == null:
		return
	_mp_applying = true
	if c.has_method("receive_ext_powder"):
		c.call("receive_ext_powder", zone)
	if first_hit:
		var msg := "Customer: \"Agh! My face!!\"" if zone == "face" else "Customer: \"What the heck?!\""
		_flash(msg, Color("EF9A9A"))
	_mp_applying = false
	## Guest sprayed — host owns ticket / fine / 1★ spray review (must not be under _mp_applying).
	if first_hit and NetManager.is_host() and c != null and is_instance_valid(c):
		_on_customer_left(c, true)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func mp_ext_customer_push(net_id: int, zone: String, delta: float) -> void:
	var c = _customer_by_net_id(net_id)
	if c == null:
		return
	if c.has_method("apply_ext_spray_push"):
		c.call("apply_ext_spray_push", clampf(delta, 0.0, 0.05), zone)


@rpc("any_peer", "call_local", "reliable")
func mp_glock_fire(ix: float, iy: float, iz: float, cust_id: int, do_hit: bool, hostile: bool) -> void:
	_mp_applying = true
	_apply_glock_shot(Vector3(ix, iy, iz), cust_id, do_hit, hostile)
	_mp_applying = false
