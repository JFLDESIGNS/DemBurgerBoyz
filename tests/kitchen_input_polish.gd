extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g.fryer_held_index=0
 for mode in ["cook","shake"]:
  g._fryer_auto_mode=mode
  assert(not g._hands_busy_with_other_tool(),"Automatic fryer must leave hands free")
 g._fryer_auto_mode=""
 assert(g._hands_busy_with_other_tool(),"Manual basket still occupies hands")
 var buy=Button.new();g.get_node("UI/Root").add_child(buy);buy.position=Vector2(30,40);buy.size=Vector2(150,50)
 g._boss_suggested_item="fryer";g._phone_shop_refs["fryer"]={"buy":buy}
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(60,60)
 assert(g._boss_purchase_input_allowed(click))
 click.pressed=false;assert(g._boss_purchase_input_allowed(click))
 click.position=Vector2(400,400);assert(not g._boss_purchase_input_allowed(click))
 click.position=Vector2(60,60);buy.disabled=true;assert(not g._boss_purchase_input_allowed(click))
 var audio=load("res://scripts/game_audio.gd").new()
 assert(is_equal_approx(audio._next_flip_voice_pitch(1000),1.0))
 for i in range(1,20):assert(is_equal_approx(audio._next_flip_voice_pitch(1000+i*500),minf(1.4,1.0+i*.025)))
 assert(is_equal_approx(audio._next_flip_voice_pitch(12000),1.0),"Chain resets after half a second")
 audio.free()
 assert(g._make_cup_stack_prop_material().albedo_color.a>.4)
 print("KITCHEN_INPUT_POLISH_OK: automatic/manual hands, suggested purchase hitbox, pitch chain cap/reset, cup opacity")
 quit()
