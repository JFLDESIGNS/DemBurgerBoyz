extends Node3D
## Visual capacity is independent of authoritative oil coverage and aging.
const MARK_CAPACITY := 568
const REGION_COUNT := 16
var marks: Array[MeshInstance3D] = []
var emitters: Array[GPUParticles3D] = []
var strengths := PackedFloat32Array()
var positions := PackedVector3Array()
var bounds: Rect2
func setup(game: Node) -> void:
	bounds=game._grill_place_bounds()
	strengths.resize(REGION_COUNT);positions.resize(REGION_COUNT)
	for i in MARK_CAPACITY: _make_mark()
	for i in REGION_COUNT:
		var fx: GPUParticles3D=game._make_oil_burn_smoke(.065)
		fx.local_coords=false
		add_child(fx);emitters.append(fx)
func _make_mark() -> void:
	var mark:=MeshInstance3D.new()
	mark.mesh=PlaneMesh.new()
	mark.material_override=StandardMaterial3D.new()
	mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.set_meta("pooled_oil_mark",true);mark.set_meta("oil_available",true)
	mark.hide();add_child(mark);marks.append(mark)
func take_mark() -> MeshInstance3D:
	# Reserve covers the active cap plus ordinary scrape flights. An exceptional
	# burst may grow the pool rather than dropping an authoritative oil mark.
	while true:
		if marks.is_empty(): _make_mark()
		var mark=marks.pop_back()
		if is_instance_valid(mark) and not mark.is_queued_for_deletion():
			mark.set_meta("oil_available",false)
			mark.scale=Vector3.ONE
			mark.show()
			return mark
	return null
func release_mark(mark: MeshInstance3D) -> void:
	if bool(mark.get_meta("oil_available",false)): return
	mark.hide();mark.set_meta("oil_available",true)
	if mark.get_parent()!=self: mark.reparent(self)
	marks.append(mark)
func begin_regions() -> void:
	strengths.fill(0.0)
func add_smoke(at: Vector3, strength: float) -> void:
	var uv: Vector2=(Vector2(at.x,at.z)-bounds.position)/bounds.size
	var slot:=clampi(int(uv.x*4),0,3)+clampi(int(uv.y*4),0,3)*4
	if strength>strengths[slot]:
		strengths[slot]=strength;positions[slot]=at
func finish_regions() -> void:
	for i in emitters.size():
		var fx:=emitters[i]
		var on:=strengths[i]>.04
		if on: fx.global_position=positions[i]+Vector3(0,.05,0)
		if fx.emitting!=on: fx.emitting=on
		if not is_equal_approx(fx.amount_ratio,strengths[i]): fx.amount_ratio=strengths[i]
func stop() -> void:
	begin_regions();finish_regions()
