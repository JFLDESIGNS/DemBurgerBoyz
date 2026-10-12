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
 assert(g.multiplayer_btn.get_global_rect().end.x<g.start_logo_wrap.get_global_rect().position.x)
 assert(g.tutorial_btn.get_global_rect().position.y>g.multiplayer_btn.get_global_rect().end.y)
 assert(g.start_btn.size.y>g.tutorial_btn.size.y)
 assert(not layout.stage.has_node("ForegroundCat"))
 var group=g._menu_truck.world.get_node("MenuPals")
 assert(group.has_node("OpeningPal0") and group.has_node("OpeningPal1") and group.has_node("OpeningCat3D"))
 for actor_name in ["OpeningPal0","OpeningPal1","OpeningCat3D"]:
  var actor=group.get_node(actor_name)
  assert(actor.position.x<2.5 and actor.position.z>3.79,"Menu actors must remain beside the departure route")
 assert(g._menu_truck.camera.projection==Camera3D.PROJECTION_PERSPECTIVE)
 assert(g._menu_truck.camera.position.y<2.0,"Reference uses a low front-corner camera")
 for resolution in [Vector2i(1280,720),Vector2i(1440,1080),Vector2i(1920,1080)]:
  root.size=resolution
  for frame in 6: await process_frame
  var bounds=layout.get_global_rect()
  for holder in layout.entries:
   assert(bounds.encloses(holder.get_global_rect()),"Menu buttons must fit at every supported aspect ratio")

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
