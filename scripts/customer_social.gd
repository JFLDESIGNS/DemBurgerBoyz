extends Node
## Host chooses encounters; reliable events mirror the same reactions on guests.
var game: Node
var encounter_left := 8.0
var cat_left := 5.0
var walker_left := 35.0
var couples: Array = []
var walkers: Array = []

static func outcome(roll: float) -> String:
	if roll < 0.50: return "reply"
	if roll < 0.75: return "away"
	if roll < 0.85: return "love"
	return "quiet"

func _ready() -> void:
	name = "CustomerSocial"

func eligible(c) -> bool:
	return is_instance_valid(c) and c.has_method("get_customer_voice") and c.is_waiting and not c.is_leaving and not c.is_ragdoll and not c._eating and not c.dialogue_open and not c.is_cut_collector and not c.is_challenge_guest and not c.is_disguise_cat and not c.is_terrorist and not bool(c.get_meta("serve_in_progress", false)) and not c.has_meta("couple_partner")

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.playing or game.shift_paused or game.options_menu_open or game.tutorial_mode: return
	for item in walkers.duplicate():
		var c = item.get_ref()
		if not is_instance_valid(c): walkers.erase(item); continue
		c.visible = not game._hotdog_active()
		if not c.visible: continue
		c.position.x += delta * float(c.get_meta("couple_speed", 1.0)) * float(c.get_meta("couple_direction", 1.0))
		var heart_left = float(c.get_meta("couple_heart_left", 4.0)) - delta
		if heart_left <= 0.0:
			heart(c)
			heart_left = randf_range(4.0, 7.0)
		c.set_meta("couple_heart_left", heart_left)
		if absf(c.position.x) > game.BG_PEOPLE_EDGE_X + 2.0: c.queue_free(); walkers.erase(item)
	if game._hotdog_active() or game._boss_intro_running: return
	if game.mp_enabled and not NetManager.is_host(): return
	encounter_left -= delta
	cat_left -= delta
	walker_left -= delta
	var waiting = game.customers.filter(eligible)
	if encounter_left <= 0.0:
		encounter_left = randf_range(9.0, 17.0)
		if waiting.size() >= 2:
			var a = waiting.pick_random()
			var nearby = waiting.filter(func(c): return c != a and c.position.distance_to(a.position) < 3.5)
			if not nearby.is_empty():
				var b = nearby.pick_random()
				var kind = outcome(randf())
				encounter(a,b,kind)
				if game.mp_enabled and NetManager.is_online(): social_event.rpc(game._customer_net_id(a),game._customer_net_id(b),kind)
	if cat_left <= 0.0:
		cat_left = randf_range(7.0, 12.0)
		var cat = game.window_cat
		if is_instance_valid(cat) and cat.visible and cat._state == "peek" and not cat._delivery_peek_active and not waiting.is_empty():
			var c = waiting.pick_random()
			if cat.position.distance_to(c.position) < 4.0:
				var kind = "cat_love" if randf() < .5 else "cat_swat"
				encounter(c,null,kind)
				if game.mp_enabled and NetManager.is_online(): social_event.rpc(game._customer_net_id(c),-1,kind)
	if walker_left <= 0.0:
		walker_left = randf_range(40.0,75.0)
		if not couples.is_empty() and walkers.is_empty():
			var pair = couples.pick_random()
			var direction = game._bg_people_lane_dir()
			if direction == 0.0: direction = 1.0
			spawn_couple(pair, direction)
			if game.mp_enabled and NetManager.is_online(): couple_walk.rpc(pair, direction)

@rpc("authority", "call_remote", "reliable")
func social_event(a_id: int, b_id: int, kind: String) -> void:
	var a = game._customer_by_net_id(a_id)
	var b = game._customer_by_net_id(b_id)
	if is_instance_valid(a): encounter(a,b,kind)

func glance(c, point: Vector3, seconds := 2.5) -> void:
	if not is_instance_valid(c): return
	var life = c.get_node_or_null("CustomerLife")
	if life == null: return
	life.forced_target = point
	life.with_head = true
	life.gaze_left = seconds
	var token = int(c.get_meta("social_glance",0)) + 1
	c.set_meta("social_glance",token)
	var person_ref = weakref(c)
	var life_ref = weakref(life)
	create_tween().tween_interval(seconds).finished.connect(func():
		var person = person_ref.get_ref()
		var behavior = life_ref.get_ref()
		if is_instance_valid(person) and is_instance_valid(behavior) and int(person.get_meta("social_glance",0)) == token: behavior.forced_target = Vector3.INF)

func wawa(c, pitch := 1.0) -> void:
	if not is_instance_valid(c): return
	var audio = AudioStreamPlayer3D.new()
	audio.stream = preload("res://scripts/customer_voice.gd").stream(c.get_customer_voice(),false)
	audio.bus = "SFX"
	audio.pitch_scale = pitch
	audio.volume_db = -8.0
	audio.unit_size = 5.0
	c.add_child(audio)
	audio.play()
	audio.create_tween().tween_interval(.65).finished.connect(audio.queue_free)

func heart(c) -> void:
	var label = Label3D.new()
	label.text = "♥ ♥"
	label.modulate = Color("FF729D")
	label.font_size = 64
	label.pixel_size = .008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.0
	c.add_child(label)
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",2.6,2.0)
	tween.tween_property(label,"modulate:a",0.0,2.0)
	tween.chain().tween_callback(label.queue_free)

func encounter(a,b,kind: String) -> void:
	if kind.begins_with("cat_"):
		var cat = game.window_cat
		if not is_instance_valid(cat): return
		glance(a,cat.global_position + Vector3(0,.45,0))
		wawa(a,1.65)
		cat.set_meta("social_look",a.global_position)
		cat.set_meta("social_look_until",Time.get_ticks_msec()+3000)
		var cat_ref = weakref(cat)
		var person_ref = weakref(a)
		create_tween().tween_interval(.75).finished.connect(func():
			var animal = cat_ref.get_ref()
			var person = person_ref.get_ref()
			if is_instance_valid(animal) and is_instance_valid(person) and animal._state == "peek": animal.react_to_customer(person,kind == "cat_love"))
		return
	if not is_instance_valid(b): return
	glance(a,b.global_position + Vector3(0,1.5,0))
	wawa(a)
	var first_ref = weakref(a)
	var second_ref = weakref(b)
	create_tween().tween_interval(.8).finished.connect(func():
		var first = first_ref.get_ref()
		var second = second_ref.get_ref()
		if not eligible(first) or not eligible(second): return
		match kind:
			"reply":
				glance(second,first.global_position+Vector3(0,1.5,0)); wawa(second)
			"away":
				second.set_meta("social_away_until",Time.get_ticks_msec()+2400)
				second.set_meta("social_away_yaw",second.FACE_TRUCK_YAW + (55.0 if second.position.x > first.position.x else -55.0))
				glance(second,second.global_position+(second.global_position-first.global_position).normalized()*3.0+Vector3(0,1.5,0),3.0)
			"love":
				if game.mp_enabled and not NetManager.is_host(): return
				pair_customers(first,second)
				if game.mp_enabled and NetManager.is_online(): pair_event.rpc(game._customer_net_id(first),game._customer_net_id(second))
	)

func pair_customers(a,b) -> void:
	a.set_meta("couple_partner",weakref(b)); b.set_meta("couple_partner",weakref(a))
	a.set_meta("couple_first",true); b.set_meta("couple_first",false)
	var pair = [{"preset":a.get_custom_character_preset(),"skin":a.skin_idx},{"preset":b.get_custom_character_preset(),"skin":b.skin_idx}]
	couples.append(pair)
	if couples.size() > 8: couples.pop_front()
	heart(a); heart(b); play_love_song(a)
	for delay in [.4, .8, 1.2]:
		var ar = weakref(a); var br = weakref(b)
		create_tween().tween_interval(delay).finished.connect(func():
			if is_instance_valid(ar.get_ref()): heart(ar.get_ref())
			if is_instance_valid(br.get_ref()): heart(br.get_ref()))
	glance(b,a.global_position+Vector3(0,1.5,0),4.0)
	# One shared slip holds both meals; serve them sequentially through normal scoring.
	var elapsed_a = a.order_elapsed_sec
	var elapsed_b = b.order_elapsed_sec
	game._remove_ticket(a); game._remove_ticket(b)
	game._create_ticket(a); game._create_ticket(b)
	a.order_elapsed_sec = elapsed_a
	b.order_elapsed_sec = elapsed_b
	if game.selected_customer == b: game.selected_customer = a
	game._highlight_tickets()

func partner(c):
	if not is_instance_valid(c) or not c.has_meta("couple_partner"): return null
	return c.get_meta("couple_partner").get_ref()

func decorate_ticket(c, box: VBoxContainer) -> void:
	var other = partner(c)
	if not is_instance_valid(other): return
	var label = Label.new()
	label.text = "♥ TABLE FOR TWO — " + ("MEAL 1 + 2" if bool(c.get_meta("couple_first",false)) else "MEAL 2 / 2")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 138
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",Color("A34B66"))
	box.add_child(label)
	if bool(c.get_meta("couple_first",false)):
		var meal = Label.new()
		var lines: Array[String] = ["PARTNER'S MEAL (NEXT)"]
		for spec in game._ticket_line_specs(other.order): lines.append(spec.label)
		meal.text = "\n".join(lines)
		meal.add_theme_font_size_override("font_size",13)
		meal.add_theme_color_override("font_color",Color("885938"))
		box.add_child(meal)

func update_tickets() -> void:
	for c in game.tickets:
		var other = partner(c)
		if is_instance_valid(other) and not bool(c.get_meta("couple_first",false)) and game.tickets.has(other):
			game.tickets[c].hide()
			if game.tickets[c].has_meta("ticket_motion"): game.tickets[c].get_meta("ticket_motion").set_active(false)

@rpc("authority", "call_remote", "reliable")
func couple_walk(pair: Array, direction: float = 1.0) -> void:
	spawn_couple(pair, direction)

func spawn_couple(pair: Array, direction: float = 0.0) -> void:
	var pace = (game.BG_PEOPLE_SPEED_MIN + game.BG_PEOPLE_SPEED_MAX) * .5
	if direction == 0.0: direction = game._bg_people_lane_dir()
	if direction == 0.0: direction = 1.0
	for i in 2:
		var c = preload("res://scripts/customer.gd").new()
		c.is_street_pedestrian = true
		c.setup([] as Array[String],Color.WHITE,9999.0,0,int(pair[i].get("skin",0)),0,-1,pair[i].get("preset",{}),true)
		game.customers_root.add_child(c)
		c.position = Vector3(-direction * (game.BG_PEOPLE_EDGE_X + i*.45),game._bg_people_y(),game._bg_people_z()+i*.65)
		c.scale = Vector3.ONE * game._bg_people_scale()
		c.rotation_degrees.y = c.WALK_PLUS_X_YAW if direction > 0 else c.WALK_MINUS_X_YAW
		c.set_meta("couple_speed", pace)
		c.set_meta("couple_direction", direction)
		c.set_meta("couple_heart_left", 3.0+i*.6)
		c.play_street_walk(1.0)
		walkers.append(weakref(c))
		heart(c)

func reset_social() -> void:
	couples.clear()
	for item in walkers:
		var c = item.get_ref()
		if is_instance_valid(c): c.queue_free()
	walkers.clear()
	encounter_left = 8.0
	cat_left = 5.0
	walker_left = 35.0

@rpc("authority", "call_remote", "reliable")
func pair_event(first_id: int, second_id: int) -> void:
	var first = game._customer_by_net_id(first_id)
	var second = game._customer_by_net_id(second_id)
	if is_instance_valid(first) and is_instance_valid(second) and not first.has_meta("couple_partner") and not second.has_meta("couple_partner"):
		pair_customers(first,second)

@rpc("authority", "call_remote", "reliable")
func cat_smack(customer_id: int) -> void:
	var audio = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio): audio.play_cat_cartoon_smack()
	var person = game._customer_by_net_id(customer_id)
	if is_instance_valid(person): person.shake_angry(.4,.04,1.0)

func play_love_song(person: Node3D) -> void:
	var audio = AudioStreamPlayer3D.new()
	audio.stream = preload("res://assets/audio/couple_love.wav")
	audio.bus = "SFX"
	audio.volume_db = -9.0
	audio.unit_size = 5.0
	person.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
