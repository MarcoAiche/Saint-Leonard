class_name Menus
extends RefCounted
## Fenster für Läden, Werkstatt, Inventar, Werkbank und Brennkessel.
## Alle Fenster liegen in hud.menu_root; Esc oder "Schließen" macht sie zu.

static func window(hud: Hud, title: String, width := 620.0) -> VBoxContainer:
	close_all(hud)
	var p := hud.panel(hud.menu_root)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.custom_minimum_size = Vector2(width, 0)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	p.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var money := Label.new()
	money.text = "$%d" % GameState.money
	money.add_theme_color_override("font_color", Color(0.1, 0.45, 0.15))
	money.name = "Geld"
	head.add_child(money)
	var close := Button.new()
	close.text = "Schließen"
	close.pressed.connect(func(): close_all(hud))
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 30, 560 if width > 800 else 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	Hud._anchor(p, Control.PRESET_CENTER, 0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return body


static func close_all(hud: Hud) -> void:
	for c in hud.menu_root.get_children():
		c.queue_free()
	hud._restore_mouse()


static func heading(body: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.45, 0.25, 0.1))
	body.add_child(l)


static func row(body: VBoxContainer, text: String, button: String, cb: Callable, enabled := true) -> Button:
	var h := HBoxContainer.new()
	body.add_child(h)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var b := Button.new()
	b.text = button
	b.disabled = not enabled
	b.custom_minimum_size.x = 140
	b.pressed.connect(func():
		Sfx.play_2d(body, Sfx.click(), -6.0)
		cb.call())
	h.add_child(b)
	return b


static func text(body: VBoxContainer, t: String, size := 16) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	body.add_child(l)
	return l


# ------------------------------------------------------------------ Laden

static func shop(game: Node, id: String) -> void:
	var hud: Hud = game.hud
	var body := window(hud, Items.SHOP_NAMES.get(id, id))
	var reopen := func(): shop(game, id)
	if id == "pub":
		text(body, "\"Griaß di! Was darf's sein?\"  (Wirt Sepp)")
		var story_line: String = game.missions.pub_talk_text()
		if not story_line.is_empty():
			row(body, story_line, "Reden", func():
				close_all(hud)
				game.missions.talk_to_pub())
	if id == "butcher":
		_butcher_sell_ui(game, body, hud, reopen)
	else:
		heading(body, "Kaufen")
		for item in Items.stock(id):
			var it := Items.info(item)
			var have := GameState.count(item)
			var badge := "  [NEW]" if id == "gun" and have == 0 else ""
			var label := "%s%s  ($%d)" % [it.name, badge, it.price]
			if have > 0:
				label += "   hast: %d" % have
			row(body, label, "Kaufen", func():
				var err := GameState.buy(item)
				if err.is_empty():
					game.on_bought(item, id)
				else:
					hud.toast(err)
				reopen.call(), GameState.can_pay(it.price))
	var buys := Items.buys(id)
	var any := false
	for b in buys:
		if GameState.has(b[0]):
			if not any:
				heading(body, "Verkaufen")
				any = true
			var n := GameState.count(b[0])
			row(body, "%s  x%d  (je $%d)" % [Items.display(b[0]), n, b[1]], "Alle verkaufen", func():
				GameState.sell(b[0], b[1], n)
				game.on_sold(b[0], n, id)
				reopen.call())
	if id == "bauhaus":
		heading(body, "Häuser für Saint Leonard (Bauplatz wird zugewiesen)")
		for i in Items.HOUSES.size():
			var h: Dictionary = Items.HOUSES[i]
			var owned := GameState.house >= 0
			row(body, "%s  ($%d)" % [h.name, h.price], "Gekauft" if owned else "Kaufen", func():
				game.buy_house(i)
				reopen.call(), not owned and GameState.can_pay(h.price))
	if id == "gas":
		text(body, "Tanken: mit dem Pickup an die Zapfsäule fahren und [F] drücken.", 14)


# ------------------------------------------------------------------ Werkstatt

static func garage(game: Node) -> void:
	var hud: Hud = game.hud
	var body := window(hud, "Werkstatt Gust")
	var reopen := func(): garage(game)
	var t: Dictionary = GameState.truck
	text(body, "Schaden: %d %%   Tank: %d l" % [int(t.damage), int(t.fuel)])
	var repair := int(t.damage * 9.0)
	row(body, "Reparieren ($%d)" % repair, "Reparieren", func():
		if GameState.pay(repair):
			GameState.truck.damage = 0.0
			game.car.broken = false
		reopen.call(), repair > 0 and GameState.can_pay(repair))
	row(body, "Pickup in die Werkstatt holen (Abschleppen, $120)", "Holen", func():
		if GameState.pay(120):
			game.tow_truck_to_garage()
		reopen.call(), GameState.can_pay(120))
	heading(body, "Umbauten")
	for id in Items.UPGRADES:
		var u: Dictionary = Items.UPGRADES[id]
		var has: bool = t.upgrades.has(id)
		row(body, "%s  ($%d)" % [u.name, u.price], "Eingebaut" if has else "Einbauen", func():
			if GameState.pay(u.price):
				GameState.truck.upgrades[id] = true
				game.car.rebuild()
				game.missions.event("upgrade", {id = id})
			reopen.call(), not has and GameState.can_pay(u.price))
	heading(body, "Lackierung ($150)")
	var h := HFlowContainer.new()
	body.add_child(h)
	for i in Items.PAINTS.size():
		var b := Button.new()
		b.text = Items.PAINTS[i][0]
		var sb := Hud._style(Items.PAINTS[i][1], 2)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", Color.WHITE if Items.PAINTS[i][1].get_luminance() < 0.5 else Hud.INK)
		b.pressed.connect(func():
			if GameState.pay(150):
				GameState.truck.paint = i
				game.car.rebuild()
			reopen.call())
		h.add_child(b)


# ------------------------------------------------------------------ Inventar und Werkbank

static func inventory(game: Node) -> void:
	var hud: Hud = game.hud
	var body := window(hud, "Rucksack und Ausrüstung", 900)
	var reopen := func(): inventory(game)
	var view := InventoryView.new()
	view.setup(game)
	view.action.connect(func(id, what): _inv_action(game, view, id, what))
	body.add_child(view)
	if game.inside_own_house(game.player.global_position):
		heading(body, "Werkbank (zu Hause)")
		for out_id in Items.RECIPES:
			var need: Dictionary = Items.RECIPES[out_id]
			var parts := []
			var ok := true
			for k in need:
				parts.append("%dx %s" % [need[k], Items.display(k)])
				if GameState.count(k) < need[k]:
					ok = false
			row(body, "%s  (aus %s)" % [Items.display(out_id), ", ".join(parts)], "Herstellen", func():
				for k in need:
					GameState.take(k, need[k])
				GameState.give(out_id)
				hud.toast("%s hergestellt" % Items.display(out_id))
				reopen.call(), ok)
	var at_home: bool = game.inside_own_house(game.player.global_position)
	row(body, "Kleiderschrank: Figur und Kleidung" + ("" if at_home else "  (nur zu Hause)"), "Öffnen", func(): game.open_wardrobe(), at_home)
	var s: Dictionary = GameState.stats
	text(body, "Strecke: Rehe %d, Wildschweine %d, Hasen %d, Bären %d   Gebrannt: %d Flaschen   Strafen: $%d" % [s.deer, s.boar, s.rabbit, s.bear, s.bottles, s.fines], 14)


static func _inv_action(game: Node, view: InventoryView, id: String, what: String) -> void:
	var hud: Hud = game.hud
	match what:
		"use":
			close_all(hud)
			game.use_item(id)
		"place":
			close_all(hud)
			game.start_placing(id)
		"wear":
			game.wear(id)
			inventory(game)
		"jerrycan":
			if game.truck_near(game.player.global_position, 6.0):
				game.use_jerrycan()
			else:
				hud.toast("Pickup ist nicht in der Nähe")
			inventory(game)
		"equip":
			if id in ["sniper", "pistol", "assault_rifle"]:
				game._select_slot(id, Items.display(id))
			view.queue_redraw()
		"drop":
			GameState.take(id)
			hud.toast("%s weggeworfen" % Items.display(id))
			inventory(game)


# ------------------------------------------------------------------ Brennkessel

static func still(game: Node, entry: Dictionary) -> void:
	var hud: Hud = game.hud
	var body := window(hud, "Brennkessel", 560)
	var d: Dictionary = entry.data
	var reopen := func(): still(game, entry)
	var mash: String = d.get("mash", "")
	var ready_mash: String = d.get("ready_mash", "")
	if not ready_mash.is_empty():
		var bottles := randi_range(4, 6) if ready_mash == "fruit" else randi_range(2, 4)
		text(body, "Der Brand ist fertig (%s)! Wie willst du ihn abfüllen?" % ("Obst" if ready_mash == "fruit" else "Getreide"))
		row(body, "In Flaschen abfüllen (%d Flaschen Schwarzgebrannter)" % bottles, "Flaschen", func():
			GameState.give("moonshine", bottles)
			GameState.stats.bottles += bottles
			d.ready_mash = ""
			game.placed_changed(entry)
			game.missions.event("brewed", {bottles = bottles})
			close_all(hud)
			hud.toast("%d Flaschen Schwarzgebrannter fertig!" % bottles, 3.0))
		row(body, "In 10-l-Moonshine-Bottich abfüllen (Schmuggelware für Pickup)", "10-l-Bottich", func():
			GameState.give("moonshine_keg", 1)
			GameState.stats.bottles += 10
			d.ready_mash = ""
			game.placed_changed(entry)
			game.missions.event("brewed", {bottles = 10})
			if game.car and is_instance_valid(game.car) and game.car.global_position.distance_to(game.player.global_position) < 8.0 and game.car.has_space():
				var keg := Placeables.model("moonshine_keg")
				keg.set_meta("kind", "moonshine_keg")
				game.car.load_cargo(keg)
				hud.toast("10-l-Bottich abgefüllt & auf den Pickup geladen!", 3.5)
			else:
				hud.toast("10-l-Moonshine-Bottich abgefüllt!", 3.0)
			close_all(hud))
		return
	if mash.is_empty():
		text(body, "Maische ansetzen: 2x Zucker, 1x Hefe und 2x Obst (gut) oder 2x Getreide (billig, brennt leichter an).")
		row(body, "Obstmaische (ergibt mehr und besseren Schnaps)", "Ansetzen", func():
			if GameState.take("sugar", 2) and GameState.take("yeast", 1) and GameState.take("fruit", 2):
				d.mash = "fruit"
				d.temp = 20.0
				d.progress = 0.0
				game.placed_changed(entry)
			reopen.call(), GameState.has("sugar", 2) and GameState.has("yeast") and GameState.has("fruit", 2))
		row(body, "Getreidemaische", "Ansetzen", func():
			if GameState.take("sugar", 2) and GameState.take("yeast", 1) and GameState.take("grain", 2):
				d.mash = "grain"
				d.temp = 20.0
				d.progress = 0.0
				game.placed_changed(entry)
			reopen.call(), GameState.has("sugar", 2) and GameState.has("yeast") and GameState.has("grain", 2))
		row(body, "Brennkessel abbauen (zurück ins Inventar)", "Abbauen", func():
			game.pick_up_placed(entry)
			close_all(hud))
		return
	text(body, "Maische: %s. Halte die Temperatur im grünen Bereich (78 bis 92 °C).\nÜber 100 °C fliegt der Kessel in die Luft!" % ("Obst" if mash == "fruit" else "Getreide"))
	var temp_l := text(body, "", 22)
	var bar := ProgressBar.new()
	bar.max_value = 120
	bar.show_percentage = false
	bar.custom_minimum_size.y = 26
	body.add_child(bar)
	var prog := ProgressBar.new()
	prog.show_percentage = false
	prog.custom_minimum_size.y = 18
	body.add_child(prog)
	var heat := Button.new()
	heat.text = "Feuer schüren (gedrückt halten)"
	heat.custom_minimum_size.y = 60
	body.add_child(heat)
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	body.add_child(timer)
	var over := [0.0]
	timer.timeout.connect(func():
		var dt := 0.05
		var hot: bool = heat.button_pressed
		d.temp = float(d.temp) + (22.0 if hot else -9.0) * dt + randf_range(-0.6, 0.6)
		d.temp = clampf(float(d.temp), 15.0, 130.0)
		var t: float = d.temp
		var limit := 100.0 if mash == "fruit" else 96.0
		if t >= 78.0 and t <= 92.0:
			d.progress = float(d.progress) + dt / 30.0
		if t > limit:
			over[0] += dt
		else:
			over[0] = maxf(0.0, over[0] - dt)
		temp_l.text = "%d °C" % int(t)
		temp_l.add_theme_color_override("font_color", Color(0.1, 0.55, 0.15) if t >= 78.0 and t <= 92.0 else (Color(0.85, 0.1, 0.05) if t > 92.0 else Hud.INK))
		bar.value = t
		prog.value = float(d.progress) * 100.0
		if over[0] > 2.5:
			timer.stop()
			close_all(hud)
			game.still_explode(entry)
		elif float(d.progress) >= 1.0:
			timer.stop()
			d.ready_mash = mash
			d.mash = ""
			d.progress = 0.0
			game.placed_changed(entry)
			reopen.call())


# ------------------------------------------------------------------ Einstellungen

## Schieberegler und Schalter für Settings (im Hauptmenü und im Pausemenü)
static func settings_ui(body: Control) -> void:
	var slider := func(label: String, key: String, lo: float, hi: float, stp: float, fmt: String):
		var h := HBoxContainer.new()
		body.add_child(h)
		var l := Label.new()
		l.text = label
		l.custom_minimum_size.x = 190
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = lo
		s.max_value = hi
		s.step = stp
		s.value = float(Settings.get_v(key))
		s.custom_minimum_size = Vector2(220, 24)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(s)
		var v := Label.new()
		v.text = fmt % s.value
		v.custom_minimum_size.x = 60
		h.add_child(v)
		s.value_changed.connect(func(x):
			v.text = fmt % x
			Settings.set_v(key, x))
	var toggle := func(label: String, key: String):
		var c := CheckBox.new()
		c.text = label
		c.button_pressed = bool(Settings.get_v(key))
		c.add_theme_color_override("font_color", Hud.INK)
		c.add_theme_color_override("font_pressed_color", Hud.INK)
		c.add_theme_color_override("font_hover_color", Hud.INK)
		c.toggled.connect(func(on): Settings.set_v(key, on))
		body.add_child(c)
	slider.call("Mausempfindlichkeit", "sensitivity", 0.2, 3.0, 0.05, "%.2f")
	toggle.call("Maus invertieren (oben/unten)", "invert_y")
	slider.call("Sichtfeld (FOV)", "fov", 55.0, 100.0, 1.0, "%d°")
	slider.call("Gesamtlautstärke", "volume", 0.0, 1.0, 0.05, "%.2f")
	slider.call("SFX-Lautstärke", "sfx_volume", 0.0, 1.0, 0.05, "%.2f")
	slider.call("Ambience-Lautstärke", "ambience_volume", 0.0, 1.0, 0.05, "%.2f")
	slider.call("Voice-Lautstärke", "voice_volume", 0.0, 1.0, 0.05, "%.2f")
	slider.call("Radio-Lautstärke", "radio_volume", 0.0, 1.0, 0.05, "%.2f")
	toggle.call("Vollbild", "fullscreen")
	toggle.call("VSync", "vsync")
	slider.call("Auflösung (Skalierung)", "render_scale", 0.5, 1.0, 0.05, "%.2f")
	slider.call("Schatten (0 aus, 2 hoch)", "shadows", 0.0, 2.0, 1.0, "%d")
	slider.call("Sichtweite Bäume", "view_distance", 0.4, 1.5, 0.05, "%.2f")


static func _butcher_sell_ui(game: Node, body: VBoxContainer, _hud: Hud, reopen: Callable) -> void:
	text(body, "GASTON: \"You bring me something to cook, oui?\"")
	text(body, "Tipp: Wild einfach in den roten Kreis legen oder hier vom Pickup/Anhänger verkaufen!")
	heading(body, "Wild-Verkauf (Hand, Pickup & Anhänger)")
	var entries: Array = []
	var ppos: Vector3 = game.player.global_position
	if game.player.carrying is Carcass:
		entries.append({c = game.player.carrying, holder = game.player, src = "In der Hand"})
	if game.car and game.car.global_position.distance_to(ppos) < 25.0:
		for n in game.car.cargo:
			if n is Carcass:
				entries.append({c = n, holder = game.car, src = "Pickup"})
	if game.trailer and game.trailer.global_position.distance_to(ppos) < 25.0:
		for n in game.trailer.cargo:
			if n is Carcass:
				entries.append({c = n, holder = game.trailer, src = "Anhänger"})

	if entries.is_empty():
		text(body, "Bring erlegte Tiere her! (Per Hand tragen oder auf Pickup/Anhänger laden)")
		heading(body, "GASTON Preisliste")
		for pair in [
			["Reh / Hirsch", 300], ["Wildschwein", 220], ["Mutanten-Hase", 120],
			["Hase", 25], ["Braunbär", 450], ["Riesenhirsch", 650], ["Bigfoot", 1000]
		]:
			text(body, "  • %s: $%d" % [pair[0], pair[1]])
	else:
		var total := 0
		for e in entries:
			var c: Carcass = e.c
			var val := c.sell_value()
			total += val
			var label := "%s (%.0f kg, %s)  —  $%d" % [c.display_name(), c.mass, e.src, val]
			row(body, label, "Einzeln verkaufen", func():
				game.sell_single_carcass(c, e.holder)
				reopen.call())
		row(body, "Gesamte Ladung (%d Stück)" % entries.size(), "Alle verkaufen (+$%d)" % total, func():
			game.sell_truck_cargo()
			reopen.call())
