extends Node
## Host-owned 50-recipe encounter. Normal serving owns the burger flight and station.
const DATA = preload("res://scripts/game_data.gd")
const CUSTOMER = preload("res://scripts/hotdog_boss_customer.gd")
const TOTAL = 50
const MAX_LOSSES = 10
const ORDER_SECONDS = 17.0
const PLACEMENT_FILE = "user://hotdog_boss.cfg"
const VOICE_PITCH = .78
const NET_ID = 1900000050
var game: Node
var customer: Node3D
var phase = ""
var perfect = 0
var mistakes = 0
var recipes: Array = []
var milestone_history: Array[int] = []
var timer = 0.0
var impact_at = -1.0
var pending_result = -1
var suspended: Array = []
var previous_selected: Node3D
var label: Label
var music: AudioStreamPlayer
var clip = ""
var sync_timer = 0.0
var impact_serial = 0
var received_impact = 0
var generation = 0
var boss_position = Vector3(0, -.02, 6.3)
var boss_scale = 1.0
var order_left = ORDER_SECONDS
var ambient_left = 14.0
var chatter_left = 7.0
var voice_left = 0.0
var music_duck_left = 0.0
var music_duck_db = 0.0
var laugh_left = 18.0
var eat_sound_played = false
var effects: AudioStreamPlayer
var sound_streams: Dictionary = {}
var failure_reason = "WRONG BURGER!"
var voice: AudioStreamPlayer
var concrete: AudioStreamPlayer
var impact_sound: AudioStreamPlayer
var street_saved: Array = []
var spectator_presets: Array = []
var spectator_time = 0.0
var shadow_root_visible = true
var shadow_root_saved = false

static func make_recipes(seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var masks: Array[int] = []
	for i in 256: masks.append(i)
	for i in range(masks.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var swap = masks[i]; masks[i] = masks[j]; masks[j] = swap
	var result: Array = []
	for i in TOTAL + MAX_LOSSES:
		var order: Array[String] = ["bun_bottom", "patty"]
		for bit in DATA.TOPPING_ORDER.size():
			if masks[i] & (1 << bit): order.append(DATA.TOPPING_ORDER[bit])
		order.append("bun_top")
		result.append(order)
	return result

func setup(owner_game: Node) -> void:
	game = owner_game
	var config = ConfigFile.new()
	if config.load(PLACEMENT_FILE) == OK:
		boss_position = config.get_value("boss", "position", boss_position)
		boss_scale = clampf(float(config.get_value("boss", "scale", boss_scale)), .3, 3.0)
	name = "HotdogChallenge"
	label = Label.new()
	label.name = "HotdogChallengeStatus"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-270, 65)
	label.size = Vector2(540, 86)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("FFE08A"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI/Root").add_child(label)
	label.hide()
	music = AudioStreamPlayer.new()
	music.name = "ConcreteCrackBoss"
	music.bus = "Master"
	music.volume_db = linear_to_db(.62)
	add_child(music)
	var voice_bus = AudioServer.get_bus_index("BaronBratVoice")
	if voice_bus < 0:
		AudioServer.add_bus(); voice_bus = AudioServer.bus_count-1
		AudioServer.set_bus_name(voice_bus,"BaronBratVoice")
		AudioServer.set_bus_send(voice_bus,"SFX")
		var grit = AudioEffectDistortion.new()
		grit.mode = AudioEffectDistortion.MODE_OVERDRIVE
		grit.drive = .12; grit.keep_hf_hz = 9000.0
		AudioServer.add_bus_effect(voice_bus,grit)
		var space = AudioEffectReverb.new()
		space.room_size = .4; space.damping = .65; space.wet = .14; space.dry = 1.0
		space.predelay_msec = 85.0
		AudioServer.add_bus_effect(voice_bus,space)
		AudioServer.set_bus_effect_enabled(voice_bus,1,false)
	voice = AudioStreamPlayer.new(); voice.bus = "BaronBratVoice"; add_child(voice)
	concrete = AudioStreamPlayer.new(); concrete.bus = "SFX"; add_child(concrete)
	concrete.stream = load("res://sounds/boss/concrete_break_short.ogg")
	concrete.volume_db = -3.0
	effects = AudioStreamPlayer.new(); effects.bus = "SFX"; add_child(effects)
	impact_sound = AudioStreamPlayer.new(); impact_sound.bus = "SFX"; add_child(impact_sound)
	impact_sound.stream = load("res://sounds/boss/toon_ground_impact.wav")
	impact_sound.volume_db = 0.0
	for sound in ["eatboss", "laughboss", "smash1", "smash2", "bossahhhhhentrance"]:
		sound_streams[sound] = load("res://sounds/" + sound + ".wav")

func start_music() -> void:
	if music.playing: return
	var stream = load("res://sounds/boss/concrete_crack_boss.mp3") as AudioStreamMP3
	if stream == null: return
	stream = stream.duplicate()
	stream.loop = true
	music.stream = stream
	music.volume_db = linear_to_db(.62)
	music.play()
	game._sync_combat_audio()

func active() -> bool: return not phase.is_empty()
func host() -> bool: return not game.mp_enabled or NetManager.is_host()
func online() -> bool: return game.mp_enabled and NetManager.is_online()
func can_serve() -> bool: return phase == "ready" and order_left > 0

func build_hidden_controls(parent: Control) -> void:
	game._hidden_add_section(parent, "HOTDOG BOSS")
	for axis in 3:
		var a = axis
		game._hidden_add_labeled_slider(parent, "hotdog_position_" + str(a), "Position " + ["X", "Y", "Z (distance)"][a], -12.0 if a < 2 else 3.0, 12.0 if a < 2 else 20.0, .01,
			func(): return boss_position[a], func(value):
				boss_position[a] = value
				update_placement())
	game._hidden_add_labeled_slider(parent, "hotdog_scale", "Scale", .3, 3.0, .01,
		func(): return boss_scale, func(value):
			boss_scale = value
			update_placement())

func update_placement() -> void:
	apply_placement()
	if not host() and online():
		request_placement.rpc_id(1, boss_position, boss_scale)
		return
	var config = ConfigFile.new()
	config.set_value("boss", "position", boss_position)
	config.set_value("boss", "scale", boss_scale)
	config.save(PLACEMENT_FILE)
	broadcast()

@rpc("any_peer", "call_remote", "reliable")
func request_placement(pos: Vector3, size_value: float) -> void:
	if not host() or not pos.is_finite() or not is_finite(size_value): return
	boss_position = pos.clamp(Vector3(-12,-12,3), Vector3(12,12,20))
	boss_scale = clampf(size_value,.3,3.0)
	update_placement()

func apply_placement() -> void:
	if is_instance_valid(customer):
		customer.position = boss_position
		customer.scale = Vector3.ONE * boss_scale

func current_recipe() -> Array:
	return recipes[mini(perfect + mistakes, recipes.size()-1)]

func reserve_order() -> void:
	if not can_serve(): return
	phase = "feeding"; pending_result = -1
	refresh(); broadcast()

func sound_event(kind: String) -> void:
	play_sound(kind)
	if host() and online(): receive_sound.rpc(kind)

@rpc("authority", "call_remote", "reliable")
func receive_sound(kind: String) -> void:
	if active(): play_sound(kind)

func duck_music(seconds: float, reduction_db: float) -> void:
	music_duck_left = maxf(music_duck_left, seconds)
	music_duck_db = maxf(music_duck_db, reduction_db)
	music.volume_db = linear_to_db(.62) - music_duck_db

func play_sound(kind: String) -> void:
	if kind in ["impact", "smash1", "smash2"]:
		if kind == "impact" and is_instance_valid(game.game_audio): game.game_audio.play_truck_knock(1.0)
		if kind != "impact":
			impact_sound.play()
			effects.stream = sound_streams[kind]
			effects.volume_db = -2.0 if kind == "smash1" else -3.0
			effects.play()
			duck_music(effects.stream.get_length(), 12.0)
		return
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("BaronBratVoice"),1,kind == "laugh")
	voice.pitch_scale = VOICE_PITCH
	voice.volume_db = -1.0
	match kind:
		"breakout":
			concrete.play()
			voice.stream = sound_streams["bossahhhhhentrance"]
		"eat":
			voice.stream = sound_streams["eatboss"]
		"laugh":
			voice.pitch_scale = .70
			voice.stream = sound_streams["laughboss"]
		"wawawa":
			voice.stream = load("res://sounds/wawawa.ogg")
			voice.pitch_scale = .58; voice.volume_db = -7.0
		_:
			return
	voice_left = 1.7 if kind == "wawawa" else voice.stream.get_length()/voice.pitch_scale + .05
	voice.play()

func eating_sound() -> void:
	# The existing food-flight callbacks may chomp more than once per burger.
	if not host() or phase != "feeding" or eat_sound_played: return
	eat_sound_played = true
	sound_event("eat")

func handle_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode != KEY_PERIOD and event.physical_keycode != KEY_PERIOD: return false
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	if not game.playing or game.tutorial_mode or not game._kitchen_ready: return false
	if host(): start()
	elif online(): request_start.rpc_id(1)
	return true

@rpc("any_peer", "call_remote", "reliable")
func request_start() -> void:
	if host() and multiplayer.get_remote_sender_id() > 0: start()

func start() -> bool:
	if active() or not game.playing or game.tutorial_mode: return false
	if not game._challenge_phase.is_empty() or game._serve_fly_busy or game._bts_day_intro_active or game._location_relocate_busy:
		game._flash("Finish the current event, then press . for Baron Brat", Color("FFD54F"))
		return false
	perfect = 0; mistakes = 0; pending_result = -1; milestone_history.clear()
	order_left = ORDER_SECONDS; ambient_left = randf_range(12,18); chatter_left = randf_range(5,9)
	laugh_left = randf_range(12,22); eat_sound_played = false
	recipes = make_recipes(randi())
	generation += 1
	spectator_time = 0.0; spectator_presets.clear()
	for walker in game.bg_people:
		var preset = walker.get_custom_character_preset()
		if preset.is_empty(): preset = preload("res://scripts/customer.gd").take_next_saved_character_preset()
		spectator_presets.append(preset)
	_spawn()
	phase = "rumble"; timer = 1.0
	start_music()
	customer.hide()
	impact(.9)
	refresh()
	broadcast()
	return true

func _spawn() -> void:
	previous_selected = game.selected_customer
	for c in game.customers.duplicate():
		if not is_instance_valid(c): continue
		suspended.append([c, c.visible, c.process_mode])
		c.hide(); c.process_mode = Node.PROCESS_MODE_DISABLED
		if game.tickets.has(c): game.tickets[c].hide()
	customer = CUSTOMER.new()
	customer.boss = self
	customer.name = "BaronBrat"
	customer.set_meta("mp_net_id", NET_ID)
	customer.set_meta("hotdog_boss", true)
	customer.order.assign(current_recipe())
	game.customers_root.add_child(customer)
	apply_placement()
	game.customers.append(customer)
	customer.is_waiting = false
	game.selected_customer = customer
	stage_street()

func stage_street() -> void:
	if is_instance_valid(game.shadow_catcher_root):
		shadow_root_visible = game.shadow_catcher_root.visible; shadow_root_saved = true
		game.shadow_catcher_root.hide()
	street_saved.clear()
	for i in game.bg_people.size():
		var walker = game.bg_people[i]
		if not is_instance_valid(walker): continue
		var anim = walker._anim_player
		street_saved.append({"node":walker,"visible":walker.visible,"transform":walker.transform,
			"preset":walker.get_custom_character_preset(), "animation":str(anim.current_animation) if is_instance_valid(anim) else "",
			"time":anim.current_animation_position if is_instance_valid(anim) else 0.0,
			"speed":anim.speed_scale if is_instance_valid(anim) else 1.0,
			"collision":walker._wawa_click_area.collision_layer})
		if i < spectator_presets.size() and walker.get_custom_character_preset() != spectator_presets[i]:
			walker.restyle_street_character(spectator_presets[i], true)
		walker._wawa_click_area.collision_layer = 0
		walker.show(); walker.play_street_walk()
	update_spectators(0)

func update_spectators(delta: float) -> void:
	spectator_time += delta
	if is_instance_valid(game.shadow_catcher_root): game.shadow_catcher_root.hide()
	for i in street_saved.size():
		var walker = street_saved[i].node
		if not is_instance_valid(walker): continue
		var side = -1.0 if i%2 == 0 else 1.0
		var end = Vector3(boss_position.x + side*(1.6*boss_scale+.85), game._bg_people_y(), boss_position.z+1.1)
		var start = Vector3(boss_position.x+side*8.0,end.y,end.z+.3)
		var progress = clampf((spectator_time-float(i)*.25)/3.5,0,1)
		walker.position = start.lerp(end,progress)
		walker.scale = Vector3.ONE * game._bg_people_scale()
		if progress < 1:
			walker.rotation.y = atan2(end.x-start.x,end.z-start.z)
		else:
			walker.rotation.y = atan2(boss_position.x-end.x,boss_position.z-end.z)
			walker._play_anim("idle")

func restore_street() -> void:
	if is_instance_valid(game.shadow_catcher_root):
		game.shadow_catcher_root.visible = shadow_root_visible if shadow_root_saved else true
	shadow_root_saved = false
	for saved in street_saved:
		var walker = saved.node
		if not is_instance_valid(walker): continue
		if not saved.preset.is_empty() and walker.get_custom_character_preset() != saved.preset:
			walker.restyle_street_character(saved.preset,true)
		walker.transform = saved.transform; walker.visible = saved.visible
		walker._wawa_click_area.collision_layer = saved.collision
		walker._anim_state = ""
		if is_instance_valid(walker._anim_player) and walker._anim_player.has_animation(saved.animation):
			walker._anim_player.play(saved.animation)
			walker._anim_player.seek(saved.time,true)
			walker._anim_player.speed_scale = saved.speed
	street_saved.clear()

func play(name_value: String) -> float:
	clip = name_value
	if not is_instance_valid(customer) or not is_instance_valid(customer.player): return .1
	if not customer.player.has_animation(name_value):
		push_error("Missing Baron animation: " + name_value)
		return .1
	customer.player.play(name_value, .06)
	return customer.player.get_animation(name_value).length

func begin_eating() -> void:
	if phase not in ["ready", "feeding"]: return
	if phase == "ready": reserve_order()
	play("eat_thrown_burger")
	refresh(); broadcast()

func complete_serve(station_index: int, cust: Node3D) -> void:
	if not host() or cust != customer or phase not in ["ready", "feeding"] or pending_result >= 0: return
	if station_index < 0 or station_index >= game.stations.size(): return
	var station: Dictionary = game.stations[station_index]
	var built: Array = cust.get_meta("serve_recipe", station["items"])
	var exact: bool = DATA.compare_orders(built, cust.order).perfect
	if phase == "ready" and not can_serve(): return
	pending_result = 1 if exact else 0
	phase = "feeding"
	if exact:
		var pay = DATA.order_value(cust.order)
		cust.set_meta("profit_built", built.duplicate())
		game._credit_ticket_payout({"base":pay,"tip":0,"total":pay},pay,cust)
		game.total_served += 1
	game._clear_station(station_index)
	game._mp_serve_sync = false
	game._update_hud()
	if online():
		game._mp_broadcast_station(station_index)
		game._mp_broadcast_economy()
	refresh(); broadcast()

func resolve_result(correct: bool, reason: String = "WRONG BURGER!") -> void:
	pending_result = -1
	if correct:
		perfect += 1
		if perfect == TOTAL:
			phase = "victory"; timer = play("slump") + 2.0
		elif perfect in [10,30]:
			milestone_history.append(perfect)
			phase = "slump"; timer = play("slump") + 1.0
		else: ready_order()
	else:
		mistakes += 1
		failure_reason = reason
		phase = "defeat" if mistakes >= MAX_LOSSES else "attack"
		customer.is_waiting = false
		game._remove_ticket(customer)
		# Each failed burger gets the requested truck-directed hook, then a ground smash.
		timer = play("hook_forward" if mistakes % 2 else "swing_forward")
		impact_at = timer * .49
	refresh(); broadcast()

func ready_order() -> void:
	eat_sound_played = false
	phase = "ready"
	order_left = ORDER_SECONDS
	customer.order.assign(current_recipe())
	customer.is_waiting = true
	customer.set_meta("serve_in_progress", false)
	customer.set_meta("burger_in_flight", false)
	for meta in ["serve_recipe","serve_missing_items","serve_missing_side"]:
		if customer.has_meta(meta): customer.remove_meta(meta)
	game._remove_ticket(customer)
	game._create_ticket(customer)
	game.selected_customer = customer
	play(["idle_sway", "idle_wave", "idle_bounce"][perfect % 3])
	refresh()

func _process(delta: float) -> void:
	if not active(): return
	update_spectators(delta)
	music_duck_left = maxf(0, music_duck_left-delta)
	if music_duck_left <= 0:
		music_duck_db = 0.0
		music.volume_db = move_toward(music.volume_db, linear_to_db(.62), delta*10.0)
	if voice_left > 0:
		voice_left -= delta
		if voice_left <= 0: voice.stop()
	if not game.playing:
		cancel(); return
	# Keep the parked normal queue out of the boss's order flow.
	for item in suspended:
		if is_instance_valid(item[0]) and game.tickets.has(item[0]): game.tickets[item[0]].hide()
	if not host():
		if phase == "ready": order_left = maxf(0, order_left-delta); refresh()
		return
	if phase == "ready":
		order_left = maxf(0, order_left-delta)
		ambient_left -= delta; chatter_left -= delta; laugh_left -= delta
		if order_left <= 0: resolve_result(false, "TIME UP!")
		elif ambient_left <= 0:
			phase = "idle_smash"; customer.is_waiting = false
			timer = play("hammer_left" if randi()%2 else "hammer_right"); impact_at = timer * .51
			ambient_left = randf_range(12,18)
			broadcast()
		elif laugh_left <= 0 and voice_left <= 0:
			sound_event("laugh"); laugh_left = randf_range(16,26)
			chatter_left = maxf(chatter_left, 4.0)
		elif chatter_left <= 0 and voice_left <= 0:
			sound_event("wawawa"); chatter_left = randf_range(7,12)
		refresh()
	elif phase == "feeding":
		if pending_result >= 0 and not bool(customer.get_meta("burger_in_flight",false)):
			resolve_result(pending_result == 1)
	elif phase != "ready":
		var before = timer
		timer = maxf(0, timer-delta)
		if impact_at >= 0 and before >= impact_at and timer < impact_at:
			impact_at = -1; impact(.65)
		if timer <= 0: advance_phase()
	sync_timer -= delta
	if sync_timer <= 0:
		sync_timer = .25; broadcast()

func advance_phase() -> void:
	match phase:
		"rumble":
			customer.show(); phase = "emerge"; timer = play("ground_breakout"); impact_at = timer * .42
			sound_event("breakout")
		"emerge": ready_order()
		"attack":
			phase = "smash"; timer = play("hammer_left" if mistakes % 2 else "hammer_right"); impact_at = timer * .51
		"smash": ready_order()
		"idle_smash":
			phase = "ready"; customer.is_waiting = true
			play(["idle_sway", "idle_wave", "idle_bounce"][randi()%3])
		"defeat":
			game._flash("CHALLENGE LOST!  Baron Brat wins — 10 orders lost", Color("FF8A80"), 6)
			cancel(); return
		"slump": phase = "revive"; timer = play("revive")
		"revive": ready_order()
		"victory":
			game._flash("BARON BRAT BEATEN!  50 / 50 perfect burgers", Color("A5D6A7"), 5)
			cancel(); return
	refresh(); broadcast()

func impact(duration: float) -> void:
	impact_serial += 1
	game._start_slot_camera_shake(duration,.075)
	sound_event(("smash1" if randi()%2 else "smash2") if phase in ["smash", "idle_smash"] else "impact")

func refresh() -> void:
	if not is_instance_valid(label): return
	label.visible = active()
	if is_instance_valid(customer) and game.tickets.has(customer):
		game._update_ticket_seconds_label(game.tickets[customer], customer)
	var message = "%.1fs  •  %d / 50 perfect  •  %d / 10 orders lost" % [order_left,perfect,mistakes]
	match phase:
		"rumble", "emerge": message = "THE TRUCK IS SHAKING… BARON BRAT IS HERE!"
		"feeding": message = "CHOMP!  %d / 50 perfect" % perfect
		"attack", "smash": message = "%s  %d / 10 orders lost" % [failure_reason,mistakes]
		"idle_smash": message = "GROUND SMASH!  Timer paused — %.1fs left" % order_left
		"defeat": message = "CHALLENGE LOST!  10 orders lost — BARON BRAT WINS!"
		"slump", "revive": message = "%d PERFECT!  He's down… but not finished!" % perfect
		"victory": message = "50 / 50 PERFECT — BARON BRAT DEFEATED!"
	label.text = "BARON BRAT CHALLENGE\n" + message

func cancel() -> void:
	phase = ""; clip = ""; pending_result = -1; impact_at = -1
	if is_instance_valid(music): music.stop()
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(concrete): concrete.stop()
	if is_instance_valid(effects): effects.stop()
	if is_instance_valid(impact_sound): impact_sound.stop()
	restore_street()
	voice_left = 0; music_duck_left = 0; music_duck_db = 0; eat_sound_played = false
	game._sync_combat_audio()
	if is_instance_valid(customer):
		game._remove_ticket(customer)
		game.customers.erase(customer)
		customer.queue_free()
	customer = null
	for item in suspended:
		if not is_instance_valid(item[0]): continue
		item[0].visible = item[1]; item[0].process_mode = item[2]
		if game.tickets.has(item[0]): game.tickets[item[0]].show()
	suspended.clear()
	game.selected_customer = previous_selected if is_instance_valid(previous_selected) else null
	refresh()
	if host(): broadcast()

func broadcast() -> void:
	if not host() or not online(): return
	sync_state.rpc(phase, perfect, mistakes, recipes, clip, timer, impact_serial, generation, order_left, boss_position, boss_scale, failure_reason, spectator_presets, spectator_time)

@rpc("authority", "call_remote", "reliable")
func sync_state(remote_phase: String, count: int, wrong: int, orders: Array, animation: String, remaining: float, serial: int, round_id: int, seconds_left: float = ORDER_SECONDS, pos: Vector3 = Vector3(0,-.02,6.3), size_value: float = 1.0, reason: String = "WRONG BURGER!", crowd: Array = [], crowd_time: float = 0.0) -> void:
	if host(): return
	if remote_phase.is_empty():
		if active(): cancel()
		return
	if active() and generation != round_id: cancel()
	perfect = count; mistakes = wrong; recipes = orders; generation = round_id
	boss_position = pos; boss_scale = size_value; failure_reason = reason
	spectator_presets = crowd; spectator_time = crowd_time
	if not is_instance_valid(customer): _spawn()
	apply_placement()
	var changed = phase != remote_phase or customer.order != current_recipe()
	phase = remote_phase; timer = remaining
	start_music()
	customer.visible = phase != "rumble"
	customer.is_waiting = phase == "ready"
	if changed and phase == "ready": ready_order()
	order_left = seconds_left
	if clip != animation:
		play(animation)
		if remaining > 0 and customer.player.has_animation(animation):
			customer.player.seek(maxf(0,customer.player.get_animation(animation).length-remaining),true)
	if serial != received_impact:
		received_impact = serial
		game._start_slot_camera_shake(.65,.075)
	refresh()
