extends Control
## Libro delle regole: indice dei capitoli a sinistra, testo a destra. Si apre dal menu e dalla partita.

const UI = preload("res://scripts/ui/ui.gd")
const RT = preload("res://scripts/ui/rules_text.gd")

var main
var on_close: Callable
var chapter := 0
var _rt: RichTextLabel
var _btns := []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.dark_style(10, 0.97))
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 30
	box.offset_bottom = -30
	add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var head := HBoxContainer.new()
	head.add_child(UI.title("Regole", 40))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UI.primary(UI.button("Chiudi" if on_close.is_valid() else "Torna al menu", 260, 56, 22))
	back.pressed.connect(_close)
	head.add_child(back)
	vb.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	# indice
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.x = 380
	body.add_child(sc)
	var idx := VBoxContainer.new()
	idx.add_theme_constant_override("separation", 6)
	idx.custom_minimum_size.x = 360
	sc.add_child(idx)
	for i in RT.CHAPTERS.size():
		var ii := i
		var b := UI.button(RT.chapter_title(i), 360, 44, 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.pressed.connect(func(): _show(ii))
		idx.add_child(b)
		_btns.append(b)
	# testo
	_rt = RichTextLabel.new()
	_rt.bbcode_enabled = true
	_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rt.add_theme_font_size_override("normal_font_size", 21)
	_rt.add_theme_font_size_override("bold_font_size", 21)
	_rt.add_theme_constant_override("line_separation", 4)
	body.add_child(_rt)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	var prev := UI.button("Capitolo precedente", 280, 50, 20)
	prev.pressed.connect(func(): _show(maxi(0, chapter - 1)))
	nav.add_child(prev)
	var next := UI.button("Capitolo seguente", 280, 50, 20)
	next.pressed.connect(func(): _show(mini(RT.CHAPTERS.size() - 1, chapter + 1)))
	nav.add_child(next)
	vb.add_child(nav)
	_show(chapter)
	_fit()
	get_viewport().size_changed.connect(_fit)


## Su schermi stretti (iPad in verticale) l'indice si restringe.
func _fit() -> void:
	if not is_inside_tree():
		return
	var w := get_viewport_rect().size.x
	var iw := 380.0 if w >= 1500 else 300.0
	for b in _btns:
		b.custom_minimum_size.x = iw - 20


func _show(i: int) -> void:
	chapter = i
	_rt.text = RT.chapter_text(i)
	_rt.scroll_to_line(0)
	for j in _btns.size():
		var b: Button = _btns[j]
		var st := UI._btn(UI.GOLD.darkened(0.55), UI.GOLD) if j == i else null
		if st != null:
			b.add_theme_stylebox_override("normal", st)
		else:
			b.remove_theme_stylebox_override("normal")


func _close() -> void:
	if on_close.is_valid():
		on_close.call()
		queue_free()
	else:
		main.show_menu()
