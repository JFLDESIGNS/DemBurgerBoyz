extends Control
var game: Node
var bar: ProgressBar
var caption: Label
var last_tick_ms := 0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 bar=ProgressBar.new();bar.show_percentage=false
 add_child(bar)
 bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bar.anchor_left=1.0/3.0;bar.anchor_right=2.0/3.0
 bar.offset_left=0;bar.offset_right=0;bar.offset_top=-44;bar.offset_bottom=-32
 var fill:=StyleBoxFlat.new();fill.bg_color=Color("FFD06B");fill.set_corner_radius_all(7)
 var back:=StyleBoxFlat.new();back.bg_color=Color(.025,.035,.06,.85);back.set_corner_radius_all(7)
 bar.add_theme_stylebox_override("fill",fill);bar.add_theme_stylebox_override("background",back)
 caption=Label.new();add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 caption.anchor_left=1.0/3.0;caption.anchor_right=2.0/3.0
 caption.offset_left=0;caption.offset_right=0;caption.offset_top=-75;caption.offset_bottom=-46
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.add_theme_font_size_override("font_size",14)
 caption.add_theme_color_override("font_color",Color("FFE5A5"))
 caption.add_theme_color_override("font_outline_color",Color.BLACK)
 caption.add_theme_constant_override("outline_size",3)
func _process(_dt:float) -> void:
 if game==null or not is_visible_in_tree():
  last_tick_ms=0
  return
 var now := Time.get_ticks_msec()
 var elapsed := float(now-last_tick_ms)/1000.0 if last_tick_ms>0 else 0.0
 last_tick_ms=now
 var phase:String=game.get_meta("loading_phase","video_playback")
 var stages:Dictionary={"video_playback":[5,"WELCOME TO BURGER PALS"],"resources":[20,"LOADING KITCHEN ASSETS"],"food_images":[35,"PREPARING INGREDIENTS"],"kitchen":[48,"BUILDING YOUR KITCHEN"],"vehicles":[72,"GETTING DELIVERIES READY"],"runtime_pools":[84,"PREPARING CUSTOMERS AND FOOD"],"final_render":[94,"WARMING UP THE GRILL"],"item_preparation":[98,"ALMOST READY"],"ready":[100,"LET'S COOK!"]}
 var stage:Array=stages.get(phase,[5,"GETTING READY"])
 bar.value=maxf(bar.value,float(stage[0]))
 if phase!="ready":
  var creep := elapsed if bar.value<95.0 else (100.0-bar.value)*(1.0-exp(-elapsed*.025))
  bar.value=minf(99.95,bar.value+creep)
 caption.text=str(stage[1])+"  %d%%" % int(bar.value)
