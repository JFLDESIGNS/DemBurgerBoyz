extends SceneTree
var folder: String
func mark(key: String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(75).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/party_fixture.gd"));root.add_child(g)
 for id in ["gnop","snak","smush"]:
  var page=load("res://scripts/phone_"+id+".gd").new();page.name=id;page.size=Vector2(200,284);g.get_node("UI/Root").add_child(page);g.set("phone_"+id+"_page",page)
 var party=load("res://scripts/phone_party.gd").new();party.name="PhoneParty";g.add_child(party);g._phone_party=party;party.setup(g)
 var cards=load("res://scripts/card_table.gd").new();cards.name="Cards";g.add_child(cards);cards.setup(g);cards.set_process(false);g.owned_machines.card_deck=true
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Party test")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  party.choose("snak");await wait_mark("one_snake")
  while party.members.snak.size()<2:await process_frame
  assert(g.phone_snak_page._snake2.size()==3);mark("two_snakes")
  while g.phone_snak_page._pending2!=Vector2i.DOWN:await process_frame
  party.choose("gnop");await wait_mark("gnop_joined")
  while not g.phone_gnop_page.partner_up:await process_frame
  mark("paddle_control")
  party.choose("smush");await wait_mark("smush_seen")
  g.phone_smush_page._board_rect=Rect2(0,0,200,280)
  for y in 7:
   for x in 5:g.phone_smush_page._board[y][x]="patty"
  mark("smush_ready")
  while g.phone_smush_page._score<=0:await process_frame
  mark("smush_clear")
  cards.send("join")
  cards.send("choose","draw");cards.send("deal")
  await wait_mark("private_hand")
  cards.send("draw",[])
  while cards.phase!="finished":await process_frame
  mark("draw_finished")
  cards.put_away()
  mark("host_closed")
  await wait_mark("blackjack_hand")
  assert(cards.opened and cards.ui.visible)
  cards.send("stand")
  while cards.phase!="finished":await process_frame
  mark("blackjack_finished")
  await wait_mark("guest_done");assert(not cards.opened and cards.packed_away)
 else:
  while g._phone_app_id!="snak":await process_frame
  assert(not g.phone_snak_page.partner);mark("one_snake");party.choose("snak")
  await wait_mark("two_snakes");g.phone_snak_page.handle_key(key(KEY_DOWN))
  while g._phone_app_id!="gnop":await process_frame
  party.choose("gnop");mark("gnop_joined");g.phone_gnop_page.handle_key(key(KEY_UP))
  await wait_mark("paddle_control")
  while g._phone_app_id!="smush":await process_frame
  party.choose("smush");mark("smush_seen");await wait_mark("smush_ready")
  var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=g.phone_smush_page._cell_rect(Vector2i(0,0)).get_center();g.phone_smush_page._on_gui_input(click)
  await wait_mark("smush_clear")
  assert(not cards.opened)
  while cards.shown.get("hand",[]).size()!=5:await process_frame
  assert(cards.opened and cards.ui.visible)
  assert(cards.hands.is_empty() and cards.deck.is_empty());assert(not cards.shown.has("hands"))
  mark("private_hand");cards.send("draw",[]);await wait_mark("draw_finished")
  await wait_mark("host_closed")
  cards.send("choose","blackjack");cards.send("deal")
  while cards.shown.get("mode","")!="blackjack" or cards.shown.get("hand",[]).size()!=2:await process_frame
  assert(cards.shown.dealer[1]==-1);mark("blackjack_hand");cards.send("stand")
  await wait_mark("blackjack_finished")
  while cards.shown.phase!="finished":await process_frame
  assert(-1 not in cards.shown.dealer);cards.send("leave");await create_timer(.2).timeout;assert(not cards.opened and cards.packed_away);mark("guest_done")
 print("PARTY_NETWORK_OK")
 g.mp_enabled=false;net.leave(false);quit()
func key(code):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;return event
