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
var wins_x: int = 0 ## Host / player 1 — carved tallies below the board
var wins_o: int = 0 ## Guest / player 2
const WINS_RESET_AT := 10 ## Best-of streak resets when either side hits 10
const SCRUB_CLEAR_SEC := 2.0 ## Spatula scrub on the board to wipe it away
var _hover_cell: int = -1
var scrub_t: float = 0.0 ## Progress toward scrubbing the board off (0..SCRUB_CLEAR_SEC)

var _grid_mi: MeshInstance3D = null
var _bevel_mi: MeshInstance3D = null
var _mark_root: Node3D = null
var _tally_mi: MeshInstance3D = null
var _tally_bevel_mi: MeshInstance3D = null
var _hover_mi: MeshInstance3D = null
var _hover_bevel_mi: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _bevel_mat: StandardMaterial3D = null
var _hover_mat: StandardMaterial3D = null
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
	_ensure_hover_meshes()
	_rebuild_tallies()


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
	_rebuild_tallies()


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
	if _hover_mat == null:
		_hover_mat = StandardMaterial3D.new()
		_hover_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hover_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_hover_mat.render_priority = 8
	_hover_mat.albedo_color = Color(
		lerpf(scratch_color.r, 0.55, 0.45),
		lerpf(scratch_color.g, 0.62, 0.45),
		lerpf(scratch_color.b, 0.72, 0.45),
		0.55
	)


func _ensure_hover_meshes() -> void:
	if _hover_mi == null or not is_instance_valid(_hover_mi):
		_hover_mi = MeshInstance3D.new()
		_hover_mi.name = "HoverMark"
		_hover_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hover_mi.visible = false
		add_child(_hover_mi)
	if _hover_bevel_mi == null or not is_instance_valid(_hover_bevel_mi):
		_hover_bevel_mi = MeshInstance3D.new()
		_hover_bevel_mi.name = "HoverBevel"
		_hover_bevel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hover_bevel_mi.visible = false
		add_child(_hover_bevel_mi)
	_hover_mi.material_override = _hover_mat
	_hover_bevel_mi.material_override = _bevel_mat


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
	scrub_t = 0.0
	_rebuild_marks()
	_rebuild_tallies()
	clear_hover()


func hide_board() -> void:
	revealed = false
	visible = false
	scrub_t = 0.0
	clear_hover()


func reset_game() -> void:
	cells = [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY]
	turn = MARK_X ## Host always opens as X
	winner = EMPTY
	scrub_t = 0.0
	_rebuild_marks()
	clear_hover()


func is_playable() -> bool:
	return revealed and winner == EMPTY


func point_on_board(world: Vector3, pad: float = -1.0) -> bool:
	## True when a world point sits on / near the carved board (for spatula scrub).
	if not revealed or world == Vector3.ZERO:
		return false
	var local := to_local(world)
	var h := board_size * 0.5
	var p := pad if pad >= 0.0 else board_size * 0.12
	## Include tally strip just below (−Z) so scrubbing tallies also clears.
	var z_lo := -h - board_size * 0.42 - p
	var z_hi := h + p
	return absf(local.x) <= h + p and local.z >= z_lo and local.z <= z_hi


func tick_scrub(delta: float, tip_on_board: bool) -> bool:
	## Accumulate spatula scrub time. Returns true when the board should wipe away.
	if not revealed:
		scrub_t = 0.0
		return false
	if tip_on_board:
		scrub_t = minf(SCRUB_CLEAR_SEC, scrub_t + delta)
	else:
		scrub_t = maxf(0.0, scrub_t - delta * 1.6)
	return scrub_t >= SCRUB_CLEAR_SEC


func scrub_progress() -> float:
	return clampf(scrub_t / SCRUB_CLEAR_SEC, 0.0, 1.0)


func note_round_winner(mark: int) -> bool:
	## Record a round win into carved tallies. Returns true if the 10-win streak reset.
	var reset := false
	if mark == MARK_X:
		wins_x = mini(wins_x + 1, WINS_RESET_AT)
	elif mark == MARK_O:
		wins_o = mini(wins_o + 1, WINS_RESET_AT)
	else:
		return false
	if wins_x >= WINS_RESET_AT or wins_o >= WINS_RESET_AT:
		wins_x = 0
		wins_o = 0
		reset = true
	_rebuild_tallies()
	return reset


func set_wins(x_wins: int, o_wins: int) -> void:
	wins_x = clampi(x_wins, 0, WINS_RESET_AT - 1)
	wins_o = clampi(o_wins, 0, WINS_RESET_AT - 1)
	_rebuild_tallies()


func reset_scores() -> void:
	wins_x = 0
	wins_o = 0
	_rebuild_tallies()


func cell_at_world(world: Vector3) -> int:
	## Local XZ → cell 0..8, or -1 if outside board. Slightly generous pad for tip aim.
	var local := to_local(world)
	var h := board_size * 0.5
	var pad := board_size * 0.06
	if absf(local.x) > h + pad or absf(local.z) > h + pad:
		return -1
	var u := clampf((local.x + h) / board_size, 0.0, 0.999)
	var v := clampf((local.z + h) / board_size, 0.0, 0.999)
	var col := clampi(int(floor(u * 3.0)), 0, 2)
	var row := clampi(int(floor(v * 3.0)), 0, 2)
	return row * 3 + col


func cell_center_local(cell: int) -> Vector3:
	if cell < 0 or cell >= 9:
		return Vector3.ZERO
	var h := board_size * 0.5
	var third := board_size / 3.0
	var col := cell % 3
	var row := cell / 3
	return Vector3(-h + third * (float(col) + 0.5), 0.0014, -h + third * (float(row) + 0.5))


func set_hover_cell(cell: int) -> void:
	## Ghost mark under the spatula / cursor for the next X or O.
	_ensure_mats()
	_ensure_hover_meshes()
	_hover_cell = cell
	if not revealed or not is_playable() or cell < 0 or cell >= 9 or cells[cell] != EMPTY:
		_hover_mi.visible = false
		_hover_bevel_mi.visible = false
		return
	var third := board_size / 3.0
	var center := cell_center_local(cell)
	_hover_mi.visible = true
	_hover_bevel_mi.visible = true
	_hover_mi.position = center
	_hover_bevel_mi.position = center + Vector3(0.0, -bevel_y, -bevel_z)
	if turn == MARK_X:
		_hover_mi.mesh = _make_x_mesh(third * 0.30, 1.0, 900)
		_hover_bevel_mi.mesh = _make_x_mesh(third * 0.30, bevel_scale, 910)
	else:
		_hover_mi.mesh = _make_o_mesh(third * 0.28, 1.0, 920)
		_hover_bevel_mi.mesh = _make_o_mesh(third * 0.28, bevel_scale, 930)


func clear_hover() -> void:
	_hover_cell = -1
	if _hover_mi != null and is_instance_valid(_hover_mi):
		_hover_mi.visible = false
	if _hover_bevel_mi != null and is_instance_valid(_hover_bevel_mi):
		_hover_bevel_mi.visible = false


func hover_cell() -> int:
	return _hover_cell


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
	clear_hover()
	return true


func apply_state(packed: Array, next_turn: int, win: int, show: bool, x_wins: int = -1, o_wins: int = -1) -> void:
	for i in mini(9, packed.size()):
		cells[i] = int(packed[i])
	while cells.size() < 9:
		cells.append(EMPTY)
	turn = next_turn if next_turn == MARK_X or next_turn == MARK_O else MARK_X
	winner = win
	revealed = show
	visible = show
	scrub_t = 0.0
	if x_wins >= 0:
		wins_x = clampi(x_wins, 0, WINS_RESET_AT)
	if o_wins >= 0:
		wins_o = clampi(o_wins, 0, WINS_RESET_AT)
	_rebuild_marks()
	_rebuild_tallies()


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


func _rebuild_tallies() -> void:
	## Two score strips below the board (−Z / toward cook): X left, O right.
	## Each side = two sets of 5 classic tallies (||||/), reset when either hits 10.
	_ensure_mats()
	if _tally_mi != null and is_instance_valid(_tally_mi):
		_tally_mi.queue_free()
	if _tally_bevel_mi != null and is_instance_valid(_tally_bevel_mi):
		_tally_bevel_mi.queue_free()
	_tally_mi = MeshInstance3D.new()
	_tally_mi.name = "TallyGroove"
	_tally_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tally_mi.material_override = _mat
	_tally_mi.mesh = _make_tally_mesh(1.0, 0.0, 0.0, 500)
	add_child(_tally_mi)
	_tally_bevel_mi = MeshInstance3D.new()
	_tally_bevel_mi.name = "TallyBevel"
	_tally_bevel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tally_bevel_mi.material_override = _bevel_mat
	_tally_bevel_mi.mesh = _make_tally_mesh(bevel_scale, -bevel_y, -bevel_z, 560)
	add_child(_tally_bevel_mi)


func _make_tally_mesh(width_mul: float, y_off: float, z_off: float, seed_add: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := board_size * 0.5
	var y := 0.001 + y_off
	## Just below the frame, toward cook (−Z). Row 1 nearer board, row 2 further cook-side.
	var row1_z := -h - board_size * 0.14 + z_off
	var row2_z := row1_z - board_size * 0.10
	var label_arm := board_size * 0.028
	var lw := mark_w * 0.38 * width_mul
	## Player 1 (X / host) — left strip, two sets of 5
	_noisy_stroke(st, Vector3(-h * 0.92 - label_arm, y, row1_z - label_arm), Vector3(-h * 0.92 + label_arm, y, row1_z + label_arm), lw, scratch_seed + seed_add)
	_noisy_stroke(st, Vector3(-h * 0.92 - label_arm, y, row1_z + label_arm), Vector3(-h * 0.92 + label_arm, y, row1_z - label_arm), lw, scratch_seed + seed_add + 3)
	_emit_tally_sets(st, Vector3(-h * 0.72, y, row1_z), wins_x, width_mul, scratch_seed + seed_add + 10)
	_emit_tally_sets(st, Vector3(-h * 0.72, y, row2_z), maxi(0, wins_x - 5), width_mul, scratch_seed + seed_add + 40)
	## Player 2 (O) — right strip, two sets of 5
	var o_r := board_size * 0.032
	for i in 12:
		var a0 := TAU * float(i) / 12.0
		var a1 := TAU * float(i + 1) / 12.0
		var p0 := Vector3(h * 0.92 + cos(a0) * o_r, y, row1_z + sin(a0) * o_r)
		var p1 := Vector3(h * 0.92 + cos(a1) * o_r, y, row1_z + sin(a1) * o_r)
		_scratch_line(st, p0, p1, lw * 0.9)
	_emit_tally_sets(st, Vector3(h * 0.22, y, row1_z), wins_o, width_mul, scratch_seed + seed_add + 70)
	_emit_tally_sets(st, Vector3(h * 0.22, y, row2_z), maxi(0, wins_o - 5), width_mul, scratch_seed + seed_add + 100)
	return st.commit()


func _emit_tally_sets(st: SurfaceTool, origin: Vector3, count: int, width_mul: float, stroke_seed: int) -> void:
	## One row of up to 5 classic tally marks starting at origin.
	var n := clampi(count, 0, 5)
	if n <= 0:
		return
	var tall := board_size * 0.055
	var gap := board_size * 0.022
	var half_w := mark_w * 0.42 * width_mul
	for i in mini(n, 4):
		var x := origin.x + float(i) * gap
		_noisy_stroke(
			st,
			Vector3(x, origin.y, origin.z - tall * 0.5),
			Vector3(x, origin.y, origin.z + tall * 0.5),
			half_w,
			stroke_seed + i * 5
		)
	if n >= 5:
		## Fifth mark crosses the four.
		_noisy_stroke(
			st,
			Vector3(origin.x - gap * 0.25, origin.y, origin.z + tall * 0.55),
			Vector3(origin.x + gap * 3.25, origin.y, origin.z - tall * 0.55),
			half_w * 1.05,
			stroke_seed + 40
		)


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
