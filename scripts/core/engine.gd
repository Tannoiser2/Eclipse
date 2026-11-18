class_name ECEngine
extends Node
## Motore delle regole di Eclipse — Seconda Alba per la Galassia (senza grafica).
## Ogni scelta passa da `decide()`: l'IA risponde subito; per le persone viene emesso `decision_requested`
## e si attende `provide_decision()`. Online le scelte viaggiano nel registro di mosse (OnlineSession):
## con lo stesso seme ogni dispositivo gioca la stessa partita. Anche i salvataggi sono registri di mosse.
##
## Richieste (req["type"]) e risposte:
##  - "turn":      {passed, opts, colony, diplo}  → {"a": azione | "pass" | "r_upg"/"r_bui"/"r_mov" | "colony" | "trade" | "diplo", …}
##                 trade: {"a": "trade", "from": r, "to": r, "n": quantità ottenuta}; diplo: {"a": "diplo", "t": giocatore}
##  - "explore":   {zones, left}                  → {"z": zona} | {"stop": true}
##  - "place":     {zone, tiles, rots}            → {"tile": n, "rot": r} | {"discard": true}
##  - "claim":     {h}                            → {"yes": bool}
##  - "discovery": {tile}                         → {"vp": bool}
##  - "part":      {part, opts: [[nave, casella]]}→ {"s": nave, "i": casella} | {"keep": true}
##  - "research":  {opts: [{t, cost}]}            → {"t": tecnologia, "cat": tracciato (solo rare)} | {"stop": true}
##  - "upgrade":   {opts: [{s, i, part}]}          → {"s", "i", "part"} | {"stop": true}
##  - "build":     {opts: [{w, h}]}                → {"w", "h"} | {"stop": true}
##  - "move":      {opts: {id: [destinazioni]}}    → {"id", "to"} | {"stop": true}
##  - "influence": {add, remove}                  → {"add": h} | {"remove": h} | {"stop": true}
##  - "colony":    {opts: [{h, i, t: [tracciati]}]}→ {"h", "i", "t"} | {"stop": true}
##  - "diplo":     {from}                         → {"ok": bool}
##  - "battle":    {h, s, dests, foe}             → {"retreat": h} | {"fire": true}
##  - "artifact":  {n}                            → {"r": risorsa}
##  - "warp":      {opts}                         → {"h": settore}

const D = preload("res://scripts/data/ec_data.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

var players: Array = []          # [{name, ai, level, color, species}]
var ais: Array = []
var online = null
var ai_delay := 0.5
var anim := 1.0
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var n := 0
var adv_npc := false             # progetti avanzati di Antichi, Guardiani e SDCG
var events := false              # eventi galattici (pulsar, supernove, buchi neri, nebulose)
var minors_on := false           # specie minori
var turn_var := false            # variante: ordine di turno secondo l'ordine in cui si è passato
var minors: Array = []           # specie minori ancora disponibili
var turn_order: Array = []       # ordine di turno (variante)
var pass_order: Array = []
var pulsar_used := {}            # settore -> true se usato in questo round
var npc_var := {"anc": 0, "gua": 0, "gcds": 0}
var replay: Array = []
var replay_i := 0
var record: Array = []

var ps: Array = []
var hexes := {}                  # chiave "q,r" -> settore piazzato
var ships: Array = []            # navi dei giocatori {id, p, t, h, dmg, ret, ret_to, ret_round}
var next_ship_id := 1
var stacks := {1: [], 2: [], 3: []}
var discards := {1: [], 2: [], 3: []}
var tech_bag: Array = []
var tray := {}                   # tecnologia -> copie disponibili
var rare_row: Array = []
var disc_bag: Array = []
var rep_bag: Array = []
var traitor := -1
var round_n := 1
var phase := "setup"            # action, combat, upkeep, cleanup, over
var start_player := 0
var first_pass := -1
var current := -1
var over := false
var result := {}
var log_lines: Array = []
var history: Array = []          # punteggi a fine round
var battle := {}                 # battaglia in corso (per la grafica)
var last_dice: Array = []
var stats_kills := {}


# ================================================================ preparazione

func setup(cfg: Dictionary) -> void:
	players = cfg.get("seats", [])
	n = players.size()
	adv_npc = bool(cfg.get("adv_npc", false))
	events = bool(cfg.get("events", false))
	minors_on = bool(cfg.get("minors", false))
	turn_var = bool(cfg.get("turn_order", false))
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	ai_delay = float(cfg.get("ai_delay", 0.5))
	anim = float(cfg.get("anim", 1.0))
	replay = cfg.get("replay", [])
	ais.resize(n)
	if adv_npc:
		for k in ["anc", "gua", "gcds"]:
			npc_var[k] = 1 + rng.randi_range(0, 1)
	# pile dei settori
	stacks[1] = _shuffled(D.STACK_I.duplicate())
	var mid: Array = D.STACK_II.duplicate()
	if events:
		mid.append_array(D.EVENTS_II)
	stacks[2] = _shuffled(mid)
	var outer: Array = _shuffled(D.STACK_III.duplicate())
	outer.resize(D.OUTER_COUNT[clampi(n, 2, 6)] if n >= 2 else 5)
	if events:
		# gli eventi si aggiungono agli esterni (non contano nel numero)
		outer.append_array(D.EVENTS_III)
		outer.append(D.BLACK_HOLES[rng.randi_range(0, 1)])
		outer = _shuffled(outer)
	stacks[3] = outer
	if minors_on:
		minors = _shuffled(D.MINORS.keys())
		minors.resize(4)
	# scoperte
	disc_bag.clear()
	for t in D.DISCOVERIES:
		for i in int(t["n"]):
			disc_bag.append(t.duplicate())
	disc_bag = _shuffled(disc_bag)
	# reputazione
	rep_bag.clear()
	for v in D.REP_BAG:
		for i in int(D.REP_BAG[v]):
			rep_bag.append(v)
	rep_bag = _shuffled(rep_bag)
	# tecnologie
	tech_bag.clear()
	for t in D.TECHS:
		for i in int(D.TECHS[t]["n"]):
			tech_bag.append(t)
	tech_bag = _shuffled(tech_bag)
	tray.clear()
	rare_row.clear()
	_draw_techs(D.TECH_START[clampi(n, 2, 6)] if n >= 2 else 12)
	# Centro Galattico
	hexes.clear()
	ships.clear()
	var gc := _new_hex(Vector2i.ZERO, 1, 0)
	hexes[D.key(Vector2i.ZERO)] = gc
	# giocatori
	ps.clear()
	var slots: Array = D.START_SLOTS[clampi(n, 2, 6)] if n >= 2 else [0]
	var used_slots := {}
	for p in n:
		var sid: String = players[p].get("species", D.COLOR_SPECIES[int(players[p].get("color", p))][0])
		var S := D.species(sid)
		var st := {
			"sp": sid, "S": S, "col": int(players[p].get("color", p)),
			"res": S["res"].duplicate(), "track": {"m": D.POP_START, "s": D.POP_START, "$": D.POP_START},
			"grave": {"m": 0, "s": 0, "$": 0},
			"discs": D.INF_SPACES - int(S.get("disc_minus", 0)), "disc_total": D.DISC_TOTAL - 3 - int(S.get("disc_minus", 0)),
			"colony": int(S["colony"]), "colony_used": 0,
			"techs": {"mil": [], "grid": [], "nano": []},
			"bp": {"int": [], "cru": [], "dre": [], "sb": []}, "outside": {"int": [], "cru": [], "dre": [], "sb": []},
			"spare": [], "rep": [], "disc_vp": 0, "passed": false, "acts_used": {}, "reacts": 0,
			"eliminated": false, "amb_left": int(S.get("amb", 3)), "warp_tile": "", "kills": 0,
			"types": S["types"].duplicate(), "minors": [], "shrines": [], "tech_disc": {}, "anc_used": 0, "wg_ability": false,
		}
		for s2 in S["types"]:
			st["outside"][s2] = S["outside"].get(s2, []).duplicate()
			if not st["bp"].has(s2):
				st["bp"][s2] = []
		for t in S["techs"]:
			var tc: String = D.TECHS[t]["cat"]
			st["techs"]["mil" if tc == "rare" else tc].append(t)
			rare_row.erase(t)
			tech_bag.erase(t)
		for s in S["types"]:
			var b: Array = S["bp_base"][s]
			var o := []
			for i in b.size():
				o.append("")
			st["bp"][s] = o
		ps.append(st)
		var slot: int = int(slots[p])
		used_slots[slot] = true
		var pos: Vector2i = D.DIRS[slot] * 2
		var hx := _new_hex(pos, int(S["home"]), _rot_facing_center(pos))
		hexes[D.key(pos)] = hx
		hx["owner"] = p
		st["discs"] -= 1
		# popolazione sui pianeti normali
		var pl: Array = D.SECTORS[int(S["home"])]["pl"]
		for i in pl.size():
			var code: String = pl[i]
			if code.ends_with("*"):
				if code == "s*" and S.get("home_adv_sci", false):
					hx["cubes"][i] = "s"
					st["track"]["s"] -= 1
				continue
			var tt := code
			if tt == "g":
				tt = "m"
			hx["cubes"][i] = tt
			st["track"][tt] -= 1
		_add_ship(p, "cru" if S.get("start_cruiser", false) else "int", D.key(pos))
		for i in int(S.get("start_ints", 1)) - 1:
			_add_ship(p, "int", D.key(pos))
		if S.get("start_orbital", false):
			hx["orb"] = true
		if S.get("tech_disc", false):
			st["tech_disc"] = _draw_disc()
		for i in int(S.get("start_rep", 0)):
			_rep_offer(p, [_draw_rep()], false)
	# Guardiani nelle zone di partenza libere (non con 6 giocatori)
	if n < 6:
		var gs: Array = _shuffled(D.GUARDIANS.duplicate())
		for slot in 6:
			if used_slots.has(slot) or gs.is_empty():
				continue
			var pos: Vector2i = D.DIRS[slot] * 2
			hexes[D.key(pos)] = _new_hex(pos, int(gs.pop_back()), _rot_facing_center(pos))
	start_player = 0
	turn_order = range(n)
	round_n = 1
	phase = "action"
	for p in n:
		ais[p] = null


func _shuffled(a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


## Rotazione che porta il lato 0 (la freccia) verso il centro.
func _rot_facing_center(pos: Vector2i) -> int:
	var to_c := -1
	for d in 6:
		if D.DIRS[d] * 2 == -pos or D.DIRS[d] == -pos:
			to_c = d
	if to_c < 0:
		return 0
	return to_c


func _new_hex(pos: Vector2i, num: int, rot: int) -> Dictionary:
	var S: Dictionary = D.SECTORS[num]
	var cubes := []
	for i in S["pl"].size():
		cubes.append("")
	var hx := {"pos": pos, "k": D.key(pos), "n": num, "rot": rot, "owner": -1, "cubes": cubes,
		"orb": false, "orb_cube": "", "mono": false, "disc": {}, "npc": [], "warp_tile": -1, "anc_portal": false, "entry": []}
	if S.get("disc", false):
		hx["disc"] = _draw_disc()
	hx["disc_more"] = []
	for i in int(S.get("disc_extra", 0)):
		hx["disc_more"].append(_draw_disc())
	hx["orb_unit"] = {"dmg": 0}
	hx["shrines"] = []
	if S.get("pulsar", false):
		hx["pulsar"] = "mov"
	for i in int(S.get("anc", 0)):
		hx["npc"].append({"k": "anc", "dmg": 0})
	if S.has("npc"):
		hx["npc"].append({"k": S["npc"], "dmg": 0})
	return hx


func _draw_disc() -> Dictionary:
	if disc_bag.is_empty():
		return {}
	return disc_bag.pop_back()


func _draw_rep() -> int:
	if rep_bag.is_empty():
		return 0
	return int(rep_bag.pop_back())


func _draw_techs(count: int) -> void:
	var drawn := 0
	while drawn < count and not tech_bag.is_empty():
		var t: String = tech_bag.pop_back()
		if D.TECHS[t]["cat"] == "rare":
			rare_row.append(t)
		else:
			tray[t] = int(tray.get(t, 0)) + 1
			drawn += 1


# ================================================================ utilità

func pname(p: int) -> String:
	if p < 0 or p >= n:
		return "neutrali"
	var nm: String = str(players[p].get("name", ""))
	return nm if nm != "" else D.species_title(ps[p]["sp"])


func pcol(p: int) -> int:
	return int(ps[p]["col"]) if p >= 0 and p < ps.size() else 0


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if replay_i < replay.size():
		return
	await get_tree().create_timer(sec / anim).timeout


func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	changed.emit()
	var r
	if replay_i < replay.size():
		r = replay[replay_i]
		replay_i += 1
	elif abort:
		r = ais[seat].decide(self, seat, req)
	elif online != null:
		r = await online.decide(self, seat, req)
	elif players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay / max(anim, 0.1)).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[seat].decide(self, seat, req)
	if not (r is Dictionary):
		r = {"stop": true}
	record.append(r)
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


func hex_at(k: String) -> Dictionary:
	return hexes.get(k, {})


func sector(hx: Dictionary) -> Dictionary:
	if hx.get("exploded", false):
		return D.EXPLODED
	return D.SECTORS[int(hx["n"])]


## Wormhole sul lato «edge» del settore piazzato.
func wh(hx: Dictionary, edge: int) -> bool:
	var w: Array = sector(hx)["wh"]
	return int(w[(edge - int(hx["rot"]) + 6) % 6]) == 1


func is_warp(hx: Dictionary) -> bool:
	return bool(sector(hx).get("warp", false)) or int(hx.get("warp_tile", -1)) >= 0 or bool(hx.get("anc_portal", false))


func has_tech(p: int, t: String) -> bool:
	for c in ps[p]["techs"]:
		if t in ps[p]["techs"][c]:
			return true
	return false


## Collegamento fra due settori (anche con il Generatore di wormhole di p, se half_ok).
func connected(a: Dictionary, b: Dictionary, p: int = -1, diplo := false) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var d := D.dir_to(a["pos"], b["pos"])
	if d >= 0:
		var w1 := wh(a, d)
		var w2 := wh(b, (d + 3) % 6)
		if w1 and w2:
			return true
		if not diplo and p >= 0 and (w1 or w2) and wg(p):
			return true
	if is_warp(a) and is_warp(b) and a["k"] != b["k"]:
		return true
	return false


func neighbors(hx: Dictionary) -> Array:
	var out := []
	for d in 6:
		var k := D.key(hx["pos"] + D.DIRS[d])
		if hexes.has(k):
			out.append(hexes[k])
	if is_warp(hx):
		for k in hexes:
			var o: Dictionary = hexes[k]
			if o["k"] != hx["k"] and is_warp(o) and not out.has(o):
				out.append(o)
	return out


func ships_in(k: String, p: int = -99) -> Array:
	var out := []
	for s in ships:
		if s["h"] == k and (p == -99 or int(s["p"]) == p):
			out.append(s)
	return out


func ship_by_id(id: int) -> Dictionary:
	for s in ships:
		if int(s["id"]) == id:
			return s
	return {}


func owners_in(k: String) -> Array:
	var out := []
	for s in ships:
		if s["h"] == k and not out.has(int(s["p"])):
			out.append(int(s["p"]))
	return out


func count_ships(p: int, t: String) -> int:
	var c := 0
	for s in ships:
		if int(s["p"]) == p and s["t"] == t:
			c += 1
	return c


func _add_ship(p: int, t: String, k: String) -> Dictionary:
	var s := {"id": next_ship_id, "p": p, "t": t, "h": k, "dmg": 0, "ret": "", "ret_round": -1}
	next_ship_id += 1
	ships.append(s)
	_enter(p, k)
	return s


func _enter(p: int, k: String) -> void:
	var hx: Dictionary = hexes[k]
	var e: Array = hx["entry"]
	if not e.has(p):
		e.append(p)


func _leave_check(k: String) -> void:
	var hx: Dictionary = hexes.get(k, {})
	if hx.is_empty():
		return
	var e: Array = hx["entry"]
	for p in e.duplicate():
		if ships_in(k, p).is_empty():
			e.erase(p)


## Navi che bloccano le navi di p nel settore (gli Antichi non bloccano Draco, l'SDCG blocca tutto).
func pin_power(k: String, p: int) -> int:
	var c := 0
	for s in ships:
		if s["h"] == k and int(s["p"]) != p:
			c += 1
	var hx: Dictionary = hexes[k]
	for npc in hx["npc"]:
		if npc["k"] == "gcds":
			return 999
		if npc["k"] == "anc" and ps[p]["S"].get("ancient_friend", false):
			continue
		c += 1
	if has_tech(p, "cloaking_device"):
		c = int(c / 2)
	return c


func unpinned(k: String, p: int) -> bool:
	var own := ships_in(k, p).size()
	return own > pin_power(k, p)


func controls(p: int) -> Array:
	var out := []
	for k in hexes:
		if int(hexes[k]["owner"]) == p:
			out.append(hexes[k])
	return out


func npc_blocks(hx: Dictionary, p: int) -> bool:
	for npc in hx["npc"]:
		if npc["k"] != "anc" or not ps[p]["S"].get("ancient_friend", false):
			return true
	return false


# ---------------------------------------------------------------- risorse

func prod(p: int, r: String) -> int:
	var c: int = int(ps[p]["track"][r])
	if c >= 12:
		return 0
	return D.POP_VALUES[11 - max(c, 0)]


func upkeep(p: int) -> int:
	var dsc: int = int(ps[p]["discs"])
	if dsc >= D.INF_SPACES:
		return 0
	return D.INF_VALUES[clampi(12 - dsc, 0, 12)]


## Upkeep se si usasse un altro disco.
func upkeep_next(p: int) -> int:
	var dsc: int = int(ps[p]["discs"]) - 1
	if dsc >= D.INF_SPACES:
		return 0
	return D.INF_VALUES[clampi(12 - dsc, 0, 12)]


func trade_rate(p: int) -> int:
	return int(ps[p]["S"]["trade"])


## Scambio da una risorsa: [quante se ne pagano, quante se ne ricevono].
func trade_pair(p: int, from: String) -> Array:
	return ps[p]["S"]["trade_rates"].get(from, [trade_rate(p), 1])


func wg(p: int) -> bool:
	return has_tech(p, "wormhole_generator") or bool(ps[p].get("wg_ability", false))


## Quanto di r si può ottenere in tutto, scambiando le altre risorse.
func spendable(p: int, r: String) -> int:
	var t: int = int(ps[p]["res"][r])
	for o in D.RES:
		if o != r:
			var tp := trade_pair(p, o)
			t += int(int(ps[p]["res"][o]) / int(tp[0])) * int(tp[1])
	return t


func can_pay(p: int, r: String, amount: int) -> bool:
	return spendable(p, r) >= amount


## Paga, scambiando automaticamente le altre risorse se non basta (prima quella più abbondante).
func pay(p: int, r: String, amount: int) -> bool:
	if not can_pay(p, r, amount):
		return false
	var res: Dictionary = ps[p]["res"]
	while int(res[r]) < amount:
		var best := ""
		for o in D.RES:
			if o != r and int(res[o]) >= int(trade_pair(p, o)[0]) and (best == "" or int(res[o]) > int(res[best])):
				best = o
		if best == "":
			return false
		var tp := trade_pair(p, best)
		res[best] = int(res[best]) - int(tp[0])
		res[r] = int(res[r]) + int(tp[1])
		log_msg("%s scambia %d %s per %d %s." % [pname(p), int(tp[0]), D.RES_NAME[best].to_lower(), int(tp[1]), D.RES_NAME[r].to_lower()])
	res[r] = int(res[r]) - amount
	return true


func _return_cube(p: int, t: String, grave := false) -> void:
	var st: Dictionary = ps[p]
	if grave:
		st["grave"][t] = int(st["grave"][t]) + 1
		return
	if int(st["track"][t]) >= 12:
		for o in ["$", "s", "m"]:
			if int(st["track"][o]) < 12:
				t = o
				break
	st["track"][t] = int(st["track"][t]) + 1


## Il tracciato migliore su cui rimettere un cubetto da un pianeta grigio o da un orbitale.
func _best_track(p: int, allowed: Array) -> String:
	var best := ""
	for t in allowed:
		if int(ps[p]["track"][t]) < 12 and (best == "" or int(ps[p]["track"][t]) < int(ps[p]["track"][best])):
			best = t
	return best if best != "" else allowed[0]


## Toglie il disco da un settore: i cubetti tornano sui tracciati.
func _remove_disc(hx: Dictionary, grave := false) -> void:
	var p: int = int(hx["owner"])
	if p < 0:
		return
	var pl: Array = sector(hx)["pl"]
	for i in hx["cubes"].size():
		var c: String = hx["cubes"][i]
		if c == "":
			continue
		hx["cubes"][i] = ""
		_return_cube(p, c, grave)
	if hx["orb_cube"] != "":
		_return_cube(p, hx["orb_cube"], grave)
		hx["orb_cube"] = ""
	hx["owner"] = -1
	ps[p]["discs"] = int(ps[p]["discs"]) + 1


func _place_disc(p: int, hx: Dictionary) -> bool:
	if int(ps[p]["discs"]) <= 0:
		return false
	ps[p]["discs"] = int(ps[p]["discs"]) - 1
	hx["owner"] = p
	if not hx["disc"].is_empty() and hx["npc"].is_empty() and ships_in(hx["k"]).is_empty():
		pass
	return true


# ---------------------------------------------------------------- progetti delle navi

func part_at(p: int, s: String, i: int) -> String:
	var ov: String = ps[p]["bp"][s][i]
	if ov != "":
		return ov
	return ps[p]["S"]["bp_base"][s][i]


func ship_stats(p: int, s: String) -> Dictionary:
	var st := {"en_p": 0, "en_u": 0, "comp": 0, "sh": 0, "hull": 0, "mv": 0, "ini": 0, "can": [], "mis": [], "regen": 0, "drives": 0}
	var S: Dictionary = ps[p]["S"]
	st["ini"] = int(S["ini"][s])
	var bonus: Dictionary = S.get("bonus", {}).get(s, {})
	st["en_p"] += int(bonus.get("en", 0))
	st["comp"] += int(bonus.get("comp", 0))
	st["hull"] += int(bonus.get("hull", 0))
	var parts := []
	for i in ps[p]["bp"][s].size():
		var pt := part_at(p, s, i)
		if pt != "":
			parts.append(pt)
	for pt in ps[p]["outside"][s]:
		parts.append(pt)
	for pt in parts:
		var P: Dictionary = D.PARTS[pt]
		var e: int = int(P.get("en", 0))
		if e > 0:
			st["en_p"] += e
		else:
			st["en_u"] -= e
		st["comp"] += int(P.get("comp", 0))
		st["sh"] += int(P.get("sh", 0))
		st["hull"] += int(P.get("hull", 0))
		st["mv"] += int(P.get("mv", 0))
		st["ini"] += int(P.get("ini", 0))
		st["regen"] += int(P.get("regen", 0))
		if int(P.get("mv", 0)) > 0:
			st["drives"] += 1
		for d in P.get("can", []):
			st["can"].append(d)
		for d in P.get("mis", []):
			st["mis"].append(d)
	if s == "sb" or s == "orb":
		st["mv"] = 0
	return st


func npc_stats(k: String) -> Dictionary:
	var b: Dictionary = D.NPC_BP[k][int(npc_var[k])]
	return {"comp": int(b.get("comp", 0)), "sh": int(b.get("sh", 0)), "hull": int(b.get("hull", 0)), "ini": int(b.get("ini", 0)),
		"can": b.get("can", []), "mis": b.get("mis", []), "regen": 0, "mv": 0}


## Il progetto con la parte pt nella casella i è valido?
func bp_valid_with(p: int, s: String, i: int, pt: String) -> bool:
	var old: String = ps[p]["bp"][s][i]
	ps[p]["bp"][s][i] = pt
	var st := ship_stats(p, s)
	ps[p]["bp"][s][i] = old
	if st["en_u"] > st["en_p"]:
		return false
	if s == "sb" or s == "orb":
		return st["drives"] == 0
	return st["drives"] >= 1


func parts_available(p: int) -> Array:
	var out := []
	for pt in D.PARTS:
		var P: Dictionary = D.PARTS[pt]
		if P.get("anc", false):
			continue
		var t: String = P.get("tech", "")
		if t == "" or has_tech(p, t):
			out.append(pt)
	for pt in ps[p]["spare"]:
		if not out.has(pt) and not D.PARTS[pt].get("outside", false):
			out.append(pt)
	return out


func upgrade_opts(p: int) -> Array:
	var out := []
	var avail := parts_available(p)
	for s in ps[p]["types"]:
		for i in ps[p]["bp"][s].size():
			var cur := part_at(p, s, i)
			if cur != "" and D.PARTS[cur].get("fixed", false):
				continue
			for pt in avail:
				if pt == cur:
					continue
				if (s == "sb" or s == "orb") and int(D.PARTS[pt].get("mv", 0)) > 0:
					continue
				if bp_valid_with(p, s, i, pt):
					out.append({"s": s, "i": i, "part": pt})
	return out


func _apply_part(p: int, s: String, i: int, pt: String) -> void:
	var old: String = ps[p]["bp"][s][i]
	if old != "" and D.PARTS[old].get("anc", false):
		pass  # le parti antiche tolte escono dal gioco
	ps[p]["bp"][s][i] = pt
	if D.PARTS[pt].get("anc", false):
		ps[p]["spare"].erase(pt)
		ps[p]["anc_used"] = int(ps[p]["anc_used"]) + 1


# ---------------------------------------------------------------- tecnologie

func tech_cost(p: int, t: String, cat := "") -> int:
	var T: Dictionary = D.TECHS[t]
	var c: String = T["cat"]
	if c == "rare":
		c = cat if cat != "" else _best_track_for_rare(p)
	var k: int = ps[p]["techs"][c].size()
	if k >= 7:
		return 999
	var minor := 1 if ps[p]["minors"].has("res") else 0
	return max(int(T["min"]), int(T["cost"]) - D.TECH_DISCOUNT[k] - minor)


func _best_track_for_rare(p: int) -> String:
	var best := ""
	for c in D.TECH_CATS:
		var k: int = ps[p]["techs"][c].size()
		if k < 7 and (best == "" or k > ps[p]["techs"][best].size()):
			best = c
	return best if best != "" else "mil"


func research_opts(p: int) -> Array:
	var out := []
	var seen := {}
	for t in tray:
		if int(tray[t]) <= 0 or has_tech(p, t):
			continue
		var c: String = D.TECHS[t]["cat"]
		if ps[p]["techs"][c].size() >= 7:
			continue
		var cost := tech_cost(p, t)
		if can_pay(p, "s", cost):
			out.append({"t": t, "cost": cost})
	for t in rare_row:
		if seen.has(t) or has_tech(p, t):
			continue
		seen[t] = true
		var cost := tech_cost(p, t)
		if cost < 999 and can_pay(p, "s", cost):
			out.append({"t": t, "cost": cost, "rare": true})
	return out


func _gain_tech(p: int, t: String, cat := "") -> void:
	var c: String = D.TECHS[t]["cat"]
	if c == "rare":
		c = cat if cat != "" and ps[p]["techs"].has(cat) and ps[p]["techs"][cat].size() < 7 else _best_track_for_rare(p)
		rare_row.erase(t)
	else:
		tray[t] = int(tray[t]) - 1
		if int(tray[t]) <= 0:
			tray.erase(t)
	ps[p]["techs"][c].append(t)
	if ps[p]["techs"][c].size() >= 4 and not ps[p]["tech_disc"].is_empty():
		ps[p]["tech_disc_ready"] = true


## Custodi di Magellano: la scoperta sotto i tracciati si risolve alla quarta tecnologia.
func _check_tech_disc(p: int) -> void:
	if not ps[p].get("tech_disc_ready", false):
		return
	ps[p]["tech_disc_ready"] = false
	var tile: Dictionary = ps[p]["tech_disc"]
	ps[p]["tech_disc"] = {}
	log_msg("%s risolve la scoperta dei Custodi." % pname(p))
	await _discovery(p, tile, home_of(p))


func home_of(p: int) -> String:
	for hx in controls(p):
		if sector(hx).get("home", false):
			return hx["k"]
	return ""


# ================================================================ partita

func run() -> void:
	log_msg("Inizia la partita: %d civiltà si contendono la galassia." % n)
	while round_n <= D.ROUNDS and not abort:
		log_msg("— Round %d —" % round_n)
		phase = "action"
		changed.emit()
		await _action_phase()
		if abort:
			return
		phase = "combat"
		changed.emit()
		await _combat_phase()
		if abort:
			return
		phase = "upkeep"
		changed.emit()
		await _upkeep_phase()
		if abort:
			return
		history.append(scores_now())
		if round_n == D.ROUNDS:
			break
		phase = "cleanup"
		await _cleanup()
		round_n += 1
		changed.emit()
	_finish()


func alive_players() -> Array:
	var out := []
	for p in n:
		if not ps[p]["eliminated"]:
			out.append(p)
	return out


func _action_phase() -> void:
	first_pass = -1
	pass_order = []
	pulsar_used = {}
	for p in n:
		ps[p]["passed"] = ps[p]["eliminated"]
	var order: Array = []
	if turn_var:
		order = turn_order.duplicate()
	else:
		for i in n:
			order.append((start_player + i) % n)
	var idx := 0
	var guard := 0
	while not abort:
		var all_passed := true
		for p in n:
			if not ps[p]["passed"]:
				all_passed = false
		if all_passed:
			break
		var cur: int = order[idx % order.size()]
		if not ps[cur]["eliminated"]:
			await _hole_returns(cur)
			await _turn(cur)
		idx += 1
		guard += 1
		if guard > 500:
			break


func turn_opts(p: int) -> Array:
	var st: Dictionary = ps[p]
	var out := []
	if int(st["discs"]) <= 0:
		return out
	if st["passed"]:
		if not upgrade_opts(p).is_empty():
			out.append("r_upg")
		if not build_opts(p).is_empty():
			out.append("r_bui")
		if not move_opts(p).is_empty():
			out.append("r_mov")
		return out
	if not explore_zones(p).is_empty():
		out.append("exp")
	if not research_opts(p).is_empty():
		out.append("res")
	if not upgrade_opts(p).is_empty():
		out.append("upg")
	if not build_opts(p).is_empty():
		out.append("bui")
	if not move_opts(p).is_empty():
		out.append("mov")
	if not influence_targets(p).is_empty() or not controls(p).is_empty():
		out.append("inf")
	return out


func _turn(p: int) -> void:
	var free := 0
	while not abort:
		var opts := turn_opts(p)
		var req := {"type": "turn", "passed": ps[p]["passed"], "opts": opts, "colony": not colony_opts(p).is_empty(),
			"diplo": diplo_targets(p), "trade": trade_rate(p), "pulsars": pulsar_opts(p), "minors": minor_opts(p),
			"colony_res": ps[p]["S"].get("colony_res", false) and int(ps[p]["colony_used"]) < int(ps[p]["colony"])}
		var r: Dictionary = await decide(p, req)
		var a: String = r.get("a", "pass")
		if free > 40 and a in ["colony", "trade", "diplo", "minor", "colony_res"]:
			a = "pass"
		match a:
			"pulsar":
				var pk := str(r.get("h", ""))
				var pa := str(r.get("act", ""))
				if pulsar_opts(p).has(pk) and pa in D.PULSAR_ACTS and pa != str(hexes[pk].get("pulsar", "mov")):
					await _pulsar(p, pk, pa)
					_aggression_check(p)
					changed.emit()
					return
				continue
			"minor":
				free += 1
				_take_minor(p, str(r.get("m", "")))
				changed.emit()
				continue
			"colony_res":
				free += 1
				var cr := str(r.get("r", "$"))
				if D.RES.has(cr) and int(ps[p]["colony_used"]) < int(ps[p]["colony"]):
					ps[p]["colony_used"] = int(ps[p]["colony_used"]) + 1
					ps[p]["res"][cr] = int(ps[p]["res"][cr]) + 1
					log_msg("%s gira una nave coloniale: +1 %s." % [pname(p), D.RES_NAME[cr].to_lower()])
				changed.emit()
				continue
			"colony":
				free += 1
				await _colony(p, false)
				changed.emit()
				continue
			"trade":
				free += 1
				_trade(p, str(r.get("from", "$")), str(r.get("to", "m")), int(r.get("n", 1)))
				changed.emit()
				continue
			"diplo":
				free += 1
				await _diplo(p, int(r.get("t", -1)))
				changed.emit()
				continue
			"pass":
				if not ps[p]["passed"]:
					ps[p]["passed"] = true
					pass_order.append(p)
					if first_pass < 0:
						first_pass = p
						ps[p]["res"]["$"] = int(ps[p]["res"]["$"]) + 2
						log_msg("%s passa per primo: +2 denaro e sarà primo giocatore." % pname(p))
					else:
						log_msg("%s passa." % pname(p))
				changed.emit()
				return
		if not opts.has(a):
			# scelta non valida: si passa
			if not ps[p]["passed"]:
				ps[p]["passed"] = true
				pass_order.append(p)
				if first_pass < 0:
					first_pass = p
					ps[p]["res"]["$"] = int(ps[p]["res"]["$"]) + 2
			return
		ps[p]["discs"] = int(ps[p]["discs"]) - 1
		if a.begins_with("r_"):
			ps[p]["reacts"] = int(ps[p]["reacts"]) + 1
			var b := a.substr(2)
			log_msg("%s reagisce: %s." % [pname(p), D.ACTION_NAME[b]])
			fx.emit("action", {"p": p, "a": b, "react": true})
			match b:
				"upg":
					await _upgrade(p, 1)
				"bui":
					await _build(p, 1)
				"mov":
					await _move(p, 1)
		else:
			ps[p]["acts_used"][a] = int(ps[p]["acts_used"].get(a, 0)) + 1
			log_msg("%s: %s." % [pname(p), D.ACTION_NAME[a]])
			fx.emit("action", {"p": p, "a": a, "react": false})
			var acts: Dictionary = ps[p]["S"]["acts"]
			match a:
				"exp":
					await _explore(p, int(acts["exp"]))
				"res":
					await _research(p, int(acts["res"]))
					if ps[p]["S"].get("shrines", false):
						await _shrine(p)
				"upg":
					await _upgrade(p, int(acts["upg"]) + (2 if has_tech(p, "pico_modulator") else 0))
				"bui":
					await _build(p, int(acts["bui"]) + (1 if has_tech(p, "nanorobots") else 0))
				"mov":
					await _move(p, int(acts["mov"]) + (1 if has_tech(p, "improved_logistics") else 0))
				"inf":
					await _influence(p, int(acts["inf"]))
		_aggression_check(p)
		changed.emit()
		return


func _trade(p: int, from: String, to: String, amount: int) -> void:
	if from == to or not D.RES.has(from) or not D.RES.has(to) or amount <= 0:
		return
	var tp := trade_pair(p, from)
	var res: Dictionary = ps[p]["res"]
	amount = min(amount, int(int(res[from]) / int(tp[0])))
	if amount <= 0:
		return
	res[from] = int(res[from]) - amount * int(tp[0])
	res[to] = int(res[to]) + amount * int(tp[1])
	log_msg("%s scambia %d %s per %d %s." % [pname(p), amount * int(tp[0]), D.RES_NAME[from].to_lower(), amount * int(tp[1]), D.RES_NAME[to].to_lower()])


# ---------------------------------------------------------------- esplorazione

func explore_zones(p: int) -> Array:
	var out := []
	var wgen := wg(p)
	for k in hexes:
		var hx: Dictionary = hexes[k]
		if not (int(hx["owner"]) == p or (not ships_in(k, p).is_empty() and unpinned(k, p))):
			continue
		for d in 6:
			var z: Vector2i = hx["pos"] + D.DIRS[d]
			var zk := D.key(z)
			if hexes.has(zk) or out.has(zk):
				continue
			if D.dist(z) > D.MAX_DIST:
				continue
			if not wh(hx, d) and not wgen:
				continue
			var ring := D.ring_of(z)
			if stacks[ring].is_empty() and discards[ring].is_empty():
				continue
			out.append(zk)
	return out


## Rotazioni valide per piazzare il settore num nella zona z.
func place_rots(p: int, num: int, zk: String) -> Array:
	var out := []
	var z := D.unkey(zk)
	var wgen := wg(p)
	var w: Array = D.SECTORS[num]["wh"]
	for rot in 6:
		var ok := false
		for d in 6:
			var nk := D.key(z + D.DIRS[d])
			if not hexes.has(nk):
				continue
			var hx: Dictionary = hexes[nk]
			if not (int(hx["owner"]) == p or (not ships_in(nk, p).is_empty() and unpinned(nk, p))):
				continue
			var mine := int(w[(d - rot + 6) % 6]) == 1
			var theirs := wh(hx, (d + 3) % 6)
			if mine and (theirs or wgen):
				ok = true
				break
		if ok:
			out.append(rot)
	return out


func _draw_sector(ring: int) -> int:
	if stacks[ring].is_empty():
		stacks[ring] = _shuffled(discards[ring])
		discards[ring] = []
	if stacks[ring].is_empty():
		return -1
	return int(stacks[ring].pop_back())


func _explore(p: int, count: int) -> void:
	for i in count:
		var zones := explore_zones(p)
		if zones.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "explore", "zones": zones, "left": count - i})
		if r.get("stop", false) or not zones.has(str(r.get("z", ""))):
			break
		var zk: String = r["z"]
		var ring := D.ring_of(D.unkey(zk))
		var tiles := []
		for j in (2 if ps[p]["S"].get("draw2", false) else 1):
			var t := _draw_sector(ring)
			if t >= 0:
				tiles.append(t)
		if tiles.is_empty():
			continue
		var rots := {}
		for t in tiles:
			rots[str(t)] = place_rots(p, t, zk)
		fx.emit("reveal", {"p": p, "z": zk, "tiles": tiles})
		var r2: Dictionary = await decide(p, {"type": "place", "zone": zk, "tiles": tiles, "rots": rots})
		var chosen := int(r2.get("tile", -1))
		if r2.get("discard", false) or not tiles.has(chosen) or not rots[str(chosen)].has(int(r2.get("rot", -1))):
			for t in tiles:
				discards[ring].append(t)
			log_msg("%s scarta il settore esplorato." % pname(p))
			fx.emit("discard", {"z": zk})
			break
		for t in tiles:
			if t != chosen:
				discards[ring].append(t)
		var hx := _new_hex(D.unkey(zk), chosen, int(r2["rot"]))
		hexes[zk] = hx
		log_msg("%s scopre %s (%d)." % [pname(p), sector(hx)["name"], chosen])
		fx.emit("place", {"p": p, "h": zk})
		changed.emit()
		await _pace(0.5)
		var friendly: bool = not npc_blocks(hx, p) and not sector(hx).get("nebula", false) and not sector(hx).has("hole")
		var later: bool = sector(hx).get("nebula", false) or sector(hx).has("hole")
		if not hx["disc"].is_empty() and hx["npc"].is_empty() and not later:
			var tile: Dictionary = hx["disc"]
			hx["disc"] = {}
			await _discovery(p, tile, zk)
		if friendly and int(ps[p]["discs"]) > 0:
			var r3: Dictionary = await decide(p, {"type": "claim", "h": zk, "why": "explore"})
			if r3.get("yes", false):
				_place_disc(p, hx)
				log_msg("%s prende il controllo di %s." % [pname(p), sector(hx)["name"]])
				fx.emit("influence", {"p": p, "h": zk})
				changed.emit()


# ---------------------------------------------------------------- scoperte

func _discovery(p: int, tile: Dictionary, hk: String) -> void:
	if tile.is_empty():
		return
	var r: Dictionary = await decide(p, {"type": "discovery", "tile": tile, "h": hk})
	fx.emit("discovery", {"p": p, "tile": tile, "vp": r.get("vp", false)})
	if r.get("vp", false):
		ps[p]["disc_vp"] = int(ps[p]["disc_vp"]) + 1
		log_msg("%s tiene la scoperta come 2 PV." % pname(p))
		return
	var res: Dictionary = ps[p]["res"]
	var hx: Dictionary = hexes.get(hk, {})
	if not hx.is_empty() and sector(hx).get("nebula", false) and str(tile["k"]) in ["orbital", "monolith"]:
		# orbitali e monoliti non vanno nelle nebulose: si pesca un'altra tessera
		var t2 := _draw_disc()
		if not t2.is_empty():
			await _discovery(p, t2, hk)
			return
	match str(tile["k"]):
		"mat6":
			res["m"] = int(res["m"]) + 6
		"sci5":
			res["s"] = int(res["s"]) + 5
		"money8":
			res["$"] = int(res["$"]) + 8
		"mix":
			res["m"] = int(res["m"]) + 2
			res["s"] = int(res["s"]) + 2
			res["$"] = int(res["$"]) + 3
		"tech":
			var best := ""
			for t in tray:
				if int(tray[t]) <= 0 or has_tech(p, t):
					continue
				if ps[p]["techs"][D.TECHS[t]["cat"]].size() >= 7:
					continue
				if best == "" or int(D.TECHS[t]["cost"]) < int(D.TECHS[best]["cost"]):
					best = t
			if best != "":
				_gain_tech(p, best)
				await _tech_instant(p, best)
				await _check_tech_disc(p)
				log_msg("%s ottiene la tecnologia %s." % [pname(p), D.tech_name(best)])
			else:
				ps[p]["disc_vp"] = int(ps[p]["disc_vp"]) + 1
		"cruiser":
			if count_ships(p, "cru") < D.SHIP_LIMIT["cru"] and not hx.is_empty():
				_add_ship(p, "cru", hk)
			else:
				ps[p]["disc_vp"] = int(ps[p]["disc_vp"]) + 1
		"orbital":
			res["m"] = int(res["m"]) + 2
			if not hx.is_empty() and not hx["orb"]:
				hx["orb"] = true
		"monolith":
			if not hx.is_empty() and not hx["mono"]:
				hx["mono"] = true
			else:
				ps[p]["disc_vp"] = int(ps[p]["disc_vp"]) + 1
		"warp":
			if not hx.is_empty():
				hx["anc_portal"] = true
		"part":
			var pt: String = tile["part"]
			if D.PARTS[pt].get("outside", false):
				var oo := []
				for t2 in ps[p]["types"]:
					oo.append([t2, -1])
				var r2: Dictionary = await decide(p, {"type": "part", "part": pt, "opts": oo})
				var s: String = r2.get("s", "")
				if not ps[p]["types"].has(s):
					s = ps[p]["types"][0]
				ps[p]["outside"][s].append(pt)
				ps[p]["anc_used"] = int(ps[p]["anc_used"]) + 1
			else:
				var opts := []
				for s in ps[p]["types"]:
					for i in ps[p]["bp"][s].size():
						if (s == "sb" or s == "orb") and int(D.PARTS[pt].get("mv", 0)) > 0:
							continue
						var cur := part_at(p, s, i)
						if cur != "" and D.PARTS[cur].get("fixed", false):
							continue
						if bp_valid_with(p, s, i, pt):
							opts.append([s, i])
				var r2: Dictionary = await decide(p, {"type": "part", "part": pt, "opts": opts})
				var ok := false
				for o in opts:
					if o[0] == r2.get("s", "") and int(o[1]) == int(r2.get("i", -9)):
						ok = true
				if ok:
					_apply_part(p, r2["s"], int(r2["i"]), pt)
				else:
					ps[p]["spare"].append(pt)
	log_msg("%s usa la scoperta: %s." % [pname(p), disc_name(tile)])
	changed.emit()


func disc_name(tile: Dictionary) -> String:
	if tile.get("k", "") == "part":
		return "parte antica: %s" % D.part_name(tile["part"])
	return str(tile.get("name", ""))


# ---------------------------------------------------------------- ricerca

func _research(p: int, count: int) -> void:
	for i in count:
		var opts := research_opts(p)
		if opts.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "research", "opts": opts, "left": count - i})
		if r.get("stop", false):
			break
		var t: String = r.get("t", "")
		var ok := false
		for o in opts:
			if o["t"] == t:
				ok = true
		if not ok:
			break
		var cat: String = r.get("cat", "")
		var cost := tech_cost(p, t, cat)
		pay(p, "s", cost)
		_gain_tech(p, t, cat)
		log_msg("%s ricerca %s (%d scienza)." % [pname(p), D.tech_name(t), cost])
		fx.emit("tech", {"p": p, "t": t})
		await _tech_instant(p, t)
		await _check_tech_disc(p)
		changed.emit()
		await _pace(0.3)


func _tech_instant(p: int, t: String) -> void:
	match t:
		"quantum_grid":
			ps[p]["discs"] = int(ps[p]["discs"]) + 2
			ps[p]["disc_total"] = int(ps[p]["disc_total"]) + 2
		"advanced_robotics":
			ps[p]["discs"] = int(ps[p]["discs"]) + 1
			ps[p]["disc_total"] = int(ps[p]["disc_total"]) + 1
		"artifact_key":
			var c := 0
			for hx in controls(p):
				if sector(hx).get("art", false):
					c += 1
			if c > 0:
				var r: Dictionary = await decide(p, {"type": "artifact", "n": c * 5})
				var rr: String = r.get("r", "s")
				if not D.RES.has(rr):
					rr = "s"
				ps[p]["res"][rr] = int(ps[p]["res"][rr]) + c * 5
				log_msg("%s riceve %d %s dagli artefatti." % [pname(p), c * 5, D.RES_NAME[rr].to_lower()])
		"warp_portal":
			var opts := []
			for hx in controls(p):
				if int(hx["warp_tile"]) < 0:
					opts.append(hx["k"])
			if not opts.is_empty():
				var r: Dictionary = await decide(p, {"type": "warp", "opts": opts})
				var h: String = r.get("h", opts[0])
				if not opts.has(h):
					h = opts[0]
				hexes[h]["warp_tile"] = p
		"ancient_labs":
			var tile := _draw_disc()
			var home := ""
			for hx in controls(p):
				if sector(hx).get("home", false):
					home = hx["k"]
			if home == "" and not controls(p).is_empty():
				home = controls(p)[0]["k"]
			await _discovery(p, tile, home)


# ---------------------------------------------------------------- potenziamento

func _upgrade(p: int, count: int) -> void:
	for i in count:
		var opts := upgrade_opts(p)
		if opts.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "upgrade", "opts": opts, "left": count - i})
		if r.get("stop", false):
			break
		var ok := false
		for o in opts:
			if o["s"] == r.get("s", "") and int(o["i"]) == int(r.get("i", -1)) and o["part"] == r.get("part", ""):
				ok = true
		if not ok:
			break
		_apply_part(p, r["s"], int(r["i"]), r["part"])
		log_msg("%s monta %s sul progetto %s." % [pname(p), D.part_name(r["part"]), D.SHIP_NAME[r["s"]].to_lower()])
		fx.emit("upgrade", {"p": p, "s": r["s"]})
		changed.emit()


# ---------------------------------------------------------------- costruzione

func build_cost(p: int, w: String) -> int:
	var c: int = int(ps[p]["S"]["cost"].get(w, 99))
	if ps[p]["minors"].has(w):
		c -= int(D.MINOR_DISC.get(w, 0))
	return max(1, c)


func build_opts(p: int) -> Array:
	var out := []
	var mine := controls(p)
	for w in ["int", "cru", "dre", "sb", "orb", "mono"]:
		if not ps[p]["S"]["cost"].has(w):
			continue
		if w in D.SHIP_TYPES and not ps[p]["types"].has(w):
			continue
		if not can_pay(p, "m", build_cost(p, w)):
			continue
		if D.SHIP_LIMIT.has(w) and count_ships(p, w) >= int(D.SHIP_LIMIT[w]):
			continue
		if w == "sb" and not has_tech(p, "starbase"):
			continue
		if w == "orb" and not has_tech(p, "orbital"):
			continue
		if w == "mono" and not has_tech(p, "monolith"):
			continue
		for hx in mine:
			if w == "orb" and hx["orb"]:
				continue
			if w == "mono" and hx["mono"]:
				continue
			out.append({"w": w, "h": hx["k"]})
	return out


func _build(p: int, count: int) -> void:
	for i in count:
		var opts := build_opts(p)
		if opts.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "build", "opts": opts, "left": count - i})
		if r.get("stop", false):
			break
		var ok := false
		for o in opts:
			if o["w"] == r.get("w", "") and o["h"] == r.get("h", ""):
				ok = true
		if not ok:
			break
		var w: String = r["w"]
		var hk: String = r["h"]
		pay(p, "m", build_cost(p, w))
		var hx: Dictionary = hexes[hk]
		match w:
			"orb":
				hx["orb"] = true
				log_msg("%s costruisce un orbitale in %s." % [pname(p), sector(hx)["name"]])
			"mono":
				hx["mono"] = true
				log_msg("%s costruisce un monolito in %s." % [pname(p), sector(hx)["name"]])
			_:
				_add_ship(p, w, hk)
				log_msg("%s costruisce: %s in %s." % [pname(p), D.SHIP_NAME[w].to_lower(), sector(hx)["name"]])
		fx.emit("build", {"p": p, "w": w, "h": hk})
		changed.emit()
		await _pace(0.25)


# ---------------------------------------------------------------- movimento

## Destinazioni di una nave (con il percorso più breve).
func ship_dests(s: Dictionary) -> Dictionary:
	var p: int = int(s["p"])
	var mv: int = int(ship_stats(p, s["t"])["mv"])
	var out := {}
	if mv <= 0 or s["t"] == "sb":
		return out
	var start: String = s["h"]
	if not hexes.has(start) or not unpinned(start, p):
		return out
	var frontier := [[start, [start]]]
	var seen := {start: true}
	for step in mv:
		var nxt := []
		for f in frontier:
			var hx: Dictionary = hexes[f[0]]
			if f[0] != start:
				# una nave che entra dove ci sono nemici si ferma se è bloccata
				var own := ships_in(f[0], p).size() + 1
				if own <= pin_power(f[0], p):
					continue
			for nb in neighbors(hx):
				if seen.has(nb["k"]):
					continue
				if not connected(hx, nb, p):
					continue
				seen[nb["k"]] = true
				var path: Array = f[1].duplicate()
				path.append(nb["k"])
				out[nb["k"]] = path
				if not sector(nb).has("hole"):
					nxt.append([nb["k"], path])
		frontier = nxt
	return out


func move_opts(p: int) -> Dictionary:
	var out := {}
	for s in ships:
		if int(s["p"]) != p:
			continue
		var d := ship_dests(s)
		if not d.is_empty():
			out[str(s["id"])] = d.keys()
	return out


func _move(p: int, count: int) -> void:
	for i in count:
		var opts := move_opts(p)
		if opts.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "move", "opts": opts, "left": count - i})
		if r.get("stop", false):
			break
		var id := str(r.get("id", ""))
		var to: String = str(r.get("to", ""))
		if not opts.has(id) or not opts[id].has(to):
			break
		var s := ship_by_id(int(id))
		var path: Array = ship_dests(s)[to]
		var from: String = s["h"]
		s["h"] = to
		_enter(p, to)
		_leave_check(from)
		log_msg("%s muove %s da %s a %s." % [pname(p), D.SHIP_NAME[s["t"]].to_lower(), sector(hexes[from])["name"], sector(hexes[to])["name"]])
		fx.emit("move", {"p": p, "id": int(id), "path": path})
		changed.emit()
		await _pace(0.5)
		if sector(hexes[to]).has("hole"):
			await _enter_hole(p, s, to)


# ---------------------------------------------------------------- influenza

func influence_targets(p: int) -> Array:
	var out := []
	for k in hexes:
		var hx: Dictionary = hexes[k]
		if int(hx["owner"]) >= 0 or npc_blocks(hx, p) or sector(hx).get("nebula", false) or sector(hx).has("hole"):
			continue
		var owners := owners_in(k)
		var foes := false
		for o in owners:
			if o != p:
				foes = true
		if owners.has(p) and not foes:
			out.append(k)
			continue
		if foes:
			continue
		for nb in neighbors(hx):
			if (int(nb["owner"]) == p or not ships_in(nb["k"], p).is_empty()) and connected(nb, hx, p):
				out.append(k)
				break
	return out


func _influence(p: int, count: int) -> void:
	var before := int(ps[p]["colony_used"])
	ps[p]["colony_used"] = max(0, before - int(ps[p]["S"].get("inf_flip", 2)))
	if before > 0:
		log_msg("%s rigira %d navi coloniali." % [pname(p), before - int(ps[p]["colony_used"])])
	var touched := {}
	for i in count:
		var add := []
		if int(ps[p]["discs"]) > 0:
			for k in influence_targets(p):
				if not touched.has(k):
					add.append(k)
		var rem := []
		for hx in controls(p):
			if not touched.has(hx["k"]):
				rem.append(hx["k"])
		if add.is_empty() and rem.is_empty():
			break
		var r: Dictionary = await decide(p, {"type": "influence", "add": add, "remove": rem, "left": count - i})
		if r.has("add") and add.has(str(r["add"])):
			var hx: Dictionary = hexes[str(r["add"])]
			_place_disc(p, hx)
			touched[hx["k"]] = true
			log_msg("%s porta la sua influenza in %s." % [pname(p), sector(hx)["name"]])
			fx.emit("influence", {"p": p, "h": hx["k"]})
			# chi per primo mette il disco in un settore abbandonato con la scoperta la prende
			if not hx["disc"].is_empty() and hx["npc"].is_empty():
				var tile: Dictionary = hx["disc"]
				hx["disc"] = {}
				await _discovery(p, tile, hx["k"])
		elif r.has("remove") and rem.has(str(r["remove"])):
			var hx: Dictionary = hexes[str(r["remove"])]
			_remove_disc(hx)
			touched[hx["k"]] = true
			log_msg("%s ritira l'influenza da %s." % [pname(p), sector(hx)["name"]])
			fx.emit("influence", {"p": p, "h": hx["k"], "off": true})
		else:
			break
		changed.emit()


# ---------------------------------------------------------------- colonizzazione

func colony_opts(p: int, upkeep_step := false) -> Array:
	var out := []
	var st: Dictionary = ps[p]
	if int(st["colony_used"]) >= int(st["colony"]):
		return out
	var adv := {"m": has_tech(p, "advanced_mining"), "s": has_tech(p, "advanced_labs"), "$": has_tech(p, "advanced_economy")}
	var meta := has_tech(p, "metasynthesis")
	for hx in controls(p):
		if upkeep_step:
			var foes := false
			for o in owners_in(hx["k"]):
				if o != p:
					foes = true
			if foes:
				continue
		var pl: Array = sector(hx)["pl"]
		for i in pl.size():
			if hx["cubes"][i] != "":
				continue
			var code: String = pl[i]
			var isadv := code.ends_with("*")
			var base := code.replace("*", "")
			var ts := []
			for t in (["m", "s", "$"] if base == "g" else [base]):
				if int(st["track"][t]) <= 0:
					continue
				if isadv and not (meta or adv[t]):
					continue
				ts.append(t)
			if not ts.is_empty():
				out.append({"h": hx["k"], "i": i, "t": ts})
		if hx["orb"] and hx["orb_cube"] == "":
			var ts := []
			for t in ["s", "$"]:
				if int(st["track"][t]) > 0:
					ts.append(t)
			if not ts.is_empty():
				out.append({"h": hx["k"], "i": -1, "t": ts})
	return out


func _colony(p: int, upkeep_step: bool) -> void:
	while not abort:
		var opts := colony_opts(p, upkeep_step)
		if opts.is_empty():
			return
		var r: Dictionary = await decide(p, {"type": "colony", "opts": opts, "upkeep": upkeep_step})
		if r.get("stop", false):
			return
		var ok := false
		for o in opts:
			if o["h"] == r.get("h", "") and int(o["i"]) == int(r.get("i", -9)) and o["t"].has(r.get("t", "")):
				ok = true
		if not ok:
			return
		var hx: Dictionary = hexes[r["h"]]
		var t: String = r["t"]
		if int(r["i"]) < 0:
			hx["orb_cube"] = t
		else:
			hx["cubes"][int(r["i"])] = t
		ps[p]["track"][t] = int(ps[p]["track"][t]) - 1
		ps[p]["colony_used"] = int(ps[p]["colony_used"]) + 1
		log_msg("%s colonizza %s (%s)." % [pname(p), sector(hx)["name"], D.RES_NAME[t].to_lower()])
		fx.emit("colony", {"p": p, "h": hx["k"]})
		changed.emit()


# ---------------------------------------------------------------- diplomazia

func has_relation(p: int, q: int) -> bool:
	for e in ps[p]["rep"]:
		if e.get("k", "") == "A" and int(e.get("from", -1)) == q:
			return true
	return false


func rep_slots(p: int) -> Array:
	return ps[p]["S"]["rep"]


func amb_room(p: int) -> bool:
	var amb := 0
	for e in ps[p]["rep"]:
		if e["k"] == "A":
			amb += 1
	return amb < rep_slots(p).size()


func diplo_targets(p: int) -> Array:
	var out := []
	if n < 4 or traitor == p or int(ps[p]["amb_left"]) <= 0 or not amb_room(p):
		return out
	for q in n:
		if q == p or ps[q]["eliminated"] or traitor == q or has_relation(p, q) or int(ps[q]["amb_left"]) <= 0 or not amb_room(q):
			continue
		if _hostile_presence(p, q) or _hostile_presence(q, p):
			continue
		var link := false
		for a in controls(p):
			for b in neighbors(a):
				if int(b["owner"]) == q and connected(a, b, -1, true):
					link = true
					break
			if link:
				break
		if link:
			out.append(q)
	return out


## Navi di p in settori controllati da q o con navi di q.
func _hostile_presence(p: int, q: int) -> bool:
	for s in ships:
		if int(s["p"]) != p:
			continue
		if not hexes.has(s["h"]):
			continue
		var hx: Dictionary = hexes[s["h"]]
		if int(hx["owner"]) == q or not ships_in(s["h"], q).is_empty():
			return true
	return false


func _best_cube_track(p: int) -> String:
	var best := ""
	for t in ["$", "s", "m"]:
		if int(ps[p]["track"][t]) > 0 and (best == "" or int(ps[p]["track"][t]) > int(ps[p]["track"][best])):
			best = t
	return best


func _diplo(p: int, q: int) -> void:
	if not diplo_targets(p).has(q):
		return
	var r: Dictionary = await decide(q, {"type": "diplo", "from": p})
	if not r.get("ok", false):
		log_msg("%s rifiuta le relazioni diplomatiche con %s." % [pname(q), pname(p)])
		return
	for pair in [[p, q], [q, p]]:
		var giver: int = pair[0]
		var taker: int = pair[1]
		var t := _best_cube_track(giver)
		if t != "":
			ps[giver]["track"][t] = int(ps[giver]["track"][t]) - 1
		ps[giver]["amb_left"] = int(ps[giver]["amb_left"]) - 1
		_rep_place_amb(taker, {"k": "A", "from": giver, "t": t})
	log_msg("%s e %s stringono relazioni diplomatiche." % [pname(p), pname(q)])
	fx.emit("diplo", {"p": p, "q": q})


func _rep_place_amb(p: int, e: Dictionary) -> void:
	var rep: Array = ps[p]["rep"]
	var slots := rep_slots(p)
	if rep.size() >= slots.size():
		# si rimette nel sacchetto la reputazione più bassa
		var low := -1
		for i in rep.size():
			if rep[i]["k"] == "R" and (low < 0 or int(rep[i]["v"]) < int(rep[low]["v"])):
				low = i
		if low >= 0:
			rep_bag.append(int(rep[low]["v"]))
			rep.remove_at(low)
	rep.append(e)


func _aggression_check(p: int) -> void:
	for q in n:
		if q == p or not (has_relation(p, q) or has_relation(q, p)):
			continue
		var aggr := false
		for s in ships:
			if int(s["p"]) != p:
				continue
			if not hexes.has(s["h"]):
				continue
			var hx: Dictionary = hexes[s["h"]]
			if int(hx["owner"]) == q or not ships_in(s["h"], q).is_empty():
				aggr = true
				break
		if not aggr:
			continue
		for pair in [[p, q], [q, p]]:
			var holder: int = pair[0]
			var from: int = pair[1]
			var rep: Array = ps[holder]["rep"]
			for i in range(rep.size() - 1, -1, -1):
				if rep[i]["k"] == "A" and int(rep[i]["from"]) == from:
					var t: String = rep[i].get("t", "")
					if t != "":
						_return_cube(from, t)
					ps[from]["amb_left"] = int(ps[from]["amb_left"]) + 1
					rep.remove_at(i)
		traitor = p
		log_msg("%s rompe le relazioni diplomatiche con %s: è il Traditore!" % [pname(p), pname(q)])
		fx.emit("traitor", {"p": p, "q": q})


# ---------------------------------------------------------------- reputazione

## Offre le tessere pescate: si tiene la migliore se c'è posto (o se migliora la peggiore).
func _rep_offer(p: int, drawn: Array, log_it := true) -> void:
	drawn = drawn.filter(func(v): return int(v) > 0)
	if drawn.is_empty():
		return
	drawn.sort()
	var best: int = int(drawn.pop_back())
	for v in drawn:
		rep_bag.append(v)
	var rep: Array = ps[p]["rep"]
	var slots := rep_slots(p)
	var x_slots := 0
	for s in slots:
		if s == "X":
			x_slots += 1
	var reps := 0
	var amb := 0
	for e in rep:
		if e["k"] == "R":
			reps += 1
		else:
			amb += 1
	# posti liberi per la reputazione: caselle X non occupate da ambasciatori (gli ambasciatori vanno prima sulle A)
	var a_slots := slots.size() - x_slots
	var amb_in_x: int = max(0, amb - a_slots)
	if reps + amb_in_x < x_slots:
		rep.append({"k": "R", "v": best})
		if log_it:
			log_msg("%s prende una tessera reputazione." % pname(p))
		rep_bag = _shuffled(rep_bag)
		return
	var low := -1
	for i in rep.size():
		if rep[i]["k"] == "R" and (low < 0 or int(rep[i]["v"]) < int(rep[low]["v"])):
			low = i
	if low >= 0 and int(rep[low]["v"]) < best:
		rep_bag.append(int(rep[low]["v"]))
		rep[low] = {"k": "R", "v": best}
		if log_it:
			log_msg("%s migliora la sua reputazione." % pname(p))
	else:
		rep_bag.append(best)
	rep_bag = _shuffled(rep_bag)


# ================================================================ combattimento

func _sides_in(k: String) -> Array:
	## Giocatori presenti in ordine d'entrata, con chi controlla il settore per primo.
	var hx: Dictionary = hexes[k]
	var order: Array = []
	for p in hx["entry"]:
		if not ships_in(k, p).is_empty() and not order.has(p):
			order.append(p)
	for p in owners_in(k):
		if not order.has(p):
			order.append(p)
	var ob := orb_ship(k)
	if ob >= 0 and not order.has(ob):
		order.append(ob)
	var own: int = int(hx["owner"])
	if order.has(own):
		order.erase(own)
		order.push_front(own)
	return order


func _battle_needed(k: String) -> bool:
	var hx: Dictionary = hexes[k]
	var sides := _sides_in(k)
	if sides.size() >= 2:
		return true
	if sides.size() == 1 and npc_blocks(hx, int(sides[0])) and not hx["npc"].is_empty():
		return true
	return false


func _combat_phase() -> void:
	var keys := []
	for k in hexes:
		if _battle_needed(k):
			keys.append(k)
	keys.sort_custom(func(a, b): return int(hexes[a]["n"]) > int(hexes[b]["n"]))
	for k in keys:
		await _resolve_sector(k)
		if abort:
			return
	battle = {}
	await _attack_population()
	await _post_combat_influence()
	await _claim_discoveries()
	for s in ships:
		s["dmg"] = 0
		s["ret"] = ""
	for k in hexes:
		for npc in hexes[k]["npc"]:
			npc["dmg"] = 0
	for p in n:
		if ps[p]["eliminated"]:
			continue
		var any := false
		for s in ships:
			if int(s["p"]) == p:
				any = true
				break
		if not any and controls(p).is_empty():
			_eliminate(p)
	changed.emit()


func _resolve_sector(k: String) -> void:
	var hx: Dictionary = hexes[k]
	var participants := {}
	var kills := {}
	var retreat_all := {}
	var queue := _sides_in(k)
	for p in queue:
		participants[p] = true
		kills[p] = 0
	log_msg("Battaglia in %s." % sector(hx)["name"])
	while queue.size() >= 2 and not abort:
		var att: int = queue[queue.size() - 1]
		var dfn: int = queue[queue.size() - 2]
		await _battle(k, att, dfn, kills, retreat_all)
		queue = _sides_in(k)
		for p in queue:
			participants[p] = true
			if not kills.has(p):
				kills[p] = 0
	if queue.size() == 1 and not hx["npc"].is_empty() and npc_blocks(hx, int(queue[0])):
		await _battle(k, int(queue[0]), -1, kills, retreat_all)
	# reputazione
	var order := []
	if participants.has(int(hx["owner"])):
		order.append(int(hx["owner"]))
	for p in hx["entry"]:
		if participants.has(p) and not order.has(p):
			order.append(p)
	for p in participants:
		if not order.has(p):
			order.append(p)
	for p in order:
		if ps[p]["eliminated"]:
			continue
		var cnt: int = int(kills.get(p, 0)) + (0 if retreat_all.get(p, false) else 1)
		cnt = min(cnt, 5)
		var drawn := []
		for i in cnt:
			drawn.append(_draw_rep())
		_rep_offer(p, drawn)
		if ps[p]["S"].get("rep_money", false) and cnt > 1:
			ps[p]["res"]["$"] = int(ps[p]["res"]["$"]) + cnt - 1
			log_msg("%s incassa %d denaro dalla reputazione." % [pname(p), cnt - 1])
	_leave_check(k)
	battle = {}
	fx.emit("battle_end", {"h": k})
	changed.emit()
	await _pace(0.6)


## Unità in battaglia: {side, p (-1 neutrali), t, ref (nave o neutrale), st}
func _units(k: String, side: int, p: int) -> Array:
	var out := []
	if p >= 0:
		for s in ships_in(k, p):
			if s.get("ret_done", false):
				continue
			out.append({"side": side, "p": p, "t": s["t"], "ref": s, "st": ship_stats(p, s["t"])})
		if orb_ship(k) == p:
			out.append({"side": side, "p": p, "t": "orb", "ref": hexes[k]["orb_unit"], "st": ship_stats(p, "orb")})
	else:
		for npc in hexes[k]["npc"]:
			out.append({"side": side, "p": -1, "t": npc["k"], "ref": npc, "st": npc_stats(npc["k"])})
	return out


func _alive(u: Dictionary) -> bool:
	return int(u["ref"]["dmg"]) <= int(u["st"]["hull"]) and not u["ref"].get("ret_done", false)


func _battle(k: String, att: int, dfn: int, kills: Dictionary, retreat_all: Dictionary) -> void:
	# dfn = -1: neutrali (sempre in difesa)
	var units := _units(k, 0, dfn) + _units(k, 1, att)
	if units.is_empty():
		return
	battle = {"h": k, "att": att, "def": dfn, "units": units, "round": 0}
	fx.emit("battle_start", {"h": k, "att": att, "def": dfn})
	log_msg("%s attacca %s." % [pname(att), (pname(dfn) if dfn >= 0 else D.NPC_PLURAL[units[0]["t"]])])
	changed.emit()
	await _pace(0.8)
	# gruppi per tipo, in ordine d'iniziativa (a parità prima il difensore)
	var groups := []
	for u in units:
		var found := false
		for g in groups:
			if g["side"] == u["side"] and g["t"] == u["t"]:
				g["u"].append(u)
				found = true
		if not found:
			groups.append({"side": u["side"], "p": u["p"], "t": u["t"], "ini": int(u["st"]["ini"]), "u": [u], "ret_to": "", "ret_round": -1})
	groups.sort_custom(func(a, b):
		if a["ini"] != b["ini"]:
			return a["ini"] > b["ini"]
		return a["side"] < b["side"])
	# missili
	for g in groups:
		var dice := []
		for u in g["u"]:
			if not _alive(u):
				continue
			for d in u["st"]["mis"]:
				dice.append({"d": d, "comp": int(u["st"]["comp"]), "src": u})
		if not dice.is_empty():
			await _volley(k, g, dice, units, kills, true)
			if _side_gone(units, 0) or _side_gone(units, 1):
				break
	# stallo: nessuno può più fare danni
	var rnd := 0
	while not _side_gone(units, 0) and not _side_gone(units, 1) and not abort:
		rnd += 1
		battle["round"] = rnd
		var any_cannon := false
		for u in units:
			if _alive(u) and not u["st"]["can"].is_empty():
				any_cannon = true
		if not any_cannon:
			# l'attaccante deve ritirarsi o le sue navi sono distrutte
			var dests := retreat_dests(k, att)
			for u in units:
				if u["side"] == 1 and _alive(u):
					if not dests.is_empty():
						u["ref"]["h"] = dests[0]
						u["ref"]["ret_done"] = true
					else:
						u["ref"]["dmg"] = 99
			retreat_all[att] = true
			log_msg("Stallo: %s deve ritirarsi." % pname(att))
			break
		if rnd > 60:
			break
		for g in groups:
			var live := []
			for u in g["u"]:
				if _alive(u):
					live.append(u)
			if live.is_empty():
				continue
			if _side_gone(units, 0) or _side_gone(units, 1):
				break
			# completamento di una ritirata cominciata prima
			if g["ret_to"] != "":
				for u in live:
					u["ref"]["h"] = g["ret_to"]
					u["ref"]["ret_done"] = true
					_enter(int(g["p"]), g["ret_to"])
				log_msg("%s: %s si ritirano." % [pname(g["p"]), D.SHIP_PLURAL[g["t"]].to_lower()])
				fx.emit("retreat_done", {"h": k, "to": g["ret_to"]})
				changed.emit()
				continue
			# rigenerazione dello scudo mutaforma
			for u in live:
				if int(u["st"]["regen"]) > 0 and int(u["ref"]["dmg"]) > 0:
					u["ref"]["dmg"] = max(0, int(u["ref"]["dmg"]) - int(u["st"]["regen"]))
			if g["p"] >= 0 and not (g["t"] in ["sb", "orb"]):
				var dests := retreat_dests(k, int(g["p"]))
				if not dests.is_empty():
					var foe := 1 - int(g["side"])
					var r: Dictionary = await decide(int(g["p"]), {"type": "battle", "h": k, "s": g["t"], "dests": dests,
						"foe": (att if foe == 1 else dfn), "round": rnd})
					if r.has("retreat") and dests.has(str(r["retreat"])):
						g["ret_to"] = str(r["retreat"])
						g["ret_round"] = rnd
						for u in live:
							u["ref"]["ret"] = g["ret_to"]
						# chi si ritira con tutte le navi perde il gettone di partecipazione
						var others := false
						for u in units:
							if u["side"] == g["side"] and _alive(u) and u["ref"].get("ret", "") == "":
								others = true
						if not others:
							retreat_all[int(g["p"])] = true
						log_msg("%s: %s cominciano a ritirarsi." % [pname(g["p"]), D.SHIP_PLURAL[g["t"]].to_lower()])
						fx.emit("retreat", {"h": k, "p": g["p"], "t": g["t"]})
						continue
			var dice := []
			for u in live:
				for d in u["st"]["can"]:
					dice.append({"d": d, "comp": int(u["st"]["comp"]), "src": u})
			if not dice.is_empty():
				await _volley(k, g, dice, units, kills, false)
	# le navi in ritirata da un round precedente completano la ritirata
	for g in groups:
		if g["ret_to"] != "" and int(g["ret_round"]) < rnd:
			for u in g["u"]:
				if _alive(u):
					u["ref"]["h"] = g["ret_to"]
					u["ref"]["ret_done"] = true
					_enter(int(g["p"]), g["ret_to"])
	# rimozione delle navi distrutte (un orbitale degli Esuli resta: il cubetto va al cimitero)
	for u in units:
		if u["t"] == "orb" and u["p"] >= 0:
			if int(u["ref"]["dmg"]) > int(u["st"]["hull"]):
				var hxo: Dictionary = hexes[k]
				if hxo["orb_cube"] != "":
					_return_cube(int(u["p"]), hxo["orb_cube"], true)
					hxo["orb_cube"] = ""
			u["ref"]["dmg"] = 0
			continue
		if int(u["ref"]["dmg"]) > int(u["st"]["hull"]):
			if u["p"] >= 0:
				ships.erase(u["ref"])
			else:
				hexes[k]["npc"].erase(u["ref"])
	for s in ships:
		s.erase("ret_done")
		s["ret"] = ""
	_leave_check(k)
	battle = {}
	changed.emit()
	await _pace(0.5)


func _side_gone(units: Array, side: int) -> bool:
	for u in units:
		if u["side"] == side and _alive(u):
			return false
	return true


func _roll() -> int:
	return rng.randi_range(1, 6)


## Una raffica: tira i dadi, li assegna e applica i danni.
func _volley(k: String, g: Dictionary, dice: Array, units: Array, kills: Dictionary, missile: bool) -> void:
	var foes := []
	for u in units:
		if u["side"] != g["side"] and _alive(u):
			foes.append(u)
	if foes.is_empty():
		return
	var rolls := []
	var self_dmg := 0
	for d in dice:
		var v := _roll()
		var e := {"d": d["d"], "v": v, "comp": d["comp"], "dmg": 0}
		if d["d"] == "x":
			var face: Array = D.RIFT_FACES[v - 1]
			e["dmg"] = int(face[0])
			self_dmg += int(face[1])
		else:
			e["dmg"] = int(D.DIE_DMG[d["d"]])
		rolls.append(e)
	# Illuminati di Lyra: una nave coloniale inutilizzata per ritirare un dado mancato
	var gp: int = int(g["p"])
	if gp >= 0 and ps[gp]["S"].get("reroll", false):
		var min_sh := 99
		for u in foes:
			min_sh = min(min_sh, int(u["st"]["sh"]))
		for e in rolls:
			if int(ps[gp]["colony_used"]) >= int(ps[gp]["colony"]):
				break
			if e["d"] == "x":
				continue
			var v: int = int(e["v"])
			if v == 6 or (v > 1 and v + int(e["comp"]) - min_sh >= 6):
				continue
			ps[gp]["colony_used"] = int(ps[gp]["colony_used"]) + 1
			e["v"] = _roll()
			log_msg("%s gira una nave coloniale e ritira un dado." % pname(gp))
	_assign(rolls, foes)
	var shown := []
	for e in rolls:
		shown.append({"d": e["d"], "v": e["v"], "hit": e.get("target", null) != null})
	last_dice = shown
	fx.emit("volley", {"h": k, "p": g["p"], "t": g["t"], "dice": shown, "missile": missile})
	await _pace(0.9)
	for e in rolls:
		if e.get("target", null) == null:
			continue
		var u: Dictionary = e["target"]
		u["ref"]["dmg"] = int(u["ref"]["dmg"]) + int(e["dmg"])
	# danni dello squarcio sulle proprie navi armate a squarcio
	if self_dmg > 0:
		var mine := []
		for u in units:
			if u["side"] == g["side"] and _alive(u) and (u["st"]["can"].has("x")):
				mine.append(u)
		mine.sort_custom(func(a, b): return D.SHIP_SIZE[a["t"]] > D.SHIP_SIZE[b["t"]])
		for u in mine:
			if self_dmg <= 0:
				break
			var need: int = int(u["st"]["hull"]) + 1 - int(u["ref"]["dmg"])
			var take: int = min(need, self_dmg)
			u["ref"]["dmg"] = int(u["ref"]["dmg"]) + take
			self_dmg -= take
	var destroyed := []
	for u in foes:
		if int(u["ref"]["dmg"]) > int(u["st"]["hull"]):
			destroyed.append(u)
			if g["p"] >= 0:
				kills[g["p"]] = int(kills.get(g["p"], 0)) + int(D.SHIP_REP[u["t"]])
				ps[g["p"]]["kills"] = int(ps[g["p"]]["kills"]) + 1
			log_msg("%s distrugge %s di %s." % [pname(g["p"]) if g["p"] >= 0 else D.NPC_PLURAL[g["t"]],
				(D.SHIP_NAME[u["t"]] if u["p"] >= 0 else D.NPC_NAME[u["t"]]).to_lower(), pname(u["p"]) if u["p"] >= 0 else "neutrali"])
			fx.emit("destroy", {"h": k, "p": u["p"], "t": u["t"], "id": int(u["ref"].get("id", -1))})
	changed.emit()
	await _pace(0.4)


## Assegna i dadi ai bersagli: prima si distruggono le navi più grandi possibili, poi si danneggia la più grande.
func _assign(rolls: Array, foes: Array) -> void:
	for e in rolls:
		e["target"] = null
	var hits_on := func(e: Dictionary, u: Dictionary) -> bool:
		if int(e["dmg"]) <= 0:
			return false
		if e["d"] == "x":
			return true
		var v: int = int(e["v"])
		if v == 6:
			return true
		if v == 1:
			return false
		return v + int(e["comp"]) - int(u["st"]["sh"]) >= 6
	var order := foes.duplicate()
	order.sort_custom(func(a, b): return D.SHIP_SIZE[a["t"]] > D.SHIP_SIZE[b["t"]])
	var pending := []
	for u in order:
		pending.append(int(u["ref"]["dmg"]))
	for ui in order.size():
		var u: Dictionary = order[ui]
		var need: int = int(u["st"]["hull"]) + 1 - int(pending[ui])
		if need <= 0:
			continue
		var cand := []
		for e in rolls:
			if e["target"] == null and hits_on.call(e, u):
				cand.append(e)
		cand.sort_custom(func(a, b): return int(a["dmg"]) > int(b["dmg"]))
		var tot := 0
		for e in cand:
			tot += int(e["dmg"])
		if tot < need:
			continue
		# il dado più piccolo che basta da solo, altrimenti i più grandi in ordine
		var single = null
		for e in cand:
			if int(e["dmg"]) >= need and (single == null or int(e["dmg"]) < int(single["dmg"])):
				single = e
		if single != null:
			single["target"] = u
			pending[ui] = int(pending[ui]) + int(single["dmg"])
			continue
		var acc := 0
		for e in cand:
			if acc >= need:
				break
			e["target"] = u
			acc += int(e["dmg"])
		pending[ui] = int(pending[ui]) + acc
	# i dadi rimasti danneggiano la nave più grande ancora in piedi che possono colpire
	for e in rolls:
		if e["target"] != null:
			continue
		for ui in order.size():
			var u: Dictionary = order[ui]
			if int(pending[ui]) <= int(u["st"]["hull"]) and hits_on.call(e, u):
				e["target"] = u
				pending[ui] = int(pending[ui]) + int(e["dmg"])
				break
		if e["target"] == null:
			for u in order:
				if hits_on.call(e, u):
					e["target"] = u
					break


func retreat_dests(k: String, p: int) -> Array:
	var out := []
	var hx: Dictionary = hexes[k]
	for nb in neighbors(hx):
		if int(nb["owner"]) != p or not connected(hx, nb, p):
			continue
		var foe := false
		for o in owners_in(nb["k"]):
			if o != p:
				foe = true
		if foe or not nb["npc"].is_empty():
			continue
		out.append(nb["k"])
	return out


func _attack_population() -> void:
	for k in hexes:
		var hx: Dictionary = hexes[k]
		var o: int = int(hx["owner"])
		if o < 0:
			continue
		var cubes := 0
		for c in hx["cubes"]:
			if c != "":
				cubes += 1
		if hx["orb_cube"] != "":
			cubes += 1
		if cubes == 0:
			continue
		for p in owners_in(k):
			if p == o or cubes == 0:
				continue
			if has_relation(p, o):
				continue
			var kill := 0
			if ps[o]["S"].get("fragile", false) or (has_tech(p, "neutron_bombs") and not has_tech(o, "neutron_absorber")):
				kill = cubes
			else:
				for s in ships_in(k, p):
					var st := ship_stats(p, s["t"])
					for d in st["can"]:
						var v := _roll()
						if d == "x":
							kill += int(D.RIFT_FACES[v - 1][0])
						elif v == 6 or (v > 1 and v + int(st["comp"]) >= 6):
							kill += int(D.DIE_DMG[d])
			kill = min(kill, cubes)
			if kill <= 0:
				continue
			for i in hx["cubes"].size():
				if kill <= 0:
					break
				var c: String = hx["cubes"][i]
				if c != "":
					hx["cubes"][i] = ""
					_return_cube(o, c, true)
					kill -= 1
					cubes -= 1
			if kill > 0 and hx["orb_cube"] != "":
				_return_cube(o, hx["orb_cube"], true)
				hx["orb_cube"] = ""
				cubes -= 1
			log_msg("%s attacca la popolazione di %s in %s." % [pname(p), pname(o), sector(hx)["name"]])
			fx.emit("population", {"h": k, "p": p})
			changed.emit()
			await _pace(0.4)


func _post_combat_influence() -> void:
	var keys := hexes.keys()
	keys.sort_custom(func(a, b): return int(hexes[a]["n"]) > int(hexes[b]["n"]))
	for k in keys:
		var hx: Dictionary = hexes[k]
		var o: int = int(hx["owner"])
		if o >= 0:
			var invaders := []
			for p in owners_in(k):
				if p != o and not has_relation(p, o):
					invaders.append(p)
			var cubes := 0
			for c in hx["cubes"]:
				if c != "":
					cubes += 1
			if hx["orb_cube"] != "":
				cubes += 1
			if not invaders.is_empty() and cubes == 0:
				_remove_disc(hx)
				log_msg("%s perde il controllo di %s." % [pname(o), sector(hx)["name"]])
				fx.emit("influence", {"p": o, "h": k, "off": true})
		if int(hx["owner"]) < 0 and hx["npc"].is_empty():
			var here := owners_in(k)
			if here.size() == 1:
				var p: int = here[0]
				if int(ps[p]["discs"]) > 0 and not ps[p]["eliminated"]:
					var r: Dictionary = await decide(p, {"type": "claim", "h": k, "why": "combat"})
					if r.get("yes", false):
						_place_disc(p, hx)
						log_msg("%s prende il controllo di %s." % [pname(p), sector(hx)["name"]])
						fx.emit("influence", {"p": p, "h": k})
	changed.emit()


func _claim_discoveries() -> void:
	var keys := hexes.keys()
	keys.sort_custom(func(a, b): return int(hexes[a]["n"]) > int(hexes[b]["n"]))
	for k in keys:
		var hx: Dictionary = hexes[k]
		if sector(hx).get("nebula", false) and hx["npc"].is_empty():
			var here2 := owners_in(k)
			if here2.size() == 1:
				var tiles := []
				if not hx["disc"].is_empty():
					tiles.append(hx["disc"])
				for t3 in hx["disc_more"]:
					if not t3.is_empty():
						tiles.append(t3)
				hx["disc"] = {}
				hx["disc_more"] = []
				for t3 in tiles:
					await _discovery(int(here2[0]), t3, k)
			continue
		if hx["disc"].is_empty() or not hx["npc"].is_empty():
			continue
		var here := owners_in(k)
		var p := -1
		if here.size() == 1:
			p = here[0]
		elif here.is_empty() and int(hx["owner"]) >= 0:
			p = int(hx["owner"])
		if p < 0:
			continue
		var tile: Dictionary = hx["disc"]
		hx["disc"] = {}
		await _discovery(p, tile, k)


func _eliminate(p: int) -> void:
	ps[p]["eliminated"] = true
	ps[p]["passed"] = true
	for hx in controls(p):
		_remove_disc(hx)
	for s in ships.duplicate():
		if int(s["p"]) == p:
			ships.erase(s)
	log_msg("La civiltà di %s è crollata: esce dalla partita." % pname(p))
	fx.emit("eliminated", {"p": p})


# ================================================================ mantenimento e pulizia

func _upkeep_phase() -> void:
	for p in n:
		if ps[p]["eliminated"]:
			continue
		if not colony_opts(p, true).is_empty():
			await _colony(p, true)
	for p in n:
		if ps[p]["eliminated"]:
			continue
		var res: Dictionary = ps[p]["res"]
		var net := prod(p, "$") - upkeep(p)
		var guard := 0
		while int(res["$"]) + net < 0 and guard < 30:
			guard += 1
			# si scambiano le altre risorse
			var from := ""
			for o in ["s", "m"]:
				if int(res[o]) >= int(trade_pair(p, o)[0]) and (from == "" or int(res[o]) > int(res[from])):
					from = o
			if from != "":
				var tp := trade_pair(p, from)
				res[from] = int(res[from]) - int(tp[0])
				res["$"] = int(res["$"]) + int(tp[1])
				continue
			# si abbandonano i settori meno preziosi
			var worst = null
			var wv := 999
			for hx in controls(p):
				var money := 0
				for c in hx["cubes"]:
					if c == "$":
						money += 1
				if hx["orb_cube"] == "$":
					money += 1
				var v: int = money * 10 + int(sector(hx)["vp"]) + (50 if sector(hx).get("home", false) else 0)
				if v < wv:
					wv = v
					worst = hx
			if worst == null:
				break
			_remove_disc(worst)
			log_msg("%s non può pagare: abbandona %s." % [pname(p), sector(worst)["name"]])
			net = prod(p, "$") - upkeep(p)
		if int(res["$"]) + net < 0:
			res["$"] = 0
			_eliminate(p)
			continue
		res["$"] = int(res["$"]) + net
		res["m"] = int(res["m"]) + prod(p, "m")
		res["s"] = int(res["s"]) + prod(p, "s")
	log_msg("Mantenimento: le civiltà pagano l'influenza e producono.")
	changed.emit()


func _cleanup() -> void:
	await _supernovae()
	_draw_techs(D.TECH_ROUND[clampi(n, 2, 6)] if n >= 2 else 4)
	for p in n:
		var st: Dictionary = ps[p]
		var used := 0
		for a in st["acts_used"]:
			used += int(st["acts_used"][a])
		used += int(st["reacts"])
		st["discs"] = int(st["discs"]) + used
		st["acts_used"] = {}
		st["reacts"] = 0
		for t in ["m", "s", "$"]:
			for i in int(st["grave"][t]):
				_return_cube(p, t)
			st["grave"][t] = 0
		st["colony_used"] = 0
		st["passed"] = false
	if first_pass >= 0:
		start_player = first_pass
	if turn_var:
		var order: Array = pass_order.duplicate()
		for p in turn_order:
			if not order.has(p):
				order.append(p)
		turn_order = order
	# navi perse nel buco nero (non rientrate nel loro round)
	for s2 in ships.duplicate():
		if s2["h"] == "hole" and int(s2.get("hole_round", 0)) <= round_n:
			ships.erase(s2)
			log_msg("Una nave di %s si perde nello spaziotempo." % pname(int(s2["p"])))


# ================================================================ punteggio

func score(p: int) -> Dictionary:
	var st: Dictionary = ps[p]
	var s := {"rep": 0, "amb": 0, "settori": 0, "monoliti": 0, "scoperte": 0, "traditore": 0, "tecnologie": 0, "specie": 0}
	for e in st["rep"]:
		if e["k"] == "R":
			s["rep"] += int(e["v"])
		else:
			s["amb"] += 1
	for hx in controls(p):
		s["settori"] += int(sector(hx)["vp"])
		if int(hx["warp_tile"]) >= 0:
			s["settori"] += 1
		if hx["anc_portal"]:
			s["settori"] += 2
		if hx["mono"]:
			s["monoliti"] += 3
	s["scoperte"] = int(st["disc_vp"]) * 2
	if traitor == p and not st["S"].get("traitor_free", false):
		s["traditore"] = -2
	for c in D.TECH_CATS:
		s["tecnologie"] += D.TECH_VP[min(7, st["techs"][c].size())]
	if st["S"].get("vp_sector", 0) > 0:
		s["specie"] += controls(p).size() * int(st["S"]["vp_sector"])
	if st["S"].get("ancient_friend", false):
		for k in hexes:
			for npc in hexes[k]["npc"]:
				if npc["k"] == "anc":
					s["specie"] += 1
	if st["S"].get("orb_ships", false):
		for k in hexes:
			var hx: Dictionary = hexes[k]
			if hx["orb"] and hx["orb_cube"] != "" and int(hx["owner"]) == p:
				s["specie"] += 1
	if st["S"].get("vp_part", false):
		s["specie"] += int(st["anc_used"])
	if st["S"].get("shrines", false):
		for hx in controls(p):
			s["specie"] += hx["shrines"].size()
	# specie minori (1 PV come ambasciatori, già contati, più i loro premi)
	var reps := 0
	var ambs := 0
	for e in st["rep"]:
		if e["k"] == "R":
			reps += 1
		else:
			ambs += 1
	for m in st["minors"]:
		match m:
			"diplo":
				s["amb"] += ambs - 1
			"wealth":
				s["amb"] += 2
			"rep":
				s["amb"] += reps - 1
	var tot := 0
	for v in s.values():
		tot += int(v)
	s["totale"] = tot
	return s


func scores_now() -> Array:
	var out := []
	for p in n:
		out.append(score(p)["totale"])
	return out


func _finish() -> void:
	phase = "over"
	over = true
	var sc := []
	var best := -1
	for p in n:
		var s := score(p)
		sc.append(s)
	for p in n:
		if ps[p]["eliminated"] and n > 1:
			continue
		if best < 0:
			best = p
			continue
		var a: int = sc[p]["totale"]
		var b: int = sc[best]["totale"]
		if a > b or (a == b and _res_total(p) > _res_total(best)):
			best = p
	result = {"scores": sc, "winner": best}
	log_msg("Fine della partita: vince %s con %d punti!" % [pname(best), int(sc[best]["totale"])])
	changed.emit()
	game_ended.emit(result)


func _res_total(p: int) -> int:
	var t := 0
	for r in D.RES:
		t += int(ps[p]["res"][r])
	return t


## Impronta dello stato (per le prove: due dispositivi online o una partita ricaricata devono coincidere).
func fingerprint() -> String:
	var parts := [round_n, phase, start_player]
	for p in n:
		var st: Dictionary = ps[p]
		parts.append([st["res"], st["track"], st["discs"], st["techs"], st["bp"], st["rep"].size(), st["disc_vp"]])
	var ks := hexes.keys()
	ks.sort()
	for k in ks:
		var hx: Dictionary = hexes[k]
		parts.append([k, hx["n"], hx["rot"], hx["owner"], hx["cubes"], hx["npc"].size()])
	for s in ships:
		parts.append([s["id"], s["p"], s["t"], s["h"]])
	return str(var_to_str(parts).hash())



# ================================================================ espansioni

## Orbitale degli Esuli che combatte come nave: proprietario, oppure -1.
func orb_ship(k: String) -> int:
	var hx: Dictionary = hexes.get(k, {})
	if hx.is_empty() or not hx["orb"] or hx["orb_cube"] == "":
		return -1
	var o: int = int(hx["owner"])
	if o >= 0 and ps[o]["S"].get("orb_ships", false):
		return o
	return -1


# ---------------------------------------------------------------- pulsar

func pulsar_opts(p: int) -> Array:
	var out := []
	if not events or ps[p]["passed"]:
		return out
	for hx in controls(p):
		if sector(hx).get("pulsar", false) and not pulsar_used.has(hx["k"]):
			out.append(hx["k"])
	return out


## Pulsar: il disco si sposta su un'altra azione del settore e se ne fa un'attivazione (al posto dell'azione).
func _pulsar(p: int, k: String, act: String) -> void:
	var hx: Dictionary = hexes[k]
	hx["pulsar"] = act
	pulsar_used[k] = true
	log_msg("%s attiva il pulsar di %s: %s." % [pname(p), sector(hx)["name"], D.ACTION_NAME[act]])
	fx.emit("action", {"p": p, "a": act, "react": false})
	match act:
		"upg":
			await _upgrade(p, 1)
		"bui":
			await _build(p, 1)
		"mov":
			await _move(p, 1)


# ---------------------------------------------------------------- buchi neri

func _enter_hole(p: int, s: Dictionary, k: String) -> void:
	var hx: Dictionary = hexes[k]
	if not hx["disc"].is_empty():
		var tile: Dictionary = hx["disc"]
		hx["disc"] = {}
		await _discovery(p, tile, home_of(p))
	var v := _roll()
	s["hole_from"] = k
	if v == 1 or v == 6:
		s["dmg"] = int(s["dmg"]) + 1
		s["h"] = "hole"
		s["hole_round"] = round_n
		log_msg("%s: la nave attraversa il buco nero e torna subito, danneggiata." % pname(p))
		await _hole_return(p, s, true)
	else:
		s["h"] = "hole"
		s["hole_round"] = round_n + (1 if v <= 3 else 2)
		log_msg("%s: la nave sparisce nel buco nero e tornerà nel round %d." % [pname(p), int(s["hole_round"])])
	_leave_check(k)
	changed.emit()


func hole_dests(s: Dictionary) -> Array:
	var kind: String = D.SECTORS[int(hexes[s["hole_from"]]["n"])].get("hole", "inner")
	var out := []
	for k in hexes:
		var hx: Dictionary = hexes[k]
		if sector(hx).has("hole"):
			continue
		if kind == "inner":
			if D.ring_of(hx["pos"]) == 1:
				out.append(k)
		else:
			for d in 6:
				if wh(hx, d) and not hexes.has(D.key(hx["pos"] + D.DIRS[d])):
					out.append(k)
					break
	return out


func _hole_return(p: int, s: Dictionary, forced: bool) -> void:
	var dests := hole_dests(s)
	if dests.is_empty():
		ships.erase(s)
		return
	var r: Dictionary = await decide(p, {"type": "hole", "opts": dests, "forced": forced, "t": s["t"]})
	var to: String = str(r.get("h", ""))
	if not dests.has(to):
		if forced:
			to = dests[0]
		else:
			return
	s["h"] = to
	s.erase("hole_round")
	_enter(p, to)
	log_msg("%s: %s riemerge in %s." % [pname(p), D.SHIP_NAME[s["t"]], sector(hexes[to])["name"]])
	fx.emit("place", {"p": p, "h": to})
	changed.emit()


## All'inizio del turno: navi che possono uscire dal buco nero in questo round.
func _hole_returns(p: int) -> void:
	for s in ships.duplicate():
		if int(s["p"]) == p and s["h"] == "hole" and int(s.get("hole_round", 0)) == round_n:
			await _hole_return(p, s, false)


# ---------------------------------------------------------------- supernove

func _supernovae() -> void:
	for k in hexes.keys():
		var hx: Dictionary = hexes[k]
		if hx.get("exploded", false) or not D.SECTORS[int(hx["n"])].get("supernova", false):
			continue
		var tot := 0
		for i in 2:
			var v := _roll()
			if v >= 2 and v <= 5:
				tot += v
		var o: int = int(hx["owner"])
		if o >= 0:
			var best := 0
			for c in D.TECH_CATS:
				best = max(best, ps[o]["techs"][c].size())
			tot += best
		if tot >= round_n:
			log_msg("La supernova di %s resta stabile (%d)." % [sector(hx)["name"], tot])
			continue
		if o >= 0:
			_remove_disc(hx)
		for s in ships.duplicate():
			if s["h"] == k:
				ships.erase(s)
		hx["npc"] = []
		hx["orb"] = false
		hx["mono"] = false
		hx["disc"] = {}
		hx["exploded"] = true
		hx["cubes"] = []
		log_msg("La supernova di %s esplode!" % D.SECTORS[int(hx["n"])]["name"])
		fx.emit("supernova", {"h": k})
		changed.emit()
		await _pace(0.6)


# ---------------------------------------------------------------- specie minori

func minor_opts(p: int) -> Array:
	var out := []
	if not minors_on or not amb_room(p):
		return out
	for m in minors:
		if int(ps[p]["res"]["$"]) >= int(D.MINORS[m]["cost"]):
			out.append(m)
	return out


func _take_minor(p: int, m: String) -> void:
	if not minor_opts(p).has(m):
		return
	ps[p]["res"]["$"] = int(ps[p]["res"]["$"]) - int(D.MINORS[m]["cost"])
	minors.erase(m)
	ps[p]["minors"].append(m)
	var e := {"k": "A", "from": -1, "minor": m}
	if m == "prod":
		var t := _best_cube_track(p)
		if t != "":
			ps[p]["track"][t] = int(ps[p]["track"][t]) - 1
			e["t"] = t
	ps[p]["rep"].append(e)
	log_msg("%s stringe relazioni con la specie minore %s." % [pname(p), D.MINORS[m]["name"]])
	fx.emit("minor", {"p": p, "m": m})


# ---------------------------------------------------------------- santuari di Lyra

func shrine_opts(p: int) -> Array:
	var out := []
	var placed: Array = ps[p]["shrines"]
	for i in D.SHRINES.size():
		if placed.has(i):
			continue
		var r: String = D.SHRINES[i][0]
		var cost: int = int(D.SHRINES[i][1])
		if not can_pay(p, r, cost):
			continue
		for hx in controls(p):
			var pl: Array = sector(hx)["pl"]
			for j in pl.size():
				var base: String = str(pl[j]).replace("*", "")
				if (base == r or base == "g") and not hx["shrines"].has(j):
					out.append({"i": i, "h": hx["k"], "pl": j})
	return out


func _shrine(p: int) -> void:
	var opts := shrine_opts(p)
	if opts.is_empty():
		return
	var r: Dictionary = await decide(p, {"type": "shrine", "opts": opts})
	var ok := false
	for o in opts:
		if int(o["i"]) == int(r.get("i", -1)) and o["h"] == r.get("h", "") and int(o["pl"]) == int(r.get("pl", -1)):
			ok = true
	if not ok:
		return
	var i := int(r["i"])
	pay(p, D.SHRINES[i][0], int(D.SHRINES[i][1]))
	ps[p]["shrines"].append(i)
	hexes[r["h"]]["shrines"].append(int(r["pl"]))
	log_msg("%s costruisce un santuario in %s." % [pname(p), sector(hexes[r["h"]])["name"]])
	fx.emit("shrine", {"p": p, "h": r["h"]})
	# fila completata
	var row := int(i / 3)
	var full := true
	for j in 3:
		if not ps[p]["shrines"].has(row * 3 + j):
			full = false
	if full:
		log_msg("%s completa una fila di santuari: %s." % [pname(p), D.SHRINE_ROW[row]])
		match row:
			0:
				ps[p]["wg_ability"] = true
			1:
				await _discovery(p, _draw_disc(), home_of(p))
			2:
				ps[p]["discs"] = int(ps[p]["discs"]) + 1
				ps[p]["disc_total"] = int(ps[p]["disc_total"]) + 1
	changed.emit()
