extends RefCounted
static func add_header(parent: Control) -> void:
 var header:=HBoxContainer.new();header.alignment=BoxContainer.ALIGNMENT_CENTER;header.add_theme_constant_override("separation",16);parent.add_child(header)
 var burger:=Control.new();burger.custom_minimum_size=Vector2(185,147);burger.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(burger)
 var ids=["bun_bottom","lettuce","patty","cheese","tomato","bun_top"]
 var ys=[95,83,65,57,46,5]
 var widths=[160,170,163,170,148,175]
 for i in ids.size():
  var tex:Texture2D=FoodSprites.get_tex(ids[i]) if ids[i]!="patty" else FoodSprites.build_patty_state_tex(.15,false)
  var image:=FoodSprites.prep_texture_for_composite(tex)
  var layer:=TextureRect.new();layer.texture=ImageTexture.create_from_image(image);layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;layer.stretch_mode=TextureRect.STRETCH_SCALE;layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var w:float=widths[i];var h:float=w*image.get_height()/float(image.get_width())
  layer.size=Vector2(w,minf(h,80.0));layer.position=Vector2((185-w)*.5,ys[i]);layer.size*=.80;layer.position=layer.position*.80+Vector2(18,3);burger.add_child(layer)
  if ids[i] in ["bun_bottom","bun_top"]:layer.material=preload("res://shaders/build_bun_color.tres")
 var lettering:=VBoxContainer.new();lettering.custom_minimum_size=Vector2(265,0);lettering.add_theme_constant_override("separation",0);header.add_child(lettering)
 var logo:=TextureRect.new();logo.texture=preload("res://assets/ui/burger_pals_letter_mask.png");logo.custom_minimum_size=Vector2(265,103);logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_SCALE
 logo.material=ShaderMaterial.new();logo.material.shader=preload("res://shaders/challenge_burger_word.gdshader");lettering.add_child(logo)
 var title:=Label.new();title.text="CHALLENGE";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_override("font",preload("res://assets/fonts/AlfaSlabOne-Regular.ttf"));title.add_theme_font_size_override("font_size",29);title.add_theme_color_override("font_color",Color("613722"));lettering.add_child(title)
static func style_button(button: Button, primary: bool) -> void:
 button.add_theme_font_override("font",preload("res://assets/fonts/Nunito-ExtraBold.ttf"))
 button.add_theme_font_size_override("font_size",20 if primary else 17)
 for state in ["normal","hover","pressed","focus"]:
  var skin:=StyleBoxFlat.new();skin.set_corner_radius_all(12);skin.set_border_width_all(2);skin.border_width_bottom=5
  skin.bg_color=Color("C34125") if primary else Color("F9EFD8");skin.border_color=Color("842E20") if primary else Color("C6A67B")
  if state=="hover":skin.bg_color=skin.bg_color.lightened(.12)
  if state=="pressed":skin.bg_color=skin.bg_color.darkened(.12);skin.border_width_bottom=2
  skin.shadow_color=Color(0.25,.12,.05,.16);skin.shadow_size=4;skin.shadow_offset=Vector2(0,3)
  button.add_theme_stylebox_override(state,skin)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("FFF4DA") if primary else Color("785134"))
 button.add_theme_constant_override("outline_size",0)
