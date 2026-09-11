@tool
class_name ModularCharacterBase
extends Node3D

signal skin_color_changed(color: Color)
signal modules_changed

enum NoseStyle { NONE, BUTTON, POINT }
enum MouthStyle { SMILE, FLAT, OPEN }
enum BrowStyle { NONE, STRAIGHT, ARCHED, ANGRY, WORRIED }
enum LashStyle { ALMOND, ALMOND_RIM, CLASSIC, NONE }
enum CheekStyle { NONE, ROSY_RADIAL }
enum HairStyle { NONE, SIMPLE_PARTED, BUZZED, LONG, BUNS, LOWPOLY_MALE, LOWPOLY_SHORT_1, LOWPOLY_PONYTAIL, LOWPOLY_SHORT_2, CAP_WITH_HAIR, CAPSULE_FEMALE, CAPSULE_MALE }
enum FacialHairStyle { NONE, FULL_BEARD, MOUSTACHE, SHORT_BEARD, QUATERNIUS_BEARD }
enum HatStyle { NONE, RANGER_HOOD, ROUND_HOOD, TOP_HAT, BASEBALL_CAP, LOWPOLY_CAP, LOWPOLY_CAP_HAIR, LOWPOLY_ROUND_HAT, CAPSULE_CAP }
enum TopStyle { NONE, T_SHIRT, TANK_TOP, LONG_SLEEVE, CROP_TOP, BLOUSE, POLO, HOODIE, SWEATER, OFF_SHOULDER, DRESS_BODICE, CARDIGAN }
enum BottomStyle { NONE, PANTS, SHORTS, CAPRIS, LEGGINGS, MINI_SKIRT, LONG_SKIRT, PLEATED_SKIRT }
enum ShoeStyle { NONE, SNEAKERS, ANKLE_BOOTS, HIGH_TOPS, LOAFERS, SANDALS }
enum ShirtGraphic { NONE, SKULL, HEART, STAR, LIGHTNING, FLAME, FLOWER, CAT, MOON, BURGER, CROWN }
enum MakeupStyle { NONE, EYE_SHADOW, WINGED_LINER, BEAUTY_MARK, GLAM }
enum JewelryStyle { NONE, STUDS, HOOPS, DROP_EARRINGS, CHOKER }
enum GlassesStyle { NONE, SPORT, CLASSIC, CAT_EYE, ROUND, SHUTTER, AVIATOR, PIXEL, RETRO_ROUND, SLIM, WAYFARER }
enum PreviewAnimation { WAVE, WALK_IN_PLACE, CELEBRATE }

const HAIR_SCENES: Array = [
	null,
	preload("res://assets/characters/modular_runtime/modules/hair/Hair_SimpleParted.gltf"),
	preload("res://assets/characters/modular_runtime/modules/hair/Hair_Buzzed.gltf"),
	preload("res://assets/characters/modular_runtime/modules/hair/Hair_Long.gltf"),
	preload("res://assets/characters/modular_runtime/modules/hair/Hair_Buns.gltf"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Male_Hair.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Short_Hair_1.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Ponytail.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Short_Hair_2.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Cap_Hair.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Capsule_Female_Hair.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Capsule_Male_Hair.tscn"),
]
const FACIAL_HAIR_SCENES: Array = [
	null,
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Full_Beard.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Moustache.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Lowpoly_Beard.tscn"),
	preload("res://assets/characters/modular_runtime/modules/hair/Quaternius_Beard.tscn"),
]

static func migrate_legacy_hair_fields(data: Dictionary) -> void:
	if data.has("facial_hair_style"):
		return
	var old_style: int = int(data.get("hair_style", 0))
	var hair: int = clampi(old_style, 0, 8)
	var face: int = 0
	match old_style:
		9:
			hair = 0
			face = 1
		10:
			hair = 0
			face = 2
		11:
			hair = 0
			face = 3
		12:
			hair = 9
		13:
			hair = 10
		14:
			hair = 11
		15:
			hair = 0
			face = 4
	data["hair_style"] = hair
	data["facial_hair_style"] = face
	if not data.has("facial_hair_color"):
		data["facial_hair_color"] = data.get("hair_color", "35231dff")
	if not data.has("facial_hair_scale"):
		data["facial_hair_scale"] = data.get("hair_scale", 1.3) if face != 0 else 1.0
	if not data.has("facial_hair_offset"):
		if face != 0:
			data["facial_hair_offset"] = data.get("hair_offset", [0.0, 0.0, 0.0])
			data["hair_offset"] = [0.0, 0.3, 0.0]
			data["hair_scale"] = 1.3
		else:
			data["facial_hair_offset"] = [0.0, 0.0, 0.0]

const HAT_SCENES: Array = [
	null,
	preload("res://assets/characters/modular_runtime/modules/headwear/Male_Ranger_Head_Hood.gltf"),
	preload("res://assets/characters/modular_runtime/modules/headwear/Female_Ranger_Head_Hood.gltf"),
	null,
	null,
	preload("res://assets/characters/modular_runtime/modules/headwear/Lowpoly_Cap.tscn"),
	preload("res://assets/characters/modular_runtime/modules/headwear/Lowpoly_Cap_With_Hair.tscn"),
	preload("res://assets/characters/modular_runtime/modules/headwear/Lowpoly_Round_Hat.tscn"),
	preload("res://assets/characters/modular_runtime/modules/headwear/Capsule_Cap.tscn"),
]
const SHIRT_GRAPHICS: Array[Texture2D] = [
	null,
	preload("res://assets/characters/modular_runtime/modules/graphics/skull.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/heart.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/star.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/lightning.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/flame.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/flower.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/cat.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/moon.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/burger.svg"),
	preload("res://assets/characters/modular_runtime/modules/graphics/crown.svg"),
]
const GLASSES_SCENES: Array = [
	null,
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses1.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses2.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses3.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses4.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses5.003.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses8.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses11.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses14.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses20.001.fbx"),
	preload("res://assets/characters/modular_runtime/sourced/glasses/glasses29.001.fbx"),
]
const CONTROL_RIG_SPECS := {
	"left_hand": {"root": "LeftArm", "mid": "LeftForeArm", "tip": "LeftHand", "min_bend": 4.0, "max_bend": 138.0, "pole": "left_elbow", "color": Color("35d7ff")},
	"right_hand": {"root": "RightArm", "mid": "RightForeArm", "tip": "RightHand", "min_bend": 4.0, "max_bend": 138.0, "pole": "right_elbow", "color": Color("ff4fc8")},
	"left_foot": {"root": "LeftUpLeg", "mid": "LeftLeg", "tip": "LeftFoot", "min_bend": 6.0, "max_bend": 125.0, "pole": "left_knee", "color": Color("ffd84a")},
	"right_foot": {"root": "RightUpLeg", "mid": "RightLeg", "tip": "RightFoot", "min_bend": 6.0, "max_bend": 125.0, "pole": "right_knee", "color": Color("ff833d")},
}
const CONTROL_POLE_SPECS := {
	"left_elbow": {"chain": "left_hand", "bone": "LeftForeArm", "fallback": Vector3(0.0, 0.0, 0.38), "color": Color("78e8ff")},
	"right_elbow": {"chain": "right_hand", "bone": "RightForeArm", "fallback": Vector3(0.0, 0.0, 0.38), "color": Color("ff85da")},
	"left_knee": {"chain": "left_foot", "bone": "LeftLeg", "fallback": Vector3(0.0, 0.0, 0.44), "color": Color("fff080")},
	"right_knee": {"chain": "right_foot", "bone": "RightLeg", "fallback": Vector3(0.0, 0.0, 0.44), "color": Color("ffad72")},
}
const CONTROL_BODY_SPECS := {
	"waist": {"bone": "Hips", "mode": "translate", "color": Color("8dff8a")},
	"torso": {"bone": "Chest", "mode": "rotate", "color": Color("65ffa9")}, "neck": {"bone": "Neck", "mode": "rotate", "color": Color("a4ffdf")},
	"head": {"bone": "Head", "mode": "rotate", "color": Color("ffffff")},
	"left_shoulder": {"bone": "LeftArm", "mode": "rotate", "color": Color("62bfff")}, "right_shoulder": {"bone": "RightArm", "mode": "rotate", "color": Color("ff74bd")},
	"left_hip": {"bone": "LeftUpLeg", "mode": "rotate", "color": Color("a5ff66")}, "right_hip": {"bone": "RightUpLeg", "mode": "rotate", "color": Color("d5ff66")},
	"left_ankle": {"bone": "LeftFoot", "mode": "rotate", "color": Color("ffd966")}, "right_ankle": {"bone": "RightFoot", "mode": "rotate", "color": Color("ffad66")},
	"left_toes": {"bone": "LeftToes", "mode": "rotate", "color": Color("fff2a8")}, "right_toes": {"bone": "RightToes", "mode": "rotate", "color": Color("ffd0a8")},
}

@export var skin_color := Color("d88b5f"):
	set(value):
		skin_color = value
		if _should_rebuild():
			_apply_skin_material()
			skin_color_changed.emit(skin_color)

@export_range(0.4, 2.0, 0.05) var eye_width := 1.0:
	set(value):
		eye_width = value
		if _should_rebuild():
			_build_eyes()
			_build_eyebrows()
			_build_lashes()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var eye_height := 0.6:
	set(value):
		eye_height = value
		if _should_rebuild():
			_build_eyes()
			_build_eyebrows()
			_build_lashes()
			modules_changed.emit()

@export_range(-0.12, 0.14, 0.01) var eye_vertical := -0.04:
	set(value):
		eye_vertical = value
		if _should_rebuild():
			_build_eyes()
			_build_eyebrows()
			_build_lashes()
			modules_changed.emit()

@export_range(0.45, 1.8, 0.05) var eye_spacing := 1.0:
	set(value):
		eye_spacing = value
		if _should_rebuild():
			_build_eyes()
			_build_eyebrows()
			_build_lashes()
			modules_changed.emit()

@export_range(-0.35, 0.25, 0.01) var eye_depth := -0.18:
	set(value):
		eye_depth = value
		if _should_rebuild():
			_build_eyes()
			_build_eyebrows()
			_build_lashes()
			modules_changed.emit()

@export_range(0.12, 0.92, 0.01) var eye_pupil_size := 0.64:
	set(value):
		eye_pupil_size = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.55, 0.55, 0.01) var eye_pupil_inward := 0.22:
	set(value):
		eye_pupil_inward = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.15, 1.0, 0.01) var eye_sclera_brightness := 1.0:
	set(value):
		eye_sclera_brightness = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.8, 0.8, 0.01) var left_eye_yaw := -0.6:
	set(value):
		left_eye_yaw = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.8, 0.8, 0.01) var right_eye_yaw := 0.6:
	set(value):
		right_eye_yaw = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.3, 2.0, 0.05) var eye_specular_scale := 0.75:
	set(value):
		eye_specular_scale = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.08, 0.08, 0.005) var eye_specular_horizontal := -0.025:
	set(value):
		eye_specular_horizontal = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.10, 0.10, 0.005) var eye_specular_vertical := 0.04:
	set(value):
		eye_specular_vertical = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.05, 0.08, 0.005) var eye_specular_depth := 0.0:
	set(value):
		eye_specular_depth = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export var eyelid_enabled := true:
	set(value):
		eyelid_enabled = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.5, 2.2, 0.01) var eyelid_scale := 1.0:
	set(value):
		eyelid_scale = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.01) var eyelid_width := 1.0:
	set(value):
		eyelid_width = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.01) var eyelid_height := 1.0:
	set(value):
		eyelid_height = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.01) var eyelid_depth := 1.0:
	set(value):
		eyelid_depth = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.12, 0.12, 0.005) var eyelid_vertical := 0.0:
	set(value):
		eyelid_vertical = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(-0.12, 0.12, 0.005) var eyelid_forward := 0.0:
	set(value):
		eyelid_forward = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export_range(0.0, 1.0, 0.01) var eyelid_mask_height := 0.42:
	set(value):
		eyelid_mask_height = value
		if _should_rebuild():
			_apply_eyelid_materials()
			modules_changed.emit()

@export_range(0.0, 1.5, 0.01) var eyelid_mask_width := 0.88:
	set(value):
		eyelid_mask_width = value
		if _should_rebuild():
			_apply_eyelid_materials()
			modules_changed.emit()

@export var lash_style: LashStyle = LashStyle.NONE:
	set(value):
		lash_style = value
		if _should_rebuild():
			_build_eyes()
			modules_changed.emit()

@export var lash_color := Color("241817"):
	set(value):
		lash_color = value
		if _should_rebuild():
			_apply_eyelid_materials()
			modules_changed.emit()

@export_range(0.01, 0.36, 0.005) var lash_rim_width := 0.035:
	set(value):
		lash_rim_width = value
		if _should_rebuild():
			_apply_eyelid_materials()
			modules_changed.emit()

@export var cheek_style: CheekStyle = CheekStyle.NONE:
	set(value):
		cheek_style = value
		if _should_rebuild():
			_build_cheeks()
			modules_changed.emit()

@export var cheek_color := Color(0.95, 0.12, 0.18, 0.72):
	set(value):
		cheek_color = value
		if _should_rebuild(): _build_cheeks()

@export_range(0.4, 2.0, 0.05) var cheek_scale := 1.0:
	set(value):
		cheek_scale = value
		if _should_rebuild(): _build_cheeks()

@export_range(0.4, 2.0, 0.05) var cheek_width := 1.0:
	set(value):
		cheek_width = value
		if _should_rebuild(): _build_cheeks()

@export_range(0.4, 2.0, 0.05) var cheek_height := 1.0:
	set(value):
		cheek_height = value
		if _should_rebuild(): _build_cheeks()

@export_range(-0.18, 0.18, 0.01) var cheek_vertical := 0.0:
	set(value):
		cheek_vertical = value
		if _should_rebuild(): _build_cheeks()

@export_range(0.5, 1.8, 0.05) var cheek_spacing := 1.0:
	set(value):
		cheek_spacing = value
		if _should_rebuild(): _build_cheeks()

@export_range(-0.50, 0.35, 0.01) var cheek_depth := 0.0:
	set(value):
		cheek_depth = value
		if _should_rebuild(): _build_cheeks()

@export var brow_style: BrowStyle = BrowStyle.STRAIGHT:
	set(value):
		brow_style = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export var brow_color := Color("35231d"):
	set(value):
		brow_color = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(0.5, 2.0, 0.05) var brow_scale := 1.0:
	set(value):
		brow_scale = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(0.5, 2.0, 0.05) var brow_width := 1.0:
	set(value):
		brow_width = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(0.5, 2.0, 0.05) var brow_height := 1.0:
	set(value):
		brow_height = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(-0.12, 0.14, 0.01) var brow_vertical := -0.02:
	set(value):
		brow_vertical = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(0.6, 1.6, 0.05) var brow_spacing := 1.0:
	set(value):
		brow_spacing = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(-0.10, 0.10, 0.005) var brow_depth := -0.03:
	set(value):
		brow_depth = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(-0.8, 0.8, 0.01) var left_brow_yaw := -0.72:
	set(value):
		left_brow_yaw = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export_range(-0.8, 0.8, 0.01) var right_brow_yaw := 0.67:
	set(value):
		right_brow_yaw = value
		if _should_rebuild():
			_build_eyebrows()
			modules_changed.emit()

@export var nose_color := Color("e84242"):
	set(value):
		nose_color = value
		if _should_rebuild():
			_build_nose()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var nose_width := 1.0:
	set(value):
		nose_width = value
		if _should_rebuild():
			_build_nose()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var nose_height := 1.0:
	set(value):
		nose_height = value
		if _should_rebuild():
			_build_nose()
			modules_changed.emit()

@export_range(-0.35, 0.25, 0.01) var nose_depth := -0.14:
	set(value):
		nose_depth = value
		if _should_rebuild():
			_build_nose()
			modules_changed.emit()

@export_range(-0.18, 0.18, 0.01) var nose_vertical := 0.04:
	set(value):
		nose_vertical = value
		if _should_rebuild():
			_build_nose()
			modules_changed.emit()

@export var nose_style: NoseStyle = NoseStyle.BUTTON:
	set(value):
		nose_style = value
		if _should_rebuild():
			_build_nose()
		modules_changed.emit()

@export var mouth_style: MouthStyle = MouthStyle.SMILE:
	set(value):
		mouth_style = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export var mouth_color := Color("791f26"):
	set(value):
		mouth_color = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var mouth_width := 0.7:
	set(value):
		mouth_width = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var mouth_height := 0.45:
	set(value):
		mouth_height = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(-0.35, 0.25, 0.01) var mouth_depth := -0.12:
	set(value):
		mouth_depth = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(-0.18, 0.18, 0.01) var mouth_vertical := 0.05:
	set(value):
		mouth_vertical = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.0, 0.45, 0.01) var mouth_curve := 0.10:
	set(value):
		mouth_curve = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export var mouth_shadow_color := Color(0.02, 0.01, 0.02, 0.82):
	set(value):
		mouth_shadow_color = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.0, 1.0, 0.01) var mouth_shadow_size := 0.20:
	set(value):
		mouth_shadow_size = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(-0.40, 0.60, 0.01) var mouth_shadow_position := 0.0:
	set(value):
		mouth_shadow_position = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.0, 0.45, 0.01) var mouth_shadow_softness := 0.10:
	set(value):
		mouth_shadow_softness = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export_range(0.15, 1.0, 0.01) var mouth_shadow_width := 1.0:
	set(value):
		mouth_shadow_width = value
		if _should_rebuild():
			_build_mouth()
			modules_changed.emit()

@export var ear_color := Color("d88b5f"):
	set(value):
		ear_color = value
		if _should_rebuild():
			_build_ears()
			modules_changed.emit()

@export_range(0.4, 2.0, 0.05) var ear_scale := 1.0:
	set(value):
		ear_scale = value
		if _should_rebuild():
			_build_ears()
			modules_changed.emit()

@export_range(0.6, 1.8, 0.05) var ear_spacing := 1.0:
	set(value):
		ear_spacing = value
		if _should_rebuild():
			_build_ears()
			modules_changed.emit()

@export_range(-0.35, 0.25, 0.01) var ear_depth := 0.0:
	set(value):
		ear_depth = value
		if _should_rebuild():
			_build_ears()
			modules_changed.emit()

@export var hair_style: HairStyle = HairStyle.NONE:
	set(value):
		hair_style = value
		if _should_rebuild():
			_build_hair()
		modules_changed.emit()

@export var hat_style: HatStyle = HatStyle.NONE:
	set(value):
		hat_style = value
		if _should_rebuild():
			_build_hat()
		modules_changed.emit()

@export var hair_color := Color("35231d"):
	set(value):
		hair_color = value
		if _should_rebuild():
			_build_hair()
			modules_changed.emit()

@export_range(0.3, 3.0, 0.05) var hair_scale := 1.3:
	set(value):
		hair_scale = value
		if _should_rebuild():
			_build_hair()
			modules_changed.emit()

@export var hair_scale_xyz := Vector3.ONE:
	set(value):
		hair_scale_xyz = Vector3(clampf(value.x, 0.3, 3.0), clampf(value.y, 0.3, 3.0), clampf(value.z, 0.3, 3.0))
		if _should_rebuild():
			_build_hair()
			modules_changed.emit()

@export var hair_offset := Vector3(0.0, 0.3, 0.0):
	set(value):
		hair_offset = value
		if _should_rebuild():
			_build_hair()
			modules_changed.emit()

const MAX_EXTRA_HAIRS := 5
## Extra stacked hair pieces. Each dict: style, color, scale, scale_xyz, offset.
var extra_hairs: Array = []:
	set(value):
		extra_hairs = _normalize_extra_hairs(value)
		if _should_rebuild():
			_build_hair()
			modules_changed.emit()

@export var facial_hair_style: FacialHairStyle = FacialHairStyle.NONE:
	set(value):
		facial_hair_style = value
		if _should_rebuild():
			_build_facial_hair()
		modules_changed.emit()

@export var facial_hair_color := Color("35231d"):
	set(value):
		facial_hair_color = value
		if _should_rebuild():
			_build_facial_hair()
			modules_changed.emit()

@export_range(0.3, 3.0, 0.05) var facial_hair_scale := 1.0:
	set(value):
		facial_hair_scale = value
		if _should_rebuild():
			_build_facial_hair()
			modules_changed.emit()

@export var facial_hair_scale_xyz := Vector3.ONE:
	set(value):
		facial_hair_scale_xyz = Vector3(clampf(value.x, 0.3, 3.0), clampf(value.y, 0.3, 3.0), clampf(value.z, 0.3, 3.0))
		if _should_rebuild():
			_build_facial_hair()
			modules_changed.emit()

@export var facial_hair_offset := Vector3.ZERO:
	set(value):
		facial_hair_offset = value
		if _should_rebuild():
			_build_facial_hair()
			modules_changed.emit()

@export var hat_color := Color("d94b3d"):
	set(value):
		hat_color = value
		if _should_rebuild():
			_build_hat()
			modules_changed.emit()

@export_range(0.5, 2.0, 0.05) var hat_scale := 1.0:
	set(value):
		hat_scale = value
		if _should_rebuild():
			_build_hat()
			modules_changed.emit()

@export var hat_offset := Vector3.ZERO:
	set(value):
		hat_offset = value
		if _should_rebuild():
			_build_hat()
			modules_changed.emit()

@export var hat_rotation := Vector3.ZERO:
	set(value):
		hat_rotation = value
		if _should_rebuild(): _build_hat()

@export var glasses_style: GlassesStyle = GlassesStyle.NONE:
	set(value):
		glasses_style = value
		if _should_rebuild(): _build_glasses()

@export var glasses_color := Color("20242b"):
	set(value):
		glasses_color = value
		if _should_rebuild(): _build_glasses()

@export_range(0.5, 2.0, 0.05) var glasses_scale := 1.0:
	set(value):
		glasses_scale = value
		if _should_rebuild(): _build_glasses()

@export var glasses_offset := Vector3(0.0, 0.28, 0.43):
	set(value):
		glasses_offset = value
		if _should_rebuild(): _build_glasses()

@export var makeup_style: MakeupStyle = MakeupStyle.NONE:
	set(value):
		makeup_style = value
		if _should_rebuild(): _build_makeup()

@export var makeup_color := Color(0.55, 0.18, 0.45, 0.72):
	set(value):
		makeup_color = value
		if _should_rebuild(): _build_makeup()

@export_range(0.5, 2.0, 0.05) var makeup_scale := 1.0:
	set(value):
		makeup_scale = value
		if _should_rebuild(): _build_makeup()

@export var makeup_offset := Vector3.ZERO:
	set(value):
		makeup_offset = value
		if _should_rebuild(): _build_makeup()

@export var jewelry_style: JewelryStyle = JewelryStyle.NONE:
	set(value):
		jewelry_style = value
		if _should_rebuild(): _build_jewelry()

@export var jewelry_color := Color("e8c84d"):
	set(value):
		jewelry_color = value
		if _should_rebuild(): _build_jewelry()

@export_range(0.5, 2.0, 0.05) var jewelry_scale := 1.0:
	set(value):
		jewelry_scale = value
		if _should_rebuild(): _build_jewelry()

@export var jewelry_offset := Vector3.ZERO:
	set(value):
		jewelry_offset = value
		if _should_rebuild(): _build_jewelry()

@export var top_style: TopStyle = TopStyle.T_SHIRT:
	set(value):
		top_style = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export var top_color := Color("3f6a45"):
	set(value):
		top_color = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export_range(0.9, 1.12, 0.01) var top_scale := 1.0:
	set(value):
		top_scale = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export var shirt_graphic: ShirtGraphic = ShirtGraphic.NONE:
	set(value):
		shirt_graphic = value
		if _should_rebuild():
			_build_shirt_graphic()
			modules_changed.emit()

@export var shirt_graphic_color := Color.WHITE:
	set(value):
		shirt_graphic_color = value
		if _should_rebuild(): _build_shirt_graphic()

@export_range(0.4, 2.0, 0.05) var shirt_graphic_scale := 1.0:
	set(value):
		shirt_graphic_scale = value
		if _should_rebuild(): _build_shirt_graphic()

@export_range(-0.18, 0.18, 0.01) var shirt_graphic_horizontal := 0.0:
	set(value):
		shirt_graphic_horizontal = value
		if _should_rebuild(): _build_shirt_graphic()

@export_range(-0.40, 0.80, 0.01) var shirt_graphic_vertical := 0.0:
	set(value):
		shirt_graphic_vertical = value
		if _should_rebuild(): _build_shirt_graphic()

@export_range(-0.40, 0.30, 0.005) var shirt_graphic_depth := 0.0:
	set(value):
		shirt_graphic_depth = value
		if _should_rebuild(): _build_shirt_graphic()

@export var bottom_style: BottomStyle = BottomStyle.SHORTS:
	set(value):
		bottom_style = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export var bottom_color := Color("334e68"):
	set(value):
		bottom_color = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export_range(0.9, 1.12, 0.01) var bottom_scale := 1.0:
	set(value):
		bottom_scale = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export var shoe_style: ShoeStyle = ShoeStyle.NONE:
	set(value):
		shoe_style = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export var shoe_color := Color("6b3f2a"):
	set(value):
		shoe_color = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@export_range(0.9, 1.2, 0.01) var shoe_scale := 1.03:
	set(value):
		shoe_scale = value
		if _should_rebuild():
			_build_clothing()
			modules_changed.emit()

@onready var toon_body: Node3D = $Body
@onready var _clothing_root: Node3D = $Modules/Clothes
## Texture resolution controls tattoo detail; mesh subdivision does not improve UV paint.
## 1024 keeps one RGBA canvas lightweight while providing 4x the texel count of 512.
const SKIN_PAINT_SIZE := 1024

var _skin_material: ShaderMaterial
var _skin_paint_image: Image
var _skin_paint_texture: ImageTexture
var _skin_paint_dirty := false
var _skin_paint_has_marks := false
var _skin_paint_unlit_preview := false
var _skin_paint_needs_mark_scan := false
var _skin_uv_guide_lines := PackedVector2Array()
var _clothes_hidden_for_paint := false
var _head_attachment: BoneAttachment3D
var _eyes_root: Node3D
var _lashes_root: Node3D
var _cheeks_root: Node3D
var _eyebrows_root: Node3D
var _nose_root: Node3D
var _mouth_root: Node3D
var _ears_root: Node3D
var _hair_root: Node3D
var _facial_hair_root: Node3D
var _hat_root: Node3D
var _glasses_root: Node3D
var _makeup_root: Node3D
var _jewelry_root: Node3D
var _shirt_graphic_attachment: BoneAttachment3D
var _shirt_graphic_root: Node3D
var _unit := 0.01
var _preview_playing := false
var _preview_animation: PreviewAnimation = PreviewAnimation.WAVE
var _preview_time := 0.0
var _preview_bone_indices: Dictionary[String, int] = {}
var _preview_base_rotations: Dictionary[int, Quaternion] = {}
var _preview_base_positions: Dictionary[int, Vector3] = {}
var _control_rig_root: Node3D
var _rig_targets: Dictionary = {}
var _rig_target_defaults: Dictionary = {}
var _rig_lines: Dictionary = {}
var _ik_nodes: Dictionary = {}
var _rig_poles: Dictionary = {}
var _body_targets: Dictionary = {}
var _body_target_defaults: Dictionary = {}
var _body_bone_base_positions: Dictionary = {}
var _active_ik_chains: Dictionary = {}
var _active_rig_target := ""
var _drag_plane := Plane()
var _rig_drag_last_point := Vector3.ZERO
var _control_rig_visible := true
var _body_rotations: Dictionary = {}
var _pose_controls: Dictionary[String, float] = {
	"head_nod": 0.0,
	"head_yaw": 0.0,
	"head_tilt": 0.0,
	"spine_lean": 0.0,
	"spine_twist": 0.0,
	"left_arm_raise": 0.0,
	"right_arm_raise": 0.0,
	"left_arm_forward": 0.0,
	"right_arm_forward": 0.0,
	"left_elbow_bend": 0.0,
	"right_elbow_bend": 0.0,
	"left_leg_forward": 0.0,
	"right_leg_forward": 0.0,
	"left_knee_bend": 0.0,
	"right_knee_bend": 0.0,
}
static var _garment_mesh_cache: Dictionary = {}
var _rebuild_suspended := false
@export var defer_initial_appearance := false


func _ready() -> void:
	_apply_skin_material()
	_create_head_modules()
	if not defer_initial_appearance:
		_rebuild_all_appearance()
	_cache_preview_pose()
	_create_control_rig_v2()


func begin_appearance_batch() -> void:
	_rebuild_suspended = true


func end_appearance_batch() -> void:
	if not _rebuild_suspended:
		return
	_rebuild_suspended = false
	if is_node_ready():
		_rebuild_all_appearance()
		modules_changed.emit()


func _should_rebuild() -> bool:
	return is_node_ready() and not _rebuild_suspended


func _rebuild_all_appearance() -> void:
	_apply_skin_material()
	_build_eyes()
	_build_lashes()
	_build_cheeks()
	_build_eyebrows()
	_build_nose()
	_build_mouth()
	_build_ears()
	_build_hair()
	_build_facial_hair()
	_build_hat()
	_build_glasses()
	_build_makeup()
	_build_jewelry()
	_build_clothing()


func rebuild_appearance() -> void:
	if is_node_ready():
		_rebuild_all_appearance()
		modules_changed.emit()


func feature_world_position(feature_id: String) -> Vector3:
	var skeleton := get_active_skeleton()
	if skeleton == null:
		return global_position
	match feature_id:
		"hair":
			return _safe_bone_world(skeleton, "Head") + Vector3(0.0, 0.16, 0.05)
		"eyes":
			if _eyes_root != null:
				return _eyes_root.global_position + Vector3(0.0, 0.0, 0.05)
			return _safe_bone_world(skeleton, "Head") + Vector3(0.0, 0.06, 0.12)
		"mouth":
			if _mouth_root != null:
				return _mouth_root.global_position + Vector3(0.0, -0.03, 0.06)
			return _safe_bone_world(skeleton, "Head") + Vector3(0.0, -0.05, 0.12)
		"shirt":
			return _safe_bone_world(skeleton, "Chest")
		"pants":
			return _safe_bone_world(skeleton, "Hips").lerp(_safe_bone_world(skeleton, "LeftUpLeg"), 0.55)
		"shoes":
			return (_safe_bone_world(skeleton, "LeftFoot") + _safe_bone_world(skeleton, "RightFoot")) * 0.5
	return global_position


func _safe_bone_world(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index < 0:
		return global_position
	return _bone_world_position(bone_index)


func _process(delta: float) -> void:
	if _preview_playing:
		_preview_time += delta
		_apply_preview_pose()
	else:
		_update_control_rig_lines()


func set_skin_tone(color: Color) -> void:
	skin_color = color


func start_preview_animation(animation_index: int) -> void:
	_set_ik_enabled(false)
	_preview_playing = false
	_restore_base_pose()
	_preview_animation = clampi(animation_index, 0, PreviewAnimation.size() - 1) as PreviewAnimation
	_preview_time = 0.0
	_preview_playing = true
	_apply_preview_pose()


func stop_preview_animation() -> void:
	_preview_playing = false
	_apply_manual_pose()
	_sync_rig_targets_from_pose()
	_set_ik_enabled(true)


func is_preview_animation_playing() -> bool:
	return _preview_playing


func _cache_preview_pose() -> void:
	var skeleton := get_active_skeleton()
	if skeleton == null:
		return
	for bone_name in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			_preview_bone_indices[bone_name] = bone_index
			_preview_base_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)
			_preview_base_positions[bone_index] = skeleton.get_bone_pose_position(bone_index)
	_apply_manual_pose()


func _apply_preview_pose() -> void:
	_restore_base_pose()
	var phase := sin(_preview_time * 4.0)
	match _preview_animation:
		PreviewAnimation.WAVE:
			_pose_rotate("RightArm", Vector3(0.0, 0.0, -58.0))
			_pose_rotate("RightForeArm", Vector3(0.0, 48.0 + phase * 24.0, 0.0))
			_pose_rotate("Spine", Vector3(0.0, phase * 3.0, 0.0))
		PreviewAnimation.WALK_IN_PLACE:
			_pose_rotate("LeftUpLeg", Vector3(phase * 25.0, 0.0, 0.0))
			_pose_rotate("RightUpLeg", Vector3(-phase * 25.0, 0.0, 0.0))
			_pose_rotate("LeftLeg", Vector3(maxf(0.0, -phase) * 32.0, 0.0, 0.0))
			_pose_rotate("RightLeg", Vector3(maxf(0.0, phase) * 32.0, 0.0, 0.0))
			_pose_rotate("LeftArm", Vector3(0.0, phase * 20.0, 0.0))
			_pose_rotate("RightArm", Vector3(0.0, phase * 20.0, 0.0))
			_preview_move("Hips", Vector3(0.0, absf(phase) * 0.00045, 0.0))
		PreviewAnimation.CELEBRATE:
			_pose_rotate("LeftArm", Vector3(0.0, 0.0, 62.0 + phase * 7.0))
			_pose_rotate("RightArm", Vector3(0.0, 0.0, -62.0 - phase * 7.0))
			_pose_rotate("LeftForeArm", Vector3(0.0, -28.0 - phase * 10.0, 0.0))
			_pose_rotate("RightForeArm", Vector3(0.0, 28.0 + phase * 10.0, 0.0))
			_preview_move("Hips", Vector3(0.0, absf(phase) * 0.0007, 0.0))


func _restore_base_pose() -> void:
	var skeleton := get_active_skeleton()
	if skeleton == null:
		return
	for bone_name in _preview_bone_indices:
		var bone_index := _preview_bone_indices[bone_name]
		skeleton.set_bone_pose_rotation(bone_index, _preview_base_rotations[bone_index])
		skeleton.set_bone_pose_position(bone_index, _preview_base_positions[bone_index])


func _pose_rotate(bone_name: String, euler_degrees: Vector3) -> void:
	if not _preview_bone_indices.has(bone_name):
		return
	var skeleton := get_active_skeleton()
	var bone_index := _preview_bone_indices[bone_name]
	var radians := Vector3(deg_to_rad(euler_degrees.x), deg_to_rad(euler_degrees.y), deg_to_rad(euler_degrees.z))
	var visual_delta := Basis.from_euler(radians)
	var skeleton_basis := skeleton.global_transform.basis.orthonormalized()
	var skeleton_delta := skeleton_basis.inverse() * visual_delta * skeleton_basis
	var parent_index := skeleton.get_bone_parent(bone_index)
	var parent_basis := Basis.IDENTITY
	if parent_index >= 0:
		parent_basis = skeleton.get_bone_global_rest(parent_index).basis.orthonormalized()
	var local_delta := parent_basis.inverse() * skeleton_delta * parent_basis
	skeleton.set_bone_pose_rotation(bone_index, local_delta.get_rotation_quaternion() * _preview_base_rotations[bone_index])


func _pose_rotate_local_hinge(bone_name: String, angle_degrees: float) -> void:
	if not _preview_bone_indices.has(bone_name):
		return
	var skeleton := get_active_skeleton()
	var bone_index := _preview_bone_indices[bone_name]
	var hinge_axis := Vector3.RIGHT
	if bone_name == "LeftLeg":
		hinge_axis = Vector3(1.0, 0.0, 0.38).normalized()
	elif bone_name == "RightLeg":
		hinge_axis = Vector3(1.0, 0.0, -0.38).normalized()
	var hinge := Quaternion(hinge_axis, deg_to_rad(angle_degrees))
	skeleton.set_bone_pose_rotation(bone_index, _preview_base_rotations[bone_index] * hinge)


func _preview_move(bone_name: String, offset: Vector3) -> void:
	if not _preview_bone_indices.has(bone_name):
		return
	var skeleton := get_active_skeleton()
	var bone_index := _preview_bone_indices[bone_name]
	skeleton.set_bone_pose_position(bone_index, _preview_base_positions[bone_index] + offset)


func set_pose_control(control_name: String, value: float) -> void:
	if not _pose_controls.has(control_name):
		return
	_set_ik_enabled(false)
	_pose_controls[control_name] = value
	_preview_playing = false
	_apply_manual_pose()
	_sync_rig_targets_from_pose()
	_set_ik_enabled(true)


func get_pose_control(control_name: String) -> float:
	return _pose_controls.get(control_name, 0.0)


func get_pose_controls() -> Dictionary[String, float]:
	return _pose_controls.duplicate()


func load_pose_controls(values: Variant) -> void:
	_set_ik_enabled(false)
	if values is Dictionary:
		for key in _pose_controls:
			_pose_controls[key] = float(values.get(key, 0.0))
	_preview_playing = false
	_apply_manual_pose()
	_sync_rig_targets_from_pose()
	_set_ik_enabled(true)


func reset_pose_controls() -> void:
	_set_ik_enabled(false)
	for key in _pose_controls:
		_pose_controls[key] = 0.0
	_preview_playing = false
	_apply_manual_pose()
	_reset_control_rig_targets()
	_set_ik_enabled(true)


func _apply_manual_pose() -> void:
	if _preview_bone_indices.is_empty():
		return
	_restore_base_pose()
	_pose_rotate("Head", Vector3(_pose_controls.head_nod, _pose_controls.head_yaw, _pose_controls.head_tilt))
	_pose_rotate("Spine", Vector3(_pose_controls.spine_lean, _pose_controls.spine_twist, 0.0))
	_pose_rotate("LeftArm", Vector3(0.0, -_pose_controls.left_arm_forward, _pose_controls.left_arm_raise))
	_pose_rotate("RightArm", Vector3(0.0, _pose_controls.right_arm_forward, -_pose_controls.right_arm_raise))
	_pose_rotate_local_hinge("LeftForeArm", _pose_controls.left_elbow_bend)
	_pose_rotate_local_hinge("RightForeArm", -_pose_controls.right_elbow_bend)
	_pose_rotate("LeftUpLeg", Vector3(-_pose_controls.left_leg_forward, 0.0, 0.0))
	_pose_rotate("RightUpLeg", Vector3(-_pose_controls.right_leg_forward, 0.0, 0.0))
	_pose_rotate_local_hinge("LeftLeg", _pose_controls.left_knee_bend)
	_pose_rotate_local_hinge("RightLeg", _pose_controls.right_knee_bend)
	for body_name in _body_rotations:
		var bone_name: String = CONTROL_BODY_SPECS[body_name].bone
		_pose_rotate(bone_name, _body_rotations[body_name])


func _create_control_rig() -> void:
	var skeleton := get_active_skeleton()
	if skeleton == null or _control_rig_root != null:
		return
	_control_rig_root = Node3D.new()
	_control_rig_root.name = "InteractiveControlRig"
	add_child(_control_rig_root)
	for target_name in CONTROL_RIG_SPECS:
		var spec: Dictionary = CONTROL_RIG_SPECS[target_name]
		var tip_index := skeleton.find_bone(spec.tip)
		var mid_index := skeleton.find_bone(spec.mid)
		if tip_index < 0 or mid_index < 0:
			continue
		var target := Node3D.new()
		target.name = target_name.to_pascal_case() + "Target"
		_control_rig_root.add_child(target)
		target.global_position = _bone_world_position(tip_index)
		_rig_targets[target_name] = target
		_rig_target_defaults[target_name] = target.position
		var handle := MeshInstance3D.new()
		handle.name = "DragHandle"
		var sphere := SphereMesh.new()
		sphere.radius = 0.055
		sphere.height = 0.11
		sphere.radial_segments = 16
		sphere.rings = 8
		handle.mesh = sphere
		var handle_material := _control_rig_material(spec.color, 0.88)
		handle.material_override = handle_material
		target.add_child(handle)
		var line := MeshInstance3D.new()
		line.name = target_name.to_pascal_case() + "Guide"
		line.mesh = ImmediateMesh.new()
		line.material_override = _control_rig_material(spec.color, 0.60)
		_control_rig_root.add_child(line)
		_rig_lines[target_name] = line
		var ik := SkeletonIK3D.new()
		ik.name = target_name.to_pascal_case() + "IK"
		ik.root_bone = spec.root
		ik.tip_bone = spec.tip
		ik.override_tip_basis = false
		ik.use_magnet = true
		var pole_world := _bone_world_position(mid_index) + Vector3(0.0, 0.0, 0.65)
		ik.magnet = skeleton.global_transform.affine_inverse() * pole_world
		ik.max_iterations = 24
		ik.min_distance = 0.00001
		skeleton.add_child(ik)
		ik.target_node = ik.get_path_to(target)
		ik.start(false)
		_ik_nodes[target_name] = ik
	_update_control_rig_lines()


func _create_control_rig_v2() -> void:
	var skeleton := get_active_skeleton()
	if skeleton == null or _control_rig_root != null:
		return
	_control_rig_root = Node3D.new()
	_control_rig_root.name = "InteractiveControlRig"
	add_child(_control_rig_root)
	for target_name in CONTROL_RIG_SPECS:
		var spec: Dictionary = CONTROL_RIG_SPECS[target_name]
		var tip_index := skeleton.find_bone(spec.tip)
		if tip_index < 0:
			continue
		var target := _create_rig_handle_v2(target_name, spec.color, 0.055)
		target.global_transform = _bone_world_control_transform(tip_index)
		_rig_targets[target_name] = target
		_rig_target_defaults[target_name] = target.transform
		var line := MeshInstance3D.new()
		line.name = target_name.to_pascal_case() + "Guide"
		line.mesh = ImmediateMesh.new()
		line.material_override = _control_rig_material(spec.color, 0.60)
		_control_rig_root.add_child(line)
		_rig_lines[target_name] = line
		var ik := SkeletonIK3D.new()
		ik.name = target_name.to_pascal_case() + "IK"
		ik.root_bone = spec.root
		ik.tip_bone = spec.tip
		ik.override_tip_basis = true
		ik.use_magnet = true
		ik.max_iterations = 32
		ik.min_distance = 0.00001
		skeleton.add_child(ik)
		ik.target_node = ik.get_path_to(target)
		_ik_nodes[target_name] = ik
	for pole_name in CONTROL_POLE_SPECS:
		var pole_spec: Dictionary = CONTROL_POLE_SPECS[pole_name]
		var bone_index := skeleton.find_bone(pole_spec.bone)
		var pole := _create_rig_handle_v2(pole_name, pole_spec.color, 0.042)
		pole.global_position = _bone_world_position(bone_index)
		_rig_poles[pole_name] = pole
		_rig_target_defaults[pole_name] = pole.transform
		_update_chain_magnet(pole_spec.chain)
	for body_name in CONTROL_BODY_SPECS:
		var body_spec: Dictionary = CONTROL_BODY_SPECS[body_name]
		var body_index := skeleton.find_bone(body_spec.bone)
		if body_index < 0:
			continue
		var body_target := _create_rig_handle_v2(body_name, body_spec.color, 0.045)
		body_target.global_position = _bone_world_position(body_index)
		_body_targets[body_name] = body_target
		_body_target_defaults[body_name] = body_target.transform
		_body_bone_base_positions[body_name] = skeleton.get_bone_pose_position(body_index)
	_update_control_rig_lines()


func _create_rig_handle_v2(handle_name: String, color: Color, radius: float) -> Node3D:
	var target := Node3D.new()
	target.name = handle_name.to_pascal_case() + "Target"
	_control_rig_root.add_child(target)
	var handle := MeshInstance3D.new()
	handle.name = "DragHandle"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	handle.mesh = sphere
	handle.material_override = _control_rig_material(color, 0.88)
	target.add_child(handle)
	return target


func _control_rig_material(color: Color, opacity: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 1.0)
	material.emission_enabled = true
	material.emission = color * 0.12
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.no_depth_test = false
	return material


func _bone_world_position(bone_index: int) -> Vector3:
	var skeleton := get_active_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin

func _bone_world_transform(bone_index: int) -> Transform3D:
	var skeleton := get_active_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)


func _bone_world_control_transform(bone_index: int) -> Transform3D:
	var result := _bone_world_transform(bone_index)
	result.basis = result.basis.orthonormalized()
	return result


func _update_chain_magnet(chain_name: String) -> void:
	if not _ik_nodes.has(chain_name):
		return
	var pole_name: String = CONTROL_RIG_SPECS[chain_name].pole
	if not _rig_poles.has(pole_name):
		return
	var skeleton := get_active_skeleton()
	var pole_spec: Dictionary = CONTROL_POLE_SPECS[pole_name]
	var joint_index := skeleton.find_bone(pole_spec.bone)
	var joint_position := _bone_world_position(joint_index)
	var pole_position := (_rig_poles[pole_name] as Node3D).global_position
	if pole_position.distance_to(joint_position) < 0.06:
		pole_position = joint_position + global_transform.basis * (pole_spec.fallback as Vector3)
	(_ik_nodes[chain_name] as SkeletonIK3D).magnet = skeleton.global_transform.affine_inverse() * pole_position



func set_control_rig_visible(visible: bool) -> void:
	_control_rig_visible = visible
	if _control_rig_root != null:
		_control_rig_root.visible = visible


func is_control_rig_visible() -> bool:
	return _control_rig_visible


func begin_control_rig_drag(camera: Camera3D, screen_position: Vector2) -> bool:
	if not _control_rig_visible or _preview_playing:
		return false
	var closest_name := ""
	var closest_distance := 24.0
	var selectable := {}
	selectable.merge(_rig_targets)
	selectable.merge(_rig_poles)
	selectable.merge(_body_targets)
	for target_name in selectable:
		var target := selectable[target_name] as Node3D
		if camera.is_position_behind(target.global_position):
			continue
		var distance := camera.unproject_position(target.global_position).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_name = target_name
	if closest_name.is_empty():
		return false
	_active_rig_target = closest_name
	var selected := selectable[closest_name] as Node3D
	_drag_plane = Plane(-camera.global_transform.basis.z.normalized(), selected.global_position)
	_rig_drag_last_point = selected.global_position
	if CONTROL_RIG_SPECS.has(closest_name):
		_update_chain_magnet(closest_name)
		var ik := _ik_nodes[closest_name] as SkeletonIK3D
		ik.start(false)
		_active_ik_chains[closest_name] = true
	elif CONTROL_POLE_SPECS.has(closest_name):
		var chain_name: String = CONTROL_POLE_SPECS[closest_name].chain
		(_ik_nodes[chain_name] as SkeletonIK3D).start(false)
		_active_ik_chains[chain_name] = true
	else:
		_set_ik_enabled(false)
	return true


func drag_control_rig(camera: Camera3D, screen_position: Vector2) -> void:
	if _active_rig_target.is_empty():
		return
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var intersection: Variant = _drag_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return
	if CONTROL_RIG_SPECS.has(_active_rig_target):
		var target := _rig_targets[_active_rig_target] as Node3D
		target.global_position = _constrain_rig_target(_active_rig_target, intersection as Vector3)
	elif CONTROL_POLE_SPECS.has(_active_rig_target):
		var pole := _rig_poles[_active_rig_target] as Node3D
		var requested := intersection as Vector3
		if _active_rig_target.ends_with("knee"):
			var local := global_transform.affine_inverse() * requested
			local.z = maxf(local.z, 0.12)
			requested = global_transform * local
		pole.global_position = requested
		_update_chain_magnet(CONTROL_POLE_SPECS[_active_rig_target].chain)
	else:
		var body_target := _body_targets[_active_rig_target] as Node3D
		var base_transform: Transform3D = _body_target_defaults[_active_rig_target]
		var requested_local := _control_rig_root.to_local(intersection as Vector3)
		var body_spec: Dictionary = CONTROL_BODY_SPECS[_active_rig_target]
		var skeleton := get_active_skeleton()
		var bone_index := skeleton.find_bone(body_spec.bone)
		if body_spec.mode == "rotate":
			var previous_local := _control_rig_root.to_local(_rig_drag_last_point)
			var drag_delta := requested_local - previous_local
			var rotation_delta := Vector3(-drag_delta.z, drag_delta.x, drag_delta.y) * 180.0
			if _active_rig_target == "right_shoulder":
				rotation_delta.z *= -1.0
			var rotation: Vector3 = _body_rotations.get(_active_rig_target, Vector3.ZERO) + rotation_delta
			rotation.x = clampf(rotation.x, -85.0, 85.0)
			rotation.y = clampf(rotation.y, -85.0, 85.0)
			rotation.z = clampf(rotation.z, -110.0, 110.0)
			_body_rotations[_active_rig_target] = rotation
			_apply_manual_pose()
			_sync_rig_targets_from_pose()
			body_target.global_position = _bone_world_position(bone_index)
			_rig_drag_last_point = intersection as Vector3
		else:
			var delta := requested_local - base_transform.origin
			if delta.length() > 0.22:
				delta = delta.normalized() * 0.22
			body_target.position = base_transform.origin + delta
			var skeleton_delta := skeleton.global_transform.basis.inverse() * (_control_rig_root.global_transform.basis * delta)
			skeleton.set_bone_pose_position(bone_index, _body_bone_base_positions[_active_rig_target] + skeleton_delta)
	_update_control_rig_lines()


func end_control_rig_drag() -> void:
	_active_rig_target = ""


func is_control_rig_dragging() -> bool:
	return not _active_rig_target.is_empty()


func _constrain_rig_target(target_name: String, requested_position: Vector3) -> Vector3:
	var skeleton := get_active_skeleton()
	var spec: Dictionary = CONTROL_RIG_SPECS[target_name]
	var root_index := skeleton.find_bone(spec.root)
	var mid_index := skeleton.find_bone(spec.mid)
	var tip_index := skeleton.find_bone(spec.tip)
	var root_position := _bone_world_position(root_index)
	var mid_position := _bone_world_position(mid_index)
	var tip_position := _bone_world_position(tip_index)
	var upper_length := root_position.distance_to(mid_position)
	var lower_length := mid_position.distance_to(tip_position)
	var min_bend := deg_to_rad(float(spec.min_bend))
	var max_bend := deg_to_rad(float(spec.max_bend))
	var maximum_reach := sqrt(upper_length * upper_length + lower_length * lower_length + 2.0 * upper_length * lower_length * cos(min_bend))
	var minimum_reach := sqrt(upper_length * upper_length + lower_length * lower_length + 2.0 * upper_length * lower_length * cos(max_bend))
	var offset := requested_position - root_position
	if offset.length_squared() < 0.000001:
		offset = Vector3(0.0, -1.0, 0.0)
	return root_position + offset.normalized() * clampf(offset.length(), minimum_reach, maximum_reach)


func _update_control_rig_lines() -> void:
	if _control_rig_root == null or not _control_rig_visible:
		return
	var skeleton := get_active_skeleton()
	for target_name in _rig_lines:
		var line := _rig_lines[target_name] as MeshInstance3D
		var immediate := line.mesh as ImmediateMesh
		immediate.clear_surfaces()
		var spec: Dictionary = CONTROL_RIG_SPECS[target_name]
		var root_position := _control_rig_root.to_local(_bone_world_position(skeleton.find_bone(spec.root)))
		var target_position := (_rig_targets[target_name] as Node3D).position
		immediate.surface_begin(Mesh.PRIMITIVE_LINES)
		immediate.surface_add_vertex(root_position)
		immediate.surface_add_vertex(target_position)
		immediate.surface_end()


func _set_ik_enabled(enabled: bool) -> void:
	if not enabled:
		for target_name in _ik_nodes:
			(_ik_nodes[target_name] as SkeletonIK3D).stop()
		_active_ik_chains.clear()
	if _control_rig_root != null:
		_control_rig_root.visible = _control_rig_visible


func _sync_rig_targets_from_pose() -> void:
	if _rig_targets.is_empty():
		return
	var skeleton := get_active_skeleton()
	for target_name in _rig_targets:
		var tip_name: String = CONTROL_RIG_SPECS[target_name].tip
		(_rig_targets[target_name] as Node3D).global_transform = _bone_world_control_transform(skeleton.find_bone(tip_name))
	for pole_name in _rig_poles:
		var pole_bone: String = CONTROL_POLE_SPECS[pole_name].bone
		(_rig_poles[pole_name] as Node3D).global_position = _bone_world_position(skeleton.find_bone(pole_bone))
	for body_name in _body_targets:
		var body_bone: String = CONTROL_BODY_SPECS[body_name].bone
		(_body_targets[body_name] as Node3D).global_position = _bone_world_position(skeleton.find_bone(body_bone))


func _reset_control_rig_targets() -> void:
	_set_ik_enabled(false)
	_body_rotations.clear()
	_apply_manual_pose()
	for target_name in _rig_targets:
		(_rig_targets[target_name] as Node3D).transform = _rig_target_defaults[target_name]
	for pole_name in _rig_poles:
		(_rig_poles[pole_name] as Node3D).transform = _rig_target_defaults[pole_name]
	for body_name in _body_targets:
		(_body_targets[body_name] as Node3D).transform = _body_target_defaults[body_name]
		var skeleton := get_active_skeleton()
		var bone_index := skeleton.find_bone(CONTROL_BODY_SPECS[body_name].bone)
		skeleton.set_bone_pose_position(bone_index, _body_bone_base_positions[body_name])
	for chain_name in _ik_nodes: _update_chain_magnet(chain_name)


func get_control_rig_targets() -> Dictionary:
	var result := {}
	for target_name in _rig_targets:
		var position := (_rig_targets[target_name] as Node3D).position
		result[target_name] = [position.x, position.y, position.z]
	return result


func load_control_rig_targets(values: Variant) -> void:
	if not values is Dictionary:
		return
	_set_ik_enabled(false)
	for target_name in _rig_targets:
		var packed: Variant = values.get(target_name, null)
		if packed is Array and packed.size() >= 3:
			var target := _rig_targets[target_name] as Node3D
			target.position = Vector3(float(packed[0]), float(packed[1]), float(packed[2]))
			var default_transform: Transform3D = _rig_target_defaults[target_name]
			if target.position.distance_to(default_transform.origin) > 0.01:
				_update_chain_magnet(target_name)
				(_ik_nodes[target_name] as SkeletonIK3D).start(false)
				_active_ik_chains[target_name] = true
	_set_ik_enabled(true)


## Applies only the appearance portion of a Character Creator JSON preset.
## Saved poses are ignored so game customers start from a clean skeleton before
## the normal Food Flip idle and walk animations are attached.
func apply_saved_preset(data: Dictionary) -> void:
	data = data.duplicate(true)
	migrate_legacy_hair_fields(data)
	# Old presets used 1/2 for tube and torus lashes. Both migrate to the new
	# fitted rim; 0 stays the clean almond opening.
	if int(data.get("eye_opening_version", 0)) < 1:
		data["lash_style"] = int(LashStyle.NONE)
	else:
		data["lash_style"] = clampi(int(data.get("lash_style", int(LashStyle.NONE))), 0, 3)
	data["eyelid_enabled"] = true
	begin_appearance_batch()
	var skipped := {
		"pose_controls": true,
		"control_rig_targets": true,
		"name": true,
		"format_version": true,
		"body_type": true,
		"eyes": true,
		"saved_at": true,
		"skin_paint": true,
		"extra_hairs": true,
	}
	for property_info in get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name.is_empty() or skipped.has(property_name) or not data.has(property_name):
			continue
		var raw_value: Variant = data[property_name]
		var property_type := int(property_info.get("type", TYPE_NIL))
		match property_type:
			TYPE_COLOR:
				set(property_name, Color.from_string(str(raw_value), get(property_name) as Color))
			TYPE_VECTOR3:
				if raw_value is Array and raw_value.size() >= 3:
					set(property_name, Vector3(float(raw_value[0]), float(raw_value[1]), float(raw_value[2])))
			TYPE_FLOAT:
				set(property_name, float(raw_value))
			TYPE_INT:
				set(property_name, int(raw_value))
			TYPE_BOOL:
				set(property_name, bool(raw_value))
	extra_hairs = _normalize_extra_hairs(data.get("extra_hairs", []))
	end_appearance_batch()
	set_skin_paint_png_base64(str(data.get("skin_paint", "")))
	if int(data.get("format_version", 1)) < 11:
		migrate_legacy_skin_paint_v_flip()
	if top_style == TopStyle.NONE:
		top_style = TopStyle.T_SHIRT
	if bottom_style == BottomStyle.NONE:
		bottom_style = BottomStyle.SHORTS


func get_active_body() -> Node3D:
	return toon_body


func get_active_skeleton() -> Skeleton3D:
	var skeletons := toon_body.find_children("*", "Skeleton3D", true, false)
	return skeletons[0] as Skeleton3D if not skeletons.is_empty() else null


func _apply_skin_material() -> void:
	if not is_node_ready():
		return
	_ensure_skin_paint()
	if _skin_material == null:
		_skin_material = _skin_paint_shader_material()
		_skin_material.resource_name = "Toon Skin Paint"
	_skin_material.set_shader_parameter("skin_color", skin_color)
	_skin_material.set_shader_parameter("paint_tex", _skin_paint_texture)
	for child in toon_body.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		# Only the original weighted body receives skin-tone / paint changes.
		if mesh.skin != null:
			mesh.material_override = _skin_material
	_apply_eyelid_materials()


func set_paint_mode_preview(enabled: bool) -> void:
	_clothes_hidden_for_paint = false
	## Keep the character dressed while painting. Paint is still applied only to
	## the weighted skin mesh, so clothing never receives or saves skin markings.
	if _clothing_root != null:
		_clothing_root.visible = true
	if _shirt_graphic_root != null:
		_shirt_graphic_root.visible = true


func _ensure_skin_paint() -> void:
	if _skin_paint_image == null:
		_skin_paint_image = Image.create(SKIN_PAINT_SIZE, SKIN_PAINT_SIZE, false, Image.FORMAT_RGBA8)
		_skin_paint_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		_skin_paint_dirty = false
		_skin_paint_has_marks = false
	if _skin_paint_texture == null:
		_skin_paint_texture = ImageTexture.create_from_image(_skin_paint_image)
	elif _skin_paint_dirty:
		_skin_paint_texture.set_image(_skin_paint_image)
		_skin_paint_dirty = false


func _upload_skin_paint() -> void:
	if _skin_paint_image == null:
		return
	if _skin_paint_texture == null:
		_skin_paint_texture = ImageTexture.create_from_image(_skin_paint_image)
	else:
		_skin_paint_texture.set_image(_skin_paint_image)
	_skin_paint_dirty = false
	if _skin_material != null:
		_skin_material.set_shader_parameter("paint_tex", _skin_paint_texture)


func _skin_paint_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

uniform vec4 skin_color : source_color = vec4(0.85, 0.55, 0.37, 1.0);
uniform sampler2D paint_tex : source_color, filter_linear, repeat_disable;
uniform float unlit_preview : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 paint = texture(paint_tex, UV);
	vec3 diffuse_color = mix(skin_color.rgb, paint.rgb, clamp(paint.a, 0.0, 1.0));
	ALBEDO = diffuse_color;
	EMISSION = diffuse_color * unlit_preview;
	ROUGHNESS = 0.82;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("skin_color", skin_color)
	_ensure_skin_paint()
	material.set_shader_parameter("paint_tex", _skin_paint_texture)
	material.set_shader_parameter("unlit_preview", 1.0 if _skin_paint_unlit_preview else 0.0)
	return material


func set_skin_paint_unlit_preview(enabled: bool) -> void:
	_skin_paint_unlit_preview = enabled
	if _skin_material != null:
		_skin_material.set_shader_parameter("unlit_preview", 1.0 if enabled else 0.0)


func get_skin_paint_resolution() -> int:
	return SKIN_PAINT_SIZE


func get_skin_paint_texture() -> Texture2D:
	_ensure_skin_paint()
	return _skin_paint_texture


func commit_skin_paint() -> void:
	if _skin_paint_needs_mark_scan and _skin_paint_image != null:
		_skin_paint_has_marks = not _skin_paint_image.is_invisible()
		_skin_paint_needs_mark_scan = false
	_upload_skin_paint()


func get_skin_paint_snapshot_png() -> PackedByteArray:
	_ensure_skin_paint()
	return _skin_paint_image.save_png_to_buffer()


func restore_skin_paint_snapshot_png(bytes: PackedByteArray, has_marks: bool) -> void:
	if bytes.is_empty():
		clear_skin_paint()
		return
	var restored := Image.new()
	if restored.load_png_from_buffer(bytes) != OK:
		return
	if restored.get_width() != SKIN_PAINT_SIZE or restored.get_height() != SKIN_PAINT_SIZE:
		restored.resize(SKIN_PAINT_SIZE, SKIN_PAINT_SIZE, Image.INTERPOLATE_LANCZOS)
	if restored.get_format() != Image.FORMAT_RGBA8:
		restored.convert(Image.FORMAT_RGBA8)
	_skin_paint_image = restored
	_skin_paint_has_marks = has_marks
	_skin_paint_texture = ImageTexture.create_from_image(_skin_paint_image)
	_skin_paint_dirty = false
	if _skin_material != null:
		_skin_material.set_shader_parameter("paint_tex", _skin_paint_texture)


func clear_skin_paint() -> void:
	_ensure_skin_paint()
	_skin_paint_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_skin_paint_has_marks = false
	_upload_skin_paint()


func has_skin_paint() -> bool:
	return _skin_paint_has_marks


func get_skin_paint_png_base64() -> String:
	if _skin_paint_image == null or not has_skin_paint():
		return ""
	var bytes := _skin_paint_image.save_png_to_buffer()
	if bytes.is_empty():
		return ""
	return Marshalls.raw_to_base64(bytes)


func set_skin_paint_png_base64(encoded: String) -> void:
	if encoded.strip_edges().is_empty():
		clear_skin_paint()
		return
	var bytes := Marshalls.base64_to_raw(encoded)
	var loaded := Image.new()
	if loaded.load_png_from_buffer(bytes) != OK:
		return
	if loaded.get_width() != SKIN_PAINT_SIZE or loaded.get_height() != SKIN_PAINT_SIZE:
		loaded.resize(SKIN_PAINT_SIZE, SKIN_PAINT_SIZE, Image.INTERPOLATE_LANCZOS)
	if loaded.get_format() != Image.FORMAT_RGBA8:
		loaded.convert(Image.FORMAT_RGBA8)
	_skin_paint_image = loaded
	_skin_paint_has_marks = true
	_skin_paint_texture = ImageTexture.create_from_image(_skin_paint_image)
	_skin_paint_dirty = false
	if is_node_ready():
		_apply_skin_material()


func migrate_legacy_skin_paint_v_flip() -> void:
	## Paint saved before format 11 was stamped with V inverted. Flip the stored
	## canvas once so an existing customer's marks land where they were clicked.
	if not _skin_paint_has_marks or _skin_paint_image == null:
		return
	_skin_paint_image.flip_y()
	_upload_skin_paint()


func _get_skin_mesh() -> MeshInstance3D:
	if toon_body == null:
		return null
	for child in toon_body.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.skin != null and mesh.mesh != null:
			return mesh
	return null


func pick_skin_uv(from_camera: Camera3D, screen_pos: Vector2) -> Vector2:
	if from_camera == null:
		return Vector2(-1.0, -1.0)
	var origin := from_camera.project_ray_origin(screen_pos)
	var direction := from_camera.project_ray_normal(screen_pos)
	return _intersect_skin_uv(origin, direction)


func _intersect_skin_uv(origin: Vector3, direction: Vector3) -> Vector2:
	var mesh_node := _get_skin_mesh()
	if mesh_node == null or mesh_node.mesh == null:
		return Vector2(-1.0, -1.0)
	var skeleton := get_active_skeleton()
	var best_t := 1.0e9
	var best_uv := Vector2(-1.0, -1.0)
	for surface_index in mesh_node.mesh.get_surface_count():
		var arrays := mesh_node.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		var uvs: PackedVector2Array = PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			uvs = arrays[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_BONES] is PackedInt32Array:
			bones = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = PackedFloat32Array()
		if arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
			weights = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or indices.is_empty():
			continue
		var has_uv: bool = uvs.size() == vertices.size()
		var can_skin: bool = skeleton != null and mesh_node.skin != null and bones.size() >= vertices.size() * 4
		for tri in range(0, indices.size(), 3):
			var i0 := indices[tri]
			var i1 := indices[tri + 1]
			var i2 := indices[tri + 2]
			var a := _skin_world_vertex(mesh_node, skeleton, vertices[i0], bones, weights, i0, can_skin)
			var b := _skin_world_vertex(mesh_node, skeleton, vertices[i1], bones, weights, i1, can_skin)
			var c := _skin_world_vertex(mesh_node, skeleton, vertices[i2], bones, weights, i2, can_skin)
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
			if not (hit is Vector3):
				continue
			var point := hit as Vector3
			var t := origin.distance_to(point)
			if t >= best_t:
				continue
			best_t = t
			var bary := _triangle_barycentric(point, a, b, c)
			if has_uv:
				best_uv = uvs[i0] * bary.x + uvs[i1] * bary.y + uvs[i2] * bary.z
			else:
				best_uv = _fallback_uv(vertices[i0]) * bary.x + _fallback_uv(vertices[i1]) * bary.y + _fallback_uv(vertices[i2]) * bary.z
	return best_uv


func _skin_world_vertex(
	mesh_node: MeshInstance3D, skeleton: Skeleton3D, vertex: Vector3,
	bones: PackedInt32Array, weights: PackedFloat32Array, vertex_index: int, can_skin: bool
) -> Vector3:
	if not can_skin:
		return mesh_node.global_transform * vertex
	var result := Vector3.ZERO
	var total := 0.0
	var skin := mesh_node.skin
	for influence in 4:
		var w := weights[vertex_index * 4 + influence]
		if w <= 0.0001:
			continue
		var bind_i := bones[vertex_index * 4 + influence]
		var bone_name := String(skin.get_bind_name(bind_i))
		var bone_i := skeleton.find_bone(bone_name)
		if bone_i < 0:
			continue
		var xf := skeleton.global_transform * skeleton.get_bone_global_pose(bone_i) * skin.get_bind_pose(bind_i)
		result += w * (xf * vertex)
		total += w
	if total <= 0.0001:
		return mesh_node.global_transform * vertex
	return result / total


func _triangle_barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 0.0000001:
		return Vector3(1.0, 0.0, 0.0)
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	var u := 1.0 - v - w
	return Vector3(u, v, w)


func _fallback_uv(vertex: Vector3) -> Vector2:
	var angle := atan2(vertex.x, vertex.z)
	return Vector2(angle / TAU + 0.5, clampf(vertex.y * 0.55 + 0.5, 0.0, 1.0))


func paint_skin_stamp(uv: Vector2, radius_px: float, color: Color, hard_edge: bool = false, commit: bool = true) -> void:
	if uv.x < 0.0:
		return
	_ensure_skin_paint()
	var size_f := float(SKIN_PAINT_SIZE - 1)
	## Godot's Image rows and the mesh UV sampled by the spatial shader use the
	## same V direction. Flipping V here mirrored every stroke vertically, which
	## made the cursor appear unrelated to the mark on the model.
	var cx := clampf(uv.x, 0.0, 1.0) * size_f
	var cy := clampf(uv.y, 0.0, 1.0) * size_f
	var radius := maxf(radius_px, 0.5)
	var r_i := int(ceil(radius))
	for oy in range(-r_i, r_i + 1):
		for ox in range(-r_i, r_i + 1):
			var dist := sqrt(float(ox * ox + oy * oy))
			if dist > radius:
				continue
			var falloff := 1.0 if hard_edge else pow(1.0 - dist / maxf(radius, 0.001), 0.62)
			## A one-pixel antialias fringe keeps hard tattoo edges crisp without stair steps.
			if hard_edge and dist > radius - 1.0:
				falloff = clampf(radius - dist, 0.0, 1.0)
			var px := clampi(int(floor(cx + float(ox))), 0, SKIN_PAINT_SIZE - 1)
			var py := clampi(int(floor(cy + float(oy))), 0, SKIN_PAINT_SIZE - 1)
			var src := color
			src.a *= falloff
			var dst := _skin_paint_image.get_pixel(px, py)
			var out_a := src.a + dst.a * (1.0 - src.a)
			var out_rgb := Vector3.ZERO
			if out_a > 0.0001:
				out_rgb = (Vector3(src.r, src.g, src.b) * src.a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - src.a)) / out_a
			_skin_paint_image.set_pixel(px, py, Color(out_rgb.x, out_rgb.y, out_rgb.z, out_a))
	_skin_paint_has_marks = true
	if commit:
		_upload_skin_paint()


func erase_skin_stamp(uv: Vector2, radius_px: float, opacity: float = 1.0, commit: bool = true) -> void:
	if uv.x < 0.0:
		return
	_ensure_skin_paint()
	var size_f := float(SKIN_PAINT_SIZE - 1)
	var cx := clampf(uv.x, 0.0, 1.0) * size_f
	var cy := clampf(uv.y, 0.0, 1.0) * size_f
	var radius := maxf(radius_px, 0.5)
	var r_i := int(ceil(radius))
	for oy in range(-r_i, r_i + 1):
		for ox in range(-r_i, r_i + 1):
			var dist := sqrt(float(ox * ox + oy * oy))
			if dist > radius:
				continue
			var falloff := pow(1.0 - dist / maxf(radius, 0.001), 0.62)
			var px := clampi(int(floor(cx + float(ox))), 0, SKIN_PAINT_SIZE - 1)
			var py := clampi(int(floor(cy + float(oy))), 0, SKIN_PAINT_SIZE - 1)
			var dst := _skin_paint_image.get_pixel(px, py)
			dst.a *= 1.0 - clampf(opacity, 0.0, 1.0) * falloff
			if dst.a < 0.002:
				dst = Color(0.0, 0.0, 0.0, 0.0)
			_skin_paint_image.set_pixel(px, py, dst)
	_skin_paint_needs_mark_scan = true
	if commit:
		commit_skin_paint()


func blur_skin_stamp(uv: Vector2, radius_px: float, commit: bool = true) -> void:
	if uv.x < 0.0:
		return
	_ensure_skin_paint()
	var size_f := float(SKIN_PAINT_SIZE - 1)
	var cx := clampf(uv.x, 0.0, 1.0) * size_f
	var cy := clampf(uv.y, 0.0, 1.0) * size_f
	var radius := maxf(radius_px, 2.0)
	var r_i := int(ceil(radius))
	var snapshot := _skin_paint_image.duplicate() as Image
	for oy in range(-r_i, r_i + 1):
		for ox in range(-r_i, r_i + 1):
			var dist := sqrt(float(ox * ox + oy * oy))
			if dist > radius:
				continue
			var px := clampi(int(floor(cx + float(ox))), 0, SKIN_PAINT_SIZE - 1)
			var py := clampi(int(floor(cy + float(oy))), 0, SKIN_PAINT_SIZE - 1)
			var acc := Color(0.0, 0.0, 0.0, 0.0)
			var count := 0.0
			for by in range(-1, 2):
				for bx in range(-1, 2):
					var sx := posmod(px + bx, SKIN_PAINT_SIZE)
					var sy := posmod(py + by, SKIN_PAINT_SIZE)
					acc += snapshot.get_pixel(sx, sy)
					count += 1.0
			var blurred := acc / maxf(count, 1.0)
			var dst := snapshot.get_pixel(px, py)
			var mix_w := 0.55 * (1.0 - dist / radius)
			_skin_paint_image.set_pixel(px, py, dst.lerp(blurred, mix_w))
	if commit:
		_upload_skin_paint()


func fill_skin_lasso(from_camera: Camera3D, polygon: PackedVector2Array, color: Color) -> void:
	if from_camera == null or polygon.size() < 3:
		return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var step := 4.0
	var y := bounds.position.y
	while y <= bounds.end.y:
		var x := bounds.position.x
		while x <= bounds.end.x:
			var sample := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(sample, polygon):
				var uv := pick_skin_uv(from_camera, sample)
				if uv.x >= 0.0:
					paint_skin_stamp(uv, 3.5, color, false, false)
			x += step
		y += step
	_upload_skin_paint()


func fill_skin_uv_lasso(polygon_uv: PackedVector2Array, color: Color, hard_edge: bool = false) -> void:
	if polygon_uv.size() < 3:
		return
	_ensure_skin_paint()
	var polygon_px := PackedVector2Array()
	var bounds := Rect2(polygon_uv[0] * float(SKIN_PAINT_SIZE - 1), Vector2.ZERO)
	for uv in polygon_uv:
		var point := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)) * float(SKIN_PAINT_SIZE - 1)
		polygon_px.append(point)
		bounds = bounds.expand(point)
	var min_x := clampi(int(floor(bounds.position.x)), 0, SKIN_PAINT_SIZE - 1)
	var max_x := clampi(int(ceil(bounds.end.x)), 0, SKIN_PAINT_SIZE - 1)
	var min_y := clampi(int(floor(bounds.position.y)), 0, SKIN_PAINT_SIZE - 1)
	var max_y := clampi(int(ceil(bounds.end.y)), 0, SKIN_PAINT_SIZE - 1)
	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			if Geometry2D.is_point_in_polygon(Vector2(px, py), polygon_px):
				var dst := _skin_paint_image.get_pixel(px, py)
				var src_a := clampf(color.a, 0.0, 1.0)
				var out_a := src_a + dst.a * (1.0 - src_a)
				var out_rgb := Vector3.ZERO
				if out_a > 0.0001:
					out_rgb = (Vector3(color.r, color.g, color.b) * src_a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - src_a)) / out_a
				_skin_paint_image.set_pixel(px, py, Color(out_rgb.x, out_rgb.y, out_rgb.z, out_a))
	_skin_paint_has_marks = true
	_upload_skin_paint()


func get_skin_uv_guide_lines() -> PackedVector2Array:
	if not _skin_uv_guide_lines.is_empty():
		return _skin_uv_guide_lines
	var mesh_node := _get_skin_mesh()
	if mesh_node != null and mesh_node.mesh != null:
		for surface_index in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface_index)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			if uvs.is_empty() or indices.is_empty():
				continue
			for tri in range(0, indices.size(), 3):
				var a := uvs[indices[tri]] * float(SKIN_PAINT_SIZE - 1)
				var b := uvs[indices[tri + 1]] * float(SKIN_PAINT_SIZE - 1)
				var c := uvs[indices[tri + 2]] * float(SKIN_PAINT_SIZE - 1)
				_skin_uv_guide_lines.append_array(PackedVector2Array([a, b, b, c, c, a]))
	return _skin_uv_guide_lines


func _create_head_modules() -> void:
	var skeleton := get_active_skeleton()
	if skeleton == null:
		push_error("The toon body is missing its Skeleton3D")
		return
	_head_attachment = BoneAttachment3D.new()
	_head_attachment.name = "ModularHeadAttachment"
	_head_attachment.bone_name = "Head"
	skeleton.add_child(_head_attachment)
	# Compensate only for this scene's internal Body scale. Using the full global
	# scale also canceled Food Flip's customer wrapper scale, making the modular
	# face and hair huge while the weighted body stayed small.
	var world_scale := _head_attachment.global_transform.basis.get_scale().x
	var character_scale := global_transform.basis.get_scale().x
	var inherited_scale := world_scale / maxf(character_scale, 0.001)
	_unit = 1.0 / maxf(inherited_scale, 0.001)
	_eyes_root = _new_module_root("Eyes")
	_lashes_root = _new_module_root("Eyelashes")
	_cheeks_root = _new_module_root("Cheeks")
	_eyebrows_root = _new_module_root("Eyebrows")
	_nose_root = _new_module_root("Nose")
	_mouth_root = _new_module_root("Mouth")
	_ears_root = _new_module_root("Ears")
	_hair_root = _new_module_root("Hair")
	_facial_hair_root = _new_module_root("FacialHair")
	_hat_root = _new_module_root("Hat")
	_glasses_root = _new_module_root("Glasses")
	_makeup_root = _new_module_root("Makeup")
	_jewelry_root = _new_module_root("Jewelry")
	_shirt_graphic_attachment = BoneAttachment3D.new()
	_shirt_graphic_attachment.name = "ShirtGraphicAttachment"
	_shirt_graphic_attachment.bone_name = "Chest"
	skeleton.add_child(_shirt_graphic_attachment)
	_shirt_graphic_root = Node3D.new()
	_shirt_graphic_root.name = "ShirtGraphic"
	_shirt_graphic_attachment.add_child(_shirt_graphic_root)


func _new_module_root(module_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = module_name
	_head_attachment.add_child(root)
	return root


func _build_eyes() -> void:
	if _eyes_root == null:
		return
	_clear(_eyes_root)
	var eye_position_y := 0.35 + eye_vertical
	var eye_half_size := Vector3(0.085 * eye_width, 0.12 * eye_height, 0.028)
	var eye_position_x := 0.18 * eye_spacing
	var eye_position_z := 0.475 + eye_depth
	var specular_material := _toon_material(Color.WHITE)
	specular_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var specular_size := Vector3(0.018, 0.022, 0.010) * eye_specular_scale
	for side in [-1.0, 1.0]:
		var eye_group := Node3D.new()
		eye_group.name = "EyeLeftGroup" if side < 0.0 else "EyeRightGroup"
		eye_group.position = Vector3(side * eye_position_x, eye_position_y, eye_position_z) * _unit
		eye_group.rotation.y = left_eye_yaw if side < 0.0 else right_eye_yaw
		_eyes_root.add_child(eye_group)
		var eye_material := _eye_shader_material(-side * eye_pupil_inward)
		_add_sphere(eye_group, "Eye", Vector3.ZERO, eye_half_size, eye_material)
		if eyelid_enabled and lash_style != LashStyle.NONE:
			var lid_size := eye_half_size * Vector3(1.10, 1.12, 1.10) * eyelid_scale * Vector3(eyelid_width, eyelid_height, eyelid_depth)
			var lid_pos := Vector3(0.0, eyelid_vertical, eyelid_forward)
			_add_sphere(eye_group, "Eyelid", lid_pos, lid_size, _eyelid_shader_material(), 32, 16)
		_add_sphere(eye_group, "Specular", Vector3(eye_specular_horizontal, eye_specular_vertical, 0.031 + eye_specular_depth), specular_size, specular_material)


func _build_lashes() -> void:
	if _lashes_root == null:
		return
	_clear(_lashes_root)
	## Legacy tube and torus lashes were removed. The fitted lash rim is rendered
	## by the eyelid shader so it always follows the almond opening.


func _build_cheeks() -> void:
	if _cheeks_root == null:
		return
	_clear(_cheeks_root)
	if cheek_style == CheekStyle.NONE:
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	var center_color := cheek_color
	var middle_color := cheek_color
	middle_color.a *= 0.52
	var edge_color := cheek_color
	edge_color.a = 0.0
	gradient.colors = PackedColorArray([center_color, middle_color, edge_color])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	var cheek_x := 0.245 * cheek_spacing
	var cheek_y := 0.19 + cheek_vertical
	var cheek_z := 0.493 + cheek_depth
	for side in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		cheek.name = "LeftRosyCheek" if side < 0.0 else "RightRosyCheek"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.17 * cheek_scale * cheek_width, 0.12 * cheek_scale * cheek_height) * _unit
		cheek.mesh = quad
		cheek.material_override = material
		cheek.position = Vector3(side * cheek_x, cheek_y, cheek_z) * _unit
		_cheeks_root.add_child(cheek)


func _build_eyebrows() -> void:
	if _eyebrows_root == null:
		return
	_clear(_eyebrows_root)
	if brow_style == BrowStyle.NONE:
		return
	var material := _toon_material(brow_color)
	var brow_y := 0.35 + eye_vertical + 0.15 + brow_vertical
	var brow_x := 0.18 * eye_spacing * brow_spacing
	var brow_z := 0.475 + eye_depth + brow_depth
	var width_scale := brow_scale * brow_width
	var thickness_scale := brow_scale * brow_height
	for side in [-1.0, 1.0]:
		var group := Node3D.new()
		group.name = "BrowLeftGroup" if side < 0.0 else "BrowRightGroup"
		group.position = Vector3(side * brow_x, brow_y, brow_z) * _unit
		group.rotation.y = left_brow_yaw if side < 0.0 else right_brow_yaw
		_eyebrows_root.add_child(group)
		if brow_style == BrowStyle.ARCHED:
			var outer := _add_box(group, "BrowArchOuter", Vector3(side * 0.038 * width_scale, -0.005, 0.0), Vector3(0.085 * width_scale, 0.024 * thickness_scale, 0.035 * brow_scale), material)
			var inner := _add_box(group, "BrowArchInner", Vector3(-side * 0.038 * width_scale, -0.005, 0.0), Vector3(0.085 * width_scale, 0.024 * thickness_scale, 0.035 * brow_scale), material)
			outer.rotation.z = -side * 0.18
			inner.rotation.z = side * 0.18
		else:
			var segment_width := 0.16 if brow_style == BrowStyle.ANGRY or brow_style == BrowStyle.WORRIED else 0.15
			var segment_height := 0.027 if brow_style == BrowStyle.ANGRY or brow_style == BrowStyle.WORRIED else 0.025
			var brow := _add_box(group, "Brow", Vector3.ZERO, Vector3(segment_width * width_scale, segment_height * thickness_scale, 0.035 * brow_scale), material)
			if brow_style == BrowStyle.ANGRY:
				brow.rotation.z = side * 0.24
			elif brow_style == BrowStyle.WORRIED:
				brow.rotation.z = -side * 0.24


func _build_nose() -> void:
	if _nose_root == null:
		return
	_clear(_nose_root)
	if nose_style == NoseStyle.NONE:
		return
	var nose_material := _toon_material(nose_color)
	var nose_position_y := 0.20 + nose_vertical
	if nose_style == NoseStyle.BUTTON:
		_add_sphere(_nose_root, "ButtonNose", Vector3(0.0, nose_position_y, 0.445 + nose_depth), Vector3(0.065 * nose_width, 0.06 * nose_height, 0.075), nose_material)
	else:
		var nose := MeshInstance3D.new()
		nose.name = "PointNose"
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.065 * _unit
		cone.height = 0.16 * _unit
		cone.radial_segments = 12
		nose.mesh = cone
		nose.material_override = nose_material
		nose.position = Vector3(0.0, nose_position_y, 0.47 + nose_depth) * _unit
		nose.rotation.x = PI * 0.5
		nose.scale = Vector3(nose_width, 1.0, nose_height)
		_nose_root.add_child(nose)


func _build_mouth() -> void:
	if _mouth_root == null:
		return
	_clear(_mouth_root)
	var mouth_material := _mouth_shader_material()
	var mouth_position_y := mouth_vertical
	if mouth_style == MouthStyle.SMILE:
		_add_curved_mouth(
			_mouth_root,
			"SmileMouth",
			Vector3(0.0, 0.105 + mouth_position_y, 0.472 + mouth_depth),
			0.135 * mouth_width,
			0.13 * mouth_height,
			0.025,
			"smile",
			mouth_material
		)
	elif mouth_style == MouthStyle.FLAT:
		_add_curved_mouth(
			_mouth_root,
			"FlatMouth",
			Vector3(0.0, 0.07 + mouth_position_y, 0.452 + mouth_depth),
			0.14 * mouth_width,
			0.035 * mouth_height,
			0.022,
			"flat",
			mouth_material
		)
	else:
		_add_curved_mouth(
			_mouth_root,
			"OpenMouth",
			Vector3(0.0, 0.08 + mouth_position_y, 0.455 + mouth_depth),
			0.11 * mouth_width,
			0.14 * mouth_height,
			0.013,
			"open",
			mouth_material
		)


func _build_ears() -> void:
	if _ears_root == null:
		return
	_clear(_ears_root)
	var material := _toon_material(ear_color)
	var ear_x := 0.34 * ear_spacing
	var ear_position_z := 0.02 + ear_depth
	var left_ear := _add_cylinder(_ears_root, "EarLeft", Vector3(-ear_x, 0.22, ear_position_z), 0.09 * ear_scale, 0.055 * ear_scale, material)
	var right_ear := _add_cylinder(_ears_root, "EarRight", Vector3(ear_x, 0.22, ear_position_z), 0.09 * ear_scale, 0.055 * ear_scale, material)
	# Cylinder caps face forward toward the character-preview camera.
	left_ear.rotation.x = PI * 0.5
	right_ear.rotation.x = PI * 0.5


func _build_hair() -> void:
	if _hair_root == null:
		return
	_clear(_hair_root)
	_spawn_hair_piece(
		int(hair_style), hair_color, hair_scale, hair_scale_xyz, hair_offset, "HairBase"
	)
	for i in extra_hairs.size():
		var layer: Dictionary = extra_hairs[i]
		var col := Color.from_string(str(layer.get("color", hair_color.to_html(true))), hair_color)
		var sc_xyz: Vector3 = _vector3_from_hair_array(layer.get("scale_xyz", [1.0, 1.0, 1.0]), Vector3.ONE)
		var off: Vector3 = _vector3_from_hair_array(layer.get("offset", [0.0, 0.3, 0.0]), Vector3(0.0, 0.3, 0.0))
		_spawn_hair_piece(
			int(layer.get("style", 0)),
			col,
			clampf(float(layer.get("scale", 1.3)), 0.3, 3.0),
			sc_xyz,
			off,
			"HairExtra%d" % i
		)


func _spawn_hair_piece(
	style: int,
	color: Color,
	scale_all: float,
	scale_xyz: Vector3,
	offset: Vector3,
	piece_name: String
) -> void:
	if style <= 0 or style >= HAIR_SCENES.size():
		return
	var packed := HAIR_SCENES[style] as PackedScene
	if packed == null:
		return
	var hair := packed.instantiate() as Node3D
	if hair == null:
		return
	hair.name = piece_name
	_hair_root.add_child(hair)
	if style <= int(HairStyle.BUNS):
		var fit: float = 3.45
		if style == int(HairStyle.LONG):
			fit = 3.15
		var adjusted_fit: float = fit * scale_all
		hair.scale = Vector3(
			adjusted_fit * scale_xyz.x,
			adjusted_fit * scale_xyz.y,
			adjusted_fit * scale_xyz.z
		) * _unit
		hair.position = (Vector3(0.0, 0.48 - 1.75 * adjusted_fit * scale_xyz.y, 0.02) + offset) * _unit
	else:
		_fit_sourced_accessory(hair, 0.76 * scale_all, Vector3(0.0, 0.47, 0.0) + offset, scale_xyz)
	_override_mesh_materials(hair, _toon_material(color))


func hair_layer_count() -> int:
	return 1 + extra_hairs.size()


func add_extra_hair(style: int = -1, copy_from: int = 0) -> int:
	if extra_hairs.size() >= MAX_EXTRA_HAIRS:
		return extra_hairs.size()
	var src: Dictionary = get_hair_layer(copy_from)
	var src_style: int = int(src["style"])
	var use_style: int = src_style if style < 1 else clampi(style, 1, HairStyle.size() - 1)
	if use_style < 1:
		hair_style = HairStyle.SIMPLE_PARTED
		return 0
	var src_color: Color = src["color"]
	var src_xyz: Vector3 = src["scale_xyz"]
	var src_off: Vector3 = src["offset"]
	var next: Array = extra_hairs.duplicate(true)
	var bump: float = 0.07 * float(next.size() + 1)
	next.append({
		"style": use_style,
		"color": src_color.to_html(true),
		"scale": clampf(float(src["scale"]), 0.3, 3.0),
		"scale_xyz": [src_xyz.x, src_xyz.y, src_xyz.z],
		"offset": [src_off.x, src_off.y + bump, src_off.z],
	})
	extra_hairs = next
	return extra_hairs.size()


func remove_extra_hair(extra_index: int) -> void:
	if extra_index < 0 or extra_index >= extra_hairs.size():
		return
	var next: Array = extra_hairs.duplicate(true)
	next.remove_at(extra_index)
	extra_hairs = next


func get_hair_layer(index: int) -> Dictionary:
	if index <= 0:
		return {
			"style": int(hair_style),
			"color": hair_color,
			"scale": hair_scale,
			"scale_xyz": hair_scale_xyz,
			"offset": hair_offset,
		}
	var extra_i: int = index - 1
	if extra_i < 0 or extra_i >= extra_hairs.size():
		return get_hair_layer(0)
	var layer: Dictionary = extra_hairs[extra_i]
	return {
		"style": int(layer.get("style", 0)),
		"color": Color.from_string(str(layer.get("color", hair_color.to_html(true))), hair_color),
		"scale": clampf(float(layer.get("scale", 1.3)), 0.3, 3.0),
		"scale_xyz": _vector3_from_hair_array(layer.get("scale_xyz", [1.0, 1.0, 1.0]), Vector3.ONE),
		"offset": _vector3_from_hair_array(layer.get("offset", [0.0, 0.3, 0.0]), Vector3(0.0, 0.3, 0.0)),
	}


func set_hair_layer_style(index: int, style: int) -> void:
	var clamped: int = clampi(style, 0, HairStyle.size() - 1)
	if index <= 0:
		hair_style = clamped as HairStyle
		return
	_patch_extra_hair(index - 1, "style", clamped)


func set_hair_layer_color(index: int, color: Color) -> void:
	if index <= 0:
		hair_color = color
		return
	_patch_extra_hair(index - 1, "color", color.to_html(true))


func set_hair_layer_scale(index: int, scale_all: float) -> void:
	var v: float = clampf(scale_all, 0.3, 3.0)
	if index <= 0:
		hair_scale = v
		return
	_patch_extra_hair(index - 1, "scale", v)


func set_hair_layer_scale_xyz(index: int, scale_xyz: Vector3) -> void:
	if index <= 0:
		hair_scale_xyz = scale_xyz
		return
	_patch_extra_hair(index - 1, "scale_xyz", [scale_xyz.x, scale_xyz.y, scale_xyz.z])


func set_hair_layer_offset(index: int, offset: Vector3) -> void:
	if index <= 0:
		hair_offset = offset
		return
	_patch_extra_hair(index - 1, "offset", [offset.x, offset.y, offset.z])


func _patch_extra_hair(extra_index: int, key: String, value: Variant) -> void:
	if extra_index < 0 or extra_index >= extra_hairs.size():
		return
	var next: Array = extra_hairs.duplicate(true)
	var layer: Dictionary = next[extra_index]
	layer[key] = value
	next[extra_index] = layer
	extra_hairs = next


func _normalize_extra_hairs(value: Variant) -> Array:
	var out: Array = []
	if not (value is Array):
		return out
	for entry in value:
		if out.size() >= MAX_EXTRA_HAIRS:
			break
		if not (entry is Dictionary):
			continue
		var layer: Dictionary = entry
		var style: int = clampi(int(layer.get("style", 0)), 0, HairStyle.size() - 1)
		if style <= 0:
			continue
		var sc_xyz: Vector3 = _vector3_from_hair_array(layer.get("scale_xyz", [1.0, 1.0, 1.0]), Vector3.ONE)
		var off: Vector3 = _vector3_from_hair_array(layer.get("offset", [0.0, 0.3, 0.0]), Vector3(0.0, 0.3, 0.0))
		out.append({
			"style": style,
			"color": str(layer.get("color", hair_color.to_html(true))),
			"scale": clampf(float(layer.get("scale", 1.3)), 0.3, 3.0),
			"scale_xyz": [sc_xyz.x, sc_xyz.y, sc_xyz.z],
			"offset": [off.x, off.y, off.z],
		})
	return out


func _vector3_from_hair_array(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _build_facial_hair() -> void:
	if _facial_hair_root == null:
		return
	_clear(_facial_hair_root)
	if facial_hair_style == FacialHairStyle.NONE:
		return
	var packed := FACIAL_HAIR_SCENES[int(facial_hair_style)] as PackedScene
	if packed == null:
		return
	var piece := packed.instantiate() as Node3D
	piece.name = FacialHairStyle.keys()[int(facial_hair_style)].capitalize()
	_facial_hair_root.add_child(piece)
	var desired_width := 0.48
	var anchor := Vector3(0.0, 0.08, 0.42)
	if facial_hair_style == FacialHairStyle.MOUSTACHE:
		desired_width = 0.34
		anchor = Vector3(0.0, 0.16, 0.44)
	_fit_sourced_accessory(piece, desired_width * facial_hair_scale, anchor + facial_hair_offset, facial_hair_scale_xyz)
	_override_mesh_materials(piece, _toon_material(facial_hair_color))


func _build_hat() -> void:
	if _hat_root == null:
		return
	_clear(_hat_root)
	if hat_style == HatStyle.NONE:
		return
	var material := _toon_material(hat_color)
	if hat_style == HatStyle.RANGER_HOOD or hat_style == HatStyle.ROUND_HOOD:
		var packed := HAT_SCENES[int(hat_style)] as PackedScene
		var hood := packed.instantiate() as Node3D
		hood.name = "RangerHood" if hat_style == HatStyle.RANGER_HOOD else "RoundHood"
		var fit := 2.55 * hat_scale
		hood.scale = Vector3.ONE * fit * _unit
		hood.position = (Vector3(0.0, 0.38 - 1.695 * fit, 0.0) + hat_offset) * _unit
		_hat_root.add_child(hood)
		_override_mesh_materials(hood, material)
	elif hat_style == HatStyle.TOP_HAT:
		_add_cylinder(_hat_root, "TopHatBrim", Vector3(0.0, 0.59, 0.0) + hat_offset, 0.36 * hat_scale, 0.045 * hat_scale, material)
		_add_cylinder(_hat_root, "TopHatCrown", Vector3(0.0, 0.59 + 0.17 * hat_scale, 0.0) + hat_offset, 0.235 * hat_scale, 0.34 * hat_scale, material)
	elif hat_style == HatStyle.BASEBALL_CAP:
		_add_sphere(_hat_root, "CapCrown", Vector3(0.0, 0.55, -0.015) + hat_offset, Vector3(0.38, 0.24, 0.34) * hat_scale, material)
		_add_box(_hat_root, "CapBrim", Vector3(0.0, 0.47, 0.31) + hat_offset, Vector3(0.42, 0.045, 0.30) * hat_scale, material)
	else:
		var packed := HAT_SCENES[int(hat_style)] as PackedScene
		if packed == null:
			return
		var sourced_hat := packed.instantiate() as Node3D
		sourced_hat.name = HatStyle.keys()[int(hat_style)].capitalize()
		_hat_root.add_child(sourced_hat)
		_fit_sourced_accessory(sourced_hat, 0.82 * hat_scale, Vector3(0.0, 0.59, 0.0) + hat_offset)
		_override_mesh_materials(sourced_hat, material)
		_smooth_meshes(sourced_hat)
	for child in _hat_root.get_children():
		if child is Node3D:
			(child as Node3D).rotation_degrees = hat_rotation


func _build_glasses() -> void:
	if _glasses_root == null:
		return
	_clear(_glasses_root)
	if glasses_style == GlassesStyle.NONE:
		return
	var packed := GLASSES_SCENES[int(glasses_style)] as PackedScene
	var glasses := packed.instantiate() as Node3D
	glasses.name = GlassesStyle.keys()[int(glasses_style)].capitalize()
	_glasses_root.add_child(glasses)
	_fit_sourced_accessory(glasses, 0.62 * glasses_scale, glasses_offset)
	_override_mesh_materials(glasses, _toon_material(glasses_color))
	_smooth_meshes(glasses)


func _build_makeup() -> void:
	if _makeup_root == null:
		return
	_clear(_makeup_root)
	if makeup_style == MakeupStyle.NONE:
		return
	var material := _toon_material(makeup_color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var o := makeup_offset
	if makeup_style in [MakeupStyle.EYE_SHADOW, MakeupStyle.GLAM]:
		_add_sphere(_makeup_root, "LeftShadow", Vector3(-0.145, 0.37, 0.449) + o, Vector3(0.105, 0.038, 0.012) * makeup_scale, material)
		_add_sphere(_makeup_root, "RightShadow", Vector3(0.145, 0.37, 0.449) + o, Vector3(0.105, 0.038, 0.012) * makeup_scale, material)
	if makeup_style in [MakeupStyle.WINGED_LINER, MakeupStyle.GLAM]:
		var left := _add_box(_makeup_root, "LeftWing", Vector3(-0.245, 0.315, 0.474) + o, Vector3(0.11, 0.018, 0.018) * makeup_scale, material)
		var right := _add_box(_makeup_root, "RightWing", Vector3(0.245, 0.315, 0.474) + o, Vector3(0.11, 0.018, 0.018) * makeup_scale, material)
		left.rotation.z = -0.24
		right.rotation.z = 0.24
	if makeup_style in [MakeupStyle.BEAUTY_MARK, MakeupStyle.GLAM]:
		_add_sphere(_makeup_root, "BeautyMark", Vector3(0.205, 0.105, 0.482) + o, Vector3.ONE * 0.018 * makeup_scale, material)


func _build_jewelry() -> void:
	if _jewelry_root == null:
		return
	_clear(_jewelry_root)
	if jewelry_style == JewelryStyle.NONE:
		return
	var material := _toon_material(jewelry_color)
	var o := jewelry_offset
	if jewelry_style == JewelryStyle.STUDS:
		_add_sphere(_jewelry_root, "LeftStud", Vector3(-0.355, 0.20, 0.045) + o, Vector3.ONE * 0.035 * jewelry_scale, material)
		_add_sphere(_jewelry_root, "RightStud", Vector3(0.355, 0.20, 0.045) + o, Vector3.ONE * 0.035 * jewelry_scale, material)
	elif jewelry_style in [JewelryStyle.HOOPS, JewelryStyle.DROP_EARRINGS]:
		for side in [-1.0, 1.0]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.055 * jewelry_scale * _unit
			torus.outer_radius = 0.072 * jewelry_scale * _unit
			ring.mesh = torus
			ring.position = (Vector3(0.365 * side, 0.12, 0.04) + o) * _unit
			ring.rotation.x = PI * 0.5
			ring.material_override = material
			_jewelry_root.add_child(ring)
			if jewelry_style == JewelryStyle.DROP_EARRINGS:
				_add_sphere(_jewelry_root, "Drop", Vector3(0.365 * side, 0.015, 0.04) + o, Vector3(0.035, 0.055, 0.025) * jewelry_scale, material)
	elif jewelry_style == JewelryStyle.CHOKER:
		var choker := _add_cylinder(_jewelry_root, "Choker", Vector3(0.0, -0.19, 0.0) + o, 0.205 * jewelry_scale, 0.045 * jewelry_scale, material)
		choker.scale.z = 0.85


func _build_clothing() -> void:
	if _clothing_root == null:
		return
	_clear(_clothing_root)
	var torso_bones: Array[String] = ["Hips", "Spine", "Chest", "UpperChest"]
	if top_style == TopStyle.T_SHIRT:
		_build_weighted_garment("TShirt", torso_bones + ["LeftShoulder", "LeftArm", "RightShoulder", "RightArm"], _toon_material(top_color), 0.015, INF, top_scale)
	elif top_style == TopStyle.TANK_TOP:
		_build_weighted_garment("TankTop", torso_bones, _toon_material(top_color), 0.015, INF, top_scale)
	elif top_style == TopStyle.LONG_SLEEVE:
		_build_weighted_garment("LongSleeve", torso_bones + ["LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm"], _toon_material(top_color), 0.015, INF, top_scale)
	elif top_style == TopStyle.CROP_TOP:
		_build_weighted_garment("CropTop", torso_bones + ["LeftShoulder", "LeftArm", "RightShoulder", "RightArm"], _toon_material(top_color), 0.024, INF, top_scale)
	elif top_style == TopStyle.BLOUSE:
		_build_weighted_garment("Blouse", torso_bones + ["LeftShoulder", "LeftArm", "RightShoulder", "RightArm"], _toon_material(top_color), 0.012, INF, top_scale * 1.035, 0.0008)
	elif top_style == TopStyle.POLO:
		_build_weighted_garment("Polo", torso_bones + ["LeftShoulder", "LeftArm", "RightShoulder", "RightArm"], _toon_material(top_color), 0.014, INF, top_scale * 1.01, 0.0007)
	elif top_style == TopStyle.HOODIE:
		_build_weighted_garment("Hoodie", torso_bones + ["LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm"], _toon_material(top_color), 0.010, INF, top_scale * 1.055, 0.0010)
	elif top_style == TopStyle.SWEATER:
		_build_weighted_garment("Sweater", torso_bones + ["LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm"], _toon_material(top_color), 0.010, INF, top_scale * 1.025, 0.00085)
	elif top_style == TopStyle.OFF_SHOULDER:
		_build_weighted_garment("OffShoulder", torso_bones, _toon_material(top_color), 0.012, 0.044, top_scale * 1.03, 0.0008)
	elif top_style == TopStyle.DRESS_BODICE:
		_build_weighted_garment("DressBodice", torso_bones, _toon_material(top_color), 0.006, INF, top_scale * 1.02, 0.00075)
	elif top_style == TopStyle.CARDIGAN:
		_build_weighted_garment("Cardigan", torso_bones + ["LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm"], _toon_material(top_color), 0.008, INF, top_scale * 1.045, 0.0009)
	if bottom_style == BottomStyle.PANTS:
		_build_weighted_garment("Pants", ["Hips", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"], _toon_material(bottom_color), -INF, INF, bottom_scale)
	elif bottom_style == BottomStyle.SHORTS:
		_build_weighted_garment("Shorts", ["Hips", "LeftUpLeg", "RightUpLeg"], _toon_material(bottom_color), 0.010, INF, bottom_scale)
	elif bottom_style == BottomStyle.CAPRIS:
		_build_weighted_garment("Capris", ["Hips", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"], _toon_material(bottom_color), 0.003, INF, bottom_scale)
	elif bottom_style == BottomStyle.LEGGINGS:
		_build_weighted_garment("Leggings", ["Hips", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"], _toon_material(bottom_color), -INF, INF, bottom_scale * 1.004, 0.00025)
	elif bottom_style == BottomStyle.MINI_SKIRT:
		_build_weighted_garment("MiniSkirt", ["Hips", "LeftUpLeg", "RightUpLeg"], _toon_material(bottom_color), 0.015, 0.035, bottom_scale * 1.07, 0.0010)
	elif bottom_style == BottomStyle.LONG_SKIRT:
		_build_weighted_garment("LongSkirt", ["Hips", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"], _toon_material(bottom_color), 0.004, 0.036, bottom_scale * 1.10, 0.0012)
	elif bottom_style == BottomStyle.PLEATED_SKIRT:
		_build_weighted_garment("PleatedSkirt", ["Hips", "LeftUpLeg", "RightUpLeg"], _toon_material(bottom_color), 0.010, 0.037, bottom_scale * 1.115, 0.0014)
	_build_shoes()
	_build_shirt_graphic()
	if _clothes_hidden_for_paint:
		if _clothing_root != null:
			_clothing_root.visible = false
		if _shirt_graphic_root != null:
			_shirt_graphic_root.visible = false


func _build_shirt_graphic() -> void:
	if _shirt_graphic_root == null:
		return
	_clear(_shirt_graphic_root)
	if top_style != TopStyle.T_SHIRT or shirt_graphic == ShirtGraphic.NONE:
		return
	var decal := MeshInstance3D.new()
	decal.name = ShirtGraphic.keys()[int(shirt_graphic)].capitalize()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.22 * shirt_graphic_scale * _unit
	decal.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = SHIRT_GRAPHICS[int(shirt_graphic)]
	material.albedo_color = shirt_graphic_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	decal.material_override = material
	# Chest-bone space: centered on the front of the exact-weight T-shirt.
	decal.position = Vector3(shirt_graphic_horizontal, -0.04 + shirt_graphic_vertical, 0.38 + shirt_graphic_depth) * _unit
	_shirt_graphic_root.add_child(decal)


func _build_shoes() -> void:
	if shoe_style == ShoeStyle.NONE:
		return
	var foot_bones: Array[String] = ["LeftFoot", "LeftToes", "RightFoot", "RightToes"]
	var boot_bones: Array[String] = ["LeftLeg", "LeftFoot", "LeftToes", "RightLeg", "RightFoot", "RightToes"]
	var upper_material := _toon_material(shoe_color)
	var sole_material := _toon_material(shoe_color.lightened(0.35))
	match shoe_style:
		ShoeStyle.SNEAKERS:
			_build_weighted_garment("Sneakers", foot_bones, upper_material, -INF, INF, shoe_scale, 0.00065)
			_build_weighted_garment("SneakerSoles", foot_bones, sole_material, -INF, 0.0017, shoe_scale * 1.015, 0.00085)
		ShoeStyle.ANKLE_BOOTS:
			_build_weighted_garment("AnkleBoots", boot_bones, upper_material, -INF, 0.008, shoe_scale, 0.00075)
			_build_weighted_garment("BootSoles", foot_bones, sole_material, -INF, 0.0018, shoe_scale * 1.02, 0.00095)
		ShoeStyle.HIGH_TOPS:
			_build_weighted_garment("HighTops", boot_bones, upper_material, -INF, 0.0055, shoe_scale, 0.00065)
			_build_weighted_garment("HighTopSoles", foot_bones, sole_material, -INF, 0.0017, shoe_scale * 1.02, 0.0009)
		ShoeStyle.LOAFERS:
			_build_weighted_garment("Loafers", foot_bones, upper_material, -INF, 0.0038, shoe_scale, 0.0005)
			_build_weighted_garment("LoaferSoles", foot_bones, sole_material, -INF, 0.0015, shoe_scale * 1.01, 0.00075)
		ShoeStyle.SANDALS:
			_build_weighted_garment("SandalSoles", foot_bones, sole_material, -INF, 0.0016, shoe_scale * 1.01, 0.00065)
			_build_weighted_garment("SandalStraps", ["LeftToes", "RightToes"], upper_material, 0.0012, 0.0032, shoe_scale, 0.0006)


func _build_weighted_garment(garment_name: String, allowed_bone_names: Array, material: Material, minimum_height := -INF, maximum_height := INF, garment_scale := 1.0, inflation := 0.0005) -> void:
	var source_skeleton := get_active_skeleton()
	if source_skeleton == null:
		return
	var source_mesh: MeshInstance3D
	for child in toon_body.find_children("*", "MeshInstance3D", true, false):
		var candidate := child as MeshInstance3D
		if candidate.skin != null:
			source_mesh = candidate
			break
	if source_mesh == null:
		return
	var cache_key := "%s|%.5f|%.5f|%.5f" % [garment_name, minimum_height, maximum_height, inflation]
	var generated_mesh: ArrayMesh
	if _garment_mesh_cache.has(cache_key):
		generated_mesh = _garment_mesh_cache[cache_key] as ArrayMesh
	else:
		# Mesh bone arrays index Skin binds, not Skeleton3D bones directly.
		var allowed_bones: Dictionary[int, bool] = {}
		for bind_index in source_mesh.skin.get_bind_count():
			if allowed_bone_names.has(String(source_mesh.skin.get_bind_name(bind_index))):
				allowed_bones[bind_index] = true
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface_index in source_mesh.mesh.get_surface_count():
			var arrays := source_mesh.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for triangle_start in range(0, indices.size(), 3):
				var triangle := [indices[triangle_start], indices[triangle_start + 1], indices[triangle_start + 2]]
				var accepted := true
				for vertex_index in triangle:
					if vertices[vertex_index].z < minimum_height or vertices[vertex_index].z > maximum_height or not allowed_bones.has(_dominant_bone(vertex_index, bones, weights)):
						accepted = false
						break
				if not accepted:
					continue
				for vertex_index in triangle:
					var vertex_bones := PackedInt32Array()
					var vertex_weights := PackedFloat32Array()
					for influence in 4:
						vertex_bones.append(bones[vertex_index * 4 + influence])
						vertex_weights.append(weights[vertex_index * 4 + influence])
					surface.set_bones(vertex_bones)
					surface.set_weights(vertex_weights)
					surface.set_normal(normals[vertex_index])
					surface.add_vertex(vertices[vertex_index] + normals[vertex_index] * inflation)
		generated_mesh = surface.commit()
		if generated_mesh != null and generated_mesh.get_surface_count() > 0:
			_garment_mesh_cache[cache_key] = generated_mesh
	if generated_mesh == null or generated_mesh.get_surface_count() == 0:
		return
	var garment := MeshInstance3D.new()
	garment.name = garment_name
	garment.mesh = generated_mesh
	garment.skin = source_mesh.skin
	garment.material_override = material
	_clothing_root.add_child(garment)
	garment.transform = _clothing_root.global_transform.affine_inverse() * source_mesh.global_transform
	garment.scale *= garment_scale
	garment.skeleton = garment.get_path_to(source_skeleton)


func _dominant_bone(vertex_index: int, bones: PackedInt32Array, weights: PackedFloat32Array) -> int:
	var strongest_index := 0
	var strongest_weight := -1.0
	for influence in 4:
		var weight := weights[vertex_index * 4 + influence]
		if weight > strongest_weight:
			strongest_weight = weight
			strongest_index = influence
	return bones[vertex_index * 4 + strongest_index]


func _add_sphere(parent: Node3D, part_name: String, world_position: Vector3, half_size: Vector3, material: Material, radial_segments: int = 16, rings: int = 8) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	part.mesh = sphere
	part.position = world_position * _unit
	part.scale = half_size * _unit
	part.material_override = material
	if part_name == "Eyelid":
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _add_box(parent: Node3D, part_name: String, world_position: Vector3, world_size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var box := BoxMesh.new()
	box.size = world_size * _unit
	part.mesh = box
	part.position = world_position * _unit
	part.material_override = material
	parent.add_child(part)
	return part


func _add_cylinder(parent: Node3D, part_name: String, world_position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * _unit
	cylinder.bottom_radius = radius * _unit
	cylinder.height = height * _unit
	cylinder.radial_segments = 24
	part.mesh = cylinder
	part.position = world_position * _unit
	part.material_override = material
	parent.add_child(part)
	return part


func _add_half_disc(parent: Node3D, part_name: String, world_position: Vector3, world_size: Vector2, depth: float, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 18
	var half_depth := depth * 0.5 * _unit
	var center := Vector3.ZERO
	for i in segments:
		var angle_a := PI + PI * float(i) / float(segments)
		var angle_b := PI + PI * float(i + 1) / float(segments)
		var point_a := Vector3(cos(angle_a) * world_size.x * 0.5, sin(angle_a) * world_size.y, 0.0) * _unit
		var point_b := Vector3(cos(angle_b) * world_size.x * 0.5, sin(angle_b) * world_size.y, 0.0) * _unit
		_add_surface_triangle(surface, center + Vector3(0, 0, half_depth), point_b + Vector3(0, 0, half_depth), point_a + Vector3(0, 0, half_depth), Vector3.BACK)
		_add_surface_triangle(surface, center - Vector3(0, 0, half_depth), point_a - Vector3(0, 0, half_depth), point_b - Vector3(0, 0, half_depth), Vector3.FORWARD)
		var side_normal := Vector3(point_a.x + point_b.x, point_a.y + point_b.y, 0.0).normalized()
		_add_surface_triangle(surface, point_a - Vector3(0, 0, half_depth), point_b - Vector3(0, 0, half_depth), point_b + Vector3(0, 0, half_depth), side_normal)
		_add_surface_triangle(surface, point_a - Vector3(0, 0, half_depth), point_b + Vector3(0, 0, half_depth), point_a + Vector3(0, 0, half_depth), side_normal)
	part.mesh = surface.commit()
	part.position = world_position * _unit
	part.material_override = material
	parent.add_child(part)
	return part


func _mouth_local_point(style: String, u: float, v: float, half_w: float, height: float) -> Vector3:
	var x := u * half_w
	var y := 0.0
	if style == "smile":
		var taper := sqrt(maxf(0.0, 1.0 - u * u))
		y = -v * height * taper
	elif style == "flat":
		y = (0.5 - v) * height
	else:
		y = (0.5 - v) * height * 2.0
	var z := -mouth_curve * u * u
	return Vector3(x, y, z) * _unit


func _mouth_inside(style: String, u: float, v: float) -> bool:
	if style == "open":
		var ny := (v * 2.0) - 1.0
		return (u * u) + (ny * ny) <= 1.02
	return true


func _add_curved_mouth(
	parent: Node3D,
	part_name: String,
	world_position: Vector3,
	half_w: float,
	height: float,
	depth: float,
	style: String,
	material: Material
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 22
	var rows := 10
	var half_depth := depth * 0.5 * _unit
	for row in rows:
		var v0 := float(row) / float(rows)
		var v1 := float(row + 1) / float(rows)
		for col in cols:
			var u0 := lerpf(-1.0, 1.0, float(col) / float(cols))
			var u1 := lerpf(-1.0, 1.0, float(col + 1) / float(cols))
			if not _mouth_inside(style, u0, v0) and not _mouth_inside(style, u1, v0) \
					and not _mouth_inside(style, u0, v1) and not _mouth_inside(style, u1, v1):
				continue
			var p00 := _mouth_local_point(style, u0, v0, half_w, height)
			var p10 := _mouth_local_point(style, u1, v0, half_w, height)
			var p01 := _mouth_local_point(style, u0, v1, half_w, height)
			var p11 := _mouth_local_point(style, u1, v1, half_w, height)
			var uv00 := Vector2((u0 + 1.0) * 0.5, v0)
			var uv10 := Vector2((u1 + 1.0) * 0.5, v0)
			var uv01 := Vector2((u0 + 1.0) * 0.5, v1)
			var uv11 := Vector2((u1 + 1.0) * 0.5, v1)
			var dz_du := -2.0 * mouth_curve * ((u0 + u1) * 0.5)
			var front_n := Vector3(-dz_du, 0.0, 1.0).normalized()
			var back_n := -front_n
			var z_off := Vector3(0.0, 0.0, half_depth)
			_add_mouth_triangle(surface, p00 + z_off, p10 + z_off, p11 + z_off, front_n, uv00, uv10, uv11)
			_add_mouth_triangle(surface, p00 + z_off, p11 + z_off, p01 + z_off, front_n, uv00, uv11, uv01)
			_add_mouth_triangle(surface, p00 - z_off, p11 - z_off, p10 - z_off, back_n, uv00, uv11, uv10)
			_add_mouth_triangle(surface, p00 - z_off, p01 - z_off, p11 - z_off, back_n, uv00, uv01, uv11)
	part.mesh = surface.commit()
	part.position = world_position * _unit
	part.material_override = material
	parent.add_child(part)
	return part


func _add_mouth_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.set_uv(uv_c)
	surface.add_vertex(c)


func _add_surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)


func _toon_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.94
	## Wrap lighting hides the hard terminator on big low-poly faces.
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _mouth_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 mouth_color : source_color = vec4(0.47, 0.12, 0.15, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.02, 0.01, 0.02, 0.82);
uniform float shadow_size : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float shadow_position : hint_range(-0.4, 0.6, 0.01) = 0.0;
uniform float shadow_softness : hint_range(0.0, 0.45, 0.01) = 0.10;
uniform float shadow_width : hint_range(0.15, 1.0, 0.01) = 1.0;

void fragment() {
	float y = UV.y - shadow_position;
	float soft = max(shadow_softness, 0.001);
	float vertical = 1.0 - smoothstep(shadow_size - soft, shadow_size + soft, y);
	float x_centered = abs(UV.x - 0.5) * 2.0;
	float horizontal = 1.0 - smoothstep(shadow_width, min(shadow_width + 0.14, 1.08), x_centered);
	float mask = clamp(vertical * horizontal, 0.0, 1.0) * shadow_color.a;
	ALBEDO = mix(mouth_color.rgb, shadow_color.rgb, mask);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mouth_color", mouth_color)
	material.set_shader_parameter("shadow_color", mouth_shadow_color)
	material.set_shader_parameter("shadow_size", mouth_shadow_size)
	material.set_shader_parameter("shadow_position", mouth_shadow_position)
	material.set_shader_parameter("shadow_softness", mouth_shadow_softness)
	material.set_shader_parameter("shadow_width", mouth_shadow_width)
	return material


func _eye_shader_material(pupil_offset_x: float = 0.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 sclera_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float pupil_size : hint_range(0.12, 0.92, 0.01) = 0.55;
uniform float edge_softness : hint_range(0.001, 0.08, 0.001) = 0.018;
uniform float pupil_offset_x = 0.0;

varying vec3 eye_direction;

void vertex() {
	eye_direction = normalize(VERTEX);
}

void fragment() {
	vec3 direction = normalize(eye_direction);
	float distance_from_eye_axis = length(direction.xy - vec2(pupil_offset_x, 0.0));
	float pupil_mask = 1.0 - smoothstep(pupil_size, min(pupil_size + edge_softness, 1.0), distance_from_eye_axis);
	ALBEDO = mix(sclera_color.rgb, pupil_color.rgb, pupil_mask);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("pupil_size", eye_pupil_size)
	material.set_shader_parameter("pupil_offset_x", pupil_offset_x)
	var white: float = clampf(eye_sclera_brightness, 0.15, 1.0)
	material.set_shader_parameter("sclera_color", Color(white, white, white, 1.0))
	return material


func _eyelid_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled, depth_prepass_alpha;

uniform vec4 skin_color : source_color = vec4(0.85, 0.55, 0.37, 1.0);
uniform vec4 lash_color : source_color = vec4(0.14, 0.09, 0.09, 1.0);
uniform float mask_height : hint_range(0.0, 1.0) = 0.42;
uniform float mask_width : hint_range(0.0, 1.5) = 0.88;
uniform float rim_width : hint_range(0.01, 0.36) = 0.035;
uniform bool rim_enabled = false;
uniform int opening_style = 0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	ALBEDO = skin_color.rgb;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	float half_h = max(mask_height, 0.0);
	float half_w = max(mask_width, 0.0);
	float nx = abs(local_pos.x) / max(half_w, 0.0005);
	float almond_h = 1.0 - pow(min(nx, 1.0), 1.55);
	bool almond_opening = nx <= 1.0
		&& abs(local_pos.y) / max(half_h, 0.0005) <= almond_h;
	bool classic_opening = abs(local_pos.x) <= half_w && abs(local_pos.y) <= half_h;
	bool opening = local_pos.z > 0.0
		&& ((opening_style == 2) ? classic_opening : almond_opening);
	if (opening) {
		discard;
	}
	float outer_w = half_w + rim_width;
	float outer_h = half_h + rim_width;
	float outer_x = abs(local_pos.x) / max(outer_w, 0.0005);
	float outer_almond_h = 1.0 - pow(min(outer_x, 1.0), 1.55);
	bool in_outer = local_pos.z > 0.0 && outer_x <= 1.0
		&& abs(local_pos.y) / max(outer_h, 0.0005) <= outer_almond_h;
	if (rim_enabled && in_outer) {
		ALBEDO = lash_color.rgb;
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("skin_color", skin_color)
	material.set_shader_parameter("lash_color", lash_color)
	material.set_shader_parameter("mask_height", eyelid_mask_height)
	material.set_shader_parameter("mask_width", eyelid_mask_width)
	material.set_shader_parameter("rim_width", lash_rim_width)
	material.set_shader_parameter("rim_enabled", lash_style == LashStyle.ALMOND_RIM)
	material.set_shader_parameter("opening_style", int(lash_style))
	return material


func _apply_eyelid_materials() -> void:
	if _eyes_root == null:
		return
	for found in _eyes_root.find_children("Eyelid", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		var mat := mesh.material_override as ShaderMaterial
		if mat == null:
			mesh.material_override = _eyelid_shader_material()
			continue
		mat.set_shader_parameter("skin_color", skin_color)
		mat.set_shader_parameter("lash_color", lash_color)
		mat.set_shader_parameter("mask_height", eyelid_mask_height)
		mat.set_shader_parameter("mask_width", eyelid_mask_width)
		mat.set_shader_parameter("rim_width", lash_rim_width)
		mat.set_shader_parameter("rim_enabled", lash_style == LashStyle.ALMOND_RIM)
		mat.set_shader_parameter("opening_style", int(lash_style))


func _override_mesh_materials(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = material
	for child in root.get_children():
		_override_mesh_materials(child, material)


func _smooth_meshes(root: Node) -> void:
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var rebuilt := ArrayMesh.new()
		for surface_index in mesh_node.mesh.get_surface_count():
			var tool := SurfaceTool.new()
			tool.create_from(mesh_node.mesh, surface_index)
			tool.generate_normals()
			var old_material := mesh_node.mesh.surface_get_material(surface_index)
			tool.set_material(old_material)
			tool.commit(rebuilt)
		if rebuilt.get_surface_count() > 0:
			mesh_node.mesh = rebuilt


func _fit_sourced_accessory(accessory: Node3D, desired_width: float, anchor: Vector3, axis_scale: Vector3 = Vector3.ONE) -> void:
	var meshes := accessory.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_node := meshes[0] as MeshInstance3D
	var transformed_aabb: AABB = mesh_node.transform * mesh_node.mesh.get_aabb()
	var source_width := maxf(transformed_aabb.size.x, 0.00001)
	var fit := desired_width / source_width
	accessory.scale = Vector3(fit * axis_scale.x, fit * axis_scale.y, fit * axis_scale.z) * _unit
	accessory.position = anchor * _unit


func _clear(root: Node) -> void:
	for child in root.get_children():
		child.free()
