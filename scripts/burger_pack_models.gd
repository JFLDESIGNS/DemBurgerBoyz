## Loads burgerpack try2 GLB props (textured) for grill inspect gallery.
extends RefCounted
class_name BurgerPackModels

const TRY2_DIR := "res://models/burgerpack/try2/"

## Explicit list so exported builds don't depend on DirAccess folder scanning.
const TRY2_GLB_FILES: PackedStringArray = [
	"SM_BurgerBunUntoastedBottom.glb",
	"SM_BurgerBunUntoastedTop.glb",
	"SM_GrillSpatula.glb",
	"SM_SpiceShaker.glb",
]

static var _scene_cache: Dictionary = {} ## path -> PackedScene


static func list_try2_glb_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for file_name in TRY2_GLB_FILES:
		var path := TRY2_DIR + file_name
		if ResourceLoader.exists(path):
			out.append(path)
	return out


static func display_name_from_path(path: String) -> String:
	var base := path.get_file().get_basename()
	if base.begins_with("SM_"):
		base = base.substr(3)
	var chars: PackedStringArray = PackedStringArray()
	for i in base.length():
		var ch := base[i]
		if i > 0 and ch >= "A" and ch <= "Z":
			chars.append(" ")
		chars.append(ch)
	return "".join(chars)


static func instantiate_scene(path: String, scale_mul: float = 1.0) -> Node3D:
	var packed: PackedScene = _scene_cache.get(path, null)
	if packed == null:
		if not ResourceLoader.exists(path):
			return null
		packed = load(path) as PackedScene
		if packed == null:
			return null
		_scene_cache[path] = packed
	var root := packed.instantiate() as Node3D
	if root == null:
		return null
	_strip_collision_meshes(root)
	root.scale = Vector3.ONE * scale_mul
	return root


static func _strip_collision_meshes(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var n := String(mi.name)
		if n.begins_with("UCX_") or n.begins_with("UBX_") or n.begins_with("USP_"):
			mi.visible = false
			mi.queue_free()
