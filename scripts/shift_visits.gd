extends Node

var game: Node
var unfed_peek_time := 0.0
var theft_rolled := false
var gaze: Node3D
var steal_pending := false
var visit: Node3D
var visit_tween: Tween
var profit_label: Label
var profit_tween: Tween

func _process(delta: float) -> void:
 if not game.playing:
  if is_instance_valid(visit):
   if visit_tween: visit_tween.kill()
   visit.queue_free()
  if is_instance_valid(profit_label): profit_label.hide()
  return
 _update_boss_gaze(delta)
 if game.tutorial_mode or game._cat_delivery_blocks_visit() or (game.mp_enabled and not NetManager.is_host()): return
 var cat = game.window_cat
 if not is_instance_valid(cat): return
 if cat._state != "peek":
  unfed_peek_time = 0.0
  if not steal_pending: theft_rolled = false
  return
 if steal_pending or theft_rolled or not cat.enabled or cat._delivery_peek_active or cat._bag_heist or cat._visit_fed: return
 unfed_peek_time += delta
 if unfed_peek_time < 4.0: return
 theft_rolled = true
 if randf() > .35: return
 var candidates: Array = game.grill.duplicate()
 candidates.shuffle()
 for patty in candidates:
  if eligible_patty(patty):
   if game.mp_enabled: game.mp_cat_steal_patty.rpc(int(patty.net_id))
   else: steal_patty(patty)
   break

func eligible_patty(patty) -> bool:
 if not is_instance_valid(patty): return false
 if patty == game.dragging_patty or patty == game.spatula_patty or patty == game.flicking_patty: return false
 if bool(patty.is_held) or game._is_bun_toast(patty): return false
 if patty.get_meta("cat_snatched", false): return false
 return patty.global_position.z >= game.GRILL_SURFACE_Z + game.GRILL_DEPTH * .5 - .16 or absf(patty.global_position.x - game.GRILL_CENTER_X) >= game.GRILL_WIDTH * .23

func steal_patty(patty: Node3D, committed: bool=false) -> void:
 var cat = game.window_cat
 if not is_instance_valid(cat) or not is_instance_valid(patty): return
 if not committed and (steal_pending or not eligible_patty(patty) or cat._visit_fed): return
 steal_pending = true
 var side := 1.0 if patty.global_position.x >= game.GRILL_CENTER_X else -1.0
 cat.peek_for_patty(side * 1.15)
 if not committed: await get_tree().create_timer(.85).timeout
 steal_pending = false
 if not game.playing or not is_instance_valid(cat) or not is_instance_valid(patty): return
 if not committed and (not eligible_patty(patty) or cat._delivery_peek_active or cat._visit_fed): return
 if game.mp_enabled and NetManager.is_host(): game.mp_cat_commit_theft.rpc(int(patty.net_id))
 patty.set_meta("cat_snatched", true)
 patty.reparent(game.world, true)
 var slot := int(patty.slot_index)
 if slot >= 0 and slot < game.grill.size() and game.grill[slot] == patty: game.grill[slot] = null
 patty.is_held = true
 patty.heating = false
 patty.set_process(false)
 patty.collision_layer = 0
 var start: Vector3 = patty.global_position
 var original_scale: Vector3 = patty.scale
 cat._timer = maxf(cat._timer, 2.0)
 cat.wants_meow.emit(1.15)
 var tongue:=MeshInstance3D.new()
 tongue.name="CatStealingTongue"
 var tube:=CylinderMesh.new()
 tube.top_radius=.017;tube.bottom_radius=.021;tube.height=1.0
 tongue.mesh=tube
 var red:=StandardMaterial3D.new()
 red.albedo_color=Color("DA2844");red.roughness=.5
 tongue.material_override=red
 game.world.add_child(tongue)
 var visual_home: Vector3=cat._visual.position
 cat.set_meta("steal_lean_lift",.34)
 cat._visual.position.y += .34
 cat._visual.rotation_degrees.x=18.0
 var tw := create_tween()
 tw.tween_method(func(t: float):
  if not is_instance_valid(cat) or not is_instance_valid(tongue): return
  var mouth: Vector3=cat.to_global(Vector3(0,.68,.22))
  _stretch_tongue(tongue,mouth,mouth.lerp(start,t))
 ,0.0,1.0,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 tw.tween_interval(.06)
 tw.tween_method(func(t: float):
  if not is_instance_valid(patty) or not is_instance_valid(cat): return
  var mouth: Vector3 = cat.to_global(Vector3(0,.68,.22))
  patty.global_position = start.lerp(mouth,t) + Vector3.UP * sin(t*PI)*.32
  patty.scale = original_scale
  _stretch_tongue(tongue,mouth,patty.global_position)
 ,0.0,1.0,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 tw.tween_callback(func():
  if is_instance_valid(tongue): tongue.queue_free()
  if is_instance_valid(cat):
   cat._visual.rotation_degrees.x=0.0
   cat.remove_meta("steal_lean_lift")
   cat._visual.position=visual_home
  if is_instance_valid(patty):
   patty.reparent(game.patties_root, true)
   patty.remove_meta("cat_snatched")
   patty.collision_layer = 2
   patty.set_process(true)
   game._return_patty_to_spawn_pool(patty)
  if is_instance_valid(cat): cat.feed("patty", true)
 )
 game._flash("The cat swiped a patty! Keep an eye on burgers near the grill edges.",Color("FFCC80"),2.5)

func show_profit(payout: float, cost: float) -> void:
 if not is_instance_valid(profit_label):
  profit_label = Label.new()
  profit_label.name = "OrderProfit"
  profit_label.z_index = 2000
  profit_label.z_as_relative = false
  game.get_node("UI/Root").add_child(profit_label)
  profit_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
  profit_label.offset_left = -770
  profit_label.offset_right = -245
  profit_label.offset_top = 55
  profit_label.offset_bottom = 81
  profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  profit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  game.UiFontsScript.apply_label(profit_label,true,17)
  profit_label.add_theme_color_override("font_outline_color",Color(0,0,0,.8))
  profit_label.add_theme_constant_override("outline_size",2)
 if profit_tween: profit_tween.kill()
 profit_label.text = "Profit %s  ·  Paid %s  ·  Cost %s" % [game._format_money(payout-cost),game._format_money(payout),game._format_money(cost)]
 profit_label.add_theme_color_override("font_color",Color("FFA52E"))
 profit_label.modulate.a = 1.0
 profit_label.show()
 profit_tween = create_tween()
 profit_tween.tween_interval(4.0)
 profit_tween.tween_property(profit_label,"modulate:a",0.0,.5)

func boss_peek(style: int) -> void:
 if is_instance_valid(visit) or game._has_cut_collector() or not game.playing: return
 var boss = game.CustomerScript.new()
 boss.is_cut_collector = true
 var empty_order: Array[String] = []
 boss.setup(empty_order,Color("4A3B2F"),9999.0,0,game.CUT_COLLECTOR_SKIN,0,-1)
 visit = Node3D.new()
 visit.name = "BossWindowPeek"
 game.world.add_child(visit)
 gaze = Node3D.new()
 gaze.name = "CursorGaze"
 visit.add_child(gaze)
 gaze.add_child(boss)
 boss.apply_cut_collector_look()
 boss.set_process(false)
 boss.rotation_degrees.y = 180.0
 boss.hide()
 await get_tree().process_frame
 if not is_instance_valid(boss): return
 var head: Node3D = boss._collector_head_host()
 await get_tree().process_frame
 if not is_instance_valid(boss): return
 boss.show()
 if boss._skeleton != null: boss._skeleton.force_update_all_bone_transforms()
 # Keep the complete character. Offscreen limbs must not project giant
 # moving silhouettes back across the cart during the sideways entrance.
 for mesh in boss.find_children("*","GeometryInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for player in boss.find_children("*","AnimationPlayer",true,false):
  player.pause()
 var head_offset: Vector3 = head.global_position - boss.global_position
 boss.position = -head_offset
 var target: Vector3
 var tucked: Vector3
 match style:
  0:
   target = Vector3(2.70,1.86,2.35)
   tucked = target + Vector3(1.0,0,0)
   visit.rotation_degrees.z = 62.0
  1:
   target = Vector3(-2.06,.99,1.95)
   tucked = target - Vector3(0,1.0,0)
  _:
   var bunting_depth: float = game.window_bunting_root.global_position.z if is_instance_valid(game.window_bunting_root) else 1.52
   target = Vector3(.45,2.54,maxf(2.25,bunting_depth + .75))
   tucked = target + Vector3(0,1.0,0)
   visit.rotation_degrees.z = 180.0
 visit.set_meta("peek_style",style)
 visit.position = tucked
 if game.game_audio != null: game.game_audio.play_boss_peek_boing()
 visit_tween = create_tween()
 visit_tween.tween_property(visit,"position",target,.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 visit_tween.tween_callback(func():
  if randf() < .45: game._play_boss_arrive_sound())
 visit_tween.tween_interval(2.4)
 visit_tween.tween_property(visit,"position",tucked,.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
 visit_tween.tween_callback(visit.queue_free)


func _update_boss_gaze(delta: float) -> void:
 if not is_instance_valid(visit) or not is_instance_valid(gaze) or not is_instance_valid(game.camera): return
 var camera: Camera3D = game.camera
 var cursor: Vector2 = game.get_viewport().get_mouse_position()
 var target: Vector3 = camera.project_position(cursor, 2.0)
 var direction: Vector3 = visit.global_basis.inverse() * (target - visit.global_position)
 var gaze_limit: float = .14 if int(visit.get_meta("peek_style",-1)) == 0 else .42
 var yaw := clampf(atan2(-direction.x,-direction.z),-gaze_limit,gaze_limit)
 var pitch_limit: float = .10 if int(visit.get_meta("peek_style",-1)) == 0 else .28
 var pitch := clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-pitch_limit,pitch_limit)
 pitch += sin(Time.get_ticks_msec() * .0029) * .07
 yaw += sin(Time.get_ticks_msec() * .0021) * .09
 gaze.rotation.x = lerp_angle(gaze.rotation.x,pitch,minf(delta*8.0,1.0))
 gaze.rotation.y = lerp_angle(gaze.rotation.y,yaw,minf(delta*8.0,1.0))


func _stretch_tongue(tongue: MeshInstance3D, from: Vector3, to: Vector3) -> void:
 if not is_instance_valid(tongue): return
 var direction:=to-from
 var length:=maxf(direction.length(),.001)
 var axis:=direction/length if direction.length()>.001 else Vector3.UP
 var right:=axis.cross(Vector3.FORWARD).normalized()
 if right.length()<.01: right=Vector3.RIGHT
 var forward:=right.cross(axis).normalized()
 tongue.global_transform=Transform3D(Basis(right*.8,axis*length,forward*.65),(from+to)*.5)
