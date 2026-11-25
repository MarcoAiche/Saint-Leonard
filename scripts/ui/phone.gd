class_name Phone
extends RefCounted
## Handy (Taste P): Nachrichten, Aufträge, Kamera, Fotos, Wildkameras, Karte, Pannenhilfe,
## Freunde (Mehrspieler-Chat) und Einstellungen (Minimap, Sprachchat).

static var messages: Array = []  # [[von, text, uhrzeit]]
static var trailcam_log: Array = []


static func log_message(from: String, text: String) -> void:
	messages.append([from, text, GameState.clock_text()])
	if messages.size() > 40:
		messages.pop_front()


static func open(game: Node, app := "home") -> void:
	var hud: Hud = game.hud
	Menus.close_all(hud)
	var p := hud.panel(hud.menu_root, Color(0.12, 0.12, 0.14, 0.97))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.custom_minimum_size = Vector2(380, 640)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var clock := Label.new()
	clock.text = "%s   $%d" % [GameState.clock_text(), GameState.money]
	clock.add_theme_color_override("font_color", Color.WHITE)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(clock)
	var back := Button.new()
	back.text = "Zurück" if app != "home" else "Weg"
	back.pressed.connect(func(): open(game) if app != "home" else Menus.close_all(hud))
	top.add_child(back)
	var screen := PanelContainer.new()
	var sb := Hud._style(Color(0.93, 0.95, 0.97), 0)
	sb.set_corner_radius_all(10)
	screen.add_theme_stylebox_override("panel", sb)
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(screen)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match app:
		"home": _home(game, body)
		"msg": _messages(body)
		"jobs": _jobs(game, body)
		"photos": _photos(body)
		"cams": _cams(body)
		"friends": _friends(game, body)
		"settings": _settings(game, body)


static func _btn(body: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 46
	b.pressed.connect(func():
		Sfx.play_2d(body, Sfx.click(), -8.0)
		cb.call())
	body.add_child(b)


static func _home(game: Node, body: VBoxContainer) -> void:
	_btn(body, "Nachrichten (%d)" % messages.size(), func(): open(game, "msg"))
	_btn(body, "Aufträge", func(): open(game, "jobs"))
	_btn(body, "Kamera (Foto machen)", func():
		Menus.close_all(game.hud)
		game.take_photo())
	_btn(body, "Fotos (%d)" % GameState.photos.size(), func(): open(game, "photos"))
	_btn(body, "Wildkameras", func(): open(game, "cams"))
	_btn(body, "Karte", func():
		Menus.close_all(game.hud)
		game.hud.toggle_map())
	_btn(body, "Pannenhilfe ($250)", func():
		if GameState.pay(250):
			game.tow_truck_to_player()
			Menus.close_all(game.hud)
		else:
			game.hud.toast("Zu wenig Geld"))
	if Net.active():
		_btn(body, "Freunde und Chat", func(): open(game, "friends"))
	_btn(body, "Einstellungen", func(): open(game, "settings"))


static func _label(body: Control, t: String, size := 15, color := Hud.INK) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 320
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	body.add_child(l)
	return l


static func _messages(body: VBoxContainer) -> void:
	if messages.is_empty():
		_label(body, "Keine Nachrichten.")
	for i in range(messages.size() - 1, -1, -1):
		var m: Array = messages[i]
		_label(body, "%s  %s" % [m[2], m[0]], 13, Color(0.35, 0.35, 0.4))
		_label(body, m[1])


static func _jobs(game: Node, body: VBoxContainer) -> void:
	var ms: Missions = game.missions
	if GameState.story.get("done", false):
		_label(body, "Geschichte abgeschlossen: Das Gasthaus Pirtscher ist gerettet!", 16)
	else:
		_label(body, ms.chapter().get("title", ""), 18)
		for g in ms.goals():
			_label(body, ("[x] " if g[1] else "[  ] ") + g[0], 14, Color(0.3, 0.55, 0.3) if g[1] else Hud.INK)
	_label(body, "Laufende Nebenaufträge", 18)
	var any := false
	for j in GameState.side_jobs:
		if j.state == "active":
			any = true
			_label(body, "%s ($%d)" % [j.text, int(j.reward)], 14)
			if j.has("target"):
				_btn(body, "Wegpunkt setzen", func():
					game.set_waypoint(Vector2(j.target[0], j.target[1]))
					game.hud.toast("Wegpunkt gesetzt"))
			_btn(body, "Abbrechen", func():
				ms.abandon(j)
				open(game, "jobs"))
	if not any:
		_label(body, "Keine.", 14)
	_label(body, "Neue Angebote (heute)", 18)
	for j in ms.offers():
		_label(body, "%s ($%d)" % [j.text, int(j.reward)], 14)
		_btn(body, "Annehmen", func():
			ms.accept(j)
			open(game, "jobs"))


static func _photos(body: VBoxContainer) -> void:
	if GameState.photos.is_empty():
		_label(body, "Noch keine Fotos. Kamera-App benutzen; im Bauhaus gibt es Fotorahmen für zu Hause.")
	for i in range(GameState.photos.size() - 1, maxi(-1, GameState.photos.size() - 7), -1):
		var path: String = GameState.photos[i]
		var img := Image.load_from_file(path)
		if img:
			img.resize(320, 180)
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			body.add_child(tr)


static func _cams(body: VBoxContainer) -> void:
	if trailcam_log.is_empty():
		_label(body, "Keine Aufnahmen. Wildkameras gibt es im Bauhaus.")
	for i in range(trailcam_log.size() - 1, -1, -1):
		_label(body, trailcam_log[i], 14)


static func _friends(game: Node, body: VBoxContainer) -> void:
	for n in Net.player_names():
		_label(body, n, 16)
	var line := LineEdit.new()
	line.placeholder_text = "Nachricht an alle"
	body.add_child(line)
	_btn(body, "Senden", func():
		if not line.text.strip_edges().is_empty():
			Net.send_chat(line.text.strip_edges())
			line.text = "")
	_label(body, "Sprachchat: [B] gedrückt halten zum Sprechen, [J] stumm. Funk (Gruppenkanal) unter Einstellungen.", 13)


static func _settings(game: Node, body: VBoxContainer) -> void:
	_btn(body, "Minimap: %s" % ("an" if GameState.minimap_on else "aus"), func():
		game.toggle_minimap()
		open(game, "settings"))
	_btn(body, "Sprachchat-Funk (Gruppenkanal): %s" % ("an" if Voice.radio_on else "aus"), func():
		Voice.radio_on = not Voice.radio_on
		open(game, "settings"))
	_btn(body, "Mikrofon: %s" % ("stumm" if Voice.muted else "an"), func():
		Voice.muted = not Voice.muted
		open(game, "settings"))
	_btn(body, "Ansicht: %s" % ("Ego" if game.rig.first_person else "Third Person"), func():
		game.rig.toggle_view()
		open(game, "settings"))
