## Bundled display fonts for a punchier food-truck look.
extends RefCounted

const TITLE_PATH := "res://assets/fonts/Fredoka-Bold.ttf"
const TITLE_SEMI_PATH := "res://assets/fonts/Fredoka-SemiBold.ttf"
const BODY_PATH := "res://assets/fonts/Nunito-Bold.ttf"
const BODY_HEAVY_PATH := "res://assets/fonts/Nunito-ExtraBold.ttf"
## Amatic SC — handwritten look that stays clear in ALL CAPS.
const HAND_PATH := "res://assets/fonts/AmaticSC-Bold.ttf"

static var title: Font
static var title_semi: Font
static var body: Font
static var body_heavy: Font
static var handwritten: Font
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	title = load(TITLE_PATH) as Font
	title_semi = load(TITLE_SEMI_PATH) as Font
	body = load(BODY_PATH) as Font
	body_heavy = load(BODY_HEAVY_PATH) as Font
	handwritten = load(HAND_PATH) as Font
	_loaded = true


static func apply_label(label: Label, use_title: bool = false, size: int = -1) -> void:
	ensure_loaded()
	var f: Font = title if use_title else body
	if f:
		label.add_theme_font_override("font", f)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)


static func apply_handwritten(label: Label, size: int = 22) -> void:
	ensure_loaded()
	if handwritten:
		label.add_theme_font_override("font", handwritten)
	if size > 0:
		label.add_theme_font_size_override("font_size", size)


static func apply_button(btn: Button, use_title: bool = true, size: int = -1) -> void:
	ensure_loaded()
	var f: Font = title_semi if use_title else body
	if f:
		btn.add_theme_font_override("font", f)
	if size > 0:
		btn.add_theme_font_size_override("font_size", size)


## Crisp in-world text — high glyph res, no mip blur, modest outline.
static func apply_label3d(lab: Label3D, use_title: bool = true, font_size: int = 64, world_height: float = 0.078) -> void:
	ensure_loaded()
	var f: Font = title if use_title else body_heavy
	if f:
		lab.font = f
	lab.font_size = font_size
	lab.pixel_size = world_height / float(font_size)
	lab.outline_size = 6
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
