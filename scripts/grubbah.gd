extends Node
# Host-owned mobile fulfillment. Visuals are reconstructed from a revisioned snapshot.
const DRIVER_APPROACH = 1.0
const DRIVER_WALK = 2.25
const DRIVER_RETURN = 1.5
const DRIVER_EXIT = .85
const DATA = preload("res://scripts/game_data.gd")
const PACK = "res://models/burgerpack/try2/"
var game: Node
var state: Dictionary = {}
var revision = 0
var next_number = 1
var wait_time = 95.0
var age = 0.0
var sync_time = 0.0
var last_day = -1
var was_playing = false
var online_seen = false
var page: VBoxContainer
var body: Label
var status_label: Label
var total_label: Label
var arrival_tween: Tween
var action: Button
var decline: Button
var ticket_owner: Node3D
var wrap_button: Button
var paper3d: Node3D
var paper_outline: MeshInstance3D
var flying_ticket: Sprite3D
var bag_finish: Label3D
var bag_glow: Node3D
var bag_ticket: Sprite3D
var ticket_view: SubViewport
var ticket_flight_start: Vector3
var packing_tween: Tween
var board_surface=Vector3.ZERO
var props: Node3D
var napkins: Node3D
var knife: Node3D
var bag: Node3D
var wrapped: Node3D
var courier: Node3D
var driver_style = -1
var car_style = -1
const DRIVER_CARS = [preload("res://assets/vehicles/sugar_street/lagoon_hatch.glb"),preload("res://assets/vehicles/sugar_street/guava_micro.glb"),preload("res://assets/vehicles/sugar_street/custard_pickup.glb")]
var car_ground_y: float = 0.0
var screech: AudioStreamPlayer3D
var arrival_screeched = false
var car: Node3D
var ledge: MeshInstance3D
var knife_owner = 0
var knife_home = Vector3.ZERO
var knife_home_rotation = Vector3(0,0,-1.25)
var wrap_sound: AudioStreamPlayer
var last_wrap_sound_ms = -1000
var paper_start = Vector2.ZERO
var last_phase = ""
var flash_time = 0.0
var packet_time = 0.0
var remote_knife_pos = Vector3.ZERO
func holding_knife() -> bool:
 return knife_owner==(get_node("/root/NetManager").my_id() if online() else 1)
func host() -> bool:
 return not game.mp_enabled or get_node("/root/NetManager").is_host()
func online() -> bool:
 return game.mp_enabled and get_node("/root/NetManager").is_online()
func setup(g: Node, parent: Control) -> void:
 game=g
 name="Grubbah"
 wrap_sound=AudioStreamPlayer.new();wrap_sound.stream=preload("res://sounds/ticket/paper_rustle.wav");wrap_sound.bus="SFX";wrap_sound.volume_db=-5;add_child(wrap_sound)
 page=VBoxContainer.new();page.name="GrubbahApp";page.add_theme_constant_override("separation",12);parent.add_child(page)
 var title=Label.new();title.text="grubbah";title.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"));title.add_theme_font_size_override("font_size",34);title.modulate=Color("FFAB49");page.add_child(title)
 var subtitle=Label.new();subtitle.text="PICKUP ORDERS";subtitle.add_theme_font_size_override("font_size",12);subtitle.modulate=Color("B7D4C7");page.add_child(subtitle)
 var card=PanelContainer.new();var card_style=StyleBoxFlat.new();card_style.bg_color=Color("153832");card_style.set_corner_radius_all(12);card_style.content_margin_left=14;card_style.content_margin_right=14;card_style.content_margin_top=14;card_style.content_margin_bottom=14;card.add_theme_stylebox_override("panel",card_style);page.add_child(card)
 var contents=VBoxContainer.new();contents.add_theme_constant_override("separation",10);card.add_child(contents)
 status_label=Label.new();status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.add_theme_font_size_override("font_size",14);status_label.modulate=Color("FFC875");contents.add_child(status_label)
 body=Label.new();body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_font_size_override("font_size",16);body.modulate=Color("FFF3D9");contents.add_child(body)
 total_label=Label.new();total_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;total_label.add_theme_font_size_override("font_size",18);total_label.modulate=Color("98E2AF");contents.add_child(total_label)
 action=Button.new();action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.custom_minimum_size.y=44;action.pressed.connect(func():request("action"));page.add_child(action)
 var button_style=StyleBoxFlat.new();button_style.bg_color=Color("DC8E39");button_style.set_corner_radius_all(10);action.add_theme_stylebox_override("normal",button_style);action.add_theme_color_override("font_color",Color("231F19"))
 decline=Button.new();decline.text="Cancel order";decline.add_theme_color_override("font_color",Color("EDAAA0"));decline.pressed.connect(func():request("cancel"));page.add_child(decline)
 page.hide()
 var ui=game.get_node("UI/Root")
 wrap_button=Button.new();wrap_button.text="WRAP BURGER";wrap_button.custom_minimum_size=Vector2(175,38);wrap_button.pressed.connect(func():request("seal" if str(state.get("phase",""))=="bagging" else "wrap"));ui.add_child(wrap_button)
 var gold=StyleBoxFlat.new();gold.bg_color=Color("574327");gold.border_color=Color("FFCE48");gold.set_border_width_all(3);gold.set_corner_radius_all(10);wrap_button.add_theme_stylebox_override("normal",gold)
 refresh()
func show_app(id: String) -> void:
 page.visible=id=="grubbah"
 if page.visible: refresh()
func refresh() -> void:
 if not is_instance_valid(page): return
 var phase=str(state.get("phase",""))
 var lines=""
 for id in state.get("items",[]):
  if id in ["bun_bottom","bun_top"]:continue
  lines+=str(DATA.INGREDIENT_LABELS.get(id,id))+"\n"
 var number=display_number()
 var notes={"offered":"NEW ORDER","accepted":"IN QUEUE","paper":"BUILDING","wrapping":"WRAPPING", "bagging":"PACK THE SIDES", "sealed":"HEADING TO PICKUP", "pickup":"DRIVER ARRIVING", "collected":"PICKED UP"}
 status_label.text=str(notes.get(phase,"OPEN FOR ORDERS"))
 if phase=="accepted" and is_instance_valid(ticket_owner):status_label.text="YOUR TURN" if is_selected() else "IN QUEUE · #%d" % (game.tickets.keys().find(ticket_owner)+1)
 body.text="Orders arrive automatically.\n\nThey join the regular ticket queue." if phase=="" else number+"\n\n"+lines.strip_edges()
 total_label.text="" if phase=="" else "$%d  +  quality tip" % int(state.get("base",0))
 action.visible=false
 action.text={"offered":"ACCEPT ORDER","accepted":"START WRAPPING","paper":"WRAP BURGER","bagging":"PACK SIDES + SEAL"}.get(phase,"")
 decline.visible=phase in ["offered","accepted","paper","bagging"]
 decline.text="Cancel order" if phase!="bagging" else "Cancel • discard packed food"
 sync_ticket()
 wrap_button.visible=false and game.playing and phase=="bagging" and game.selected_customer==ticket_owner
 wrap_button.text="PACK SIDES + SEAL" if phase=="bagging" else "WRAP BURGER"
func sync_ticket() -> void:
 var live=game.playing and str(state.get("phase","")) in ["accepted","paper","wrapping","bagging","sealed"]
 if not live:
  if is_instance_valid(ticket_owner):
   game._remove_ticket(ticket_owner)
   if game.selected_customer==ticket_owner:game.selected_customer=null;game._highlight_tickets()
   ticket_owner.queue_free();ticket_owner=null
  return
 if not is_instance_valid(game.ticket_box):return
 if not is_instance_valid(ticket_owner):
  ticket_owner=preload("res://scripts/mobile_ticket_owner.gd").new();ticket_owner.name="MobileTicketOwner";ticket_owner.order.assign(state.items);ticket_owner.is_waiting=true;ticket_owner.patience=99999;ticket_owner.patience_max=99999
  ticket_owner.set_meta("mobile_order",true);ticket_owner.set_meta("mobile_number",int(state.number));ticket_owner.set_meta("mp_net_id",1000000+int(state.number));add_child(ticket_owner)
  game._create_ticket(ticket_owner)
  if bool(state.get("selected",false)) or not is_instance_valid(game.selected_customer):game._select_ticket_local(ticket_owner)
  announce_arrival.call_deferred(ticket_owner)
 if game.tickets.has(ticket_owner):
  var wrap=game.tickets[ticket_owner]
  wrap.visible=str(state.phase)!="sealed"
func is_selected() -> bool:
 return is_instance_valid(ticket_owner) and game.selected_customer==ticket_owner
func select_order() -> void:
 sync_ticket()
 if is_instance_valid(ticket_owner):
  game._select_ticket_local(ticket_owner)
  state["selected"]=true
func auto_lay_paper() -> void:
 if host() and str(state.get("phase",""))=="accepted" and is_selected() and game.stations[0].get("patties",[]).is_empty():
  set_phase("paper")
func holds_customer_timers() -> bool:
 return is_selected() and str(state.get("phase","")) in ["accepted","paper","wrapping","bagging"]
func bag_station_pos() -> Vector3:return board_pos()+Vector3(.12,.2182,.32)
func _process(delta: float) -> void:
 if not is_instance_valid(game):return
 if not game.playing:
  if was_playing and host():state={};knife_owner=0;publish()
  was_playing=false
  if is_instance_valid(props):props.hide()
  refresh();return
 if game.get_tree().paused:return
 if not was_playing:
  was_playing=true
  if host():wait_time=95.0 if game.day==1 else 35.0;last_day=game.day
 if not is_instance_valid(props):build_props()
 props.show()
 if online() and not online_seen:
  online_seen=true
  if not host():request_snapshot.rpc_id(1)
 age+=delta;sync_time+=delta;flash_time=maxf(0,flash_time-delta)
 if host():
  auto_lay_paper()
  if state.is_empty() and not game.tutorial_mode and game._challenge_phase=="":
   wait_time-=delta
   if wait_time<=0:new_order()
  elif not state.is_empty():
   var phase=str(state.phase)
   if phase=="offered" and age>90:state={};wait_time=45;publish()
   elif phase=="wrapping" and age>=1.2:
    if burger_ready():consume_build();set_phase("bagging")
    else:set_phase("paper")
   elif phase=="sealed" and age>=.75:set_phase("pickup")
   elif phase=="pickup" and age>=DRIVER_APPROACH+DRIVER_WALK:
    pay_order();set_phase("collected")
   elif phase=="collected" and age>=DRIVER_RETURN+DRIVER_EXIT:
    state={};wait_time=randf_range(160,240) if game.day==1 else randf_range(55,110)/maxf(.85,float(game._location_stats().get("spawn_rate",1.0)));publish()
  if sync_time>1.0:
   sync_time=0
   if knife_owner>0 and online() and knife_owner!=get_node("/root/NetManager").my_id() and not multiplayer.get_peers().has(knife_owner):knife_owner=0
   publish()
 update_visuals(delta)
func new_order() -> void:
 var items: Array=["bun_bottom","patty"]
 if randf()<.8:items.append("cheese")
 if game.day>1:items.append(["lettuce","pickle","ketchup"].pick_random())
 items.append("bun_top")
 if game._owns_fryer_machine() and randf()<.45:items.append("fries")
 if game._owns_soda_machine() and randf()<.45:items.append("soda_cola")
 state={"number":next_number,"items":items,"phase":"accepted","selected":false,"driver_skin":randi_range(0,6),"car_style":randi_range(0,2),"base":DATA.order_value(items),"paid":false,"quality":1.0};next_number+=1;age=0;publish()
 game._flash("Grubbah: mobile order added to the queue",Color("FFCF76"))
func request(kind: String) -> void:
 if not game.playing:return
 if online() and not host():command.rpc_id(1,kind,int(state.get("number",0)))
 else:apply_command(kind,int(state.get("number",0)),get_node("/root/NetManager").my_id() if online() else 1)
@rpc("any_peer","call_remote","reliable")
func command(kind: String, number: int) -> void:
 if not host():return
 apply_command(kind,number,multiplayer.get_remote_sender_id())
func apply_command(kind: String, number: int, peer: int) -> void:
 if not game.playing:return
 if kind=="knife":
  if not bool(game.owned_machines.get("chef_knife",false)):return
  if knife_owner==0:knife_owner=peer
  elif knife_owner==peer:knife_owner=0
  publish();return
 if state.is_empty() or number!=int(state.number):return
 var phase=str(state.phase)
 if kind in ["decline","cancel"] and phase in ["offered","accepted","paper","bagging"]:
  state={};wait_time=70;publish();return
 if kind=="action":
  kind={"offered":"accept","accepted":"paper","paper":"wrap","bagging":"seal"}.get(phase,"")
 match kind:
  "accept":
   if phase=="offered":state["selected"]=true;set_phase("accepted");select_order()
  "paper":
   if phase!="accepted":return
   if not game.stations[0].get("patties",[]).is_empty():notice("Clear the build before laying paper.",peer);return
   state["selected"]=true;set_phase("paper");select_order()
  "wrap":
   if phase!="paper":return
   if not burger_ready():notice("Finish the mobile recipe first.",peer);return
   if not game.stations[0].items.has("bun_top"):
    if not game._crown_serve_burger(0):notice("Need a top bun in stock.",peer);return
    game._refresh_station(0)
   if online():game._mp_broadcast_station(0)
   state["quality"]=game._station_freshness_ratio(0)
   var patties: Array=game.stations[0].get("patties",[])
   for patty in patties:
    if is_instance_valid(patty):state.quality=minf(state.quality,patty.doneness_multiplier())
   set_phase("wrapping")
  "seal":
   if phase!="bagging":return
   var sodas=DATA.order_soda_ids(state.items)
   var drink:Node3D=null
   if not sodas.is_empty():
    drink=game._find_ready_drink_for_soda(str(sodas[0]))
    if drink==null:notice("Set a full cola on the tray first.",peer);return
   if DATA.wants_fries(state.items) and game.fryer_ready_servings<=0:notice("Cook the fries first.",peer);return
   if drink!=null:
    game._serve_cup_node=drink;game._consume_cup_for_serve()
   if DATA.wants_fries(state.items):
    game.fryer_ready_servings-=1;game._refresh_ready_fries_visuals()
   if online():game._mp_broadcast_economy()
   set_phase("sealed")
func notice(text: String, peer: int) -> void:
 if online() and peer!=get_node("/root/NetManager").my_id():show_notice.rpc_id(peer,text)
 else:game._flash(text,Color("FFD478"))
@rpc("authority","call_remote","reliable")
func show_notice(text: String) -> void:game._flash(text,Color("FFD478"))
func burger_ready() -> bool:
 if game.stations.is_empty():return false
 var st:Dictionary=game.stations[0]
 var items:Array=st.items.duplicate()
 if not items.has("bun_top"):items.append("bun_top")
 return not st.get("patties",[]).is_empty() and bool(DATA.compare_orders(items,DATA.order_burger_items(state.get("items",[]))).get("perfect",false)) and not game._station_sauce_in_flight(0)
func consume_build() -> void:
 var pic=game._make_review_burger_snapshot(0)
 if pic!=null:state["photo"]=pic.get_image().save_png_to_buffer()
 game._clear_station(0)
 if online():game._mp_broadcast_station(0)
func set_phase(phase: String) -> void:
 state.phase=phase;age=0;publish()
func snapshot_payload() -> Dictionary:
 var data=state.duplicate()
 # The burger photo is sent once with the sales history, not every animation tick.
 data.erase("photo")
 return data
func publish() -> void:
 revision+=1
 if not state.is_empty() and is_instance_valid(ticket_owner):state["selected"]=is_selected()
 refresh()
 game._refresh_customer_queue_timers()
 if online():snapshot.rpc(snapshot_payload(),revision,age,knife_owner)
@rpc("any_peer","call_remote","reliable")
func request_snapshot() -> void:
 if host():snapshot.rpc_id(multiplayer.get_remote_sender_id(),snapshot_payload(),revision,age,knife_owner)
@rpc("authority","call_remote","reliable")
func snapshot(data: Dictionary, rev: int, elapsed: float, owner: int) -> void:
 if host() or rev<revision:return
 var same_phase=str(state.get("phase",""))==str(data.get("phase","")) and int(state.get("number",-1))==int(data.get("number",-2))
 state=data.duplicate(true);revision=rev;age=maxf(age,elapsed) if same_phase else elapsed;knife_owner=owner;refresh()
 game._refresh_customer_queue_timers()
 if bool(state.get("selected",false)) and is_instance_valid(ticket_owner) and not is_selected():game._select_ticket_local(ticket_owner)
func pay_order() -> void:
 if bool(state.get("paid",false)):return
 state.paid=true
 var base=int(state.base);var tip=int(round(float(base)*.25*clampf(float(state.quality),0,1)))
 var cost=0.0
 for id in state.items:
  if str(id) in game.SUPPLY_IDS:cost+=game._supply_buy_unit_cost(str(id))
 if not DATA.order_soda_ids(state.items).is_empty():cost+=game._supply_buy_unit_cost("syrup_cola")*game.SUPPLY_BUY_PACK*game.SODA_TANK_CUP_COST/game.SODA_TANK_SYRUP_REFILL
 game.money+=base+tip;game.shift_food_sales+=base;game.shift_tips+=tip;game.total_served+=1
 game._achievement_event("orders");game._achievement_event("earnings",base+tip)
 game.order_history_revision+=1
 game.order_history.append({"number":game.order_history_revision,"day":game.day,"items":"Grubbah "+display_number()+" · "+", ".join(state.items),"sale":base,"tip":tip,"cost":cost,"profit":base+tip-cost,"perfect":float(state.quality)>=1,"photo":state.get("photo",PackedByteArray())})
 if game.order_history.size()>100:game.order_history.pop_front()
 game._show_order_profit(base+tip,cost);game._update_hud()
 if is_instance_valid(game._order_insights):game._order_insights.refresh()
 if game.game_audio:game.game_audio.play_order_up()
 if online():
  game.mp_order_history.rpc(game.order_history,game.order_history_revision);game.mp_order_profit.rpc(base+tip,cost);game._mp_broadcast_economy()
func fitted(file: String, width: float) -> Node3D:
 var root=Node3D.new()
 var model=load(PACK+file+".glb").instantiate();root.add_child(model)
 var bounds=game._shop_preview_bounds(model)
 var scale_factor=width/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
 model.scale=Vector3.ONE*scale_factor;model.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_factor
 return root
func board_pos() -> Vector3:
 if board_surface!=Vector3.ZERO:return board_surface
 if is_instance_valid(game.build_cutting_board):
  var box=game._mesh_aabb_local(game.build_cutting_board)
  return game.build_cutting_board.to_global(Vector3(box.get_center().x,box.end.y+.015,box.get_center().z))
 return Vector3(.65,1.15,.6)
func build_props() -> void:
 props=Node3D.new();props.name="GrubbahProps";game.world.add_child(props)
 var base=board_pos();board_surface=base
 napkins=Node3D.new();props.add_child(napkins);napkins.position=base+Vector3(.49,-.055,.23)
 for i in 5:
  var sheet=fitted("SM_BurgerPackagingPaper",.27);sheet.position.y=i*.009;sheet.rotation.y=i*.025;napkins.add_child(sheet)
 var stack_logo=Sprite3D.new();stack_logo.name="BurgerPalsWrapLogo";stack_logo.texture=preload("res://assets/ui/burger_pals_letter_mask.png");stack_logo.pixel_size=.00018
 stack_logo.material_override=ShaderMaterial.new();stack_logo.material_override.shader=preload("res://shaders/brand_lettering_cup.gdshader");stack_logo.material_override.set_shader_parameter("mask_tex",stack_logo.texture)
 var stack_bounds=game._shop_preview_bounds(napkins)
 stack_logo.position=Vector3(0,stack_bounds.end.y+.002,0);stack_logo.rotation=Vector3(-PI*.5,0,PI);napkins.add_child(stack_logo)
 paper3d=fitted("SM_BurgerPackagingPaper",.45);paper3d.name="MobileBurgerPaper";props.add_child(paper3d)
 var paper_box=game._shop_preview_bounds(paper3d)
 var logo=Sprite3D.new();logo.texture=preload("res://assets/ui/burger_pals_letter_mask.png");logo.pixel_size=.00021;logo.material_override=ShaderMaterial.new();logo.material_override.shader=preload("res://shaders/brand_lettering_cup.gdshader");logo.material_override.set_shader_parameter("mask_tex",logo.texture);logo.position=Vector3(0,paper_box.end.y+.003,-.10);logo.rotation=Vector3(-PI*.5,0,PI);paper3d.add_child(logo)
 paper_outline=MeshInstance3D.new();var line=ImmediateMesh.new();line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
 for point in [Vector3(-.23,.007,-.19),Vector3(.23,.007,-.19),Vector3(.23,.007,.19),Vector3(-.23,.007,.19),Vector3(-.23,.007,-.19)]:line.surface_add_vertex(point)
 line.surface_end();paper_outline.mesh=line;paper_outline.material_override=game._make_basic_mat(Color("FFD147"));paper_outline.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;paper3d.add_child(paper_outline)
 flying_ticket=Sprite3D.new();flying_ticket.texture=game._ticket_paper_texture(false);flying_ticket.pixel_size=.0004;flying_ticket.billboard=BaseMaterial3D.BILLBOARD_ENABLED;props.add_child(flying_ticket)
 knife=fitted("SM_ChefsKnife",.56);props.add_child(knife);knife_home=game.oil_home+Vector3(-.20,-.10,-.05);knife.position=knife_home;knife.rotation=knife_home_rotation
 bag=fitted("SM_FastFoodBagOpen",.40);props.add_child(bag)
 wrapped=fitted("SM_BurgerPackagingPaperWrapped",.25);props.add_child(wrapped)
 add_bag_label()
 ledge=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.85,.06,.38);ledge.mesh=box;ledge.material_override=game._make_basic_mat(Color("727E81"),.7,.25);props.add_child(ledge);ledge.position=Vector3(.4192,1.03,1.85)
 var car_scene=load("res://assets/vehicles/sugar_street/lagoon_hatch.glb");car=car_scene.instantiate();props.add_child(car);car.scale=Vector3.ONE*game.STREET_CAR_MODEL_SCALE;car.rotation.y=0;car_ground_y=-.06-game._shop_preview_bounds(car).position.y*car.scale.y;car.hide()
 screech=AudioStreamPlayer3D.new();screech.stream=preload("res://sounds/vehicles/mail_truck_tire_screech.mp3");screech.bus="SFX";screech.volume_db=-4;screech.unit_size=5.0;screech.max_distance=35;car.add_child(screech)
 courier=game.CustomerScript.new();courier.set_meta("delivery_driver",true);courier.is_street_pedestrian=true;courier.setup(["bun_bottom","patty","bun_top"] as Array[String],Color("E8AC6F"),9999,0,2);props.add_child(courier);courier.set_process(false);courier.set_physics_process(false);courier.play_street_run(1.45);courier.hide()
 for n in courier.find_children("*","Label3D",true,false):n.hide()
func prepare_bag_ticket() -> void:
 if is_instance_valid(ticket_view):ticket_view.queue_free()
 ticket_view=SubViewport.new();ticket_view.transparent_bg=true;ticket_view.disable_3d=true;ticket_view.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(ticket_view)
 var note: Control
 if is_instance_valid(ticket_owner) and game.tickets.has(ticket_owner):
  var original=game.tickets[ticket_owner].get_meta("ticket_note")
  note=original.duplicate(0)
  ticket_view.size=Vector2i(original.size)+Vector2i(8,8)
  var screen=original.get_global_rect().get_center()
  ticket_flight_start=game.camera.project_position(screen,1.25)
 else:
  ticket_view.size=Vector2i(260,320)
  note=Label.new();note.text="GRUBBAH\n"+display_number();note.add_theme_font_size_override("font_size",32)
  ticket_flight_start=Vector3(.7,2.0,1.5)
 ticket_view.add_child(note);note.position=Vector2(4,4);note.rotation=0;note.scale=Vector2.ONE;note.modulate=Color.WHITE;note.show()
 flying_ticket.texture=ticket_view.get_texture()
 flying_ticket.pixel_size=.20/float(ticket_view.size.y)
func packing_audio(phase: String) -> void:
 if phase!="wrapping":return
 if is_instance_valid(packing_tween):packing_tween.kill()
 play_wrap_sound()
 packing_tween=create_tween()
 packing_tween.tween_interval(.40)
 packing_tween.tween_callback(play_wrap_sound)
func add_bag_label() -> void:
 var logo=Sprite3D.new();logo.texture=preload("res://assets/ui/burger_pals_letter_mask.png");logo.pixel_size=.00017;logo.material_override=ShaderMaterial.new();logo.material_override.shader=preload("res://shaders/bag_red_logo.gdshader");logo.material_override.set_shader_parameter("mask_tex",logo.texture);logo.position=Vector3(0,.13,-.12);logo.rotation.y=PI;bag.add_child(logo)
 bag_finish=Label3D.new();bag_finish.text="CLICK TO FINISH";bag_finish.font_size=32;bag_finish.pixel_size=.0016;bag_finish.position=Vector3(0,.46,0);bag_finish.billboard=BaseMaterial3D.BILLBOARD_ENABLED;bag_finish.modulate=Color("FFD147");bag.add_child(bag_finish)
 bag_glow=Node3D.new();bag_glow.name="BagSilhouetteOutline";bag.add_child(bag_glow)
 for source in bag.find_children("*","MeshInstance3D",true,false):
  var rim=MeshInstance3D.new();rim.mesh=source.mesh;bag_glow.add_child(rim);rim.global_transform=source.global_transform
  var mat=game._tutorial_outline_material().duplicate() as ShaderMaterial
  mat.set_shader_parameter("outline_width",.0025/maxf(.001,rim.global_basis.get_scale().x));mat.set_shader_parameter("glow_strength",.4)
  rim.material_override=mat;rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 bag_ticket=Sprite3D.new();bag_ticket.name="AttachedMobileTicket";bag_ticket.texture=ticket_view.get_texture() if is_instance_valid(ticket_view) else game._ticket_paper_texture(false);bag_ticket.pixel_size=.20/float(ticket_view.size.y) if is_instance_valid(ticket_view) else .0005;bag_ticket.position=Vector3(.035,.25,-.135);bag_ticket.rotation=Vector3(0,PI,-.08);bag.add_child(bag_ticket);bag_ticket.hide()
func update_visuals(_delta: float) -> void:
 if not is_instance_valid(props):return
 var phase=str(state.get("phase",""));var base=board_pos()
 if not state.is_empty():
  var desired_driver=int(state.get("driver_skin",2))
  if driver_style!=desired_driver:
   driver_style=desired_driver;courier.restyle_kenney_skin(driver_style);courier.play_street_run(1.45)
  var desired_car=clampi(int(state.get("car_style",0)),0,DRIVER_CARS.size()-1)
  if car_style!=desired_car:
   car_style=desired_car
   var old_car=car;car=DRIVER_CARS[car_style].instantiate();props.add_child(car);car.scale=Vector3.ONE*game.STREET_CAR_MODEL_SCALE
   screech.reparent(car,false);car_ground_y=-.06-game._shop_preview_bounds(car).position.y*car.scale.y;old_car.queue_free()
 if phase!=last_phase:
  last_phase=phase
  if phase=="pickup":
   arrival_screeched=false
   courier.remove_meta("slide_sounded")
  courier.set_meta("footstep_sliding",false)
  courier.rotation.z=0.0
  if phase=="wrapping":packing_audio(phase)
  if phase=="sealed" or (phase in ["pickup","collected"] and not is_instance_valid(ticket_view)):prepare_bag_ticket()
  if phase in ["pickup","collected"] and is_instance_valid(ticket_view):bag_ticket.texture=ticket_view.get_texture();bag_ticket.pixel_size=.20/float(ticket_view.size.y)
  if phase=="bagging" or phase=="sealed":
   var old=bag;bag=fitted("SM_FastFoodBagClosed" if phase=="sealed" else "SM_FastFoodBagOpen",.40);props.add_child(bag);add_bag_label();old.queue_free()
 var ui=game.get_node("UI/Root")
 var screen=game._station_stack_screen_center(0) if not game.stations.is_empty() else game.camera.unproject_position(base)
 var center=ui.get_global_transform_with_canvas().affine_inverse()*screen
 paper3d.visible=phase=="paper"
 paper3d.position=napkins.position.lerp(base,clampf(age/.55,0,1)) if phase=="paper" else base
 paper3d.scale=Vector3.ONE*lerpf(.6,1,clampf(age/.55,0,1)) if phase=="paper" else Vector3.ONE*maxf(.1,1-age/1.2)
 paper_outline.visible=phase=="paper" and burger_ready()
 wrap_button.disabled=phase=="paper" and not burger_ready()
 wrap_button.position=center+Vector2(-87,98)
 wrap_button.modulate=Color("FFD06A") if not wrap_button.disabled else Color("B7B0A0")
 var preview=game.stations[0].get("preview")
 if is_instance_valid(preview):preview.modulate.a=0.0 if phase=="wrapping" else 1.0
 bag_finish.visible=phase=="bagging"
 bag_glow.visible=phase=="bagging"
 bag.visible=phase in ["bagging","sealed","pickup","collected"]
 wrapped.visible=phase in ["wrapping","bagging"]
 wrapped.position=base+Vector3(0,.06,0)
 if phase=="bagging":wrapped.position=base.lerp(bag_station_pos()+Vector3(0,.28,0),clampf(age/.6,0,1));wrapped.visible=age<.6
 bag.position=bag_station_pos()
 if phase=="sealed":bag.position=bag.position.lerp(ledge.position+Vector3(0,.05,0),smoothstep(0,1,age/.75))
 elif phase=="pickup":bag.position=ledge.position+Vector3(0,.05,0)
 elif phase=="collected":bag.position=courier.position+Vector3(.2,.7,-.2)
 bag_ticket.visible=phase in ["pickup","collected"] or (phase=="sealed" and age>=.7)
 flying_ticket.visible=phase=="sealed" and age<.7
 if phase=="sealed":
  flying_ticket.position=ticket_flight_start.lerp(bag.position+bag_ticket.position,clampf(age/.7,0,1))
 car.visible=phase in ["pickup","collected"];courier.visible=car.visible
 if phase=="pickup":
  car.position=Vector3(lerpf(-9,10,clampf(age/DRIVER_APPROACH,0,1)),car_ground_y,game.STREET_CAR_Z)
  courier.visible=age>DRIVER_APPROACH
  if age>=DRIVER_APPROACH-.35 and not arrival_screeched:
   arrival_screeched=true;screech.play()
  var run_t=clampf((age-DRIVER_APPROACH)/(DRIVER_WALK-.18),0,1)
  var slide=clampf((run_t-.80)/.20,0,1)
  var travel=run_t if run_t<.80 else .80+.20*(1.0-pow(1.0-slide,2))
  courier.position=Vector3(lerpf(5.5,ledge.position.x,travel),.1,2.8)
  courier.rotation.y=-PI*.5
  courier.rotation.z=sin(slide*PI)*.18
  courier.set_meta("footstep_sliding",run_t>=.80)
  if run_t>=.80 and not courier.has_meta("slide_sounded"):
   courier.set_meta("slide_sounded",true)
   var shoe=courier.get_node_or_null("CharacterFootsteps")
   if shoe!=null:shoe.play_skid()

 elif phase=="collected":
  courier.position=Vector3(lerpf(ledge.position.x,5.5,clampf(age/DRIVER_RETURN,0,1)),.1,2.8);courier.rotation.y=PI*.5
  courier.visible=age<DRIVER_RETURN;bag.visible=age<DRIVER_RETURN
  car.position=Vector3(lerpf(10,24,clampf((age-DRIVER_RETURN)/DRIVER_EXIT,0,1)),car_ground_y,game.STREET_CAR_Z)
 knife.visible=bool(game.owned_machines.get("chef_knife",false))
 knife.scale=Vector3.ONE*(.8 if knife_owner!=0 else 1.0)
 if knife_owner!=0:knife.rotation=Vector3(-.20,PI*.5+.30,0)
 if knife_owner==0:knife.position=knife_home;knife.rotation=knife_home_rotation
 elif knife_owner==(get_node("/root/NetManager").my_id() if online() else 1):
  var mouse=game.get_viewport().get_mouse_position();knife.global_position=game.camera.project_position(mouse,1.1)
  packet_time+=_delta
  if online() and packet_time>.08:
   packet_time=0
   if host():knife_pose_sync.rpc(knife.global_position)
   else:knife_pose.rpc_id(1,knife.global_position)
 else:knife.global_position=remote_knife_pos if remote_knife_pos!=Vector3.ZERO else knife_home+Vector3(0,.25,0)
func _bag_finish_hit(screen_pos: Vector2) -> bool:
 if not is_instance_valid(bag) or not bag.visible or str(state.get("phase",""))!="bagging":return false
 var bounds:=Rect2(game.camera.unproject_position(bag.global_position),Vector2.ZERO)
 for x in [-.15,.15]:
  for y in [0.0,.42]:
   for z in [-.12,.12]:
    bounds=bounds.expand(game.camera.unproject_position(bag.to_global(Vector3(x,y,z))))
 if is_instance_valid(bag_finish):bounds=bounds.expand(game.camera.unproject_position(bag_finish.global_position))
 return bounds.grow(10).has_point(screen_pos)

func handle_input(event: InputEvent) -> bool:
 if not game.playing or not is_instance_valid(props):return false
 if holding_knife() and event is InputEventMouseButton:
  if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:request("knife")
  return true
 if str(state.get("phase",""))=="wrapping" and event is InputEventMouseButton:return true
 if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return false
 var my_id=get_node("/root/NetManager").my_id() if online() else 1
 if knife_owner==my_id:request("knife");return true
 # UI is handled normally; don't steal clicks from the phone or menus.
 if game.get_viewport().gui_get_hovered_control()!=null:
  var hovered=game.get_viewport().gui_get_hovered_control()
  if hovered is BaseButton or (is_instance_valid(game.phone_column) and game.phone_column.is_ancestor_of(hovered)):return false
 # The visible bag wins over build layers and wrap/napkin hit areas.
 if _bag_finish_hit(event.position):
  request("seal");return true
 var layer_hover=game.get_viewport().gui_get_hovered_control()
 if layer_hover!=null and str(layer_hover.get_meta("item_id",""))=="bun_bottom":return false
 if knife.visible and event.position.distance_to(game.camera.unproject_position(knife.global_position+Vector3(0,.13,0)))<55:
  if is_instance_valid(game.spatula_patty) or is_instance_valid(game.dragging_patty):game._flash("Put the burger down first",Color("FFD147"));return true
  request("knife");return true
 if event.position.distance_to(game.camera.unproject_position(napkins.global_position))<35:
  request("paper");return true
 if paper3d.visible and burger_ready() and event.position.distance_to(game.camera.unproject_position(paper3d.global_position))<110:
  if game._try_build_burger_click(event.position):return true
  request("wrap");return true
 return false

@rpc("any_peer","call_remote","unreliable_ordered")
func knife_pose(pos: Vector3) -> void:
 if not host() or multiplayer.get_remote_sender_id()!=knife_owner:return
 if not pos.is_finite() or pos.distance_to(board_pos())>4:return
 remote_knife_pos=pos
 knife_pose_sync.rpc(pos)
@rpc("authority","call_remote","unreliable_ordered")
func knife_pose_sync(pos: Vector3) -> void:remote_knife_pos=pos

func play_wrap_sound() -> void:
 var now=Time.get_ticks_msec()
 if now-last_wrap_sound_ms<350 or not is_instance_valid(wrap_sound):return
 last_wrap_sound_ms=now
 wrap_sound.pitch_scale=randf_range(.95,1.05)
 wrap_sound.play()

func announce_arrival(owner: Node3D) -> void:
 if not is_instance_valid(owner) or not game.tickets.has(owner):return
 if game.game_audio:game.game_audio.play_order_up()
 var phone=game.phone_column
 if is_instance_valid(phone):
  if is_instance_valid(arrival_tween):arrival_tween.kill()
  phone.rotation=0;phone.pivot_offset=Vector2.ZERO;game._layout_phone_ui_overlay()
  var phone_home: Vector2=phone.position
  arrival_tween=create_tween()
  for shift in [-3.0,3.0,-2.0,2.0,-1.0,1.0,0.0]:arrival_tween.tween_property(phone,"position",phone_home+Vector2(shift,0),.065)
  arrival_tween.tween_callback(game._layout_phone_ui_overlay)
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_instance_valid(owner) or not game.tickets.has(owner):return
 var wrap=game.tickets[owner]
 var note=wrap.get_meta("ticket_note")
 var ghost=note.duplicate() as Control
 if ghost==null:return
 var ui=game.get_node("UI/Root");ui.add_child(ghost);ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.z_index=100;ghost.rotation=0;ghost.pivot_offset=Vector2.ZERO
 var inv=ui.get_global_transform_with_canvas().affine_inverse()
 ghost.position=inv*(phone.get_global_rect().get_center() if is_instance_valid(phone) else Vector2(1600,450));ghost.scale=Vector2.ONE*.18
 var target=inv*wrap.get_global_rect().position
 wrap.modulate.a=0
 var flight=create_tween();flight.set_parallel(true);flight.tween_property(ghost,"position",target,.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);flight.tween_property(ghost,"scale",Vector2.ONE*.7,.65)
 var wrap_ref=weakref(wrap)
 flight.chain().tween_callback(func():
  var live_wrap=wrap_ref.get_ref()
  if is_instance_valid(live_wrap):live_wrap.modulate.a=1
  if is_instance_valid(ghost):ghost.queue_free())

func display_number() -> String:
 var code=DATA.order_number_code(state.get("items",[]))
 return "M"+(code if code!="" else str(state.get("number",0)))
