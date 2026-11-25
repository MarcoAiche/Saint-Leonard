class_name FigureEditor
extends Control
## Figur-Editor (Kleiderschrank): links die Kategorien, daneben die Varianten und Farben der
## gewählten Kategorie, rechts unten "Fertig" und "Abbrechen". Die Figur selbst zeigt der Aufrufer
## in 3D (Menü: Standspiegel, im Spiel: Kamera vor der Spielfigur). Ziehen mit der Maus dreht sie.
## Gesperrte Teile zeigen, wie man sie bekommt (Bauhaus, Supermarkt, Werkbank).

signal changed(outfit: Dictionary)  # nach jeder Änderung (Vorschau neu bauen)
signal finished(outfit: Dictionary, accepted: bool)
signal rotate(delta_yaw: float)

var outfit := {}
var _original := {}
var _category := "body"
var _tabs: VBoxContainer
var _detail: VBoxContainer
var _detail_title: Label
var _dragging := false


func open(o: Dictionary) -> void:
	outfit = Outfit.normalize(o)
	_original = outfit.duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var root := HBoxContainer.new()
	root.position = Vector2(28, 28)
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	# Kategorien
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	root.add_child(_tabs)
	var head := MenuStyle.label("Figur", 34, MenuStyle.GOLD)
	_tabs.add_child(head)
	for cat in Outfit.CATEGORIES:
		var b := Button.new()
		b.text = "  ●  " + cat.name
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(190, 50)
		b.add_theme_font_size_override("font_size", 24)
		b.toggle_mode = true
		b.button_pressed = cat.id == _category
		var id: String = cat.id
		b.pressed.connect(func(): _select(id))
		b.set_meta("cat", id)
		_tabs.add_child(b)
	var sp := Control.new()
	sp.custom_minimum_size.y = 18
	_tabs.add_child(sp)
	var rnd := Button.new()
	rnd.text = "Zufällig"
	rnd.pressed.connect(_randomize)
	_tabs.add_child(rnd)
	var reset := Button.new()
	reset.text = "Standard"
	reset.pressed.connect(func():
		outfit = Outfit.normalize(Outfit.preset_look(str(outfit.get("preset", "overalls"))))
		_emit())
	_tabs.add_child(reset)
	# Details der Kategorie
	var panel := MenuStyle.panel(370)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	panel.add_child(_detail)
	_fill_detail()
	# Fertig / Abbrechen rechts unten
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.anchor_left = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_right = -32
	bottom.offset_bottom = -32
	add_child(bottom)
	var cancel := MenuStyle.big_button("✕  Abbrechen", MenuStyle.RED, 22)
	cancel.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -6.0)
		finished.emit(_original, false))
	bottom.add_child(cancel)
	var ok := MenuStyle.big_button("✓  Fertig", MenuStyle.GREEN, 36)
	ok.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -4.0)
		finished.emit(outfit, true))
	bottom.add_child(ok)
	var hint := MenuStyle.label("Ziehen mit der Maus dreht die Figur", 15, MenuStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.3
	hint.anchor_right = 0.7
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -44
	add_child(hint)


func _select(id: String) -> void:
	_category = id
	for b in _tabs.get_children():
		if b is Button and b.has_meta("cat"):
			(b as Button).button_pressed = b.get_meta("cat") == id
	Sfx.play_2d(self, Sfx.click(), -8.0)
	_fill_detail()


func _fill_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var cat: Dictionary = {}
	for c in Outfit.CATEGORIES:
		if c.id == _category:
			cat = c
	_detail.add_child(MenuStyle.label(cat.name, 30, MenuStyle.GOLD))
	if cat.key == "preset":
		_detail.add_child(MenuStyle.label("Vorlage (setzt Farben, Hut, Frisur und Figur)", 15, MenuStyle.MUTED))
	_style_list(cat.key, Outfit.STYLES[cat.key])
	for sl in cat.get("sliders", []):
		_slider(sl[0], sl[1])
	if cat.has("extra"):
		_detail.add_child(MenuStyle.label("Brille", 20))
		_style_list(cat.extra, Outfit.STYLES[cat.extra])
	for ck in cat.colors:
		_detail.add_child(MenuStyle.label(Outfit.COLOR_NAMES.get(ck, ck), 20))
		_swatches(ck)


## Varianten als Liste: gewählte hervorgehoben, gesperrte mit Schloss und Hinweis
func _style_list(key: String, styles: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_detail.add_child(box)
	for s in styles:
		var b := Button.new()
		var ok := Outfit.unlocked(key, s.id)
		var current: bool = str(outfit.get(key, "")) == s.id
		b.text = ("✓  " if current else "     ") + s.name + ("   (gesperrt)" if not ok else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.x = 340
		b.toggle_mode = true
		b.button_pressed = current
		b.disabled = not ok
		if not ok:
			b.tooltip_text = Outfit.unlock_hint(key, s.id)
		var id: String = s.id
		b.pressed.connect(func():
			if key == "preset":
				outfit.merge(Outfit.preset_look(id), true)
			else:
				outfit[key] = id
			Sfx.play_2d(self, Sfx.click(), -8.0)
			_emit())
		box.add_child(b)
		if not ok:
			var h := MenuStyle.label("      " + Outfit.unlock_hint(key, s.id), 13, MenuStyle.MUTED)
			box.add_child(h)


func _swatches(key: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_detail.add_child(grid)
	for col in Outfit.PALETTES[key]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 34)
		var cur: Color = outfit.get(key, Color.WHITE)
		var sel := cur.is_equal_approx(col)
		var st := MenuStyle.box(col, 8, 3 if sel else 1, MenuStyle.GOLD if sel else Color(0, 0, 0, 0.5))
		st.set_content_margin_all(0)
		for k in ["normal", "hover", "pressed", "focus"]:
			var s2 := st.duplicate() as StyleBoxFlat
			if k == "hover":
				s2.border_color = Color(1, 1, 1)
				s2.set_border_width_all(3)
			b.add_theme_stylebox_override(k, s2)
		var c2: Color = col
		b.pressed.connect(func():
			outfit[key] = c2
			Sfx.play_2d(self, Sfx.click(), -10.0)
			_emit())
		grid.add_child(b)


## Regler (Bauch, Stirn) von 0 bis 1
func _slider(key: String, label: String) -> void:
	var h := HBoxContainer.new()
	_detail.add_child(h)
	var l := MenuStyle.label(label, 20)
	l.custom_minimum_size.x = 90
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(outfit.get(key, 0.5))
	sl.custom_minimum_size = Vector2(240, 30)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# nur Vorschau beim Ziehen, Liste erst beim Loslassen neu aufbauen
	sl.value_changed.connect(func(v):
		outfit[key] = v
		changed.emit(outfit))
	h.add_child(sl)


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	outfit.gut_belly = snappedf(rng.randf(), 0.05)
	outfit.forehead = snappedf(rng.randf(), 0.05)
	for key in Outfit.STYLES:
		if key == "preset":
			continue
		var opts: Array = Outfit.STYLES[key].filter(func(s): return Outfit.unlocked(key, s.id))
		outfit[key] = opts[rng.randi() % opts.size()].id
	for key in Outfit.PALETTES:
		var pal: Array = Outfit.PALETTES[key]
		outfit[key] = pal[rng.randi() % pal.size()]
	_emit()


func _emit() -> void:
	changed.emit(outfit)
	_fill_detail()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
	elif e is InputEventMouseMotion and _dragging:
		rotate.emit(e.relative.x * 0.012)
