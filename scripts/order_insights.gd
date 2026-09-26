extends Node
var game: Node
var page: VBoxContainer
var ledger: VBoxContainer
var counter: Label
var expanded := {}
func setup(g: Node, parent: Control) -> void:
 game=g
 page=VBoxContainer.new()
 page.name="MyOrdersApp"
 parent.add_child(page)
 ledger=VBoxContainer.new()
 ledger.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 ledger.add_theme_constant_override("separation",12)
 page.add_child(ledger)
 page.hide()
 counter=Label.new()
 counter.name="PerfectOrderCounter"
 counter.mouse_filter=Control.MOUSE_FILTER_IGNORE
 counter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 counter.offset_left=-170
 counter.offset_right=170
 counter.offset_top=36
 counter.offset_bottom=69
 counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 counter.add_theme_font_size_override("font_size",14)
 counter.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
 counter.add_theme_color_override("font_color",Color("FFA52E"))
 counter.add_theme_color_override("font_outline_color",Color("30231B"))
 counter.add_theme_constant_override("outline_size",2)
 game.get_node("UI/Root").add_child(counter)
 refresh()
func _process(_delta: float) -> void:
 var streak := 0
 for i in range(game.order_history.size()-1,-1,-1):
  var row: Dictionary = game.order_history[i]
  if int(row.get("day",0)) != game.day or not bool(row.get("perfect",false)): break
  streak += 1
 counter.modulate.a = move_toward(counter.modulate.a, 1.0 if game.playing and streak > 0 else 0.0, _delta * 3.0)
 counter.visible = counter.modulate.a > .001
 var ui_scale := maxf(.1,counter.get_global_transform_with_canvas().y.length())
 counter.offset_top=36.0-35.0/ui_scale
 counter.offset_bottom=counter.offset_top+33.0
 if streak > 0: counter.text="★  PERFECT STREAK  %d" % streak
func show_app(id: String) -> void:
 page.visible=id=="orders"
 if page.visible: refresh()
func label(parent: Control, text: String, color: Color=Color("E7EFED"), size: int=13) -> Label:
 var node := Label.new()
 node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 node.add_theme_font_size_override("font_size",size)
 node.add_theme_color_override("font_color",color)
 parent.add_child(node)
 return node
func refresh() -> void:
 if not is_instance_valid(ledger): return
 for child in ledger.get_children():ledger.remove_child(child);child.queue_free()
 label(ledger,"MY SALES",Color("FFD06A"),18)
 label(ledger,"This session · Before boss cut",Color("9EBCB9"),11)
 if game.order_history.is_empty():label(ledger,"Your first sale will appear here.")
 for i in range(game.order_history.size()-1,-1,-1):
  var row: Dictionary=game.order_history[i]
  var card:=PanelContainer.new()
  var style:=StyleBoxFlat.new();style.bg_color=Color("192630");style.set_corner_radius_all(9);style.set_content_margin_all(10)
  card.add_theme_stylebox_override("panel",style);ledger.add_child(card)
  var body:=VBoxContainer.new();body.add_theme_constant_override("separation",7);card.add_child(body)
  label(body,"ORDER #%d  ·  DAY %d" % [row.number,row.day],Color("FFD06A"),13)
  var photo: PackedByteArray=row.get("photo",PackedByteArray())
  if not photo.is_empty():
   var img:=Image.new()
   if img.load_png_from_buffer(photo)==OK:
    var pic:=TextureRect.new();pic.texture=ImageTexture.create_from_image(img)
    pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pic.custom_minimum_size=Vector2(0,112);body.add_child(pic)
  var names:=PackedStringArray()
  for item in str(row.get("items","")).split(","):
   var clean:=item.strip_edges()
   if clean in ["bun_top","bun_bottom"]:continue
   names.append(clean.replace("_"," ").capitalize())
  label(body," · ".join(names),Color("C7D9D5"),12)
  var stats: Dictionary=row.get("stats",{})
  for entry in [["Accuracy","accuracy"],["Cook","doneness"],["Seasoning","seasoning"],["Freshness","freshness"]]:
   if stats.has(entry[1]):label(body,"%s: %s" % [entry[0],stats[entry[1]]],Color("D9E2E0"),12)
  body.add_child(HSeparator.new())
  label(body,"Sale  $%.2f     Tip  $%.2f" % [row.sale,row.tip],Color.WHITE,12)
  label(body,"Cost  $%.2f" % row.cost,Color("9EBCB9"),12)
  label(body,"PROFIT  $%.2f" % row.profit,Color("9FEDAD"),16)
  var review:=str(row.get("review",""))
  if not review.is_empty():
   var key:=str(row.number)
   var toggle:=Button.new();toggle.text="%.1f stars · %s" % [float(row.get("stars",0)),"Hide review" if expanded.get(key,false) else "Read review"]
   toggle.add_theme_font_size_override("font_size",12);body.add_child(toggle)
   toggle.pressed.connect(func():expanded[key]=not bool(expanded.get(key,false));refresh())
   label(body,review if expanded.get(key,false) else review.left(65)+("…" if review.length()>65 else ""),Color("B8CBC6"),12)
