## Stylized Kenney toon customers (CC0) with mood reactions + patience bar.
extends Node3D

const GameDataScript := preload("res://scripts/game_data.gd")
const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const CHAR_SCENE_PATH := "res://assets/characters/Model/characterMedium.fbx"
const IDLE_SCENE_PATH := "res://assets/characters/Animations/idle.fbx"
const RUN_SCENE_PATH := "res://assets/characters/Animations/run.fbx"
const DISGUISE_MUSTACHE_TEX := "res://IMAGES/MUSTACHE.png"
const JIN_SKIN_PATH := "res://models/characters/Skins/JIN.png"
const JIMIN_SKIN_PATH := "res://models/characters/Skins/JIMIN.png"
const V_SKIN_PATH := "res://models/characters/Skins/v.png"
const JHOPE_SKIN_PATH := "res://models/characters/Skins/JHOPE.png"
const JUNG_SKIN_PATH := "res://models/characters/Skins/JUNG.png"
const RM_SKIN_PATH := "res://models/characters/Skins/rm.png"
const SUGA_SKIN_PATH := "res://models/characters/Skins/SUGA.png"
## Stylized Kenney toon skins only — skip photoreal human* (blurry/weird on this mesh).
const CHAR_SKINS: Array[String] = [
	"res://assets/characters/Skins/skaterMaleA.png",
	"res://models/characters/Skins/skaterFemaleA copy.png",
	"res://assets/characters/Skins/criminalMaleA.png",
	"res://assets/characters/Skins/cyborgFemaleA.png",
	"res://models/characters/Skins/criminalMaleA copy 2.png",
	"res://models/characters/Skins/cyborgFemaleA.png",
	"res://models/characters/Skins/skaterMaleA copy 2.png",
]
const JIN_SKIN_IDX := 7
const JIMIN_SKIN_IDX := 8
const V_SKIN_IDX := 9
const JHOPE_SKIN_IDX := 10
const JUNG_SKIN_IDX := 11
const RM_SKIN_IDX := 12
const SUGA_SKIN_IDX := 13
const BTS_SKIN_IDXS: Array[int] = []
const JIN_FACTS: Array[String] = [
	"Jin fact: My real name is Kim Seok-jin.",
	"Jin fact: I was born on December 4, 1992.",
	"Jin fact: I am the oldest member of BTS.",
	"Jin fact: I debuted with BTS on June 13, 2013.",
	"Jin fact: I am part of the BTS vocal line.",
	"Jin fact: I studied Film Studies at Konkuk University.",
	"Jin fact: I graduated from Konkuk University in 2017.",
	"Jin fact: Big Hit scouted me while I was studying acting.",
	"Jin fact: Awake was my solo song on Wings.",
	"Jin fact: Epiphany was my solo song for Love Yourself: Answer.",
	"Jin fact: Moon was my solo song on Map of the Soul: 7.",
	"Jin fact: Tonight was my first independent song.",
	"Jin fact: Abyss was released in 2020.",
	"Jin fact: Yours was my Jirisan drama OST.",
	"Jin fact: Super Tuna started as a birthday gift song.",
	"Jin fact: The Astronaut was my first official solo single.",
	"Jin fact: The Astronaut was released in October 2022.",
	"Jin fact: I co-wrote The Astronaut with Coldplay.",
	"Jin fact: I performed The Astronaut with Coldplay in Buenos Aires.",
	"Jin fact: I enlisted for military service in December 2022.",
	"Jin fact: I was discharged from military service in June 2024.",
	"Jin fact: I carried the Paris 2024 Olympic torch.",
	"Jin fact: Happy was my first solo album.",
	"Jin fact: Happy was released in November 2024.",
	"Jin fact: Happy has six tracks.",
	"Jin fact: Run Jin is my solo variety show.",
	"Jin fact: I was a host on Korean music shows.",
	"Jin fact: BTS received the Hwagwan Order of Cultural Merit in 2018.",
	"Jin fact: My BT21 character is RJ.",
	"Jin fact: RJ loves cooking and eating.",
]
const JIMIN_FACTS: Array[String] = [
	"Jimin fact: My real name is Park Ji-min.",
	"Jimin fact: I was born on October 13, 1995.",
	"Jimin fact: I was born in Busan, South Korea.",
	"Jimin fact: I debuted with BTS on June 13, 2013.",
	"Jimin fact: I am a vocalist and dancer in BTS.",
	"Jimin fact: I studied contemporary dance before debut.",
	"Jimin fact: I trained at Just Dance Academy in Busan.",
	"Jimin fact: I attended Busan High School of Arts.",
	"Jimin fact: I transferred to Korean Arts High School.",
	"Jimin fact: I graduated from Korean Arts High School in 2014.",
	"Jimin fact: I graduated from Global Cyber University.",
	"Jimin fact: I majored in Broadcasting and Entertainment.",
	"Jimin fact: I received Global Cyber University's President's Award.",
	"Jimin fact: Lie was my solo song on Wings.",
	"Jimin fact: Serendipity was my solo intro on Love Yourself: Her.",
	"Jimin fact: Filter was my solo song on Map of the Soul: 7.",
	"Jimin fact: I co-wrote Friends for Map of the Soul: 7.",
	"Jimin fact: Promise was my first credited solo song.",
	"Jimin fact: Promise came out in December 2018.",
	"Jimin fact: Christmas Love came out in December 2020.",
	"Jimin fact: With You was my Our Blues drama OST duet.",
	"Jimin fact: I featured on Taeyang's Vibe in 2023.",
	"Jimin fact: FACE was my first solo album.",
	"Jimin fact: FACE was released in March 2023.",
	"Jimin fact: Like Crazy reached No. 1 on the Billboard Hot 100.",
	"Jimin fact: I released Closer Than This for fans in December 2023.",
	"Jimin fact: MUSE was my second solo album.",
	"Jimin fact: MUSE was released in July 2024.",
	"Jimin fact: MUSE has seven tracks.",
	"Jimin fact: My BT21 character is Chimmy.",
]
## Shrink so face + torso sit in the service window (not cropped by the lintel).
const CHAR_SCALE := 0.552 ## ~15% larger than 0.48
## Sidewalk stand height — feet on pavement (was floating ~1 ft at 0.22).
const STAND_Y := -0.02
## Stay nearer the camera than the street matte (game.gd STREET_MATTE_BASE_Z ≈ 11.5).
const MATTE_FRONT_Z_MAX := 9.8
const WAIT_Z := 2.25
const ANTSY_WAIT_RATIO_START := 0.34
const ANTSY_HANDS_UP_RATIO_START := 0.16
const ANTSY_MIN_WAIT_SEC := 12.0
const ANTSY_HANDS_UP_MIN_WAIT_SEC := 24.0
## Impatient wawa mutter after the patience bar drops below half.
const GROBBLE_PATIENCE_RATIO := 0.5
const GROBBLE_INTERVAL_SEC := 10.0
const GROBBLE_SHAKE_SEC := 3.0
const GROBBLE_SHAKE_AMP := 0.085
const GROBBLE_SHAKE_RATE := 0.28 ## Slow impatient sway (angry shake is ~1.0).
## Compact patience chip above the toon head (inside the window opening).
## Tuned for the service-window camera — higher world Y reads lower on screen.
const HEAD_TOP_Y := 0.95
const BAR_ABOVE_HEAD := 0.14
const BAR_Y := HEAD_TOP_Y + BAR_ABOVE_HEAD
const BAR_W := 0.42
const BAR_H := 0.038
const LEAVE_TURN_SEC := 0.38
const ARRIVE_TURN_SEC := 0.42
## Knock-back tumble after a Glock hit, then settle and despawn.
const RAGDOLL_ACTIVE_SEC := 9.5
const RAGDOLL_TWIST_SEC := 2.2 ## Free spin window before settling onto their back.
const RAGDOLL_DESPAWN_SEC := 5.5 ## Extra time lying around after the active flop.
const LEAVE_FADE_SEC := 1.2
## Yaw: 180 faces the cook/truck (−Z); 0 walks away down the street (+Z).
## Kenney mesh noses along +Z, so these match travel on ±X.
const FACE_TRUCK_YAW := 180.0
const FACE_AWAY_YAW := 0.0
## Approach along the sidewalk — face travel, then turn to truck.
const WALK_PLUS_X_YAW := 90.0
const WALK_MINUS_X_YAW := -90.0
## Wait slots: front of line near window center; new customers queue screen-right.
## (world +X = screen-left, −X = screen-right)
const LANE_X: Array[float] = [-0.35, -1.1, -1.85, -2.6]

signal arrived(customer: Node3D)
signal patience_expired(customer: Node3D)
signal served(customer: Node3D, payout: int)

var order: Array[String] = []
var body_color: Color = Color.WHITE
var skin_idx: int = 0
var face_style: int = 0
var patience_max: float = 45.0
var patience: float = 45.0
var target_x: float = 0.0
var lane: int = 0
var is_waiting: bool = false
var is_leaving: bool = false
var order_value: int = 8
var queue_timer_active: bool = true
## Serve-speed clock — starts when the order ticket appears (not when meat is ready).
var order_elapsed_sec: float = 0.0
var _order_clock_on: bool = false
const SERVE_WOW_SEC := 3.0
const SERVE_PERFECT_SEC := 6.0
const SERVE_GREAT_SEC := 10.0
const SERVE_GOOD_SEC := 30.0
const SERVE_NOT_GOOD_SEC := 45.0
var speech: String = ""
var last_tip: int = 0
var last_base_pay: int = 0
## Chat at the window — quiet customers skip the popup.
var personality: String = "quiet" ## quiet | chatty | annoying
var chatter: String = ""
var dialogue_open: bool = false
var tip_mood_mult: float = 1.0
## Incomplete serve — customer noticed missing items.
var complaint_active: bool = false
var pending_missing: Array = []
var dialogue_mode: String = "chat" ## chat | complaint

var _body: Node3D
var _face: MeshInstance3D ## unused with 3D toon models (kept for old helpers)
var _face_mat: StandardMaterial3D
var _char_meshes: Array = [] ## MeshInstance3D skins we tint by mood
var _anim_player: AnimationPlayer = null
var _anim_state: String = "" ## idle | walk
var _bubble: Label3D
var _bubble_bg: MeshInstance3D
var _bar_root: Node3D
var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D
var _review_stars: Label3D = null
var _review_stars_tween: Tween = null
var _treat_hearts: Label3D = null
var _treat_hearts_tween: Tween = null

var _bounce: float = 0.0
var _bobble_phase: float = 0.0
var _antsy_phase: float = 0.0
var _antsy_active: bool = false
var _antsy_hands_up_active: bool = false
var _grobble_cd: float = 0.0
var _mood: String = "happy"
var _shake_time: float = 0.0
var _shake_amp: float = 0.0
var _shake_rate: float = 1.0
var _shake_tilt: float = 35.0
var _expr_t: float = 0.0
var _leave_spin: float = 0.0
var _leave_turned: bool = false
var _leave_yaw_from: float = FACE_TRUCK_YAW
var _leave_fade_t: float = 0.0
var _leave_fade_active: bool = false
var _leave_fade_wait_for_turn: bool = false
var _leave_fade_alpha: float = 1.0
var _arrive_turning: bool = false
var _arrive_turn_t: float = 0.0
var _arrive_yaw_from: float = WALK_PLUS_X_YAW
var _base_body_y: float = 0.0
var _home_x: float = 0.0
var _face_style: int = 0 ## slight variety per customer
var _skin_path: String = ""
var is_terrorist: bool = false
## Full-size window cat in a fake mustache — orders a triple, never pays.
var is_disguise_cat: bool = false
var is_jin_guest: bool = false
var is_jimin_guest: bool = false
var is_bts_guest: bool = false
var _mustache_root: Node3D = null
var _disguise_hat_root: Node3D = null
var _disguise_cat_mesh: Node3D = null
## Match the fattest window cat: width chonk first, then 2× overall growth.
const DISGUISE_CAT_SCALE_X := 14.35
const DISGUISE_CAT_SCALE_Y := 7.05
const DISGUISE_CAT_SCALE_Z := 12.35
## Mid-body FBX pivot — lift so paws sit on the sidewalk and head fills the window.
const DISGUISE_CAT_MESH_Y := 0.47
const DISGUISE_CAT_WAIT_Z_OFFSET := 0.15
## Window-cat mouth sits at (0, 0.34, 0.22) with MESH_SCALE 3.35 — scale with us.
const _WINDOW_CAT_MESH_SCALE := 3.35
const _WINDOW_CAT_MOUTH := Vector3(0.0, 0.34, 0.22)
## Fire-extinguisher powder stuck to the toon (white spheres that build up).
var _powder_hit: bool = false
var _powdering: bool = false ## Standing still while powder coats them.
var _powder_stand_t: float = 0.0
var _powder_drip_cool: float = 0.0
var _powder_face_build: float = 0.0 ## 0–1 — spray buildup on the face
var _powder_panic_t: float = 0.0
var _powder_knock_x: float = 0.0
var _powder_knock_z: float = 0.0
const POWDER_STAND_SEC := 2.6
var _powder_blobs: Array = [] ## {mesh, mat, life, max_life, start_scale, zone}
var _panic_bones: Dictionary = {} ## Kenney arm bone indices for hands-up pose
var _powder_face_mount: BoneAttachment3D = null
var _powder_body_mount: BoneAttachment3D = null
## Catching / eating a served burger in the window.
var _eating: bool = false
var _eat_lean_x: float = 0.0
## Glock hit — blood + limp skeleton flop (not a spinning tornado).
var is_ragdoll: bool = false
var _ragdoll_vel: Vector3 = Vector3.ZERO
var _ragdoll_ang: Vector3 = Vector3.ZERO
var _ragdoll_t: float = 0.0
var _ragdoll_lie: float = 0.0 ## 0 upright → 1 flat on back
var _ragdoll_bone_phase: Dictionary = {} ## Per-limb wobble seeds for noodle flop.
var _skeleton: Skeleton3D = null
var _blood_bursts: Array = [] ## GPUParticles3D to free later
static var _face_cache: Dictionary = {} ## legacy; unused with 3D characters
static var _char_scene: PackedScene = null
static var _skin_tex_cache: Dictionary = {} ## path -> Texture2D
static var _idle_lib: AnimationLibrary = null
static var _walk_lib: AnimationLibrary = null


## When true (co-op guest), patience/order clock are driven by host sync — not local timers.
var mp_host_driven: bool = false


func setup(
	p_order: Array[String],
	color: Color,
	p_patience: float,
	p_lane: int,
	skin_idx: int = -1,
	face_style: int = -1,
	jin_fact_idx: int = -1
) -> void:
	order = p_order
	body_color = color
	patience_max = p_patience
	patience = p_patience
	lane = p_lane
	order_value = GameDataScript.order_value(order)
	_roll_personality()
	self.face_style = face_style if face_style >= 0 else (randi() % 3)
	_face_style = self.face_style
	if skin_idx >= 0 and not CHAR_SKINS.is_empty():
		self.skin_idx = skin_idx % CHAR_SKINS.size()
		_skin_path = CHAR_SKINS[self.skin_idx]
	else:
		self.skin_idx = randi() % CHAR_SKINS.size()
		_skin_path = CHAR_SKINS[self.skin_idx]
	is_jin_guest = false
	is_jimin_guest = false
	is_bts_guest = false
	speech = _make_speech()


static func lane_x_for(lane_i: int) -> float:
	if LANE_X.is_empty():
		return 0.0
	return LANE_X[clampi(lane_i, 0, LANE_X.size() - 1)]


func _wait_z() -> float:
	return WAIT_Z + (DISGUISE_CAT_WAIT_Z_OFFSET if is_disguise_cat else 0.0)


func _roll_personality() -> void:
	var roll := randf()
	if roll < 0.42:
		personality = "quiet"
		chatter = ""
	elif roll < 0.72:
		personality = "chatty"
		chatter = _pick_chatty_line()
	else:
		personality = "annoying"
		chatter = _pick_annoying_line()


func _apply_jin_guest_fact(fact_idx: int = -1) -> void:
	personality = "chatty"
	dialogue_mode = "chat"
	complaint_active = false
	pending_missing.clear()
	var idx := fact_idx
	if idx < 0 or idx >= JIN_FACTS.size():
		idx = randi() % JIN_FACTS.size()
	chatter = JIN_FACTS[idx]
	speech = "%s\n%s" % [chatter, _order_line()]


func _apply_jimin_guest_fact(fact_idx: int = -1) -> void:
	personality = "chatty"
	dialogue_mode = "chat"
	complaint_active = false
	pending_missing.clear()
	var idx := fact_idx
	if idx < 0 or idx >= JIMIN_FACTS.size():
		idx = randi() % JIMIN_FACTS.size()
	chatter = JIMIN_FACTS[idx]
	speech = "%s\n%s" % [chatter, _order_line()]


func show_special_speech(duration: float = 5.5) -> void:
	if chatter == "":
		return
	if _bubble:
		_bubble.text = chatter
		_bubble.modulate = Color(1.0, 0.94, 0.62)
		_bubble.visible = true
	if _bubble_bg:
		_bubble_bg.visible = true
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	if _bubble and is_waiting:
		_bubble.visible = false
	if _bubble_bg and is_waiting:
		_bubble_bg.visible = false


func needs_dialogue() -> bool:
	return personality == "chatty" or personality == "annoying"


func needs_complaint() -> bool:
	return complaint_active and not pending_missing.is_empty()


func begin_complaint(missing: Array) -> void:
	complaint_active = true
	pending_missing = missing.duplicate()
	dialogue_mode = "complaint"
	dialogue_open = true
	_set_mood("mad")
	shake_angry(0.5, 0.07)
	speech = _complaint_line()
	_refresh_bubble()


func clear_complaint() -> void:
	complaint_active = false
	pending_missing.clear()
	dialogue_mode = "chat"
	dialogue_open = false


func dialogue_prompt() -> Dictionary:
	## {title, body, options:[{label, tone}]}
	if dialogue_mode == "complaint" or complaint_active:
		var miss := _missing_label_list()
		return {
			"title": "Missing something!",
			"body": "You forgot my %s!\nWhat are you gonna do about it?" % miss,
			"options": [
				{"label": "I'll get you the %s" % miss, "tone": "fix"},
				{"label": "Full refund — keep your money", "tone": "refund"},
				{"label": "Fine — take it and go", "tone": "take_food"},
			],
		}
	if personality == "annoying":
		return {
			"title": "Annoyed customer",
			"body": chatter,
			"options": [
				{"label": "Please stop — what do you want?", "tone": "firm"},
				{"label": "Sir/ma'am. Order. Now.", "tone": "shut_down"},
				{"label": "Uh-huh… keep going…", "tone": "indulge"},
			],
		}
	## chatty
	return {
		"title": "Friendly chat",
		"body": chatter,
		"options": [
			{"label": "Aww, that's sweet! What can I get you?", "tone": "nice"},
			{"label": "Cool. What's the order?", "tone": "neutral"},
			{"label": "I don't have time for this.", "tone": "rude"},
		],
	}


func apply_dialogue_choice(tone: String) -> String:
	## Returns a short reaction flash; complaint tones resolved by game.gd.
	if dialogue_mode == "complaint" or complaint_active:
		dialogue_open = false
		match tone:
			"fix":
				complaint_active = false
				dialogue_mode = "chat"
				patience = minf(patience_max, patience + 14.0)
				_set_mood("ok")
				speech = "Well? Hurry up!\n" + _order_line()
				_refresh_bubble()
				return "fix"
			"refund":
				clear_complaint()
				_set_mood("mad")
				shake_angry(0.55, 0.08)
				speech = "I want my\nmoney back!"
				_refresh_bubble()
				return "refund"
			_:
				clear_complaint()
				_set_mood("mad")
				speech = "Whatever.\nI'm taking it."
				_refresh_bubble()
				return "take_food"
	dialogue_open = false
	match personality:
		"annoying":
			match tone:
				"firm":
					tip_mood_mult = 1.05
					_set_mood("ok")
					speech = "Fine.\n" + _order_line()
					_refresh_bubble()
					return "They simmer down and order."
				"shut_down":
					tip_mood_mult = 0.95
					_set_mood("mad")
					shake_angry(0.45, 0.06)
					speech = "Hmph.\n" + _order_line()
					_refresh_bubble()
					return "They look offended… but they stop talking."
				_:
					tip_mood_mult = 0.75
					patience = maxf(8.0, patience - 12.0)
					_set_mood("mad")
					speech = "AND ANOTHER THING—"
					_refresh_bubble()
					return "They keep ranting. Patience draining!"
		_:
			match tone:
				"nice":
					tip_mood_mult = 1.12
					_set_mood("cheer")
					bounce_happy()
					speech = "Thanks!\n" + _order_line()
					_refresh_bubble()
					return "They're smiling. Tip mood up!"
				"neutral":
					tip_mood_mult = 1.0
					speech = _order_line()
					_refresh_bubble()
					return "Straight to the order."
				_:
					tip_mood_mult = 0.8
					_set_mood("mad")
					shake_angry(0.4, 0.05)
					speech = "Rude.\n" + _order_line()
					_refresh_bubble()
					return "They got quiet… and colder."
	return ""


func _missing_label_list() -> String:
	var parts: Array[String] = []
	var seen := {}
	for item in pending_missing:
		var id := str(item)
		if seen.has(id):
			continue
		seen[id] = true
		parts.append(str(GameDataScript.INGREDIENT_LABELS.get(id, id.capitalize())))
	if parts.is_empty():
		return "stuff"
	if parts.size() == 1:
		return parts[0]
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	return ", ".join(parts.slice(0, parts.size() - 1)) + ", and " + parts[parts.size() - 1]


func _complaint_line() -> String:
	return "Hey!\nWhere's my\n%s?!" % _missing_label_list()


func _refresh_bubble() -> void:
	if _bubble:
		_bubble.text = speech


func _order_line() -> String:
	var parts: Array[String] = []
	for item in order:
		if item == "bun_bottom" or item == "bun_top":
			continue
		if item == "patty":
			parts.append("Patty")
		else:
			parts.append(GameDataScript.INGREDIENT_LABELS.get(item, item))
	if parts.is_empty():
		return "Burger please!"
	return "I want: " + " + ".join(parts)


func _pick_chatty_line() -> String:
	var lines := [
		"My kid's birthday is Friday and they ONLY want your burgers. Can you believe that?",
		"So my sister texted me from Florida… long story short, I need comfort food.",
		"My dad used to flip burgers on a flat-top just like this. Makes me nostalgic!",
		"We're road-tripping with the cousins and everyone voted for THIS truck.",
		"My partner said if I don't bring home a cheeseburger they're sleeping on the couch.",
		"Little tip: my grandma swears mustard goes on first. Don't tell her I disagree.",
		"I promised my nephew I'd describe every topping. He's six and very serious.",
	]
	return lines[randi() % lines.size()]


func _pick_annoying_line() -> String:
	var lines := [
		"Okay so FIRST of all the last truck put onions on EVERYTHING and I almost— wait are you listening?",
		"Let me tell you about my food blog… chapter three… the incident with the pickles…",
		"Do you know who I am? My cousin's roommate once ate here. Anyway—",
		"I've been waiting forever. Also my Wi‑Fi is bad. Also can you hurry but also don't rush my vibes?",
		"Before I order I need to explain my entire allergy spreadsheet. Sit down.",
		"Real talk: customer service is dead. Not you personally. Or maybe you. Continue.",
		"Hold on, I'm on a call with my mom about the burger. Mom says hi. Mom wants to talk to you—",
	]
	return lines[randi() % lines.size()]


func _ready() -> void:
	_build()
	_bounce = randf() * TAU
	_bobble_phase = randf() * TAU


func _build() -> void:
	_body = Node3D.new()
	_body.name = "CharacterVisual"
	_body.position = Vector3(0, _base_body_y, 0)
	_body.scale = Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE)
	add_child(_body)

	if not _try_attach_toon_character():
		## Fallback: old colored cube if the Kenney pack failed to import.
		_build_fallback_box()

	_bubble_bg = MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.92, 0.32, 0.04)
	_bubble_bg.mesh = bg_mesh
	_bubble_bg.position = Vector3(0, BAR_Y + 0.22, 0)
	var bgm := StandardMaterial3D.new()
	bgm.albedo_color = Color(1, 1, 1, 0.95)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_bg.material_override = bgm
	_bubble_bg.visible = false
	add_child(_bubble_bg)

	_bubble = Label3D.new()
	_bubble.text = speech
	_bubble.position = Vector3(0, BAR_Y + 0.22, 0.035)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color(0.12, 0.12, 0.14)
	_bubble.visible = false
	UiFontsScript.apply_label3d(_bubble, false, 40, 0.062)
	_bubble.outline_modulate = Color(0, 0, 0, 0)
	_bubble.outline_size = 0
	add_child(_bubble)

	## Patience meter lives on the order ticket UI — no 3D overlay on the customer.
	_bar_root = null
	_bar_bg = null
	_bar_fill = null


func _try_attach_toon_character() -> bool:
	if _char_scene == null:
		if not ResourceLoader.exists(CHAR_SCENE_PATH):
			return false
		_char_scene = load(CHAR_SCENE_PATH) as PackedScene
	if _char_scene == null:
		return false
	var model: Node = _char_scene.instantiate()
	if model == null:
		return false
	model.name = "ToonCustomer"
	_body.add_child(model)
	_char_meshes.clear()
	_collect_char_meshes(model)
	if _skin_path == "":
		_skin_path = CHAR_SKINS[randi() % CHAR_SKINS.size()]
	_apply_skin_texture(_skin_path)
	_apply_mood_tint("happy")
	_setup_character_animations(model)
	return not _char_meshes.is_empty()


func _build_bts_portrait_card() -> bool:
	var portrait_path := _skin_path
	if portrait_path == "":
		portrait_path = JIMIN_SKIN_PATH if is_jimin_guest else JIN_SKIN_PATH
	var tex := load(portrait_path) as Texture2D
	if tex == null:
		return false
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.942, 2.948)
	var card := MeshInstance3D.new()
	card.name = "BTSPortrait"
	card.mesh = mesh
	card.position = Vector3(0.0, 2.37, 0.0)
	card.sorting_offset = 28.0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.alpha_scissor_threshold = 0.035
	mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mat.roughness = 0.62
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	card.material_override = mat
	_body.add_child(card)
	_char_meshes.clear()
	_char_meshes.append(card)
	_anim_player = null
	return true


func _setup_character_animations(model: Node) -> void:
	## Idle + walk (Kenney run clip at a calmer speed).
	if _idle_lib == null:
		_idle_lib = _load_anim_library(IDLE_SCENE_PATH, "Idle", ["idle"])
	if _walk_lib == null:
		_walk_lib = _load_anim_library(RUN_SCENE_PATH, "Walk", ["run", "walk", "running"])
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "CustomerAnim"
	model.add_child(_anim_player)
	if _idle_lib != null and _idle_lib.has_animation("Idle"):
		_anim_player.add_animation_library("kenney", _idle_lib)
	if _walk_lib != null and _walk_lib.has_animation("Walk"):
		## Separate library so Idle/Walk names don't collide.
		_anim_player.add_animation_library("kenney_walk", _walk_lib)
	_anim_player.active = true
	_play_anim("idle")


func _play_anim(state: String) -> void:
	if _anim_player == null:
		return
	if state == _anim_state and _anim_player.is_playing():
		return
	var prev := _anim_state
	_anim_state = state
	if state == "walk" and _anim_player.has_animation("kenney_walk/Walk"):
		_anim_player.play("kenney_walk/Walk")
		_anim_player.speed_scale = 0.72 + randf() * 0.18
		return
	if _anim_player.has_animation("kenney/Idle"):
		_anim_player.play("kenney/Idle")
		_anim_player.speed_scale = 0.8 + randf() * 0.35
		if prev != "idle":
			var idle_anim := _anim_player.get_animation("kenney/Idle")
			if idle_anim != null and idle_anim.length > 0.05:
				_anim_player.seek(randf() * idle_anim.length, true)


func _load_anim_library(scene_path: String, store_as: String, accept_names: Array) -> AnimationLibrary:
	if not ResourceLoader.exists(scene_path):
		return null
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var temp: Node = packed.instantiate()
	var src: AnimationPlayer = temp.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		temp.queue_free()
		return null
	var lib := AnimationLibrary.new()
	var accept_lower: Array = []
	for n in accept_names:
		accept_lower.append(str(n).to_lower())
	for full_name in src.get_animation_list():
		var anim := src.get_animation(full_name)
		if anim == null:
			continue
		var short := String(full_name)
		if short.contains("|"):
			short = short.get_slice("|", 1)
		if not accept_lower.has(short.to_lower()):
			continue
		var copy := anim.duplicate() as Animation
		copy.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(store_as, copy)
		break
	temp.queue_free()
	if lib.get_animation_list().is_empty():
		return null
	return lib


func _collect_char_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		## Keep toons in front of the street matte painting.
		mi.sorting_offset = 24.0
		if mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).render_priority = 2
		_char_meshes.append(mi)
	for c in n.get_children():
		_collect_char_meshes(c)


func _get_skin_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _skin_tex_cache.has(path):
		return _skin_tex_cache[path]
	var tex := load(path) as Texture2D
	if tex != null:
		_skin_tex_cache[path] = tex
	return tex


func _apply_skin_texture(path: String) -> void:
	var tex := _get_skin_tex(path)
	if tex == null:
		return
	for mi in _char_meshes:
		if mi == null or not is_instance_valid(mi):
			continue
		var mesh_i := mi as MeshInstance3D
		var base: Material = mesh_i.get_active_material(0)
		if base == null:
			base = mesh_i.material_override
		var sm: StandardMaterial3D
		if base is StandardMaterial3D:
			sm = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		else:
			sm = StandardMaterial3D.new()
		sm.albedo_texture = tex
		## Nearest keeps Kenney toon skins crisp (linear+mips made human skins mushy).
		sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sm.roughness = 0.72
		sm.metallic = 0.0
		sm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mesh_i.material_override = sm


func _build_fallback_box() -> void:
	var box_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 1.05, 0.95)
	box_mi.mesh = box
	box_mi.position = Vector3(0, 0.55 / CHAR_SCALE, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.55
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	box_mi.material_override = mat
	_body.add_child(box_mi)
	_char_meshes.append(box_mi)

	_face = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.82, 0.82)
	_face.mesh = quad
	_face.position = Vector3(0, 0.04 / CHAR_SCALE, 0.485 / CHAR_SCALE)
	_face_mat = StandardMaterial3D.new()
	_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_face_mat.albedo_texture = _get_face_tex("happy")
	_face.material_override = _face_mat
	box_mi.add_child(_face)


func _set_mood(mood: String) -> void:
	if mood == _mood:
		return
	_mood = mood
	_apply_face(mood)
	_apply_mood_tint(mood)


func _apply_face(mood: String) -> void:
	if _face_mat == null:
		return
	_face_mat.albedo_texture = _get_face_tex(mood)


func _apply_mood_tint(mood: String) -> void:
	## Soft color wash over the toon skin so patience mood still reads.
	var tint := Color(1, 1, 1, _leave_fade_alpha)
	match mood:
		"happy", "cheer":
			tint = Color(1.05, 1.02, 0.98)
		"ok":
			tint = Color(1.0, 0.98, 0.92)
		"mad":
			tint = Color(1.08, 0.82, 0.78)
		"dead":
			tint = Color(0.72, 0.72, 0.78)
		_:
			tint = Color(1, 1, 1)
	## Blend a hint of the assigned body_color so customers stay distinct.
	tint = tint.lerp(body_color.lightened(0.35), 0.12)
	tint.a = _leave_fade_alpha
	for mi in _char_meshes:
		if mi == null or not is_instance_valid(mi):
			continue
		var mesh_i := mi as MeshInstance3D
		var sm := mesh_i.material_override as StandardMaterial3D
		if sm == null:
			continue
		sm.albedo_color = tint


func _begin_leave_fade() -> void:
	_leave_fade_t = 0.0
	_leave_fade_active = false
	_leave_fade_wait_for_turn = true
	_leave_fade_alpha = 1.0
	_apply_leave_fade_alpha(1.0)


func _start_leave_fade_now() -> void:
	_leave_fade_t = 0.0
	_leave_fade_wait_for_turn = false
	_leave_fade_active = true
	_apply_leave_fade_alpha(1.0)


func _update_leave_fade(delta: float) -> void:
	if not _leave_fade_active:
		return
	_leave_fade_t += delta
	var alpha := 1.0 - clampf(_leave_fade_t / LEAVE_FADE_SEC, 0.0, 1.0)
	_apply_leave_fade_alpha(alpha)
	if alpha <= 0.01:
		queue_free()


func _apply_leave_fade_alpha(alpha: float) -> void:
	_leave_fade_alpha = clampf(alpha, 0.0, 1.0)
	_fade_node_materials(self, _leave_fade_alpha)
	if _bubble:
		_bubble.modulate.a = minf(_bubble.modulate.a, alpha)
	if _treat_hearts:
		_treat_hearts.modulate.a = minf(_treat_hearts.modulate.a, alpha)
	if _review_stars:
		_review_stars.modulate.a = minf(_review_stars.modulate.a, alpha)


func _fade_node_materials(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var surf_count := 0
		if mi.mesh != null:
			surf_count = mi.mesh.get_surface_count()
		surf_count = maxi(surf_count, mi.get_surface_override_material_count())
		if surf_count <= 0:
			var mat := _material_for_fade(mi.material_override)
			if mat != null:
				mi.material_override = mat
				_set_material_alpha(mat, alpha)
		else:
			for si in surf_count:
				var base: Material = mi.get_surface_override_material(si)
				if base == null:
					base = mi.get_active_material(si)
				if base == null and mi.mesh != null and si < mi.mesh.get_surface_count():
					base = mi.mesh.surface_get_material(si)
				if base == null:
					base = mi.material_override
				var sm := _material_for_fade(base)
				if sm == null:
					continue
				if mi.mesh != null and si < mi.mesh.get_surface_count():
					mi.set_surface_override_material(si, sm)
				else:
					mi.material_override = sm
				_set_material_alpha(sm, alpha)
	for child in node.get_children():
		_fade_node_materials(child, alpha)


func _material_for_fade(base: Material) -> StandardMaterial3D:
	if base is StandardMaterial3D:
		var sm := base as StandardMaterial3D
		if not bool(sm.get_meta("customer_fade_unique", false)):
			sm = sm.duplicate() as StandardMaterial3D
			sm.set_meta("customer_fade_unique", true)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		return sm
	var fresh := StandardMaterial3D.new()
	fresh.set_meta("customer_fade_unique", true)
	fresh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fresh.cull_mode = BaseMaterial3D.CULL_DISABLED
	fresh.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	fresh.albedo_color = Color(1.0, 1.0, 1.0, _leave_fade_alpha)
	fresh.roughness = 0.72
	fresh.metallic = 0.0
	fresh.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return fresh


func _set_material_alpha(sm: StandardMaterial3D, alpha: float) -> void:
	var c := sm.albedo_color
	c.a = alpha
	sm.albedo_color = c


func _get_face_tex(mood: String) -> ImageTexture:
	var key := "%s_%d" % [mood, _face_style]
	if _face_cache.has(key):
		return _face_cache[key]
	var tex := _draw_face(mood, _face_style)
	_face_cache[key] = tex
	return tex


func _draw_face(mood: String, style: int) -> ImageTexture:
	## Crisp pixel-ish 2D face: eyes + mouth only, clear expression.
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.08, 0.07, 0.09, 1.0)
	var eye_y := 38 + (style - 1) * 2
	var eye_dx := 16 + style
	var eye_r := 5 + (style % 2)
	var mouth_y := 62 + style

	match mood:
		"happy":
			_face_fill_circle(img, 48 - eye_dx, eye_y, eye_r, ink)
			_face_fill_circle(img, 48 + eye_dx, eye_y, eye_r, ink)
			_face_arc(img, 48, mouth_y - 2, 16, 4, 18, 162, ink, 3)
		"ok":
			_face_fill_circle(img, 48 - eye_dx, eye_y, eye_r, ink)
			_face_fill_circle(img, 48 + eye_dx, eye_y, eye_r, ink)
			_face_hline(img, 48 - 12, 48 + 12, mouth_y, ink, 3)
		"mad":
			## Angled brows + smaller eyes + frown
			_face_line(img, 48 - eye_dx - 8, eye_y - 10, 48 - eye_dx + 7, eye_y - 4, ink, 3)
			_face_line(img, 48 + eye_dx + 8, eye_y - 10, 48 + eye_dx - 7, eye_y - 4, ink, 3)
			_face_fill_circle(img, 48 - eye_dx, eye_y + 1, eye_r - 1, ink)
			_face_fill_circle(img, 48 + eye_dx, eye_y + 1, eye_r - 1, ink)
			_face_arc(img, 48, mouth_y + 8, 14, 5, 198, 342, ink, 3)
		"cheer":
			## Squint lines + big open smile
			_face_line(img, 48 - eye_dx - 7, eye_y, 48 - eye_dx + 7, eye_y - 2, ink, 3)
			_face_line(img, 48 - eye_dx - 7, eye_y, 48 - eye_dx + 7, eye_y + 2, ink, 3)
			_face_line(img, 48 + eye_dx - 7, eye_y - 2, 48 + eye_dx + 7, eye_y, ink, 3)
			_face_line(img, 48 + eye_dx - 7, eye_y + 2, 48 + eye_dx + 7, eye_y, ink, 3)
			_face_arc(img, 48, mouth_y - 6, 18, 8, 12, 168, ink, 3)
			_face_fill_ellipse(img, 48, mouth_y + 2, 12, 6, Color(0.12, 0.1, 0.12, 0.85))
		"dead":
			## X eyes + wavy frown
			_face_line(img, 48 - eye_dx - 6, eye_y - 6, 48 - eye_dx + 6, eye_y + 6, ink, 3)
			_face_line(img, 48 - eye_dx - 6, eye_y + 6, 48 - eye_dx + 6, eye_y - 6, ink, 3)
			_face_line(img, 48 + eye_dx - 6, eye_y - 6, 48 + eye_dx + 6, eye_y + 6, ink, 3)
			_face_line(img, 48 + eye_dx - 6, eye_y + 6, 48 + eye_dx + 6, eye_y - 6, ink, 3)
			_face_arc(img, 48, mouth_y + 6, 13, 4, 200, 340, ink, 3)
		_:
			_face_fill_circle(img, 48 - eye_dx, eye_y, eye_r, ink)
			_face_fill_circle(img, 48 + eye_dx, eye_y, eye_r, ink)
			_face_hline(img, 48 - 10, 48 + 10, mouth_y, ink, 3)

	return ImageTexture.create_from_image(img)


func _face_set(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)


func _face_fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				_face_set(img, x, y, col)


func _face_fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / float(maxi(1, rx))
			var ny := float(y - cy) / float(maxi(1, ry))
			if nx * nx + ny * ny <= 1.0:
				_face_set(img, x, y, col)


func _face_hline(img: Image, x0: int, x1: int, y: int, col: Color, thick: int = 2) -> void:
	var a := mini(x0, x1)
	var b := maxi(x0, x1)
	var ht := int(thick / 2)
	for x in range(a, b + 1):
		for t in range(-ht, ht + 1):
			_face_set(img, x, y + t, col)


func _face_line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, thick: int = 2) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	var ht := int(thick / 2)
	while true:
		for ty in range(-ht, ht + 1):
			for tx in range(-ht, ht + 1):
				_face_set(img, x + tx, y + ty, col)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


func _face_arc(img: Image, cx: int, cy: int, rx: int, ry: int, deg0: float, deg1: float, col: Color, thick: int = 2) -> void:
	var steps := maxi(12, int((deg1 - deg0) * 0.5))
	var prev: Vector2i
	var has_prev := false
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := deg_to_rad(lerpf(deg0, deg1, t))
		var p := Vector2i(cx + int(cos(ang) * rx), cy + int(sin(ang) * ry))
		if has_prev:
			_face_line(img, prev.x, prev.y, p.x, p.y, col, thick)
		prev = p
		has_prev = true


func _make_speech() -> String:
	if personality == "chatty" and chatter != "":
		return "Hey!\n*chatting…*"
	if personality == "annoying" and chatter != "":
		return "Listen—\n*ranting…*"
	return _order_line()


func _process(delta: float) -> void:
	_bounce += delta * 3.2
	_bobble_phase += delta * 2.4
	_expr_t += delta
	_home_x = target_x
	_update_powder_blobs(delta)
	_update_leave_fade(delta)

	if is_ragdoll:
		_update_ragdoll(delta)
		return

	## Powdered — stand still (same size) while spheres build up, then walk off.
	if _powdering and not is_leaving:
		_update_powder_stand(delta)
		return

	if mp_host_driven and not is_leaving:
		_update_host_driven_pose(delta)
		return

	if _shake_time > 0.0 and not is_leaving:
		_shake_time -= delta
		var rate := maxf(0.05, _shake_rate)
		var shake_x := sin(Time.get_ticks_msec() * 0.06 * rate) * _shake_amp
		var shake_z := cos(Time.get_ticks_msec() * 0.08 * rate) * _shake_amp * 0.45
		global_position.x = _home_x + shake_x
		global_position.z = _wait_z() + shake_z
		if _body:
			_body.rotation_degrees.z = shake_x * _shake_tilt
		if _shake_time <= 0.0:
			_shake_amp = 0.0
			_shake_rate = 1.0
			_shake_tilt = 35.0
			if _body:
				_body.rotation_degrees.z = 0.0
			global_position.x = _home_x
			global_position.z = _wait_z()
	elif is_leaving:
		_shake_time = 0.0
		_shake_amp = 0.0
		_shake_rate = 1.0
		_shake_tilt = 35.0

	if is_leaving:
		_leave_spin += delta
		## Stay planted on the sidewalk — never float up while leaving.
		global_position.y = STAND_Y
		if not _leave_turned:
			var turn_t := clampf(_leave_spin / LEAVE_TURN_SEC, 0.0, 1.0)
			var ease_t := turn_t * turn_t * (3.0 - 2.0 * turn_t)
			rotation_degrees.y = lerpf(_leave_yaw_from, FACE_AWAY_YAW, ease_t)
			if _body:
				_body.position.y = _base_body_y
				if _powder_hit:
					_powder_panic_t += delta
					var wob := sin(_powder_panic_t * 17.0) * 0.07
					global_position.x = _home_x + wob
					_body.rotation_degrees.x = sin(_powder_panic_t * 11.0) * 3.0
					_body.rotation_degrees.z = sin(_powder_panic_t * 14.0) * 5.0
					_apply_hands_up_pose(1.0)
					if _anim_player:
						_anim_player.stop()
				else:
					_body.rotation_degrees = Vector3.ZERO
			if not _powder_hit:
				_play_anim("idle")
			if turn_t >= 1.0:
				_leave_turned = true
				rotation_degrees.y = FACE_AWAY_YAW
				if _leave_fade_wait_for_turn:
					_start_leave_fade_now()
				if _powder_hit:
					_reset_skeleton_pose()
					if _anim_player:
						_anim_player.active = true
				_play_anim("walk")
			return
		## Facing away — walk off down the sidewalk at ground level (never behind matte).
		global_position.z += delta * (2.15 if _powder_hit else 2.6)
		global_position.z = minf(global_position.z, MATTE_FRONT_Z_MAX)
		_play_anim("walk")
		if _body:
			var step := absf(sin(_leave_spin * 9.0)) * 0.02
			_body.position.y = _base_body_y + step
			if _powder_hit:
				_powder_panic_t += delta
				var stomp := sin(_powder_panic_t * 15.0) * 0.09
				global_position.x = _home_x + stomp
				_body.rotation_degrees.z = sin(_powder_panic_t * 12.0) * 14.0
				_body.rotation_degrees.x = sin(_powder_panic_t * 8.5) * 7.0
			else:
				_body.rotation_degrees = Vector3.ZERO
		if global_position.z >= MATTE_FRONT_Z_MAX and not _leave_fade_active:
			queue_free()
		return

	var dx: float = target_x - global_position.x
	if absf(dx) > 0.05 and _shake_time <= 0.0:
		## Face the way we're walking (along the sidewalk), not sideways at the truck.
		rotation_degrees.y = WALK_PLUS_X_YAW if dx > 0.0 else WALK_MINUS_X_YAW
		_arrive_turning = false
		global_position.x += signf(dx) * minf(absf(dx), delta * 1.6)
		_play_anim("walk")
		_apply_bobble(true)
		if _bar_root:
			_bar_root.visible = false
		if _bar_bg:
			_bar_bg.visible = false
		if _bar_fill:
			_bar_fill.visible = false
	elif not is_waiting:
		## Arrived at the lane — turn to face the cook, then idle.
		if not _arrive_turning:
			_arrive_turning = true
			_arrive_turn_t = 0.0
			_arrive_yaw_from = rotation_degrees.y
		_arrive_turn_t += delta
		var turn_t := clampf(_arrive_turn_t / ARRIVE_TURN_SEC, 0.0, 1.0)
		var ease_t := turn_t * turn_t * (3.0 - 2.0 * turn_t)
		rotation_degrees.y = lerpf(_arrive_yaw_from, FACE_TRUCK_YAW, ease_t)
		_play_anim("idle")
		_apply_bobble(false)
		if _bar_root:
			_bar_root.visible = false
		if turn_t < 1.0:
			_animate_expression(delta)
			return
		_arrive_turning = false
		rotation_degrees.y = FACE_TRUCK_YAW
		is_waiting = true
		## Speech bubble off for now — tickets carry the order.
		if _bubble:
			_bubble.visible = false
		if _bubble_bg:
			_bubble_bg.visible = false
		_refresh_patience_bar()
		_play_anim("idle")
		arrived.emit(self)
		_apply_bobble(false)
	elif _shake_time <= 0.0:
		rotation_degrees.y = FACE_TRUCK_YAW
		if _eating:
			_play_anim("idle")
			if _anim_player:
				_anim_player.stop()
			_apply_eat_hands_pose(1.0)
			if _body:
				_body.position.y = _base_body_y
				_body.rotation_degrees.x = _eat_lean_x
				_body.rotation_degrees.z = 0.0
		else:
			_play_anim("idle")
			if _should_antsy_wait():
				_apply_antsy_wait(delta)
			else:
				_clear_antsy_wait_pose()
				_apply_bobble(false)

	_animate_expression(delta)

	if is_waiting:
		## Drain pauses during chat / mid-bite, but the bar stays visible either way.
		## Co-op guests mirror host patience — don't expire locally (desyncs tickets).
		if queue_timer_active and not dialogue_open and not mp_host_driven and not _eating:
			patience -= delta
		_refresh_patience_bar()
		if queue_timer_active:
			_update_wait_grobble(delta)
		if queue_timer_active and patience <= 0.0 and not mp_host_driven and not _eating:
			leave_mad()
			patience_expired.emit(self)
	## Ticket clock runs from the moment the slip is pinned until serve / leave.
	if _order_clock_on and queue_timer_active and not is_leaving and not mp_host_driven:
		order_elapsed_sec += delta


func _update_host_driven_pose(delta: float) -> void:
	## Multiplayer guests receive position/ticket state from the host; avoid local
	## arrival-turn code fighting that snapshot and spinning remote customers.
	global_position.y = STAND_Y
	if is_waiting:
		rotation_degrees.y = FACE_TRUCK_YAW
		if _eating:
			_play_anim("idle")
			if _anim_player:
				_anim_player.stop()
			_apply_eat_hands_pose(1.0)
			if _body:
				_body.position.y = _base_body_y
				_body.rotation_degrees.x = _eat_lean_x
				_body.rotation_degrees.z = 0.0
		else:
			_play_anim("idle")
			if _should_antsy_wait():
				_apply_antsy_wait(delta)
			else:
				_clear_antsy_wait_pose()
		_animate_expression(delta)
		return
	rotation_degrees.y = WALK_PLUS_X_YAW
	_play_anim("walk")
	_apply_bobble(true)
	_animate_expression(delta)


func start_order_clock(reset_elapsed: bool = true) -> void:
	## Call when the order ticket is created.
	if reset_elapsed:
		order_elapsed_sec = 0.0
	_order_clock_on = true


func stop_order_clock() -> void:
	_order_clock_on = false


func set_queue_timer_active(active: bool) -> void:
	queue_timer_active = active
	if active:
		start_order_clock(false)
	else:
		stop_order_clock()


func speed_rating(burnt: bool = false) -> Dictionary:
	## Wow! ≤3s · Perfect! ≤6s · Great! ≤10s · Good <30s · Not good → Bad — from ticket time.
	if burnt:
		return {
			"score": 12,
			"grade": "F",
			"stars": 0,
			"label": "Bad",
			"detail": "Burnt",
			"color": Color("EF5350"),
			"pay_mul": 0.22,
			"wait": order_elapsed_sec,
			"text": "Bad  Burnt",
		}
	var wait := order_elapsed_sec
	var score := 70
	var grade := "B"
	var stars := 3
	var label := "Good"
	var detail := "%.0fs" % wait
	var color := Color("81C784")
	var pay_mul := 1.0
	if wait <= SERVE_WOW_SEC:
		score = 100
		grade = "S"
		stars = 5
		label = "Wow!"
		detail = "%.1fs" % wait
		color = Color("FFD54F")
		pay_mul = 1.5
	elif wait <= SERVE_PERFECT_SEC:
		score = 100
		grade = "S"
		stars = 5
		label = "Perfect!"
		detail = "%.1fs" % wait
		color = Color("FFEB3B")
		pay_mul = 1.35
	elif wait <= SERVE_GREAT_SEC:
		score = 88
		grade = "A"
		stars = 4
		label = "Great!"
		detail = "%.1fs" % wait
		color = Color("A5D6A7")
		pay_mul = 1.2
	elif wait < SERVE_GOOD_SEC:
		score = 72
		grade = "B"
		stars = 3
		label = "Good"
		detail = "%.0fs" % wait
		color = Color("81C784")
		pay_mul = 1.0
	elif wait < SERVE_NOT_GOOD_SEC:
		score = 38
		grade = "D"
		stars = 1
		label = "Not good"
		detail = "%.0fs" % wait
		color = Color("FFA726")
		pay_mul = 0.55
	else:
		score = 15
		grade = "F"
		stars = 0
		label = "Bad"
		detail = "%.0fs" % wait
		color = Color("EF5350")
		pay_mul = 0.28
	return {
		"score": score,
		"grade": grade,
		"stars": stars,
		"label": label,
		"detail": detail,
		"color": color,
		"pay_mul": pay_mul,
		"wait": wait,
		"text": "%s  %s" % [label, detail],
	}


func _refresh_patience_bar() -> void:
	## Mood only — the fill meter is drawn on the order ticket (game.gd).
	var t: float = clampf(patience / maxf(0.01, patience_max), 0.0, 1.0)
	if t > 0.55:
		_set_mood("happy")
	elif t > 0.28:
		_set_mood("ok")
	else:
		_set_mood("mad")


func _apply_bobble(walking: bool) -> void:
	if _body == null:
		return
	## Idle skeleton owns the pose — only a light root bob so we don't fight the anim.
	if _anim_player != null and _anim_player.is_playing():
		var bob_amp := 0.01 if walking else 0.005
		_body.position.y = _base_body_y + sin(_bobble_phase) * bob_amp
		_body.rotation_degrees = Vector3.ZERO
		return
	var bob_amp2 := 0.055 if walking else 0.035
	var sway := 4.5 if walking else 3.0
	_body.position.y = _base_body_y + sin(_bobble_phase) * bob_amp2
	_body.rotation_degrees.z = sin(_bobble_phase * 0.85) * sway
	_body.rotation_degrees.x = cos(_bobble_phase * 0.7) * 2.0


func _update_wait_grobble(delta: float) -> void:
	## Every 10s past half patience — play 3s of pitched-up wawawa from a random offset.
	if not is_waiting or is_leaving or is_ragdoll or _eating or _powdering or dialogue_open:
		_grobble_cd = 0.0
		return
	if is_disguise_cat or is_terrorist:
		_grobble_cd = 0.0
		return
	if patience_ratio() > GROBBLE_PATIENCE_RATIO:
		_grobble_cd = 0.0
		return
	_grobble_cd -= delta
	if _grobble_cd > 0.0:
		return
	_grobble_cd = GROBBLE_INTERVAL_SEC
	var impatience := clampf((GROBBLE_PATIENCE_RATIO - patience_ratio()) / GROBBLE_PATIENCE_RATIO, 0.0, 1.0)
	shake_angry(GROBBLE_SHAKE_SEC, GROBBLE_SHAKE_AMP, GROBBLE_SHAKE_RATE, false)
	var audio := get_tree().get_first_node_in_group("game_audio") if get_tree() else null
	if audio != null and audio.has_method("play_customer_grobble"):
		audio.play_customer_grobble(impatience)


func _should_antsy_wait() -> bool:
	if not is_waiting or is_leaving or is_ragdoll or _eating or _powdering or dialogue_open:
		return false
	if _shake_time > 0.0:
		return false
	return order_elapsed_sec >= ANTSY_MIN_WAIT_SEC and patience_ratio() <= ANTSY_WAIT_RATIO_START


func _antsy_wait_strength() -> float:
	var patience_t := patience_ratio()
	var patience_s := clampf((ANTSY_WAIT_RATIO_START - patience_t) / ANTSY_WAIT_RATIO_START, 0.0, 1.0)
	var time_s := clampf((order_elapsed_sec - ANTSY_MIN_WAIT_SEC) / 10.0, 0.0, 1.0)
	return patience_s * time_s


func _apply_antsy_wait(delta: float) -> void:
	if _body == null:
		return
	_antsy_active = true
	var s := _antsy_wait_strength()
	_antsy_phase += delta * lerpf(4.2, 8.8, s)
	var step := sin(_antsy_phase)
	var hop := absf(sin(_antsy_phase * 1.7))
	var lean := sin(_antsy_phase * 1.15)
	_body.position.y = _base_body_y + hop * lerpf(0.004, 0.026, s)
	_body.rotation_degrees.x = sin(_antsy_phase * 1.35) * lerpf(0.8, 4.0, s)
	_body.rotation_degrees.z = lean * lerpf(2.0, 8.5, s)
	rotation_degrees.y = FACE_TRUCK_YAW + step * lerpf(0.5, 4.5, s)
	if order_elapsed_sec >= ANTSY_HANDS_UP_MIN_WAIT_SEC and patience_ratio() <= ANTSY_HANDS_UP_RATIO_START:
		var panic_s := clampf((ANTSY_HANDS_UP_RATIO_START - patience_ratio()) / ANTSY_HANDS_UP_RATIO_START, 0.0, 1.0)
		var throw_up := 0.45 + 0.55 * absf(sin(_antsy_phase * 0.72))
		_antsy_hands_up_active = true
		_apply_hands_up_pose(panic_s * throw_up)
	elif _antsy_hands_up_active:
		_antsy_hands_up_active = false
		_reset_skeleton_pose()


func _clear_antsy_wait_pose() -> void:
	if not _antsy_active:
		return
	_antsy_active = false
	_antsy_hands_up_active = false
	_reset_skeleton_pose()
	if _body:
		_body.position.y = _base_body_y
		_body.rotation_degrees.x = 0.0
		_body.rotation_degrees.z = 0.0


func _animate_expression(_delta: float) -> void:
	if is_leaving or _body == null:
		return
	## Don't squash-scale over a playing idle clip.
	if _anim_player != null and _anim_player.is_playing():
		_body.scale = Vector3(CHAR_SCALE, CHAR_SCALE, CHAR_SCALE)
		return
	var pulse := 1.0 + sin(_expr_t * 4.5) * 0.012
	if _mood == "mad":
		pulse = 1.0 + sin(_expr_t * 10.0) * 0.02
	elif _mood == "cheer":
		pulse = 1.0 + absf(sin(_expr_t * 7.0)) * 0.03
	_body.scale = Vector3(CHAR_SCALE * pulse, CHAR_SCALE * pulse, CHAR_SCALE * pulse)
	if _face != null:
		_face.scale = Vector3(pulse, pulse, 1.0)


func shake_angry(duration: float = 0.7, amp: float = 0.12, rate: float = 1.0, punch: bool = true) -> void:
	_set_mood("mad")
	_shake_time = duration
	_shake_amp = amp
	_shake_rate = rate
	## Slower shakes lean less so they don't look twitchy.
	_shake_tilt = lerpf(12.0, 35.0, clampf(rate, 0.0, 1.0))
	## Quick squash punch — stay at CHAR_SCALE (never jump to 1.0).
	if punch and _body:
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector3(CHAR_SCALE * 1.06, CHAR_SCALE * 0.94, CHAR_SCALE * 1.06), 0.08)
		tw.tween_property(_body, "scale", Vector3.ONE * CHAR_SCALE, 0.12)


func bounce_happy() -> void:
	_set_mood("cheer")
	if _body == null:
		return
	var tw := create_tween()
	tw.tween_property(_body, "position:y", _base_body_y + 0.22, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", _base_body_y, 0.18).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(_body, "scale", Vector3(CHAR_SCALE * 1.05, CHAR_SCALE * 0.95, CHAR_SCALE * 1.05), 0.1)
	tw.tween_property(_body, "scale", Vector3.ONE * CHAR_SCALE, 0.15)


func show_review_stars(stars: float) -> void:
	## Floating ★★★★☆ above the head when this guest posts a social review.
	var full := clampi(int(floor(clampf(stars, 0.0, 5.0) + 0.25)), 0, 5)
	var text := ""
	for i in 5:
		text += "★" if i < full else "☆"
	if _review_stars == null:
		_review_stars = Label3D.new()
		_review_stars.name = "ReviewStars"
		_review_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_review_stars.no_depth_test = true
		_review_stars.shaded = false
		UiFontsScript.apply_label3d(_review_stars, true, 56, 0.11)
		_review_stars.outline_size = 10
		_review_stars.outline_modulate = Color(0.08, 0.05, 0.0, 0.85)
		add_child(_review_stars)
	_review_stars.text = text
	_review_stars.position = Vector3(0.0, BAR_Y + 0.08, 0.05)
	## Gold for solid ratings; cooler amber when they roasted you.
	if full >= 4:
		_review_stars.modulate = Color(1.0, 0.86, 0.22, 1.0)
	elif full >= 3:
		_review_stars.modulate = Color(1.0, 0.78, 0.28, 1.0)
	elif full >= 2:
		_review_stars.modulate = Color(0.92, 0.72, 0.35, 1.0)
	else:
		_review_stars.modulate = Color(0.95, 0.45, 0.35, 1.0)
	_review_stars.visible = true
	if _review_stars_tween != null and is_instance_valid(_review_stars_tween):
		_review_stars_tween.kill()
	_review_stars_tween = create_tween()
	_review_stars_tween.set_parallel(true)
	_review_stars_tween.tween_property(
		_review_stars, "position:y", BAR_Y + 0.58, 1.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_review_stars_tween.tween_property(
		_review_stars, "modulate:a", 0.0, 1.55
	).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_review_stars_tween.chain().tween_callback(func() -> void:
		if _review_stars != null and is_instance_valid(_review_stars):
			_review_stars.visible = false
	)


func react_free_icecream(accepted: bool = true) -> void:
	if is_leaving or is_ragdoll:
		return
	if accepted:
		_set_mood("cheer")
		bounce_happy()
		if _bubble:
			_bubble.text = "Free cone!"
			_bubble.visible = true
			_bubble.modulate = Color(1.0, 0.88, 0.96)
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_instance_valid(self) and _bubble and is_waiting:
					_bubble.visible = false
			)
		_show_treat_hearts()
	else:
		_set_mood("mad")
		shake_angry(0.65, 0.09)
		if _bubble:
			_bubble.text = "I didn't order that!"
			_bubble.visible = true
			_bubble.modulate = Color(1.0, 0.52, 0.42)
			get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(self) and _bubble and is_waiting:
					_bubble.visible = false
			)


func _show_treat_hearts() -> void:
	if _treat_hearts == null:
		_treat_hearts = Label3D.new()
		_treat_hearts.name = "TreatHearts"
		_treat_hearts.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_treat_hearts.no_depth_test = true
		_treat_hearts.shaded = false
		UiFontsScript.apply_label3d(_treat_hearts, true, 58, 0.11)
		_treat_hearts.outline_size = 8
		_treat_hearts.outline_modulate = Color(0.2, 0.02, 0.08, 0.85)
		add_child(_treat_hearts)
	_treat_hearts.text = "♥ ♥"
	_treat_hearts.position = Vector3(0.0, BAR_Y + 0.08, 0.05)
	_treat_hearts.modulate = Color(1.0, 0.24, 0.48, 1.0)
	_treat_hearts.visible = true
	if _treat_hearts_tween != null and is_instance_valid(_treat_hearts_tween):
		_treat_hearts_tween.kill()
	_treat_hearts_tween = create_tween()
	_treat_hearts_tween.set_parallel(true)
	_treat_hearts_tween.tween_property(
		_treat_hearts, "position:y", BAR_Y + 0.55, 1.1
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_treat_hearts_tween.tween_property(
		_treat_hearts, "modulate:a", 0.0, 1.1
	).set_delay(0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_treat_hearts_tween.chain().tween_callback(func() -> void:
		if _treat_hearts != null and is_instance_valid(_treat_hearts):
			_treat_hearts.visible = false
	)


func leave_happy() -> void:
	stop_order_clock()
	_eating = false
	_eat_lean_x = 0.0
	is_leaving = true
	is_waiting = false
	_leave_spin = 0.0
	_leave_turned = false
	_leave_yaw_from = rotation_degrees.y
	global_position.y = STAND_Y
	_set_mood("cheer")
	_clear_antsy_wait_pose()
	_reset_skeleton_pose()
	_play_anim("idle")
	if _body:
		_body.rotation_degrees.x = 0.0
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	_begin_leave_fade()


func leave_meh() -> void:
	## Bland / unseasoned — shrug and walk off. Paid base, no tip energy.
	stop_order_clock()
	_eating = false
	_eat_lean_x = 0.0
	is_leaving = true
	is_waiting = false
	_leave_spin = 0.0
	_leave_turned = false
	_leave_yaw_from = rotation_degrees.y
	global_position.y = STAND_Y
	_set_mood("ok")
	_clear_antsy_wait_pose()
	_reset_skeleton_pose()
	_play_anim("idle")
	if _body:
		_body.rotation_degrees.x = 0.0
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	_begin_leave_fade()


func leave_heck() -> void:
	## Grease-fire scare — blurt and bolt.
	stop_order_clock()
	is_leaving = true
	is_waiting = false
	_leave_spin = 0.0
	_leave_turned = false
	_leave_yaw_from = rotation_degrees.y
	global_position.y = STAND_Y
	speech = "What the heck?!"
	_set_mood("mad")
	_clear_antsy_wait_pose()
	_play_anim("idle")
	if _bubble:
		_bubble.text = speech
		_bubble.visible = true
	if _bubble_bg:
		_bubble_bg.visible = true
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	_begin_leave_fade()
	## Hide the blurt after a beat so they can turn and leave.
	get_tree().create_timer(0.85).timeout.connect(func():
		if not is_instance_valid(self):
			return
		if _bubble:
			_bubble.visible = false
		if _bubble_bg:
			_bubble_bg.visible = false
	)


func receive_ext_powder(spray_zone: String = "body") -> bool:
	## Stick white spheres on face + body. First hit → hands-up panic, then storm off.
	if is_ragdoll:
		return false
	var zone := spray_zone if spray_zone == "face" or spray_zone == "body" else "body"
	if zone == "face":
		_powder_face_build = clampf(_powder_face_build + 0.18, 0.0, 1.0)
	else:
		_powder_face_build = clampf(_powder_face_build + 0.08, 0.0, 1.0)
	var face_n := 3 if zone == "face" else 2
	var body_n := 3 if zone == "body" else 2
	if _powdering:
		face_n = maxi(face_n, 2 + int(_powder_face_build * 3.0))
		body_n = maxi(body_n, 2 + int(_powder_face_build * 2.0))
	for _i in face_n:
		_spawn_powder_blob("face")
	for _i in body_n:
		_spawn_powder_blob("body")
	if is_leaving:
		return false
	if _powdering:
		return false
	_powder_hit = true
	_powdering = true
	_powder_stand_t = 0.0
	_powder_panic_t = 0.0
	_powder_drip_cool = 0.0
	_powder_knock_x = 0.0
	_powder_knock_z = 0.0
	_begin_powder_stand()
	return true


func apply_ext_spray_push(delta: float, zone: String = "body") -> void:
	## Continuous knock-back while the extinguisher cone hits them.
	if is_ragdoll or is_leaving:
		return
	var push_z := 1.55 if zone == "face" else 0.95
	_powder_knock_z += delta * push_z
	_powder_knock_x += randf_range(-delta * 0.42, delta * 0.42)
	_powder_knock_x = clampf(_powder_knock_x, -0.65, 0.65)
	_powder_knock_z = clampf(_powder_knock_z, 0.0, 2.4)
	global_position.z = clampf(global_position.z + delta * push_z * 0.62, _wait_z() - 0.08, MATTE_FRONT_Z_MAX - 0.12)
	global_position.x = clampf(global_position.x + randf_range(-delta * 0.22, delta * 0.22), _home_x - 0.55, _home_x + 0.55)


func _begin_powder_stand() -> void:
	## Freeze — throw hands up while powder piles on face + torso.
	stop_order_clock()
	is_waiting = false
	_shake_time = 0.0
	_shake_amp = 0.0
	global_position.y = STAND_Y
	global_position.z = _wait_z()
	speech = "Agh! My face!! Never coming back!"
	_set_mood("mad")
	if _anim_player:
		_anim_player.stop()
		_anim_player.active = false
	_apply_hands_up_pose(1.0)
	if _body:
		_body.scale = Vector3.ONE * CHAR_SCALE
		_body.position.y = _base_body_y
		_body.rotation_degrees.x = 0.0
	if _bubble:
		_bubble.text = speech
		_bubble.visible = true
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false


func _update_powder_stand(delta: float) -> void:
	_powder_stand_t += delta
	_powder_panic_t += delta
	global_position.y = STAND_Y
	_powder_knock_x = lerpf(_powder_knock_x, 0.0, delta * 1.35)
	_powder_knock_z = lerpf(_powder_knock_z, 0.0, delta * 0.95)
	var wob := sin(_powder_panic_t * 16.0) * 0.05
	global_position.x = _home_x + wob + _powder_knock_x
	global_position.z = clampf(_wait_z() + _powder_knock_z, _wait_z(), MATTE_FRONT_Z_MAX - 0.15)
	if _body:
		_body.scale = Vector3.ONE * CHAR_SCALE
		_body.position.y = _base_body_y + absf(sin(_powder_panic_t * 10.0)) * 0.015
		_body.rotation_degrees.x = sin(_powder_panic_t * 9.0) * 3.0
		_body.rotation_degrees.z = sin(_powder_panic_t * 13.0) * 4.0
	_apply_hands_up_pose(1.0)
	## Keep dripping — bias toward the face as it gets coated.
	_powder_drip_cool -= delta
	if _powder_drip_cool <= 0.0:
		_powder_drip_cool = 0.07
		var face_drips := 2 + int(_powder_face_build * 3.0)
		for _i in face_drips:
			_spawn_powder_blob("face")
		_spawn_powder_blob("body")
		_spawn_powder_blob("body")
		if randf() < 0.45:
			_spawn_powder_blob("body")
	if _powder_stand_t >= POWDER_STAND_SEC:
		_powdering = false
		leave_powdered()


func leave_powdered() -> void:
	## After the stand — wobble off angry with powder still stuck on.
	if is_ragdoll:
		return
	if is_leaving:
		return
	_powdering = false
	stop_order_clock()
	is_leaving = true
	is_waiting = false
	_leave_spin = 0.0
	_leave_turned = false
	_leave_yaw_from = rotation_degrees.y
	global_position.y = STAND_Y
	speech = "I'm calling the health department!!"
	_set_mood("mad")
	if _anim_player:
		_anim_player.stop()
		_anim_player.active = false
	_apply_hands_up_pose(1.0)
	if _body:
		_body.scale = Vector3.ONE * CHAR_SCALE
		_body.position.y = _base_body_y
	if _bubble:
		_bubble.text = speech
		_bubble.visible = true
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	_begin_leave_fade()
	get_tree().create_timer(1.2).timeout.connect(func():
		if not is_instance_valid(self):
			return
		if _bubble:
			_bubble.visible = false
		if _bubble_bg:
			_bubble_bg.visible = false
	)


func get_shot(shot_from: Vector3, shot_dir: Vector3) -> bool:
	## Returns true on the first fatal hit (caller should drop the ticket / queue).
	_spawn_blood_splash(shot_dir)
	if is_ragdoll:
		## Extra hits: blood + harder shove / twist — also keep the body around longer.
		_ragdoll_t = minf(_ragdoll_t, RAGDOLL_ACTIVE_SEC * 0.35)
		var nudge := shot_dir.normalized()
		if nudge.length_squared() < 0.01:
			nudge = Vector3(0, 0, 1)
		nudge.y = 0.0
		if nudge.length_squared() < 0.01:
			nudge = Vector3(0, 0, 1)
		nudge = nudge.normalized()
		nudge.z = maxf(nudge.z, 0.55)
		nudge = nudge.normalized()
		_ragdoll_vel += nudge * randf_range(2.8, 4.2) + Vector3(0, randf_range(0.8, 1.4), 0)
		_ragdoll_vel.x = clampf(_ragdoll_vel.x, -7.0, 7.0)
		_ragdoll_vel.z = clampf(_ragdoll_vel.z, -2.0, 9.0)
		_ragdoll_ang += Vector3(
			randf_range(-220.0, 220.0),
			randf_range(-280.0, 280.0),
			randf_range(-200.0, 200.0)
		)
		_bump_noodle_impulse()
		return false
	stop_order_clock()
	is_ragdoll = true
	is_leaving = true
	is_waiting = false
	_ragdoll_t = 0.0
	_ragdoll_lie = 0.0
	_set_mood("mad")
	if _anim_player:
		_anim_player.stop()
		_anim_player.active = false
	_anim_state = ""
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	## Blast them backward into the street with a hard twist.
	var push := shot_dir.normalized()
	if push.length_squared() < 0.01:
		push = (global_position - shot_from).normalized()
	push.y = 0.0
	if push.length_squared() < 0.01:
		push = Vector3(0, 0, 1)
	push = push.normalized()
	## Prefer street-ward (+Z) so they fly away from the truck window.
	push.z = maxf(push.z, 0.65)
	push = push.normalized()
	_ragdoll_vel = push * randf_range(6.2, 8.8) + Vector3(0.0, randf_range(2.6, 3.8), 0.0)
	var yaw_sign := 1.0 if randf() < 0.5 else -1.0
	var roll_sign := 1.0 if randf() < 0.5 else -1.0
	_ragdoll_ang = Vector3(
		randf_range(160.0, 280.0), ## tumble over backward
		yaw_sign * randf_range(180.0, 340.0), ## spin / twist
		roll_sign * randf_range(120.0, 240.0) ## barrel roll
	)
	if _body:
		_body.position.y = _base_body_y
		_body.rotation_degrees = Vector3.ZERO
	_cache_skeleton()
	_init_noodle_ragdoll(push)
	return true


func _cache_skeleton() -> void:
	if _skeleton != null and is_instance_valid(_skeleton):
		return
	if _body == null:
		return
	_skeleton = _body.find_child("Skeleton3D", true, false) as Skeleton3D


func _init_noodle_ragdoll(shot_dir: Vector3) -> void:
	_ragdoll_bone_phase.clear()
	for bn in [
		"LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
		"LeftHand", "RightHand", "Head", "Neck", "UpperChest", "Chest", "Spine"
	]:
		_ragdoll_bone_phase[bn] = randf() * TAU
	## Shot from the right → right arm whips harder (and vice versa).
	var side := clampf(shot_dir.x, -1.0, 1.0)
	_ragdoll_bone_phase["RightArm"] = side * PI * 0.5 + randf_range(-0.4, 0.4)
	_ragdoll_bone_phase["LeftArm"] = -side * PI * 0.5 + randf_range(-0.4, 0.4)
	_update_noodle_skeleton(0.0)


func _bump_noodle_impulse() -> void:
	for bn in _ragdoll_bone_phase.keys():
		_ragdoll_bone_phase[bn] = float(_ragdoll_bone_phase[bn]) + randf_range(-1.2, 1.2)


func _noodle_bone(bone_name: String, base: Vector3, t: float, speed: float, flop: float) -> void:
	if not _panic_bones.has(bone_name):
		return
	var phase := float(_ragdoll_bone_phase.get(bone_name, 0.0))
	var w1 := sin(t * speed + phase) * deg_to_rad(42.0) * flop
	var w2 := cos(t * speed * 1.41 + phase * 1.6) * deg_to_rad(32.0) * flop
	var w3 := sin(t * speed * 0.77 + phase * 2.1) * deg_to_rad(24.0) * flop
	_set_panic_bone_rot(bone_name, base + Vector3(w1, w2 * 0.45, w3))


func _update_noodle_skeleton(_delta: float) -> void:
	## Live noodly limbs — arms swing on damped sines instead of locking in rest pose.
	_cache_skeleton()
	_cache_panic_bones()
	if _skeleton == null:
		return
	_skeleton.reset_bone_poses()
	var flop := clampf(1.0 - _ragdoll_t * 0.065, 0.4, 1.0)
	var t := _ragdoll_t
	var sway := sin(t * 2.6) * deg_to_rad(26.0) * flop
	var sway2 := cos(t * 3.4) * deg_to_rad(20.0) * flop
	## Arms hang out and flap — big elbow/knee bends.
	_noodle_bone("RightArm", Vector3(deg_to_rad(28.0) + sway, deg_to_rad(6.0), deg_to_rad(112.0) + sway2), t, 2.35, flop)
	_noodle_bone("RightForeArm", Vector3(deg_to_rad(-105.0) + sway2 * 1.6, deg_to_rad(10.0), deg_to_rad(18.0)), t, 3.9, flop)
	_noodle_bone("RightHand", Vector3(deg_to_rad(-32.0), deg_to_rad(8.0), deg_to_rad(42.0) + sway), t, 4.5, flop)
	_noodle_bone("LeftArm", Vector3(deg_to_rad(22.0) - sway, deg_to_rad(-5.0), deg_to_rad(-108.0) - sway2), t, 2.2, flop)
	_noodle_bone("LeftForeArm", Vector3(deg_to_rad(-98.0) - sway2 * 1.5, deg_to_rad(-8.0), deg_to_rad(-14.0)), t, 3.7, flop)
	_noodle_bone("LeftHand", Vector3(deg_to_rad(-28.0), deg_to_rad(-6.0), deg_to_rad(-38.0) - sway), t, 4.3, flop)
	## Torso + head loosely follow the flop.
	_noodle_bone("Spine", Vector3(deg_to_rad(10.0) + sway * 0.35, sway2 * 0.2, 0.0), t, 1.6, flop * 0.55)
	_noodle_bone("Chest", Vector3(deg_to_rad(8.0) + sway * 0.3, 0.0, sway2 * 0.25), t, 1.8, flop * 0.5)
	_noodle_bone("UpperChest", Vector3(deg_to_rad(6.0) + sway * 0.25, 0.0, sway2 * 0.2), t, 2.0, flop * 0.45)
	_noodle_bone("Neck", Vector3(deg_to_rad(-14.0) + sway * 0.4, sway2 * 0.35, 0.0), t, 2.4, flop * 0.5)
	_noodle_bone("Head", Vector3(deg_to_rad(-18.0) + sway * 0.55, sway2 * 0.4, sway * 0.3), t, 2.8, flop * 0.55)


func _apply_limp_skeleton(amount: float = 1.0) -> void:
	## Legacy entry — noodle ragdoll replaces the old stiff random twist.
	_init_noodle_ragdoll(Vector3(0, 0, 1))


func _spawn_blood_splash(shot_dir: Vector3) -> void:
	## Red splash burst out of the torso.
	var fx := GPUParticles3D.new()
	fx.name = "BloodSplash"
	fx.amount = 42
	fx.lifetime = 0.55
	fx.one_shot = true
	fx.explosiveness = 1.0
	fx.randomness = 0.7
	fx.emitting = true
	fx.position = Vector3(0.0, 0.85, 0.05)
	fx.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pmat := ParticleProcessMaterial.new()
	var out := shot_dir.normalized()
	if out.length_squared() < 0.01:
		out = Vector3(0, 0.2, 1)
	pmat.direction = Vector3(out.x, 0.35, out.z).normalized()
	pmat.spread = 55.0
	pmat.initial_velocity_min = 2.2
	pmat.initial_velocity_max = 5.5
	pmat.gravity = Vector3(0, -9.0, 0)
	pmat.damping_min = 1.0
	pmat.damping_max = 2.5
	pmat.scale_min = 0.35
	pmat.scale_max = 1.1
	pmat.color = Color(0.75, 0.05, 0.05, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(0.95, 0.12, 0.08, 0.0),
		Color(0.85, 0.05, 0.05, 1.0),
		Color(0.55, 0.02, 0.02, 0.75),
		Color(0.25, 0.0, 0.0, 0.0),
	])
	var gtex := GradientTexture1D.new()
	gtex.gradient = grad
	pmat.color_ramp = gtex
	fx.process_material = pmat
	var dm := SphereMesh.new()
	dm.radius = 0.028
	dm.height = 0.056
	fx.draw_pass_1 = dm
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = Color(0.8, 0.05, 0.05, 0.95)
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.disable_receive_shadows = true
	fx.material_override = draw
	add_child(fx)
	_blood_bursts.append(fx)
	## A few bigger flying blobs for splash read.
	for i in 6:
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var rad := 0.03 + randf() * 0.045
		sphere.radius = rad
		sphere.height = rad * 2.0
		blob.mesh = sphere
		blob.position = Vector3(randf_range(-0.08, 0.08), 0.75 + randf() * 0.25, randf_range(-0.05, 0.1))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.7, 0.04, 0.04, 0.92)
		mat.disable_receive_shadows = true
		blob.material_override = mat
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)
		var fly := out * randf_range(1.2, 2.4) + Vector3(randf_range(-0.8, 0.8), randf_range(1.5, 3.0), randf_range(-0.4, 0.6))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(blob, "position", blob.position + fly, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(blob, "scale", Vector3.ONE * 0.15, 0.45)
		tw.chain().tween_callback(blob.queue_free)
	## Cleanup particle node after it finishes.
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)


func _update_ragdoll(delta: float) -> void:
	_ragdoll_t += delta
	var active := _ragdoll_t < RAGDOLL_ACTIVE_SEC
	var twisting := _ragdoll_t < RAGDOLL_TWIST_SEC
	_update_noodle_skeleton(delta)
	_ragdoll_vel.y -= 15.5 * delta
	global_position += _ragdoll_vel * delta
	if twisting:
		## Softer tumble — limbs do most of the flop.
		rotation_degrees.x += _ragdoll_ang.x * delta * 0.72
		rotation_degrees.y += _ragdoll_ang.y * delta * 0.85
		rotation_degrees.z += _ragdoll_ang.z * delta * 0.65
		if _body:
			_body.rotation_degrees.x += _ragdoll_ang.x * delta * 0.22
			_body.rotation_degrees.z += _ragdoll_ang.z * delta * 0.28
	else:
		## Ease onto their back but keep a little slack.
		_ragdoll_lie = minf(1.0, _ragdoll_lie + delta * 1.35)
		rotation_degrees.x = lerpf(rotation_degrees.x, 78.0 * _ragdoll_lie, 1.0 - exp(-delta * 3.5))
		rotation_degrees.y += _ragdoll_ang.y * delta * 0.28
		rotation_degrees.z = lerpf(rotation_degrees.z, clampf(_ragdoll_ang.z * 0.18, -48.0, 48.0), 1.0 - exp(-delta * 3.0))
		if _body:
			_body.rotation_degrees.x = lerpf(_body.rotation_degrees.x, 16.0 * _ragdoll_lie, 1.0 - exp(-delta * 3.5))
			_body.rotation_degrees.z = lerpf(_body.rotation_degrees.z, clampf(_ragdoll_ang.z * 0.1, -28.0, 28.0), 1.0 - exp(-delta * 3.0))
	## Never slip behind the street matte painting.
	if global_position.z > MATTE_FRONT_Z_MAX:
		global_position.z = MATTE_FRONT_Z_MAX
		_ragdoll_vel.z = -absf(_ragdoll_vel.z) * 0.35
	## Soft land — no bounce storm.
	if global_position.y < STAND_Y:
		global_position.y = STAND_Y
		if _ragdoll_vel.y < 0.0:
			_ragdoll_vel.y *= -0.12
			_ragdoll_vel.x *= 0.68
			_ragdoll_vel.z *= 0.68
			_ragdoll_ang *= 0.5
			if absf(_ragdoll_vel.y) < 0.4:
				_ragdoll_vel.y = 0.0
	_ragdoll_ang *= 1.0 - delta * (1.6 if twisting else (2.6 if active else 6.0))
	_ragdoll_vel.x *= 1.0 - delta * (1.1 if active else 3.5)
	_ragdoll_vel.z *= 1.0 - delta * (1.0 if active else 3.5)
	if not active and _ragdoll_t > RAGDOLL_ACTIVE_SEC + RAGDOLL_DESPAWN_SEC:
		queue_free()
	if global_position.y < -2.0:
		queue_free()


func _cache_panic_bones() -> void:
	if not _panic_bones.is_empty():
		return
	_cache_skeleton()
	if _skeleton == null:
		return
	for i in _skeleton.get_bone_count():
		var bn := _skeleton.get_bone_name(i)
		_panic_bones[bn] = i


func _ensure_powder_mounts() -> void:
	## Only cache skeleton — blobs are now parented to _body with manual offsets.
	_cache_panic_bones()
	_cache_skeleton()


func _head_pos_in_body() -> Vector3:
	if _skeleton == null or _body == null:
		return Vector3(0.0, 1.75, 0.0)
	var idx := int(_panic_bones.get("Head", -1))
	if idx < 0:
		return Vector3(0.0, 1.75, 0.0)
	var head_global := (_skeleton.global_transform * _skeleton.get_bone_global_pose(idx)).origin
	return _body.to_local(head_global)


func _chest_pos_in_body() -> Vector3:
	if _skeleton == null or _body == null:
		return Vector3(0.0, 1.1, 0.0)
	var bone_name := "UpperChest" if _panic_bones.has("UpperChest") else "Chest"
	var idx := int(_panic_bones.get(bone_name, -1))
	if idx < 0:
		return Vector3(0.0, 1.1, 0.0)
	var chest_global := (_skeleton.global_transform * _skeleton.get_bone_global_pose(idx)).origin
	return _body.to_local(chest_global)


func _powder_parent_for_zone(_zone: String) -> Node3D:
	return _body if _body != null else self


func _reset_skeleton_pose() -> void:
	_cache_skeleton()
	if _skeleton == null:
		return
	_skeleton.reset_bone_poses()


func _set_panic_bone_rot(bone_name: String, euler: Vector3) -> void:
	var i := int(_panic_bones.get(bone_name, -1))
	if i < 0 or _skeleton == null:
		return
	_skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(euler))


func _apply_hands_up_pose(strength: float) -> void:
	## Arms raised beside the head — rotate in bone-local space (Kenney T-pose).
	_cache_panic_bones()
	if _skeleton == null:
		return
	var s := clampf(strength, 0.0, 1.0)
	_skeleton.reset_bone_poses()
	if s <= 0.01:
		return
	## Negative Z lifts the left arm upward; positive Z mirrors for the right.
	_set_panic_bone_rot("LeftArm", Vector3(deg_to_rad(-8.0 * s), 0.0, deg_to_rad(-82.0 * s)))
	_set_panic_bone_rot("RightArm", Vector3(deg_to_rad(-8.0 * s), 0.0, deg_to_rad(82.0 * s)))
	_set_panic_bone_rot("LeftForeArm", Vector3(deg_to_rad(-36.0 * s), 0.0, 0.0))
	_set_panic_bone_rot("RightForeArm", Vector3(deg_to_rad(-36.0 * s), 0.0, 0.0))


func _apply_eat_hands_pose(strength: float) -> void:
	## Hands up toward the window — ready to catch / shove the burger in.
	_cache_panic_bones()
	if _skeleton == null:
		return
	var s := clampf(strength, 0.0, 1.0)
	_skeleton.reset_bone_poses()
	if s <= 0.01:
		return
	_set_panic_bone_rot("LeftArm", Vector3(deg_to_rad(-42.0 * s), deg_to_rad(18.0 * s), deg_to_rad(-68.0 * s)))
	_set_panic_bone_rot("RightArm", Vector3(deg_to_rad(-42.0 * s), deg_to_rad(-18.0 * s), deg_to_rad(68.0 * s)))
	_set_panic_bone_rot("LeftForeArm", Vector3(deg_to_rad(-58.0 * s), deg_to_rad(8.0 * s), 0.0))
	_set_panic_bone_rot("RightForeArm", Vector3(deg_to_rad(-58.0 * s), deg_to_rad(-8.0 * s), 0.0))
	_set_panic_bone_rot("LeftHand", Vector3(deg_to_rad(-12.0 * s), 0.0, deg_to_rad(-20.0 * s)))
	_set_panic_bone_rot("RightHand", Vector3(deg_to_rad(-12.0 * s), 0.0, deg_to_rad(20.0 * s)))


func begin_catch_burger() -> void:
	## Hands up + lean in while the burger flies.
	if is_leaving or is_ragdoll:
		return
	_eating = true
	_eat_lean_x = -14.0
	_set_mood("cheer")
	if _anim_player:
		_anim_player.stop()
	_apply_eat_hands_pose(1.0)
	if _body:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_body, "rotation_degrees:x", _eat_lean_x, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "position:y", _base_body_y + 0.03, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func chomp_burger() -> void:
	## Sharp bite at contact — squash, hop, then settle while chewing.
	if not is_instance_valid(self):
		return
	_set_mood("cheer")
	_apply_eat_hands_pose(1.0)
	if _body == null:
		return
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3(CHAR_SCALE * 1.1, CHAR_SCALE * 0.82, CHAR_SCALE * 1.1), 0.05)
	tw.parallel().tween_property(_body, "rotation_degrees:x", _eat_lean_x - 6.0, 0.05)
	tw.tween_property(_body, "scale", Vector3.ONE * CHAR_SCALE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_body, "rotation_degrees:x", _eat_lean_x + 2.0, 0.14)
	tw.parallel().tween_property(_body, "position:y", _base_body_y + 0.08, 0.08)
	tw.tween_property(_body, "position:y", _base_body_y, 0.16).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(_body, "rotation_degrees:x", -4.0, 0.16)


func finish_catch_burger() -> void:
	_eating = false
	_eat_lean_x = 0.0
	_reset_skeleton_pose()
	if _body and is_instance_valid(_body):
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_body, "rotation_degrees:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_body, "scale", Vector3.ONE * CHAR_SCALE, 0.12)
		tw.tween_property(_body, "position:y", _base_body_y, 0.18)
	if _anim_player:
		_anim_player.active = true


func _spawn_powder_blob(zone: String) -> void:
	## White spheres parented to _body — sized in local space (body is CHAR_SCALE).
	_ensure_powder_mounts()
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	## Local radii ~0.07–0.16 → world ~0.04–0.09 after CHAR_SCALE (readable clumps).
	var rad := 0.07 + randf() * 0.09
	if zone == "face":
		rad = 0.055 + randf() * 0.065
	## Buildup makes later clumps a bit bigger.
	rad *= 1.0 + _powder_face_build * 0.55
	sphere.radius = rad
	sphere.height = rad * 2.0
	sphere.radial_segments = 8
	sphere.rings = 5
	blob.mesh = sphere
	var anchor: Vector3
	if zone == "face":
		anchor = _head_pos_in_body()
		blob.position = anchor + Vector3(
			randf_range(-0.06, 0.06),
			randf_range(-0.04, 0.07),
			randf_range(0.03, 0.09)
		)
	else:
		anchor = _chest_pos_in_body()
		blob.position = anchor + Vector3(
			randf_range(-0.11, 0.11),
			randf_range(-0.09, 0.10),
			randf_range(0.02, 0.10)
		)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.sorting_offset = 8.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.97, 0.98, 1.0, 0.95)
	mat.roughness = 0.75
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.render_priority = 12
	blob.material_override = mat
	var parent := _powder_parent_for_zone(zone)
	parent.add_child(blob)
	var start_s := 0.85 + randf() * 0.45
	blob.scale = Vector3.ONE * start_s
	var life := 6.0 + randf() * 3.0
	_powder_blobs.append({
		"mesh": blob,
		"mat": mat,
		"life": life,
		"max_life": life,
		"start_scale": start_s,
		"zone": zone,
	})
	while _powder_blobs.size() > 160:
		var old: Dictionary = _powder_blobs.pop_front()
		var m = old.get("mesh")
		if m != null and is_instance_valid(m):
			m.queue_free()


func _spawn_powder_blob_on_body() -> void:
	_spawn_powder_blob("body")


func _update_powder_blobs(delta: float) -> void:
	var i := 0
	while i < _powder_blobs.size():
		var item: Dictionary = _powder_blobs[i]
		var mesh = item.get("mesh")
		if mesh == null or not is_instance_valid(mesh):
			_powder_blobs.remove_at(i)
			continue
		item["life"] = float(item["life"]) - delta
		var life: float = float(item["life"])
		var max_life: float = maxf(0.05, float(item["max_life"]))
		var t := clampf(life / max_life, 0.0, 1.0)
		## Stick around — only mild shrink/fade so buildup stays readable.
		var s: float = float(item["start_scale"]) * (0.78 + 0.22 * t)
		mesh.scale = Vector3.ONE * s
		var mat = item.get("mat") as StandardMaterial3D
		if mat != null:
			var c: Color = mat.albedo_color
			c.a = 0.55 + 0.40 * t
			mat.albedo_color = c
		if life <= 0.0:
			mesh.queue_free()
			_powder_blobs.remove_at(i)
			continue
		_powder_blobs[i] = item
		i += 1


func leave_mad() -> void:
	stop_order_clock()
	_eating = false
	_eat_lean_x = 0.0
	is_leaving = true
	is_waiting = false
	_leave_spin = 0.0
	_leave_turned = false
	_leave_yaw_from = rotation_degrees.y
	global_position.y = STAND_Y
	_set_mood("mad")
	_clear_antsy_wait_pose()
	_reset_skeleton_pose()
	_play_anim("idle")
	if _body:
		_body.rotation_degrees.x = 0.0
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	if _bar_root:
		_bar_root.visible = false
	if _bar_bg:
		_bar_bg.visible = false
	if _bar_fill:
		_bar_fill.visible = false
	_begin_leave_fade()
	get_tree().create_timer(0.55).timeout.connect(func():
		if is_instance_valid(self):
			_set_mood("dead")
	)



func leave_after_dispute() -> void:
	## Refund / take-the-food outcomes — walk off angry, no payout.
	clear_complaint()
	served.emit(self, 0)
	leave_mad()


func patience_ratio() -> float:
	return clampf(patience / maxf(0.01, patience_max), 0.0, 1.0)


func feed_bacon_snack(restore_ratio: float = 0.10) -> bool:
	## Dragged bacon treat — bump patience up to max (10% of bar by default).
	if not is_waiting or is_leaving or is_ragdoll:
		return false
	if patience >= patience_max - 0.05:
		return false
	var bump := patience_max * clampf(restore_ratio, 0.0, 1.0)
	patience = minf(patience_max, patience + bump)
	_refresh_patience_bar()
	bounce_happy()
	if _bubble:
		_bubble.text = "Mmm… bacon!"
		_bubble.visible = true
		_bubble.modulate = Color(1.0, 0.92, 0.75)
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(self) and _bubble and is_waiting:
				_bubble.visible = false
		)
	return true


## Serve fly animation target — roughly lip height in the service window.
func mouth_global() -> Vector3:
	if is_disguise_cat:
		var mouth_local := _disguise_mustache_local()
		return global_position + Vector3(mouth_local.x, mouth_local.y, mouth_local.z + 0.12)
	return global_position + Vector3(0.0, 1.18, 0.06)


func _disguise_mustache_local() -> Vector3:
	## Same snout placement as the window cat, scaled up for our mesh size + plant lift.
	return Vector3(
		_WINDOW_CAT_MOUTH.x,
		DISGUISE_CAT_MESH_Y + _WINDOW_CAT_MOUTH.y * (DISGUISE_CAT_SCALE_Y / _WINDOW_CAT_MESH_SCALE),
		_WINDOW_CAT_MOUTH.z * (DISGUISE_CAT_SCALE_Z / _WINDOW_CAT_MESH_SCALE)
	)


func apply_disguise_cat_look() -> void:
	## Swap the toon for the street cat + a cheap fake mustache.
	is_disguise_cat = true
	global_position.z = _wait_z()
	global_position.y = STAND_Y
	personality = "quiet"
	chatter = ""
	speech = "One triple patty burger… please."
	if _bubble:
		_bubble.text = speech
	## Hide the human toon — cat mesh parents to this root so CHAR_SCALE never shrinks it.
	if _body != null and is_instance_valid(_body):
		_body.visible = false
	const CAT_PATH := "res://assets/cat/cat.fbx"
	if ResourceLoader.exists(CAT_PATH):
		var packed := load(CAT_PATH) as PackedScene
		if packed != null:
			_disguise_cat_mesh = packed.instantiate() as Node3D
			if _disguise_cat_mesh != null:
				_disguise_cat_mesh.name = "DisguiseCatMesh"
				_disguise_cat_mesh.scale = Vector3(DISGUISE_CAT_SCALE_X, DISGUISE_CAT_SCALE_Y, DISGUISE_CAT_SCALE_Z)
				_disguise_cat_mesh.position = Vector3(0.0, DISGUISE_CAT_MESH_Y, 0.06)
				_disguise_cat_mesh.rotation_degrees = Vector3.ZERO
				add_child(_disguise_cat_mesh)
				## Same black street-cat retint as the window cat (raw FBX is purple).
				_retint_disguise_cat_fur(_disguise_cat_mesh)
				var anim := _disguise_cat_mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim != null and anim.has_animation("CINEMA_4D_Main"):
					anim.stop()
					anim.active = false
	_build_fake_mustache()
	_build_disguise_top_hat()


func _retint_disguise_cat_fur(node: Node) -> void:
	## Kill the stock purple cast — match window_cat black fur + glossy eyes.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var is_eye := str(mi.name).to_lower().contains("eye")
		var surf_count := 0
		if mi.mesh != null:
			surf_count = mi.mesh.get_surface_count()
		if surf_count <= 0:
			surf_count = maxi(1, mi.get_surface_override_material_count())
		for si in surf_count:
			var base: Material = mi.get_active_material(si) if mi.mesh != null and si < mi.mesh.get_surface_count() else null
			if base == null:
				base = mi.material_override
			var sm: StandardMaterial3D
			if base is StandardMaterial3D:
				sm = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			elif base == null:
				sm = StandardMaterial3D.new()
			else:
				continue
			if is_eye:
				_disguise_make_eye_glossy(sm, si, base)
			else:
				_disguise_make_fur_dark(sm)
			if mi.mesh != null and si < mi.mesh.get_surface_count():
				mi.set_surface_override_material(si, sm)
			else:
				mi.material_override = sm
	for child in node.get_children():
		_retint_disguise_cat_fur(child)


func _disguise_make_eye_glossy(sm: StandardMaterial3D, surf_i: int, base: Material) -> void:
	var src := sm.albedo_color
	if base is StandardMaterial3D:
		src = (base as StandardMaterial3D).albedo_color
	var name_hint := ""
	if base != null:
		name_hint = str(base.resource_name).to_lower()
	var is_yellow := name_hint.contains("yellow") or (src.r > 0.45 and src.g > 0.35 and src.b < 0.45)
	var is_black := name_hint.contains("black") or src.get_luminance() < 0.25
	if is_yellow or (not is_black and surf_i == 0 and src.g > src.b):
		sm.albedo_color = Color(0.95, 0.78, 0.12)
		if sm.albedo_texture != null:
			sm.albedo_color = Color(1.0, 0.92, 0.55)
	else:
		sm.albedo_color = Color(0.04, 0.035, 0.03)
		if sm.albedo_texture != null:
			sm.albedo_color = Color(0.12, 0.1, 0.09)
	sm.metallic = 0.15
	sm.roughness = 0.08
	sm.clearcoat_enabled = true
	sm.clearcoat = 1.0
	sm.clearcoat_roughness = 0.04
	sm.rim_enabled = true
	sm.rim = 0.45
	sm.rim_tint = 0.35
	sm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX


func _disguise_make_fur_dark(sm: StandardMaterial3D) -> void:
	var c := sm.albedo_color
	var gray := (c.r + c.g + c.b) / 3.0
	c.r = lerpf(c.r, gray, 0.35)
	c.g = lerpf(c.g, gray, 0.2)
	c.b = lerpf(c.b, gray * 0.85, 0.7)
	if sm.albedo_texture != null:
		c = Color(0.38, 0.34, 0.30) * Color(minf(c.r + 0.15, 1.0), minf(c.g + 0.12, 1.0), minf(c.b + 0.08, 1.0))
	else:
		c = c.darkened(0.42)
		c.b *= 0.75
	sm.albedo_color = c
	sm.metallic = minf(sm.metallic, 0.05)
	sm.roughness = maxf(sm.roughness, 0.72)


func _build_fake_mustache() -> void:
	if _mustache_root != null and is_instance_valid(_mustache_root):
		_mustache_root.queue_free()
	_mustache_root = Node3D.new()
	_mustache_root.name = "FakeMustache"
	## Parent to the customer root (same trick as window-cat mouth burger) so the
	## mustache sits on the snout — not scaled into the sky by the mesh transform.
	_mustache_root.position = _disguise_mustache_local()
	add_child(_mustache_root)
	var mustache_s := DISGUISE_CAT_SCALE_Y / _WINDOW_CAT_MESH_SCALE
	var card := MeshInstance3D.new()
	card.name = "MustacheCard"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25 * mustache_s, 0.156 * mustache_s)
	card.mesh = quad
	card.position = Vector3(0.0, -0.016 * mustache_s, 0.040 * mustache_s)
	var card_mat := StandardMaterial3D.new()
	card_mat.albedo_texture = load(DISGUISE_MUSTACHE_TEX) as Texture2D
	card_mat.albedo_color = Color.WHITE
	card_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_mat.alpha_scissor_threshold = 0.08
	card_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	card_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	card_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.material_override = card_mat
	_mustache_root.add_child(card)


func _disguise_hat_local() -> Vector3:
	return Vector3(
		0.0,
		DISGUISE_CAT_MESH_Y + 0.532 * (DISGUISE_CAT_SCALE_Y / _WINDOW_CAT_MESH_SCALE),
		0.01 * (DISGUISE_CAT_SCALE_Z / _WINDOW_CAT_MESH_SCALE)
	)


func _build_disguise_top_hat() -> void:
	if _disguise_hat_root != null and is_instance_valid(_disguise_hat_root):
		_disguise_hat_root.queue_free()
	_disguise_hat_root = Node3D.new()
	_disguise_hat_root.name = "DisguiseTopHat"
	_disguise_hat_root.position = _disguise_hat_local()
	_disguise_hat_root.rotation_degrees = Vector3(-5.0, 0.0, 3.0)
	add_child(_disguise_hat_root)

	var black_mat := StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.012, 0.011, 0.010)
	black_mat.roughness = 0.82
	black_mat.metallic = 0.0
	black_mat.clearcoat_enabled = false
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.22, 0.045, 0.04)
	band_mat.roughness = 0.78
	band_mat.metallic = 0.0

	var s := DISGUISE_CAT_SCALE_Y / _WINDOW_CAT_MESH_SCALE * 1.18
	var brim := MeshInstance3D.new()
	brim.name = "TopHatBrim"
	var brim_mesh := CylinderMesh.new()
	brim_mesh.top_radius = 0.215 * s
	brim_mesh.bottom_radius = 0.215 * s
	brim_mesh.height = 0.022 * s
	brim_mesh.radial_segments = 28
	brim.mesh = brim_mesh
	brim.material_override = black_mat
	_disguise_hat_root.add_child(brim)

	var crown := MeshInstance3D.new()
	crown.name = "TopHatCrown"
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.145 * s
	crown_mesh.bottom_radius = 0.145 * s
	crown_mesh.height = 0.205 * s
	crown_mesh.radial_segments = 28
	crown.mesh = crown_mesh
	crown.material_override = black_mat
	crown.position = Vector3(0.0, 0.106 * s, 0.0)
	_disguise_hat_root.add_child(crown)

	var cap := MeshInstance3D.new()
	cap.name = "TopHatTopCap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.148 * s
	cap_mesh.bottom_radius = 0.148 * s
	cap_mesh.height = 0.014 * s
	cap_mesh.radial_segments = 28
	cap.mesh = cap_mesh
	cap.material_override = black_mat
	cap.position = Vector3(0.0, 0.214 * s, 0.0)
	_disguise_hat_root.add_child(cap)

	var band := MeshInstance3D.new()
	band.name = "TopHatBand"
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.149 * s
	band_mesh.bottom_radius = 0.149 * s
	band_mesh.height = 0.028 * s
	band_mesh.radial_segments = 28
	band.mesh = band_mesh
	band.material_override = band_mat
	band.position = Vector3(0.0, 0.052 * s, 0.0)
	_disguise_hat_root.add_child(band)


func drop_mustache_and_flee() -> void:
	## Clicked the freeloader — mustache falls off, busted, runs.
	if not is_disguise_cat or is_leaving:
		return
	if _mustache_root != null and is_instance_valid(_mustache_root):
		var m := _mustache_root
		_mustache_root = null
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "position", m.position + Vector3(0.25, -1.1, 0.35), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "rotation_degrees", Vector3(95.0, 50.0, -30.0), 0.55)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(m):
				m.queue_free()
		)
	if _disguise_hat_root != null and is_instance_valid(_disguise_hat_root):
		var h := _disguise_hat_root
		_disguise_hat_root = null
		var hat_tw := create_tween()
		hat_tw.set_parallel(true)
		hat_tw.tween_property(h, "position", h.position + Vector3(-0.22, -1.0, 0.28), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hat_tw.tween_property(h, "rotation_degrees", Vector3(120.0, -35.0, 45.0), 0.55)
		hat_tw.chain().tween_callback(func() -> void:
			if is_instance_valid(h):
				h.queue_free()
		)
	if _bubble:
		_bubble.text = "MEOW?!"
		_bubble.visible = true
		_bubble.modulate = Color(1.0, 0.45, 0.4)
	served.emit(self, 0)
	leave_mad()


func disguise_bribe_leave() -> void:
	## Fed a treat — they take it and split (still no bill).
	if not is_disguise_cat or is_leaving:
		return
	if _bubble:
		_bubble.text = "…ok bye"
		_bubble.visible = true
	served.emit(self, 0)
	leave_happy()


## Returns {total, base, tip, perfect, wrong, meh}
func receive_burger(
	built: Array,
	patty_mult: float,
	combo: int,
	tip_factor: float,
	fresh_ratio: float = 1.0,
	seasoned: bool = true
) -> Dictionary:
	var result: Dictionary = GameDataScript.compare_orders(built, order)
	last_tip = 0
	last_base_pay = 0
	if float(result.quality) < 0.4:
		react_wrong()
		return {"total": 0, "base": 0, "tip": 0, "perfect": false, "wrong": true, "meh": false}

	var base_pay: int = int(round(
		float(order_value) * float(result.quality) * patty_mult * (1.0 + float(combo) * 0.05)
	))
	base_pay = maxi(base_pay, 1 if float(result.quality) >= 0.55 else 0)
	if base_pay <= 0:
		react_wrong()
		return {"total": 0, "base": 0, "tip": 0, "perfect": false, "wrong": true, "meh": false}

	## Tip for doing a good job: perfect match, good cook, fresh, patient — and seasoned beef.
	var tip_pay := 0
	var perfect: bool = bool(result.perfect)
	var good_job := perfect or float(result.quality) >= 0.9
	var meh := not seasoned
	if good_job and seasoned:
		tip_pay = 2
		if perfect:
			tip_pay += 2
		if patty_mult >= 1.2:
			tip_pay += 2 ## well-cooked patty
		elif patty_mult >= 1.0:
			tip_pay += 1
		if fresh_ratio > 0.7:
			tip_pay += 2 ## nice and fresh
		elif fresh_ratio > 0.4:
			tip_pay += 1
		## Happier customers tip more
		tip_pay = int(round(float(tip_pay) * (0.55 + tip_factor * 1.4) * tip_mood_mult))
		if combo >= 2:
			tip_pay += mini(combo, 4)
		## Tips stay in a tight band — never stingy, never wild.
		tip_pay = clampi(tip_pay, 3, 10)
	elif meh:
		tip_pay = 0

	last_base_pay = base_pay
	last_tip = tip_pay
	var total := base_pay + tip_pay
	if meh:
		complete_serve_meh(total)
	else:
		complete_serve(total)
	return {
		"total": total,
		"base": base_pay,
		"tip": tip_pay,
		"perfect": perfect,
		"wrong": false,
		"meh": meh,
	}


func react_wrong() -> void:
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	served.emit(self, 0)
	leave_mad()


func complete_serve(payout: int) -> void:
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	served.emit(self, payout)
	leave_happy()


func complete_serve_meh(payout: int) -> void:
	if _bubble:
		_bubble.visible = false
	if _bubble_bg:
		_bubble_bg.visible = false
	served.emit(self, payout)
	leave_meh()
