extends Node
## Persistent local profile achievements. Only committed gameplay events reach this node.
signal unlocked(id: String)
const SAVE_PATH := "user://burger_pals_achievements.cfg"
const CHIME = preload("res://sounds/ui/chef_points.wav")
var save_path := SAVE_PATH
var stats: Dictionary = {}
var earned: Dictionary = {}
var catalog: Array[Dictionary] = []
var game: Node
var page: ScrollContainer
var list: VBoxContainer
var notifications: Array[Dictionary] = []
var toast_busy := false
func _init() -> void:
 for row in [["earnings",[100,500,1000,2500,5000,10000],"Earn $%d from real orders"], ["orders",[1,10,50,100,250],"Serve %d real orders"], ["perfect_burgers",[1,10,50],"Serve %d perfect burgers"], ["flips",[1,25,100],"Make %d perfect flips"], ["quick_cooks",[1,25],"Lift %d perfectly cooked patties"], ["purchases",[1,10,50],"Make %d purchases"], ["unlocks",[1,3,6],"Buy %d equipment upgrades"], ["reviews",[1,10,50],"Earn %d five-star reviews"], ["deliveries",[1,10,25],"Receive %d cat deliveries"], ["cat_treats",[1,10,25],"Give the cat %d treats"], ["days",[1,7],"Complete %d shifts"], ["tips",[1,100,500],"Earn $%d in tips"], ["cat_pets",[1],"Pet the cat"]]:
  for goal in row[1]:
   var title: String = (row[2] % goal) if "%d" in row[2] else row[2]
   if row[0]=="orders" and goal==1: title="First real order served"
   if row[0]=="perfect_burgers" and goal==1: title="First perfect burger"
   if row[0]=="purchases" and goal==1: title="First purchase"
   if row[0]=="unlocks" and goal==1: title="First equipment unlock"
   catalog.append({"id":"%s_%d"%[row[0],goal],"stat":row[0],"goal":float(goal),"title":title})
 for item in [["fryer_machine","Fry cook"],["soda_machine","Soda fountain"],["icecream_machine","Sweet tooth"],["grill_roomba","Clean machine"],["fridge_upgrade","Room to grow"],["gold_spatula","Golden touch"]]:
  catalog.append({"id":"buy_"+item[0],"stat":"buy_"+item[0],"goal":1.0,"title":item[1]})
func setup(owner_game: Node) -> void:
 game=owner_game
 var cfg:=ConfigFile.new()
 if cfg.load(save_path)==OK:
  stats=cfg.get_value("progress","stats",{})
  earned=cfg.get_value("progress","earned",{})
func record(key: String, amount: float=1.0) -> void:
 if amount<=0: return
 stats[key]=float(stats.get(key,0.0))+amount
 for entry in catalog:
  if entry.stat!=key or earned.has(entry.id) or float(stats[key])+0.0001<float(entry.goal): continue
  earned[entry.id]=Time.get_unix_time_from_system()
  notifications.append(entry)
  unlocked.emit(entry.id)
 save()
 if is_instance_valid(page) and page.visible: refresh_page()
 if is_instance_valid(game): _next_toast()
func save() -> void:
 var cfg:=ConfigFile.new()
 cfg.set_value("progress","stats",stats)
 cfg.set_value("progress","earned",earned)
 cfg.save(save_path)
func make_page(parent: Control) -> void:
 page=ScrollContainer.new()
 page.name="Achievements"
 page.custom_minimum_size.y=350
 page.size_flags_vertical=Control.SIZE_EXPAND_FILL
 page.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 parent.add_child(page)
 list=VBoxContainer.new()
 list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",10)
 page.add_child(list)
 page.hide()
 refresh_page()
func refresh_page() -> void:
 for child in list.get_children():
  list.remove_child(child)
  child.queue_free()
 var heading:=Label.new()
 heading.text="ACHIEVEMENTS  %d / %d"%[earned.size(),catalog.size()]
 heading.add_theme_font_size_override("font_size",18)
 heading.add_theme_color_override("font_color",Color("ffd375"))
 list.add_child(heading)
 var hint:=Label.new()
 hint.text="Lifetime progress - saved across games.\nPractice orders do not count."
 hint.add_theme_font_size_override("font_size",12)
 list.add_child(hint)
 for entry in catalog:
  var row:=VBoxContainer.new()
  list.add_child(row)
  var label:=Label.new()
  var done:=earned.has(entry.id)
  label.text=("UNLOCKED - " if done else "")+entry.title
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  label.add_theme_font_size_override("font_size",15)
  label.add_theme_color_override("font_color",Color("ffd375") if done else Color("d3dce7"))
  row.add_child(label)
  var bar:=ProgressBar.new()
  bar.max_value=float(entry.goal)
  bar.value=minf(float(stats.get(entry.stat,0)),bar.max_value)
  bar.custom_minimum_size.y=12
  bar.show_percentage=false
  var fill:=StyleBoxFlat.new()
  fill.bg_color=Color("e9a34f") if done else Color("628b99")
  fill.set_corner_radius_all(4)
  bar.add_theme_stylebox_override("fill",fill)
  var track:=StyleBoxFlat.new()
  track.bg_color=Color("263442")
  track.set_corner_radius_all(4)
  bar.add_theme_stylebox_override("background",track)
  row.add_child(bar)
  var count:=Label.new()
  count.text="%s / %s"%[str(int(bar.value)),str(int(entry.goal))]
  count.add_theme_font_size_override("font_size",12)
  row.add_child(count)
func _next_toast() -> void:
 if toast_busy or notifications.is_empty() or not is_instance_valid(game): return
 var ui:=game.get_node_or_null("UI/Root")
 if ui==null: return
 toast_busy=true
 var entry: Dictionary=notifications.pop_front()
 var toast:=PanelContainer.new()
 toast.mouse_filter=Control.MOUSE_FILTER_IGNORE
 toast.z_index=100
 ui.add_child(toast)
 toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 toast.offset_left=-230;toast.offset_right=230;toast.offset_top=116;toast.offset_bottom=196
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("25322e")
 style.border_color=Color("ffd375")
 style.set_border_width_all(2);style.set_corner_radius_all(12)
 style.content_margin_left=18;style.content_margin_right=18
 style.content_margin_top=12;style.content_margin_bottom=12
 toast.add_theme_stylebox_override("panel",style)
 var content:=HBoxContainer.new()
 content.add_theme_constant_override("separation",12)
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 toast.add_child(content)
 var icon:=TextureRect.new()
 icon.texture=preload("res://assets/ui/achievement_chef.svg")
 icon.custom_minimum_size=Vector2(54,54)
 icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 content.add_child(icon)
 var label:=Label.new()
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.text="ACHIEVEMENT UNLOCKED\n"+entry.title
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_color_override("font_color",Color("ffe3a2"))
 label.add_theme_font_size_override("font_size",20)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 content.add_child(label)
 var sound:=AudioStreamPlayer.new()
 sound.stream=CHIME;sound.bus="SFX";sound.volume_db=-12
 toast.add_child(sound);sound.play()
 toast.modulate.a=0
 var tween:=toast.create_tween()
 tween.tween_property(toast,"modulate:a",1.0,0.18)
 tween.tween_interval(3.2)
 tween.tween_property(toast,"modulate:a",0.0,0.3)
 tween.tween_callback(func(): toast.queue_free();toast_busy=false;_next_toast())
