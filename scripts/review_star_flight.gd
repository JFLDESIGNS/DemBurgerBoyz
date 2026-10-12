extends RefCounted
static func launch(game: Node,source: Label) -> void:
 if not is_instance_valid(source) or not is_instance_valid(game.chef_points_hud): return
 var ui: Control=game.get_node("UI/Root")
 var audio:=AudioStreamPlayer.new()
 audio.stream=preload("res://sounds/ui/five_star_dance.wav");audio.bus="SFX";audio.volume_db=-12
 ui.add_child(audio);audio.finished.connect(audio.queue_free);audio.play()
 await game.get_tree().create_timer(.45).timeout
 if not is_instance_valid(source) or not is_instance_valid(game.chef_points_hud): return
 var inverse:=ui.get_global_transform_with_canvas().affine_inverse()
 var origin:=inverse*source.get_global_transform_with_canvas()*Vector2.ZERO
 var width: float=source.size.x
 source.modulate.a=0.0
 for i in 5:
  var star:=Label.new();star.text="★";star.mouse_filter=Control.MOUSE_FILTER_IGNORE;star.z_index=100
  star.add_theme_font_override("font",preload("res://assets/fonts/Nunito-ExtraBold.ttf"))
  star.add_theme_font_size_override("font_size",22);star.add_theme_color_override("font_color",Color("FFD65A"))
  star.add_theme_color_override("font_outline_color",Color("805420"));star.add_theme_constant_override("outline_size",2)
  ui.add_child(star)
  var start:=origin+Vector2(width*(float(i)/5.0),0)
  star.position=start
  var tween:=star.create_tween()
  tween.tween_interval(float(i)*.10)
  tween.tween_method(func(t:float):
   if not is_instance_valid(game.chef_points_hud): return
   var target: Vector2=inverse*game.chef_points_hud.get_global_transform_with_canvas()*(game.chef_points_hud.size*.5)
   star.position=start.lerp(target,t*t)+Vector2(sin(t*PI)*(float(i)-2)*25,-sin(t*PI)*75)
   star.rotation=sin(t*PI)*.25
   star.scale=Vector2.ONE*lerpf(1.0,.55,t)
  ,0.0,1.0,.8)
  tween.tween_callback(func():
   if is_instance_valid(game.chef_points_hud):
    var hud=game.chef_points_hud
    hud.modulate=Color(1.4,1.25,.8)
    hud.create_tween().tween_property(hud,"modulate",Color.WHITE,.18)
   star.queue_free()
  )
