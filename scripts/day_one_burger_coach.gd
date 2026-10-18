extends CanvasLayer
# A local, non-blocking first-day helper, including for multiplayer guests.
const TIPS := [
 "Welcome, chef! Read the ticket, then drag a patty onto the grill.",
 "Watch the patty as it cooks. Flip it with the spatula so both sides cook!",
 "Start with a bottom bun. Add the cooked patty and ticket toppings, then a top bun.",
 "Drag the finished burger to your customer to serve it. Check their ticket first!",
 "Scrape leftover bits off the grill with your spatula to keep it clean."
]
var game: Node
var panel: Control
var caption: Label
var view: SubViewport
var actor: Node3D
var player: AnimationPlayer
var elapsed := 0.0
var tip_index := -1
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
  player=players[0];player.play("MarchLoop");player.pause();player.seek(.2,true)
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
 var index := int((elapsed-8.0)/28.0) if elapsed>=8.0 else -1
 var active := index>=0 and index<TIPS.size() and fmod(elapsed-8.0,28.0)<9.0
 if not built and not active:return
 if not built:_build()
 if active and index!=tip_index:
  tip_index=index;caption.text=TIPS[index]
 shown=move_toward(shown,1.0 if active else 0.0,delta*2.5)
 panel.visible=shown>0.0
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if panel.visible else SubViewport.UPDATE_DISABLED
 var screen := get_viewport().get_visible_rect().size
 var ui_scale := minf(1.0,screen.x/1000.0)
 panel.scale=Vector2.ONE*ui_scale
 panel.position=Vector2(20,screen.y-200*ui_scale+(1.0-ease(shown,.45))*230*ui_scale)
 clock+=delta
 actor.rotation.z=sin(clock*2.5)*.035
 actor.position.y=sin(clock*3.0)*.025
