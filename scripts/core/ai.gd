class_name ECAI
extends RefCounted
## Intelligenza artificiale per i posti vuoti. Euristica: valuta settori, tecnologie e progetti delle navi,
## tiene d'occhio il denaro per il mantenimento e attacca solo quando una simulazione rapida della battaglia
## dà buone probabilità di vittoria. Ha un proprio generatore casuale (non tocca quello del motore).
## Livelli: 0 facile, 1 normale, 2 difficile.

const D = preload("res://scripts/data/ec_data.gd")

var level := 1
var rng := RandomNumberGenerator.new()
var ab := ""                      # varianti per i confronti delle simulazioni
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
		"hole":
			return _hole(e, p, req)
		"shrine":
			return _shrine(e, p, req)
	return {"stop": true}


# ================================================================ denaro

## Denaro che resterebbe dopo il mantenimento con un disco in più (contando gli scambi possibili).
func _margin(e, p: int, extra_discs := 1) -> float:
	var st: Dictionary = e.ps[p]
	var dsc: int = int(st["discs"]) - extra_discs
	var up := 0
	if dsc < D.INF_SPACES:
		up = D.INF_VALUES[clampi(12 - dsc, 0, 12)]
	# le altre risorse si possono scambiare al mantenimento: se ne tiene una scorta per costruire e ricercare
	var other := 0.0
	var keep: int = 6 if e.round_n < 7 else 0
	for r in ["m", "s"]:
		var tp: Array = e.trade_pair(p, r)
		other += float(int(max(0, int(st["res"][r]) - keep) / int(tp[0])) * int(tp[1]))
	var w := 0.6 if level >= 1 and ab.find("f") < 0 else 0.3
	return float(int(st["res"]["$"]) + e.prod(p, "$") - up) + other * w


# ================================================================ turno

func _turn(e, p: int, req: Dictionary) -> Dictionary:
	var opts: Array = req["opts"]
	if req.get("colony", false):
		return {"a": "colony"}
	var mp := _minor_pick(e, p, req)
	if mp != "":
		return {"a": "minor", "m": mp}
	if not req.get("passed", false):
		var pk := _pulsar_pick(e, p, req)
		if not pk.is_empty():
			return pk
	var dip: Array = req.get("diplo", [])
	if not dip.is_empty() and level >= 1 and ab.find("g") < 0:
		return {"a": "diplo", "t": dip[0]}
	var margin := _margin(e, p)
	var best := "pass"
	var bv := 1.0 + (0.0 if level >= 2 and ab.find("b") < 0 else 0.5)
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
		v += rng.randf() * (0.6 if level == 0 or ab.find("e") >= 0 else 0.25)
		if v > bv:
			bv = v
			best = a
	# bancarotta tattica: nei primi round si può andare un po' in rosso e lasciare i settori meno utili
	var floor_m := -2.0
	if level >= 1 and ab.find("A") >= 0 and e.round_n <= 2 and best == "exp":
		floor_m = -5.0
	if best != "pass" and margin < 0:
		# un disco in più non si potrebbe pagare: solo se l'azione vale molto
		if bv < 6.0 or margin < floor_m:
			best = "pass"
	elif best != "pass" and margin < 2 and bv < 2.0 and e.round_n < 8:
		best = "pass"
	if best == "pass" and req.get("colony_res", false) and not req.get("colony", false):
		var need := "$" if _margin(e, p, 0) < 2 else ("s" if int(e.ps[p]["res"]["s"]) < 8 else "m")
		return {"a": "colony_res", "r": need}
	return {"a": best}


# ================================================================ valori dei settori

func _sector_value(e, p: int, num: int) -> float:
	var S: Dictionary = D.SECTORS[num]
	if S.get("nebula", false) or S.has("hole"):
		return 0.3
	var v: float = float(S["vp"]) * (0.8 + e.round_n * 0.12)
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
	var zones: Array = e.explore_zones(p)
	if zones.is_empty():
		return 0.0
	if int(e.ps[p]["discs"]) < 2:
		return 0.5
	var r: int = e.round_n
	if _margin(e, p, 2) < (-4 if r <= 2 and level >= 1 and ab.find("A") >= 0 else -1):
		return 1.0
	var base := 8.5 - r * 0.95
	var own: int = e.controls(p).size()
	if own < 4:
		base += 1.5
	if zones.size() <= 1:
		base -= 1.0
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
	for s in e.ps[p]["types"]:
		for i in e.ps[p]["bp"][s].size():
			if (s == "sb" or s == "orb") and int(D.PARTS[pt].get("mv", 0)) > 0:
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
			v = (5.5 if r >= 3 else 3.5) if r <= 6 else 2.0
		"advanced_robotics":
			# il disco in più si ripaga quasi subito: la tecnologia più consigliata all'inizio
			v = 7.0 if r <= 5 else (3.0 if r <= 7 else 1.0)
		"nanorobots":
			v = (2.5 if e.prod(p, "m") >= 6 else 1.0) if r <= 6 else 0.6
		"orbital":
			v = (2.0 if r <= 5 else 0.6) + (1.5 if e.ps[p]["S"].get("orb_ships", false) else 0.0)
		"monolith":
			v = 4.5 if r >= 3 and r <= 7 else 2.0
		"starbase":
			v = 1.5 if _threatened(e, p) else 0.8
		"neutron_bombs":
			v = 2.5 if r >= 3 else 1.5
		"wormhole_generator":
			v = 1.5 if r >= 4 and r <= 6 else 0.6
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
				# armi e corazze che i giocatori esperti prendono presto
				if t in ["improved_hull", "plasma_cannon", "positron_computer"] and r <= 5:
					v += 1.8
				elif t in ["fusion_source", "gauss_shield"] and r <= 4:
					v += 0.6
	# punti dei tracciati
	var cat: String = T["cat"]
	if cat == "rare":
		cat = e._best_track_for_rare(p)
	var k: int = e.ps[p]["techs"][cat].size()
	v += (D.TECH_VP[min(7, k + 1)] - D.TECH_VP[min(7, k)]) * (1.4 if r >= 6 else 1.0)
	v += float(D.TECH_DISCOUNT[min(6, k + 1)] - D.TECH_DISCOUNT[min(6, k)]) * max(0.0, (6 - r) * 0.18)
	# meglio concentrarsi su uno o due tracciati che spargere la ricerca
	if level >= 1 and ab.find("c") < 0:
		var tracks := []
		for c2 in D.TECH_CATS:
			tracks.append(e.ps[p]["techs"][c2].size())
		tracks.sort()
		if k >= tracks[1] and k > 0:
			v += 0.4 * min(k, 4)
	if r >= 7 and T["kind"] != "instant":
		v *= 0.6
	return v


func _part_tech_value(e, p: int, t: String) -> float:
	var best := 0.0
	for pt in D.PARTS:
		if D.PARTS[pt].get("tech", "") != t:
			continue
		for s in e.ps[p]["types"]:
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
	var n_act: int = int(e.ps[p]["S"]["acts"]["res"])
	var vals := []
	for o in opts:
		var v := _tech_value(e, p, o["t"])
		var cost: int = int(o["cost"])
		if cost > sci:
			v -= (cost - sci) * 0.6
		v = v * 1.5 - cost * 0.12
		vals.append(v)
	vals.sort()
	vals.reverse()
	for i in min(n_act, vals.size()):
		best += max(0.0, vals[i]) * (1.0 if i == 0 else 0.6)
	# scienza che resterebbe inutilizzata
	if sci >= 10:
		best += 1.0
	return best


func _research(e, p: int, req: Dictionary) -> Dictionary:
	var best := ""
	var bv := 0.6
	var sci: int = int(e.ps[p]["res"]["s"])
	for o in req["opts"]:
		var v := _tech_value(e, p, o["t"])
		var cost: int = int(o["cost"])
		if cost > sci:
			v -= (cost - sci) * 0.7
		v = v * 1.5 - cost * 0.12 + rng.randf() * (0.6 if level == 0 else 0.2)
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
			v = max(v, 7.5 if e.round_n >= 3 else 4.5)
		elif o["w"] == "orb":
			var spare := 0
			for t in ["s", "$"]:
				spare += int(e.ps[p]["track"][t])
			v = max(v, (3.5 if e.round_n <= 6 else 1.0) if spare > 2 else 0.5)
	if m >= 14:
		v += 1.5
	if e.round_n == 8 and m >= 3:
		v += 1.0
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
				v = 6.0 if e.round_n >= 3 else 3.0
			"orb":
				v = 2.6 if e.round_n <= 6 else 0.5
			"sb":
				v = _ship_value(e.ship_stats(p, "sb")) / cost * 4.0 * (1.5 if _threatened(e, p) else 0.5)
			_:
				v = _ship_value(e.ship_stats(p, w)) / cost * 6.0
				# le corazzate sono le più efficienti in azioni (costruire e muovere)
				if w == "dre":
					v *= 1.35 if level >= 1 and ab.find("h") < 0 else 1.15
				elif w == "cru":
					v *= 1.15 if level >= 1 and ab.find("h") < 0 else 1.0
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
	var thr: float = [0.8, 0.72, 0.66][level] if ab.find("d") < 0 else 0.8
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
		var players_here := false
		for s in e.ships_in(k):
			if int(s["p"]) != p:
				players_here = true
		var t2 := thr if players_here or int(hx["owner"]) >= 0 else thr - 0.06
		if pw < t2:
			continue
		var gain := _sector_value(e, p, int(hx["n"])) + 1.5 * dfn.size()
		# le prime battaglie danno reputazione migliore
		if e.round_n <= 5:
			gain += 1.0
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


# ================================================================ espansioni

func _hole(e, p: int, req: Dictionary) -> Dictionary:
	var best: String = req["opts"][0]
	var bv := -99.0
	for k in req["opts"]:
		var hx: Dictionary = e.hexes[k]
		var v := 0.0
		if int(hx["owner"]) == p:
			v += 3.0
		for s in e.ships_in(k):
			v += 1.0 if int(s["p"]) == p else -2.0
		v -= hx["npc"].size() * 2.0
		if v > bv:
			bv = v
			best = k
	return {"h": best}


func _shrine(e, p: int, req: Dictionary) -> Dictionary:
	var best := {}
	var bv := -99.0
	var placed: Array = e.ps[p]["shrines"]
	for o in req["opts"]:
		var i := int(o["i"])
		var cost: int = int(D.SHRINES[i][1])
		var row := int(i / 3)
		var in_row := 0
		for j in 3:
			if placed.has(row * 3 + j):
				in_row += 1
		var v := 2.2 - cost * 0.35 + in_row * 0.8 + rng.randf() * 0.1
		if v > bv:
			bv = v
			best = o
	if best.is_empty() or bv < 0.0:
		return {"stop": true}
	return {"i": best["i"], "h": best["h"], "pl": best["pl"]}


## Specie minore che conviene prendere ora (o "").
func _minor_pick(e, p: int, req: Dictionary) -> String:
	var opts: Array = req.get("minors", [])
	if opts.is_empty():
		return ""
	var st: Dictionary = e.ps[p]
	var best := ""
	var bv := 0.0
	for m in opts:
		var cost: int = int(D.MINORS[m]["cost"])
		var after: float = float(int(st["res"]["$"]) - cost + e.prod(p, "$") - e.upkeep_next(p))
		if after < 0:
			continue
		var v := 1.0
		match m:
			"wealth":
				v = 3.0
			"rep":
				v = float(st["rep"].size()) * 0.7 + 0.5
			"diplo":
				v = float(st["rep"].size()) * 0.6 + 1.0
			"prod":
				v = 1.0 + (8 - e.round_n) * 0.9
			"res":
				v = 1.0 + (8 - e.round_n) * 0.5
			"cru", "dre", "orb", "mono":
				v = 1.0 + (8 - e.round_n) * 0.25
		v = v * 2.0 - cost * 0.45 + (1.5 if e.round_n >= 7 else 0.0)
		if v > bv:
			bv = v
			best = m
	return best


## Pulsar: attivazione gratuita se serve a qualcosa.
func _pulsar_pick(e, p: int, req: Dictionary) -> Dictionary:
	for k in req.get("pulsars", []):
		var cur: String = str(e.hexes[k].get("pulsar", "mov"))
		var best := ""
		var bv := 2.0
		for a in D.PULSAR_ACTS:
			if a == cur:
				continue
			var v := 0.0
			match a:
				"upg":
					v = _value_upgrade(e, p)
				"bui":
					v = _value_build(e, p)
				"mov":
					v = _value_move(e, p)
			if v > bv:
				bv = v
				best = a
		if best != "":
			return {"a": "pulsar", "h": k, "act": best}
	return {}
