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
 logo.texture = preload("res://assets/ui/title_poster_logo.png")
 logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
 logo.position = Vector2(35,5)
 logo.size = Vector2(810,445)
 stage.add_child(logo)
 _button(game.start_btn,Vector2(80,448),Vector2(625,140),Color("E64D32"),Color("FFF2CF"),48,0)
 _button(game.multiplayer_btn,Vector2(82,596),Vector2(601,104),Color("14777C"),Color("FFF2CF"),42,1)
 var truck: Control = game.start_logo_wrap
 truck.reparent(stage)
 truck.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 truck.custom_minimum_size = Vector2.ZERO
 truck.position = Vector2(685,115)
 truck.size = Vector2(870,805)
 truck.z_index = 0
 game.tutorial_btn.text = "CAT TUTORIAL"
 _button(game.tutorial_btn,Vector2(85,710),Vector2(283,78),Color("EDB64D"),Color("704323"),24,2)
 _button(creator,Vector2(379,708),Vector2(303,72),Color("B5D6CB"),Color("20575B"),24,3)
 var cat := TextureRect.new()
 cat.name="ForegroundCat"
 var cat_atlas:=AtlasTexture.new()
 cat_atlas.atlas=preload("res://assets/ui/title_black_cat.png")
 cat_atlas.region=cat_atlas.atlas.get_image().get_used_rect()
 cat.texture=cat_atlas
 cat.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 cat.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 cat.position=Vector2(695,660)
 cat.size=Vector2(270,245)
 cat.z_index=5
 cat.mouse_filter=Control.MOUSE_FILTER_IGNORE
 stage.add_child(cat)
 old.hide()
 resized.connect(_layout)
 _layout()
 visibility_changed.connect(func():
  if is_visible_in_tree(): _entrance())
 call_deferred("_entrance")
func _layout() -> void:
 if not is_instance_valid(stage): return
 var fit := minf(size.x/1672.0,size.y/941.0)
 fit = maxf(.1,fit)
 stage.size = Vector2(1672,941)
 stage.scale = Vector2.ONE*fit
 stage.position = (size-stage.size*fit)*.5
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
  if state=="focus":
   style.bg_color=Color.TRANSPARENT
   style.border_color=Color("FFD66A")
   style.set_border_width_all(3)
  button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_outline_color"]: button.add_theme_color_override(key,Color.TRANSPARENT)
 var art := TextureRect.new()
 art.name="ReferenceButtonArt"
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.texture=load("res://assets/ui/title_button_%d.png"%order)
 button.add_child(art)
 button.set_meta("art_label",button.text)
 var status_bg:=ColorRect.new()
 status_bg.name="StatusBackground"
 status_bg.color=color
 status_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
 status_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 status_bg.hide()
 button.add_child(status_bg)
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
 caption.add_theme_constant_override("outline_size",0)
 caption.add_theme_color_override("font_color",ink)
 caption.add_theme_color_override("font_shadow_color",Color(0.05,.12,.14,.16))
 caption.add_theme_constant_override("shadow_offset_x",1)
 caption.add_theme_constant_override("shadow_offset_y",2)
 button.add_child(caption)
 caption.hide()
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
  var status_changed:bool=button.text!=str(button.get_meta("art_label"))
  caption.visible=status_changed
  button.get_node("StatusBackground").visible=status_changed
  var art=button.get_node("ReferenceButtonArt")
  art.visible=not status_changed
  art.modulate=Color(1.1,1.1,1.1) if button.has_focus() or button.is_hovered() else Color.WHITE
