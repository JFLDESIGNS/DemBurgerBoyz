extends Node
var game: Node
var page: VBoxContainer
var ledger: RichTextLabel
var counter: Label
var expanded := {}
func setup(g: Node, parent: Control) -> void:
 game=g
 page=VBoxContainer.new()
 page.name="MyOrdersApp"
 parent.add_child(page)
 ledger=RichTextLabel.new()
 ledger.bbcode_enabled=true
 ledger.meta_clicked.connect(func(meta):
  expanded[str(meta)] = not bool(expanded.get(str(meta),false))
  refresh())
 ledger.custom_minimum_size=Vector2(0,390)
 ledger.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 ledger.add_theme_font_size_override("normal_font_size",14)
 ledger.add_theme_font_size_override("bold_font_size",14)
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
 counter.add_theme_font_size_override("font_size",22)
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
 counter.visible=game.playing and streak>0
 var ui_scale := maxf(.1,counter.get_global_transform_with_canvas().y.length())
 counter.offset_top=36.0-40.0/ui_scale
 counter.offset_bottom=counter.offset_top+33.0
 counter.text="★  PERFECT STREAK  %d" % streak
func show_app(id: String) -> void:
 page.visible=id=="orders"
 if page.visible: refresh()
func refresh() -> void:
 if not is_instance_valid(ledger): return
 ledger.clear()
 ledger.append_text("[b]LAST 100 ORDERS[/b]\n[color=#9EBCB9]This session · Profit before boss cut[/color]\n\n")
 if game.order_history.is_empty(): ledger.append_text("Your first sale will appear here.")
 for i in range(game.order_history.size()-1,-1,-1):
  var row: Dictionary=game.order_history[i]
  ledger.append_text("[color=#FFD06A][b]ORDER #%d  ·  DAY %d[/b][/color]\n" % [row.number,row.day])
  var photo: PackedByteArray = row.get("photo",PackedByteArray())
  if not photo.is_empty():
   var img := Image.new()
   if img.load_png_from_buffer(photo) == OK: ledger.add_image(ImageTexture.create_from_image(img),110,110)
  ledger.add_text(str(row.items)+"\n")
  var stats: Dictionary = row.get("stats",{})
  if not stats.is_empty(): ledger.add_text("Accuracy %s · %s\n%s · Freshness %s\n" % [stats.get("accuracy","—"),stats.get("doneness","—"),stats.get("seasoning","—"),stats.get("freshness","—")])
  var review := str(row.get("review",""))
  if not review.is_empty():
   var key := str(row.number)
   ledger.append_text("[url=%s]%.1f stars · %s[/url]\n" % [key,float(row.get("stars",0)),"Hide review" if expanded.get(key,false) else "Read review"])
   ledger.add_text((review if expanded.get(key,false) else review.left(72)+"…")+"\n")
  ledger.append_text("Sale $%.2f  +  Tip $%.2f\nIngredients $%.2f\n[color=#9FEDAD][b]Food profit $%.2f[/b][/color]\n\n" % [row.sale,row.tip,row.cost,row.profit])
