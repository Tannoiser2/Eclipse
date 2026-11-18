extends SceneTree
## Prova del tutorial: segue il percorso guidato (con una scelta sbagliata che deve essere rifiutata),
## fotografa i passi e controlla che si arrivi alla fine del round con il riquadro finale.
## Uso: xvfb-run ... godot --path . -s tests/tut_play.gd -- <cartella> <larghezza> <altezza>

const ANS := [{"a": "exp"}, {"z": "0,-3"}, {"tile": 382, "rot": 0}, {"vp": false}, {"yes": true}, {"a": "colony"},
	{"h": "0,-3", "i": 0, "t": "s"}, {"h": "0,-3", "i": 1, "t": "m"}, {"a": "exp"}, {"z": "1,-3"}, {"tile": 315, "rot": 0},
	{"vp": false}, {"yes": false}, {"a": "res"}, {"t": "fusion_source"}, {"a": "bui"}, {"w": "sb", "h": "0,-3"}, {"a": "pass"}]

func _init() -> void:
	_run()

func _snap(out: String, name: String) -> void:
	if out == "":
		return
	for i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		var w := int(a[1])
		var h := int(a[2])
		root.size = Vector2i(w, h)
		DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.start_game(load("res://scripts/ui/tutorial.gd").config())
	var g = main.current
	var k := 0
	var rejected := false
	var guard := 0
	while guard < 20000:
		guard += 1
		await process_frame
		if g.tutorial == null or g.tutorial._final:
			break
		if g.pending.is_empty() or g.pending["seat"] != 0:
			continue
		await create_timer(0.3).timeout
		if g.pending.is_empty():
			continue
		var t: String = g.pending["type"]
		await _snap(out, "%02d_%s" % [k, t])
		# a metà percorso una scelta sbagliata deve essere rifiutata
		if k == 13 and not rejected:
			rejected = true
			g._submit({"a": "inf"})
			print("TUT rifiutata: ", not g.pending.is_empty())
		if k < ANS.size():
			print("TUT passo ", k, " ", t, " -> ", ANS[k])
			g._submit(ANS[k])
			k += 1
		else:
			print("TUT richiesta extra ", t, " passed=", g.pending.get("passed", false))
			g._submit({"a": "pass"} if t == "turn" else {"stop": true})
	await create_timer(1.0).timeout
	await _snap(out, "fine_0")
	if g.tutorial != null:
		g.tutorial._goto(1)
		await _snap(out, "fine_1")
	print("TUT fine: round ", g.engine.round_n, " finale ", g.tutorial != null and g.tutorial._final, " risorse ", g.engine.ps[0]["res"])
	quit()
