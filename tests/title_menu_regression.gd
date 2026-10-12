extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(90).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/title_menu_fixture.gd"))
 root.add_child(g);current_scene=g
 g._style_static_labels()
 g._setup_multiplayer_ui()
 g.flash_label.hide();g.game_over_panel.hide()
 var layout=g.start_overlay.get_node("TitleMenuLayout")
 await create_timer(1.5).timeout
 assert(not g.get_node("UI/Root/StartOverlay/StartCenter").visible)
 assert(g.start_btn.get_global_rect().end.y<g.multiplayer_btn.get_global_rect().position.y)
 assert(g.multiplayer_btn.get_global_rect().end.x<g.start_logo_wrap.get_global_rect().position.x + 100)
 assert(g.tutorial_btn.get_global_rect().position.y>g.multiplayer_btn.get_global_rect().end.y)
 assert(g.start_btn.size.y>g.tutorial_btn.size.y)
 assert(not layout.stage.has_node("ForegroundCat"))
 var group=g._menu_truck.world.get_node("MenuPals")
 assert(group.has_node("OpeningPal0") and layout.stage.has_node("ForegroundPal3D") and layout.stage.has_node("OpeningCat3D"))
 for actor_name in ["OpeningPal0"]:
  var actor=group.get_node(actor_name)
  assert(actor.position.z < -5.0,"Menu actors must remain beside the departure route")
 assert(g._menu_truck.camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
 assert(g._menu_truck.camera.position.y<2.0,"Reference uses a low front-corner camera")
 for resolution in [Vector2i(1280,720),Vector2i(1440,1080),Vector2i(1920,1080)]:
  root.size=resolution
  for frame in 6: await process_frame
  var bounds=layout.get_global_rect()
  for holder in layout.entries:
   assert(bounds.encloses(holder.get_global_rect()),"Menu buttons must fit at every supported aspect ratio")

 var cat=layout.stage.get_node("OpeningCat3D")
 assert(g.start_btn.pressed.is_connected(cat.celebrate))
 cat.celebrate()
 cat._process(.15)
 assert(cat.cat.position.y>.3 and cat.eyes.size()==2)
 for material in cat.eyes: assert(material.get_shader_parameter("pupil_gaze") is Vector2)
 cat.hop=0;cat._process(.01)
 g.start_btn.mouse_entered.emit()
 await create_timer(.4).timeout
 assert(is_equal_approx(g.start_btn.position.y,-4))
 g.start_btn.mouse_exited.emit()
 await create_timer(.25).timeout
 assert(is_zero_approx(g.start_btn.position.y))
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/title_menu_checked.png")
 g.start_overlay.hide();g.playing=true;g.menu_ready=true;g._kitchen_ready=true
 for key in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
  var event=InputEventKey.new();event.keycode=key;event.pressed=true
  assert(g._is_serve_shortcut_pressed(event))
  g._input(event)
  event.echo=true;assert(not g._is_serve_shortcut_pressed(event))
 assert(g.serve_shortcuts==3)
 var entry=LineEdit.new();g.get_node("UI/Root").add_child(entry);entry.grab_focus()
 var typing=InputEventKey.new();typing.keycode=KEY_SPACE;typing.pressed=true
 assert(not g._is_serve_shortcut_pressed(typing))
 print("TITLE_MENU_REGRESSION_OK")
 quit()
