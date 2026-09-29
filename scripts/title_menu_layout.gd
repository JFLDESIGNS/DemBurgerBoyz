extends Control
var stage: Control
var entries: Array[Control] = []
func setup(game: Node) -> void:
 name = "TitleMenuLayout"
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 stage = Control.new()
 stage.name = "MenuStage"
 stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(stage)
 var old = game.get_node("UI/Root/StartOverlay/StartCenter")
 var creator: Button = old.get_node("StartMenuCard/StartMenuCol/CharacterCreatorButton")
 var logo := TextureRect.new()
 logo.name = "TitleLogo"
 logo.texture = load(game.PHONE_LOGO_TEX_PATH)
 logo.material = ShaderMaterial.new()
 logo.material.shader = preload("res://shaders/title_logo_mask.gdshader")
 logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
 logo.position = Vector2(190,10)
 logo.size = Vector2(420,210)
 stage.add_child(logo)
 _button(game.start_btn,Vector2(70,246),Vector2(660,82),Color("D84C3E"),Color("FFF5DA"),32,0)
 _button(game.multiplayer_btn,Vector2(70,350),Vector2(660,82),Color("147E83"),Color("FFF5DA"),32,1)
 var truck: Control = game.start_logo_wrap
 truck.reparent(stage)
 truck.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 truck.custom_minimum_size = Vector2.ZERO
 truck.position = Vector2(0,448)
 truck.size = Vector2(800,330)
 truck.z_index = 0
 game.tutorial_btn.text = "CAT TUTORIAL"
 _button(game.tutorial_btn,Vector2(142,810),Vector2(244,44),Color("E5BA65"),Color("4C382B"),17,2)
 _button(creator,Vector2(410,810),Vector2(244,44),Color("B5D6CB"),Color("25595B"),17,3)
 game._setup_player_settings()
 var settings := Button.new()
 settings.name = "SettingsButton"
 settings.text = "SETTINGS"
 settings.add_theme_font_override("font",game.start_btn.get_theme_font("font"))
 stage.add_child(settings)
 settings.pressed.connect(game._open_player_settings)
 _button(settings,Vector2(278,872),Vector2(244,44),Color("147E83"),Color("FFF5DA"),17,4)
 var quit_button := Button.new()
 quit_button.name = "QuitGameButton"
 quit_button.text = "QUIT GAME"
 preload("res://scripts/player_settings.gd").style_button(quit_button)
 add_child(quit_button)
 quit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 quit_button.offset_left = -194
 quit_button.offset_right = -24
 quit_button.offset_top = -112
 quit_button.offset_bottom = -64
 quit_button.pressed.connect(game._options_exit_game)
 old.hide()
 resized.connect(_layout)
 _layout()
 visibility_changed.connect(func():
  if is_visible_in_tree(): _entrance())
 call_deferred("_entrance")
func _layout() -> void:
 if not is_instance_valid(stage): return
 var fit := minf(size.x/900.0,(size.y-108.0)/900.0)
 fit = maxf(.1,fit)
 stage.size = Vector2(800,900)
 stage.scale = Vector2.ONE*fit
 stage.position = Vector2((size.x-800*fit)*.5,(size.y-64-900*fit)*.5)
func _button(button: Button, at: Vector2, dimensions: Vector2, color: Color, ink: Color, font_size: int, order: int) -> void:
 var holder := Control.new()
 holder.name = button.name + "Motion"
 holder.position = at
 holder.size = dimensions
 holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
 holder.set_meta("home",at)
 holder.set_meta("order",order)
 stage.add_child(holder)
 button.reparent(holder)
 button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 button.position = Vector2.ZERO
 button.custom_minimum_size = dimensions
 button.size = dimensions
 button.add_theme_font_size_override("font_size",font_size)
 for state in ["normal","hover","pressed","focus"]:
  var style := StyleBoxFlat.new()
  style.bg_color = color.lightened(.05) if state=="hover" else color
  style.border_color = color.darkened(.32)
  style.border_width_bottom = 4 if state=="pressed" else 9 if font_size>20 else 5
  style.set_corner_radius_all(12 if font_size>20 else 8)
  style.content_margin_left=18;style.content_margin_right=18
  style.content_margin_top=8;style.content_margin_bottom=14
  button.add_theme_stylebox_override(state,style)
 for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_outline_color"]: button.add_theme_color_override(key,Color.TRANSPARENT)
 var caption := Label.new()
 caption.name = "MenuCaption"
 caption.text = button.text
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 caption.offset_top = -3
 caption.offset_bottom = -3
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.add_theme_font_override("font",button.get_theme_font("font"))
 caption.add_theme_font_size_override("font_size",font_size)
 caption.add_theme_color_override("font_color",Color.WHITE)
 caption.add_theme_color_override("font_shadow_color",Color(0.05,.12,.14,.35))
 caption.add_theme_constant_override("shadow_offset_x",1)
 caption.add_theme_constant_override("shadow_offset_y",2)
 button.add_child(caption)
 button.mouse_entered.connect(func(): _hover(button,true))
 button.mouse_exited.connect(func(): _hover(button,false))
 button.button_down.connect(func(): _move_button(button,3,.07))
 button.button_up.connect(func(): _hover(button,button.is_hovered()))
 entries.append(holder)
func _move_button(button: Button, y: float, duration: float) -> Tween:
 var previous = button.get_meta("menu_motion") if button.has_meta("menu_motion") else null
 if is_instance_valid(previous): previous.kill()
 var tween := create_tween()
 button.set_meta("menu_motion",tween)
 tween.tween_property(button,"position:y",y,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 return tween
func _hover(button: Button, hover: bool) -> void:
 var tween := _move_button(button,-8 if hover else 0,.14)
 if hover: tween.tween_property(button,"position:y",-4,.18).set_trans(Tween.TRANS_SINE)
func _entrance() -> void:
 if not is_visible_in_tree(): return
 for holder in entries:
  var previous = holder.get_meta("entrance") if holder.has_meta("entrance") else null
  if is_instance_valid(previous): previous.kill()
  var home: Vector2 = holder.get_meta("home")
  holder.position = home-Vector2(0,55)
  holder.modulate.a=0
  var tween := create_tween()
  holder.set_meta("entrance",tween)
  tween.tween_interval(.12+float(holder.get_meta("order"))*.11)
  tween.set_parallel(true)
  tween.tween_property(holder,"position",home,.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tween.tween_property(holder,"modulate:a",1.0,.3)

func _process(_delta: float) -> void:
 for holder in entries:
  var button := holder.get_child(0) as Button
  var caption := button.get_node("MenuCaption") as Label
  caption.text = button.text
