extends Node
var game
var pages := {}
var members := {}
var applying := false
var routing := false
var clock := 0.0
var screen_clock := 0.0
var last_screen: Array=[]
var pending_view: Array=[]
var pending_view_until := 0
const FIELDS := {
 "gnop":["_player_y","_cpu_y","_ball","_vel","_score_p","_score_c","_alive","_started","partner"],
 "snak":["_snake","_snake2","_foods","_dir","_dir2","_alive","_alive2","_started","_score","partner"],
 "smush":["_board","_score","_combo","_busy","_moves","_toast","_toast_t","_drop_offsets","_bottom_roll_offset","_tile_ages","_poofs","_bursts","_expired_columns","_best_chain","_bottom_roll_direction","_swap_cell","_right_press_cell"]}
func setup(g):
 game=g
 pages={"gnop":g.phone_gnop_page,"snak":g.phone_snak_page,"smush":g.phone_smush_page}
 if is_instance_valid(g.phone_muvye_page):g.phone_muvye_page.party=self
 for id in pages:
  pages[id].party=self;pages[id].party_id=id
func online():return game.mp_enabled and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED
func host():return not online() or multiplayer.is_server()
func choose(id: String):
 if applying or not online():return
 if host():request_nav(id)
 else:request_nav.rpc_id(1,id)
@rpc("any_peer","call_remote","reliable")
func request_nav(id: String):
 if not host() or id not in ["home","shop","social","maps","bank","snak","gnop","smush","muvye","grubbah","orders","achievements"]:return
 var peer=multiplayer.get_remote_sender_id()
 if peer==0:peer=multiplayer.get_unique_id()
 if pages.has(id):
  var players: Array=members.get(id,[])
  if peer not in players and players.size()<2:players.append(peer)
  members[id]=players
  if id!="smush":pages[id].partner=players.size()>1
  if id=="snak" and players.size()>1:pages[id].join_second()
 show_nav.rpc(id,members)
 show_nav(id,members)
@rpc("authority","call_remote","reliable")
func show_nav(id: String, roster: Dictionary):
 members=roster
 applying=true;game._set_phone_app(id);applying=false
func input_event(page, event: InputEvent) -> bool:
 if routing or not online():return false
 if event is InputEventMouseMotion:return false
 var data: Dictionary={}
 if event is InputEventKey:
  if event.echo:return true
  data={"key":event.keycode if event.keycode else event.physical_keycode,"pressed":event.pressed}
 elif event is InputEventMouseButton:
  data={"button":event.button_index,"pressed":event.pressed,"pos":event.position/page.size.max(Vector2.ONE)}
 else:return false
 if host():request_input(page.party_id,data)
 else:request_input.rpc_id(1,page.party_id,data)
 return true
@rpc("any_peer","call_remote","reliable")
func request_input(id: String, data: Dictionary):
 if not host() or not pages.has(id):return
 var peer=multiplayer.get_remote_sender_id()
 if peer==0:peer=multiplayer.get_unique_id()
 var players: Array=members.get(id,[])
 if peer not in players:
  if players.size()>=2:return
  players.append(peer);members[id]=players
  if id!="smush":pages[id].partner=players.size()>1
  if id=="snak":pages[id].join_second()
 var page=pages[id]
 var slot=players.find(peer)
 if data.has("key"):
  if int(data.key) not in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_ENTER]:return
  if id=="gnop" and slot==1:
   if data.key==KEY_UP:page.partner_up=bool(data.pressed)
   if data.key==KEY_DOWN:page.partner_down=bool(data.pressed)
   if data.pressed:page._started=true
  elif id=="snak" and slot==1:page.second_key(int(data.key),bool(data.pressed))
  else:
   var event=InputEventKey.new();event.keycode=int(data.key);event.pressed=bool(data.pressed)
   routing=true;page.handle_key(event);routing=false
 elif data.has("button") and data.get("pos") is Vector2:
  var event=InputEventMouseButton.new();event.button_index=int(data.button);event.pressed=bool(data.pressed);event.position=data.pos.clamp(Vector2.ZERO,Vector2.ONE)*page.size
  routing=true;page._on_gui_input(event);routing=false
func _process(delta):
 if not is_instance_valid(game) or not online():return
 if not host():
  screen_clock+=delta
  if screen_clock>=.1:
   screen_clock=0
   var local_view=[game._phone_expanded,game.phone_scroll.scroll_vertical if is_instance_valid(game.phone_scroll) else 0]
   if not applying and local_view!=last_screen:
    last_screen=local_view
    pending_view=local_view.duplicate()
    pending_view_until=Time.get_ticks_msec()+800
    request_view.rpc_id(1,bool(local_view[0]),int(local_view[1]))
  return
 screen_clock+=delta
 if screen_clock>=.2:
  screen_clock=0
  var scroll=game.phone_scroll.scroll_vertical if is_instance_valid(game.phone_scroll) else 0
  screen_state.rpc(game._phone_app_id,scroll,game._phone_expanded)
  var movie=game.phone_muvye_page
  if game._phone_app_id=="muvye" and is_instance_valid(movie) and is_instance_valid(movie._video):
   movie_state.rpc(movie._current_movie,movie._browse_index,movie._video.paused,movie._video.stream_position)
 clock+=delta
 if clock<.067:return
 clock=0
 for id in members:
  var live: Array=[]
  for peer in members[id]:
   if peer==multiplayer.get_unique_id() or peer in multiplayer.get_peers():live.append(peer)
  members[id]=live
  if id!="smush":pages[id].partner=live.size()>1
  if game._phone_app_id!=id:continue
  var state: Dictionary={}
  for key in FIELDS[id]:state[key]=pages[id].get(key)
  snapshot.rpc(id,var_to_bytes({"state":state,"members":members}).compress(FileAccess.COMPRESSION_DEFLATE))
@rpc("authority","call_remote","unreliable_ordered",2)
func snapshot(id: String,payload: PackedByteArray):
 if not pages.has(id) or payload.size()>8192:return
 var decoded=bytes_to_var(payload.decompress_dynamic(65536,FileAccess.COMPRESSION_DEFLATE))
 if not decoded is Dictionary:return
 var state: Dictionary=decoded.get("state",{})
 var roster: Dictionary=decoded.get("members",{})
 members=roster
 if game._phone_app_id!=id:
  applying=true;game._set_phone_app(id);applying=false
 for key in FIELDS[id]:
  if state.has(key):pages[id].set(key,state[key])
 pages[id].queue_redraw()

@rpc("authority","call_remote","unreliable_ordered",2)
func screen_state(id: String,scroll: int,expanded: bool):
 if game._phone_app_id!=id:
  applying=true;game._set_phone_app(id);applying=false
 var local_view=[game._phone_expanded,game.phone_scroll.scroll_vertical if is_instance_valid(game.phone_scroll) else 0]
 var incoming=[expanded,scroll]
 if incoming==pending_view:pending_view.clear()
 # Keep a guest's new scroll position while an older host echo is in flight.
 if local_view!=last_screen or (not pending_view.is_empty() and Time.get_ticks_msec()<pending_view_until):return
 applying=true
 if game._phone_expanded!=expanded:game._set_phone_expanded(expanded)
 if is_instance_valid(game.phone_scroll):game.phone_scroll.scroll_vertical=scroll
 last_screen=[expanded,scroll];applying=false

@rpc("any_peer","call_remote","reliable")
func request_view(expanded: bool,scroll: int):
 if not host():return
 if game._phone_expanded!=expanded:game._set_phone_expanded(expanded)
 if is_instance_valid(game.phone_scroll):game.phone_scroll.scroll_vertical=clampi(scroll,0,100000)

func media_action(method: String,args: Array) -> bool:
 if routing or applying or not online():return false
 if host():request_media(method,args)
 else:request_media.rpc_id(1,method,args)
 return true
@rpc("any_peer","call_remote","reliable")
func request_media(method: String,args: Array):
 if not host() or not is_instance_valid(game.phone_muvye_page):return
 if method not in ["_play_movie","_browse","_show_library","_toggle_play_pause","_seek_relative","_party_seek"]:return
 var count=0 if method in ["_show_library","_toggle_play_pause"] else 1
 if args.size()!=count:return
 if count and (not (args[0] is int or args[0] is float) or not is_finite(float(args[0]))):return
 routing=true;game.phone_muvye_page.callv(method,args);routing=false
@rpc("authority","call_remote","unreliable_ordered",2)
func movie_state(index: int,browse: int,paused: bool,seconds: float):
 var movie=game.phone_muvye_page
 if not is_instance_valid(movie):return
 applying=true
 if movie._current_movie!=index:
  if index<0:movie._show_library()
  else:movie._play_movie(index)
 if movie._browse_index!=browse:movie._browse_index=browse;movie._refresh_library()
 if is_instance_valid(movie._video) and index>=0:
  movie._video.paused=paused
  if absf(movie._video.stream_position-seconds)>1.5:movie._party_seek(seconds)
 applying=false

func status(id: String) -> String:
 var slot: int=members.get(id,[]).find(multiplayer.get_unique_id())
 if slot<0:return "WATCHING - CLICK TO JOIN"
 if id=="gnop":return "YOU: LEFT - UP/DOWN" if slot==0 else "YOU: RIGHT - UP/DOWN"
 if id=="snak":return "YOU: GREEN - ARROWS" if slot==0 else "YOU: BLUE - ARROWS"
 return "SMUSH TOGETHER"
