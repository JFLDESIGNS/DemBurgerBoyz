extends RefCounted
static func add_header(parent: Control) -> void:
 var header:=HBoxContainer.new();header.alignment=BoxContainer.ALIGNMENT_CENTER;header.add_theme_constant_override("separation",16);parent.add_child(header)
 var burger:=Control.new();burger.custom_minimum_size=Vector2(185,147);burger.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(burger)
 var ids=["bun_bottom","patty","lettuce","cheese","tomato","bun_top"]
 var ys=[95,78,67,57,46,15]
 var widths=[160,163,170,170,148,175]
 for i in ids.size():
  var tex:Texture2D=FoodSprites.get_tex(ids[i]) if ids[i]!="patty" else FoodSprites.build_patty_state_tex(.15,false)
  var image:=FoodSprites.prep_texture_for_composite(tex)
  var layer:=TextureRect.new();layer.texture=ImageTexture.create_from_image(image);layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;layer.stretch_mode=TextureRect.STRETCH_SCALE;layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var w:float=widths[i];var h:float=w*image.get_height()/float(image.get_width())
  layer.size=Vector2(w,minf(h,80.0));layer.position=Vector2((185-w)*.5,ys[i]);layer.size*=.80;layer.position=layer.position*.80+Vector2(18,3);burger.add_child(layer)
  if ids[i] in ["bun_bottom","bun_top"]:layer.material=preload("res://shaders/build_bun_color.tres")
 var lettering:=VBoxContainer.new();lettering.custom_minimum_size=Vector2(265,0);lettering.add_theme_constant_override("separation",0);header.add_child(lettering)
 var logo:=Control.new();logo.custom_minimum_size=Vector2(265,91);lettering.add_child(logo)
 var mask:=preload("res://assets/ui/burger_pals_letter_mask.png")
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/challenge_burger_word.gdshader")
 var contours: Array[PackedVector2Array]=[
  PackedVector2Array([Vector2(398,19),Vector2(399,18),Vector2(417,12),Vector2(427,9),Vector2(438,6),Vector2(452,3),Vector2(464,1),Vector2(472,0),Vector2(499,0),Vector2(506,1),Vector2(514,3),Vector2(520,5),Vector2(525,7),Vector2(527,8),Vector2(532,11),Vector2(536,14),Vector2(540,18),Vector2(544,23),Vector2(547,28),Vector2(550,37),Vector2(551,43),Vector2(556,198),Vector2(556,199),Vector2(546,210),Vector2(528,229),Vector2(514,243),Vector2(513,243),Vector2(412,240),Vector2(411,239),Vector2(398,32)]),
  PackedVector2Array([Vector2(546,122),Vector2(547,115),Vector2(548,109),Vector2(551,97),Vector2(555,87),Vector2(559,79),Vector2(562,74),Vector2(568,65),Vector2(572,60),Vector2(591,41),Vector2(596,37),Vector2(600,34),Vector2(606,30),Vector2(614,25),Vector2(621,21),Vector2(623,20),Vector2(636,14),Vector2(641,12),Vector2(649,9),Vector2(661,5),Vector2(669,3),Vector2(671,3),Vector2(672,4),Vector2(691,105),Vector2(691,106),Vector2(690,114),Vector2(687,133),Vector2(681,170),Vector2(673,218),Vector2(671,228),Vector2(667,232),Vector2(662,236),Vector2(650,240),Vector2(646,241),Vector2(641,242),Vector2(626,242),Vector2(620,241),Vector2(616,240),Vector2(610,238),Vector2(598,232),Vector2(589,226),Vector2(584,222),Vector2(577,215),Vector2(572,209),Vector2(568,204),Vector2(566,201),Vector2(563,196),Vector2(557,184),Vector2(554,177),Vector2(552,172),Vector2(550,165),Vector2(549,161),Vector2(547,151),Vector2(546,142)]),
  PackedVector2Array([Vector2(0,96),Vector2(1,95),Vector2(7,91),Vector2(20,83),Vector2(30,77),Vector2(51,65),Vector2(79,51),Vector2(90,46),Vector2(104,40),Vector2(122,33),Vector2(140,27),Vector2(151,24),Vector2(155,23),Vector2(164,21),Vector2(170,20),Vector2(178,19),Vector2(194,19),Vector2(200,20),Vector2(207,22),Vector2(211,24),Vector2(214,26),Vector2(222,34),Vector2(226,42),Vector2(227,47),Vector2(250,184),Vector2(251,190),Vector2(251,204),Vector2(250,210),Vector2(249,215),Vector2(247,223),Vector2(246,226),Vector2(243,234),Vector2(241,239),Vector2(231,259),Vector2(222,274),Vector2(218,280),Vector2(205,296),Vector2(185,320),Vector2(177,329),Vector2(168,339),Vector2(150,358),Vector2(130,378),Vector2(0,109)]),
  PackedVector2Array([Vector2(689,241),Vector2(692,214),Vector2(712,40),Vector2(713,33),Vector2(714,31),Vector2(727,30),Vector2(743,29),Vector2(762,28),Vector2(782,27),Vector2(823,27),Vector2(823,32),Vector2(813,93),Vector2(812,99),Vector2(797,181),Vector2(778,247),Vector2(777,248),Vector2(770,249),Vector2(706,251),Vector2(689,251)]),
  PackedVector2Array([Vector2(234,88),Vector2(236,86),Vector2(269,69),Vector2(289,59),Vector2(311,49),Vector2(327,44),Vector2(340,40),Vector2(363,33),Vector2(370,31),Vector2(374,30),Vector2(375,31),Vector2(376,35),Vector2(381,77),Vector2(382,86),Vector2(384,105),Vector2(386,129),Vector2(387,150),Vector2(387,164),Vector2(386,180),Vector2(385,190),Vector2(384,195),Vector2(382,204),Vector2(378,216),Vector2(371,230),Vector2(369,233),Vector2(361,242),Vector2(359,244),Vector2(352,248),Vector2(350,249),Vector2(345,251),Vector2(341,252),Vector2(336,253),Vector2(323,253),Vector2(316,251),Vector2(313,250),Vector2(307,247),Vector2(301,243),Vector2(297,240),Vector2(289,232),Vector2(285,227),Vector2(279,218),Vector2(276,213),Vector2(268,197),Vector2(265,190),Vector2(262,182),Vector2(255,161),Vector2(249,142),Vector2(246,132),Vector2(235,94),Vector2(234,89)]),
  PackedVector2Array([Vector2(792,269),Vector2(821,143),Vector2(839,65),Vector2(841,57),Vector2(848,57),Vector2(856,58),Vector2(863,59),Vector2(875,61),Vector2(886,63),Vector2(895,65),Vector2(903,67),Vector2(913,70),Vector2(922,73),Vector2(927,75),Vector2(934,78),Vector2(946,84),Vector2(951,87),Vector2(957,91),Vector2(961,94),Vector2(969,101),Vector2(971,103),Vector2(976,109),Vector2(982,118),Vector2(983,120),Vector2(985,125),Vector2(987,131),Vector2(988,136),Vector2(988,149),Vector2(987,154),Vector2(954,300),Vector2(950,305),Vector2(943,313),Vector2(902,351),Vector2(898,354),Vector2(897,354),Vector2(793,271),Vector2(792,270)])
 ]
 for contour in contours:
  var letter:=Polygon2D.new();letter.polygon=contour;letter.uv=contour;letter.texture=mask;letter.material=material;letter.scale=Vector2(.265,.235);logo.add_child(letter)
 var title:=Label.new();title.text="CHALLENGE";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_override("font",preload("res://assets/fonts/AlfaSlabOne-Regular.ttf"));title.add_theme_font_size_override("font_size",29);title.add_theme_color_override("font_color",Color("613722"));lettering.add_child(title)
static func style_button(button: Button, primary: bool) -> void:
 button.add_theme_font_override("font",preload("res://assets/fonts/LuckiestGuy-Regular.ttf"))
 button.add_theme_font_size_override("font_size",23 if primary else 20)
 for state in ["normal","hover","pressed","focus"]:
  var skin:=StyleBoxFlat.new();skin.set_corner_radius_all(17);skin.corner_radius_top_left=25;skin.corner_radius_bottom_right=25;skin.set_border_width_all(3);skin.border_width_bottom=8
  skin.bg_color=Color("EF6033") if primary else Color("F6D98C");skin.border_color=Color("7C2B21") if primary else Color("997043")
  if state=="hover":skin.bg_color=skin.bg_color.lightened(.12)
  if state=="pressed":skin.bg_color=skin.bg_color.darkened(.12);skin.border_width_bottom=2
  skin.shadow_color=Color(0.25,.12,.05,.16);skin.shadow_size=1;skin.shadow_offset=Vector2(0,5)
  button.add_theme_stylebox_override(state,skin)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("FFF4DA") if primary else Color("785134"))
 button.add_theme_color_override("font_outline_color",Color("7C2B21") if primary else Color("FBEAC1"))
 button.add_theme_constant_override("outline_size",3 if primary else 2)
