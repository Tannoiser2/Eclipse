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
	_run(np, games, lv, adv)


func _run(np: int, games: int, lv: int, adv: int) -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var wins := {}
	var tot := 0.0
	for g in games:
		var eng := ECEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		for i in np:
			var l := lv if lv >= 0 else (i + g) % 3
			var col := (i + g) % 6
			var sp: String = D.COLOR_SPECIES[col][(i + g) % 2]
			seats.append({"name": "IA%d-%s" % [i, sp.substr(0, 6)], "ai": true, "level": l, "color": col, "species": sp})
		eng.setup({"seats": seats, "seed": 1000 + g, "adv_npc": adv == 1})
		for i in np:
			eng.ais[i] = ECAI.new(int(seats[i]["level"]), 50 + g * 7 + i)
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
		var npc := 0
		for k in eng.hexes:
			npc += eng.hexes[k]["npc"].size()
		print("  partita %d: %d settori, neutrali rimasti %d, vince %s — %s" % [g, eng.hexes.size(), npc, seats[w]["name"], "  ".join(line)])
		eng.queue_free()
	print("Vittorie %s, punti medi %.1f, %d ms" % [wins, tot / (games * np), Time.get_ticks_msec() - t0])
	quit()


func _ships(eng, p: int) -> int:
	var c := 0
	for s in eng.ships:
		if int(s["p"]) == p:
			c += 1
	return c
