extends Control
## Menu principale: civiltà in gioco (colore, specie, persona o IA), opzioni, partite salvate e gioco online.

const D = preload("res://scripts/data/ec_data.gd")
const MODES := ["Persona", "IA facile", "IA normale", "IA difficile"]

var main
var page: Control
var nplayers := 4
var modes := [0, 2, 2, 2, 2, 2]
var names := ["", "", "", "", "", ""]
var colors := [0, 1, 2, 3, 4, 5]
var sides := [0, 1, 1, 1, 1, 1]          # 0 terrestri, 1 alieni
var adv := 0
var events := 0
var minors := 0
var turn_order := 0
var speed := 1
var anim := 1
var msg: Label
var seat_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	if not st.is_empty():
		nplayers = st["nplayers"]
		modes = st["modes"].duplicate()
		names = st["names"].duplicate()
		colors = st["colors"].duplicate()
		sides = st["sides"].duplicate()
		speed = st["speed"]
		anim = st.get("anim", 1)
		adv = st.get("adv", 0)
		events = st.get("events", 0)
		minors = st.get("minors", 0)
		turn_order = st.get("turn_order", 0)
	page = Control.new()
	page.size = Vector2(1920, 1080)
	add_child(page)
	_center.call_deferred()
	get_viewport().size_changed.connect(_center)

	# a sinistra: titolo e una tessera del Centro Galattico
	var gc := UI.icon_rect(UI.sector_tex(1), Vector2(520, 520))
	gc.position = Vector2(110, 90)
	gc.modulate = Color(1, 1, 1, 0.92)
	page.add_child(gc)
	var t1 := UI.title("ECLIPSE", 104)
	t1.position = Vector2(92, 640)
	page.add_child(t1)
	var t2 := UI.label("SECONDA ALBA PER LA GALASSIA", 26, UI.LINE, UI.font_head_r)
	t2.position = Vector2(104, 778)
	page.add_child(t2)
	var t3 := UI.wrap(UI.label("Touko Tahkokallio · Lautapelit.fi\nGuida una civiltà interstellare: esplora i settori, colonizza i pianeti, ricerca le tecnologie, progetta e costruisci le tue navi e affronta Antichi, Guardiani, il Sistema di Difesa del Centro Galattico e le altre specie. Dopo otto round vince chi ha più punti vittoria.", 21, UI.MUTED, UI.font_italic), 620)
	t3.position = Vector2(104, 830)
	page.add_child(t3)

	# a destra: civiltà e opzioni
	var col := VBoxContainer.new()
	col.position = Vector2(760, 50)
	col.custom_minimum_size = Vector2(1100, 0)
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	col.add_child(UI.heading("Civiltà", 30))
	col.add_child(_segmented("Giocatori", ["2", "3", "4", "5", "6"], nplayers - 2, func(k):
		nplayers = k + 2
		_refresh(), 90))
	seat_box = VBoxContainer.new()
	seat_box.add_theme_constant_override("separation", 6)
	col.add_child(seat_box)
	col.add_child(UI.heading("Opzioni", 30))
	col.add_child(_segmented("Antichi, Guardiani e SDCG", ["Progetti base", "Progetti avanzati"], adv, func(k): adv = k, 230))
	var o1 := HBoxContainer.new()
	o1.add_theme_constant_override("separation", 30)
	col.add_child(o1)
	o1.add_child(_segmented("Eventi galattici", ["No", "Sì"], events, func(k): events = k, 80))
	o1.add_child(_segmented("Specie minori", ["No", "Sì"], minors, func(k): minors = k, 80))
	col.add_child(_segmented("Ordine dei turni", ["Classico (in senso orario)", "Variante: chi passa prima"], turn_order, func(k): turn_order = k, 300))
	var o2 := HBoxContainer.new()
	o2.add_theme_constant_override("separation", 30)
	col.add_child(o2)
	o2.add_child(_segmented("Pausa dell'IA", ["Lunga", "Normale", "Breve", "Nessuna"], speed, func(k): speed = k, 110))
	o2.add_child(_segmented("Animazioni", ["Lente", "Normali", "Veloci"], anim, func(k): anim = k, 110))
	var sp := Control.new()
	sp.custom_minimum_size.y = 10
	col.add_child(sp)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	col.add_child(btns)
	var play := UI.primary(UI.button("Gioca", 230, 70, 30))
	play.pressed.connect(_on_start)
	btns.add_child(play)
	var onl := UI.button("Gioca online", 220, 70, 22)
	onl.pressed.connect(_online_panel)
	btns.add_child(onl)
	var ld := UI.button("Carica partita", 210, 70, 22)
	ld.pressed.connect(_load_panel)
	btns.add_child(ld)
	var rules := UI.button("Regole", 150, 70, 22)
	rules.pressed.connect(func():
		_store()
		main.show_rules())
	btns.add_child(rules)
	var tut := UI.button("Tutorial", 160, 70, 22)
	tut.pressed.connect(func():
		_store()
		main.start_game(preload("res://scripts/ui/tutorial.gd").config()))
	btns.add_child(tut)
	msg = UI.label("", 21, UI.GOLD_L)
	col.add_child(msg)
	_refresh()


func _center() -> void:
	var vs := get_viewport_rect().size
	var k := minf(vs.x / 1920.0, vs.y / 1080.0)
	page.scale = Vector2(k, k)
	page.position = (vs - Vector2(1920, 1080) * k) * 0.5


func _store() -> void:
	main.menu_state = {"nplayers": nplayers, "modes": modes.duplicate(), "names": names.duplicate(), "speed": speed,
		"anim": anim, "adv": adv, "colors": colors.duplicate(), "sides": sides.duplicate(), "events": events, "minors": minors, "turn_order": turn_order}


func _refresh() -> void:
	for c in seat_box.get_children():
		c.queue_free()
	for s in nplayers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		seat_box.add_child(row)
		var sw := UI.Swatch.new(D.COLORS[colors[s]]["c"], Vector2(34, 34), true)
		row.add_child(sw)
		var nm := LineEdit.new()
		nm.placeholder_text = "Nome"
		nm.text = names[s]
		nm.max_length = 18
		nm.custom_minimum_size = Vector2(210, 50)
		nm.add_theme_font_size_override("font_size", 21)
		var si := s
		nm.text_changed.connect(func(t): names[si] = t)
		row.add_child(nm)
		var mo := _option(MODES, modes[s], 170)
		mo.item_selected.connect(func(i): modes[si] = i)
		row.add_child(mo)
		var cnames := []
		for c in D.COLORS:
			cnames.append(c["name"])
		var co := _option(cnames, colors[s], 130)
		co.item_selected.connect(func(i):
			# due civiltà non possono avere lo stesso colore: si scambiano
			var other := colors.find(i)
			if other >= 0 and other != si:
				colors[other] = colors[si]
			colors[si] = i
			_refresh())
		row.add_child(co)
		var opts := _species_list(colors[s])
		var labels := []
		for sp in opts:
			labels.append(D.species_title(sp) + (" (esp.)" if D.SPECIES[sp].get("exp", false) else ""))
		var so := _option(labels, clampi(sides[s], 0, opts.size() - 1), 330)
		so.item_selected.connect(func(i):
			sides[si] = i
			_refresh())
		row.add_child(so)
	msg.text = ""


## Specie sceglibili con un colore: le due facce della plancia e le specie delle espansioni.
func _species_list(col: int) -> Array:
	var out: Array = D.COLOR_SPECIES[col].duplicate()
	out.append_array(D.EXP_SPECIES)
	return out


func _species_of(s: int) -> String:
	var l := _species_list(colors[s])
	return l[clampi(sides[s], 0, l.size() - 1)]


func _option(items: Array, cur: int, w: float) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.select(cur)
	o.custom_minimum_size = Vector2(w, 50)
	o.add_theme_font_size_override("font_size", 20)
	o.fit_to_longest_item = false
	return o


func _segmented(label_text: String, items: Array, cur: int, cb: Callable, w := 120) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := UI.label(label_text, 21, UI.MUTED)
	l.custom_minimum_size.x = 150 if label_text.length() < 16 else 300
	h.add_child(l)
	var group := ButtonGroup.new()
	for i in items.size():
		var b := UI.button(items[i], w, 46, 19)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == cur
		var ii := i
		b.pressed.connect(func(): cb.call(ii))
		h.add_child(b)
	return h


func _config() -> Dictionary:
	var seats := []
	for s in nplayers:
		var col: int = colors[s]
		var sp: String = _species_of(s)
		var nm: String = names[s].strip_edges()
		if nm == "":
			nm = D.species_title(sp) if modes[s] == 0 else "%s (IA)" % D.species_title(sp)
		seats.append({"name": nm, "ai": modes[s] != 0, "level": maxi(0, modes[s] - 1), "color": col, "species": sp})
	var delays := [1.2, 0.6, 0.25, 0.0]
	var anims := [0.6, 1.0, 1.8]
	return {"seats": seats, "ai_delay": delays[speed], "anim": anims[anim], "adv_npc": adv == 1,
		"events": events == 1, "minors": minors == 1, "turn_order": turn_order == 1}


## Due civiltà non possono avere la stessa specie.
func _dup_species() -> String:
	var seen := {}
	for s in nplayers:
		var sp := _species_of(s)
		if seen.has(sp):
			return D.species_title(sp)
		seen[sp] = true
	return ""


func _on_start() -> void:
	var dup := _dup_species()
	if dup != "":
		msg.text = "%s è scelta da due civiltà: cambiane una." % dup
		return
	_store()
	main.start_game(_config())


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _overlay(w: float, title_text: String) -> VBoxContainer:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.98))
	box.position = page.position + Vector2((1920 - w) * 0.5, 130) * page.scale
	box.scale = page.scale
	box.custom_minimum_size = Vector2(w, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	vb.add_child(UI.title(title_text, 44))
	return vb


func _online_panel() -> void:
	var vb := _overlay(860, "Gioca online")
	vb.add_child(UI.wrap(UI.label("Chi crea la stanza guida la prima civiltà della lista. I posti segnati «Persona» nel menu restano liberi per gli amici, che entrano con il codice; quelli segnati IA li gioca il computer. Civiltà e opzioni scelte nel menu valgono per tutti. La partita resta salvata nella stanza: si può rientrare con lo stesso codice.", 20, UI.MUTED), 820))
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 18)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := UI.button("Crea una stanza", 0, 56, 22)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 56, 22)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 21, Color.WHITE), 820)
	on_lbl.custom_minimum_size.y = 120
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = UI.primary(UI.button("Inizia online", 420, 60, 24))
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := UI.button("Indietro", 300, 60, 22)
	b_close.pressed.connect(func(): on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 24)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_name(i: int) -> String:
	return D.species_title(_species_of(i))


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		parts.append("%s: %s" % [_seat_name(int(idx)), who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	if _dup_species() != "":
		_say("%s è scelta da due civiltà: cambiane una nel menu." % _dup_species())
		return
	var seats := [0]
	for s in range(1, nplayers):
		if modes[s] == 0:
			seats.append(s)
	if seats.size() < 2:
		_say("Segna «Persona» nel menu almeno un posto oltre al tuo, per l'amico.")
		return
	modes[0] = 0
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": 0}
	net.remember_room(code, 0)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice agli amici.\nPosti: %s.\nQuando ci sono premi Inizia online (i posti rimasti liberi li gioca l'IA)." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (posto %d).\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1])
		await get_tree().create_timer(2.0).timeout


## Chi ha creato la stanza avvia: civiltà, opzioni e seme valgono per tutti.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in nplayers:
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", cfg["seats"][i]["name"]))
			cfg["seats"][i]["ai"] = false
		else:
			cfg["seats"][i]["ai"] = true
			cfg["seats"][i]["level"] = maxi(1, modes[i] - 1)
			if modes[i] == 0:
				cfg["seats"][i]["name"] = "%s (IA)" % _seat_name(i)
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	main.lobby = {}
	main.start_game(cfg)


# =================================================================== partite salvate

func _load_panel() -> void:
	var vb := _overlay(820, "Carica partita")
	vb.add_child(UI.wrap(UI.label("Scrivi il codice di 6 lettere ottenuto con «Salva» durante la partita. Le partite salvate stanno su Firebase e si riprendono da qualsiasi dispositivo.", 20, UI.MUTED), 780))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 6)
	on_code.custom_minimum_size.x = 260
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b := UI.primary(UI.button("Carica", 220, 56, 22))
	b.pressed.connect(_do_load)
	row.add_child(b)
	vb.add_child(row)
	on_lbl = UI.wrap(UI.label("", 21, Color.WHITE), 780)
	on_lbl.custom_minimum_size.y = 80
	vb.add_child(on_lbl)
	var cl := UI.button("Indietro", 260, 56, 22)
	cl.pressed.connect(func(): on_panel.queue_free())
	vb.add_child(cl)


func _do_load() -> void:
	var code := on_code.text.strip_edges().to_upper()
	if code.length() != 6:
		_say("Il codice ha 6 lettere.")
		return
	_say("Carico la partita %s…" % code)
	var net: Net = main.get_net()
	var data := await net.load_game(code)
	if data.is_empty():
		_say("Partita %s non trovata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	var cfg = str_to_var(str(data.get("cfg", "")))
	var moves = str_to_var(str(data.get("moves", "[]")))
	if not (cfg is Dictionary) or not (moves is Array):
		_say("Salvataggio non valido.")
		return
	cfg["replay"] = moves
	main.start_game(cfg)
	if main.current != null:
		main.current.save_code = code
