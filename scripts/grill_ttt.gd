extends Node3D
## Scratched-metal tic-tac-toe carved into the HOLD cook-edge steel.
## Dark groove + bright bevel lip (offset lower / toward cook) for a cut look.

const EMPTY := 0
const MARK_X := 1
const MARK_O := 2

## Defaults — runtime look is driven from game.gd Hidden sliders.
var board_size: float = 0.155
var line_y: float = 0.008 ## Sit clearly above steel
var line_w: float = 0.0042
var mark_w: float = 0.0055
var scratch_color := Color(0.10, 0.11, 0.13, 0.92)
var bevel_color := Color(0.72, 0.74, 0.78, 0.78)
var offset_x: float = 0.0 ## world +X = camera-left
var offset_z: float = 0.0 ## world +Z = away from cook / forward into truck
var noise_amt: float = 0.55 ## 0 = ruler-straight, 1 = rough scratch
var noise_freq: float = 7.0 ## wobbles along each stroke
var bevel_y: float = 0.0016 ## bright lip sits lower (into the cut)
var bevel_z: float = 0.0018 ## bright lip nudged toward cook (−Z)
var bevel_scale: float = 0.88 ## bright stroke a bit thinner than the groove
var scratch_seed: int = 17

var cells: Array[int] = [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]
var turn: int = MARK_X
var winner: int = EMPTY ## EMPTY = playing, MARK_* = win, -1 = draw
var revealed: bool = false

var _grid_mi: MeshInstance3D = null
var _bevel_mi: MeshInstance3D = null
var _mark_root: Node3D = null
var _mat: StandardMaterial3D = null
var _bevel_mat: StandardMaterial3D = null
var _seat: Vector3 = Vector3.ZERO ## Steel center (Y without line_y lift)


func setup_on_grill(center: Vector3) -> void:
	name = "GrillTicTacToe"
	_seat = center
	_refresh_position()
	rotation_degrees = Vector3(0, 0, 0)
	visible = false
	_ensure_mats()
	_build_grid()
	if _mark_root == null or not is_instance_valid(_mark_root):
		_mark_root = Node3D.new()
		_mark_root.name = "Marks"
		add_child(_mark_root)


func apply_look(cfg: Dictionary) -> void:
	board_size = maxf(0.04, float(cfg.get("size", board_size)))
	line_y = clampf(float(cfg.get("height", line_y)), -0.02, 0.12)
	line_w = clampf(float(cfg.get("line_w", line_w)), 0.001, 0.02)
	mark_w = clampf(float(cfg.get("mark_w", mark_w)), 0.001, 0.025)
	scratch_color = cfg.get("color", scratch_color) as Color
	bevel_color = cfg.get("bevel_color", bevel_color) as Color
	offset_x = float(cfg.get("off_x", offset_x))
	offset_z = float(cfg.get("off_z", offset_z))
	noise_amt = clampf(float(cfg.get("noise", noise_amt)), 0.0, 1.0)
	noise_freq = clampf(float(cfg.get("noise_freq", noise_freq)), 1.0, 24.0)
	bevel_y = clampf(float(cfg.get("bevel_y", bevel_y)), 0.0, 0.01)
	bevel_z = clampf(float(cfg.get("bevel_z", bevel_z)), 0.0, 0.012)
	bevel_scale = clampf(float(cfg.get("bevel_scale", bevel_scale)), 0.4, 1.2)
	scratch_seed = int(cfg.get("seed", scratch_seed))
	_refresh_position()
	_ensure_mats()
	_mat.albedo_color = scratch_color
	_bevel_mat.albedo_color = bevel_color
	_build_grid()
	_rebuild_marks()


func _refresh_position() -> void:
	position = Vector3(_seat.x + offset_x, _seat.y + line_y, _seat.z + offset_z)


func _ensure_mats() -> void:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.render_priority = 6
	_mat.albedo_color = scratch_color
	if _bevel_mat == null:
		_bevel_mat = StandardMaterial3D.new()
		_bevel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bevel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_bevel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bevel_mat.render_priority = 7
	_bevel_mat.albedo_color = bevel_color


func _build_grid() -> void:
	if _grid_mi != null and is_instance_valid(_grid_mi):
		_grid_mi.queue_free()
	if _bevel_mi != null and is_instance_valid(_bevel_mi):
		_bevel_mi.queue_free()
	_grid_mi = MeshInstance3D.new()
	_grid_mi.name = "ScratchGrid"
	_grid_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_mi.material_override = _mat
	_grid_mi.mesh = _make_grid_mesh(1.0, 0.0, 0.0, 0)
	add_child(_grid_mi)
	## Bright bevel lip — lower into the cut + nudged toward the cook (−Z).
	_bevel_mi = MeshInstance3D.new()
	_bevel_mi.name = "ScratchBevel"
	_bevel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bevel_mi.material_override = _bevel_mat
	_bevel_mi.mesh = _make_grid_mesh(bevel_scale, -bevel_y, -bevel_z, 41)
	add_child(_bevel_mi)


func _make_grid_mesh(width_mul: float, y_off: float, z_off: float, seed_add: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := board_size * 0.5
	var third := board_size / 3.0
	var lw := line_w * 0.5 * width_mul
	var sid := scratch_seed + seed_add
	for i in 2:
		var x := -h + third * float(i + 1)
		_noisy_stroke(st, Vector3(x, y_off, -h + z_off), Vector3(x, y_off, h + z_off), lw, sid + i * 11)
	for i in 2:
		var z := -h + third * float(i + 1)
		_noisy_stroke(st, Vector3(-h, y_off, z + z_off), Vector3(h, y_off, z + z_off), lw, sid + 30 + i * 13)
	## Outer frame — faint scratched border.
	var fw := line_w * 0.35 * width_mul
	_noisy_stroke(st, Vector3(-h, y_off, -h + z_off), Vector3(h, y_off, -h + z_off), fw, sid + 70)
	_noisy_stroke(st, Vector3(-h, y_off, h + z_off), Vector3(h, y_off, h + z_off), fw, sid + 80)
	_noisy_stroke(st, Vector3(-h, y_off, -h + z_off), Vector3(-h, y_off, h + z_off), fw, sid + 90)
	_noisy_stroke(st, Vector3(h, y_off, -h + z_off), Vector3(h, y_off, h + z_off), fw, sid + 100)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _hash01(n: int) -> float:
	## Deterministic 0..1 from an int (stable across rebuilds).
	var x := float((n * 1103515245 + 12345) & 0x7fffffff)
	return x / 2147483647.0


func _noisy_stroke(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float, stroke_seed: int) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.0001:
		return
	dir /= len
	var side := Vector3(-dir.z, 0.0, dir.x)
	var segs := clampi(int(round(6.0 + noise_freq * 1.4)), 4, 28)
	if noise_amt < 0.02:
		segs = 1
	var amp := half_w * 1.85 * noise_amt
	var prev := a
	for i in segs:
		var t1 := float(i + 1) / float(segs)
		var p := a.lerp(b, t1)
		if noise_amt > 0.01 and i < segs - 1:
			var n1 := _hash01(stroke_seed + i * 3) * 2.0 - 1.0
			var n2 := _hash01(stroke_seed + i * 3 + 1) * 2.0 - 1.0
			var n3 := _hash01(stroke_seed + i * 3 + 2) * 2.0 - 1.0
			## Perp wobble + slight along-stroke jitter + tiny thickness pulse.
			p += side * (n1 * amp)
			p += dir * (n2 * amp * 0.35)
			var w_pulse := half_w * (1.0 + n3 * 0.28 * noise_amt)
			_scratch_line(st, prev, p, w_pulse)
		else:
			_scratch_line(st, prev, p, half_w)
		prev = p


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
	_ensure_mats()
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
		## Dark groove mark.
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _mat
		mi.position = Vector3(cx, 0.0012, cz)
		if m == MARK_X:
			mi.mesh = _make_x_mesh(third * 0.32, 1.0, 0)
		else:
			mi.mesh = _make_o_mesh(third * 0.30, 1.0, 0)
		_mark_root.add_child(mi)
		## Bright bevel twin — lower + toward cook.
		var bi := MeshInstance3D.new()
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bi.material_override = _bevel_mat
		bi.position = Vector3(cx, 0.0012 - bevel_y, cz - bevel_z)
		if m == MARK_X:
			bi.mesh = _make_x_mesh(third * 0.32, bevel_scale, 200 + i * 7)
		else:
			bi.mesh = _make_o_mesh(third * 0.30, bevel_scale, 300 + i * 9)
		_mark_root.add_child(bi)


func _make_x_mesh(arm: float, width_mul: float, seed_add: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := mark_w * 0.5 * width_mul
	_noisy_stroke(st, Vector3(-arm, 0, -arm), Vector3(arm, 0, arm), w, scratch_seed + seed_add)
	_noisy_stroke(st, Vector3(-arm, 0, arm), Vector3(arm, 0, -arm), w, scratch_seed + seed_add + 5)
	return st.commit()


func _make_o_mesh(radius: float, width_mul: float, seed_add: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 18
	var w := mark_w * 0.45 * width_mul
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		## Mild radial noise so the O isn't a perfect circle.
		if noise_amt > 0.01:
			var n0 := (_hash01(scratch_seed + seed_add + i * 2) * 2.0 - 1.0) * radius * 0.06 * noise_amt
			var n1 := (_hash01(scratch_seed + seed_add + i * 2 + 1) * 2.0 - 1.0) * radius * 0.06 * noise_amt
			p0 *= 1.0 + n0 / maxf(radius, 0.001)
			p1 *= 1.0 + n1 / maxf(radius, 0.001)
		_scratch_line(st, p0, p1, w * (1.0 + (_hash01(scratch_seed + seed_add + i) - 0.5) * 0.35 * noise_amt))
	return st.commit()


func _scratch_line(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float) -> void:
	var dir := (b - a)
	var len := dir.length()
	if len < 0.0001:
		return
	dir /= len
	var side := Vector3(-dir.z, 0.0, dir.x) * half_w
	_quad(st, a - side, a + side, b + side, b - side)
