extends SceneTree
const Voice=preload("res://scripts/customer_voice.gd")
func _initialize():call_deferred("run")
func run() -> void:
 create_timer(80).timeout.connect(func():push_error("GUEST_EXPERIENCE_TIMEOUT");quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/guest_experience_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 assert(Voice.resolve({"name":"Rowan"})=="female")
 assert(Voice.resolve({"name":"Man5","facial_hair_style":3})=="male")
 assert(Voice.resolve({"name":"Woman4"})=="female")
 assert(Voice.resolve({"customer_voice":"female","facial_hair_style":3})=="female")
 assert(Voice.resolve({},5)=="female" and Voice.resolve({},7)=="male")
 g._build_phone_ui();g._grubbah.set_process(false);g._set_phone_in_truck(true);g._set_phone_app("shop")
 for i in 12:await process_frame
 var phone_rect:Rect2=g.phone_scroll.get_global_rect()
 for id in g._phone_supply_row_refs:
  var button:Button=g._phone_supply_row_refs[id].buy
  assert(button.get_global_rect().end.x<=phone_rect.end.x+1,"Buy clipped for "+str(id))
 var wheel=InputEventMouseButton.new();wheel.position=phone_rect.get_center();wheel.global_position=wheel.position;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
 assert(g._handle_phone_scroll_input(wheel));g._update_phone_scroll_inertia(.1)
 assert(g.phone_scroll.scroll_vertical>0)
 var party=g._phone_party
 var local_scroll:int=g.phone_scroll.scroll_vertical
 party.last_screen=[g._phone_expanded,local_scroll]
 party.pending_view=party.last_screen.duplicate();party.pending_view_until=Time.get_ticks_msec()+800
 party.screen_state("shop",0,g._phone_expanded)
 assert(g.phone_scroll.scroll_vertical==local_scroll,"Old phone echo reset guest scroll")
 party.screen_state("shop",local_scroll,g._phone_expanded)
 assert(party.pending_view.is_empty())
 print("PHONE_LAYOUT_SCROLL_OK")
 var order:Array[String]=["bun_bottom","patty","bun_top"]
 g._spawn_customer_local(order,Color.WHITE,60,0,99001,0,0,false,-1,false,{"name":"Woman4","hair_style":10,"top_style":1},true)
 var host=g.customers.back();host.set_process(false);host.is_waiting=true;host._play_anim("grill_dance");host._anim_player.advance(.4)
 var replica=load("res://scripts/customer.gd").new();replica.setup(order,Color.WHITE,60,0,0,0,-1,host.get_custom_character_preset(),true);g.world.add_child(replica);replica.set_process(false);replica.mp_host_driven=true
 replica.apply_presentation_snapshot(host.presentation_snapshot());replica._update_host_driven_pose(.016)
 assert(replica._anim_player.current_animation==host._anim_player.current_animation)
 assert(absf(replica._anim_player.current_animation_position-host._anim_player.current_animation_position)<.03)
 print("CUSTOMER_ANIMATION_MIRROR_OK")
 g._build_window_cat();g.window_cat.set_process(false);g.window_cat._state="peek";g.window_cat.visible=true
 g.supply_orders=[{"id":"cheese","pack":2,"wait":10.0,"kind":"stock"}]
 g.window_cat._process(.1);assert(not g.window_cat.visible and g.window_cat._delivery_visit_pending)
 g.supply_orders.clear();g._cat_after_delivery_wait=5;g.window_cat._process(1);assert(not g.window_cat.visible)
 g._cat_after_delivery_wait=0;g.window_cat._process(.1);assert(g.window_cat.visible and g.window_cat._state=="rising")
 host.apply_disguise_cat_look();g._disguise_cat_active=true;host.is_waiting=true
 g._begin_cat_supply_delivery("cheese",2,"stock")
 var mail=g.mail_delivery_truck
 assert(mail.disguise_customer==host and host.get_meta("delivery_errand") and not host.is_waiting)
 assert(mail.cat_visual.get_node_or_null("CourierMustache")!=null)
 mail.advance(.9);assert(mail.phase=="waiting" and host.visible)
 mail.advance(1.0);assert(not host.visible and mail.phase!="waiting")
 mail.phase="treat_wait";g._feed_cat_target("cheese")
 assert(mail.phase=="thanks" and not g.window_cat.visible)
 mail.finished=true;mail.restore_cat();assert(host.visible and not host.get_meta("delivery_errand") and g.customers.has(host) and not host.is_waiting)
 assert(g._cat_after_delivery_wait==5 and not g.window_cat.visible)
 print("CAT_DELIVERY_IDENTITY_OK")
 g.grill.resize(g.GRILL_SLOTS);g.grill.fill(null)
 var patty=load("res://scripts/patty.gd").new();patty.net_id=99100;patty.slot_index=0
 g.patties_root.add_child(patty);patty.set_process(false);g.grill[0]=patty
 patty.apply_mp_shape(1);assert(patty.place_ball_waiting)
 g.mp_patty_smash(99100);assert(not patty.place_ball_waiting)
 var state=[[99100],[0],[0],[g.GRILL_SURFACE_Y],[0],[],[],[],[],[],[],[],[],[],[],[],[],[1]]
 g.callv("mp_sync_grill",state)
 assert(not patty.place_ball_waiting,"Stale snapshot undid guest smash")
 state[17]=[0];g.callv("mp_sync_grill",state)
 assert(not patty.has_meta("mp_smash_pending_until"))
 g.grill_residue.resize(g.GRILL_SLOTS);g.grill_residue.fill(0.0)
 g.grill_residue_kind.resize(g.GRILL_SLOTS);g.grill_residue_kind.fill("")
 g.grill_residue_centers.resize(g.GRILL_SLOTS);g.grill_residue_centers.fill(Vector3.ZERO)
 g._mp_cleaned_residue[0]=Vector2.ZERO
 g.mp_sync_grill_mess([1.0],[0],[0],["patty"],[],[],[],[],[],[])
 assert(g.grill_residue[0]==0.0,"Stale snapshot rebuilt cleaned residue")
 g.mp_sync_grill_mess([0.0],[0],[0],[""],[],[],[],[],[],[])
 assert(not g._mp_cleaned_residue.has(0))
 print("GUEST_SMASH_SCRAPE_PREDICTION_OK")
 g.queue_free();await process_frame
 print("GUEST_EXPERIENCE_SMOKE_OK")
 quit()

