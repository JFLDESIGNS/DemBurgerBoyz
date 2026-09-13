extends SceneTree
const Cat = preload("res://scripts/window_cat.gd")
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(50).timeout.connect(func(): quit(1))
	var stage := Node3D.new();root.add_child(stage);current_scene=stage
	var camera := Camera3D.new();stage.add_child(camera);camera.position=Vector3(1.38,1.18,-1.4);camera.look_at(Vector3(1.38,1.18,1.76));camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.25
	var cat := Cat.new();stage.add_child(cat);cat.set_process(false);cat.special_people_peek(60);cat._apply_visual_scale()
	expect(cat._cat_eyes.size()==2,"Two live pupil surfaces")
	for clip in ["01_Idle","02_Mail_Walk","03_Box_Delivery","04_Happy_Hop"]:expect(cat._anim.has_animation(clip),"Missing clip "+clip)
	expect(cat._visual.find_children("Flying*","",true,false).is_empty(),"No Blender ingredient geometry")
	cat._anim.play("01_Idle");cat._anim.advance(.2)
	expect(is_equal_approx(cat._parcel.scale.x,.8),"Box is 20 percent smaller")
	expect(cat._parcel.position.y<.25,"Box has been lowered")
	cat.update_pupil_target(cat.to_global(Vector3(-2,.5,2)),1)
	var left: Vector2=cat._cat_eyes[0].material_override.get_shader_parameter("pupil_gaze")
	cat.update_pupil_target(cat.to_global(Vector3(2,.5,2)),1)
	var right: Vector2=cat._cat_eyes[0].material_override.get_shader_parameter("pupil_gaze")
	expect(left.x<-.1 and right.x>.1,"Pupils track both horizontal directions")
	cat.request_delivery_peek();cat._update_character(.01);cat._anim.advance(.2);cat._anim.seek(1.2,true)
	expect(cat._parcel.visible and cat._anim.current_animation=="03_Box_Delivery","Delivery selects animated parcel")
	var top=cat._visual.find_child("Box_Front_Flap",true,false)
	var side=cat._visual.find_child("Box_Right_Flap",true,false)
	print("FLAP_POSE ",top.rotation," ",side.rotation," at ",cat._anim.current_animation_position)
	expect(absf(top.rotation.x)>.6 and absf(side.rotation.z)<.05,"Top flaps precede side flaps")
	cat._delivery_anim_left=0;cat._state="peek";cat.pet(true);cat._update_character(.01)
	expect(cat._anim.current_animation=="04_Happy_Hop" and not cat._parcel.visible,"Pet reaction and hidden idle parcel")
	cat._state="running";cat._update_character(.01);expect(cat._anim.current_animation=="02_Mail_Walk","Running uses walk clip")
	expect(load("res://scripts/game.gd")!=null,"Game script parses")
	expect(load("res://scripts/game_audio.gd")!=null,"Audio script parses")
	if DisplayServer.get_name()!="headless":
		var light:=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.5
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("333A40");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;stage.add_child(environment)
		cat.special_people_peek(60);cat._delivery_anim_left=0;cat._happy_anim_left=0;cat._update_character(.01);cat._anim.advance(0)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/runtime_cat.png"))
	print("SHIPPING_CAT_SMOKE_OK" if failures.is_empty() else str(failures));quit(0 if failures.is_empty() else 1)
