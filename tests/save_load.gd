extends SceneTree
## Prova di salvataggio e caricamento (sul finto Firebase): gioca qualche round, salva, ricarica dal codice
## e controlla che la partita ripresa sia identica (impronta) e prosegua.

var ai := ECAI.new(1, 4)

func _init() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _play_until(g, rnd: int) -> void:
	while g.engine.round_n < rnd or g.pending.is_empty() or g.pending["type"] != "turn":
		await process_frame
		if not g.pending.is_empty():
			g._submit(ai.decide(g.engine, g.pending["seat"], g.pending))

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	var seats := [{"name": "Io", "ai": false, "level": 1, "color": 0, "species": "terran_directorate"},
		{"name": "", "ai": true, "level": 1, "color": 1, "species": "hydran"}, {"name": "", "ai": true, "level": 2, "color": 2, "species": "planta"}]
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 0.0, "seed": 77})
	var g = main.current
	await _play_until(g, 3)
	var fp1: String = g.engine.fingerprint()
	await g._save_game()
	var code: String = g.save_code
	print("ECTEST salvata ", code, " ", fp1)
	main.show_menu()
	await _wait(0.3)
	var menu = main.current
	menu._load_panel()
	menu.on_code.text = code
	await menu._do_load()
	var g2 = main.current
	while g2.pending.is_empty():
		await process_frame
	print("ECTEST ripresa ", g2.engine.fingerprint(), " ", "OK" if g2.engine.fingerprint() == fp1 else "DIVERSA")
	await _play_until(g2, 5)
	print("ECTEST prosegue fino al round ", g2.engine.round_n)
	quit()
