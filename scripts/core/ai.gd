class_name ECAI
extends RefCounted
## Intelligenza artificiale per i posti vuoti. Euristica: valuta settori, tecnologie e progetti delle navi,
## tiene d'occhio il denaro per il mantenimento e attacca solo quando una simulazione rapida della battaglia
## dà buone probabilità di vittoria. Ha un proprio generatore casuale (non tocca quello del motore).
## Livelli: 0 facile, 1 normale, 2 difficile.

const D = preload("res://scripts/data/ec_data.gd")

var level := 1
var rng := RandomNumberGenerator.new()
var plan := {}                    # obiettivo d'attacco: {h, ships: [id]}


func _init(lv := 1, seed_v := 0) -> void:
	level = lv
	rng.seed = seed_v


func decide(e, p: int, req: Dictionary):
	match str(req.get("type", "")):
		"turn":
			return _turn(e, p, req)
		"explore":
			return _explore(e, p, req)
		"place":
			return _place(e, p, req)
		"claim":
			return {"yes": _claim(e, p, req["h"])}
		"discovery":
			return _discovery(e, p, req)
		"part":
			return _part(e, p, req)
		"research":
			return _research(e, p, req)
		"upgrade":
			return _upgrade(e, p, req)
		"build":
			return _build(e, p, req)
		"move":
			return _move(e, p, req)
		"influence":
			return _influence(e, p, req)
		"colony":
			return _colony(e, p, req)
		"diplo":
			return {"ok": e.traitor != int(req["from"])}
		"battle":
			return _battle(e, p, req)
		"artifact":
			return {"r": "s" if e.round_n <= 4 else "m"}
		"warp":
			return {"h": req["opts"][0]}
	return {"stop": true}


# ================================================================ denaro

## Denaro che resterebbe dopo il mantenimento con un disco in più (contando gli scambi possibili).
func _margin(e, p: int, extra_discs := 1) -> float:
	var st: Dictionary = e.ps[p]
	var dsc: int = int(st["discs"]) - extra_discs
	var up := 0
	if dsc < D.INF_SPACES:
		up = D.INF_VALUES[clampi(12 - dsc, 0, 12)]
	var rate: int = e.trade_rate(p)
	var other: float = float(int(st["res"]["m"]) + int(st["res"]["s"])) / rate
	return float(int(st["res"]["$"]) + e.prod(p, "$") - up) + other * 0.35


# ================================================================ turno

func _turn(e, p: int, req: Dictionary) -> Dictionary:
	var opts: Array = req["opts"]
	if req.get("colony", false):
		return {"a": "colony"}
	var dip: Array = req.get("diplo", [])
	if not dip.is_empty() and level >= 1:
		return {"a": "diplo", "t": dip[0]}
	var margin := _margin(e, p)
	var best := "pass"
	var bv := 0.8 + (0.0 if level >= 2 else 0.4)
	if req.get("passed", false):
		# reazioni: solo per difendersi o per non lasciare risorse inutilizzate
		if opts.has("r_mov") and margin > 2 and _defense_target(e, p) != {}:
			return {"a": "r_mov"}
		if opts.has("r_bui") and margin > 3 and int(e.ps[p]["res"]["m"]) >= 8 and _threatened(e, p):
			return {"a": "r_bui"}
		return {"a": "pass"}
	for a in opts:
		var v := 0.0
		match a:
			"exp":
				v = _value_explore(e, p)
			"res":
				v = _value_research(e, p)
			"upg":
				v = _value_upgrade(e, p)
			"bui":
				v = _value_build(e, p)
			"mov":
				v = _value_move(e, p)
			"inf":
				v = _value_influence(e, p)
		v += rng.randf() * (0.6 if level == 0 else 0.25)
		if v > bv:
			bv = v
			best = a
	if best != "pass" and margin < 0:
		# un disco in più non si potrebbe pagare: solo se l'azione vale molto
		if bv < 8.0 or margin < -2:
			best = "pass"
	return {"a": best}


# ================================================================ valori dei settori

func _sector_value(e, p: int, num: int) -> float:
	var S: Dictionary = D.SECTORS[num]
	var v := float(S["vp"]) * 0.8
	for code in S["pl"]:
		var adv: bool = code.ends_with("*")
		var t: String = code.replace("*", "")
		var w := 1.0
		if t == "$":
			w = 1.3
		elif t == "s":
			w = 1.1
		if adv:
			var techs := {"m": "advanced_mining", "s": "advanced_labs", "$": "advanced_economy", "g": ""}
			if t == "g" or not e.has_tech(p, techs[t]):
				w *= 0.35
		v += w * 1.4
	if S.get("disc", false):
		v += 1.2
	if S.get("art", false):
		v += 0.5
	if S.get("warp", false):
		v += 0.3
	var anc: int = int(S.get("anc", 0))
	if anc > 0 and not e.ps[p]["S"].get("ancient_friend", false):
		v -= anc * (1.5 if e.round_n <= 3 else 0.8)
	return v


func _value_explore(e, p: int) -> float:
	if e.explore_zones(p).is_empty():
		return 0.0
	if int(e.ps[p]["discs"]) < 2:
		return 0.5
	if _margin(e, p, 2) < 0:
		return 1.0
	var r: int = e.round_n
	var base := 7.0 - r * 0.8
	var own: int = e.controls(p).size()
	if own < 4:
		base += 1.5
	return max(base, 0.5)


# ================================================================ esplorazione

func _explore(e, p: int, req: Dictionary) -> Dictionary:
	var zones: Array = req["zones"]
	if zones.is_empty():
		return {"stop": true}
	var best := ""
	var bv := -99.0
	for zk in zones:
		var z := D.unkey(zk)
		var ring := D.ring_of(z)
		var v := 0.0
		v += {1: 2.6, 2: 2.0, 3: 1.6}[ring]
		# vicino ai propri settori
		for d in 6:
			var nk := D.key(z + D.DIRS[d])
			if e.hexes.has(nk) and int(e.hexes[nk]["owner"]) == p:
				v += 0.8
			elif e.hexes.has(nk) and int(e.hexes[nk]["owner"]) >= 0:
				v -= 0.4
		v += rng.randf() * 0.8
		if v > bv:
			bv = v
			best = zk
	return {"z": best}


func _place(e, p: int, req: Dictionary) -> Dictionary:
	var best := -1
	var brot := -1
	var bv := -99.0
	for t in req["tiles"]:
		var rots: Array = req["rots"][str(t)]
		if rots.is_empty():
			continue
		var v := _sector_value(e, p, int(t))
		var rr := _best_rot(e, p, int(t), req["zone"], rots)
		if v > bv:
			bv = v
			best = int(t)
			brot = rr
	if best < 0:
		return {"discard": true}
	# un settore pessimo si scarta (ma all'inizio conviene allargarsi comunque)
	if bv < 0.5 and e.round_n > 2 and rng.randf() < 0.6:
		return {"discard": true}
	return {"tile": best, "rot": brot}


func _best_rot(e, p: int, num: int, zk: String, rots: Array) -> int:
	var z := D.unkey(zk)
	var w: Array = D.SECTORS[num]["wh"]
	var best: int = rots[0]
	var bv := -99.0
	for rot in rots:
		var v := 0.0
		for d in 6:
			var mine := int(w[(d - rot + 6) % 6]) == 1
			if not mine:
				continue
			var nk := D.key(z + D.DIRS[d])
			if e.hexes.has(nk):
				var hx: Dictionary = e.hexes[nk]
				if e.wh(hx, (d + 3) % 6):
					v += 1.5 if int(hx["owner"]) == p else 0.4
			else:
				v += 0.6 if D.dist(z + D.DIRS[d]) <= D.MAX_DIST else 0.0
		v += rng.randf() * 0.1
		if v > bv:
			bv = v
			best = rot
	return best


func _claim(e, p: int, hk: String) -> bool:
	var hx: Dictionary = e.hexes[hk]
	var v := _sector_value(e, p, int(hx["n"]))
	if not hx["npc"].is_empty() and not e.ps[p]["S"].get("ancient_friend", false):
		return false
	if int(e.ps[p]["discs"]) <= 1:
		return v > 4.0
	var m := _margin(e, p)
	if m < -2 or (m < 0 and v < 4.0):
		return false
	return v > 0.8 or e.round_n >= 7


# ================================================================ scoperte

func _discovery(e, p: int, req: Dictionary) -> Dictionary:
	var t: Dictionary = req["tile"]
	var late: bool = e.round_n >= 7
	match str(t.get("k", "")):
		"mat6", "sci5", "money8", "mix":
			return {"vp": late}
		"tech", "cruiser", "monolith", "orbital", "warp":
			return {"vp": false}
		"part":
			var pt: String = t["part"]
			var best := _best_part_slot(e, p, pt)
			return {"vp": best.is_empty() and late}
	return {"vp": true}


func _part(e, p: int, req: Dictionary) -> Dictionary:
	var pt: String = req["part"]
	if D.PARTS[pt].get("outside", false):
		return {"s": "dre" if e.count_ships(p, "dre") > 0 else ("cru" if e.count_ships(p, "cru") > 0 else "int")}
	var b := _best_part_slot(e, p, pt)
	if b.is_empty():
		return {"keep": true}
	return {"s": b["s"], "i": b["i"]}


func _best_part_slot(e, p: int, pt: String) -> Dictionary:
	var best := {}
	var bv := 0.05
	for s in D.SHIP_TYPES:
		for i in e.ps[p]["bp"][s].size():
			if s == "sb" and int(D.PARTS[pt].get("mv", 0)) > 0:
				continue
			if not e.bp_valid_with(p, s, i, pt):
				continue
			var dv := _bp_delta(e, p, s, i, pt)
			if dv > bv:
				bv = dv
				best = {"s": s, "i": i}
	return best


# ================================================================ ricerca

func _tech_value(e, p: int, t: String) -> float:
	var T: Dictionary = D.TECHS[t]
	var v := 0.0
	var r: int = e.round_n
	match t:
		"advanced_mining", "advanced_labs", "advanced_economy", "metasynthesis":
			var want: String = {"advanced_mining": "m", "advanced_labs": "s", "advanced_economy": "$", "metasynthesis": "*"}[t]
			var c := 0
			for hx in e.controls(p):
				var pl: Array = e.sector(hx)["pl"]
				for i in pl.size():
					if pl[i].ends_with("*") and hx["cubes"][i] == "" and (want == "*" or pl[i].begins_with(want) or pl[i].begins_with("g")):
						c += 1
			v = c * 2.2 + 0.5
		"quantum_grid":
			v = 5.0
		"advanced_robotics":
			v = 4.0
		"nanorobots":
			v = 1.5
		"orbital":
			v = 2.5 if r <= 6 else 1.0
		"monolith":
			v = 4.5 if r >= 4 else 2.5
		"starbase":
			v = 1.5
		"neutron_bombs":
			v = 1.0
		"wormhole_generator":
			v = 2.0
		"artifact_key":
			var c := 0
			for hx in e.controls(p):
				if e.sector(hx).get("art", false):
					c += 1
			v = c * 2.5
		"ancient_labs":
			v = 3.0
		"warp_portal":
			v = 2.0
		"improved_logistics", "pico_modulator", "cloaking_device", "antimatter_splitter", "neutron_absorber":
			v = 1.2
		_:
			if T["kind"] == "part":
				v = _part_tech_value(e, p, t)
	# punti dei tracciati
	var cat: String = T["cat"]
	if cat == "rare":
		cat = e._best_track_for_rare(p)
	var k: int = e.ps[p]["techs"][cat].size()
	v += (D.TECH_VP[min(7, k + 1)] - D.TECH_VP[min(7, k)]) * 1.0
	v += 0.4 * float(D.TECH_DISCOUNT[min(6, k + 1)] - D.TECH_DISCOUNT[min(6, k)])
	if r >= 7:
		v *= 0.6
	return v


func _part_tech_value(e, p: int, t: String) -> float:
	var best := 0.0
	for pt in D.PARTS:
		if D.PARTS[pt].get("tech", "") != t:
			continue
		for s in ["int", "cru", "dre", "sb"]:
			var n_ships: int = max(1, e.count_ships(p, s))
			for i in e.ps[p]["bp"][s].size():
				var old: String = e.ps[p]["bp"][s][i]
				# simula il possesso della tecnologia
				if not e.bp_valid_with(p, s, i, pt):
					continue
				var dv := _bp_delta(e, p, s, i, pt) * (1.0 + n_ships * 0.5)
				if dv > best:
					best = dv
	return best * 2.5 + 0.6


func _value_research(e, p: int) -> float:
	var opts: Array = e.research_opts(p)
	var best := 0.0
	var sci: int = int(e.ps[p]["res"]["s"])
	for o in opts:
		var v := _tech_value(e, p, o["t"])
		var cost: int = int(o["cost"])
		if cost > sci:
			v -= (cost - sci) * 0.7
		v = v * 1.4 - cost * 0.18
		best = max(best, v)
	return best


func _research(e, p: int, req: Dictionary) -> Dictionary:
	var best := ""
	var bv := 0.6
	var sci: int = int(e.ps[p]["res"]["s"])
	for o in req["opts"]:
		var v := _tech_value(e, p, o["t"])
		var cost: int = int(o["cost"])
		if cost > sci:
			v -= (cost - sci) * 0.8
		v = v * 1.4 - cost * 0.18 + rng.randf() * 0.3
		if v > bv:
			bv = v
			best = o["t"]
	if best == "":
		return {"stop": true}
	return {"t": best}


# ================================================================ progetti delle navi

func _p_hit(comp: int, sh: int) -> float:
	var need := clampi(6 - comp + sh, 2, 6)
	return float(7 - need) / 6.0


## Valore di combattimento di un progetto (attacco × resistenza, più l'iniziativa).
func _ship_value(st: Dictionary) -> float:
	var att := 0.0
	for d in st["can"]:
		att += (2.0 if d == "x" else float(D.DIE_DMG[d])) * _p_hit(int(st["comp"]), 1)
	for d in st["mis"]:
		att += (2.0 if d == "x" else float(D.DIE_DMG[d])) * _p_hit(int(st["comp"]), 1) * 0.7
	var dfn: float = float(int(st["hull"]) + 1) / max(0.12, _p_hit(1, int(st["sh"])))
	return att * (1.0 + dfn * 0.35) + int(st["ini"]) * 0.06 + min(int(st["mv"]), 3) * 0.08


func _bp_delta(e, p: int, s: String, i: int, pt: String) -> float:
	var before := _ship_value(e.ship_stats(p, s))
	var old: String = e.ps[p]["bp"][s][i]
	e.ps[p]["bp"][s][i] = pt
	var after := _ship_value(e.ship_stats(p, s))
	e.ps[p]["bp"][s][i] = old
	return after - before


func _value_upgrade(e, p: int) -> float:
	var opts: Array = e.upgrade_opts(p)
	var best := 0.0
	for o in opts:
		var n_ships: int = e.count_ships(p, o["s"])
		var dv := _bp_delta(e, p, o["s"], int(o["i"]), o["part"]) * (0.6 + n_ships)
		best = max(best, dv)
	if best < 0.25:
		return 0.0
	return best * 1.3 + (1.0 if _threatened(e, p) else 0.0)


func _upgrade(e, p: int, req: Dictionary) -> Dictionary:
	var best := {}
	var bv := 0.08
	for o in req["opts"]:
		var n_ships: int = e.count_ships(p, o["s"])
		var weight := 0.6 + n_ships
		if o["s"] == "sb" and n_ships == 0:
			weight = 0.15
		if o["s"] == "dre" and n_ships == 0:
			weight = 0.35
		var dv := _bp_delta(e, p, o["s"], int(o["i"]), o["part"]) * weight
		if dv > bv:
			bv = dv
			best = o
	if best.is_empty():
		return {"stop": true}
	return {"s": best["s"], "i": best["i"], "part": best["part"]}


# ================================================================ costruzione

func _threatened(e, p: int) -> bool:
	for hx in e.controls(p):
		for nb in e.neighbors(hx):
			for s in e.ships_in(nb["k"]):
				if int(s["p"]) != p:
					return true
	return false


func _fleet_value(e, p: int) -> float:
	var v := 0.0
	for s in e.ships:
		if int(s["p"]) == p:
			v += _ship_value(e.ship_stats(p, s["t"]))
	return v


func _value_build(e, p: int) -> float:
	var opts: Array = e.build_opts(p)
	if opts.is_empty():
		return 0.0
	var m: int = int(e.ps[p]["res"]["m"])
	var v := 0.0
	var fleet := _fleet_value(e, p)
	var want_fleet: float = 2.0 + e.round_n * 1.6 + (4.0 if _threatened(e, p) else 0.0)
	if _attack_target(e, p, true) != {}:
		want_fleet += 3.0
	if fleet < want_fleet:
		v = 3.5 + (want_fleet - fleet) * 0.4
	for o in opts:
		if o["w"] == "mono":
			v = max(v, 6.5 if e.round_n >= 4 else 4.0)
		elif o["w"] == "orb":
			v = max(v, 3.0 if e.round_n <= 6 else 1.0)
	if m >= 14:
		v += 1.5
	return v


func _build(e, p: int, req: Dictionary) -> Dictionary:
	var best := {}
	var bv := 0.3
	var m: int = int(e.ps[p]["res"]["m"])
	var target := _attack_target(e, p, true)
	for o in req["opts"]:
		var w: String = o["w"]
		var cost: int = e.build_cost(p, w)
		var v := 0.0
		match w:
			"mono":
				v = 5.0 if e.round_n >= 3 else 2.0
			"orb":
				v = 2.4 if e.round_n <= 6 else 0.5
			"sb":
				v = _ship_value(e.ship_stats(p, "sb")) / cost * 4.0 * (1.5 if _threatened(e, p) else 0.5)
			_:
				v = _ship_value(e.ship_stats(p, w)) / cost * 6.0
				if w == "dre":
					v *= 1.15
		# vicino all'obiettivo o in casa
		var hx: Dictionary = e.hexes[o["h"]]
		if not target.is_empty() and w in ["int", "cru", "dre"]:
			v += 1.0 / (1.0 + D.dist(hx["pos"], e.hexes[target["h"]]["pos"]))
		if e.sector(hx).get("home", false):
			v += 0.2
		if cost > m:
			v -= (cost - m) * 1.0
		v += rng.randf() * 0.2
		if v > bv:
			bv = v
			best = o
	if best.is_empty():
		return {"stop": true}
	return {"w": best["w"], "h": best["h"]}


# ================================================================ combattimento simulato

## Unità per la simulazione: {st, hp, side}
func _sim(att: Array, dfn: Array, runs := 24) -> float:
	var wins := 0
	for r in runs:
		var units := []
		for u in att:
			units.append({"st": u, "hp": int(u["hull"]) + 1, "side": 1})
		for u in dfn:
			units.append({"st": u, "hp": int(u["hull"]) + 1, "side": 0})
		units.sort_custom(func(a, b):
			if int(a["st"]["ini"]) != int(b["st"]["ini"]):
				return int(a["st"]["ini"]) > int(b["st"]["ini"])
			return a["side"] < b["side"])
		# missili
		for u in units:
			_sim_fire(u, units, u["st"]["mis"])
		var rounds := 0
		while rounds < 12 and _sim_alive(units, 0) and _sim_alive(units, 1):
			rounds += 1
			for u in units:
				if u["hp"] > 0:
					_sim_fire(u, units, u["st"]["can"])
		if _sim_alive(units, 1) and not _sim_alive(units, 0):
			wins += 1
	return float(wins) / runs


func _sim_alive(units: Array, side: int) -> bool:
	for u in units:
		if u["side"] == side and u["hp"] > 0:
			return true
	return false


func _sim_fire(u: Dictionary, units: Array, dice: Array) -> void:
	if u["hp"] <= 0:
		return
	for d in dice:
		var foes := []
		for o in units:
			if o["side"] != u["side"] and o["hp"] > 0:
				foes.append(o)
		if foes.is_empty():
			return
		var t: Dictionary = foes[0]
		for o in foes:
			if o["hp"] < t["hp"]:
				t = o
		var v := rng.randi_range(1, 6)
		var dmg := 0
		if d == "x":
			dmg = [1, 2, 3, 0, 0, 0][v - 1]
		elif v == 6 or (v > 1 and v + int(u["st"]["comp"]) - int(t["st"]["sh"]) >= 6):
			dmg = int(D.DIE_DMG[d])
		t["hp"] -= dmg


func _defenders(e, p: int, hk: String) -> Array:
	var out := []
	var hx: Dictionary = e.hexes[hk]
	for s in e.ships_in(hk):
		if int(s["p"]) != p:
			out.append(e.ship_stats(int(s["p"]), s["t"]))
	if e.npc_blocks(hx, p):
		for npc in hx["npc"]:
			out.append(e.npc_stats(npc["k"]))
	return out


## Obiettivo d'attacco raggiungibile con buone probabilità: {h, ships: [id], p}
func _attack_target(e, p: int, loose := false) -> Dictionary:
	var thr: float = [0.8, 0.72, 0.66][level]
	if loose:
		thr -= 0.25
	var mine := []
	for s in e.ships:
		if int(s["p"]) == p:
			mine.append(s)
	if mine.is_empty():
		return {}
	var dests := {}
	for s in mine:
		dests[int(s["id"])] = e.ship_dests(s)
	var best := {}
	var bv := 0.0
	for k in e.hexes:
		var hx: Dictionary = e.hexes[k]
		var dfn := _defenders(e, p, k)
		if dfn.is_empty():
			continue
		# niente attacchi a chi ha relazioni diplomatiche
		var friend := false
		for s in e.ships_in(k):
			if int(s["p"]) != p and e.has_relation(p, int(s["p"])):
				friend = true
		if friend:
			continue
		var att := []
		var ids := []
		for s in mine:
			if s["h"] == k:
				att.append(e.ship_stats(p, s["t"]))
			elif dests[int(s["id"])].has(k):
				att.append(e.ship_stats(p, s["t"]))
				ids.append(int(s["id"]))
		if ids.is_empty() or att.is_empty():
			continue
		var pw := _sim(att, dfn, 40)
		if pw < thr:
			continue
		var gain := _sector_value(e, p, int(hx["n"])) + 1.5 * dfn.size()
		if int(hx["owner"]) >= 0 and int(hx["owner"]) != p:
			gain += 2.0
		var v := gain * pw
		if v > bv:
			bv = v
			best = {"h": k, "ships": ids, "pw": pw}
	return best


func _defense_target(e, p: int) -> Dictionary:
	for hx in e.controls(p):
		var foes := false
		for s in e.ships_in(hx["k"]):
			if int(s["p"]) != p:
				foes = true
		if not foes:
			continue
		for s in e.ships:
			if int(s["p"]) == p and s["h"] != hx["k"] and e.ship_dests(s).has(hx["k"]):
				return {"h": hx["k"], "ships": [int(s["id"])]}
	return {}


func _value_move(e, p: int) -> float:
	var t := _attack_target(e, p)
	if not t.is_empty():
		plan = t
		return 5.5 + float(t["pw"]) * 2.0
	var d := _defense_target(e, p)
	if not d.is_empty():
		plan = d
		return 5.0
	# spostare navi verso settori liberi da influenzare
	return 0.0


func _move(e, p: int, req: Dictionary) -> Dictionary:
	var opts: Dictionary = req["opts"]
	if plan.is_empty():
		var t := _attack_target(e, p)
		if t.is_empty():
			t = _defense_target(e, p)
		plan = t
	if plan.is_empty():
		return {"stop": true}
	var target: String = plan["h"]
	# la nave più forte che può arrivare
	var best := ""
	var bv := -1.0
	for id in opts:
		if not opts[id].has(target):
			continue
		var s: Dictionary = e.ship_by_id(int(id))
		var v := _ship_value(e.ship_stats(p, s["t"]))
		if v > bv:
			bv = v
			best = id
	if best == "":
		plan = {}
		return {"stop": true}
	return {"id": best, "to": target}


func _battle(e, p: int, req: Dictionary) -> Dictionary:
	var k: String = req["h"]
	var att := []
	for s in e.ships_in(k, p):
		var st: Dictionary = e.ship_stats(p, s["t"])
		var copy := st.duplicate()
		copy["hull"] = max(0, int(st["hull"]) - int(s["dmg"]))
		att.append(copy)
	var dfn := []
	for s in e.ships_in(k):
		if int(s["p"]) != p:
			var st: Dictionary = e.ship_stats(int(s["p"]), s["t"])
			var copy := st.duplicate()
			copy["hull"] = max(0, int(st["hull"]) - int(s["dmg"]))
			dfn.append(copy)
	var hx: Dictionary = e.hexes[k]
	for npc in hx["npc"]:
		var st: Dictionary = e.npc_stats(npc["k"])
		var copy := st.duplicate()
		copy["hull"] = max(0, int(st["hull"]) - int(npc["dmg"]))
		dfn.append(copy)
	var pw := _sim(att, dfn, 16)
	if pw < [0.1, 0.2, 0.28][level]:
		return {"retreat": req["dests"][0]}
	return {"fire": true}


# ================================================================ influenza e colonie

func _value_influence(e, p: int) -> float:
	var targets: Array = e.influence_targets(p)
	var best := 0.0
	for k in targets:
		var v := _sector_value(e, p, int(e.hexes[k]["n"]))
		best = max(best, v)
	if int(e.ps[p]["discs"]) <= 1:
		best *= 0.5
	var flip: int = int(e.ps[p]["colony_used"])
	var col := 0
	var free_ships: int = int(e.ps[p]["colony"]) - flip
	for hx in e.controls(p):
		var pl: Array = e.sector(hx)["pl"]
		for i in pl.size():
			if hx["cubes"][i] != "":
				continue
			var code: String = pl[i]
			if code.ends_with("*"):
				var t: String = code.replace("*", "")
				var need: String = {"m": "advanced_mining", "s": "advanced_labs", "$": "advanced_economy", "g": "metasynthesis"}[t]
				if not e.has_tech(p, need) and not e.has_tech(p, "metasynthesis"):
					continue
			col += 1
	var usable: int = min(col - free_ships, min(flip, 2))
	if usable > 0:
		best += 2.6 * usable
	return best * 0.9


func _influence(e, p: int, req: Dictionary) -> Dictionary:
	var best := ""
	var bv := 1.2
	if int(e.ps[p]["discs"]) > 1 or _margin(e, p) > 0:
		for k in req["add"]:
			var v := _sector_value(e, p, int(e.hexes[k]["n"])) + rng.randf() * 0.2
			if v > bv:
				bv = v
				best = k
	if best != "":
		return {"add": best}
	# si ritirano i dischi dai settori vuoti quando servono dischi
	if int(e.ps[p]["discs"]) <= 2:
		for k in req["remove"]:
			var hx: Dictionary = e.hexes[k]
			var cubes := 0
			for c in hx["cubes"]:
				if c != "":
					cubes += 1
			if cubes == 0 and int(e.sector(hx)["vp"]) <= 1 and not e.sector(hx).get("home", false) and not hx["mono"]:
				return {"remove": k}
	return {"stop": true}


func _colony(e, p: int, req: Dictionary) -> Dictionary:
	var best := {}
	var bv := 0.0
	var st: Dictionary = e.ps[p]
	var money_need: bool = e.prod(p, "$") < e.upkeep_next(p) + 1
	for o in req["opts"]:
		for t in o["t"]:
			var c: int = int(st["track"][t])
			var now: int = e.prod(p, t)
			st["track"][t] = c - 1
			var after: int = e.prod(p, t)
			st["track"][t] = c
			var w: float = {"$": 1.15, "s": 1.0, "m": 0.9}[t]
			if t == "$" and money_need:
				w = 1.6
			var v: float = (after - now) * w + rng.randf() * 0.1
			if v > bv:
				bv = v
				best = {"h": o["h"], "i": o["i"], "t": t}
	if best.is_empty():
		return {"stop": true}
	return best
