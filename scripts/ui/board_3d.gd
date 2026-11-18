extends Control
## Mappa 3D della galassia: le tessere settore originali su esagoni in rilievo, le navi con i modelli 3D
## del modulo (colorate per civiltà), dischi influenza, cubetti sui pianeti, orbitali, monoliti,
## Antichi, Guardiani e la Luna nera del Sistema di Difesa del Centro Galattico.
## Comandi: un dito o il tasto sinistro trascinano; due dita pizzicano per lo zoom e ruotano;
## il tasto destro (o due dita in verticale) inclina la vista; rotella per lo zoom.

const D = preload("res://scripts/data/ec_data.gd")
const POS = preload("res://scripts/data/ec_pos.gd")
const R := 1.0                    # raggio dell'esagono (centro-vertice)
const TOP := 0.06                 # altezza della tessera
const SQ3 := 1.7320508

signal hex_pressed(k: String)

var e
var hot := {}                     # chiave -> {col, label}
var sel := ""                     # esagono evidenziato (selezione corrente)
var preview := {}                 # settore appena esplorato da piazzare: {k, n, rot}
var svc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var tiles: Node3D
var pieces: Node3D
var marks: Node3D
var ship_nodes := {}              # id -> Node3D
var tile_nodes := {}              # chiave -> MeshInstance3D
var meshes := {}
var hex_mesh_cache := {}
var mat_cache := {}
var yaw := 0.0
var pitch := 1.0
var dist := 11.0
var target := Vector3.ZERO
var _touches := {}
var _pinch := {}
var _press := Vector2.ZERO
var _moved := false
var _t := 0.0
var viewer := -1


func setup(eng) -> void:
	e = eng
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.own_world_3d = true
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = _starfield()
	sky.sky_material = pm
	en.sky = sky
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color("#a8b8d8")
	en.ambient_light_energy = 0.42
	en.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = en
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#7fb0ff")
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.fov = 42
	cam.far = 400
	vp.add_child(cam)
	tiles = Node3D.new()
	vp.add_child(tiles)
	pieces = Node3D.new()
	vp.add_child(pieces)
	marks = Node3D.new()
	vp.add_child(marks)
	for k in ["intercettore", "incrociatore", "corazzata", "base_stellare", "sdcg", "disco"]:
		meshes[k] = load("res://assets/modelli/%s.obj" % k)
	_cam()
	refresh()


## Cielo: stelle e nebulose disegnate in un'immagine panoramica.
func _starfield() -> Texture2D:
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color("#02030a"))
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for neb in [[Vector2(0.3, 0.42), Color("#3b1850"), 260], [Vector2(0.72, 0.55), Color("#122e5c"), 300], [Vector2(0.52, 0.35), Color("#4a2410"), 160]]:
		var c: Vector2 = neb[0] * Vector2(w, h)
		var rad: int = neb[2]
		for y in range(maxi(0, int(c.y) - rad), mini(h, int(c.y) + rad)):
			for x in range(int(c.x) - rad * 2, int(c.x) + rad * 2):
				var xx := posmod(x, w)
				var dd := Vector2((x - c.x) * 0.5, y - c.y).length() / rad
				if dd < 1.0:
					var k := (1.0 - dd) * (1.0 - dd) * 0.6
					img.set_pixel(xx, y, img.get_pixel(xx, y).lerp(neb[1], k))
	for i in 5200:
		var x := r.randi_range(0, w - 1)
		var y := r.randi_range(0, h - 1)
		var b := r.randf_range(0.35, 1.0)
		var tint := Color(b, b, b).lerp(Color("#bcd2ff"), r.randf() * 0.4)
		img.set_pixel(x, y, tint)
		if r.randf() < 0.06 and x < w - 1 and y < h - 1:
			img.set_pixel(x + 1, y, tint * 0.7)
			img.set_pixel(x, y + 1, tint * 0.7)
	return ImageTexture.create_from_image(img)


func _cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


# ================================================================ geometria

func hex_center(pos: Vector2i) -> Vector3:
	return Vector3(R * 1.5 * pos.x, 0.0, R * SQ3 * (pos.y + pos.x * 0.5))


func world_to_hex(p: Vector3) -> Vector2i:
	var q := (2.0 / 3.0 * p.x) / R
	var rr := (-1.0 / 3.0 * p.x + SQ3 / 3.0 * p.z) / R
	var x := q
	var z := rr
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


func _corner(i: int, rad: float) -> Vector2:
	var a := deg_to_rad(60.0 * i)
	return Vector2(cos(a), sin(a)) * rad


## Punto dell'immagine della tessera (0-1) -> posizione locale (x, z), con la rotazione della tessera.
func img_to_local(uv: Vector2, rot: int) -> Vector3:
	var x := (uv.x - 0.5) * 2.0 * R
	var z := (uv.y - 0.5) / 0.469 * (0.866 * R)
	var a := deg_to_rad(60.0 * rot)
	var xr := x * cos(a) - z * sin(a)
	var zr := x * sin(a) + z * cos(a)
	return Vector3(xr, TOP, zr)


## Prisma esagonale con la faccia superiore mappata sull'immagine (ruotata di rot passi).
func _hex_mesh(rot: int) -> ArrayMesh:
	if hex_mesh_cache.has(rot):
		return hex_mesh_cache[rot]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := deg_to_rad(-60.0 * rot)
	var uvf := func(x: float, z: float) -> Vector2:
		var xr := x * cos(a) - z * sin(a)
		var zr := x * sin(a) + z * cos(a)
		return Vector2(0.5 + xr / (2.0 * R), 0.5 + zr / (0.866 * R) * 0.469)
	for i in 6:
		var c0 := _corner(i, R * 0.985)
		var c1 := _corner(i + 1, R * 0.985)
		st.set_normal(Vector3.UP)
		st.set_uv(uvf.call(0.0, 0.0))
		st.add_vertex(Vector3(0, TOP, 0))
		st.set_uv(uvf.call(c0.x, c0.y))
		st.add_vertex(Vector3(c0.x, TOP, c0.y))
		st.set_uv(uvf.call(c1.x, c1.y))
		st.add_vertex(Vector3(c1.x, TOP, c1.y))
	var top := st.commit()
	# fianchi in una seconda superficie
	var s2 := SurfaceTool.new()
	s2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var c0 := _corner(i, R * 0.985)
		var c1 := _corner(i + 1, R * 0.985)
		var nrm := Vector3((c0.x + c1.x) * 0.5, 0, (c0.y + c1.y) * 0.5).normalized()
		for v in [Vector3(c0.x, TOP, c0.y), Vector3(c1.x, 0, c1.y), Vector3(c1.x, TOP, c1.y), Vector3(c0.x, TOP, c0.y), Vector3(c0.x, 0, c0.y), Vector3(c1.x, 0, c1.y)]:
			s2.set_normal(nrm)
			s2.set_uv(Vector2.ZERO)
			s2.add_vertex(v)
	s2.commit(top)
	hex_mesh_cache[rot] = top
	return top


func _ring_mesh(r_out: float, r_in: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var o0 := _corner(i, r_out)
		var o1 := _corner(i + 1, r_out)
		var i0 := _corner(i, r_in)
		var i1 := _corner(i + 1, r_in)
		for v in [o0, o1, i1, o0, i1, i0]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, y, v.y))
	return st.commit()


func _fill_mesh(rad: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var c0 := _corner(i, rad)
		var c1 := _corner(i + 1, rad)
		for v in [Vector2.ZERO, c1, c0]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, y, v.y))
	return st.commit()


func _mat(key: String, col: Color, metal := 0.5, rough := 0.45, emit := Color.BLACK) -> StandardMaterial3D:
	var k := "%s_%s" % [key, col.to_html()]
	if mat_cache.has(k):
		return mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = 1.2
	mat_cache[k] = m
	return m


func _unshaded(col: Color) -> StandardMaterial3D:
	var k := "u_" + col.to_html()
	if mat_cache.has(k):
		return mat_cache[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cache[k] = m
	return m


## Istanza di un modello, centrata e scalata alla lunghezza data.
func _model(key: String, length: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m: Mesh = meshes[key]
	mi.mesh = m
	var ab := m.get_aabb()
	var ext := maxf(ab.size.x, ab.size.z)
	var k := length / maxf(ext, 0.001)
	mi.scale = Vector3(k, k, k)
	mi.position = -Vector3(ab.get_center().x, ab.position.y, ab.get_center().z) * k
	mi.material_override = mat
	var holder := Node3D.new()
	holder.add_child(mi)
	return mi


# ================================================================ aggiornamento

func refresh() -> void:
	if e == null:
		return
	# tessere
	for k in e.hexes:
		var hx: Dictionary = e.hexes[k]
		if not tile_nodes.has(k):
			var mi := MeshInstance3D.new()
			mi.mesh = _hex_mesh(int(hx["rot"]))
			var m := StandardMaterial3D.new()
			m.albedo_texture = UI.sector_tex(int(hx["n"]))
			m.roughness = 1.0
			m.metallic_specular = 0.08
			var side := _mat("side", Color("#1a2236"), 0.3, 0.7)
			mi.set_surface_override_material(0, m)
			mi.set_surface_override_material(1, side)
			mi.position = hex_center(hx["pos"])
			tiles.add_child(mi)
			tile_nodes[k] = mi
			# comparsa
			mi.scale = Vector3(0.2, 1, 0.2)
			var tw := create_tween()
			tw.tween_property(mi, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in tile_nodes.keys():
		if e.hexes.has(k) and e.hexes[k].get("exploded", false) and not tile_nodes[k].has_meta("exploded"):
			tile_nodes[k].set_meta("exploded", true)
			var mx := StandardMaterial3D.new()
			mx.albedo_texture = UI.tex("res://assets/settori/%d_esplosa.jpg" % int(e.hexes[k]["n"]))
			tile_nodes[k].set_surface_override_material(0, mx)
		if not e.hexes.has(k):
			tile_nodes[k].queue_free()
			tile_nodes.erase(k)
	_refresh_pieces()
	_refresh_marks()


func _refresh_pieces() -> void:
	for c in pieces.get_children():
		if not c.has_meta("ship"):
			c.queue_free()
	var alive := {}
	for k in e.hexes:
		var hx: Dictionary = e.hexes[k]
		var base := hex_center(hx["pos"])
		var rot: int = int(hx["rot"])
		# disco influenza (sul cerchio centrale della tessera)
		if int(hx["owner"]) >= 0:
			var d := _model("disco", 0.21, _mat("disc", UI.pcolor(e, int(hx["owner"])), 0.2, 0.5))
			var n3 := Node3D.new()
			n3.position = base + img_to_local(Vector2(0.5, 0.5), rot) + Vector3(0, 0.005, 0)
			_add_holder(n3, d)
		# cubetti sui pianeti
		var pl: Array = e.sector(hx)["pl"]
		var pos: Array = POS.POS.get(int(hx["n"]), [])
		for i in hx["cubes"].size():
			if hx["cubes"][i] == "" or i >= pos.size():
				continue
			var cube := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.085, 0.085, 0.085)
			cube.mesh = bm
			cube.material_override = _mat("cube", UI.pcolor(e, int(hx["owner"])), 0.1, 0.55)
			cube.position = base + img_to_local(pos[i], rot) + Vector3(0, 0.045, 0)
			pieces.add_child(cube)
		# santuari di Lyra (accanto ai pianeti)
		for j in hx.get("shrines", []):
			if j >= pos.size():
				continue
			var sh := MeshInstance3D.new()
			var sm := PrismMesh.new()
			sm.size = Vector3(0.08, 0.12, 0.08)
			sh.mesh = sm
			sh.material_override = _mat("shrine", Color("#f2d27e"), 0.8, 0.3, Color("#f2a93b") * 0.4)
			sh.position = base + img_to_local(pos[j], rot) + Vector3(0.07, 0.06, -0.05)
			pieces.add_child(sh)
		# orbitale e monolito
		if hx["orb"]:
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.07
			tm.outer_radius = 0.11
			tor.mesh = tm
			tor.material_override = _mat("orb", Color("#c9d3e2"), 0.8, 0.3, Color("#2a6f9a"))
			tor.position = base + img_to_local(Vector2(0.5, 0.82), rot) + Vector3(0, 0.03, 0)
			pieces.add_child(tor)
			if hx["orb_cube"] != "":
				var oc := MeshInstance3D.new()
				var ob := BoxMesh.new()
				ob.size = Vector3(0.07, 0.07, 0.07)
				oc.mesh = ob
				oc.material_override = _mat("cube", UI.pcolor(e, int(hx["owner"])), 0.1, 0.55)
				oc.position = tor.position + Vector3(0, 0.05, 0)
				pieces.add_child(oc)
		if hx["mono"]:
			var mono := MeshInstance3D.new()
			var mb := BoxMesh.new()
			mb.size = Vector3(0.07, 0.34, 0.13)
			mono.mesh = mb
			mono.material_override = _mat("mono", Color("#15151a"), 0.9, 0.2, Color("#f2a93b") * 0.25)
			mono.position = base + img_to_local(Vector2(0.28, 0.5), rot) + Vector3(0, 0.17, 0)
			pieces.add_child(mono)
		# portali
		if int(hx["warp_tile"]) >= 0 or hx["anc_portal"]:
			var ring := MeshInstance3D.new()
			var rm := TorusMesh.new()
			rm.inner_radius = 0.16
			rm.outer_radius = 0.19
			ring.mesh = rm
			ring.material_override = _mat("warp", Color("#b07cff"), 0.2, 0.3, Color("#b07cff"))
			ring.position = base + img_to_local(Vector2(0.22, 0.28), rot) + Vector3(0, 0.02, 0)
			pieces.add_child(ring)
		# tessera scoperta
		if not hx["disc"].is_empty():
			var dt := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.12
			cyl.height = 0.02
			cyl.radial_segments = 6
			dt.mesh = cyl
			var dm := StandardMaterial3D.new()
			dm.albedo_texture = UI.tex("res://assets/scoperte/retro.jpg")
			dt.material_override = dm
			dt.position = base + img_to_local(Vector2(0.5, 0.5), rot) + Vector3(0, 0.012, 0)
			pieces.add_child(dt)
		# navi neutrali
		var nn: int = hx["npc"].size()
		for i in nn:
			var npc: Dictionary = hx["npc"][i]
			var mi: MeshInstance3D
			match str(npc["k"]):
				"anc":
					mi = _model("incrociatore", 0.42, _mat("anc", Color("#4b5a4a"), 0.7, 0.35, Color("#38ffb0") * 0.35))
				"gua":
					mi = _model("corazzata", 0.5, _mat("gua", Color("#7d8596"), 0.8, 0.3, Color("#ff9a3c") * 0.25))
				_:
					mi = _model("sdcg", 0.62, _mat("gcds", Color("#9aa2ad"), 0.85, 0.35, Color("#ff4030") * 0.3))
			var h3 := Node3D.new()
			var off := Vector3(0, 0, 0)
			if nn > 1:
				off = Vector3(cos(TAU * i / nn), 0, sin(TAU * i / nn)) * 0.28
			h3.position = base + Vector3(0, TOP + 0.08, 0) + off
			h3.rotation.y = PI * 0.25
			_add_holder(h3, mi)
			if int(npc["dmg"]) > 0:
				_damage_marks(h3, int(npc["dmg"]))
	# navi dei giocatori: restano e si spostano con un'animazione
	var groups := {}
	for s in e.ships:
		var key: String = "%s|%d" % [s["h"], int(s["p"])]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(s)
	for key in groups:
		var parts: PackedStringArray = key.split("|")
		var hk: String = parts[0]
		var p := int(parts[1])
		var hx: Dictionary = e.hexes.get(hk, {})
		if hx.is_empty():
			continue
		var owners: Array = e.owners_in(hk)
		var oi := owners.find(p)
		var no := owners.size()
		var base := hex_center(hx["pos"])
		var ang := TAU * oi / maxf(no, 1) + PI * 0.15
		var center := base + Vector3(cos(ang), 0, sin(ang)) * (0.42 if no > 1 or not hx["npc"].is_empty() else 0.36)
		var list: Array = groups[key]
		list.sort_custom(func(a, b): return D.SHIP_SIZE[a["t"]] > D.SHIP_SIZE[b["t"]])
		for i in list.size():
			var s: Dictionary = list[i]
			var id: int = int(s["id"])
			alive[id] = true
			var col := i % 3
			var row := int(i / 3)
			var spot := center + Vector3((col - 1) * 0.26, TOP + 0.1, (row - 0.5) * 0.24 * (1 if list.size() > 3 else 0))
			if not ship_nodes.has(id):
				var len: float = {"int": 0.3, "cru": 0.4, "dre": 0.5, "sb": 0.38}[s["t"]]
				var mesh_key: String = {"int": "intercettore", "cru": "incrociatore", "dre": "corazzata", "sb": "base_stellare"}[s["t"]]
				var mi := _model(mesh_key, len, _mat("ship", UI.pcolor(e, p), 0.55, 0.38))
				var h3 := Node3D.new()
				h3.set_meta("ship", id)
				h3.position = spot
				h3.rotation.y = -ang + PI * 0.5
				_add_holder(h3, mi)
				ship_nodes[id] = h3
				h3.scale = Vector3(0.1, 0.1, 0.1)
				var tw := create_tween()
				tw.tween_property(h3, "scale", Vector3.ONE, 0.3)
			else:
				var h3: Node3D = ship_nodes[id]
				if h3.position.distance_to(spot) > 0.02:
					var tw := create_tween()
					var mid := (h3.position + spot) * 0.5 + Vector3(0, 0.6, 0)
					tw.tween_property(h3, "position", mid, 0.22)
					tw.tween_property(h3, "position", spot, 0.22)
			var node: Node3D = ship_nodes[id]
			for c in node.get_children():
				if c.has_meta("dmg"):
					c.queue_free()
			if int(s["dmg"]) > 0:
				_damage_marks(node, int(s["dmg"]))
	for id in ship_nodes.keys():
		if not alive.has(id):
			var n3: Node3D = ship_nodes[id]
			ship_nodes.erase(id)
			var tw := create_tween()
			tw.tween_property(n3, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
			tw.tween_callback(n3.queue_free)


func _add_holder(h3: Node3D, mi: MeshInstance3D) -> void:
	if mi.get_parent() != null:
		var holder := mi.get_parent()
		holder.remove_child(mi)
		holder.queue_free()
	h3.add_child(mi)
	if h3.get_parent() == null:
		pieces.add_child(h3)


func _damage_marks(node: Node3D, dmg: int) -> void:
	for j in mini(dmg, 6):
		var c := MeshInstance3D.new()
		c.set_meta("dmg", true)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.04, 0.04)
		c.mesh = bm
		c.material_override = _mat("dmgc", Color("#a040ff"), 0.1, 0.4, Color("#a040ff"))
		c.position = Vector3(-0.12 + j * 0.05, 0.16, 0)
		node.add_child(c)


func _refresh_marks() -> void:
	for c in marks.get_children():
		c.queue_free()
	for k in hot:
		var h: Dictionary = hot[k]
		var pos := D.unkey(k)
		var col: Color = h.get("col", UI.GOLD_L)
		var base := hex_center(pos)
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(R * 0.98, R * 0.88, TOP + 0.012)
		ring.material_override = _unshaded(Color(col, 0.95))
		ring.position = base
		ring.set_meta("pulse", true)
		marks.add_child(ring)
		if not e.hexes.has(k):
			var f := MeshInstance3D.new()
			f.mesh = _fill_mesh(R * 0.95, 0.005)
			f.material_override = _unshaded(Color(col, 0.18))
			f.position = base
			marks.add_child(f)
		if str(h.get("label", "")) != "":
			var lb := Label3D.new()
			lb.text = h["label"]
			lb.font = UI.font_head
			lb.font_size = 64
			lb.pixel_size = 0.004
			lb.outline_size = 14
			lb.modulate = col
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.position = base + Vector3(0, 0.55, 0)
			marks.add_child(lb)
	if not preview.is_empty():
		var pm := MeshInstance3D.new()
		pm.mesh = _hex_mesh(int(preview["rot"]))
		var m := StandardMaterial3D.new()
		m.albedo_texture = UI.sector_tex(int(preview["n"]))
		m.emission_enabled = true
		m.emission = Color(0.12, 0.12, 0.16)
		pm.set_surface_override_material(0, m)
		pm.set_surface_override_material(1, _mat("side", Color("#1a2236"), 0.3, 0.7))
		pm.position = hex_center(D.unkey(preview["k"])) + Vector3(0, 0.25, 0)
		marks.add_child(pm)
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(R * 1.0, R * 0.9, TOP + 0.26)
		ring.material_override = _unshaded(Color(UI.GOLD_L, 0.95))
		ring.position = hex_center(D.unkey(preview["k"]))
		ring.set_meta("pulse", true)
		marks.add_child(ring)
	if sel != "" and not hot.has(sel):
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(R * 0.99, R * 0.93, TOP + 0.014)
		ring.material_override = _unshaded(Color(UI.LINE, 0.9))
		ring.position = hex_center(D.unkey(sel))
		marks.add_child(ring)


func _process(dt: float) -> void:
	_t += dt
	var a := 0.55 + 0.45 * sin(_t * 4.0)
	for c in marks.get_children():
		if c.has_meta("pulse") and c is MeshInstance3D:
			c.transparency = 1.0 - a


## Inquadra tutta la galassia esplorata.
func fit() -> void:
	var mx := 2.0
	for k in e.hexes:
		mx = maxf(mx, hex_center(e.hexes[k]["pos"]).length() + R)
	for k in hot:
		mx = maxf(mx, hex_center(D.unkey(k)).length() + R)
	target = Vector3.ZERO
	var aspect := size.x / maxf(size.y, 1.0)
	dist = clampf(mx * (2.4 if aspect > 1.2 else 3.1), 5.0, 32.0)
	pitch = 1.0
	_cam()


func focus_hex(k: String) -> void:
	if k == "":
		return
	var tw := create_tween()
	tw.tween_method(func(v: Vector3):
		target = v
		_cam(), target, hex_center(D.unkey(k)), 0.35)


# ================================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			_press = ev.position
			_moved = false
		else:
			var tap: bool = _touches.size() == 1 and not _moved
			_touches.erase(ev.index)
			_pinch = {}
			if tap:
				_click(ev.position)
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if ev.position.distance_to(_press) > 10:
			_moved = true
		if _touches.size() == 1:
			_pan(ev.relative)
		elif _touches.size() >= 2:
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			var mid := (a + b) * 0.5
			if not _pinch.is_empty():
				dist = clampf(dist * _pinch["d"] / maxf(1.0, d), 2.0, 40.0)
				yaw -= ang - _pinch["ang"]
				pitch = clampf(pitch + (mid.y - _pinch["mid"].y) * 0.004, 0.3, 1.5)
				_cam()
			_pinch = {"d": d, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 2.0, 40.0)
		_cam()
		accept_event()
		return
	if ev is InputEventPanGesture:
		_pan(-ev.delta * 10.0)
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, 2.0, 40.0)
			_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist / 0.9, 2.0, 40.0)
			_cam()
		elif ev.pressed:
			_press = ev.position
			_moved = false
		elif ev.button_index == MOUSE_BUTTON_LEFT and not _moved and _touches.is_empty():
			_click(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.position.distance_to(_press) > 6:
			_moved = true
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= ev.relative.x * 0.006
			pitch = clampf(pitch + ev.relative.y * 0.004, 0.3, 1.5)
			_cam()
		else:
			_pan(ev.relative)
		accept_event()


func _pan(rel: Vector2) -> void:
	var k := dist * 0.0012
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	target += (-right * rel.x + fwd * rel.y) * k
	target.x = clampf(target.x, -12.0, 12.0)
	target.z = clampf(target.z, -12.0, 12.0)
	_cam()


func _click(s: Vector2) -> void:
	var sc := s * Vector2(vp.size) / size
	var o := cam.project_ray_origin(sc)
	var dir := cam.project_ray_normal(sc)
	if absf(dir.y) < 0.0001:
		return
	var t := (TOP - o.y) / dir.y
	var hit := o + dir * t
	var h := world_to_hex(hit)
	hex_pressed.emit(D.key(h))


## Posizione sullo schermo (coordinate di questo controllo) di un esagono.
func screen_pos(k: String) -> Vector2:
	var w := hex_center(D.unkey(k)) + Vector3(0, TOP, 0)
	if cam.is_position_behind(w):
		return Vector2(-999, -999)
	return cam.unproject_position(w) * size / Vector2(vp.size)
