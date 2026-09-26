extends CanvasLayer
var game: Node
var screen: ColorRect
var summary: VBoxContainer
var title: Label
var transition: Tween
var saved: Array=[]
var active:=false
var recap_layer: CanvasLayer
var recap_root: Control
var lifted: Array=[]
var started_ms:=0

func setup(owner_game: Node) -> void:
 game=owner_game
 layer=500
 recap_layer=CanvasLayer.new()
 recap_layer.layer=501
 add_child(recap_layer)
 recap_root=Control.new()
 recap_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 recap_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 recap_layer.add_child(recap_root)
 screen=ColorRect.new()
 screen.mouse_filter=Control.MOUSE_FILTER_STOP
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var material:=ShaderMaterial.new()
 material.shader=preload("res://shaders/shift_night.gdshader")
 screen.material=material
 add_child(screen)
 screen.hide()

func begin() -> void:
 if not active:
  active=true
  started_ms=Time.get_ticks_msec()
  lift_control(game.game_over_panel)
  screen.material.set_shader_parameter("blackout",0.0)
  screen.material.set_shader_parameter("dusk",0.0)
  for lamp in [game.gfx_sun,game._profile_sun,game.gfx_outside_fill]:
   if is_instance_valid(lamp): saved.append({"lamp":lamp,"energy":lamp.light_energy,"rotation":lamp.rotation,"color":lamp.light_color})
  screen.show()
  transition=create_tween()
  transition.tween_method(_sunset,0.0,1.0,7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  transition.tween_interval(2.0)
  transition.tween_method(func(t: float): screen.material.set_shader_parameter("blackout",t),0.0,1.0,3.0)
 rebuild()

func lift_control(control: Control) -> void:
 if control.get_parent()==recap_root: return
 for item in lifted:
  if item.node==control: return
 lifted.append({"node":control,"parent":control.get_parent(),"index":control.get_index()})
 control.reparent(recap_root)

func seek_closing(seconds: float) -> void:
 if transition: transition.custom_step(maxf(seconds,0.0))

func _sunset(t: float) -> void:
 screen.material.set_shader_parameter("dusk",t)
 for item in saved:
  if not is_instance_valid(item.lamp): continue
  item.lamp.light_energy=lerpf(item.energy,item.energy*.06,t)
  item.lamp.light_color=item.color.lerp(Color("EF9867"),minf(t*2.0,1.0))
  item.lamp.rotation=Vector3(lerpf(item.rotation.x,deg_to_rad(8),t),item.rotation.y,item.rotation.z)

func restore() -> void:
 if not active: return
 active=false
 if transition: transition.kill()
 for item in saved:
  if is_instance_valid(item.lamp):
   item.lamp.light_energy=item.energy
   item.lamp.rotation=item.rotation
   item.lamp.light_color=item.color
 saved.clear()
 screen.hide()
 for item in lifted:
  if is_instance_valid(item.node) and is_instance_valid(item.parent):
   item.node.reparent(item.parent)
   item.parent.move_child(item.node,mini(item.index,item.parent.get_child_count()-1))
 lifted.clear()
 if is_instance_valid(summary): summary.hide()
 game.game_over_label.show()

func _process(_delta: float) -> void:
 if active and game.playing: restore()

func panel_style(color: Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(16)
 style.set_content_margin_all(14)
 style.border_color=Color("476477")
 style.set_border_width_all(1)
 return style

func label(parent: Node,text: String,size: int,color: Color=Color("F7EACF")) -> Label:
 var node:=Label.new()
 node.text=text
 game.UiFontsScript.apply_label(node,true,size)
 node.add_theme_color_override("font_color",color)
 parent.add_child(node)
 return node

func card(parent: Node) -> VBoxContainer:
 var plate:=PanelContainer.new()
 plate.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 plate.add_theme_stylebox_override("panel",panel_style(Color("172B3B")))
 parent.add_child(plate)
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",6)
 plate.add_child(box)
 return box

func row(parent: Node,caption: String,value: String,color: Color=Color("F7EACF")) -> void:
 var line:=HBoxContainer.new()
 parent.add_child(line)
 label(line,caption,14,Color("ADBCC7")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label(line,value,16,color)

func rebuild() -> void:
 var panel: PanelContainer=game.game_over_panel
 panel.z_index=400
 panel.offset_left=-370;panel.offset_right=370
 panel.offset_top=-290;panel.offset_bottom=290
 panel.add_theme_stylebox_override("panel",panel_style(Color(.035,.065,.10,.96)))
 var box: VBoxContainer=panel.get_node("GOMargin/GOVBox")
 box.add_theme_constant_override("separation",10)
 box.alignment=BoxContainer.ALIGNMENT_BEGIN
 game.game_over_label.hide()
 if is_instance_valid(summary):
  box.remove_child(summary)
  summary.queue_free()
 summary=VBoxContainer.new()
 summary.name="ShiftSummary"
 summary.add_theme_constant_override("separation",10)
 box.add_child(summary)
 box.move_child(summary,0)
 label(summary,"BURGER PALS  /  AFTER HOURS",12,Color("F4BC63"))
 title=label(summary,"THAT’S A WRAP!",32)
 game.UiFontsScript.apply_luckiest_label(title,32)
 label(summary,"%s  •  AREA %d OF %d  •  %s" % [game.TruckLocationsScript.display_name(game.current_location_id),game.TruckLocationsScript.rank_of(game.current_location_id),game.TruckLocationsScript.all().size(),game.TruckLocationsScript.tier_label(game.TruckLocationsScript.tier_of(game.current_location_id))],15,Color("ADBCC7"))
 var stats:=HBoxContainer.new()
 stats.add_theme_constant_override("separation",10)
 summary.add_child(stats)
 for item in [[str(game.total_served),"ORDERS SERVED"],[str(game.perfect_serves),"PERFECT BURGERS"],[game._format_money(game.shift_food_sales+game.shift_tips-game.shift_ingredient_cost-game.last_day_cut),"NET FOOD PROFIT"]]:
  var tile:=card(stats)
  label(tile,item[0],27,Color("F0A190") if String(item[0]).contains("-") else Color("A4E3B0"))
  label(tile,item[1],11,Color("ADBCC7"))
 var columns:=HBoxContainer.new()
 columns.add_theme_constant_override("separation",12)
 summary.add_child(columns)
 var earnings:=card(columns)
 label(earnings,"THE DAY’S TAKINGS",16,Color("F4BC63"))
 row(earnings,"Food sales",game._format_money(game.shift_food_sales))
 row(earnings,"Tips",game._format_money(game.shift_tips))
 row(earnings,"Ingredients / spoilage","−"+game._format_money(game.shift_ingredient_cost))
 row(earnings,"Boss’s cut","−"+game._format_money(game.last_day_cut))
 row(earnings,"Restocks purchased",game._format_money(game.shift_restock_spend))
 label(earnings,"Inventory already paid; not deducted twice.",11,Color("ADBCC7"))
 var reviews:=card(columns)
 reviews.get_parent().custom_minimum_size.x=315
 label(reviews,"WORD ON THE STREET",16,Color("F4BC63"))
 var review_text: String=game._format_day_social_recap()
 var review:=label(reviews,review_text,13)
 review.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 review.custom_minimum_size=Vector2(280,0)
 review.max_lines_visible=9
 review.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 row(summary,"Wallet / checking",game._format_money(game.money),Color("A4E3B0"))
 row(summary,"Savings",game._format_money(game.bank_savings))
 var actions:=box.get_node_or_null("ShiftActions")
 if actions==null:
  actions=HBoxContainer.new()
  actions.name="ShiftActions"
  actions.add_theme_constant_override("separation",12)
  box.add_child(actions)
  for button in [game.restart_btn,game.game_over_location_btn]:
   if is_instance_valid(button):
    button.reparent(actions)
    button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    button.custom_minimum_size=Vector2(0,44)
    game.UiFontsScript.apply_luckiest_button(button,16)
    button.add_theme_stylebox_override("normal",panel_style(Color("264B59")))
 game.restart_btn.text="PLAY ANOTHER SHIFT"
 game.game_over_location_btn.text="MOVE THE TRUCK"
 if not game.game_over_location_btn.pressed.is_connected(restore): game.game_over_location_btn.pressed.connect(restore)
