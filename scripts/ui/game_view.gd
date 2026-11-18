extends Control
## Schermata di gioco: la galassia in 3D a tutto schermo, la plancia della civiltà a destra, i comandi in alto
## e la barra delle decisioni in basso. Le scelte si fanno con i pulsanti, nelle finestre (tecnologie,
## progetti delle navi, scoperte) o toccando gli esagoni della mappa.

const D = preload("res://scripts/data/ec_data.gd")
const SIDE_W := 540.0
var side_tab := 0

var main
var config := {}
var engine: ECEngine
var board
var side: PanelContainer
var side_scroll: ScrollContainer
var side_box: VBoxContainer
var round_lbl: Label
var chips_box: HBoxContainer
var log_panel: PanelContainer
var log_box: RichTextLabel
var prompt: PanelContainer
var prompt_title: Label
var prompt_box: HFlowContainer
var popup_layer: Control
var toast_box: VBoxContainer
var wait_lbl: Label
var dice_panel: PanelContainer
var pending := {}
var aux := {}
var focus_p := 0
var _dirty := true
var save_code := ""
var humans: Array = []
var info_hex := ""
var tutorial = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = ECEngine.new()
	add_child(engine)
	if not config.has("seed"):
		config["seed"] = 1 + randi() % 2000000000
	engine.setup(config)
	for i in engine.n:
		var st: Dictionary = config["seats"][i]
		engine.ais[i] = ECAI.new(int(st.get("level", 1)), int(config["seed"]) + i * 31)
		if not st.get("ai", false):
			humans.append(i)
	focus_p = humans[0] if not humans.is_empty() else 0
	if config.has("online"):
		engine.online = config["online"]
		add_child(engine.online)
		engine.online.view = self
		focus_p = engine.online.seat
		humans = [engine.online.seat]
		engine.online.heartbeat_loop()
	_build()
	engine.changed.connect(func(): _dirty = true)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.fx.connect(_on_fx)
	engine.game_ended.connect(_on_end)
	board.fit.call_deferred()
	engine.run.call_deferred()


func _exit_tree() -> void:
	if engine != null:
		engine.abort = true
		engine.provide_decision(null)


# ================================================================ struttura

func _build() -> void:
	board = preload("res://scripts/ui/board_3d.gd").new()
	board.anchor_right = 1.0
	board.anchor_bottom = 1.0
	board.offset_right = -SIDE_W
	add_child(board)
	board.setup(engine)
	board.hex_pressed.connect(_on_hex)

	# barra in alto
	var top := HBoxContainer.new()
	top.position = Vector2(12, 10)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	for it in [["Menu", _ask_menu], ["Regole", _show_rules], ["Salva", _save_game], ["Inquadra", func(): board.fit()],
			["+", func(): _zoom(1.25)], ["-", func(): _zoom(0.8)], ["Diario", _toggle_log], ["Punti", _show_scores]]:
		var b := UI.button(it[0], 0, 48, 19)
		b.custom_minimum_size.x = 54 if it[0].length() <= 1 else 0
		b.pressed.connect(it[1])
		top.add_child(b)
	round_lbl = UI.label("", 22, UI.GOLD_L, UI.font_head)
	round_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	round_lbl.add_theme_constant_override("outline_size", 6)
	round_lbl.position = Vector2(14, 66)
	add_child(round_lbl)
	chips_box = HBoxContainer.new()
	chips_box.position = Vector2(12, 100)
	chips_box.add_theme_constant_override("separation", 6)
	add_child(chips_box)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(16, 196)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	wait_lbl = UI.label("", 22, UI.GOLD_L, UI.font_semi)
	wait_lbl.position = Vector2(16, 166)
	wait_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	wait_lbl.add_theme_constant_override("outline_size", 6)
	add_child(wait_lbl)

	# tutorial (riquadro in alto a destra della mappa)
	if config.get("tutorial", false):
		tutorial = preload("res://scripts/ui/tutorial.gd").new()
		tutorial.gv = self
		add_child(tutorial)
		_place_tutorial.call_deferred()
		get_viewport().size_changed.connect(_place_tutorial)

	# diario (in basso a sinistra, si apre e si chiude)
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.dark_style(8, 0.88))
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 12
	log_panel.offset_right = 560
	log_panel.offset_top = -420
	log_panel.offset_bottom = -150
	log_panel.visible = false
	add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 17)
	log_panel.add_child(log_box)

	# dadi della battaglia
	dice_panel = PanelContainer.new()
	dice_panel.add_theme_stylebox_override("panel", UI.dark_style(10, 0.92))
	dice_panel.anchor_left = 0.5
	dice_panel.anchor_right = 0.5
	dice_panel.position = Vector2(0, 150)
	dice_panel.visible = false
	dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dice_panel)

	# barra delle decisioni
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.dark_style(10, 0.94))
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.anchor_right = 1.0
	prompt.offset_left = 12
	prompt.offset_right = -SIDE_W - 12
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.offset_bottom = -12
	add_child(prompt)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	prompt.add_child(pv)
	prompt_title = UI.wrap(UI.label("", 22, UI.TEXT, UI.font_semi), 600)
	prompt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(prompt_title)
	prompt_box = HFlowContainer.new()
	prompt_box.add_theme_constant_override("h_separation", 8)
	prompt_box.add_theme_constant_override("v_separation", 8)
	pv.add_child(prompt_box)
	prompt.visible = false

	# plancia a destra
	side = PanelContainer.new()
	var ss := UI.panel_style(Color(UI.PANEL, 0.97), Color(UI.LINE, 0.5), 0, 0)
	ss.border_width_left = 2
	ss.set_content_margin_all(10)
	side.add_theme_stylebox_override("panel", ss)
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -SIDE_W
	add_child(side)
	side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	side_box = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 8)
	side_box.custom_minimum_size.x = SIDE_W - 34
	side_scroll.add_child(side_box)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()


func _zoom(f: float) -> void:
	board.dist = clampf(board.dist / f, 2.0, 40.0)
	board._cam()


func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible


# ================================================================ aggiornamento

const PHASES := {"action": "Azioni", "combat": "Combattimento", "upkeep": "Mantenimento", "cleanup": "Pulizia", "over": "Fine"}


func _refresh() -> void:
	var e := engine
	round_lbl.text = "ROUND %d / 8  -  %s" % [e.round_n, PHASES.get(e.phase, "")]
	for c in chips_box.get_children():
		c.queue_free()
	for p in e.n:
		chips_box.add_child(_chip(p))
	board.refresh()
	_side()


func _chip(p: int) -> Control:
	var e := engine
	var st: Dictionary = e.ps[p]
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 64)
	var cur := e.current == p and e.phase == "action"
	var sb := UI._btn(Color(UI.pcolor(e, p).darkened(0.72), 0.95), UI.GOLD_L if cur else (UI.LINE if p == focus_p else UI.pcolor(e, p).darkened(0.2)))
	sb.set_border_width_all(3 if cur or p == focus_p else 2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(func():
		focus_p = p
		_dirty = true)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8
	vb.offset_top = 4
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var nm := UI.label(e.pname(p), 17, UI.TEXT, UI.font_bold)
	nm.clip_text = true
	nm.custom_minimum_size.x = 182
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var info := "%d PV" % e.score(p)["totale"]
	if st["eliminated"]:
		info = "eliminato"
	elif st["passed"] and e.phase == "action":
		info += " · passato"
	var l2 := UI.label(info, 16, UI.MUTED, UI.font_semi)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(l2)
	return b


# ---------------------------------------------------------------- plancia

func _side() -> void:
	for c in side_box.get_children():
		c.queue_free()
	var e := engine
	var p := focus_p
	var st: Dictionary = e.ps[p]
	var S: Dictionary = st["S"]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UI.Swatch.new(UI.pcolor(e, p), Vector2(30, 30), true))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	var t := UI.label(e.pname(p), 24, UI.GOLD_L, UI.font_head)
	t.clip_text = true
	t.custom_minimum_size.x = SIDE_W - 120
	hv.add_child(t)
	hv.add_child(UI.label(D.species_title(st["sp"]), 18, UI.LINE, UI.font_semi))
	head.add_child(hv)
	side_box.add_child(head)
	var abil := UI.wrap(UI.label(str(S.get("txt", "")), 16, UI.MUTED, UI.font_italic), SIDE_W - 40)
	side_box.add_child(abil)
	_side_tabs(p, st)
	if side_tab == 2:
		_side_details(p, st, S)
	# espansioni: specie minori, santuari, scoperta dei Custodi
	if not st["minors"].is_empty():
		var mn := []
		for m in st["minors"]:
			mn.append(D.MINORS[m]["name"])
		side_box.add_child(UI.wrap(UI.label("Specie minori alleate: " + ", ".join(mn), 16, UI.GREEN), SIDE_W - 40))
	if st["S"].get("shrines", false):
		side_box.add_child(UI.wrap(UI.label("Santuari costruiti: %d su 9" % st["shrines"].size(), 16, UI.GOLD_L), SIDE_W - 40))
	if not st["tech_disc"].is_empty():
		side_box.add_child(UI.wrap(UI.label("Scoperta sotto i tracciati: si risolve alla quarta tecnologia di un tracciato.", 16, UI.MUTED), SIDE_W - 40))
	var hole := 0
	for sh in e.ships:
		if int(sh["p"]) == p and sh["h"] == "hole":
			hole += 1
	if hole > 0:
		side_box.add_child(UI.wrap(UI.label("Navi nel buco nero: %d" % hole, 16, UI.PINK), SIDE_W - 40))
	if e.minors_on and not e.minors.is_empty():
		var av := []
		for m in e.minors:
			av.append("%s (%d denaro)" % [D.MINORS[m]["name"], int(D.MINORS[m]["cost"])])
		side_box.add_child(UI.wrap(UI.label("Specie minori libere: " + ", ".join(av), 15, UI.MUTED), SIDE_W - 40))
	if not st["spare"].is_empty():
		var sp := HBoxContainer.new()
		sp.add_child(UI.label("Parti antiche da montare:", 16, UI.MUTED))
		for pt in st["spare"]:
			sp.add_child(UI.icon_rect(UI.part_tex(pt), Vector2(40, 40)))
		side_box.add_child(sp)
	# settore selezionato
	if info_hex != "" and e.hexes.has(info_hex):
		side_box.add_child(HSeparator.new())
		side_box.add_child(_hex_info(info_hex))


## Schede del pannello: plancia originale, plancia delle scorte, dettagli in testo.
func _side_tabs(p: int, st: Dictionary) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var names := ["Plance", "Dettagli"]
	for i in names.size():
		var ii := i * 2
		var b := UI.button(names[i], 150, 42, 18)
		if ii == side_tab:
			UI.primary(b)
		b.pressed.connect(func():
			side_tab = ii
			_side())
		tabs.add_child(b)
	tabs.add_child(UI.wrap(UI.label("Tocca una plancia per ingrandirla", 16, UI.MUTED), SIDE_W - 360))
	side_box.add_child(tabs)
	if side_tab == 2:
		return
	var show := humans.has(p) or humans.is_empty()
	var w := SIDE_W - 34
	for kind in ["plancia", "scorte"]:
		var kk: String = kind
		var pb := ECPlayerBoard.new().setup(engine, p, kind, show)
		pb.custom_minimum_size = Vector2(w, w * pb.aspect())
		pb.clicked.connect(func(): _board_dialog(p, kk))
		side_box.add_child(pb)
	var sc := engine.score(p)
	var up := engine.upkeep(p)
	var net := engine.prod(p, "$") - up
	side_box.add_child(UI.wrap(UI.label("Punti %d · produzione: materiali +%d, scienza +%d, denaro +%d · mantenimento %d (saldo %s%d) · commercio %d:1" % [
		sc["totale"], engine.prod(p, "m"), engine.prod(p, "s"), engine.prod(p, "$"), up, "+" if net >= 0 else "", net, engine.trade_rate(p)],
		17, UI.RED if int(st["res"]["$"]) + net < 0 else UI.GOLD_L), w))


## La plancia a tutta finestra, per leggerla bene (anche su iPad).
func _board_dialog(p: int, kind: String) -> void:
	var vs := get_viewport_rect().size
	var asp := ECPlayerBoard.BH / ECPlayerBoard.BW if kind == "plancia" else ECPlayerBoard.SH / ECPlayerBoard.SW
	var w := minf(vs.x - 120, (vs.y - 230) / asp)
	var dlg := _dialog("%s di %s" % ["Plancia" if kind == "plancia" else "Popolazione e scorte", engine.pname(p)], w + 40)
	var pb := ECPlayerBoard.new().setup(engine, p, kind, humans.has(p) or humans.is_empty())
	pb.custom_minimum_size = Vector2(w, w * asp)
	dlg["box"].add_child(pb)
	var cl := UI.button("Chiudi", 200, 50, 20)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cl.pressed.connect(func(): dlg["root"].queue_free())
	dlg["box"].add_child(cl)


func _side_details(p: int, st: Dictionary, S: Dictionary) -> void:
	var e := engine
	# risorse
	var rb := HBoxContainer.new()
	rb.add_theme_constant_override("separation", 18)
	for r in D.RES:
		var extra := " (+%d)" % e.prod(p, r)
		rb.add_child(UI.res_chip(r, "%d%s" % [int(st["res"][r]), extra], 21))
	side_box.add_child(rb)
	var up := e.upkeep(p)
	var net := e.prod(p, "$") - up
	var econ := UI.wrap(UI.label("Mantenimento %d · saldo del round %s%d · dischi liberi %d · navi coloniali %d/%d · commercio %d:1" % [up, "+" if net >= 0 else "", net,
		int(st["discs"]), int(st["colony"]) - int(st["colony_used"]), int(st["colony"]), e.trade_rate(p)], 17, UI.RED if int(st["res"]["$"]) + net < 0 else UI.TEXT), SIDE_W - 40)
	side_box.add_child(econ)
	# attivazioni
	var acts: Dictionary = S["acts"]
	var ab := HBoxContainer.new()
	ab.add_theme_constant_override("separation", 6)
	for a in D.ACTIONS:
		var used := int(st["acts_used"].get(a, 0))
		var l := UI.label("%s %d%s" % [D.ACTION_SHORT[a], int(acts[a]), (" (x%d)" % used) if used > 0 else ""], 16, UI.GOLD_L if used > 0 else UI.MUTED, UI.font_cond_b)
		ab.add_child(l)
	side_box.add_child(ab)
	# punti
	var sc := e.score(p)
	side_box.add_child(UI.wrap(UI.label("Punti: %d (reputazione %d, ambasciatori %d, settori %d, monoliti %d, scoperte %d, tecnologie %d, specie %d%s)" % [sc["totale"], sc["rep"], sc["amb"], sc["settori"], sc["monoliti"], sc["scoperte"], sc["tecnologie"], sc["specie"], ", traditore -2" if sc["traditore"] < 0 else ""], 16, UI.GOLD_L), SIDE_W - 40))
	# reputazione
	var rep := HBoxContainer.new()
	rep.add_theme_constant_override("separation", 6)
	rep.add_child(UI.label("Reputazione", 16, UI.MUTED))
	for e2 in st["rep"]:
		if e2["k"] == "R":
			var show := p == focus_p and (humans.has(p) or humans.is_empty())
			if show:
				rep.add_child(UI.icon_rect(UI.tex("res://assets/reputazione/%d.jpg" % int(e2["v"])), Vector2(34, 34)))
			else:
				rep.add_child(UI.Swatch.new(UI.GOLD, Vector2(26, 30)))
		else:
			rep.add_child(UI.Swatch.new(UI.pcolor(e, int(e2["from"])), Vector2(26, 30), true))
	for i in e.rep_slots(p).size() - st["rep"].size():
		rep.add_child(UI.Swatch.new(Color(1, 1, 1, 0.08), Vector2(26, 30)))
	side_box.add_child(rep)
	# tecnologie
	side_box.add_child(UI.heading("Tecnologie", 19))
	for c in D.TECH_CATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var cl := UI.label(D.CAT_NAME[c], 15, D.CAT_COLOR[c], UI.font_cond_b)
		cl.custom_minimum_size.x = 64
		row.add_child(cl)
		var list: Array = st["techs"][c]
		for i in 7:
			if i < list.size():
				var tr := UI.icon_rect(UI.tech_tex(list[i]), Vector2(58, 58))
				tr.tooltip_text = "%s: %s" % [D.tech_name(list[i]), D.TECHS[list[i]]["txt"]]
				tr.mouse_filter = Control.MOUSE_FILTER_PASS
				row.add_child(tr)
			else:
				var em := Panel.new()
				em.custom_minimum_size = Vector2(58, 58)
				em.add_theme_stylebox_override("panel", UI.panel_style(Color(D.CAT_COLOR[c], 0.08), Color(D.CAT_COLOR[c], 0.3), 1, 4))
				var dl := UI.label("-%d" % D.TECH_DISCOUNT[i] if i > 0 else "", 14, Color(1, 1, 1, 0.35))
				dl.position = Vector2(18, 18)
				em.add_child(dl)
				row.add_child(em)
		side_box.add_child(row)
	# progetti delle navi
	side_box.add_child(UI.heading("Progetti delle navi", 19))
	for s in st["types"]:
		side_box.add_child(_bp_row(p, s, null))


## Riga di un progetto: nome, costo, caselle con le parti e i valori complessivi.
func _bp_row(p: int, s: String, on_slot) -> Control:
	var e := engine
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var stt: Dictionary = e.ship_stats(p, s)
	var n_sh := e.count_ships(p, s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UI.label(D.SHIP_NAME[s], 18, UI.TEXT, UI.font_bold))
	h.add_child(UI.label("costo %d · in gioco %d/%d" % [e.build_cost(p, s), n_sh, D.SHIP_LIMIT[s]], 15, UI.MUTED))
	vb.add_child(h)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 4)
	var bp: Array = e.ps[p]["bp"][s]
	for i in bp.size():
		var pt := e.part_at(p, s, i)
		var cell: Control
		if on_slot != null:
			var b := Button.new()
			b.custom_minimum_size = Vector2(66, 66)
			b.icon = UI.part_tex(pt) if pt != "" else null
			b.expand_icon = true
			b.tooltip_text = D.part_name(pt) if pt != "" else "casella vuota"
			var ii := i
			b.pressed.connect(func(): on_slot.call(s, ii))
			cell = b
		else:
			if pt != "":
				cell = UI.icon_rect(UI.part_tex(pt), Vector2(52, 52))
				cell.tooltip_text = D.part_name(pt)
				cell.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				var em := Panel.new()
				em.custom_minimum_size = Vector2(52, 52)
				em.add_theme_stylebox_override("panel", UI.panel_style(Color(UI.LINE, 0.06), Color(UI.LINE, 0.35), 1, 3))
				cell = em
		slots.add_child(cell)
	for pt in e.ps[p]["outside"][s]:
		var o := UI.icon_rect(UI.part_tex(pt), Vector2(40, 40))
		slots.add_child(o)
	vb.add_child(slots)
	var weap := []
	for d in stt["can"]:
		weap.append(D.DIE_NAME[d])
	var mis := []
	for d in stt["mis"]:
		mis.append(D.DIE_NAME[d])
	var line := "Iniziativa %d · movimento %d · energia %d/%d · computer +%d · scudi -%d · scafo %d" % [stt["ini"], stt["mv"], stt["en_u"], stt["en_p"], stt["comp"], stt["sh"], stt["hull"]]
	if not weap.is_empty():
		line += " · cannoni: " + ", ".join(weap)
	if not mis.is_empty():
		line += " · missili: " + ", ".join(mis)
	vb.add_child(UI.wrap(UI.label(line, 15, UI.MUTED), SIDE_W - 50))
	return vb


func _hex_info(k: String) -> Control:
	var e := engine
	var hx: Dictionary = e.hexes[k]
	var S: Dictionary = e.sector(hx)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.icon_rect(UI.sector_tex(int(hx["n"])), Vector2(120, 120)))
	var iv := VBoxContainer.new()
	iv.add_child(UI.label("%s (%d)" % [S["name"], int(hx["n"])], 21, UI.GOLD_L, UI.font_head))
	var own := "nessuno" if int(hx["owner"]) < 0 else e.pname(int(hx["owner"]))
	iv.add_child(UI.label("%d PV · controllo: %s" % [int(S["vp"]), own], 17, UI.TEXT))
	var pls := []
	for i in S["pl"].size():
		var code: String = S["pl"][i]
		var t: String = {"m": "materiali", "s": "scienza", "$": "denaro", "g": "grigio"}[code.replace("*", "")]
		pls.append(t + (" avanzato" if code.ends_with("*") else "") + (" (occupato)" if hx["cubes"][i] != "" else ""))
	iv.add_child(UI.wrap(UI.label("Pianeti: " + (", ".join(pls) if not pls.is_empty() else "nessuno"), 16, UI.MUTED), 360))
	var extra := []
	if hx["orb"]:
		extra.append("orbitale")
	if hx["mono"]:
		extra.append("monolito")
	if S.get("art", false):
		extra.append("artefatto")
	if e.is_warp(hx):
		extra.append("portale di curvatura")
	if not hx["disc"].is_empty():
		extra.append("tessera scoperta")
	if not hx["npc"].is_empty():
		var cnt := {}
		for npc in hx["npc"]:
			cnt[npc["k"]] = int(cnt.get(npc["k"], 0)) + 1
		for kk in cnt:
			extra.append("%d %s" % [cnt[kk], D.NPC_PLURAL[kk] if cnt[kk] > 1 else D.NPC_NAME[kk]])
	if not extra.is_empty():
		iv.add_child(UI.wrap(UI.label(", ".join(extra), 16, UI.LINE), 360))
	h.add_child(iv)
	vb.add_child(h)
	for q in e.owners_in(k):
		var cnt := {}
		for s in e.ships_in(k, q):
			cnt[s["t"]] = int(cnt.get(s["t"], 0)) + 1
		var parts := []
		for t in D.SHIP_TYPES:
			if cnt.has(t):
				parts.append("%d %s" % [cnt[t], (D.SHIP_PLURAL[t] if cnt[t] > 1 else D.SHIP_NAME[t]).to_lower()])
		vb.add_child(UI.wrap(UI.label("%s: %s" % [e.pname(q), ", ".join(parts)], 16, UI.pcolor(e, q).lightened(0.3)), SIDE_W - 50))
	return vb


# ================================================================ diario e messaggi

func _on_log(t: String) -> void:
	var col := "#e8eef8"
	if t.begins_with("—"):
		col = "#ffd27e"
	elif t.begins_with("Battaglia"):
		col = "#ff8a80"
	log_box.append_text("[color=%s]%s[/color]\n" % [col, t])
	if log_box.get_paragraph_count() > 500:
		log_box.remove_paragraph(0)
	_dirty = true


func toast(t: String, col := UI.TEXT) -> void:
	var l := UI.label(t, 21, col, UI.font_semi)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	toast_box.add_child(l)
	while toast_box.get_child_count() > 5:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_fx(kind: String, d: Dictionary) -> void:
	var e := engine
	match kind:
		"action":
			toast("%s: %s%s" % [e.pname(d["p"]), D.ACTION_NAME[d["a"]], " (reazione)" if d["react"] else ""], UI.pcolor(e, d["p"]).lightened(0.35))
		"place":
			board.focus_hex(d["h"])
		"battle_start":
			board.focus_hex(d["h"])
			toast("Battaglia in %s!" % e.sector(e.hexes[d["h"]])["name"], UI.RED)
		"volley":
			_show_dice(d)
		"battle_end":
			dice_panel.visible = false
		"destroy":
			var who: String = D.SHIP_NAME.get(d["t"], D.NPC_NAME.get(d["t"], ""))
			toast("%s distrutto%s" % [who, "" if d["p"] < 0 else " (%s)" % e.pname(d["p"])], UI.RED)
		"discovery":
			if not d["vp"]:
				toast("%s: scoperta %s" % [e.pname(d["p"]), e.disc_name(d["tile"])], UI.LINE)
		"tech":
			toast("%s ricerca %s" % [e.pname(d["p"]), D.tech_name(d["t"])], D.CAT_COLOR[D.TECHS[d["t"]]["cat"]].lightened(0.3))
		"traitor":
			toast("%s tradisce %s!" % [e.pname(d["p"]), e.pname(d["q"])], UI.RED)
		"diplo":
			toast("Relazioni diplomatiche: %s e %s" % [e.pname(d["p"]), e.pname(d["q"])], UI.GREEN)
		"eliminated":
			toast("La civiltà di %s è crollata." % e.pname(d["p"]), UI.RED)
		"supernova":
			toast("Una supernova esplode!", UI.RED)
			board.focus_hex(d["h"])
		"minor":
			toast("%s si allea con la specie minore %s" % [e.pname(d["p"]), D.MINORS[d["m"]]["name"]], UI.GREEN)
		"shrine":
			toast("%s costruisce un santuario" % e.pname(d["p"]), UI.GOLD_L)
	_dirty = true


func _show_dice(d: Dictionary) -> void:
	var e := engine
	for c in dice_panel.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var who: String = e.pname(d["p"]) if d["p"] >= 0 else D.NPC_PLURAL[d["t"]]
	var what: String = (D.SHIP_PLURAL[d["t"]] if d["p"] >= 0 else "")
	vb.add_child(UI.label("%s %s %s" % [who, ("- " + what.to_lower()) if what != "" else "", "- missili" if d["missile"] else "- cannoni"], 20, UI.pcolor(e, d["p"]).lightened(0.3) if d["p"] >= 0 else UI.MUTED, UI.font_head_r))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for x in d["dice"]:
		row.add_child(_die(x))
	vb.add_child(row)
	dice_panel.add_child(vb)
	dice_panel.visible = true
	dice_panel.reset_size()
	dice_panel.position.x = (size.x - SIDE_W) * 0.5 - dice_panel.size.x * 0.5


func _die(x: Dictionary) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(54, 54)
	var col: Color = D.DIE_COLOR[x["d"]]
	var sb := UI.panel_style(col.darkened(0.15), Color.WHITE if x["hit"] else Color(0, 0, 0, 0.5), 3 if x["hit"] else 1, 8)
	c.add_theme_stylebox_override("panel", sb)
	var l := UI.label(str(x["v"]), 28, UI.INK if x["d"] in ["y"] else Color.WHITE, UI.font_head)
	l.position = Vector2(17, 6)
	c.add_child(l)
	if not x["hit"]:
		c.modulate = Color(1, 1, 1, 0.55)
	return c


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		wait_lbl.text = ""
	else:
		wait_lbl.text = "Aspetto %s…%s" % [engine.pname(s), " (ci mette un po')" if slow else ""]


func online_mine() -> bool:
	return engine.online != null and engine.online._mine_pending


func online_status(t: String) -> void:
	toast(t, UI.RED)


func online_caught_up() -> void:
	toast("Partita ripresa: sei di nuovo al tavolo.", UI.LINE)


func online_cancel_decision(t: String) -> void:
	_clear_prompt()
	toast(t, UI.RED)


# ================================================================ finestre

func _dialog(title_text: String, w: float, modal := true) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP if modal else Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(root)
	if modal:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.97))
	root.add_child(box)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size.x = w
	sc.add_child(vb)
	vb.add_child(UI.title(title_text, 30))
	var fit := func():
		if not is_instance_valid(box):
			return
		var vs := get_viewport_rect().size
		# con il tutorial aperto le finestre stanno a destra del suo riquadro
		var left := 600.0 if (tutorial != null and is_instance_valid(tutorial) and not tutorial._collapsed and modal) else 0.0
		var k := minf(1.0, minf((vs.x - left - 40) / (w + 40), (vs.y - 40) / 900.0))
		box.scale = Vector2(k, k)
		var hgt: float = minf(vb.get_combined_minimum_size().y + 30, (vs.y - 60) / k)
		sc.custom_minimum_size = Vector2(w + 16, hgt)
		box.reset_size()
		box.position = Vector2(left + (vs.x - left - box.size.x * k) * 0.5, (vs.y - box.size.y * k) * 0.5)
	fit.call_deferred()
	get_tree().create_timer(0.06).timeout.connect(fit)
	return {"root": root, "box": vb, "fit": fit}


func _ask_menu() -> void:
	var dlg := _dialog("Tornare al menu?", 640)
	dlg["box"].add_child(UI.wrap(UI.label("La partita in corso si chiude. Per riprenderla più tardi salvala prima con «Salva».", 20, UI.TEXT), 600))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var y := UI.primary(UI.button("Torna al menu", 0, 56, 20))
	y.pressed.connect(func(): main.show_menu())
	r.add_child(y)
	var nb := UI.button("Continua a giocare", 0, 56, 20)
	nb.pressed.connect(func(): dlg["root"].queue_free())
	r.add_child(nb)
	dlg["box"].add_child(r)


func _show_rules() -> void:
	var book = preload("res://scripts/ui/rules_view.gd").new()
	book.on_close = func(): pass
	popup_layer.add_child(book)


func _show_scores() -> void:
	var e := engine
	var dlg := _dialog("Punteggio attuale", 1000)
	dlg["box"].add_child(_score_table())
	if not e.history.is_empty():
		dlg["box"].add_child(UI.label("Andamento per round: " + "  ".join(e.history.map(func(h): return "/".join(h.map(func(x): return str(x))))), 17, UI.MUTED))
	var cl := UI.button("Chiudi", 220, 54, 20)
	cl.pressed.connect(func(): dlg["root"].queue_free())
	cl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(cl)


func _score_table() -> GridContainer:
	var e := engine
	var g := GridContainer.new()
	g.columns = 10
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 6)
	for h in ["Civiltà", "Reput.", "Amb.", "Settori", "Monoliti", "Scoperte", "Tecn.", "Specie", "Tradit.", "Totale"]:
		g.add_child(UI.label(h, 17, UI.LINE, UI.font_cond_b))
	for p in e.n:
		var s := e.score(p)
		var nm := UI.label(e.pname(p), 18, UI.pcolor(e, p).lightened(0.3), UI.font_bold)
		nm.custom_minimum_size.x = 220
		g.add_child(nm)
		for k in ["rep", "amb", "settori", "monoliti", "scoperte", "tecnologie", "specie", "traditore", "totale"]:
			g.add_child(UI.label(str(s[k]), 19, UI.GOLD_L if k == "totale" else UI.TEXT, UI.font_bold if k == "totale" else UI.font_semi))
	return g


func _save_game() -> void:
	if engine.online != null:
		toast("La partita online è già salvata nella stanza: per rientrare usa il codice della stanza.", UI.LINE)
		return
	var cfg := config.duplicate(true)
	cfg.erase("online")
	cfg.erase("replay")
	var data := {"cfg": var_to_str(cfg), "moves": var_to_str(engine.record), "label": "Round %d" % engine.round_n,
		"names": ", ".join(range(engine.n).map(func(x): return engine.pname(x)))}
	toast("Salvataggio in corso…", UI.TEXT)
	var net: Net = main.get_net()
	var code := await net.save_game(data, save_code)
	if code == "":
		toast("Salvataggio non riuscito: %s" % net.last_error, UI.RED)
		return
	save_code = code
	var dlg := _dialog("Partita salvata", 640)
	dlg["box"].add_child(UI.wrap(UI.label("Per riprenderla scegli «Carica partita» nel menu e scrivi questo codice (vale da qualsiasi dispositivo):", 20, UI.TEXT), 600))
	dlg["box"].add_child(UI.title(code, 64))
	var cl := UI.button("Chiudi", 200, 54, 20)
	cl.pressed.connect(func(): dlg["root"].queue_free())
	cl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(cl)


func _on_end(res: Dictionary) -> void:
	_clear_prompt()
	if engine.online != null:
		engine.online.finish()
	_dirty = true
	var e := engine
	var dlg := _dialog("Fine della partita", 1040)
	var w: int = int(res.get("winner", 0))
	dlg["box"].add_child(UI.title("Vince %s" % e.pname(w), 40, UI.pcolor(e, w).lightened(0.4)))
	dlg["box"].add_child(_score_table())
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var m := UI.primary(UI.button("Torna al menu", 0, 56, 20))
	m.pressed.connect(func(): main.show_menu())
	r.add_child(m)
	var v := UI.button("Guarda la galassia", 0, 56, 20)
	v.pressed.connect(func(): dlg["root"].queue_free())
	r.add_child(v)
	dlg["box"].add_child(r)


# ================================================================ decisioni: base

func _clear_prompt() -> void:
	pending = {}
	aux = {}
	prompt.visible = false
	for c in prompt_box.get_children():
		c.queue_free()
	board.hot = {}
	board.preview = {}
	board._refresh_marks()
	_dirty = true
	for c in popup_layer.get_children():
		c.queue_free()


func _submit(r) -> void:
	var req := pending
	if tutorial != null and is_instance_valid(tutorial) and not req.is_empty() and not tutorial.accept(r):
		return
	_clear_prompt()
	if req.is_empty():
		return
	engine.provide_decision(r)


func _ptitle(t: String) -> void:
	prompt.visible = true
	prompt_title.text = t


func _pbtn(t: String, cb: Callable, prim := false, enabled := true) -> Button:
	var b := UI.button(t, 0, 50, 20)
	if prim:
		UI.primary(b)
	b.disabled = not enabled
	b.pressed.connect(cb)
	prompt_box.add_child(b)
	return b


func _hot(k: String, col: Color, label := "") -> void:
	board.hot[k] = {"col": col, "label": label}


func _on_hex(k: String) -> void:
	if aux.has("hex_cb") and board.hot.has(k):
		aux["hex_cb"].call(k)
		return
	if engine.hexes.has(k):
		info_hex = k
		board.sel = k
		board._refresh_marks()
		_dirty = true


func _on_decision(req: Dictionary) -> void:
	pending = req
	aux = {}
	var p: int = req["seat"]
	if humans.size() > 1 or focus_p != p:
		focus_p = p
	_dirty = true
	match str(req["type"]):
		"turn": _ui_turn(req)
		"explore": _ui_explore(req)
		"place": _ui_place(req)
		"claim": _ui_claim(req)
		"discovery": _ui_discovery(req)
		"part": _ui_part(req)
		"research": _ui_research(req)
		"upgrade": _ui_upgrade(req)
		"build": _ui_build(req)
		"move": _ui_move(req)
		"influence": _ui_influence(req)
		"colony": _ui_colony(req)
		"diplo": _ui_diplo(req)
		"battle": _ui_battle(req)
		"artifact": _ui_artifact(req)
		"warp": _ui_warp(req)
		"hole": _ui_hole(req)
		"shrine": _ui_shrine(req)
		_:
			_submit({"stop": true})
	if tutorial != null and is_instance_valid(tutorial) and humans.has(p):
		tutorial.on_request(req)


func _place_tutorial() -> void:
	var on: bool = tutorial != null and is_instance_valid(tutorial) and not tutorial.is_queued_for_deletion()
	var open: bool = on and not tutorial._collapsed
	board.offset_left = 600.0 if open else 0.0
	toast_box.position.x = 620.0 if on else 16.0
	if on:
		tutorial.position = Vector2(12, 160)
		tutorial.size.x = 580


func _who(req: Dictionary) -> String:
	return "%s: " % engine.pname(req["seat"]) if humans.size() > 1 else ""


func _hname(k: String) -> String:
	return engine.sector(engine.hexes[k])["name"]


# ================================================================ turno

func _ui_turn(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var st: Dictionary = e.ps[p]
	var opts: Array = req["opts"]
	var up_now := e.upkeep(p)
	var up_next := e.upkeep_next(p)
	var money: int = int(st["res"]["$"]) + e.prod(p, "$")
	if req["passed"]:
		_ptitle("%sHai passato: puoi fare una reazione (un'attivazione di Potenziare, Costruire o Muovere) oppure passare ancora. Ogni reazione usa un disco (mantenimento da %d a %d)." % [_who(req), up_now, up_next])
		for a in ["r_upg", "r_bui", "r_mov"]:
			var b: String = a.substr(2)
			_pbtn("Reazione: %s" % D.ACTION_NAME[b], func(): _submit({"a": a}), false, opts.has(a))
		_pbtn("Passa", func(): _submit({"a": "pass"}), true)
	else:
		var warn := ""
		if money - up_next < 0:
			warn = " Attenzione: con un altro disco il mantenimento (%d) supera denaro e reddito (%d)." % [up_next, money]
		_ptitle("%sScegli un'azione. Dischi liberi %d: un'azione in più porta il mantenimento da %d a %d.%s" % [_who(req), int(st["discs"]), up_now, up_next, warn])
		var acts: Dictionary = st["S"]["acts"]
		for a in D.ACTIONS:
			var n_act: int = int(acts[a])
			if a == "upg" and e.has_tech(p, "pico_modulator"):
				n_act += 2
			if a == "bui" and e.has_tech(p, "nanorobots"):
				n_act += 1
			if a == "mov" and e.has_tech(p, "improved_logistics"):
				n_act += 1
			var aa: String = a
			_pbtn("%s (%d)" % [D.ACTION_NAME[a], n_act], func(): _submit({"a": aa}), false, opts.has(a))
		_pbtn("Passa", func(): _submit({"a": "pass"}), true)
	if req.get("colony", false):
		_pbtn("Colonizza", func(): _submit({"a": "colony"}))
	_pbtn("Scambia", func(): _ui_trade(req))
	for pk in req.get("pulsars", []):
		var pkk: String = pk
		_pbtn("Pulsar di %s" % _hname(pk), func(): _ui_pulsar(req, pkk))
	if not req.get("minors", []).is_empty():
		_pbtn("Specie minori", func(): _ui_minors(req))
	if req.get("colony_res", false):
		_pbtn("Nave coloniale: risorsa", func(): _ui_colony_res(req))
	for q in req.get("diplo", []):
		var qq: int = q
		_pbtn("Diplomazia con %s" % e.pname(q), func(): _submit({"a": "diplo", "t": qq}))


func _ui_trade(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var rate := e.trade_rate(p)
	var dlg := _dialog("Scambio %d:1" % rate, 760)
	dlg["box"].add_child(UI.wrap(UI.label("Paghi %d unità di una risorsa per riceverne 1 di un'altra. (Quando paghi una ricerca o una costruzione, il gioco scambia da solo se ti manca qualcosa.)" % rate, 19, UI.MUTED), 720))
	for from in D.RES:
		for to in D.RES:
			if from == to:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(UI.res_chip(from, "%d" % rate, 20, 30))
			row.add_child(UI.label("per", 18, UI.MUTED))
			row.add_child(UI.res_chip(to, "1", 20, 30))
			var avail: int = int(int(e.ps[p]["res"][from]) / rate)
			for nn in [1, 3, 5]:
				var b := UI.button("x%d" % nn, 70, 44, 18)
				b.disabled = avail < nn
				var f: String = from
				var t: String = to
				var cnt: int = nn
				b.pressed.connect(func(): _submit({"a": "trade", "from": f, "to": t, "n": cnt}))
				row.add_child(b)
			dlg["box"].add_child(row)
	var cl := UI.button("Annulla", 200, 50, 20)
	cl.pressed.connect(func(): dlg["root"].queue_free())
	cl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(cl)


# ================================================================ esplorazione

func _ui_explore(req: Dictionary) -> void:
	_ptitle("%sScegli sulla mappa la zona da esplorare (attivazioni rimaste: %d)." % [_who(req), int(req["left"])])
	for z in req["zones"]:
		_hot(z, UI.LINE, "?")
	aux["hex_cb"] = func(k): _submit({"z": k})
	_pbtn("Basta esplorare", func(): _submit({"stop": true}))
	board._refresh_marks()


func _ui_place(req: Dictionary) -> void:
	var e := engine
	var tiles: Array = req["tiles"]
	aux["ti"] = 0
	for i in tiles.size():
		if not req["rots"][str(tiles[i])].is_empty():
			aux["ti"] = i
			break
	aux["ri"] = 0
	var show := func(self_ref):
		for c in prompt_box.get_children():
			c.queue_free()
		var t: int = tiles[aux["ti"]]
		var rots: Array = req["rots"][str(t)]
		var S: Dictionary = D.SECTORS[t]
		var desc := "%s (%d): %d PV" % [S["name"], t, int(S["vp"])]
		if int(S.get("anc", 0)) > 0:
			desc += ", %d Antichi" % int(S["anc"])
		if S.get("disc", false):
			desc += ", scoperta"
		if rots.is_empty():
			_ptitle("%sHai trovato %s, ma non si può orientare con un collegamento verso di te: va scartato." % [_who(req), desc])
			board.preview = {"k": req["zone"], "n": t, "rot": 0}
		else:
			var rot: int = rots[aux["ri"] % rots.size()]
			_ptitle("%sHai trovato %s. Ruotala come preferisci (orientamenti validi: %d) e piazzala, oppure scartala." % [_who(req), desc, rots.size()])
			board.preview = {"k": req["zone"], "n": t, "rot": rot}
			if rots.size() > 1:
				_pbtn("Ruota", func():
					aux["ri"] = (int(aux["ri"]) + 1) % rots.size()
					self_ref.call(self_ref))
			_pbtn("Piazza", func(): _submit({"tile": t, "rot": rot}), true)
		if tiles.size() > 1:
			for i in tiles.size():
				if i == aux["ti"]:
					continue
				var ii := i
				_pbtn("Guarda l'altro settore", func():
					aux["ti"] = ii
					aux["ri"] = 0
					self_ref.call(self_ref))
		_pbtn("Scarta", func(): _submit({"discard": true}))
		board._refresh_marks()
		board.focus_hex(req["zone"])
	show.call(show)


func _ui_claim(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var k: String = req["h"]
	board.sel = k
	_hot(k, UI.GOLD_L)
	board._refresh_marks()
	_ptitle("%sVuoi prendere il controllo di %s mettendo un disco influenza? Il mantenimento passa da %d a %d." % [_who(req), _hname(k), e.upkeep(p), e.upkeep_next(p)])
	_pbtn("Sì, prendilo", func(): _submit({"yes": true}), true)
	_pbtn("No", func(): _submit({"yes": false}))


# ================================================================ scoperte e parti

func _ui_discovery(req: Dictionary) -> void:
	var e := engine
	var tile: Dictionary = req["tile"]
	var dlg := _dialog("Tessera scoperta", 700)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.add_child(UI.icon_rect(UI.disc_tex(tile), Vector2(170, 170)))
	var v := VBoxContainer.new()
	v.add_child(UI.label(e.disc_name(tile), 24, UI.GOLD_L, UI.font_head_r))
	var txt := ""
	match str(tile["k"]):
		"tech":
			txt = "Prendi gratis la tecnologia normale più economica del vassoio che non hai."
		"cruiser":
			txt = "Un incrociatore compare nel settore della scoperta."
		"orbital":
			txt = "Un orbitale nel settore della scoperta e 2 materiali."
		"monolith":
			txt = "Un monolito (3 PV) nel settore della scoperta."
		"warp":
			txt = "Il settore diventa un portale di curvatura e vale 2 PV in più se lo controlli."
		"part":
			var P: Dictionary = D.PARTS[tile["part"]]
			txt = "Parte antica per le navi (non serve la tecnologia). Energia %+d." % int(P.get("en", 0))
		_:
			txt = "Risorse subito."
	v.add_child(UI.wrap(UI.label(txt + " In alternativa la tieni a faccia in giù: vale 2 PV a fine partita.", 19, UI.TEXT), 460))
	h.add_child(v)
	dlg["box"].add_child(h)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var u := UI.primary(UI.button("Usala", 220, 56, 22))
	u.pressed.connect(func(): _submit({"vp": false}))
	r.add_child(u)
	var k := UI.button("Tienila: 2 PV", 220, 56, 22)
	k.pressed.connect(func(): _submit({"vp": true}))
	r.add_child(k)
	dlg["box"].add_child(r)


func _ui_part(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var pt: String = req["part"]
	var dlg := _dialog("Dove monti %s?" % D.part_name(pt), 820)
	var outside: bool = D.PARTS[pt].get("outside", false)
	dlg["box"].add_child(UI.wrap(UI.label("Tocca una casella valida di un progetto (si accendono quelle compatibili con l'energia)." if not outside else "Questa parte va fuori dalle caselle: scegli il tipo di nave.", 19, UI.MUTED), 780))
	if outside:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		for s in e.ps[p]["types"]:
			var ss: String = s
			var b := UI.button(D.SHIP_NAME[s], 0, 54, 20)
			b.pressed.connect(func(): _submit({"s": ss}))
			r.add_child(b)
		dlg["box"].add_child(r)
		return
	var valid := {}
	for o in req["opts"]:
		valid["%s_%d" % [o[0], int(o[1])]] = true
	for s in e.ps[p]["types"]:
		var row := _bp_row(p, s, func(ss, ii):
			if valid.has("%s_%d" % [ss, ii]):
				_submit({"s": ss, "i": ii}))
		_mark_slots(row, s, valid)
		dlg["box"].add_child(row)
	var kp := UI.button("Tienila per dopo", 260, 54, 20)
	kp.pressed.connect(func(): _submit({"keep": true}))
	kp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(kp)


func _mark_slots(row: Control, s: String, valid: Dictionary) -> void:
	var slots: HBoxContainer = row.get_child(1)
	var i := 0
	for c in slots.get_children():
		if c is Button:
			var ok := valid.has("%s_%d" % [s, i])
			var sb := UI.panel_style(Color(UI.GREEN, 0.15) if ok else Color(0, 0, 0, 0.3), UI.GREEN if ok else Color(1, 1, 1, 0.12), 3 if ok else 1, 4)
			c.add_theme_stylebox_override("normal", sb)
			c.add_theme_stylebox_override("hover", UI.panel_style(Color(UI.GREEN, 0.3), UI.GOLD_L, 3, 4) if ok else sb)
			c.disabled = not ok
			i += 1


# ================================================================ ricerca

func _ui_research(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var opts := {}
	for o in req["opts"]:
		opts[o["t"]] = o
	var dlg := _dialog("Ricerca - attivazioni rimaste %d" % int(req["left"]), 1180)
	dlg["box"].add_child(UI.label("Scienza disponibile: %d (con gli scambi fino a %d). Il prezzo tiene conto degli sconti dei tuoi tracciati." % [int(e.ps[p]["res"]["s"]), e.spendable(p, "s")], 19, UI.MUTED))
	for c in ["mil", "grid", "nano", "rare"]:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		var cl := UI.label(D.CAT_NAME[c], 19, D.CAT_COLOR[c], UI.font_head)
		cl.custom_minimum_size.x = 120
		row.add_child(cl)
		var list := []
		if c == "rare":
			for t in e.rare_row:
				if not list.has(t):
					list.append(t)
		else:
			for t in D.TECH_ORDER[c]:
				if int(e.tray.get(t, 0)) > 0:
					list.append(t)
		if list.is_empty():
			row.add_child(UI.label("nessuna", 17, UI.MUTED))
		for t in list:
			var b := Button.new()
			b.custom_minimum_size = Vector2(118, 150)
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.position = Vector2(6, 4)
			vb.add_child(UI.icon_rect(UI.tech_tex(t), Vector2(106, 106)))
			var has := e.has_tech(p, t)
			var cost_txt := "già tua" if has else ("%d sci" % int(opts[t]["cost"]) if opts.has(t) else "%d sci" % e.tech_cost(p, t))
			var cnt := "" if c == "rare" else " x%d" % int(e.tray.get(t, 0))
			var l := UI.label(cost_txt + cnt, 16, UI.GOLD_L if opts.has(t) else UI.MUTED, UI.font_cond_b)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(l)
			b.add_child(vb)
			b.tooltip_text = "%s: %s" % [D.tech_name(t), D.TECHS[t]["txt"]]
			b.disabled = not opts.has(t)
			var tt: String = t
			b.pressed.connect(func():
				if c == "rare":
					_rare_track(req, tt)
				else:
					_submit({"t": tt}))
			row.add_child(b)
		dlg["box"].add_child(row)
	var stop := UI.button("Basta ricercare", 260, 54, 20)
	stop.pressed.connect(func(): _submit({"stop": true}))
	stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(stop)


func _rare_track(req: Dictionary, t: String) -> void:
	var e := engine
	var p: int = req["seat"]
	var dlg := _dialog("Su quale tracciato metti %s?" % D.tech_name(t), 700)
	dlg["box"].add_child(UI.wrap(UI.label("Le tecnologie rare vanno su un tracciato a scelta e ne prendono lo sconto.", 19, UI.MUTED), 660))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	for c in D.TECH_CATS:
		if e.ps[p]["techs"][c].size() >= 7:
			continue
		var cost := e.tech_cost(p, t, c)
		var cc: String = c
		var b := UI.button("%s (%d sci)" % [D.CAT_NAME[c], cost], 0, 54, 20)
		b.disabled = not e.can_pay(p, "s", cost)
		b.pressed.connect(func(): _submit({"t": t, "cat": cc}))
		r.add_child(b)
	dlg["box"].add_child(r)


# ================================================================ potenziamento

func _ui_upgrade(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var opts: Array = req["opts"]
	aux["slot"] = ""
	var dlg := _dialog("Potenziare - attivazioni rimaste %d" % int(req["left"]), 1180)
	var info := UI.wrap(UI.label("1) Tocca la casella del progetto da cambiare.  2) Scegli la parte da montare: le parti compatibili (energia sufficiente, almeno un propulsore, niente propulsori sulla base stellare) sono accese. Le navi già costruite si aggiornano tutte.", 19, UI.MUTED), 1140)
	dlg["box"].add_child(info)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	dlg["box"].add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size.x = 600
	hb.add_child(left)
	var right := HFlowContainer.new()
	right.custom_minimum_size.x = 520
	right.add_theme_constant_override("h_separation", 8)
	right.add_theme_constant_override("v_separation", 8)
	hb.add_child(right)
	var redraw := func(self_ref):
		for c in left.get_children():
			c.queue_free()
		for c in right.get_children():
			c.queue_free()
		var with_opts := {}
		for o in opts:
			with_opts["%s_%d" % [o["s"], int(o["i"])]] = true
		for s in e.ps[p]["types"]:
			var row := _bp_row(p, s, func(ss, ii):
				aux["slot"] = "%s_%d" % [ss, ii]
				self_ref.call(self_ref))
			var marks := {}
			for kk in with_opts:
				marks[kk] = true
			_mark_slots(row, s, marks)
			if aux["slot"] != "":
				var slots: HBoxContainer = row.get_child(1)
				var parts2: PackedStringArray = aux["slot"].split("_")
				if parts2[0] == s:
					var c: Control = slots.get_child(int(parts2[1]))
					c.add_theme_stylebox_override("normal", UI.panel_style(Color(UI.GOLD, 0.35), UI.GOLD_L, 4, 4))
			left.add_child(row)
		if aux["slot"] == "":
			right.add_child(UI.wrap(UI.label("Scegli prima una casella.", 19, UI.MUTED), 480))
			return
		var sp: PackedStringArray = aux["slot"].split("_")
		var s: String = sp[0]
		var i := int(sp[1])
		right.add_child(UI.wrap(UI.label("%s, casella %d: ora %s." % [D.SHIP_NAME[s], i + 1, D.part_name(e.part_at(p, s, i)) if e.part_at(p, s, i) != "" else "vuota"], 19, UI.TEXT), 500))
		for o in opts:
			if o["s"] != s or int(o["i"]) != i:
				continue
			var pt: String = o["part"]
			var P: Dictionary = D.PARTS[pt]
			var b := Button.new()
			b.custom_minimum_size = Vector2(118, 140)
			var vb := VBoxContainer.new()
			vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.position = Vector2(8, 4)
			vb.add_child(UI.icon_rect(UI.part_tex(pt), Vector2(100, 100)))
			var l := UI.label(D.part_name(pt), 14, UI.TEXT, UI.font_cond_b)
			l.custom_minimum_size.x = 102
			l.clip_text = true
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(l)
			b.add_child(vb)
			b.tooltip_text = D.part_name(pt)
			b.pressed.connect(func(): _submit({"s": s, "i": i, "part": pt}))
			right.add_child(b)
		if right.get_child_count() == 1:
			right.add_child(UI.wrap(UI.label("Nessuna parte montabile qui.", 19, UI.MUTED), 480))
		dlg["fit"].call()
	redraw.call(redraw)
	var stop := UI.button("Basta potenziare", 260, 54, 20)
	stop.pressed.connect(func(): _submit({"stop": true}))
	stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(stop)


# ================================================================ costruzione

const BUILD_NAME := {"int": "Intercettore", "cru": "Incrociatore", "dre": "Corazzata", "sb": "Base stellare", "orb": "Orbitale", "mono": "Monolito"}


func _ui_build(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var opts: Array = req["opts"]
	var by := {}
	for o in opts:
		if not by.has(o["w"]):
			by[o["w"]] = []
		by[o["w"]].append(o["h"])
	_ptitle("%sCostruire (attivazioni rimaste: %d). Materiali %d: scegli cosa costruire." % [_who(req), int(req["left"]), int(e.ps[p]["res"]["m"])])
	for w in ["int", "cru", "dre", "sb", "orb", "mono"]:
		if not by.has(w):
			continue
		var ww: String = w
		_pbtn("%s (%d)" % [BUILD_NAME[w], e.build_cost(p, w)], func():
			var hs: Array = by[ww]
			if hs.size() == 1:
				_submit({"w": ww, "h": hs[0]})
				return
			for c in prompt_box.get_children():
				c.queue_free()
			_ptitle("%sDove costruisci: %s? Tocca un tuo settore." % [_who(req), BUILD_NAME[ww].to_lower()])
			board.hot = {}
			for h in hs:
				_hot(h, UI.GOLD_L)
			aux["hex_cb"] = func(k): _submit({"w": ww, "h": k})
			_pbtn("Indietro", func():
				board.hot = {}
				aux.erase("hex_cb")
				for c in prompt_box.get_children():
					c.queue_free()
				_ui_build(req))
			board._refresh_marks())
	_pbtn("Basta costruire", func(): _submit({"stop": true}))


# ================================================================ movimento

func _ui_move(req: Dictionary) -> void:
	var e := engine
	var opts: Dictionary = req["opts"]
	var from := {}
	for id in opts:
		var s := e.ship_by_id(int(id))
		if not from.has(s["h"]):
			from[s["h"]] = []
		from[s["h"]].append(id)
	_ptitle("%sMuovere (attivazioni rimaste: %d): tocca il settore della nave da muovere." % [_who(req), int(req["left"])])
	board.hot = {}
	for h in from:
		_hot(h, UI.LINE)
	aux["hex_cb"] = func(k):
		var ids: Array = from[k]
		# una nave per tipo
		var types := {}
		for id in ids:
			var s := e.ship_by_id(int(id))
			if not types.has(s["t"]):
				types[s["t"]] = id
		if types.size() == 1:
			_move_dest(req, types.values()[0])
			return
		for c in prompt_box.get_children():
			c.queue_free()
		_ptitle("%sQuale nave muovi da %s?" % [_who(req), _hname(k)])
		for t in D.SHIP_TYPES:
			if types.has(t):
				var id = types[t]
				_pbtn(D.SHIP_NAME[t], func(): _move_dest(req, id))
		_pbtn("Indietro", func():
			for c in prompt_box.get_children():
				c.queue_free()
			_ui_move(req))
	_pbtn("Basta muovere", func(): _submit({"stop": true}))
	board._refresh_marks()


func _move_dest(req: Dictionary, id) -> void:
	var e := engine
	var s := e.ship_by_id(int(id))
	for c in prompt_box.get_children():
		c.queue_free()
	_ptitle("%sDove va %s (movimento %d)? Tocca la destinazione." % [_who(req), D.SHIP_NAME[s["t"]].to_lower(), int(e.ship_stats(int(s["p"]), s["t"])["mv"])])
	board.hot = {}
	for k in req["opts"][str(id)]:
		var foes := false
		for q in e.owners_in(k):
			if q != int(s["p"]):
				foes = true
		_hot(k, UI.RED if foes or not e.hexes[k]["npc"].is_empty() else UI.GREEN)
	board.sel = s["h"]
	aux["hex_cb"] = func(k): _submit({"id": str(id), "to": k})
	_pbtn("Altra nave", func():
		for c in prompt_box.get_children():
			c.queue_free()
		_ui_move(req))
	_pbtn("Basta muovere", func(): _submit({"stop": true}))
	board._refresh_marks()


# ================================================================ influenza e colonie

func _ui_influence(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	_ptitle("%sInfluenzare (attivazioni rimaste: %d): tocca un settore verde per mettere un disco, uno rosso per ritirarlo. Mantenimento ora %d." % [_who(req), int(req["left"]), e.upkeep(p)])
	board.hot = {}
	for k in req["remove"]:
		_hot(k, UI.RED, "-")
	for k in req["add"]:
		_hot(k, UI.GREEN, "+")
	aux["hex_cb"] = func(k):
		if req["add"].has(k):
			_submit({"add": k})
		else:
			_submit({"remove": k})
	_pbtn("Basta influenzare", func(): _submit({"stop": true}))
	board._refresh_marks()


func _ui_colony(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var st: Dictionary = e.ps[p]
	var dlg := _dialog("Navi coloniali: %d disponibili" % (int(st["colony"]) - int(st["colony_used"])), 900)
	dlg["box"].add_child(UI.wrap(UI.label("Ogni nave coloniale sposta un cubetto dal tracciato della popolazione a un pianeta libero di un tuo settore: il tracciato scopre un numero più alto e produci di più." + (" (Mantenimento: niente colonie dove ci sono navi nemiche.)" if req.get("upkeep", false) else ""), 19, UI.MUTED), 860))
	var bykey := {}
	for o in req["opts"]:
		if not bykey.has(o["h"]):
			bykey[o["h"]] = []
		bykey[o["h"]].append(o)
	for k in bykey:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon_rect(UI.sector_tex(int(e.hexes[k]["n"])), Vector2(70, 70)))
		var nm := UI.label(_hname(k), 20, UI.GOLD_L, UI.font_semi)
		nm.custom_minimum_size.x = 210
		row.add_child(nm)
		var fl := HFlowContainer.new()
		fl.custom_minimum_size.x = 540
		fl.add_theme_constant_override("h_separation", 8)
		for o in bykey[k]:
			var code: String = "orb" if int(o["i"]) < 0 else e.sector(e.hexes[k])["pl"][int(o["i"])]
			var label: String = "orbitale" if code == "orb" else ({"m": "materiali", "s": "scienza", "$": "denaro", "g": "grigio"}[code.replace("*", "")] + (" avanzato" if code.ends_with("*") else ""))
			for t in o["t"]:
				var b := UI.button("", 0, 54, 18)
				b.text = "%s: cubo %s (+%d)" % [label, {"m": "materiali", "s": "scienza", "$": "denaro"}[t], _gain(p, t)] if o["t"].size() > 1 or code == "orb" else "%s (+%d)" % [label, _gain(p, t)]
				b.icon = UI.res_tex(t)
				b.expand_icon = false
				b.add_theme_constant_override("icon_max_width", 30)
				var oo: Dictionary = o
				var tt: String = t
				b.pressed.connect(func(): _submit({"h": oo["h"], "i": oo["i"], "t": tt}))
				fl.add_child(b)
		row.add_child(fl)
		dlg["box"].add_child(row)
	var stop := UI.button("Basta così", 220, 54, 20)
	stop.pressed.connect(func(): _submit({"stop": true}))
	stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dlg["box"].add_child(stop)


func _gain(p: int, t: String) -> int:
	var e := engine
	var c: int = int(e.ps[p]["track"][t])
	var now := e.prod(p, t)
	e.ps[p]["track"][t] = c - 1
	var after := e.prod(p, t)
	e.ps[p]["track"][t] = c
	return after - now


func _ui_diplo(req: Dictionary) -> void:
	var e := engine
	var q: int = req["from"]
	var dlg := _dialog("Proposta diplomatica", 720)
	dlg["box"].add_child(UI.wrap(UI.label("%s propone a %s relazioni diplomatiche: vi scambiate un ambasciatore con un cubetto popolazione (produci di più) e ogni ambasciatore vale 1 PV. Chi poi attacca l'altro diventa il Traditore (-2 PV)." % [e.pname(q), e.pname(req["seat"])], 20, UI.TEXT), 680))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var y := UI.primary(UI.button("Accetta", 220, 56, 22))
	y.pressed.connect(func(): _submit({"ok": true}))
	r.add_child(y)
	var n := UI.button("Rifiuta", 220, 56, 22)
	n.pressed.connect(func(): _submit({"ok": false}))
	r.add_child(n)
	dlg["box"].add_child(r)


func _ui_battle(req: Dictionary) -> void:
	var e := engine
	var k: String = req["h"]
	board.focus_hex(k)
	_ptitle("%sBattaglia in %s, round %d: i tuoi %s sparano o si ritirano?" % [_who(req), _hname(k), int(req["round"]), D.SHIP_PLURAL[req["s"]].to_lower()])
	_pbtn("Fuoco!", func(): _submit({"fire": true}), true)
	for d in req["dests"]:
		var dd: String = d
		_pbtn("Ritirata verso %s" % _hname(d), func(): _submit({"retreat": dd}))


func _ui_artifact(req: Dictionary) -> void:
	_ptitle("%sChiave degli artefatti: ricevi %d risorse di un solo tipo. Quale?" % [_who(req), int(req["n"])])
	for r in D.RES:
		var rr: String = r
		_pbtn(D.RES_NAME[r], func(): _submit({"r": rr}))


func _ui_warp(req: Dictionary) -> void:
	_ptitle("%sDove metti il portale di curvatura? Tocca un tuo settore." % _who(req))
	board.hot = {}
	for k in req["opts"]:
		_hot(k, Color("#b07cff"))
	aux["hex_cb"] = func(k): _submit({"h": k})
	board._refresh_marks()



# ================================================================ espansioni

func _ui_pulsar(req: Dictionary, k: String) -> void:
	var e := engine
	var cur: String = str(e.hexes[k].get("pulsar", "mov"))
	for c in prompt_box.get_children():
		c.queue_free()
	_ptitle("%sPulsar di %s: sposta il disco su un'altra azione e fanne un'attivazione, senza usare un disco (una volta per round)." % [_who(req), _hname(k)])
	for a in D.PULSAR_ACTS:
		if a == cur:
			continue
		var aa: String = a
		_pbtn(D.ACTION_NAME[a], func(): _submit({"a": "pulsar", "h": k, "act": aa}), true)
	_pbtn("Indietro", func():
		for c in prompt_box.get_children():
			c.queue_free()
		_ui_turn(req))


func _ui_minors(req: Dictionary) -> void:
	var e := engine
	var dlg := _dialog("Specie minori", 860)
	dlg["box"].add_child(UI.wrap(UI.label("Paghi il denaro indicato e metti l'ambasciatore della specie minore su una casella ambasciatore libera della tua reputazione. L'effetto vale subito; ogni specie minore è di una sola civiltà.", 19, UI.MUTED), 820))
	for m in req["minors"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var mm: String = m
		var b := UI.primary(UI.button("%s (%d denaro)" % [D.MINORS[m]["name"], int(D.MINORS[m]["cost"])], 300, 54, 19))
		b.pressed.connect(func(): _submit({"a": "minor", "m": mm}))
		row.add_child(b)
		row.add_child(UI.wrap(UI.label(D.MINORS[m]["txt"], 18, UI.TEXT), 500))
		dlg["box"].add_child(row)
	var cl := UI.button("Annulla", 200, 50, 20)
	cl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cl.pressed.connect(func(): dlg["root"].queue_free())
	dlg["box"].add_child(cl)


func _ui_colony_res(req: Dictionary) -> void:
	for c in prompt_box.get_children():
		c.queue_free()
	_ptitle("%sGiri una nave coloniale inutilizzata e ricevi una risorsa: quale?" % _who(req))
	for r in D.RES:
		var rr: String = r
		_pbtn(D.RES_NAME[r], func(): _submit({"a": "colony_res", "r": rr}), true)
	_pbtn("Indietro", func():
		for c in prompt_box.get_children():
			c.queue_free()
		_ui_turn(req))


func _ui_hole(req: Dictionary) -> void:
	var e := engine
	if req.get("forced", false):
		_ptitle("%sLa nave riemerge subito dal buco nero: scegli dove (settori accesi)." % _who(req))
	else:
		_ptitle("%sUn tuo %s può uscire dal buco nero in questo round: scegli dove, oppure aspetta (se non esce entro il round va perso)." % [_who(req), D.SHIP_NAME[req["t"]].to_lower()])
		_pbtn("Non ora", func(): _submit({"stop": true}))
	board.hot = {}
	for k in req["opts"]:
		_hot(k, UI.PINK)
	aux["hex_cb"] = func(k): _submit({"h": k})
	board._refresh_marks()


func _ui_shrine(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var by := {}
	for o in req["opts"]:
		var i := int(o["i"])
		if not by.has(i):
			by[i] = []
		by[i].append(o)
	var dlg := _dialog("Santuario", 900)
	dlg["box"].add_child(UI.wrap(UI.label("Con la Ricerca puoi costruire un santuario accanto a un pianeta del colore della risorsa (o grigio) in un tuo settore. Ogni fila completata dà un premio; ogni santuario vale 1 PV nei settori che controlli.", 19, UI.MUTED), 860))
	for row in 3:
		dlg["box"].add_child(UI.label("Fila %d: %s" % [row + 1, D.SHRINE_ROW[row]], 19, UI.GOLD_L, UI.font_semi))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		for j in 3:
			var i := row * 3 + j
			var r: String = D.SHRINES[i][0]
			if e.ps[p]["shrines"].has(i):
				fl.add_child(UI.label("costruito", 17, UI.GREEN))
				continue
			if not by.has(i):
				fl.add_child(UI.label("%d %s: non ora" % [int(D.SHRINES[i][1]), D.RES_NAME[r].to_lower()], 17, UI.MUTED))
				continue
			var seen_h := {}
			for o in by[i]:
				if seen_h.has(o["h"]):
					continue
				seen_h[o["h"]] = true
				var oo: Dictionary = o
				var b := UI.button("%d %s in %s" % [int(D.SHRINES[i][1]), D.RES_NAME[r].to_lower(), _hname(o["h"])], 0, 50, 18)
				b.pressed.connect(func(): _submit({"i": oo["i"], "h": oo["h"], "pl": oo["pl"]}))
				fl.add_child(b)
		dlg["box"].add_child(fl)
	var stop := UI.button("Nessun santuario", 260, 54, 20)
	stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stop.pressed.connect(func(): _submit({"stop": true}))
	dlg["box"].add_child(stop)
