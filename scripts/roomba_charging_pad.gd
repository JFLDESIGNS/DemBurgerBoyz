extends Node3D
## A stationary dock: the robot can leave while its charging light stays here.
var game: Node
var indicator: StandardMaterial3D
var lamp: OmniLight3D

func _ready() -> void:
	var base := CylinderMesh.new()
	base.top_radius = .127
	base.bottom_radius = .132
	base.height = .014
	base.radial_segments = 48
	_add_mesh("DockBase", base, Vector3.ZERO, _material(Color("252e35"), .65))
	var inset := CylinderMesh.new()
	inset.top_radius = .116
	inset.bottom_radius = .116
	inset.height = .003
	inset.radial_segments = 48
	_add_mesh("RubberLanding", inset, Vector3(0, .008, 0), _material(Color("10171c"), .12))
	for x in [-.036, .036]:
		var contact := BoxMesh.new()
		contact.size = Vector3(.012, .002, .055)
		_add_mesh("ChargingContact", contact, Vector3(x, .011, 0), _material(Color("b99b61"), .8))
	indicator = _material(Color("83ffb3"), .0)
	indicator.emission_enabled = true
	indicator.emission_energy_multiplier = 1.3
	var led := BoxMesh.new()
	led.size = Vector3(.04, .003, .008)
	_add_mesh("ChargeIndicator", led, Vector3(0, .009, -.119), indicator)
	lamp = OmniLight3D.new()
	lamp.name = "DockLight"
	lamp.position = Vector3(0, .022, -.119)
	lamp.omni_range = .16
	lamp.light_energy = .12
	lamp.shadow_enabled = false
	add_child(lamp)
	_process(0)

func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = .48
	return mat

func _add_mesh(label: String, mesh: Mesh, at: Vector3, mat: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = at
	part.material_override = mat
	add_child(part)

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.grill_roomba_root):
		hide()
		return
	visible = game.grill_roomba_root.visible
	global_position = game._roomba_home_target() - Vector3(0, .038, 0)
	var docked: bool = not game.grill_roomba_held and game.grill_roomba_root.global_position.distance_to(game._roomba_home_target()) < .045
	var color := Color("83ffb3") if docked else Color("ffc56b")
	indicator.albedo_color = color
	indicator.emission = color
	lamp.light_color = color
