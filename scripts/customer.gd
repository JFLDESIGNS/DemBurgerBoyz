## Stylized Kenney toon customers (CC0) with mood reactions + patience bar.
extends Node3D

const GameDataScript := preload("res://scripts/game_data.gd")
const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const CHAR_SCENE_PATH := "res://assets/characters/Model/characterMedium.fbx"
const CHAR_SKINS: Array[String] = [
	"res://assets/characters/Skins/skaterMaleA.png",
	"res://assets/characters/Skins/skaterFemaleA.png",
	"res://assets/characters/Skins/humanMaleA.png",
	"res://assets/characters/Skins/humanFemaleA.png",
	"res://assets/characters/Skins/criminalMaleA.png",
	"res://assets/characters/Skins/cyborgFemaleA.png",
]
## Kenney medium characters are ~1.8m; shrink to fit the service window.
const CHAR_SCALE := 0.68

signal arrived(customer: Node3D)
signal patience_expired(customer: Node3D)
signal served(customer: Node3D, payout: int)

var order: Array[String] = []
var body_color: Color = Color.WHITE
var patience_max: float = 45.0
var patience: float = 45.0
var target_x: float = 0.0
var lane: int = 0
var is_waiting: bool = false
var is_leaving: bool = false
var order_value: int = 8
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
var _bubble: Label3D
var _bubble_bg: MeshInstance3D
var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D

var _bounce: float = 0.0
var _bobble_phase: float = 0.0
var _mood: String = "happy"
var _shake_time: float = 0.0
var _shake_amp: float = 0.0
var _expr_t: float = 0.0
var _leave_spin: float = 0.0
var _base_body_y: float = 0.0
var _home_x: float = 0.0
var _face_style: int = 0 ## slight variety per customer
var _skin_path: String = ""
static var _face_cache: Dictionary = {} ## legacy; unused with 3D characters
static var _char_scene: PackedScene = null
static var _skin_tex_cache: Dictionary = {} ## path -> Texture2D


func setup(p_order: Array[String], color: Color, p_patience: float, p_lane: int) -> void:
	order = p_order
	body_color = color
	patience_max = p_patience
	patience = p_patience
	lane = p_lane
	order_value = GameDataScript.order_value(order)
	_roll_personality()
	speech = _make_speech()
	_face_style = randi() % 3
	_skin_path = CHAR_SKINS[randi() % CHAR_SKINS.size()]


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
	bg_mesh.size = Vector3(1.6, 0.55, 0.05)
	_bubble_bg.mesh = bg_mesh
	_bubble_bg.position = Vector3(0, 2.05, 0)
	var bgm := StandardMaterial3D.new()
	bgm.albedo_color = Color(1, 1, 1, 0.95)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_bg.material_override = bgm
	_bubble_bg.visible = false
	add_child(_bubble_bg)

	_bubble = Label3D.new()
	_bubble.text = speech
	_bubble.position = Vector3(0, 2.05, 0.04)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color(0.12, 0.12, 0.14)
	_bubble.visible = false
	UiFontsScript.apply_label3d(_bubble, false, 64, 0.099)
	_bubble.outline_modulate = Color.WHITE
	_bubble.outline_size = 5
	add_child(_bubble)

	_bar_bg = MeshInstance3D.new()
	var bg := BoxMesh.new()
	bg.size = Vector3(0.9, 0.08, 0.05)
	_bar_bg.mesh = bg
	_bar_bg.position = Vector3(0, 1.72, 0)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.15, 0.15, 0.15)
	_bar_bg.material_override = bar_mat
	add_child(_bar_bg)

	_bar_fill = MeshInstance3D.new()
	var fill := BoxMesh.new()
	fill.size = Vector3(0.84, 0.06, 0.055)
	_bar_fill.mesh = fill
	_bar_fill.position = Vector3(0, 1.72, 0.01)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("66BB6A")
	_bar_fill.material_override = fm
	add_child(_bar_fill)


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
	return not _char_meshes.is_empty()


func _collect_char_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		_char_meshes.append(n)
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
		sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		sm.roughness = 0.62
		sm.metallic = 0.0
		## Soft toon-ish shading so faces read clean with MSAA.
		sm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		sm.specular_mode = BaseMaterial3D.SPECULAR_TOON
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
	var tint := Color(1, 1, 1, 1)
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
	for mi in _char_meshes:
		if mi == null or not is_instance_valid(mi):
			continue
		var mesh_i := mi as MeshInstance3D
		var sm := mesh_i.material_override as StandardMaterial3D
		if sm == null:
			continue
		sm.albedo_color = tint


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

	if _shake_time > 0.0:
		_shake_time -= delta
		var shake_x := sin(Time.get_ticks_msec() * 0.06) * _shake_amp
		var shake_z := cos(Time.get_ticks_msec() * 0.08) * _shake_amp * 0.45
		global_position.x = _home_x + shake_x
		global_position.z = 2.25 + shake_z
		if _body:
			_body.rotation_degrees.z = shake_x * 35.0
		if _shake_time <= 0.0:
			_shake_amp = 0.0
			if _body:
				_body.rotation_degrees.z = 0.0
			global_position.x = _home_x
			global_position.z = 2.25

	if is_leaving:
		_leave_spin += delta
		global_position.z += delta * 2.4
		global_position.y += delta * 0.25
		if _mood == "cheer":
			## Happy hop away
			if _body:
				_body.position.y = _base_body_y + absf(sin(_leave_spin * 8.0)) * 0.12
				_body.rotation_degrees.y = sin(_leave_spin * 6.0) * 12.0
		else:
			## Mad storm-off wobble
			if _body:
				_body.position.y = _base_body_y + sin(_leave_spin * 10.0) * 0.05
				_body.rotation_degrees.z = sin(_leave_spin * 14.0) * 18.0
		if global_position.z > 14.0:
			queue_free()
		return

	var dx: float = target_x - global_position.x
	if absf(dx) > 0.05 and _shake_time <= 0.0:
		global_position.x += signf(dx) * minf(absf(dx), delta * 1.6)
		_apply_bobble(true)
	elif not is_waiting:
		is_waiting = true
		_bubble.visible = true
		_bubble_bg.visible = true
		arrived.emit(self)
		_apply_bobble(false)
	elif _shake_time <= 0.0:
		_apply_bobble(false)

	_animate_expression(delta)

	if is_waiting and not dialogue_open:
		patience -= delta
		var t: float = clampf(patience / patience_max, 0.0, 1.0)
		_bar_fill.scale = Vector3(t, 1, 1)
		_bar_fill.position.x = -0.42 * (1.0 - t)
		var fm: StandardMaterial3D = _bar_fill.material_override
		if t > 0.55:
			fm.albedo_color = Color("66BB6A")
			_set_mood("happy")
		elif t > 0.28:
			fm.albedo_color = Color("FFCA28")
			_set_mood("ok")
		else:
			fm.albedo_color = Color("EF5350")
			_set_mood("mad")
		if patience <= 0.0:
			leave_mad()
			patience_expired.emit(self)


func _apply_bobble(walking: bool) -> void:
	if _body == null:
		return
	var bob_amp := 0.055 if walking else 0.035
	var sway := 4.5 if walking else 3.0
	_body.position.y = _base_body_y + sin(_bobble_phase) * bob_amp
	_body.rotation_degrees.z = sin(_bobble_phase * 0.85) * sway
	_body.rotation_degrees.x = cos(_bobble_phase * 0.7) * 2.0


func _animate_expression(_delta: float) -> void:
	if is_leaving or _body == null:
		return
	## Subtle breath / mood pulse on the whole character.
	var pulse := 1.0 + sin(_expr_t * 4.5) * 0.012
	if _mood == "mad":
		pulse = 1.0 + sin(_expr_t * 10.0) * 0.02
	elif _mood == "cheer":
		pulse = 1.0 + absf(sin(_expr_t * 7.0)) * 0.03
	_body.scale = Vector3(CHAR_SCALE * pulse, CHAR_SCALE * pulse, CHAR_SCALE * pulse)
	if _face != null:
		_face.scale = Vector3(pulse, pulse, 1.0)


func shake_angry(duration: float = 0.7, amp: float = 0.12) -> void:
	_set_mood("mad")
	_shake_time = duration
	_shake_amp = amp
	## Quick squash punch
	if _body:
		var tw := create_tween()
		tw.tween_property(_body, "scale", Vector3(1.12, 0.88, 1.12), 0.08)
		tw.tween_property(_body, "scale", Vector3.ONE, 0.12)


func bounce_happy() -> void:
	_set_mood("cheer")
	if _body == null:
		return
	var tw := create_tween()
	tw.tween_property(_body, "position:y", _base_body_y + 0.22, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", _base_body_y, 0.18).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(_body, "scale", Vector3(1.08, 0.92, 1.08), 0.1)
	tw.tween_property(_body, "scale", Vector3.ONE, 0.15)


func leave_happy() -> void:
	is_leaving = true
	is_waiting = false
	_set_mood("cheer")
	bounce_happy()
	## Keep the reaction bubble up briefly, then hide
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(self):
			_bubble.visible = false
			_bubble_bg.visible = false
	)


func leave_mad() -> void:
	is_leaving = true
	is_waiting = false
	_set_mood("mad")
	shake_angry(0.75, 0.16)
	get_tree().create_timer(0.55).timeout.connect(func():
		if is_instance_valid(self):
			_set_mood("dead")
			_bubble.visible = false
			_bubble_bg.visible = false
	)



func leave_after_dispute() -> void:
	## Refund / take-the-food outcomes — walk off angry, no payout.
	clear_complaint()
	if _bubble:
		_bubble.visible = true
		_bubble.modulate = Color("C62828")
	served.emit(self, 0)
	leave_mad()


func patience_ratio() -> float:
	return clampf(patience / maxf(0.01, patience_max), 0.0, 1.0)


## Returns {total, base, tip, perfect, wrong}
func receive_burger(built: Array, patty_mult: float, combo: int, tip_factor: float, fresh_ratio: float = 1.0) -> Dictionary:
	var result: Dictionary = GameDataScript.compare_orders(built, order)
	last_tip = 0
	last_base_pay = 0
	if float(result.quality) < 0.4:
		react_wrong()
		return {"total": 0, "base": 0, "tip": 0, "perfect": false, "wrong": true}

	var base_pay: int = int(round(
		float(order_value) * float(result.quality) * patty_mult * (1.0 + float(combo) * 0.05)
	))
	base_pay = maxi(base_pay, 1 if float(result.quality) >= 0.55 else 0)
	if base_pay <= 0:
		react_wrong()
		return {"total": 0, "base": 0, "tip": 0, "perfect": false, "wrong": true}

	## Tip for doing a good job: perfect match, good cook, fresh, patient customer.
	var tip_pay := 0
	var perfect: bool = bool(result.perfect)
	var good_job := perfect or float(result.quality) >= 0.9
	if good_job:
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
		tip_pay = maxi(tip_pay, 1 if perfect else 0)

	last_base_pay = base_pay
	last_tip = tip_pay
	var total := base_pay + tip_pay
	complete_serve(total)
	return {
		"total": total,
		"base": base_pay,
		"tip": tip_pay,
		"perfect": perfect,
		"wrong": false,
	}


func react_wrong() -> void:
	if _bubble:
		_bubble.text = "WRONG!\n>_<"
		_bubble.visible = true
		_bubble.modulate = Color("C62828")
	served.emit(self, 0)
	leave_mad()


func complete_serve(payout: int) -> void:
	if _bubble:
		if last_tip > 0:
			_bubble.text = "Yum!\n+$%d tip!" % last_tip
		else:
			_bubble.text = "Thanks!"
		_bubble.visible = true
		_bubble.modulate = Color("2E7D32")
	served.emit(self, payout)
	leave_happy()
