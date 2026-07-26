extends Node3D
## Scratched-metal tic-tac-toe carved into the HOLD cook-edge steel.

const EMPTY := 0
const MARK_X := 1
const MARK_O := 2

## Defaults — runtime look is driven from game.gd Hidden sliders.
var board_size: float = 0.155
var line_y: float = 0.008 ## Sit clearly above steel
var line_w: float = 0.0042
var mark_w: float = 0.0055
var scratch_color := Color(0.10, 0.11, 0.13, 0.92)

var cells: Array[int] = [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]
var turn: int = MARK_X
var winner: int = EMPTY ## EMPTY = playing, MARK_* = win, -1 = draw
var revealed: bool = false

var _grid_mi: MeshInstance3D = null
var _mark_root: Node3D = null
var _mat: StandardMaterial3D = null
var _seat: Vector3 = Vector3.ZERO ## Steel center (Y without line_y lift)


func setup_on_grill(center: Vector3) -> void:
	name = "GrillTicTacToe"
	_seat = center
	position = Vector3(center.x, center.y + line_y, center.z)
	rotation_degrees = Vector3(0, 0, 0)
	visible = false
	_ensure_mat()
	_build_grid()
	if _mark_root == null or not is_instance_valid(_mark_root):
		_mark_root = Node3D.new()
		_mark_root.name = "Marks"
		add_child(_mark_root)


func apply_look(size_m: float, height_m: float, line_width: float, mark_width: float, col: Color) -> void:
	board_size = maxf(0.04, size_m)
	line_y = clampf(height_m, -0.02, 0.12)
	line_w = clampf(line_width, 0.001, 0.02)
	mark_w = clampf(mark_width, 0.001, 0.025)
	scratch_color = col
	position = Vector3(_seat.x, _seat.y + line_y, _seat.z)
	_ensure_mat()
	_mat.albedo_color = scratch_color
	_build_grid()
	_rebuild_marks()


func _ensure_mat() -> void:
	if _mat != null:
		_mat.albedo_color = scratch_color
		return
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	## Dark steel scratch — slightly cool so it reads as etched metal.
	_mat.albedo_color = scratch_color
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 6


func _build_grid() -> void:
	if _grid_mi != null and is_instance_valid(_grid_mi):
		_grid_mi.queue_free()
	_grid_mi = MeshInstance3D.new()
	_grid_mi.name = "ScratchGrid"
	_grid_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_mi.material_override = _mat
	_grid_mi.mesh = _make_grid_mesh()
	add_child(_grid_mi)


func _make_grid_mesh() -> ArrayMesh:
	## Two vertical + two horizontal scratch bars (tic-tac-toe lines).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := board_size * 0.5
	var third := board_size / 3.0
	var lw := line_w * 0.5
	for i in 2:
		var x := -h + third * float(i + 1)
		_quad(st, Vector3(x - lw, 0.0, -h), Vector3(x + lw, 0.0, -h), Vector3(x + lw, 0.0, h), Vector3(x - lw, 0.0, h))
	for i in 2:
		var z := -h + third * float(i + 1)
		_quad(st, Vector3(-h, 0.0, z - lw), Vector3(h, 0.0, z - lw), Vector3(h, 0.0, z + lw), Vector3(-h, 0.0, z + lw))
	## Outer frame — faint scratched border so the board reads as etched.
	var fw := line_w * 0.35
	_quad(st, Vector3(-h, 0.0, -h - fw), Vector3(h, 0.0, -h - fw), Vector3(h, 0.0, -h + fw), Vector3(-h, 0.0, -h + fw))
	_quad(st, Vector3(-h, 0.0, h - fw), Vector3(h, 0.0, h - fw), Vector3(h, 0.0, h + fw), Vector3(-h, 0.0, h + fw))
	_quad(st, Vector3(-h - fw, 0.0, -h), Vector3(-h + fw, 0.0, -h), Vector3(-h + fw, 0.0, h), Vector3(-h - fw, 0.0, h))
	_quad(st, Vector3(h - fw, 0.0, -h), Vector3(h + fw, 0.0, -h), Vector3(h + fw, 0.0, h), Vector3(h - fw, 0.0, h))
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func reveal() -> void:
	revealed = true
	visible = true
	_rebuild_marks()


func hide_board() -> void:
	revealed = false
	visible = false


func reset_game() -> void:
	cells = [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]
	turn = MARK_X
	winner = EMPTY
	_rebuild_marks()


func is_playable() -> bool:
	return revealed and winner == EMPTY


func cell_at_world(world: Vector3) -> int:
	## Local XZ → cell 0..8, or -1 if outside board.
	var local := to_local(world)
	var h := board_size * 0.5
	if absf(local.x) > h * 1.02 or absf(local.z) > h * 1.02:
		return -1
	var u := clampf((local.x + h) / board_size, 0.0, 0.999)
	var v := clampf((local.z + h) / board_size, 0.0, 0.999)
	var col := clampi(int(floor(u * 3.0)), 0, 2)
	var row := clampi(int(floor(v * 3.0)), 0, 2)
	return row * 3 + col


func try_place(cell: int, mark: int = -1) -> bool:
	if not revealed or winner != EMPTY:
		return false
	if cell < 0 or cell >= 9:
		return false
	if cells[cell] != EMPTY:
		return false
	var m := mark if mark == MARK_X or mark == MARK_O else turn
	cells[cell] = m
	turn = MARK_O if m == MARK_X else MARK_X
	_check_winner()
	_rebuild_marks()
	return true


func apply_state(packed: Array, next_turn: int, win: int, show: bool) -> void:
	for i in mini(9, packed.size()):
		cells[i] = int(packed[i])
	while cells.size() < 9:
		cells.append(EMPTY)
	turn = next_turn if next_turn == MARK_X or next_turn == MARK_O else MARK_X
	winner = win
	revealed = show
	visible = show
	_rebuild_marks()


func get_packed_cells() -> Array:
	var out: Array = []
	for c in cells:
		out.append(int(c))
	return out


func _check_winner() -> void:
	var lines: Array = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8],
		[0, 4, 8], [2, 4, 6],
	]
	for line in lines:
		var a: int = cells[line[0]]
		if a != EMPTY and a == cells[line[1]] and a == cells[line[2]]:
			winner = a
			return
	for c in cells:
		if c == EMPTY:
			winner = EMPTY
			return
	winner = -1 ## draw


func _rebuild_marks() -> void:
	if _mark_root == null:
		return
	for c in _mark_root.get_children():
		c.queue_free()
	_ensure_mat()
	var h := board_size * 0.5
	var third := board_size / 3.0
	for i in 9:
		var m := cells[i]
		if m == EMPTY:
			continue
		var col := i % 3
		var row := i / 3
		var cx := -h + third * (float(col) + 0.5)
		var cz := -h + third * (float(row) + 0.5)
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _mat
		mi.position = Vector3(cx, 0.0012, cz)
		if m == MARK_X:
			mi.mesh = _make_x_mesh(third * 0.32)
		else:
			mi.mesh = _make_o_mesh(third * 0.30)
		_mark_root.add_child(mi)


func _make_x_mesh(arm: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := mark_w * 0.5
	## Two scratched diagonals.
	_scratch_line(st, Vector3(-arm, 0, -arm), Vector3(arm, 0, arm), w)
	_scratch_line(st, Vector3(-arm, 0, arm), Vector3(arm, 0, -arm), w)
	return st.commit()


func _make_o_mesh(radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 18
	var w := mark_w * 0.45
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		_scratch_line(st, p0, p1, w)
	return st.commit()


func _scratch_line(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float) -> void:
	var dir := (b - a)
	var len := dir.length()
	if len < 0.0001:
		return
	dir /= len
	var side := Vector3(-dir.z, 0.0, dir.x) * half_w
	_quad(st, a - side, a + side, b + side, b - side)
