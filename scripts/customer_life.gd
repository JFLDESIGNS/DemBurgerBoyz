## Per-customer secondary motion, separate from clip playback and gameplay decisions.
extends Node
const GAZE_WATCH_SECONDS := Vector2(5.0, 8.0)
const GAZE_BREAK_SECONDS := Vector2(0.65, 1.25)
var customer: Node3D
var model: Node
var modular: Node
var look: SkeletonModifier3D
var rng := RandomNumberGenerator.new()
var gaze_cooldown := 0.0
var gaze_left := 0.0
var gaze_strength := 0.0
var with_head := false
var prefer_burger := false
var blink_wait := 0.0
var blink_age := -1.0
var blink_amount := 0.0
var pupil_dilation := 0.0
var hair_value := 0.0
var hair_velocity := 0.0
var hair_sway := 0.0
var forced_target := Vector3.INF
var target_world := Vector3.ZERO
var dance_left := 0.0
var dance_phase := 0.0
var tap_glance_left := 0.0
var tap_glance_target := Vector3.ZERO

func can_grill_dance() -> bool:
	return is_instance_valid(customer) and customer.is_waiting and not customer.is_leaving and not customer._eating and not customer.is_ragdoll and not customer.dialogue_open and not bool(customer.get_meta("serve_in_progress",false))

func start_grill_dance() -> void:
	if can_grill_dance():
		dance_left = 1.5 # Every new tap extends the dance; settle after 1.5 quiet seconds.
		if customer.has_method("_play_wait_stance"): customer._play_wait_stance()

func react_to_grill_tap(at: Vector3) -> bool:
	if not can_grill_dance() or rng.randf() >= 0.5: return false
	tap_glance_target = at
	tap_glance_left = 0.65
	with_head = false
	return true

func _ready() -> void:
	process_priority = 100
	rng.seed = customer.get_instance_id() * 7919
	gaze_cooldown = rng.randf_range(0.1,0.35)
	blink_wait = rng.randf_range(1.0,4.0)
	var cursor := model
	while cursor != null and cursor != customer:
		if cursor.has_method("animate_customer_eyes"):
			modular = cursor
			modular.prepare_for_customer_animation()
			break
		cursor = cursor.get_parent()
	var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton != null:
		look = load("res://scripts/customer_head_look.gd").new()
		look.name = "WaitingHeadLook"
		skeleton.add_child(look)

func _exit_tree() -> void:
	if is_instance_valid(look): look.queue_free()

func _process(delta: float) -> void:
	if not is_instance_valid(customer): return
	var player: AnimationPlayer = customer.get("_anim_player")
	if not customer.get("is_ragdoll") and not customer.get("is_leaving"):
		preload("res://scripts/burger_animation_library.gd").update_customer_props(player, customer.get("_burger_props"))
	var clip := String(player.current_animation) if is_instance_valid(player) else ""
	var forward := clip == "burger/Idle_Forward" or clip.ends_with("/Idle")
	var waiting: bool = customer.get("is_waiting") and not customer.get("is_leaving") and not customer.get("_eating") and not customer.get("_powdering") and not customer.get("_celebrating") and not customer.get("is_ragdoll") and not customer.get("dialogue_open")
	# Eye movement continues through side glances and impatience. Phone/watch,
	# serving, and dialogue retain their own focus instead of looking at the grill.
	var idle_allows_gaze := clip.begins_with("burger/Idle_") or forward or clip == "burger/Impatient_Foot_Tap"
	dance_left = maxf(0.0,dance_left-delta)
	dance_phase += delta * 7.0
	if is_instance_valid(look):
		look.dance_phase = dance_phase
		look.dance_weight = move_toward(look.dance_weight, 1.0 if dance_left > 0.0 and waiting and customer.get("_anim_state") != "grill_dance" else 0.0,delta*3.0)
	tap_glance_left = maxf(0.0, tap_glance_left - delta)
	var tap_active := tap_glance_left > 0.0
	var target := tap_glance_target if tap_active else forced_target
	var game := get_tree().current_scene
	if not target.is_finite() and game != null and game.has_method("customer_attention_target"):
		target = game.customer_attention_target(prefer_burger)
	gaze_left = maxf(0.0, gaze_left - delta)
	if not waiting:
		gaze_left = 0.0
		gaze_cooldown = minf(gaze_cooldown, 0.25)
	elif not idle_allows_gaze:
		# Time spent using the phone also counts as a break; it must not freeze
		# a long cooldown and prevent tracking when an idle resumes.
		gaze_cooldown = maxf(0.0, gaze_cooldown - delta)
	elif gaze_left <= 0.0 and target.is_finite():
		gaze_cooldown -= delta
		if gaze_cooldown <= 0.0:
			gaze_left = rng.randf_range(GAZE_WATCH_SECONDS.x, GAZE_WATCH_SECONDS.y)
			gaze_cooldown = rng.randf_range(GAZE_BREAK_SECONDS.x, GAZE_BREAK_SECONDS.y)
			with_head = modular == null or rng.randf() < 0.35
			prefer_burger = rng.randf() < 0.3
	# A nearby hand takes immediate attention, even during the short gaze break.
	var close_hand := target.is_finite() and target.distance_to(customer.global_position + Vector3(0, 1.3, 0)) < 1.65
	var tracking := waiting and (idle_allows_gaze or tap_active) and (gaze_left > 0.0 or close_hand or tap_active) and target.is_finite()
	gaze_strength = move_toward(gaze_strength, 1.0 if tracking else 0.0, delta * (28.0 if tap_active else 6.0))
	if target.is_finite(): target_world = target
	if is_instance_valid(look):
		look.target_world = target_world
		# Preserve authored side-glance poses; eyes still follow during those clips.
		var head_goal := gaze_strength * (0.95 if close_hand else 0.65) if (with_head or close_hand) and forward and not tap_active else 0.0
		look.look_weight = move_toward(look.look_weight, head_goal, delta * 2.5)
	# Quick lid closure and a slightly slower reopening, with independent clocks.
	blink_wait -= delta
	if blink_age < 0.0 and blink_wait <= 0.0:
		blink_age = 0.0
		blink_wait = rng.randf_range(2.6,6.5)
	blink_amount = 0.0
	if blink_age >= 0.0:
		blink_age += delta
		if blink_age < 0.065: blink_amount = smoothstep(0.0,0.065,blink_age)
		elif blink_age < 0.10: blink_amount = 1.0
		elif blink_age < 0.23: blink_amount = 1.0-smoothstep(0.10,0.23,blink_age)
		else: blink_age = -1.0
	if is_instance_valid(modular):
		var delighted: bool = customer.get("_eating") and not customer.get("is_leaving") and float(customer.get_meta("meal_stars", 0.0)) >= 4.99
		pupil_dilation = move_toward(pupil_dilation, 1.0 if delighted else 0.0, delta * (2.4 if delighted else 3.0))
		modular.animate_customer_eyes(target_world,gaze_strength,blink_amount,pupil_dilation)
		var walking: bool = is_instance_valid(player) and (player.current_animation.ends_with("/Walk") or player.current_animation.ends_with("/Run") or player.current_animation.ends_with("Walk_Away_Angry")) and not customer.get("is_ragdoll")
		var phase := player.current_animation_position*TAU*2.0 if walking else 0.0
		if walking:
			var walk_clip := player.get_animation(player.current_animation)
			phase = player.current_animation_position/maxf(walk_clip.length,0.1)*TAU*2.0
		var goal := sin(phase-0.6)*0.027 if walking else 0.0
		# A damped spring keeps the bounce soft and settles it when walking stops.
		var dt := minf(delta,0.033)
		hair_velocity += ((goal-hair_value)*110.0-hair_velocity*15.0)*dt
		hair_value = clampf(hair_value+hair_velocity*dt,-0.04,0.04)
		hair_sway = lerpf(hair_sway,sin(phase*0.5)*0.015 if walking else 0.0,minf(1.0,delta*9.0))
		modular.animate_customer_hair(hair_value,hair_sway,absf(hair_value)*0.12)
