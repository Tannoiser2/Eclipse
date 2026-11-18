extends SceneTree
## Partite simulate fra IA, senza grafica: controlla che le regole reggano e misura punteggi e durata.
## Uso: godot --headless --path . -s tests/sim.gd -- [giocatori 2-6] [partite] [livello, -1 = misti] [avanzati 0/1]
## EC_LOG=1 stampa il diario della prima partita.

const D = preload("res://scripts/data/ec_data.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var np := int(args[0]) if args.size() > 0 else 4
	var games := int(args[1]) if args.size() > 1 else 3
	var lv := int(args[2]) if args.size() > 2 else 1
	var adv := int(args[3]) if args.size() > 3 else 0
	var exp := int(args[4]) if args.size() > 4 else 0
	_run(np, games, lv, adv, exp)


func _run(np: int, games: int, lv: int, adv: int, exp: int) -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var wins := {}
	var tot := 0.0
	var by_lv := {0: [0.0, 0], 1: [0.0, 0], 2: [0.0, 0]}
	var by_sp := {}
	var by_grp := [[0.0, 0, 0], [0.0, 0, 0]]
	for g in games:
		var eng := ECEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		# partite a coppie: stessa mappa e specie, varianti scambiate di posto
		var gg := int(g / 2)
		for i in np:
			var l := lv if lv >= 0 else (i + g) % 3
			var col := (i + gg) % 6
			var sp: String = D.COLOR_SPECIES[col][(i + gg) % 2]
			if exp == 1 and i < D.EXP_SPECIES.size() and (i + gg) % 2 == 0:
				sp = D.EXP_SPECIES[(i + int(gg / 2)) % D.EXP_SPECIES.size()]
			seats.append({"name": "IA%d-%s" % [i, sp.substr(0, 6)], "ai": true, "level": l, "color": col, "species": sp})
		eng.setup({"seats": seats, "seed": 1000 + gg, "adv_npc": adv == 1, "events": exp == 1, "minors": exp == 1, "turn_order": exp == 1})
		for i in np:
			eng.ais[i] = ECAI.new(int(seats[i]["level"]), 50 + gg * 7 + i)
			eng.ais[i].ab = OS.get_environment("EC_AB" if (i + g) % 2 == 0 else "EC_AB0")
		if OS.get_environment("EC_LOG") == "1" and g == 0:
			eng.log_added.connect(func(t): print(t))
		await eng.run()
		var w: int = eng.result.get("winner", -9)
		wins[seats[w]["name"]] = wins.get(seats[w]["name"], 0) + 1
		var line := []
		for p in np:
			var s: Dictionary = eng.result["scores"][p]
			var st: Dictionary = eng.ps[p]
			line.append("%d(rep%d set%d mon%d sc%d tec%d sp%d | sett%d navi%d tech%d %s)" % [s["totale"], s["rep"], s["settori"], s["monoliti"], s["scoperte"], s["tecnologie"], s["specie"],
				eng.controls(p).size(), _ships(eng, p), st["techs"]["mil"].size() + st["techs"]["grid"].size() + st["techs"]["nano"].size(), "ELIM" if st["eliminated"] else ""])
			tot += s["totale"]
			var grp := (p + g) % 2
			by_grp[grp][0] += s["totale"]
			by_grp[grp][1] += 1
			if w == p:
				by_grp[grp][2] += 1
			var lvp: int = int(seats[p]["level"])
			by_lv[lvp][0] += s["totale"]
			by_lv[lvp][1] += 1
			var spk: String = str(eng.ps[p]["sp"])
			if not by_sp.has(spk):
				by_sp[spk] = [0.0, 0]
			by_sp[spk][0] += s["totale"]
			by_sp[spk][1] += 1
		var npc := 0
		for k in eng.hexes:
			npc += eng.hexes[k]["npc"].size()
		print("  partita %d: %d settori, neutrali rimasti %d, vince %s — %s" % [g, eng.hexes.size(), npc, seats[w]["name"], "  ".join(line)])
		eng.queue_free()
	var lvs := []
	for k in by_lv:
		if by_lv[k][1] > 0:
			lvs.append("L%d %.1f" % [k, by_lv[k][0] / by_lv[k][1]])
	var sps := []
	for k in by_sp:
		sps.append("%s %.1f" % [k, by_sp[k][0] / by_sp[k][1]])
	print("Vittorie %s, punti medi %.1f (%s), %d ms" % [wins, tot / (games * np), ", ".join(lvs), Time.get_ticks_msec() - t0])
	print("Per specie: ", ", ".join(sps))
	print("Confronto: variante %.2f (%d vittorie), base %.2f (%d vittorie)" % [by_grp[0][0] / max(1, by_grp[0][1]), by_grp[0][2], by_grp[1][0] / max(1, by_grp[1][1]), by_grp[1][2]])
	quit()


func _ships(eng, p: int) -> int:
	var c := 0
	for s in eng.ships:
		if int(s["p"]) == p:
			c += 1
	return c
