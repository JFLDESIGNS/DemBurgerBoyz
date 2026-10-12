extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 var bird=load("res://scripts/park_bird.gd").new();g.add_child(bird);bird.set_process(false);bird.game=g;bird._enter(&"Idle")
 assert(bird.voice.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED)
 assert(is_equal_approx(bird.wing_sound.volume_db,-4+linear_to_db(.8)))
 var camera:=Camera3D.new();g.add_child(camera);camera.position=Vector3(0,.5,2);camera.look_at(bird.bird.global_position+Vector3.UP*.1);camera.make_current()
 var point:=camera.unproject_position(bird.bird.global_position+Vector3.UP*.1)
 assert(bird.tap_at(camera,point));assert(bird.voice.playing);assert(bird.received_chirp==1)
 bird.play_chirp_event(1,1.05);assert(bird.received_chirp==1)
 bird.play_chirp_event(2,1.2);assert(bird.received_chirp==2 and is_equal_approx(bird.voice.pitch_scale,1.2))
 var cat=load("res://scripts/window_cat.gd").new();g.add_child(cat);cat.set_process(false);cat._fat=.8;cat._giant=.3;cat._bob=0
 cat._state="peek";cat._apply_visual_scale();var window_scale:Vector3=cat._visual.scale
 cat._state="background_walk";cat._apply_visual_scale();assert(cat._visual.scale.is_equal_approx(window_scale*g._bg_people_scale()))
 cat._state="background_pounce";cat._apply_visual_scale();assert(cat._visual.scale.is_equal_approx(window_scale*g._bg_people_scale()))
 cat._state="peek";cat._apply_visual_scale();assert(cat._visual.scale.is_equal_approx(window_scale))
 assert(cat._fat==.8 and cat._giant==.3)
 print("BIRD_AUDIO_CAT_SCALE_OK");quit()
