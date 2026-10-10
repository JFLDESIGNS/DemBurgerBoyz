extends SceneTree
const Food=preload("res://scripts/food_sprites.gd")
class MeltProbe extends Node:
 var cheese_melt:float=0.0
 var cheese_effect_age:float=0.0
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1200,750);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var bg:=ColorRect.new();bg.color=Color("30343A");bg.size=Vector2(1200,750);root.add_child(bg)
 var prior:Texture2D
 for i in 12:
  var t:float=float(i)/11.0
  var tex=Food.build_patty_state_tex(0,true,t)
  assert(Food.cheese_melt_frame(t)==i)
  assert(tex!=prior and tex==Food.build_patty_state_tex(0,true,t),"Frames must differ and reuse cached textures")
  var image:=TextureRect.new();image.texture=tex;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.position=Vector2(15+(i%4)*300,25+(i/4)*245);image.size=Vector2(270,185);root.add_child(image)
  var probe=MeltProbe.new();probe.cheese_melt=t;probe.cheese_effect_age=t*1.2;root.add_child(probe)
  var blend=load("res://scripts/build_cheese_blend.gd").new();image.add_child(blend);blend.setup(probe)
  var label:=Label.new();label.text="Melt %d / 12"%(i+1);label.position=image.position+Vector2(70,185);label.add_theme_font_size_override("font_size",20);root.add_child(label)
  prior=tex
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/customer_polish_qa/cheese_melt_preview.png")
 print("CHEESE_MELT_OK: twelve aligned cached states")
 quit()
