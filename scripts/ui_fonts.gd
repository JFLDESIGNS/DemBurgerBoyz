## Bundled display fonts for a punchier food-truck look.
extends RefCounted

const TITLE_PATH := "res://assets/fonts/Fredoka-Bold.ttf"
const TITLE_SEMI_PATH := "res://assets/fonts/Fredoka-SemiBold.ttf"
const BODY_PATH := "res://assets/fonts/Nunito-Bold.ttf"
const BODY_HEAVY_PATH := "res://assets/fonts/Nunito-ExtraBold.ttf"
## Amatic SC — tall casual caps (legacy / Label3D accents).
const HAND_PATH := "res://assets/fonts/AmaticSC-Bold.ttf"
## Caveat — real pen handwriting for order tickets.
const TICKET_HAND_PATH := "res://assets/fonts/Caveat-Variable.ttf"

static var title: Font
static var title_semi: Font
static var body: Font
static var body_heavy: Font
static var handwritten: Font
static var ticket_hand: Font
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	title = _load_clean(TITLE_PATH)
	title_semi = _load_clean(TITLE_SEMI_PATH)
	body = _load_clean(BODY_PATH)
	body_heavy = _load_clean(BODY_HEAVY_PATH)
	handwritten = _load_clean(HAND_PATH)
	ticket_hand = _load_clean(TICKET_HAND_PATH)
	_loaded = true


## Force raster (non-MSDF) settings — MSDF + bold fills looked full of holes.
static func _load_clean(path: String) -> Font:
	var f := load(path)
	if f is FontFile:
		var ff := f as FontFile
		ff.multichannel_signed_distance_field = false
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.oversampling = 2.0
		ff.generate_mipmaps = false
		return ff
	return f as Font


static func apply_label(label: Label, use_title: bool = false, size: int = -1) -> void:
	ensure_loaded()
	var f: Font = title if use_title else body
	if f:
		label.add_theme_font_override("font", f)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)


## Order tickets — Caveat handwriting (marker-on-slip), no outline.
static func apply_ticket(label: Label, size: int = 26) -> void:
	ensure_loaded()
	if ticket_hand:
		label.add_theme_font_override("font", ticket_hand)
	elif handwritten:
		label.add_theme_font_override("font", handwritten)
	elif body_heavy:
		label.add_theme_font_override("font", body_heavy)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)


static func apply_handwritten(label: Label, size: int = 22) -> void:
	ensure_loaded()
	if handwritten:
		label.add_theme_font_override("font", handwritten)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)


static func apply_button(btn: Button, use_title: bool = true, size: int = -1) -> void:
	ensure_loaded()
	var f: Font = title_semi if use_title else body
	if f:
		btn.add_theme_font_override("font", f)
	if size > 0:
		btn.add_theme_font_size_override("font_size", size)


## Crisp in-world text — modest outline (fonts are non-MSDF for clean edges).
static func apply_label3d(lab: Label3D, use_title: bool = true, font_size: int = 64, world_height: float = 0.078) -> void:
	ensure_loaded()
	var f: Font = body_heavy if use_title else body
	if f == null:
		f = title if use_title else body_heavy
	if f:
		lab.font = f
	lab.font_size = font_size
	lab.pixel_size = world_height / float(font_size)
	lab.outline_size = 3
	lab.outline_modulate = Color(0, 0, 0, 1)
	lab.shaded = false
	lab.double_sided = true
	lab.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR


static func make_theme() -> Theme:
	ensure_loaded()
	var t := Theme.new()
	if body:
		t.default_font = body
	t.default_font_size = 14
	if body:
		t.set_font("font", "Label", body)
		t.set_font("font", "Button", body)
		t.set_font("font", "LineEdit", body)
	if title:
		t.set_font("font", "HeaderLarge", title)
	return t
