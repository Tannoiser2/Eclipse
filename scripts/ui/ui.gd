class_name UI
extends RefCounted
## Helper grafici condivisi. Tema «spazio profondo»: il nero stellato delle tessere settore, il ciano dei
## progetti delle navi e l'arancio dorato del logo ECLIPSE e dei punti vittoria.
## Caratteri liberi (OFL): Orbitron per titoli e intestazioni (le capitali squadrate della fantascienza),
## Exo 2 per i testi e i numeri, Rajdhani per le etichette strette.

const D = preload("res://scripts/data/ec_data.gd")

const BG := Color("#03050b")
const BG_L := Color("#0b1326")
const PANEL := Color("#0a1222")
const PANEL_L := Color("#13213b")
const LINE := Color("#3fc6ea")
const LINE_D := Color("#1d5671")
const GOLD := Color("#f2a93b")
const GOLD_L := Color("#ffd27e")
const RED := Color("#ff5a4e")
const RED_D := Color("#8c2a24")
const GREEN := Color("#69d98a")
const TEXT := Color("#e8eef8")
const MUTED := Color("#8e9cb8")
const INK := Color("#060a14")
const PINK := Color("#e690c4")
const BROWN := Color("#b0703c")
const RES_COL := {"m": Color("#b8743e"), "s": Color("#e48ac0"), "$": Color("#f2b630")}

static var _tex := {}
static var font_title: Font
static var font_head: Font
static var font_head_r: Font
static var font_body: Font
static var font_semi: Font
static var font_bold: Font
static var font_italic: Font
static var font_cond: Font
static var font_cond_b: Font


static func _var(path: String, w: int) -> Font:
	var base: FontFile = load(path)
	if path.ends_with("Orbitron.ttf"):
		# i pochi segni che Orbitron non ha («, », ·) li prende da Exo 2
		var fb: FontFile = load("res://assets/fonts/Exo2.ttf")
		base.fallbacks = [fb]
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: w}
	return fv


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = _var("res://assets/fonts/Orbitron.ttf", 900)
	font_head = _var("res://assets/fonts/Orbitron.ttf", 700)
	font_head_r = _var("res://assets/fonts/Orbitron.ttf", 500)
	font_body = _var("res://assets/fonts/Exo2.ttf", 400)
	font_semi = _var("res://assets/fonts/Exo2.ttf", 600)
	font_bold = _var("res://assets/fonts/Exo2.ttf", 750)
	font_italic = _var("res://assets/fonts/Exo2-Italic.ttf", 450)
	font_cond = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	font_cond_b = load("res://assets/fonts/Rajdhani-Bold.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func sector_tex(n: int) -> Texture2D:
	return tex("res://assets/settori/%d.jpg" % n)


static func tech_tex(t: String) -> Texture2D:
	return tex("res://assets/tecnologie/%s.jpg" % t)


static func part_tex(pt: String) -> Texture2D:
	var P: Dictionary = D.PARTS.get(pt, {})
	if P.has("img"):
		return tex("res://assets/scoperte/%s.jpg" % P["img"])
	return tex("res://assets/parti/%s.jpg" % pt)


static func disc_tex(tile: Dictionary) -> Texture2D:
	if tile.get("k", "") == "part":
		return part_tex(tile["part"])
	return tex("res://assets/scoperte/%s.jpg" % tile.get("img", "retro"))


static func res_tex(r: String) -> Texture2D:
	return tex("res://assets/icone/%s.png" % {"m": "materiali", "s": "scienza", "$": "denaro"}[r])


static func pcolor(e, p: int) -> Color:
	if p < 0:
		return Color("#9aa4b5")
	return D.COLORS[e.pcol(p)]["c"]


static func panel_style(bg: Color, border: Color = LINE, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func dark_style(radius := 8, alpha := 0.94) -> StyleBoxFlat:
	var sb := panel_style(Color(PANEL, alpha), Color(LINE, 0.55), 2, radius)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 12
	return sb


static func label(text: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func title(text: String, size := 48, col := GOLD_L) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(GOLD, 0.35))
	l.add_theme_constant_override("shadow_outline_size", maxi(4, size / 8))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


static func heading(text: String, size := 22, col := LINE) -> Label:
	init_fonts()
	return label(text, size, col, font_head)


## Etichetta che va a capo: larghezza minima fissata, così non si schiaccia mai in colonna.
static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, w := 200.0, h := 46.0, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.clip_text = false
	return b


static func primary(b: Button) -> Button:
	init_fonts()
	b.add_theme_stylebox_override("normal", _btn(Color("#7a3d0c"), GOLD))
	b.add_theme_stylebox_override("hover", _btn(Color("#a5541a"), GOLD_L))
	b.add_theme_stylebox_override("pressed", _btn(GOLD, GOLD_L))
	b.add_theme_stylebox_override("disabled", _btn(Color("#2a1d14"), Color("#3b2a1b")))
	b.add_theme_color_override("font_color", GOLD_L)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_override("font", font_head)
	return b


static func danger(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _btn(RED_D, RED))
	b.add_theme_stylebox_override("hover", _btn(Color("#b33a31"), Color("#ff8a80")))
	return b


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.corner_detail = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	return sb


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 21
	th.set_stylebox("normal", "Button", _btn(Color("#0d1c33"), Color("#2b6f8f")))
	th.set_stylebox("hover", "Button", _btn(Color("#143055"), LINE))
	th.set_stylebox("pressed", "Button", _btn(LINE, Color("#a8ecff")))
	th.set_stylebox("hover_pressed", "Button", _btn(Color("#a8ecff"), Color("#a8ecff")))
	th.set_stylebox("disabled", "Button", _btn(Color("#0a1222"), Color("#16263c")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color("#bff2ff"))
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_hover_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("#44536b"))
	th.set_font("font", "Button", font_semi)
	th.set_font_size("font_size", "Button", 21)
	th.set_color("font_color", "Label", TEXT)
	var pn := StyleBoxFlat.new()
	pn.bg_color = PANEL
	th.set_stylebox("panel", "Panel", pn)
	th.set_stylebox("panel", "PanelContainer", pn)
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	th.set_font("mono_font", "RichTextLabel", font_head_r)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
		th.set_font_size(k, "RichTextLabel", 21)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("font", "LineEdit", font_semi)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", Color("#5f6f8c"))
	th.set_color("caret_color", "LineEdit", LINE)
	th.set_stylebox("normal", "LineEdit", panel_style(Color("#07101f"), LINE_D, 2, 4))
	th.set_stylebox("focus", "LineEdit", panel_style(Color("#0b1830"), LINE, 2, 4))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 19)
	th.set_color("font_color", "TooltipLabel", TEXT)
	var tp := panel_style(PANEL_L, LINE, 2, 4)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(LINE, 0.8)
	sc.set_corner_radius_all(3)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(k, "VScrollBar", sc)
		th.set_stylebox(k, "HScrollBar", sc)
		th.set_stylebox(k, "HSlider", sc)
	var sct := StyleBoxFlat.new()
	sct.bg_color = Color(1, 1, 1, 0.06)
	th.set_stylebox("scroll", "VScrollBar", sct)
	th.set_stylebox("scroll", "HScrollBar", sct)
	# menu a tendina
	th.set_stylebox("normal", "OptionButton", _btn(Color("#0d1c33"), Color("#2b6f8f")))
	th.set_stylebox("hover", "OptionButton", _btn(Color("#143055"), LINE))
	th.set_stylebox("pressed", "OptionButton", _btn(Color("#143055"), LINE))
	th.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	th.set_font("font", "PopupMenu", font_semi)
	th.set_font_size("font_size", "PopupMenu", 21)
	th.set_stylebox("panel", "PopupMenu", panel_style(PANEL_L, LINE, 2, 4))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", GOLD_L)
	var hv := StyleBoxFlat.new()
	hv.bg_color = Color(LINE, 0.25)
	th.set_stylebox("hover", "PopupMenu", hv)
	return th


## Sfondo: cielo stellato con due nebulose (disegnato, sempre uguale).
class Backdrop extends Control:
	var stars := []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in 520:
			stars.append([Vector2(r.randf(), r.randf()), r.randf_range(0.6, 2.1), r.randf_range(0.25, 1.0)])
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
		# nebulose: cerchi sfumati sovrapposti
		for neb in [[Vector2(0.78, 0.28), Color("#6a2d7a"), 0.55], [Vector2(0.18, 0.78), Color("#1f3f8a"), 0.5], [Vector2(0.55, 0.6), Color("#8a4a1a"), 0.3]]:
			var c: Vector2 = neb[0] * size
			var rad: float = size.length() * float(neb[2])
			for k in 16:
				var f := 1.0 - float(k) / 16.0
				draw_circle(c, rad * f, Color(neb[1], 0.035))
		for s in stars:
			var p: Vector2 = s[0] * size
			draw_circle(p, s[1], Color(1, 1, 1, s[2]))


## Icona di una risorsa con il numero accanto.
static func res_chip(r: String, value: String, size := 22, w := 0.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(icon_rect(res_tex(r), Vector2(size + 6, size + 6)))
	var l := label(value, size, TEXT, font_bold)
	if w > 0:
		l.custom_minimum_size.x = w
	h.add_child(l)
	return h


## Riquadro colorato (cubetto, disco…) disegnato.
class Swatch extends Control:
	var col := Color.WHITE
	var round_shape := false
	var border := Color(0, 0, 0, 0.6)

	func _init(c: Color = Color.WHITE, sz := Vector2(18, 18), rnd := false) -> void:
		col = c
		custom_minimum_size = sz
		round_shape = rnd
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if round_shape:
			var r := minf(size.x, size.y) * 0.5
			draw_circle(size * 0.5, r, border)
			draw_circle(size * 0.5, r - 2, col)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), border)
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), col)
