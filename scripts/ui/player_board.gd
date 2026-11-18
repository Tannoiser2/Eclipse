class_name ECPlayerBoard
extends Control
## Plancia della civiltà disegnata sull'immagine originale, con tessere tecnologia, parti montate sui
## progetti, dischi influenza (sul tracciato e sulle azioni), reputazione e ambasciatori.
## Con kind = "scorte" disegna invece la plancia dei tracciati di popolazione (cubetti) e delle scorte.

const D = preload("res://scripts/data/ec_data.gd")
const UI = preload("res://scripts/ui/ui.gd")

const BW := 2000.0        # misure prese sull'immagine larga 2000 punti
const BH := 1117.0
const CELL := 118.0

## Caselle dei progetti (centri) per ogni disposizione della plancia, nell'ordine di bp_base.
const INT_STD := [Vector2(100, 257), Vector2(230, 155), Vector2(230, 290), Vector2(360, 257)]
const CRU_STD := [Vector2(560, 215), Vector2(690, 155), Vector2(820, 215), Vector2(560, 345), Vector2(690, 290), Vector2(820, 345)]
const DRE_STD := [Vector2(1035, 215), Vector2(1165, 155), Vector2(1292, 155), Vector2(1420, 215), Vector2(1035, 345), Vector2(1165, 290), Vector2(1292, 290), Vector2(1420, 345)]
const SB_STD := [Vector2(1620, 155), Vector2(1748, 215), Vector2(1875, 155), Vector2(1620, 290), Vector2(1875, 290)]
const LAYOUT := {
	"std": {"int": INT_STD, "cru": CRU_STD, "dre": DRE_STD, "sb": SB_STD},
	"orion": {"int": INT_STD, "cru": CRU_STD, "dre": DRE_STD, "sb": SB_STD},
	"planta": {"int": [Vector2(100, 257), Vector2(230, 155), Vector2(360, 257)],
		"cru": [Vector2(560, 215), Vector2(690, 155), Vector2(820, 215), Vector2(690, 290), Vector2(820, 345)],
		"dre": [Vector2(1035, 215), Vector2(1165, 155), Vector2(1292, 155), Vector2(1420, 215), Vector2(1165, 290), Vector2(1292, 290), Vector2(1420, 345)],
		"sb": [Vector2(1620, 155), Vector2(1748, 238), Vector2(1875, 155), Vector2(1875, 290)]},
	"exiles": {"int": INT_STD, "cru": CRU_STD, "dre": DRE_STD,
		"orb": [Vector2(1620, 290), Vector2(1748, 238), Vector2(1875, 160)]},
	"rho": {"int": INT_STD, "sb": SB_STD,
		"cru": [Vector2(870, 215), Vector2(1000, 155), Vector2(1130, 215), Vector2(870, 345), Vector2(1000, 290), Vector2(1130, 345)]},
}
const TECH_X := [742.0, 902.0, 1060.0, 1218.0, 1376.0, 1535.0, 1695.0]
const TECH_Y := {"mil": 532.0, "grid": 707.0, "nano": 882.0}
const TECH_SZ := 140.0
const INF_Y := 1045.0
const ACT_X := {"exp": 75.0, "res": 177.0, "upg": 281.0, "bui": 384.0, "mov": 488.0, "inf": 592.0}
const ACT_Y := 985.0
const REP_X := 1905.0
const REP_Y := [410.0, 585.0, 740.0, 890.0, 1040.0]

# plancia delle scorte (immagine 2048x986, misure su 1960x944)
const SW := 1960.0
const SH := 944.0
const PETALS := [Vector2(100, 350), Vector2(178, 265), Vector2(290, 225), Vector2(415, 238), Vector2(512, 305),
	Vector2(568, 410), Vector2(568, 540), Vector2(515, 640), Vector2(418, 710), Vector2(290, 725), Vector2(178, 685), Vector2(100, 595)]
const DIAL_DX := {"m": 0.0, "s": 605.0, "$": 1207.0}

var engine
var p := 0
var kind := "plancia"
var show_rep := false
var _tips := []   # [Rect2, testo]
signal clicked


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		clicked.emit()


func setup(e, player: int, k := "plancia", rep_visible := false) -> ECPlayerBoard:
	engine = e
	p = player
	kind = k
	show_rep = rep_visible
	tooltip_text = " "
	mouse_filter = Control.MOUSE_FILTER_PASS
	return self


func aspect() -> float:
	return (BH / BW) if kind == "plancia" else (SH / SW)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _get_tooltip(at: Vector2) -> String:
	for t in _tips:
		if (t[0] as Rect2).has_point(at):
			return t[1]
	return ""


func _draw() -> void:
	_tips.clear()
	if engine == null or p >= engine.ps.size():
		return
	if kind == "plancia":
		_draw_board()
	else:
		_draw_storage()


# ---------------------------------------------------------------- plancia

func _pt(v: Vector2) -> Vector2:
	return Vector2(v.x / BW * size.x, v.y / BH * size.y)


func _len(l: float) -> float:
	return l / BW * size.x


func _tile(t: Texture2D, c: Vector2, sz: float, tip: String) -> void:
	var s := _len(sz)
	var r := Rect2(_pt(c) - Vector2(s, s) / 2, Vector2(s, s))
	if t != null:
		draw_texture_rect(t, r, false)
	draw_rect(r, Color(0, 0, 0, 0.7), false, maxf(1.0, s * 0.03))
	_tips.append([r, tip])


func _disc(c: Vector2, r: float, col: Color) -> void:
	var pc := _pt(c)
	var rr := _len(r)
	draw_circle(pc + Vector2(rr * 0.12, rr * 0.16), rr, Color(0, 0, 0, 0.55))
	draw_circle(pc, rr, col.darkened(0.25))
	draw_circle(pc - Vector2(0, rr * 0.12), rr * 0.86, col)
	draw_arc(pc - Vector2(0, rr * 0.12), rr * 0.86, 0, TAU, 32, col.lightened(0.35), maxf(1.0, rr * 0.1))


func _text(s: String, c: Vector2, fsize: float, col := Color.WHITE) -> void:
	var f: Font = UI.font_cond_b if UI.font_cond_b != null else ThemeDB.fallback_font
	var fs := maxi(9, int(_len(fsize)))
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := _pt(c) + Vector2(-w / 2, fs * 0.35)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 5), Color(0, 0, 0, 0.9))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_board() -> void:
	var e = engine
	var st: Dictionary = e.ps[p]
	var S: Dictionary = st["S"]
	var tex := UI.tex("res://assets/plance/%s.jpg" % st["sp"])
	if tex == null:
		tex = UI.tex("res://assets/plance/terran_directorate.jpg")
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	var col: Color = UI.pcolor(e, p)
	# parti montate sui progetti
	var lay: Dictionary = LAYOUT.get(str(S.get("bp", "std")), LAYOUT["std"])
	for s in st["types"]:
		if not lay.has(s):
			continue
		var pos: Array = lay[s]
		var bp: Array = st["bp"].get(s, [])
		for i in mini(bp.size(), pos.size()):
			var pt: String = str(bp[i])
			if pt != "":
				_tile(UI.part_tex(pt), pos[i], CELL, "%s: %s" % [D.SHIP_NAME[s], D.part_name(pt)])
	# tecnologie
	for c in D.TECH_CATS:
		var list: Array = st["techs"][c]
		for i in mini(list.size(), 7):
			_tile(UI.tech_tex(list[i]), Vector2(TECH_X[i], TECH_Y[c]), TECH_SZ, "%s: %s" % [D.tech_name(list[i]), D.TECHS[list[i]]["txt"]])
	# dischi sul tracciato dell'influenza (occupano le caselle più a destra)
	var dsc: int = clampi(int(st["discs"]), 0, 13)
	for i in dsc:
		_disc(Vector2(720 + 86 * (12 - i), INF_Y), 30, col)
	var ir := Rect2(_pt(Vector2(680, 1000)), _pt(Vector2(1800, 1095)) - _pt(Vector2(680, 1000)))
	_tips.append([ir, "Dischi influenza sul tracciato: %d. Mantenimento a fine round: %d denaro." % [int(st["discs"]), e.upkeep(p)]])
	# dischi sulle azioni usate in questo round
	for a in D.ACTIONS:
		var used := int(st["acts_used"].get(a, 0))
		if used <= 0:
			continue
		_disc(Vector2(ACT_X[a], ACT_Y - 10), 34, col)
		if used > 1:
			_text("x%d" % used, Vector2(ACT_X[a], ACT_Y - 8), 34)
	if st.get("passed", false):
		_text("HA PASSATO", Vector2(330, 900), 56, UI.GOLD_L)
	# reputazione e ambasciatori
	var slots: Array = e.rep_slots(p)
	var ys: Array = REP_Y.slice(REP_Y.size() - mini(slots.size(), REP_Y.size()))
	var free := []
	for i in ys.size():
		free.append(i)
	var place := []
	for en in st["rep"]:
		var want := "A" if en["k"] == "A" else "R"
		var pick := -1
		for i in free:
			if (want == "A" and slots[i] == "A") or (want == "R" and slots[i] == "X"):
				pick = i
				break
		if pick < 0:
			for i in free:
				if slots[i] == "X":
					pick = i
					break
		if pick < 0 and not free.is_empty():
			pick = free[0]
		if pick < 0:
			break
		free.erase(pick)
		place.append([pick, en])
	for pe in place:
		var c := Vector2(REP_X, ys[pe[0]])
		var en: Dictionary = pe[1]
		if en["k"] == "R":
			if show_rep:
				_tile(UI.tex("res://assets/reputazione/%d.jpg" % int(en["v"])), c, 120, "Tessera reputazione: %d PV" % int(en["v"]))
			else:
				var s := _len(110)
				var r := Rect2(_pt(c) - Vector2(s, s) / 2, Vector2(s, s))
				draw_rect(r, UI.GOLD.darkened(0.35))
				draw_rect(r.grow(-s * 0.08), UI.GOLD)
				_text("?", c + Vector2(0, 8), 60, UI.INK)
				_tips.append([r, "Tessera reputazione coperta"])
		else:
			var fc: Color = UI.pcolor(e, int(en.get("from", -1)))
			if en.has("minor"):
				fc = UI.GREEN
			_disc(c, 42, fc)
			_text("A", c, 44, UI.INK)
			var who: String = D.MINORS[en["minor"]]["name"] if en.has("minor") else e.pname(int(en.get("from", -1)))
			_tips.append([Rect2(_pt(c) - Vector2(_len(45), _len(45)), Vector2(_len(90), _len(90))), "Ambasciatore: " + who])


# ---------------------------------------------------------------- scorte

func _sp(v: Vector2) -> Vector2:
	return Vector2(v.x / SW * size.x, v.y / SH * size.y)


func _track_pos(v: int) -> Vector2:
	v = posmod(v, 40)
	if v <= 15:
		return Vector2(128 + 112.5 * v, 45)
	if v <= 23:
		return Vector2(1885, 110 + 105 * (v - 16))
	return Vector2(1815 - 112.5 * (v - 24), 905)


func _cube(c: Vector2, s: float, col: Color) -> void:
	var r := Rect2(c - Vector2(s, s) / 2, Vector2(s, s))
	draw_rect(Rect2(r.position + Vector2(s * 0.12, s * 0.15), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, col.darkened(0.3))
	draw_rect(r.grow(-s * 0.12), col)
	draw_rect(Rect2(r.position + Vector2(s * 0.12, s * 0.12), Vector2(s * 0.76, s * 0.22)), col.lightened(0.3))


func _draw_storage() -> void:
	var e = engine
	var st: Dictionary = e.ps[p]
	draw_texture_rect(UI.tex("res://assets/plance/scorte.jpg"), Rect2(Vector2.ZERO, size), false)
	var col: Color = UI.pcolor(e, p)
	var k := size.x / SW
	for r in D.RES:
		var c: int = clampi(int(st["track"][r]), 0, 11)
		var dx: float = DIAL_DX[r]
		# cubetti sui petali più alti: quello scoperto più a destra è la produzione
		for i in range(12 - c, 12):
			_cube(_sp(PETALS[i] + Vector2(dx, 0)), 46 * k, col)
		var prod: int = e.prod(p, r)
		var ctr := _sp(Vector2(315 + dx, 470))
		var f: Font = UI.font_head if UI.font_head != null else ThemeDB.fallback_font
		var fs := maxi(10, int(70 * k))
		var line1 := "+%d" % prod
		var w1 := f.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, ctr + Vector2(-w1 / 2, -fs * 0.1), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.RES_COL[r].lightened(0.2))
		var f2: Font = UI.font_cond_b if UI.font_cond_b != null else ThemeDB.fallback_font
		var fs2 := maxi(9, int(36 * k))
		var line2 := "a round"
		var w2 := f2.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f2, ctr + Vector2(-w2 / 2, fs2 * 1.2), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.MUTED)
		var dr := Rect2(_sp(Vector2(40 + dx, 180)), _sp(Vector2(600 + dx, 770)) - _sp(Vector2(40 + dx, 180)))
		_tips.append([dr, "Tracciato di popolazione (%s): %d cubetti ancora sul tracciato, produzione %d a round." % [D.RES_NAME[r].to_lower(), c, prod]])
	# segnalini delle scorte sul tracciato esterno
	var off := {"m": Vector2(-22, -16), "s": Vector2(0, 14), "$": Vector2(22, -16)}
	for r in D.RES:
		var v: int = int(st["res"][r])
		var c2 := _sp(_track_pos(maxi(v, 0)) + off[r])
		_cube(c2, 40 * k, UI.RES_COL[r])
		if v >= 40 or v < 0:
			var f3: Font = UI.font_cond_b if UI.font_cond_b != null else ThemeDB.fallback_font
			draw_string_outline(f3, c2 + Vector2(-16 * k, 50 * k), "%+d" % (40 * int(floor(v / 40.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(30 * k)), 3, Color.BLACK)
			draw_string(f3, c2 + Vector2(-16 * k, 50 * k), "%+d" % (40 * int(floor(v / 40.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(30 * k)), UI.GOLD_L)
		_tips.append([Rect2(c2 - Vector2(30, 30) * k, Vector2(60, 60) * k), "Scorta di %s: %d" % [D.RES_NAME[r].to_lower(), v]])
	# navi coloniali (in basso al centro, nel riquadro scuro sotto i quadranti)
	var n: int = int(st["colony"])
	var used: int = int(st["colony_used"])
	for i in n:
		var c3 := _sp(Vector2(820 + i * 110 - (n - 1) * 55, 830))
		var cc: Color = Color(0.25, 0.25, 0.3) if i < used else Color(0.92, 0.92, 0.95)
		draw_colored_polygon(_octa(c3, 34 * k), cc)
		draw_polyline(_octa(c3, 34 * k) + PackedVector2Array([_octa(c3, 34 * k)[0]]), Color.BLACK, maxf(1.0, 3 * k))
	var nr := Rect2(_sp(Vector2(700, 790)), _sp(Vector2(1260, 870)) - _sp(Vector2(700, 790)))
	_tips.append([nr, "Navi coloniali: %d pronte su %d (si girano di nuovo a fine round)." % [n - used, n]])


func _octa(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		pts.append(c + Vector2(cos(a) * r * 1.25, sin(a) * r * 0.8))
	return pts
