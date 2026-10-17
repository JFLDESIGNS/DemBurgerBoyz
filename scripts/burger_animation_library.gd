extends RefCounted
## Shared by Food Flip customers and the embedded Character Editor.
const LIBRARY: AnimationLibrary = preload("res://assets/characters/Animations/Burger27.res")
const NAMES: Array[String] = [
	"Idle_Forward", "Idle_Glance_Left", "Idle_Glance_Right", "Idle_Look_Around",
	"Jump", "Point_Finger_Yell", "Take_Burger_Slow", "Take_Burger_Normal", "Take_Burger_Fast",
	"Walk_Away_Angry", "Put_On_Hat", "Phone_Two_Hands", "Phone_One_Hand", "Check_Watch",
	"Eat_Burger_Slow", "Eat_Burger_Normal", "Eat_Burger_Fast", "Wave_Hello", "Order_From_Menu",
	"Pay_At_Counter", "Burger_Celebration", "Impatient_Foot_Tap", "Wrong_Order_Shrug",
	"Smell_Burger", "Too_Hot_Reaction", "Wipe_Mouth", "Thank_You_Bow",
]
const FAST_TAKE := "Take_Burger_Fast"
const FAST_EAT := "Eat_Burger_Fast"
static var _fitted_library: AnimationLibrary
static var _prop_sphere: SphereMesh
static var _prop_boxes: Dictionary = {}

static func fitted_library() -> AnimationLibrary:
	if _fitted_library != null: return _fitted_library
	_fitted_library = LIBRARY.duplicate(false) as AnimationLibrary
	var service_library: AnimationLibrary=load("res://assets/characters/Animations/CustomerService.res")
	for clip in service_library.get_animation_list(): _fitted_library.add_animation(clip,service_library.get_animation(clip))
	var pet_library: AnimationLibrary=load("res://assets/characters/Animations/CatPet.res")
	for clip in pet_library.get_animation_list(): _fitted_library.add_animation(clip,pet_library.get_animation(clip))
	var hit_library: AnimationLibrary=load("res://assets/characters/Animations/TruckHit.res")
	for clip in hit_library.get_animation_list(): _fitted_library.add_animation(clip,hit_library.get_animation(clip))
	var impatient := LIBRARY.get_animation("Impatient_Foot_Tap").duplicate(true) as Animation
	var idle := LIBRARY.get_animation("Idle_Forward")
	for track in impatient.get_track_count():
		var path := impatient.track_get_path(track)
		var bone := String(path).get_slice(":", 1)
		if bone not in ["LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "Chest", "UpperChest"]: continue
		if impatient.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var reference := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if reference < 0: continue
		var neutral := idle.rotation_track_interpolate(reference, 0.0)
		for key in impatient.track_get_key_count(track):
			var original: Quaternion = impatient.track_get_key_value(track, key)
			impatient.track_set_key_value(track, key, neutral.slerp(original, 0.3))
	_fitted_library.remove_animation("Impatient_Foot_Tap")
	_fitted_library.add_animation("Impatient_Foot_Tap", impatient)
	return _fitted_library

static func attach(player: AnimationPlayer, model: Node) -> Node3D:
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:return null
	var library := fitted_library()
	var path := str(model.get_path_to(skeleton))
	if path != "Root/Skeleton3D":
		library = library.duplicate(true) as AnimationLibrary
		for name in library.get_animation_list():
			var animation := library.get_animation(name)
			for track in animation.get_track_count():
				animation.track_set_path(track,NodePath(str(animation.track_get_path(track)).replace("Root/Skeleton3D",path)))
	player.add_animation_library("burger", library)
	var props := skeleton.get_node_or_null("BurgerMotionProps") as Node3D
	if props != null:return props
	props = Node3D.new()
	props.name = "BurgerMotionProps"
	skeleton.add_child(props)
	for kind in ["burger", "phone", "hat", "watch", "card", "napkin"]:
		var group := Node3D.new()
		group.name = kind
		props.add_child(group)
		group.visible = false
		match kind:
			"burger":
				_oval(group,Vector3(0,0,-.07),Vector3(.29,.27,.08),Color("bf792e"))
				_oval(group,Vector3(0,0,.005),Vector3(.30,.28,.065),Color("50200e"))
				_oval(group,Vector3(0,0,.07),Vector3(.29,.27,.028),Color("c92916"))
				_oval(group,Vector3(0,0,.105),Vector3(.33,.29,.025),Color("63a828"))
				_oval(group,Vector3(0,0,.20),Vector3(.31,.29,.13),Color("bf792e"))
			"phone":
				group.scale = Vector3(1.7, 1.35, 1.55)
				_box(group,Vector3.ZERO,Vector3(.25,.075,.46),Color("162c35"))
				_box(group,Vector3(0,.042,.015),Vector3(.215,.012,.365),Color("4eaeac"))
				for z in [-.06,.02,.10]:_box(group,Vector3(0,.052,z),Vector3(.14,.006,.023),Color.WHITE)
			"hat":
				_oval(group,Vector3(0,0,.16),Vector3(.60,.46,.27),Color("edab28"))
				_oval(group,Vector3(0,-.41,.015),Vector3(.56,.32,.045),Color("edab28"))
			"watch":
				_box(group,Vector3.ZERO,Vector3(.18,.11,.055),Color("162c35"))
				_box(group,Vector3(0,-.005,.035),Vector3(.115,.10,.025),Color("edab28"))
			"card":_box(group,Vector3.ZERO,Vector3(.32,.018,.15),Color("91b984"))
			"napkin":_box(group,Vector3.ZERO,Vector3(.32,.025,.34),Color("f4f0de"))
	props.visible = false
	return props

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .75
	return material

static func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	if not _prop_boxes.has(size):
		var box := BoxMesh.new()
		box.size = size * .01
		_prop_boxes[size] = box
	var mesh: BoxMesh = _prop_boxes[size]
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = position * .01
	item.material_override = _material(color)
	parent.add_child(item)

static func _oval(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	if _prop_sphere == null:
		_prop_sphere = SphereMesh.new()
		_prop_sphere.radius = 1.0
		_prop_sphere.height = 2.0
		_prop_sphere.radial_segments = 20
		_prop_sphere.rings = 10
	var mesh := _prop_sphere
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.scale = size * .01
	item.position = position * .01
	item.material_override = _material(color)
	parent.add_child(item)


static func update_customer_props(player: AnimationPlayer, props: Node3D) -> void:
	if not is_instance_valid(player) or not is_instance_valid(props): return
	var clip := String(player.current_animation).trim_prefix("burger/")
	var kind := "phone" if clip.begins_with("Phone_") or clip == "Grisaldi_Photos" else ("card" if clip in ["Give_Money","Grisaldi_Spin_Throw"] else ("watch" if clip == "Check_Watch" else ""))
	props.visible = kind != ""
	for child in props.get_children(): child.visible = child.name == kind
	if kind == "" or not fitted_library().has_animation(clip): return
	if kind == "card" and player.current_animation_position >= (1.95 if clip == "Grisaldi_Spin_Throw" else .85):
		props.hide();return
	# Apply the authored prop transform explicitly; imported animation mixers can
	# omit non-bone tracks when the model was initialized before its props existed.
	var animation := fitted_library().get_animation(clip)
	var time := player.current_animation_position
	for track in animation.get_track_count():
		if not String(animation.track_get_path(track)).ends_with("/BurgerMotionProps"): continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D: props.position = animation.position_track_interpolate(track, time)
			Animation.TYPE_ROTATION_3D: props.quaternion = animation.rotation_track_interpolate(track, time)
	if kind == "phone":
		var skeleton := props.get_parent() as Skeleton3D
		var chest := skeleton.find_bone("Chest") if skeleton != null else -1
		if chest >= 0:
			var inward := skeleton.to_global(skeleton.get_bone_global_pose(chest).origin) - props.global_position
			inward.y = 0.0
			props.global_position += inward.normalized() * 0.025
