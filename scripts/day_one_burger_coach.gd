extends CanvasLayer
# A local, non-blocking first-day helper, including for multiplayer guests.
var game: Node
var panel: Control
var caption: Label
var view: SubViewport
var actor: Node3D
var player: AnimationPlayer
var elapsed := 0.0
var current_tip := ""
var tip_left := 0.0
var cooldown := 0.0
var seen: Dictionary = {}
var shown := 0.0
var clock := 0.0
var built := false

func _ready() -> void:
 game = get_parent()
 layer = 12

func _build() -> void:
 built = true
 panel = Control.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
 var portrait=TextureRect.new();portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
 portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 portrait.size=Vector2(180,200);panel.add_child(portrait)
 view=SubViewport.new();view.size=Vector2i(540,600);view.msaa_3d=Viewport.MSAA_4X;view.transparent_bg=true;view.own_world_3d=true
 panel.add_child(view);portrait.texture=view.get_texture()
 var world=Node3D.new();view.add_child(world)
 actor=preload("res://assets/lobby_pals/burger.glb").instantiate();world.add_child(actor)
 var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.15,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.65
 camera.look_at(Vector3(0,1.15,0));camera.current=true
 var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=1.3
 var environment=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new()
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color(1,.88,.72);environment.environment.ambient_light_energy=.7
 var players=actor.find_children("*","AnimationPlayer",true,false)
 if not players.is_empty():
  player=players[0]
  player.get_animation("MarchLoop").loop_mode=Animation.LOOP_LINEAR
  player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  player.play("MarchLoop")
 actor.rotation.y=deg_to_rad(30.0)
 var bubble=PanelContainer.new();bubble.position=Vector2(160,48);bubble.size=Vector2(350,110);bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(bubble)
 var style=StyleBoxFlat.new();style.bg_color=Color("fff0c9");style.set_corner_radius_all(18);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14
 bubble.add_theme_stylebox_override("panel",style)
 caption=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size=Vector2(310,75)
 caption.add_theme_color_override("font_color",Color("472416"));caption.add_theme_font_size_override("font_size",20);bubble.add_child(caption)

func _process(delta: float) -> void:
 var allowed: bool = game.get("playing")==true and game.get("day")==1 and game.get("_kitchen_ready")==true and game.get("tutorial_mode")!=true
 allowed = allowed and game.get("shift_paused")!=true and game.get("options_menu_open")!=true and game.get("_boss_intro_running")!=true and game.get("_bts_day_intro_active")!=true
 if not allowed:
  if built:panel.hide();view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  return
 elapsed += delta
 cooldown=maxf(0.0,cooldown-delta)
 tip_left=maxf(0.0,tip_left-delta)
 var suggestion := choose_tip()
 var key: String = suggestion.get("id", "")
 # Drop advice as soon as its condition is resolved; urgent cooking cues interrupt.
 if key!=current_tip:tip_left=0.0
 var urgent: bool = key in ["fire","flip","scoop","burnt"]
 if not key.is_empty() and key!=current_tip and (cooldown<=0.0 or urgent) and elapsed>=3.0:
  if elapsed-float(seen.get(key,-1000.0))> (35.0 if urgent else 90.0):
   if not built:_build()
   current_tip=key;caption.text=suggestion.text;tip_left=8.0;cooldown=12.0;seen[key]=elapsed
 var active := tip_left>0.0
 if not built:return
 if not active and shown<=0.0:current_tip=""
 shown=move_toward(shown,1.0 if active else 0.0,delta*2.5)
 panel.visible=shown>0.0
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if panel.visible else SubViewport.UPDATE_DISABLED
 var screen := get_viewport().get_visible_rect().size
 var ui_scale := minf(1.0,screen.x/1000.0)
 panel.scale=Vector2.ONE*ui_scale
 panel.position=Vector2(20,screen.y-200*ui_scale+(1.0-ease(shown,.45))*230*ui_scale)
 clock+=delta
 if is_instance_valid(player) and panel.visible:player.advance(delta*.65)
 actor.rotation.y=deg_to_rad(30.0)+sin(clock*1.7)*.06
 actor.rotation.z=sin(clock*2.5)*.025
 actor.position.y=sin(clock*3.0)*.025

func tip(id: String, text: String) -> Dictionary:
 return {"id":id,"text":text}

func choose_tip() -> Dictionary:
 if game.grill_on_fire:
  return tip("fire","Fire! Hold the red extinguisher and sweep it across the flames until they go out.")
 var patties: Array=[]
 for patty in game.grill:
  if is_instance_valid(patty) and patty.has_method("can_scoop"):patties.append(patty)
 for patty in patties:
  if patty.is_held:continue
  if patty.is_burnt():return tip("burnt","That patty is burnt. Drag it to the garbage and cook a fresh one for this order.")
  if patty.can_scoop():return tip("scoop","SCOOP! Left-click the cooked patty, then click the Build board on the left to place it.")
  if patty.can_flip():return tip("flip","FLIP! Quickly left-click that patty now to cook the other side.")
 if is_instance_valid(game.spatula_patty):
  return tip("carry","You've got the patty! Click the Build board on the left to start your burger.")
 var customer: Node = null
 for person in game.customers:
  if is_instance_valid(person) and person.is_waiting and not person.is_leaving:
   customer=person;break
 if is_instance_valid(game.selected_customer):customer=game.selected_customer
 if customer==null:return {}
 if not game.grill_on and patties.is_empty():
  return tip("heat","Your grill is off. Click its power knob, or press G, before cooking the customer's order.")
 for patty in patties:
  if patty.place_ball_waiting:return tip("smash","Right-click that beef ball again to smash it flat with the spatula.")
 var items: Array=[]
 if not game.stations.is_empty():items=game.stations[0].get("items",[])
 if items.has("patty"):
  var missing: Array=customer.order.duplicate()
  var extra: Array=items.duplicate()
  for ordered in customer.order:extra.erase(ordered)
  for item in items:missing.erase(item)
  missing.erase("bun_bottom")
  for side in ["fries","soda","icecream","toasted_bun"]:missing.erase(side)
  if items.has("bun_top"):
   if not extra.is_empty():return tip("extra","This burger has extra " + str(extra[0]).replace("_"," ") + ". Check the selected ticket before serving.")
   if missing.is_empty():return tip("serve","Your burger matches this ticket! Press Enter to serve it while it's fresh.")
   return tip("check","Check the ticket before serving: this burger still needs " + str(missing[0]).replace("_"," ") + ".")
  for ingredient in missing:
   if ingredient!="bun_top":return tip("add_"+str(ingredient),"The ticket needs " + str(ingredient).replace("_"," ") + ". Add it to the burger before the top bun.")
  return tip("bun","The ticket toppings are on! Click the top-bun pile to finish this burger.")
 for patty in patties:
  if not patty.is_held and patty.seasoning<.1:
   return tip("season","While that patty cooks, hold the hanging seasoning shaker over it until pepper specks appear.")
 if game.debris_piles.size()>=3:
  return tip("clean","The grill is getting messy. Left-click and drag the spatula across the debris to scrape it away.")
 if patties.is_empty() and items.is_empty():
  return tip("place","A customer is waiting! Right-click an empty spot on the hot grill to place a frozen beef ball.")
 return {}
