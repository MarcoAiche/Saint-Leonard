class_name MainMenu
extends CanvasLayer
## Hauptmenü mit Seiten: Start (Weiterspielen), Spielstände (laden, löschen, neu), Mehrspieler,
## Figur, Einstellungen.

signal start(mode: String, address: String, slot: String, new_game: bool)
signal quit

var _root: Control
var _box: PanelContainer
var _body: VBoxContainer
var _status: Label
var _name := ""
var _ip := "127.0.0.1"


func _ready() -> void:
	layer = 10
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.06, 0.09, 0.08, 0.55)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Hud.make_theme()
	add_child(_root)
	_name = _load_name()
	var f := FileAccess.open("user://server_address.txt", FileAccess.READ)
	if f:
		_ip = f.get_as_text().strip_edges()
	page_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _page(title: String, width := 480.0) -> VBoxContainer:
	if _box:
		_box.queue_free()
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", Hud._style(Hud.PAPER))
	_box.custom_minimum_size = Vector2(width, 0)
	_root.add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_box.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 44 if title == "Saint Leonard" else 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	_body = vb
	_status = Label.new()
	_status.add_theme_color_override("font_color", Hud.RED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Hud._anchor(_box, Control.PRESET_CENTER, 0)
	return vb


func _finish_page() -> void:
	_body.add_child(_status)
	Hud._anchor(_box, Control.PRESET_CENTER, 0)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _name_row(parent: Control) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = "Name"
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var e := LineEdit.new()
	e.text = _name
	e.placeholder_text = "Dein Name"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t): _name = t.strip_edges())
	h.add_child(e)


# ------------------------------------------------------------------ Seiten

func page_home() -> void:
	var vb := _page("REDNECK REDEMPTION")
	var sub := Label.new()
	sub.text = "Jagen, Brennen, Offroad. Ein Dorf in Kärnten."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	vb.add_child(sub)
	_name_row(vb)
	var saves := GameState.list_saves()
	if not saves.is_empty():
		var last: Dictionary = saves[0]
		_button(vb, "Weiterspielen: %s (Tag %d, $%d)" % [last.title, last.day, last.money], func(): _go("single", "", last.slot, false))
	_button(vb, "Neues Spiel", func(): page_new())
	_button(vb, "Spielstände (%d)" % saves.size(), func(): page_saves(), not saves.is_empty())
	_button(vb, "Mehrspieler", func(): page_multi())
	_button(vb, "Figur anpassen", func(): page_figure())
	_button(vb, "Einstellungen", func(): page_settings())
	_button(vb, "Beenden", func(): quit.emit())
	var note := Label.new()
	note.text = "Kartendaten © OpenStreetMap-Mitwirkende (ODbL)"
	note.add_theme_font_size_override("font_size", 12)
	vb.add_child(note)
	_finish_page()


func page_new() -> void:
	var vb := _page("Neues Spiel")
	_name_row(vb)
	var h := HBoxContainer.new()
	vb.add_child(h)
	var l := Label.new()
	l.text = "Spielstand"
	l.custom_minimum_size.x = 100
	h.add_child(l)
	var e := LineEdit.new()
	e.text = "Mein Saint Leonard"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(e)
	_button(vb, "Los geht's", func():
		var title := e.text.strip_edges()
		if title.is_empty():
			title = "Spielstand"
		GameState.slot_title = title
		_go("single", "", GameState.new_slot_name(title), true))
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func page_saves() -> void:
	var vb := _page("Spielstände", 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for sv in GameState.list_saves():
		var row := HBoxContainer.new()
		list.add_child(row)
		var info := Label.new()
		info.text = "%s\n%s, Tag %d, $%d, Kapitel %d   (%s)" % [sv.title, sv.player, sv.day, sv.money, min(sv.chapter, 3), sv.saved.replace("T", " ").left(16)]
		info.add_theme_font_size_override("font_size", 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_button(row, "Laden", func(): _go("single", "", sv.slot, false))
		_button(row, "Löschen", func():
			_confirm("Spielstand \"%s\" wirklich löschen? Das kann nicht rückgängig gemacht werden." % sv.title, func():
				GameState.delete_save(sv.slot)
				page_saves()))
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func _confirm(text: String, yes: Callable) -> void:
	var vb := _page("Sicher?")
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	vb.add_child(l)
	_button(vb, "Ja, löschen", yes)
	_button(vb, "Nein", func(): page_saves())
	_finish_page()


func page_multi() -> void:
	var vb := _page("Mehrspieler", 520)
	_name_row(vb)
	var info := Label.new()
	info.text = "Alle spielen auf einem gemeinsamen Server. Die Welt läuft dort weiter, auch wenn niemand online ist, und der Server speichert den Fortschritt jedes Spielers unter seinem Namen."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 480
	info.add_theme_font_size_override("font_size", 14)
	vb.add_child(info)
	var h := HBoxContainer.new()
	vb.add_child(h)
	var l := Label.new()
	l.text = "Server"
	l.custom_minimum_size.x = 90
	h.add_child(l)
	var ip := LineEdit.new()
	ip.text = _ip
	ip.placeholder_text = "Adresse oder Adresse:Port"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.text_changed.connect(func(t): _ip = t.strip_edges())
	h.add_child(ip)
	var h2 := HBoxContainer.new()
	vb.add_child(h2)
	var l2 := Label.new()
	l2.text = "Passwort"
	l2.custom_minimum_size.x = 90
	h2.add_child(l2)
	var pw := LineEdit.new()
	pw.secret = true
	pw.placeholder_text = "falls der Server eines hat"
	pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_child(pw)
	_button(vb, "Verbinden", func():
		Net.join_password = pw.text
		_save_ip()
		_go("client", _ip, "", false))
	_button(vb, "Server auf diesem PC starten und verbinden", func():
		Net.join_password = ""
		_go("localserver", "127.0.0.1", "", false))
	var hint := Label.new()
	hint.text = "Ein Server auf diesem PC läuft im Hintergrund weiter, bis du ihn im Task-Manager beendest (Godot ohne Fenster). Freunde verbinden sich mit deiner IP, z. B. über ZeroTier, Port 24680 (UDP)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 480
	hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(hint)
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func _save_ip() -> void:
	var f := FileAccess.open("user://server_address.txt", FileAccess.WRITE)
	if f:
		f.store_string(_ip)


func page_figure() -> void:
	var vb := _page("CHARACTER", 760)
	var draft: Dictionary = GameState.outfit.duplicate(true)
	var dirty := false
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vb.add_child(hbox)

	# Isolierte 3D-Charaktervorschau im eigenen SubViewport
	var preview_wrap := VBoxContainer.new()
	hbox.add_child(preview_wrap)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(280, 340)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_wrap.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.world_3d = World3D.new()
	sv.transparent_bg = true
	sv.size = Vector2i(280, 340)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.92, 0.86)
	e.ambient_light_energy = 0.9
	env.environment = e
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.12, 2.35)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	cam.fov = 40.0
	sv.add_child(cam)
	var char_holder := Node3D.new()
	sv.add_child(char_holder)
	var drag_lbl := Label.new()
	drag_lbl.text = "DRAG TO TURN"
	drag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_lbl.add_theme_font_size_override("font_size", 12)
	preview_wrap.add_child(drag_lbl)

	var dragging := [false]
	svc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			dragging[0] = ev.pressed
		elif ev is InputEventMouseMotion and dragging[0]:
			char_holder.rotate_y(ev.relative.x * 0.012))

	var ctrl := VBoxContainer.new()
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.add_theme_constant_override("separation", 10)
	hbox.add_child(ctrl)

	var unsaved_lbl := Label.new()
	unsaved_lbl.text = "UNSAVED CHANGES"
	unsaved_lbl.add_theme_color_override("font_color", Color(0.82, 0.22, 0.12))
	unsaved_lbl.add_theme_font_size_override("font_size", 13)
	unsaved_lbl.visible = false
	ctrl.add_child(unsaved_lbl)

	var rebuild_preview := func():
		for c in char_holder.get_children():
			c.queue_free()
		var m := CharacterModel.new(draft, 2)
		char_holder.add_child(m)
		unsaved_lbl.visible = dirty
	rebuild_preview.call()

	var gr := HBoxContainer.new()
	ctrl.add_child(gr)
	var g_lbl := Label.new()
	g_lbl.text = "Geschlecht: %s" % ("Mann" if draft.get("gender", "male") == "male" else "Frau")
	_button(gr, "Mann", func():
		draft.gender = "male"
		dirty = true
		g_lbl.text = "Geschlecht: Mann"
		rebuild_preview.call())
	_button(gr, "Frau", func():
		draft.gender = "female"
		dirty = true
		g_lbl.text = "Geschlecht: Frau"
		rebuild_preview.call())
	gr.add_child(g_lbl)

	var jh := HBoxContainer.new()
	ctrl.add_child(jh)
	var current := Label.new()
	current.text = "Hut: %s" % ("Jagdhut" if draft.get("hat", "hunter") in ["hunter", "hunter_gams", "cap", "floppy"] else "Kein Hut")
	_button(jh, "Mit Jagdhut", func():
		draft.hat = "hunter"
		dirty = true
		current.text = "Hut: Jagdhut"
		rebuild_preview.call())
	_button(jh, "Ohne Hut", func():
		draft.hat = "none"
		dirty = true
		current.text = "Hut: Kein Hut"
		rebuild_preview.call())
	jh.add_child(current)

	var add_slider := func(title: String, key: String, init_val: float) -> HSlider:
		var r := HBoxContainer.new()
		ctrl.add_child(r)
		var l := Label.new()
		l.text = title
		l.custom_minimum_size.x = 120
		r.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = init_val
		sl.custom_minimum_size = Vector2(180, 22)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(sl)
		var vl := Label.new()
		vl.text = "%.2f" % init_val
		vl.custom_minimum_size.x = 48
		r.add_child(vl)
		sl.value_changed.connect(func(val: float):
			draft[key] = val
			dirty = true
			vl.text = "%.2f" % val
			rebuild_preview.call())
		return sl

	var gut_sl: HSlider = add_slider.call("Gut Belly", "gut_belly", float(draft.get("gut_belly", 0.55)))
	var fh_sl: HSlider = add_slider.call("Forehead", "forehead", float(draft.get("forehead", 0.45)))

	var act := HBoxContainer.new()
	ctrl.add_child(act)
	_button(act, "RANDOMISE", func():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		draft.gender = "male" if rng.randf() > 0.35 else "female"
		draft.hat = ["hunter", "floppy", "none"][rng.randi_range(0, 2)]
		draft.gut_belly = snappedf(rng.randf_range(0.1, 0.95), 0.05)
		draft.forehead = snappedf(rng.randf_range(0.15, 0.9), 0.05)
		dirty = true
		g_lbl.text = "Geschlecht: %s" % ("Mann" if draft.gender == "male" else "Frau")
		current.text = "Hut: %s" % ("Kein Hut" if draft.hat == "none" else "Jagdhut")
		gut_sl.set_value_no_signal(float(draft.gut_belly))
		fh_sl.set_value_no_signal(float(draft.forehead))
		rebuild_preview.call())
	_button(act, "SAVE", func():
		GameState.outfit = draft.duplicate(true)
		dirty = false
		unsaved_lbl.visible = false)
	_button(ctrl, "Zurück", func(): page_home())
	_finish_page()


func page_settings() -> void:
	var vb := _page("Einstellungen", 560)
	Menus.settings_ui(vb)
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


# ------------------------------------------------------------------ Start

func _load_name() -> String:
	var f := FileAccess.open("user://name.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""


func _go(mode: String, address: String, slot: String, new_game: bool) -> void:
	if _name.is_empty():
		show_error("Bitte zuerst einen Namen eingeben.")
		return
	GameState.player_name = _name
	var f := FileAccess.open("user://name.txt", FileAccess.WRITE)
	if f:
		f.store_string(_name)
	start.emit(mode, address, slot, new_game)


func show_error(text: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = text
