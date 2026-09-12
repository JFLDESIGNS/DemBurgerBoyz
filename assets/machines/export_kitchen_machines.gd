extends SceneTree
## Captures runtime snapshots separately from the approved machine source assets.

const OUT_DIR := "res://models/kitchen_machine_studio/runtime_snapshots"
const EXPORTS := [
	{"prop": "icecream_root", "file": "ice_cream_machine.glb"},
	{"prop": "fryer_root", "file": "fryer.glb"},
	{"prop": "soda_root", "file": "pop_machine.glb"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := DirAccess.open("res://")
	if dir == null or dir.make_dir_recursive(OUT_DIR.trim_prefix("res://")) != OK and not DirAccess.dir_exists_absolute(OUT_DIR):
		push_error("Could not create runtime snapshot directory: %s" % OUT_DIR)
		quit(1)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load scenes/main.tscn")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var failed := 0
	for spec in EXPORTS:
		var node := game.get(str(spec["prop"])) as Node3D
		if node == null or not is_instance_valid(node):
			push_error("Missing machine: %s" % spec["prop"])
			failed += 1
			continue
		var path := "%s/%s" % [OUT_DIR, spec["file"]]
		if not _export_machine(node, path):
			failed += 1
	game.queue_free()
	if failed > 0:
		quit(1)
		return
	print("KITCHEN_MACHINES_EXPORT_OK")
	quit(0)


func _export_machine(source: Node3D, path: String) -> bool:
	var clone := source.duplicate() as Node3D
	if clone == null:
		push_error("Could not duplicate %s" % source.name)
		return false
	root.add_child(clone)
	clone.position = Vector3.ZERO
	clone.rotation = Vector3.ZERO
	clone.scale = Vector3.ONE
	clone.visible = true
	_strip_non_visual(clone)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(clone, state)
	clone.queue_free()
	if err != OK:
		push_error("GLTF append failed for %s (%s)" % [path, err])
		return false
	err = doc.write_to_filesystem(state, path)
	if err != OK:
		push_error("GLTF write failed for %s (%s)" % [path, err])
		return false
	print("Wrote ", path)
	return true


func _strip_non_visual(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh == null:
				node.remove_child(child)
				child.free()
				continue
			_strip_non_visual(child)
			continue
		if child is ImporterMeshInstance3D:
			_strip_non_visual(child)
			continue
		if child is Node3D and not (
			child is Area3D
			or child is CollisionObject3D
			or child is Label3D
			or child is GPUParticles3D
			or child is CPUParticles3D
			or child is Marker3D
			or child is Light3D
			or child is AudioStreamPlayer3D
			or child is Sprite3D
		):
			_strip_non_visual(child)
			continue
		node.remove_child(child)
		child.free()
