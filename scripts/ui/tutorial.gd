class_name ECTutorial
extends PanelContainer
## Tutorial: una partita preparata (sempre uguale, seme fisso) in cui la persona gioca il primo round
## guidata passo passo. Ogni passo spiega cosa fare, perché e un consiglio strategico; le scelte diverse da
## quelle del tutorial vengono rifiutate con un suggerimento, così la partita resta quella descritta.

const D = preload("res://scripts/data/ec_data.gd")
const UI = preload("res://scripts/ui/ui.gd")

const HOME := "0,-2"
const Z1 := "0,-3"
const Z2 := "1,-3"

var gv                         # la vista di gioco
var step := 0
var page := 0
var _req := {}
var _shown := -1
var _phase_seen := {}
var _final := false
var _title: Label
var _text: RichTextLabel
var _do: Label
var _prev: Button
var _next: Button
var _small: Button
var _collapsed := false
var _body: VBoxContainer


static func config() -> Dictionary:
	return {"seats": [
		{"name": "Tu", "ai": false, "level": 1, "color": 0, "species": "terran_directorate"},
		{"name": "", "ai": true, "level": 1, "color": 1, "species": "hydran"},
		{"name": "", "ai": true, "level": 1, "color": 3, "species": "draco"}],
		"ai_delay": 0.6, "anim": 1.0, "seed": 4242, "adv_npc": false, "events": false, "minors": false, "turn_order": false,
		"tutorial": true}


# ------------------------------------------------------------------ i passi
## type: tipo di richiesta del motore; pages: pagine di spiegazione; do: istruzione; ok: risposta accettata;
## no: suggerimento se la scelta è diversa; hex: settore da evidenziare.

func _steps() -> Array:
	return [
		{"type": "turn", "pages": [
			"""[b]Benvenuto in Eclipse![/b] In questo tutorial giochi il [b]primo round[/b] di una partita a tre con il [color=#ff7a6e]Direttorato Terrestre[/color] (rosso). Gli avversari sono il [color=#6fb0ff]Progresso Hydran[/color] (blu), bravi nella ricerca, e i [color=#ffd36e]Discendenti di Draco[/color] (giallo), che convivono con gli Antichi.

Ti spiegherò ogni scelta: [b]cosa[/b] fare, [b]perché[/b] e qualche [b]consiglio[/b] da giocatore esperto. Puoi spostare la galassia trascinando, zoomare con la rotella o pizzicando e ruotare con due dita. Con il pulsante Riduci puoi chiudere questo riquadro e riaprirlo quando vuoi.""",
			"""[b]La tua plancia[/b] è a destra. In alto ci sono i progetti delle navi, al centro i tracciati delle tecnologie (hai già la [b]Base stellare[/b] fra le militari), in basso le azioni e il tracciato dell’influenza con [b]12 dischi[/b] liberi.

La seconda plancia mostra la [b]popolazione[/b]: produci 3 materiali, 3 scienza e 3 denaro a round. Hai in magazzino 4 materiali, 3 scienza e 3 denaro.

Tocca una plancia per ingrandirla quando vuoi.""",
			"""[b]Il tuo pianeta madre è Procyon[/b] (settore 221), in alto sulla mappa. Il centro della galassia è difeso dal Sistema di difesa: per ora lascialo stare.

Nel primo round la cosa più importante è [b]crescere[/b]: ogni pianeta colonizzato ora produce per tutti gli otto round. Per questo la prima azione sarà [b]Esplorare[/b]."""],
			"do": "Premi Esplorare nella barra in basso.",
			"ok": func(r): return r.get("a", "") == "exp",
			"no": "Nel tutorial la prima azione è Esplorare."},
		{"type": "explore", "hex": Z1, "pages": [
			"""Le zone accese sono quelle che puoi esplorare: accanto a un settore dove hai un disco o una nave.

Quella [b]sotto Procyon[/b] è verso il centro: lì ci sono settori ricchi ma spesso custoditi dagli Antichi, e il tuo vicino giallo è vicino. Quella [b]sopra Procyon[/b], verso l’esterno, pesca dall’anello esterno: settori più poveri ma tranquilli.

Per questa partita esploriamo [b]sopra Procyon[/b], nella zona segnata in oro."""],
			"do": "Tocca sulla mappa la zona segnata in oro sopra Procyon.",
			"ok": func(r): return str(r.get("z", "")) == Z1,
			"no": "Scegli la zona segnata in oro, sopra Procyon."},
		{"type": "place", "pages": [
			"""Hai trovato [b]Zeta Chamaeleontis[/b] (settore 382): un pianeta della [b]scienza[/b] (rosa), uno dei [b]materiali[/b] (marrone), una [b]tessera scoperta[/b] e un [b]portale di curvatura[/b]. Vale 1 PV a fine partita.

Puoi ruotarlo: deve esserci almeno un wormhole collegato a Procyon. Conviene orientare i wormhole verso zone libere che vorrai esplorare, e chiuderli verso i vicini pericolosi. Qui qualsiasi orientamento valido va bene."""],
			"do": "Usa Ruota se vuoi, poi premi Piazza.",
			"ok": func(r): return not r.get("discard", false),
			"no": "Questo settore è buono: piazzalo invece di scartarlo."},
		{"type": "discovery", "pages": [
			"""Nel settore c’era una [b]scoperta[/b]: una Tecnologia antica. Ti dà gratis la tecnologia più economica del vassoio che non hai.

Puoi anche tenerla coperta per [b]2 PV[/b] a fine partita, ma all’inizio l’effetto vale quasi sempre di più: una tecnologia gratis fa anche crescere il tracciato e i suoi sconti."""],
			"do": "Premi Usala.",
			"ok": func(r): return not r.get("vp", false),
			"no": "All’inizio conviene usare la scoperta: premi Usala."},
		{"type": "claim", "pages": [
			"""Hai ottenuto le [b]Bombe a neutroni[/b]: quando attaccherai la popolazione nemica, i cubetti saranno distrutti tutti senza tirare i dadi.

Ora puoi [b]prendere il controllo[/b] del settore mettendo un disco influenza. Costa: il mantenimento sale da 0 a 1 denaro a round. Ma senza disco non puoi colonizzare i pianeti, e il settore a fine partita vale un punto."""],
			"do": "Premi Sì, prendilo.",
			"ok": func(r): return r.get("yes", false),
			"no": "Questo settore ha due pianeti: prendilo."},
		{"type": "turn", "pages": [
			"""Mentre pensavi, gli avversari hanno fatto la loro azione (lo vedi nel diario a sinistra). Ora tocca di nuovo a te.

Prima dell’azione puoi usare le [b]navi coloniali[/b]: sono gratuite e non costano dischi. Ognuna sposta un cubetto dal tracciato di popolazione su un pianeta del suo colore in un tuo settore."""],
			"do": "Premi Colonizza.",
			"ok": func(r): return r.get("a", "") == "colony",
			"no": "Prima colonizza i due pianeti nuovi: premi Colonizza."},
		{"type": "colony", "pages": [
			"""Hai 3 navi coloniali. Metti un cubetto sul [b]pianeta della scienza[/b] di Zeta Chamaeleontis: la produzione di scienza passa da 3 a 4 a round.

Guarda la plancia della popolazione: un cubetto lascia il quadrante rosa e scopre un numero più alto."""],
			"do": "Scegli il pianeta della scienza di Zeta Chamaeleontis.",
			"ok": func(r): return str(r.get("h", "")) == Z1 and str(r.get("t", "")) in ["s", "m"],
			"no": "Colonizza i pianeti di Zeta Chamaeleontis."},
		{"type": "colony", "pages": [
			"""Ora il [b]pianeta dei materiali[/b]: anche i materiali salgono da 3 a 4 a round.

[b]Consiglio:[/b] colonizza sempre appena puoi. Un cubetto messo nel primo round produce sette volte prima della fine; uno messo nel sesto, solo due."""],
			"do": "Scegli il pianeta dei materiali.",
			"ok": func(r): return str(r.get("h", "")) == Z1,
			"no": "Colonizza l’altro pianeta di Zeta Chamaeleontis."},
		{"type": "turn", "pages": [
			"""Ottimo: produci 4 materiali, 4 scienza e 3 denaro. Il mantenimento è 1.

Seconda azione: [b]Esplorare ancora[/b]. La zona [b]a destra di Procyon[/b] è libera e dà un’altra possibilità di trovare pianeti o scoperte.

Guarda il messaggio in basso: ti dice sempre di quanto sale il mantenimento con l’azione successiva."""],
			"do": "Premi Esplorare.",
			"ok": func(r): return r.get("a", "") == "exp",
			"no": "Come seconda azione esploriamo ancora: premi Esplorare."},
		{"type": "explore", "hex": Z2, "pages": [
			"""Esplora la zona segnata in oro, in alto a destra di Procyon."""],
			"do": "Tocca la zona segnata in oro.",
			"ok": func(r): return str(r.get("z", "")) == Z2,
			"no": "Scegli la zona segnata in oro."},
		{"type": "place", "pages": [
			"""[b]Epsilon Aurigae[/b] (315): niente pianeti, ma una [b]scoperta[/b]. Non sempre l’esplorazione va bene: fa parte del gioco.

Piazzalo comunque, perché la scoperta la prendi subito e il settore può tornare utile per i movimenti."""],
			"do": "Piazza il settore.",
			"ok": func(r): return not r.get("discard", false),
			"no": "Piazzalo: la scoperta vale la pena."},
		{"type": "discovery", "pages": [
			"""Un’altra Tecnologia antica! Usala: questa volta ricevi lo [b]Scudo di Gauss[/b], che va sul tracciato del reticolo (verde) e fa scendere di 1 il prezzo delle prossime tecnologie verdi."""],
			"do": "Premi Usala.",
			"ok": func(r): return not r.get("vp", false),
			"no": "Usa la scoperta: premi Usala."},
		{"type": "claim", "pages": [
			"""Ora la domanda importante: [b]vale la pena un disco?[/b] Il settore non ha pianeti, quindi non produce niente, e un disco in più farebbe salire il mantenimento da 2 a 3 denaro [b]in ogni round[/b].

Vale solo 1 PV a fine partita, e potrai sempre prenderlo più avanti con Influenzare. Per ora rinuncia.

[b]Consiglio:[/b] i dischi sono la tua risorsa più scarsa. Prendi solo i settori che producono o che servono davvero."""],
			"do": "Premi No.",
			"ok": func(r): return not r.get("yes", false),
			"no": "Questa volta rinuncia: premi No."},
		{"type": "turn", "pages": [
			"""Terza azione: [b]Ricercare[/b]. Hai 3 scienza.

Il [b]Generatore a fusione[/b] costerebbe 4, ma grazie allo Scudo di Gauss sul tracciato verde ha uno sconto di 1: lo paghi 3. Produce 6 energia nei progetti: servirà per montare cannoni migliori nei prossimi round."""],
			"do": "Premi Ricercare.",
			"ok": func(r): return r.get("a", "") == "res",
			"no": "Ora premi Ricercare."},
		{"type": "research", "pages": [
			"""Nella finestra trovi il vassoio diviso per tracciati, con il prezzo già scontato. Scegli il [b]Generatore a fusione[/b] (verde, 3 scienza).

[b]Consiglio:[/b] concentrare le tecnologie su uno o due tracciati fa scendere i prezzi in fretta e a fine partita porta punti (da 4 tecnologie in su)."""],
			"do": "Scegli Generatore a fusione.",
			"ok": func(r): return str(r.get("t", "")) == "fusion_source",
			"no": "Per il tutorial scegli il Generatore a fusione."},
		{"type": "turn", "pages": [
			"""Quarta azione: [b]Costruire[/b]. Zeta Chamaeleontis è sul bordo del tuo impero e ha due cubetti: una [b]base stellare[/b] (3 materiali) la protegge.

Le basi stellari non si muovono, ma hanno scafo, computer e cannone: tengono lontani gli esploratori nemici e costano poco."""],
			"do": "Premi Costruire.",
			"ok": func(r): return r.get("a", "") == "bui",
			"no": "Ora premi Costruire."},
		{"type": "build", "hex": Z1, "pages": [
			"""Scegli [b]Base stellare[/b], poi tocca [b]Zeta Chamaeleontis[/b] sulla mappa. Ti resterà 1 materiale: non basta per altro, quindi la costruzione si ferma da sola."""],
			"do": "Base stellare, poi Zeta Chamaeleontis.",
			"ok": func(r): return str(r.get("w", "")) == "sb" and str(r.get("h", "")) == Z1,
			"no": "Costruisci una base stellare a Zeta Chamaeleontis."},
		{"type": "turn", "pages": [
			"""Hai fatto quattro azioni. Guarda il messaggio in basso: il mantenimento ora è [b]5[/b]. A fine round incassi 3 denaro e ne hai 3 in magazzino: ti resterà [b]1 denaro[/b]. Un’altra azione porterebbe il mantenimento a 7 e andresti in rosso.

È il momento di [b]passare[/b]. Chi passa per primo riceve 2 denaro e comincia il round dopo; dopo aver passato puoi ancora fare reazioni (un’attivazione di Potenziare, Costruire o Muovere) se serve.

[b]Consiglio:[/b] nei primi round fai poche azioni forti e passa presto. Un mantenimento troppo alto ti costringe ad abbandonare settori."""],
			"do": "Premi Passa.",
			"ok": func(r): return r.get("a", "") == "pass",
			"no": "Ora passa: premi Passa."},
	]


func _passed_step() -> Dictionary:
	return {"type": "turn", "pages": [
		"""Hai passato, ma gli altri giocano ancora: a ogni loro turno puoi fare una [b]reazione[/b]. Costa un disco come un’azione, quindi usala solo per difenderti (per esempio muovere una nave dove un nemico sta per attaccare).

Ora non serve: passa di nuovo."""],
		"do": "Premi Passa.", "ok": func(r): return r.get("a", "") == "pass", "no": "Non serve una reazione: premi Passa."}


# ------------------------------------------------------------------ pannello

func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel_style(Color(0.03, 0.06, 0.13, 0.95), UI.GOLD, 2, 10))
	custom_minimum_size = Vector2(580, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var head := HBoxContainer.new()
	_title = UI.label("Tutorial", 24, UI.GOLD_L, UI.font_head)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_small = UI.button("Riduci", 120, 40, 17)
	_small.pressed.connect(_toggle)
	head.add_child(_small)
	vb.add_child(head)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	vb.add_child(_body)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(556, 0)
	_text.add_theme_font_size_override("normal_font_size", 20)
	_text.add_theme_font_size_override("bold_font_size", 20)
	_body.add_child(_text)
	_do = UI.label("", 21, UI.GREEN, UI.font_semi)
	_do.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_do.custom_minimum_size = Vector2(556, 0)
	_body.add_child(_do)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	_prev = UI.button("Indietro", 160, 46, 19)
	_prev.pressed.connect(func(): _goto(page - 1))
	nav.add_child(_prev)
	_next = UI.primary(UI.button("Avanti", 160, 46, 19))
	_next.pressed.connect(func(): _goto(page + 1))
	nav.add_child(_next)
	_body.add_child(nav)
	_text.text = "La partita si sta preparando..."
	_do.text = ""
	_prev.visible = false
	_next.visible = false


func _toggle() -> void:
	_collapsed = not _collapsed
	_body.visible = not _collapsed
	_small.text = "Apri" if _collapsed else "Riduci"
	reset_size()
	if gv != null:
		gv._place_tutorial()


func _cur() -> Dictionary:
	if _final:
		return {}
	if not _req.is_empty() and _req.get("passed", false) and step >= _steps().size() - 1:
		return _passed_step()
	var st := _steps()
	return st[step] if step < st.size() else {}


func _goto(pg: int) -> void:
	var s := _cur()
	if _final:
		_show_final(pg)
		return
	if s.is_empty():
		return
	var pages: Array = s["pages"]
	page = clampi(pg, 0, pages.size() - 1)
	_text.text = pages[page]
	var last := page == pages.size() - 1
	_title.text = "Tutorial - passo %d di %d" % [mini(step + 1, _steps().size()), _steps().size()]
	_do.text = ("Ora: " + str(s["do"])) if last else ""
	_prev.visible = page > 0
	_next.visible = not last
	if _collapsed:
		_toggle()
	reset_size()


## Chiamata dalla vista quando arriva una decisione per la persona.
func on_request(req: Dictionary) -> void:
	_req = req
	var s := _cur()
	if s.is_empty() or str(s["type"]) != str(req["type"]):
		if not _final:
			_text.text = "Scegli liberamente: questa decisione non fa parte del percorso guidato."
			_do.text = ""
			_prev.visible = false
			_next.visible = false
		return
	if _shown != step or req.get("passed", false):
		if _shown < 0:
			gv.board.focus_hex(HOME)
		_shown = step
		_goto(0)
	else:
		_goto(page)
	if s.has("hex"):
		var k: String = s["hex"]
		_mark(k)


func _mark(k: String) -> void:
	await gv.get_tree().process_frame
	if not is_instance_valid(gv):
		return
	if str(_req.get("type", "")) == "explore":
		gv.board.hot = {}
		gv._hot(k, UI.GOLD_L, "Qui")
		gv.board._refresh_marks()
	gv.board.focus_hex(k)


## La vista chiede se la risposta va bene; se sì il passo avanza.
func accept(r) -> bool:
	var s := _cur()
	if s.is_empty() or _req.is_empty() or str(s["type"]) != str(_req["type"]):
		return true
	if r is Dictionary and (s["ok"] as Callable).call(r):
		if not _req.get("passed", false) or step < _steps().size() - 1:
			step += 1
		else:
			step = _steps().size()
		if step >= _steps().size() and str(s["type"]) == "turn" and r.get("a", "") == "pass":
			_after_pass()
		return true
	gv.toast(str(s["no"]), UI.GOLD_L)
	if _collapsed:
		_toggle()
	return false


func _after_pass() -> void:
	step = _steps().size()
	_text.text = """Hai passato. Quando tutti avranno passato il round continua da solo:

[b]Combattimento[/b]: si combatte solo dove ci sono navi nemiche nello stesso settore. In questo round nessuno si è scontrato.
[b]Mantenimento[/b]: incassi la produzione di denaro e paghi i dischi; poi produci materiali e scienza.
[b]Pulizia[/b]: i dischi delle azioni tornano sul tracciato, le navi coloniali si rigirano e nel vassoio arrivano nuove tecnologie.

Guarda il diario a sinistra e le plance a destra mentre succede."""
	_do.text = "Aspetta la fine del round."
	_prev.visible = false
	_next.visible = false
	reset_size()


func _process(_dt: float) -> void:
	if gv == null or gv.engine == null or _final:
		return
	if step >= _steps().size() and gv.engine.round_n >= 2:
		_final = true
		_show_final(0)


func _show_final(pg: int) -> void:
	var e = gv.engine
	var st: Dictionary = e.ps[0]
	var pages := [
		"""[b]Fine del primo round![/b] Hai pagato 5 denaro di mantenimento e incassato la produzione: ora hai %d materiali, %d scienza e %d denaro. I dischi delle azioni sono tornati: ne hai %d liberi (gli altri due stanno su Procyon e Zeta Chamaeleontis) e il mantenimento riparte da %d.

Ricapitolando, in un round hai: esplorato due settori, preso il controllo di uno, colonizzato due pianeti, ottenuto due tecnologie gratis dalle scoperte, ricercato il Generatore a fusione e costruito una base stellare.""" % [int(st["res"]["m"]), int(st["res"]["s"]), int(st["res"]["$"]), int(st["discs"]), e.upkeep(0)],
		"""[b]E adesso?[/b] Qualche idea per i prossimi round:
• il denaro è poco: cerca pianeti gialli e l’[b]Economia avanzata[/b] per i pianeti gialli con la stella di Procyon;
• con il Generatore a fusione puoi [b]potenziare[/b] le navi con cannoni al plasma o scafi migliorati quando li avrai;
• gli [b]Antichi[/b] vicini al centro danno reputazione e scoperte: attaccali con due o tre navi ben armate;
• tieni d’occhio i vicini: se un settore confina con loro, una base stellare o qualche nave lo proteggono.

Le [b]Regole[/b] (pulsante in alto) spiegano tutto nel dettaglio, con un capitolo di consigli strategici.""",
		"""Il tutorial finisce qui. Puoi [b]continuare questa partita[/b] da solo contro l’IA: il riquadro si chiude e giochi liberamente. Oppure torna al menu e comincia una partita nuova."""]
	page = clampi(pg, 0, pages.size() - 1)
	_title.text = "Tutorial - fine del round"
	_text.text = pages[page]
	_do.text = ""
	_prev.visible = page > 0
	_next.visible = page < pages.size() - 1
	if page == pages.size() - 1:
		_do.text = "Premi Chiudi per continuare a giocare."
		_next.visible = true
		_next.text = "Chiudi"
		for c in _next.pressed.get_connections():
			_next.pressed.disconnect(c["callable"])
		_next.pressed.connect(func():
			gv.tutorial = null
			queue_free()
			gv._place_tutorial())
	reset_size()
