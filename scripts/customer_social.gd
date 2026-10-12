extends Node
## Host chooses encounters; reliable events mirror the same reactions on guests.
var game: Node
var encounter_left := 5.0
var recent_chats: Array[int] = []
var cat_left := 5.0
var walker_left := 35.0
var couples: Array = []
var walkers: Array = []
const CONVERSATIONS = [
	["That grill smells amazing.","I was trying not to order fries. I failed."],
	["Is this your usual lunch spot?","It is now. I followed the smell."],
	["I think the cat runs this place.","Definitely management."],
	["Extra cheese is a personality trait.","Finally, someone understands me."],
	["I told myself I would cook today.","You supervised. That counts."],
	["What are you getting?","A burger and a very good afternoon."],
	["I only came out for a walk.","Convenient place to stop walking."],
	["Do fries count as a vegetable?","I'm not asking any more questions."],
	["I can hear that burger sizzling.","Best song on the radio."],
	["Want to split some fries?","We both know how that ends."],
	["I brought my appetite.","Did it bring money?"],
	["That bird has its own house.","Better rent than mine."],
	["I should try something new.","Extra pickles. Be brave."],
	["The cat just looked at my lunch.","Your lunch has been selected."],
	["I'm saving room for ice cream.","I have a separate ice cream stomach."],
	["This is my lunch break workout.","One burger curl at a time."],
	["Did you smell the toasted bun?","From two streets away."],
	["I said I wasn't hungry.","Your stomach filed an objection."],
	["How spicy is the mustard?","Enough to wake up your afternoon."],
	["That cook has great aim.","Let's hope they like us."],
	["No meetings for an hour.","Then this is a holiday."],
	["I ordered a small drink.","I'll try not to judge."],
	["It's nice eating outside.","Until the bird orders a bite."],
	["You have ketchup on your sleeve.","I'm taking some home."],
	["I could eat here every day.","See you tomorrow, then."],
	["What's the secret ingredient?","Someone else doing the dishes."]
]
func next_conversation() -> int:
	var choices: Array[int] = []
	for i in CONVERSATIONS.size():
		if not recent_chats.has(i): choices.append(i)
	var selected: int = choices.pick_random()
	recent_chats.append(selected)
	if recent_chats.size() > 12: recent_chats.pop_front()
	return selected

func conversation_bubble(person: Node3D, text: String) -> void:
	var ui=game.get_node_or_null("UI/Root")
	if not is_instance_valid(ui):return
	var bubble=preload("res://scripts/customer_conversation_bubble.gd").new()
	ui.add_child(bubble);bubble.setup(person,text)


static func outcome(roll: float) -> String:
	if roll < 0.65: return "reply"
	if roll < 0.85: return "away"
	if roll < 0.87: return "love"
	return "quiet"

func _ready() -> void:
	name = "CustomerSocial"

func encounter_outcome(a: Node, b: Node, roll: float) -> String:
	var checked: Dictionary = a.get_meta("romance_checked_partners", {})
	var first := not checked.has(b.get_instance_id())
	if first:
		checked[b.get_instance_id()] = true
		a.set_meta("romance_checked_partners", checked)
		var reverse: Dictionary = b.get_meta("romance_checked_partners", {})
		reverse[a.get_instance_id()] = true
		b.set_meta("romance_checked_partners", reverse)
		return outcome(roll) # One 2% opportunity at the start of this pair's interaction.
	if roll < .65: return "reply"
	if roll < .85: return "away"
	return "quiet"

func eligible(c) -> bool:
	if not is_instance_valid(c) or bool(c.get_meta("mobile_order", false)) or bool(c.get_meta("delivery_driver", false)): return false
	return is_instance_valid(c) and c.has_method("get_customer_voice") and c.is_waiting and not c.is_leaving and not c.is_ragdoll and not c._eating and not c.dialogue_open and not c.is_cut_collector and not c.is_challenge_guest and not c.is_disguise_cat and not c.is_terrorist and not bool(c.get_meta("truck_smack_busy",false)) and not bool(c.get_meta("serve_in_progress", false)) and not c.has_meta("couple_partner")

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
		encounter_left = randf_range(7.6, 9.0)
		if waiting.size() >= 2:
			var a = waiting.pick_random()
			var nearby = waiting.filter(func(c): return c != a and c.position.distance_to(a.position) < 3.5)
			if not nearby.is_empty():
				var b = nearby.pick_random()
				var kind = encounter_outcome(a,b,randf())
				var chat := next_conversation()
				encounter(a,b,kind,chat)
				if game.mp_enabled and NetManager.is_online(): social_event.rpc(game._customer_net_id(a),game._customer_net_id(b),kind,chat)
	if cat_left <= 0.0:
		cat_left = randf_range(7.0, 12.0)
		var cat = game.window_cat
		if is_instance_valid(cat) and cat.visible and cat._state == "peek" and not cat._delivery_peek_active and not waiting.is_empty():
			for person in waiting:
				if not bool(person.get_meta("cat_greeted",false)):
					person.set_meta("cat_greeted",true)
					if randf()<.95:
						encounter(person,null,"cat_notice")
						if game.mp_enabled and NetManager.is_online():social_event.rpc(game._customer_net_id(person),-1,"cat_notice")
			var first=first_ordering_customer()
			var c=first if eligible(first) else waiting.pick_random()
			if cat.position.distance_to(c.position)<4.0 and randf()<.95:
				var kind="cat_love"
				if c==first: kind="cat_swat" if randf()<.25 else ("cat_rub" if randf()<.4 else "cat_love")
				encounter(c,null,kind)
				if game.mp_enabled and NetManager.is_online(): social_event.rpc(game._customer_net_id(c),-1,kind)

	if walker_left <= 0.0:
		walker_left = randf_range(40.0,75.0)
		if not couples.is_empty() and walkers.is_empty():
			var available = couples.filter(func(pair): return not is_instance_valid(pair[0].get("original").get_ref()) and not is_instance_valid(pair[1].get("original").get_ref()))
			if available.is_empty(): return
			var pair = available.pick_random().duplicate(true)
			for person in pair: person.erase("original")
			var direction = game._bg_people_lane_dir()
			if direction == 0.0: direction = 1.0
			spawn_couple(pair, direction)
			if game.mp_enabled and NetManager.is_online(): couple_walk.rpc(pair, direction)

@rpc("authority", "call_remote", "reliable")
func social_event(a_id: int, b_id: int, kind: String, chat: int = -1) -> void:
	var a = game._customer_by_net_id(a_id)
	var b = game._customer_by_net_id(b_id)
	if is_instance_valid(a): encounter(a,b,kind,chat)

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

func wawa(c, _pitch := 1.0) -> void:
	if not is_instance_valid(c) or not is_instance_valid(game.game_audio): return
	var voice: String = c.get_customer_voice()
	game.game_audio.play_customer_wawa_click(0.5, voice, 2.5 if voice == "male" else 0.0)
	if c.has_method("animate_wawa"):
		c.animate_wawa(1.5 if voice == "female" else 1.15)

func heart(c) -> void:
	preload("res://scripts/love_hearts.gd").burst(c, Vector3(0,2.4,.05), 1.0)

func encounter(a,b,kind: String, chat: int = -1) -> void:
	if kind.begins_with("cat_"):
		var cat = game.window_cat
		if not is_instance_valid(cat) or not eligible(a): return
		if kind=="cat_notice":
			a.set_meta("likes_cat",true);heart(a);glance(a,cat.head_global());return
		a.set_meta("likes_cat",true)
		heart(a)
		if a==first_ordering_customer(): a.pet_cat()
		glance(a,cat.global_position + Vector3(0,.45,0))
		wawa(a,1.65)
		cat.set_meta("social_look",a.global_position)
		cat.set_meta("social_look_until",Time.get_ticks_msec()+3000)
		var cat_ref = weakref(cat)
		var person_ref = weakref(a)
		create_tween().tween_interval(.75).finished.connect(func():
			var animal = cat_ref.get_ref()
			var person = person_ref.get_ref()
			if is_instance_valid(animal) and eligible(person) and animal._state == "peek":
				if not animal.mp_puppet:
					if kind=="cat_rub": animal.rub_customer(person)
					else: animal.react_to_customer(person,kind != "cat_swat")
				if kind == "cat_love":
					animal.wants_meow.emit(1.2)
					heart(person)
					person.set_meta("likes_cat", true))
		return
	if not is_instance_valid(b): return
	if chat < 0: chat = next_conversation()
	glance(a,b.global_position + Vector3(0,1.5,0))
	wawa(a)
	if chat >= 0 and chat < CONVERSATIONS.size(): conversation_bubble(a,CONVERSATIONS[chat][0])
	var first_ref = weakref(a)
	var second_ref = weakref(b)
	create_tween().tween_interval(3.7).finished.connect(func():
		var first = first_ref.get_ref()
		var second = second_ref.get_ref()
		if not eligible(first) or not eligible(second): return
		if chat >= 0 and chat < CONVERSATIONS.size():
			conversation_bubble(second,CONVERSATIONS[chat][1])
			if kind != "reply": wawa(second)
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
	if not is_instance_valid(a) or not is_instance_valid(b): return
	for person in [a, b]:
		if bool(person.get_meta("mobile_order", false)) or bool(person.get_meta("delivery_driver", false)): return
	a.set_meta("couple_partner",weakref(b)); b.set_meta("couple_partner",weakref(a))
	a.set_meta("couple_first",true); b.set_meta("couple_first",false)
	var pair = [{"preset":a.get_custom_character_preset(),"skin":a.skin_idx},{"preset":b.get_custom_character_preset(),"skin":b.skin_idx}]
	pair[0]["original"] = weakref(a); pair[1]["original"] = weakref(b)
	couples.append(pair)
	if couples.size() > 8: couples.pop_front()
	heart(a); heart(b); play_love_song(a)
	for delay in [.4, .8, 1.2]:
		var ar = weakref(a); var br = weakref(b)
		create_tween().tween_interval(delay).finished.connect(func():
			if is_instance_valid(ar.get_ref()): heart(ar.get_ref())
			if is_instance_valid(br.get_ref()): heart(br.get_ref()))
	glance(b,a.global_position+Vector3(0,1.5,0),4.0)
	# Keep both ordinary tickets, adding only a heart beside each order number.
	var elapsed_a = a.order_elapsed_sec
	var elapsed_b = b.order_elapsed_sec
	game._remove_ticket(a); game._remove_ticket(b)
	game._create_ticket(a); game._create_ticket(b)
	a.order_elapsed_sec = elapsed_a
	b.order_elapsed_sec = elapsed_b
	game._highlight_tickets()

func partner(c):
	if not is_instance_valid(c) or not c.has_meta("couple_partner"): return null
	return c.get_meta("couple_partner").get_ref()

func decorate_ticket(c, box: VBoxContainer) -> void:
	var other = partner(c)
	if not is_instance_valid(other): return
	for child in box.get_children():
		if child is Label:
			child.text += " ♥"
			return

func update_tickets() -> void:
	pass # Normal ticket selection and visibility also apply to couples.

@rpc("authority", "call_remote", "reliable")
func couple_walk(pair: Array, direction: float = 1.0) -> void:
	spawn_couple(pair, direction)

func spawn_couple(pair: Array, direction: float = 0.0) -> void:
	var pace = (game.BG_PEOPLE_SPEED_MIN + game.BG_PEOPLE_SPEED_MAX) * .5
	if direction == 0.0: direction = game._bg_people_lane_dir()
	if direction == 0.0: direction = 1.0
	var pair_key := Time.get_ticks_usec()
	for i in 2:
		var c = preload("res://scripts/customer.gd").new()
		c.is_street_pedestrian = true
		c.setup([] as Array[String],Color.WHITE,9999.0,0,int(pair[i].get("skin",0)),0,-1,pair[i].get("preset",{}),true)
		game.customers_root.add_child(c)
		c.position = Vector3(-direction * (game.BG_PEOPLE_EDGE_X + i*.45),game._bg_people_y(),game._bg_people_z()+i*.65)
		c.scale = Vector3.ONE * game._bg_people_scale()
		c.rotation_degrees.y = c.WALK_PLUS_X_YAW if direction > 0 else c.WALK_MINUS_X_YAW
		c.set_meta("street_spacing", true)
		c.set_meta("street_pair", pair_key)
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
	var target=game._customer_by_net_id(customer_id)
	if target!=first_ordering_customer() or not eligible(target):return
	var audio = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio):
		audio.play_cat_cartoon_smack()
		audio.play_cat_begging_meow(1.15)
	var person = game._customer_by_net_id(customer_id)
	if is_instance_valid(person):
		person.shake_angry(.4,.04,1.0)
		wawa(person,1.2)

func play_love_song(person: Node3D) -> void:
	var audio = AudioStreamPlayer3D.new()
	audio.stream = preload("res://assets/audio/couple_love.wav")
	audio.bus = "SFX"
	audio.volume_db = -9.0
	audio.unit_size = 5.0
	person.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func first_ordering_customer() -> Node3D:
	for c in game.customers:
		if is_instance_valid(c) and not c.is_leaving and not bool(c.get_meta("meal_aside",false)) and not c.is_cut_collector and not c.is_terrorist and not bool(c.get_meta("delivery_errand",false)):
			return c
	return null
