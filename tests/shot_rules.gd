extends SceneTree
## Fotografie del libro delle regole. Uso: xvfb-run ... godot --path . -s tests/shot_rules.gd -- <cartella> <larghezza> <altezza>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var w := int(a[1])
	var h := int(a[2])
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	main.show_rules()
	await create_timer(0.5).timeout
	for i in [0, 1, 12, 17, 18]:
		main.current._show(i)
		await create_timer(0.3).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/regole_%02d.png" % [out, i])
	quit()
