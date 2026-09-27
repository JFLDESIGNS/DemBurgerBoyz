extends Node
const Card=preload("res://scripts/playing_card.gd")
var game
var prop: Node3D
var box_parts: Array=[]
var spade: Label3D
var packed_away := false
var round_id := 0
var received_round := -1
var ui: PanelContainer
var row: HBoxContainer
var info: Label
var controls: HBoxContainer
var opened := false
var players: Array=[]
var hands: Dictionary={}
var deck: Array=[]
var dealer: Array=[]
var bot_hand: Array=[]
var done: Array=[]
var mode := ""
var phase := "choose"
var message := "Choose a game. Cards are private."
var selected: Array=[]
var shown: Dictionary={}
func online():return game.mp_enabled and multiplayer.has_multiplayer_peer()
func host():return not online() or multiplayer.is_server()
func local_id():return multiplayer.get_unique_id() if online() else 1
func setup(g):
 game=g
 ui=PanelContainer.new();ui.name="CardTable";ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 ui.position=Vector2(-350,-260);ui.size=Vector2(700,170);ui.z_index=110
 ui.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 game.get_node("UI/Root").add_child(ui);ui.hide()
 var box=VBoxContainer.new();box.add_theme_constant_override("separation",10);ui.add_child(box)
 info=Label.new();info.add_theme_font_size_override("font_size",14);info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;style_label(info);box.add_child(info)
 row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",48);box.add_child(row)
 controls=HBoxContainer.new();controls.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_child(controls)
func _process(_delta):
 if not is_instance_valid(game):return
 var owned=bool(game.owned_machines.get("card_deck",false))
 if owned and not is_instance_valid(prop) and is_instance_valid(game.world):build_prop()
 if is_instance_valid(prop):prop.visible=owned and game.playing
 if not game.playing:
  if opened:opened=false;ui.hide()
  if host() and not players.is_empty():players.clear();hands.clear();deck.clear();done.clear();phase="choose"
 if host() and online():
  for peer in players.duplicate():
   if peer!=local_id() and peer not in multiplayer.get_peers():
    players.erase(peer);hands.erase(peer);done.erase(peer);phase="choose";message="Partner left. Choose a game.";publish()
func build_prop():
 prop=Node3D.new();prop.name="BurgerPalsCards";game.world.add_child(prop)
 prop.global_position=game._cutting_board_world_center()+Vector3(-.28,.035,-.30)
 var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.12,.035,.18);mesh.mesh=box;prop.add_child(mesh)
 var mat=StandardMaterial3D.new();mat.albedo_color=Color("EFDDB8");mesh.material_override=mat
 var cover=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(.118,.178);cover.mesh=plane;cover.position.y=.019;prop.add_child(cover)
 var ink=StandardMaterial3D.new();Card.art(0);ink.albedo_texture=Card.atlas;ink.uv1_scale=Vector3(1.0/3.0,.5,1);ink.roughness=.8;cover.material_override=ink;cover.rotation.y=PI
 box_parts=[mesh,cover]
 spade=Label3D.new();spade.text="♠";spade.font_size=64;spade.pixel_size=.002;spade.position.y=.05;spade.billboard=BaseMaterial3D.BILLBOARD_ENABLED;spade.modulate=Color("FFF3D7");spade.outline_modulate=Color("173E47");spade.outline_size=10;prop.add_child(spade)
 update_box_visual()
 var area=Area3D.new();prop.add_child(area);area.collision_layer=1;area.collision_mask=0
 var shape=CollisionShape3D.new();var target=BoxShape3D.new();target.size=Vector3(.20,.1,.24);shape.shape=target;area.add_child(shape)
 area.input_event.connect(func(_camera,event,_position,_normal,_index):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not game._morning_boss_blocks_controls():toggle();game.get_viewport().set_input_as_handled()
 )
func toggle():
 opened=not opened;ui.visible=opened
 if opened:
  packed_away=false;update_box_visual();send("join")
 else:send("leave")
func update_box_visual():
 for part in box_parts:
  if is_instance_valid(part):part.visible=not packed_away
 if is_instance_valid(spade):spade.visible=packed_away
@rpc("authority","call_local","reliable")
func put_away():
 opened=false;ui.hide();packed_away=true;shown.clear();selected.clear();update_box_visual()

func send(action: String,value: Variant=null):
 if host():request(action,value)
 else:request.rpc_id(1,action,value)
@rpc("any_peer","call_remote","reliable")
func request(action: String,value: Variant=null):
 if not host() or not bool(game.owned_machines.get("card_deck",false)):return
 var peer=multiplayer.get_remote_sender_id()
 if peer==0:peer=local_id()
 if action=="join":
  if peer not in players and players.size()<2:
   players.append(peer)
   if phase=="playing":phase="ready";hands.clear();done.clear();bot_hand.clear();dealer.clear();message="Partner joined. Deal a new hand."
 elif action=="leave":
  players.clear();hands.clear();deck.clear();dealer.clear();bot_hand.clear();done.clear();phase="choose";message="Cards put away. Choose a game."
  if online():put_away.rpc()
  else:put_away()
  return
 elif peer not in players:return
 elif action=="choose" and str(value) in ["draw","blackjack"] and phase in ["choose","ready","finished"]:
  mode=str(value);phase="ready";message="Deal to play the chef, or invite your partner." if mode=="draw" else "Blackjack: hit or stand. Dealer stands on 17."
 elif action=="deal" and phase in ["ready","finished"]:
  if mode in ["draw","blackjack"]:
   # Dealing invites the other cook even if they never clicked the physical box.
   if online():
    for cook in [local_id()] + Array(multiplayer.get_peers()):
     if cook not in players and players.size()<2:players.append(cook)
   deal()
 elif phase=="playing" and peer not in done:
  if mode=="draw" and action=="draw" and value is Array and value.size()<=5:
   var unique: Array=[]
   for index in value:
    if not index is int or index<0 or index>4 or index in unique:return
    unique.append(index)
   for index in unique:hands[peer][index]=deck.pop_back()
   done.append(peer)
  elif mode=="blackjack" and action=="hit":
   hands[peer].append(deck.pop_back())
   if total(hands[peer])>=21:done.append(peer)
  elif mode=="blackjack" and action=="stand":done.append(peer)
  if done.size()==players.size():finish_round()
 publish()
func deal():
 round_id+=1
 deck=range(52);deck.shuffle();hands.clear();done.clear();dealer.clear();bot_hand.clear()
 for peer in players:hands[peer]=[]
 for i in (5 if mode=="draw" else 2):
  for peer in players:hands[peer].append(deck.pop_back())
 if mode=="blackjack":dealer=[deck.pop_back(),deck.pop_back()]
 elif players.size()==1:
  for i in 5:bot_hand.append(deck.pop_back())
 phase="playing";message="Select cards to replace, then Draw (none = keep all)." if mode=="draw" else "Hit or stand. No money is wagered."
func finish_round():
 phase="finished"
 if mode=="blackjack":
  while total(dealer)<17:dealer.append(deck.pop_back())
  message="Dealer: %d." % total(dealer)
 else:
  if players.size()==1:
   # Keep made hands and pairs; otherwise keep the highest card and draw four.
   var counts: Dictionary={}
   for card in bot_hand:counts[int(card)%13]=int(counts.get(int(card)%13,0))+1
   var keep: Array=[]
   if rank_hand(bot_hand)>=4*759375:keep=range(5)
   else:
    for i in 5:
     if int(counts[int(bot_hand[i])%13])>=2:keep.append(i)
    if keep.is_empty():
     var best=0
     for i in 5:
      if int(bot_hand[i])%13>int(bot_hand[best])%13:best=i
     keep.append(best)
   for i in 5:
    if i not in keep:bot_hand[i]=deck.pop_back()
  var a=rank_hand(hands[players[0]]);var b=rank_hand(bot_hand if players.size()==1 else hands[players[1]])
  message=("Draw!" if a==b else ("You win!" if a>b else "Chef wins!")) if players.size()==1 else ("Draw!" if a==b else "Player %d wins!" % (1 if a>b else 2))
func view_for(peer: int) -> Dictionary:
 var own: Array=hands.get(peer,[])
 var dealer_view=dealer.duplicate() if phase=="finished" else ([dealer[0],-1] if dealer.size()>0 else [])
 var text=message
 if phase=="finished" and mode=="blackjack" and not own.is_empty():
  var value=total(own);var house=total(dealer)
  text+=" You: %d — %s" % [value,"Bust" if value>21 else ("Win" if house>21 or value>house else ("Push" if value==house else "Dealer wins"))]
 return {"round":round_id,"hand":own,"dealer":dealer_view,"opponent":(bot_hand.duplicate() if phase=="finished" else [-1,-1,-1,-1,-1]) if mode=="draw" and not bot_hand.is_empty() else [],"ai":players.size()==1,"message":text,"mode":mode,"phase":phase,"count":players.size(),"waiting":peer in done,"joined":peer in players}
func publish():
 for peer in players:
  var state=view_for(peer)
  if peer==local_id():receive(state)
  elif online():receive.rpc_id(peer,state)
@rpc("authority","call_remote","reliable")
func receive(state: Dictionary):
 shown=state
 if str(state.get("phase",""))=="playing" and int(state.get("round",0))!=received_round:
  received_round=int(state.get("round",0));opened=true;ui.show();packed_away=false;update_box_visual()
 selected.clear();render()
func render():
 for child in row.get_children():child.queue_free()
 for child in controls.get_children():child.queue_free()
 info.text="BURGER PALS CARDS · %d/2 players
%s" % [shown.get("count",0),shown.get("message","")]
 var cards: Array=shown.get("hand",[])
 var own_row=hand_group("YOUR HAND",false) if not cards.is_empty() else row
 for i in cards.size():
  var button=Card.new();button.card=cards[i];button.flat=true;own_row.add_child(button)
  button.modulate.a=0;button.scale=Vector2(.7,.7)
  var deal_fx=button.create_tween();deal_fx.tween_interval(float(i)*.04)
  deal_fx.tween_property(button,"modulate:a",1.0,.15)
  deal_fx.parallel().tween_property(button,"scale",Vector2.ONE,.15)
  button.pressed.connect(func():
   if shown.phase!="playing" or shown.mode!="draw" or shown.waiting:return
   if i in selected:selected.erase(i)
   else:selected.append(i)
   button.selected=i in selected;button.queue_redraw()
  )
 var opponent: Array=shown.get("dealer",[]) if shown.get("mode","")=="blackjack" else shown.get("opponent",[])
 if not opponent.is_empty():
  var other_row=hand_group("DEALER" if shown.get("mode","")=="blackjack" else "CHEF",true)
  for value in opponent:
   var button=Card.new();button.card=value;button.disabled=true;other_row.add_child(button)
 if shown.get("phase","") in ["choose","ready","finished"]:
  add_button("Five-card draw",func():send("choose","draw"))
  add_button("Blackjack",func():send("choose","blackjack"))
  if shown.get("mode","")!="":add_button("Deal",func():send("deal"))
 elif not shown.get("waiting",false):
  if shown.mode=="draw":add_button("Draw / Keep",func():send("draw",selected))
  else:
   add_button("Hit",func():send("hit"));add_button("Stand",func():send("stand"))
 add_button("Put away",toggle)
func style_label(label: Label):
 label.add_theme_color_override("font_color",Color("FFF3D7"))
 label.add_theme_color_override("font_outline_color",Color("23333D"))
 label.add_theme_constant_override("outline_size",5)
func hand_group(title: String, opponent: bool) -> HBoxContainer:
 var group=VBoxContainer.new();group.add_theme_constant_override("separation",8);row.add_child(group)
 var label=Label.new();label.text=title;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",13);style_label(label);group.add_child(label)
 if opponent:label.add_theme_color_override("font_color",Color("A9E0DE"))
 var hand=HBoxContainer.new();hand.alignment=BoxContainer.ALIGNMENT_CENTER;hand.add_theme_constant_override("separation",5);group.add_child(hand)
 return hand
func add_button(text: String, action: Callable):
 var button=Button.new();button.text=text;controls.add_child(button);button.pressed.connect(action)
static func total(cards: Array) -> int:
 var value=0;var aces=0
 for card in cards:
  var rank=int(card)%13+2
  if rank==14:value+=11;aces+=1
  else:value+=mini(rank,10)
 while value>21 and aces>0:value-=10;aces-=1
 return value
static func rank_hand(cards: Array) -> int:
 var counts: Dictionary={};var suits: Array=[];var ranks: Array=[]
 for card in cards:
  var rank=int(card)%13+2;counts[rank]=int(counts.get(rank,0))+1;ranks.append(rank);suits.append(int(int(card)/13))
 ranks.sort();ranks.reverse()
 var flush=true
 for suit in suits:
  if suit!=suits[0]:flush=false
 var straight=0
 if counts.size()==5:
  if ranks[0]-ranks[4]==4:straight=ranks[0]
  elif ranks==[14,5,4,3,2]:straight=5
 var groups: Array=[]
 for rank in counts:groups.append([counts[rank],rank])
 groups.sort_custom(func(a,b):return a[0]>b[0] or (a[0]==b[0] and a[1]>b[1]))
 var category=0
 if straight and flush:category=8
 elif groups[0][0]==4:category=7
 elif groups[0][0]==3 and groups[1][0]==2:category=6
 elif flush:category=5
 elif straight:category=4
 elif groups[0][0]==3:category=3
 elif groups[0][0]==2 and groups[1][0]==2:category=2
 elif groups[0][0]==2:category=1
 var ordered: Array=[]
 if straight:ordered=[straight]
 else:
  for group in groups:
   for i in group[0]:ordered.append(group[1])
 var value=category
 for i in 5:value=value*15+(int(ordered[i]) if i<ordered.size() else 0)
 return value

func handle_input(event: InputEvent) -> bool:
 if not is_instance_valid(prop) or not prop.visible or not game.playing or game._morning_boss_blocks_controls():return false
 if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return false
 if opened and ui.get_global_rect().has_point(event.position):return false
 if not is_instance_valid(game.camera) or game.camera.is_position_behind(prop.global_position):return false
 var point=game.camera.unproject_position(prop.global_position)
 if point.distance_to(event.position)>24:return false
 toggle();return true
