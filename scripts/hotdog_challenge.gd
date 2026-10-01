extends Node
## Host-owned 15-perfect encounter. Normal serving owns the burger flight and station.
const DATA = preload("res://scripts/game_data.gd")
const CUSTOMER = preload("res://scripts/hotdog_boss_customer.gd")
const TOTAL = 15
const MAX_LOSSES = 3
const FINAL_STAGE = 10
const HARD_DECK_START = TOTAL + MAX_LOSSES
const SINK_SECONDS = 2.0
const ORDER_SECONDS = 17.0
const PLACEMENT_FILE = "user://hotdog_boss.cfg"
const VOICE_PITCH = .78
const NET_ID = 1900000050
var game: Node
var customer: Node3D
var next_order_preview: Node3D
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
var received_slam = -1
var generation = 0
var boss_position = Vector3(0, -.3248, 7.5192)
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
var decorations_hit = false
var bunting_home = Transform3D.IDENTITY
var bunting_fall: Tween
var sign_flip: Tween
var prop_bounces: Dictionary = {}
var smash_count = 0
var victory_played = false
var result_screen: Control

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
	# A separate finale deck keeps double/triple stacks tied to perfect progress,
	# even when earlier mistakes have consumed replacement recipes.
	for mask in masks:
		var toppings: Array[String] = []
		for bit in DATA.TOPPING_ORDER.size():
			if mask & (1 << bit): toppings.append(DATA.TOPPING_ORDER[bit])
		if toppings.size() < 4: continue
		var order: Array[String] = ["bun_bottom", "patty", "patty"]
		if (result.size() - HARD_DECK_START) % 2 == 0: order.append("patty")
		order.append_array(toppings)
		order.append("bun_top")
		result.append(order)
		if result.size() == HARD_DECK_START + 5 + MAX_LOSSES: break
	return result

func setup(owner_game: Node) -> void:
	game = owner_game
	var config = ConfigFile.new()
	if config.load(PLACEMENT_FILE) == OK:
		boss_position = config.get_value("boss", "position", boss_position)
		boss_scale = clampf(float(config.get_value("boss", "scale", boss_scale)), .3, 3.0)
		# Apply the one-foot drop once to previously saved hidden-GUI placements.
		if int(config.get_value("boss", "height_revision", 0)) < 1:
			boss_position.y -= .3048
			config.set_value("boss", "position", boss_position)
			config.set_value("boss", "height_revision", 1)
			config.save(PLACEMENT_FILE)
		# Move existing saved placements two feet farther from the truck once.
		if int(config.get_value("boss", "distance_revision", 0)) < 2:
			boss_position.z += .6096 * (2 - int(config.get_value("boss", "distance_revision", 0)))
			config.set_value("boss", "position", boss_position)
			config.set_value("boss", "distance_revision", 2)
			config.save(PLACEMENT_FILE)
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
	config.set_value("boss", "height_revision", 1)
	config.set_value("boss", "distance_revision", 2)
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
		if phase in ["sinking", "defeat_sinking"] and clip == "ground_exit":
			customer.update_ground_exit(clampf(1.0-timer/SINK_SECONDS,0,1))
		customer.scale = Vector3.ONE * boss_scale

func current_recipe() -> Array:
	return recipe_at(perfect)

func recipe_at(perfect_count: int) -> Array:
	var index = perfect_count + mistakes
	if perfect_count >= FINAL_STAGE: index = HARD_DECK_START + perfect_count - FINAL_STAGE + mistakes
	return recipes[mini(index, recipes.size()-1)]

func refresh_next_order() -> void:
	if phase not in ["ready"] or perfect >= TOTAL - 1:
		if is_instance_valid(next_order_preview) and game.tickets.has(next_order_preview):
			game.tickets[next_order_preview].hide()
		return
	var next_recipe = recipe_at(perfect + 1)
	if not is_instance_valid(next_order_preview):
		next_order_preview = preload("res://scripts/mobile_ticket_owner.gd").new()
		next_order_preview.name = "BossNextOrderPreview"
		next_order_preview.set_meta("hotdog_preview", true)
		next_order_preview.set_meta("mp_net_id", NET_ID + 1)
		next_order_preview.is_waiting = false
		next_order_preview.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(next_order_preview)
	if next_order_preview.order != next_recipe:
		game._remove_ticket(next_order_preview)
		next_order_preview.order.assign(next_recipe)
	if not game.tickets.has(next_order_preview):
		game._create_ticket(next_order_preview)
		var wrap = game.tickets[next_order_preview]
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game._update_ticket_seconds_label(wrap, next_order_preview)
	game.tickets[next_order_preview].show()

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
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("BaronBratVoice"),1,kind in ["laugh", "victory_laugh"])
	voice.pitch_scale = VOICE_PITCH
	voice.volume_db = -1.0
	match kind:
		"breakout", "revive_roar":
			if kind == "breakout": concrete.play()
			voice.volume_db = 2.0
			voice.stream = sound_streams["bossahhhhhentrance"]
		"eat":
			voice.stream = sound_streams["eatboss"]
		"laugh", "victory_laugh":
			voice.pitch_scale = .70
			voice.stream = sound_streams["laughboss"]
			if kind == "victory_laugh":
				voice.volume_db = 5.0
				duck_music(3.2, 14.0)
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
	game._hotdog_shift_triggered = true
	smash_count = 0; victory_played = false
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
	decorations_hit = false
	previous_selected = game.selected_customer
	for c in game.customers.duplicate():
		if not is_instance_valid(c): continue
		suspended.append([c, c.visible, c.process_mode])
		c.hide(); c.process_mode = Node.PROCESS_MODE_DISABLED
		if game.tickets.has(c): game.tickets[c].hide()
	customer = CUSTOMER.new()
	customer.boss = self
	customer.name = "BaronBrat"
	customer.hide() # Never expose the imported rest pose, even for one frame.
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
		var end = spectator_target(i)
		var side = signf(end.x - boss_position.x)
		var start = end + Vector3(side*3.5, 0, .3)
		var progress = clampf((spectator_time-float(i)*.25)/3.5,0,1)
		walker.position = start.lerp(end,progress)
		walker.scale = Vector3.ONE * game._bg_people_scale()
		if progress < 1:
			walker.rotation.y = atan2(end.x-start.x,end.z-start.z)
		else:
			walker.rotation.y = atan2(boss_position.x-end.x,boss_position.z-end.z)
			walker._play_anim("idle")

func spectator_target(index: int) -> Vector3:
	var end = Vector3(-6.0 if index%2 == 0 else 6.0, game._bg_people_y(), game._bg_people_z())
	if is_instance_valid(game.camera):
		var size = game.camera.get_viewport().get_visible_rect().size
		var pixel = Vector2(size.x * (.12 if index%2 == 0 else .88), size.y*.5)
		var origin = game.camera.project_ray_origin(pixel)
		var ray = game.camera.project_ray_normal(pixel)
		if absf(ray.z) > .001:
			end.x = (origin + ray * ((end.z-origin.z)/ray.z)).x
	return end

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
	if name_value == "ground_exit" and is_instance_valid(customer):
		customer.begin_ground_exit()
		return SINK_SECONDS
	if not is_instance_valid(customer) or not is_instance_valid(customer.player): return .1
	if not customer.player.has_animation(name_value):
		push_error("Missing Baron animation: " + name_value)
		return .1
	var length = customer.player.get_animation(name_value).length
	customer.player.speed_scale = maxf(1.0, length / .55) if name_value == "revive" else 1.0
	customer.player.play(name_value, 0.0 if name_value == "ground_breakout" else .06)
	if name_value == "ground_breakout": customer.player.advance(0.0)
	return length / customer.player.speed_scale

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
			phase = "victory"; timer = play("slump_defeat") + .8
			customer.is_waiting = false; game._remove_ticket(customer)
			start_victory()
		elif perfect % 5 == 0:
			milestone_history.append(perfect)
			phase = "slump"; timer = play("slump") + (3.4 if perfect == FINAL_STAGE else 1.35)
			customer.is_waiting = false
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
		if phase in ["sinking", "defeat_sinking"]: timer = maxf(0, timer-delta); apply_placement()
		return
	if phase == "ready":
		order_left = maxf(0, order_left-delta)
		ambient_left -= delta; chatter_left -= delta; laugh_left -= delta
		if order_left <= 0: resolve_result(false, "TIME UP!")
		elif ambient_left <= 0:
			phase = "idle_smash"; customer.is_waiting = false
			start_smash()
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
	elif phase != "results":
		var before = timer
		timer = maxf(0, timer-delta)
		if phase in ["sinking", "defeat_sinking"]: apply_placement()
		if impact_at >= 0 and before >= impact_at and timer < impact_at:
			impact_at = -1; impact(.65)
		if timer <= 0: advance_phase()
	sync_timer -= delta
	if sync_timer <= 0:
		sync_timer = .25; broadcast()

func advance_phase() -> void:
	match phase:
		"rumble":
			phase = "emerge"; timer = play("ground_breakout"); impact_at = timer * .42
			customer.player.seek(0.0, true)
			customer.player.advance(0.0)
			customer.show()
			sound_event("breakout")
		"emerge": ready_order()
		"attack":
			phase = "smash"; start_smash()
		"smash": ready_order()
		"idle_smash":
			phase = "ready"; customer.is_waiting = true
			play(["idle_sway", "idle_wave", "idle_bounce"][randi()%3])
		"defeat":
			phase = "defeat_laugh"; play("idle_bounce"); timer = 2.6
			sound_event("victory_laugh")
		"defeat_laugh":
			phase = "defeat_smash"; timer = play("hammer_double"); impact_at = timer*.51
		"defeat_smash":
			phase = "defeat_sinking"; timer = play("ground_exit")
			concrete.play(); duck_music(SINK_SECONDS,10.0)
		"defeat_sinking":
			game._flash("CHALLENGE LOST!  Baron Brat wins — 3 orders lost", Color("FF8A80"), 6)
			cancel(); return
		"slump":
			phase = "revive"; timer = play("revive")
			sound_event("revive_roar")
		"revive":
			phase = "revive_smash_first"; start_smash()
		"revive_smash_first":
			phase = "revive_smash_second"; start_smash()
		"revive_smash_second": ready_order()
		"victory":
			phase = "sinking"; timer = play("ground_exit")
			concrete.play()
			apply_placement()
		"sinking":
			phase = "results"; customer.hide(); restore_decorations(); show_results()
	refresh(); broadcast()

func start_smash() -> void:
	# Alternate single and double slams, with either hand on the single strikes.
	var animation = "hammer_double" if smash_count % 2 == 1 else ("hammer_left" if randi()%2 else "hammer_right")
	smash_count += 1
	timer = play(animation); impact_at = timer * .51

func start_victory() -> void:
	music.stop(); voice.stop(); effects.stop(); concrete.stop(); impact_sound.stop()
	voice_left = 0
	if victory_played: return
	victory_played = true
	if is_instance_valid(game.game_audio): game.game_audio.play_challenge_complete_tune()

func finish_results() -> void:
	if host() and phase == "results": cancel()

func show_results() -> void:
	if is_instance_valid(result_screen): return
	result_screen = Control.new()
	result_screen.name = "BaronBratVictory"
	result_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_screen.z_index = 100
	game.get_node("UI/Root").add_child(result_screen)
	var shade = ColorRect.new()
	shade.color = Color(.06, .025, .035, .82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_screen.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_screen.add_child(center)
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(600, 410)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("FFF0CB"); style.border_color = Color("E5AA39")
	style.set_border_width_all(5); style.set_corner_radius_all(24)
	style.content_margin_left = 42; style.content_margin_right = 42
	style.content_margin_top = 30; style.content_margin_bottom = 30
	style.shadow_color = Color(0,0,0,.45); style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style); center.add_child(panel)
	var rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 16); panel.add_child(rows)
	var messages = ["★  CHALLENGE COMPLETE  ★", "BARON BRAT\nBEATEN!", "15 / 15 PERFECT BURGERS", "%d / 3 ORDERS LOST  •  FINAL FIVE CONQUERED" % mistakes]
	for i in messages.size():
		var text = Label.new(); text.text = messages[i]; text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_override("font", preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
		text.add_theme_font_size_override("font_size", [22, 48, 28, 17][i])
		text.add_theme_color_override("font_color", Color("A93227") if i == 1 else Color("624020"))
		rows.add_child(text)
	var button = Button.new(); button.text = "BACK TO THE GRILL" if host() else "WAITING FOR HOST…"
	button.custom_minimum_size.y = 54; button.disabled = not host()
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(finish_results); rows.add_child(button)
	result_screen.modulate.a = 0
	create_tween().tween_property(result_screen, "modulate:a", 1.0, .3)
	if host(): button.grab_focus()

func impact(duration: float) -> void:
	impact_serial += 1
	game._start_slot_camera_shake(minf(duration, .5),.075)
	var ground_slam = phase in ["smash", "idle_smash", "revive_smash_first", "revive_smash_second", "defeat_smash"]
	if ground_slam or phase in ["attack", "defeat"]:
		hit_decorations()
		if host() and online(): receive_decoration_hit.rpc()
	if ground_slam:
		bounce_grill(impact_serial)
		if host() and online(): receive_ground_slam.rpc(impact_serial)
	sound_event(("smash1" if randi()%2 else "smash2") if ground_slam else "impact")

func refresh() -> void:
	refresh_next_order()
	if not is_instance_valid(label): return
	label.visible = active() and phase != "results"
	if is_instance_valid(customer) and game.tickets.has(customer):
		game._update_ticket_seconds_label(game.tickets[customer], customer)
	var message = "%.1fs  •  %d / 15 perfect  •  %d / 3 orders lost" % [order_left,perfect,mistakes]
	match phase:
		"rumble", "emerge": message = "THE TRUCK IS SHAKING… BARON BRAT IS HERE!"
		"feeding": message = "CHOMP!  %d / 15 perfect" % perfect
		"attack", "smash": message = "%s  %d / 3 orders lost" % [failure_reason,mistakes]
		"idle_smash": message = "GROUND SMASH!  Timer paused — %.1fs left" % order_left
		"defeat", "defeat_laugh", "defeat_smash", "defeat_sinking": message = "CHALLENGE LOST!  3 orders lost — BARON BRAT WINS!"
		"slump": message = "20 PERFECT!  Is he… finished?" if perfect == FINAL_STAGE else "%d PERFECT!  He's down…" % perfect
		"revive", "revive_smash_first", "revive_smash_second": message = "HE'S BACK!  FIVE MONSTER BURGERS TO GO!" if perfect == FINAL_STAGE else "BACK FOR MORE!"
		"victory", "sinking": message = "15 / 15 PERFECT — BARON BRAT DEFEATED!"
	if phase == "ready" and perfect >= FINAL_STAGE: message = "FINAL FIVE!  " + message
	label.text = "BARON BRAT CHALLENGE\n" + message

func cancel() -> void:
	if is_instance_valid(next_order_preview):
		game._remove_ticket(next_order_preview)
		next_order_preview.queue_free()
	next_order_preview = null
	if is_instance_valid(result_screen): result_screen.queue_free()
	result_screen = null
	phase = ""; clip = ""; pending_result = -1; impact_at = -1
	if is_instance_valid(music): music.stop()
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(concrete): concrete.stop()
	if is_instance_valid(effects): effects.stop()
	if is_instance_valid(impact_sound): impact_sound.stop()
	restore_street()
	restore_decorations()
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
	sync_state.rpc(phase, perfect, mistakes, recipes, clip, timer, impact_serial, generation, order_left, boss_position, boss_scale, failure_reason, spectator_presets, spectator_time, decorations_hit)

@rpc("authority", "call_remote", "reliable")
func sync_state(remote_phase: String, count: int, wrong: int, orders: Array, animation: String, remaining: float, serial: int, round_id: int, seconds_left: float = ORDER_SECONDS, pos: Vector3 = Vector3(0,-.02,6.3), size_value: float = 1.0, reason: String = "WRONG BURGER!", crowd: Array = [], crowd_time: float = 0.0, hit_props: bool = false) -> void:
	if host(): return
	if remote_phase.is_empty():
		if active(): cancel()
		return
	game._hotdog_shift_triggered = true
	if active() and generation != round_id: cancel()
	if generation != round_id: victory_played = false
	perfect = count; mistakes = wrong; recipes = orders; generation = round_id
	boss_position = pos; boss_scale = size_value; failure_reason = reason
	spectator_presets = crowd; spectator_time = crowd_time
	if not is_instance_valid(customer): _spawn()
	var changed = phase != remote_phase or customer.order != current_recipe()
	phase = remote_phase; timer = remaining
	apply_placement()
	if phase in ["victory", "sinking", "results"]: start_victory()
	else: start_music()
	customer.visible = phase not in ["rumble", "results"]
	customer.is_waiting = phase == "ready"
	if changed and phase == "ready": ready_order()
	order_left = seconds_left
	if clip != animation:
		play(animation)
		if remaining > 0 and animation != "ground_exit" and customer.player.has_animation(animation):
			customer.player.seek(maxf(0,customer.player.get_animation(animation).length-remaining*customer.player.speed_scale),true)
	if phase in ["sinking", "defeat_sinking"]:
		if clip != "ground_exit": play("ground_exit")
		apply_placement()
		game._remove_ticket(customer)
	elif phase == "results":
		customer.player.pause(); game._remove_ticket(customer)
	if hit_props and phase != "results": hit_decorations()
	if phase == "results":
		restore_decorations()
		show_results()
	if serial != received_impact:
		received_impact = serial
		game._start_slot_camera_shake(.5,.075)
		if phase in ["smash", "idle_smash", "revive_smash_first", "revive_smash_second", "defeat_smash"]: bounce_grill(serial)
	refresh()

func bounce_grill(serial: int) -> void:
	if serial <= received_slam: return
	received_slam = serial
	for bun in game.bun_pile_stacks:
		if is_instance_valid(bun) and bun.visible: bounce_prop(bun, .18 + .025 * int(bun.get_meta("pair_i", 0)))
	if is_instance_valid(game.tip_jar_root):
		game._tip_jar_shake_left = 0.0
		bounce_prop(game.tip_jar_root, .16)
	# Presentation only: preserve positions, cook state, ownership, and flip count.
	for patty in game.grill:
		if is_instance_valid(patty) and not patty.is_held and patty.has_method("_play_done_jump"):
			patty._play_done_jump(.24)

@rpc("authority", "call_remote", "reliable")
func receive_ground_slam(serial: int) -> void:
	if active(): bounce_grill(serial)

func bounce_prop(prop: Node3D, height: float) -> void:
	var home: Vector3 = prop.position
	if prop_bounces.has(prop):
		home = prop_bounces[prop].home
		prop_bounces[prop].tween.kill()
	prop.position = home
	var tween = prop.create_tween()
	prop_bounces[prop] = {"home": home, "tween": tween}
	tween.tween_property(prop, "position", home + Vector3.UP * height, .16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(prop, "position", home, .22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): prop_bounces.erase(prop))

func hit_decorations() -> void:
	if decorations_hit: return
	decorations_hit = true
	var bunting = game.window_bunting_root
	if is_instance_valid(bunting):
		if is_instance_valid(bunting_fall): bunting_fall.kill()
		if bunting.has_meta("boss_bunting_home"): bunting.transform = bunting.get_meta("boss_bunting_home")
		bunting_home = bunting.transform
		bunting.set_meta("boss_bunting_home", bunting_home)
		bunting.set_meta("boss_fallen", true)
		var landing: Vector3 = bunting.position
		landing.y = .035
		landing.z += .4
		bunting_fall = bunting.create_tween().set_parallel(true)
		bunting_fall.tween_property(bunting, "position", landing, .7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		bunting_fall.tween_property(bunting, "rotation", Vector3(PI * .5, 0, 0), .7)
	var sign_node = game.open_closed_sign
	if is_instance_valid(sign_node):
		if is_instance_valid(game.open_closed_sign_tween): game.open_closed_sign_tween.kill()
		if is_instance_valid(sign_flip): sign_flip.kill()
		sign_flip = sign_node.create_tween()
		sign_flip.tween_property(sign_node, "rotation_degrees:y", game.OPEN_CLOSED_SIGN_YAW_CLOSED, .35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

@rpc("authority", "call_remote", "reliable")
func receive_decoration_hit() -> void:
	if active(): hit_decorations()

func restore_decorations() -> void:
	if not decorations_hit: return
	decorations_hit = false
	var bunting = game.window_bunting_root
	if is_instance_valid(bunting):
		if is_instance_valid(bunting_fall): bunting_fall.kill()
		bunting.transform = bunting_home
		bunting.position.y += 1.4
		bunting.set_meta("boss_fallen", false)
		bunting_fall = bunting.create_tween()
		bunting_fall.tween_property(bunting, "position", bunting_home.origin, .85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(sign_flip): sign_flip.kill()
	game._sync_open_closed_sign(true)
