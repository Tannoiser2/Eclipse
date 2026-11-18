extends SceneTree
## Sonda per scrivere il tutorial: gioca la partita del tutorial con le risposte date in EC_ANS (JSON, una
## per ogni decisione della persona) e stampa ogni richiesta con le opzioni. Gli avversari sono l'IA.

const D = preload("res://scripts/data/ec_data.gd")

func _init() -> void:
	_run()

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var cfg: Dictionary = load("res://scripts/ui/tutorial.gd").config()
	main.start_game(cfg)
	var g = main.current
	var ans: Array = JSON.parse_string(OS.get_environment("EC_ANS")) if OS.get_environment("EC_ANS") != "" else []
	var k := 0
	var guard := 0
	while guard < 3000 and g.engine.round_n <= 1 and g.engine.phase != "over":
		guard += 1
		await process_frame
		if g.pending.is_empty():
			continue
		var req: Dictionary = g.pending
		var e = g.engine
		var p: int = req["seat"]
		print("--- R%d fase %s | %s res %s prod m%d s%d $%d dischi %d mant %d" % [e.round_n, e.phase, req["type"], e.ps[0]["res"], e.prod(0, "m"), e.prod(0, "s"), e.prod(0, "$"), e.ps[0]["discs"], e.upkeep(0)])
		var shown := req.duplicate()
		shown.erase("seat")
		print(JSON.stringify(shown).left(900))
		if k < ans.size():
			print(">> ", ans[k])
			g._submit(ans[k])
			k += 1
		else:
			print("FINE RISPOSTE")
			break
	print("vassoio: ", g.engine.tray)
	for i in g.engine.ps.size():
		print(i, " ", g.engine.pname(i), " ", g.engine.ps[i]["res"], " passed ", g.engine.ps[i]["passed"])
	print("log:")
	for l in g.engine.log_lines.slice(-40) if "log_lines" in g.engine else []:
		print("  ", l)
	quit()
