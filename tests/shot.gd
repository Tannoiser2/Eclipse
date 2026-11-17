extends SceneTree
## Fotografie dell'interfaccia (serve un display, anche virtuale: xvfb-run).
## Uso: xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s tests/shot.gd -- <cartella> [giocatori] [larghezza] [altezza] [specie]
## La persona (primo posto) lascia decidere all'IA; si fotografano le decisioni la prima volta che compaiono.

const D = preload("res://scripts/data/ec_data.gd")
var out := "/tmp/shots"
var taken := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var np := int(args[1]) if args.size() > 1 else 4
	var w := int(args[2]) if args.size() > 2 else 1920
	var h := int(args[3]) if args.size() > 3 else 1080
	var sp := args[4] if args.size() > 4 else "terran_directorate"
	DirAccess.make_dir_recursive_absolute(out)
	_run(np, w, h, sp)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(np: int, w: int, h: int, sp: String) -> void:
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _snap("menu")
	var seats := []
	for i in np:
		var col := i
		var s: String = sp if i == 0 else D.COLOR_SPECIES[i][1]
		if i == 0:
			for c in 6:
				if D.COLOR_SPECIES[c].has(sp):
					col = c
		elif col == 0:
			col = 5
		seats.append({"name": "Stefano" if i == 0 else "", "ai": i != 0, "level": 1, "color": col, "species": s})
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 6.0, "seed": 11})
	var g = main.current
	await create_timer(1.5).timeout
	await _snap("inizio")
	var guard := 0
	var last_round := 0
	while guard < 4000:
		guard += 1
		if g.engine.phase == "over":
			break
		if g.engine.round_n != last_round and g.engine.round_n in [3, 6]:
			last_round = g.engine.round_n
			await create_timer(0.3).timeout
			await _snap("round_%d" % last_round)
		if g.dice_panel.visible and not taken.has("battaglia"):
			taken["battaglia"] = true
			await _snap("battaglia")
		var req: Dictionary = g.pending
		if req.is_empty():
			await create_timer(0.05).timeout
			continue
		var t: String = req["type"]
		if not taken.has(t):
			taken[t] = true
			await create_timer(0.5).timeout
			await _snap("%02d_%s" % [taken.size(), t])
		var r = g.engine.ais[0].decide(g.engine, 0, req)
		g._submit(r)
		await create_timer(0.02).timeout
	await create_timer(1.5).timeout
	await _snap("fine")
	quit()
