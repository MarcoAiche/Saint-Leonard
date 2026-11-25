extends Node
## Entwickler-Helfer (Autoload). Nur im Editor bzw. in Debug-Builds aktiv, mit Startparametern nach "--":
##   --player=x,z           Spielfigur dorthin setzen
##   --drive                ins Auto einsteigen
##   --hold=aktion:sek,...  Tasten (Input-Aktionen) nacheinander gedrückt halten
##   --cam=yaw,pitch        Kamerawinkel in Grad
##   --tp                   Third-Person-Ansicht
##   --time=stunde          Uhrzeit setzen
##   --weather=art          clear, cloudy, fog, rain
##   --animal=art           ein Tier 25 m vor die Figur setzen
##   --money=betrag         Geld setzen
##   --upgrades             alle Pickup-Umbauten einbauen
##   --menu=name            Fenster öffnen (shop:gun, garage, inventory, phone, map)
##   --wait=sek             vor dem Bild warten
##   --shot=pfad.png        Bild speichern und beenden
##   --server               dedizierter Server (siehe Net)

var active := false
var args := {}


func _init() -> void:
	# Test- und Debug-Startparameter (--money, --tp, --selftest ...) nur im Editor bzw. in
	# Debug-Builds. Das ausgelieferte Spiel (Release-Export) ignoriert sie, damit niemand schummelt.
	if not OS.is_debug_build():
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	args.erase("server")
	active = not args.is_empty()


func _ready() -> void:
	if not active:
		return
	for i in 5:
		await get_tree().process_frame
	var game := get_tree().current_scene as Game
	if game == null:
		return
	if args.get("showmenu") == "lobbyjoin":
		await _lobby_test(game)
		return
	if args.has("showmenu"):
		await get_tree().create_timer(1.5).timeout
		match args.get("showmenu"):
			"saves": game.menu.page_saves()
			"settings": game.menu.page_settings()
			"multi": game.menu.page_multi()
			"figure": game.menu.page_figure("title")
			"lobby":
				# Lobby ohne Server: zwei erfundene Mitspieler
				Net.peers = {
					5: {name = "Anna", outfit = GameState._colors_out(Outfit.normalize({preset = "female", top = "hoodie", hat = "beanie", shirt = Color(0.78, 0.18, 0.14)})), state = "lobby", ready = true},
					6: {name = "Bert", outfit = GameState._colors_out(Outfit.normalize({top = "hi_vis", hat = "work_helmet", beard = "full"})), state = "lobby", ready = false},
					7: {name = "Sepp", outfit = GameState._colors_out(Outfit.normalize({top = "trachten", legs = "lederhose"})), state = "game", ready = false},
				}
				game.menu.show_lobby()
		await get_tree().create_timer(float(args.get("menuwait", "0.5"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
		return
	while not game.started:
		await get_tree().process_frame
	if args.has("mptest"):
		_nan_watch(game)
	if Net.is_dedicated():
		# Testserver: eine Weile laufen, dann Spielstand prüfen und beenden
		await get_tree().create_timer(float(args.get("quit_after", 120))).timeout
		GameState.save_game()
		var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [GameState.SAVE_DIR, GameState.slot]))
		print("[Server] Gespeichert: Profile %s, %d aufgestellt, Häuser %s" % [d.get("profiles", {}).keys(), d.world.placed.size(), d.world.houses])
		await _quit()
		return
	if args.has("mptest") and Net.is_client():
		var t := MpTest.new(game, str(args.mptest))
		await t.run()
		await _quit()
		return
	await get_tree().create_timer(0.5).timeout
	if args.has("money"):
		GameState.money = int(args.money)
	if args.has("upgrades"):
		for u in Items.UPGRADES:
			GameState.truck.upgrades[u] = true
		game.car.rebuild()
	if args.has("time"):
		GameState.time = float(args.time)
	if args.has("weather"):
		GameState.weather = args.weather
		GameState.wetness = 1.0 if args.weather == "rain" else 0.0
	if args.has("player"):
		var v := _floats(args.player)
		game.player.global_position = Vector3(v[0], game.world.height_at(v[0], v[1]) + 0.5, v[1])
		game.player.reset_physics_interpolation()
		await get_tree().create_timer(0.5).timeout
	if args.has("drive"):
		game.player.global_position = game.car.global_position + game.car.global_basis.x * 2.0
		await get_tree().physics_frame
		game.enter_vehicle(game.car, "driver")
	if args.has("tp"):
		game.rig.toggle_view()
	if args.has("cam"):
		var v := _floats(args.cam)
		game.rig.yaw = deg_to_rad(v[0])
		game.rig.pitch = deg_to_rad(v[1])
	if args.has("dist"):
		game.rig.distance = float(args.dist)
	if args.has("animal"):
		# mehrere Tiere nebeneinander, ohne KI (zum Anschauen)
		var k := 0
		for sp in args.animal.split("+"):
			var right := Vector3(-game.rig.ground_forward().z, 0, game.rig.ground_forward().x)
			var f: Vector3 = game.player.global_position + game.rig.ground_forward() * 9.0 + right * (k - 1.5) * 3.2
			var a := game.spawner.spawn(sp, Vector3(f.x, game.world.height_at(f.x, f.z) + 0.3, f.z), 9990 + k, k, args.has("freeze"))
			a.rotation.y = game.rig.yaw + PI / 2
			k += 1
	if args.has("buyhouse"):
		GameState.money = 100000
		game.buy_house(int(args.buyhouse))
		game.hud.close_dialog()
		var pl: Dictionary = game.landmarks.plots[GameState.house]
		var d := Vector3(sin(pl.yaw), 0, cos(pl.yaw))
		var pp: Vector3 = pl.pos + d * 16.0
		game.player.global_position = Vector3(pp.x, game.world.height_at(pp.x, pp.z) + 0.5, pp.z)
		game.rig.yaw = atan2(d.x, d.z)
	if args.has("place"):
		var k2 := 0
		for t in args.place.split("+"):
			var right2 := Vector3(-game.rig.ground_forward().z, 0, game.rig.ground_forward().x)
			var q: Vector3 = game.player.global_position + game.rig.ground_forward() * 8.0 + right2 * (k2 - 1.0) * 4.5
			q.y = game.world.height_at(q.x, q.z)
			Net.request_place({uid = GameState.new_uid(), type = t, pos = [q.x, q.y, q.z], rot = game.rig.yaw, owner = GameState.player_name, data = {}})
			k2 += 1
	if args.has("police"):
		var c := game.police._spawn_car()
		var q2: Vector3 = game.player.global_position + game.rig.ground_forward() * 9.0
		c.place_at(q2, Vector3(1, 0, 0))
		c.mode = PoliceCar.Mode.PARKED
		c.set_siren(true)
	if args.has("menu"):
		var m: String = args.menu
		if m.begins_with("shop:"):
			game.open_shop(m.trim_prefix("shop:"))
		elif m == "garage":
			game.open_garage()
		elif m == "inventory":
			Menus.inventory(game)
		elif m == "phone":
			Phone.open(game)
		elif m == "jobs":
			Phone.open(game, "jobs")
		elif m == "map":
			game.hud.toggle_map()
		elif m == "slots":
			game.casino.open_slots()
		elif m == "roulette":
			game.casino.open_roulette()
		elif m == "poker":
			GameState.time = 21.0
			GameState.money = 1000
			game.casino._sit_poker(250)
			await get_tree().create_timer(3.0).timeout
		elif m == "hall":
			var h: FireHall = game.hall
			game.player.global_position = h.door + Vector3.UP * 0.5
			game.player.reset_physics_interpolation()
			var to: Vector3 = h.global_position - h.door
			game.rig.yaw = atan2(-to.x, -to.z)
	if args.has("shoot"):
		# auf das erste Tier zielen und schießen
		await get_tree().create_timer(0.5).timeout
		for a in [game.spawner.animals.get(9990, null)]:
			if a == null:
				break
			var target: Vector3 = a.global_position + Vector3.UP * 0.9 + a.global_basis.z * 0.2
			var from: Vector3 = game.rig.camera.global_position
			var d := (target - from).normalized()
			game.rig.yaw = atan2(-d.x, -d.z)
			game.rig.pitch = asin(d.y)
			await get_tree().process_frame
			await get_tree().process_frame
			game.player.hand._fire()
			await get_tree().create_timer(0.3).timeout
			print("Schuss auf %s: tot = %s" % [a.species if is_instance_valid(a) else "?", not is_instance_valid(a) or a.is_dead()])
			break
	if args.has("drunk"):
		GameState.bac = float(args.drunk)
	if args.has("use"):
		game.use_item(args.use)
	if args.has("reloadtest"):
		GameState.loaded = 1
		game.player.hand.try_reload()
	if args.has("radiotest"):
		var r := Radio.new()
		game.add_child(r)
		var t := 0.0
		while Radio.online.is_empty() and t < 15.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		print("Online-Sender: ", Radio.online.size(), " ", Radio.online.slice(0, 6).map(func(x): return x.name))
		print(r.next_station())
		await get_tree().create_timer(14.0).timeout
		print("Spielt: ", r.playing or r._second.playing, ", Puffer %d Bytes, Warteschlange %d" % [r._buf.size(), r._queue.size()])
	if args.has("keytest"):
		for k in [KEY_3, KEY_1, KEY_Y, KEY_Z]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			ev.keycode = k
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			await get_tree().process_frame
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			await get_tree().process_frame
			print("Taste %s -> Hand: %s, Zigaretten: %d, Rauchzeit %.0f, Menüs offen: %s" % [OS.get_keycode_string(k), game.player.hand.slot, GameState.count("cigarettes"), GameState.smoke_time, game.hud.menus_open()])
	if args.has("trailertest"):
		await _trailer_test(game)
	if args.has("housetest"):
		await _house_test(game)
	if args.has("gasthaustest"):
		await _gasthaus_test(game)
	if args.has("wardrobetest"):
		await _wardrobe_test(game)
	if args.has("trophytest"):
		await _trophy_test(game)
	if args.has("selftest"):
		await _selftest(game)
	if args.has("aim"):
		Input.action_press("aim")
	if args.has("hold"):
		for item in args.hold.split(","):
			var parts: PackedStringArray = item.split(":")
			Input.action_press(parts[0])
			await get_tree().create_timer(float(parts[1])).timeout
			Input.action_release(parts[0])
	if args.has("wait"):
		await get_tree().create_timer(float(args.wait)).timeout
	_report(game)
	if args.has("shot"):
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("Screenshot gespeichert: ", args.shot)
	await _quit()


## Gasthaus Pirtscher: von der Straße durch die Tür in die Gaststube gehen
func _gasthaus_test(game: Game) -> void:
	var g: Gasthaus = game.gasthaus
	if g == null:
		push_error("Gasthaus fehlt")
		return
	var hz := g.size.y * 0.5
	var outside := g.global_transform * Vector3(0, 0, hz + 3.0)
	print("Gasthaus bei %s, Größe %s, Boden Tür %.2f / Haus %.2f" % [g.global_position, g.size, game.world.height_at(outside.x, outside.z), g.global_position.y])
	game.player.global_position = Vector3(outside.x, game.world.height_at(outside.x, outside.z) + 0.5, outside.z)
	game.player.reset_physics_interpolation()
	game.rig.yaw = g.rotation.y
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_forward")
	await get_tree().create_timer(3.5).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.3).timeout
	var local := g.global_transform.affine_inverse() * game.player.global_position
	print("Spieler lokal im Gasthaus: %s -> %s" % [local, "drinnen" if absf(local.z) < hz - 0.3 and absf(local.x) < g.size.x * 0.5 else "DRAUSSEN"])


## Trophäenwand: Stücke vermessen, aufhängen, Wand ansehen
func _trophy_test(game: Game) -> void:
	var counts := {}
	var seed := 1
	while GameState.trophies.size() < 9 and seed < 5000:
		for sp in ["deer", "boar", "bear", "fox", "deer"]:
			if int(counts.get(sp, 0)) >= (4 if sp == "deer" else 2):
				continue
			var msg := TrophyBoard.record(sp, true, seed)
			if msg != "":
				counts[sp] = int(counts.get(sp, 0)) + 1
				print(msg)
			seed += 1
	print("Geiß gibt Trophäe: %s, Hase: %s" % [not TrophyBoard.measure("deer", false, 3).is_empty(), not TrophyBoard.measure("rabbit", true, 3).is_empty()])
	GameState.story["done_legend_deliver"] = true
	var b: TrophyBoard = game.gasthaus.board
	print("Offen zum Aufhängen: %d" % TrophyBoard.pending().size())
	b.hang_all()
	await get_tree().process_frame
	print("Offen danach: %d, an der Wand: %d Knoten" % [TrophyBoard.pending().size(), b._mounts.get_child_count()])
	var front := b.global_transform * Vector3(0, -0.6, 4.5)
	game.player.global_position = Vector3(front.x, b.global_position.y - 2.0, front.z)
	game.player.reset_physics_interpolation()
	var look := b.global_position - front
	game.rig.yaw = atan2(-look.x, -look.z)
	game.rig.pitch = 0.05
	await get_tree().create_timer(0.6).timeout


## Sucht Knoten mit ungültiger Position (NaN) und meldet sie einmal
## Lobby-Test: über das Menü verbinden, in der Lobby "Bereit" drücken; sind alle bereit, geht es
## gemeinsam los (-- --showmenu=lobbyjoin --join=127.0.0.1 --name=Anna [--shot=lobby.png])
func _lobby_test(game: Game) -> void:
	await get_tree().create_timer(1.0).timeout
	game.menu._name = args.get("name", "Tester")
	game.menu._go("client", args.get("join", "127.0.0.1"), "", false)
	var t := 0.0
	while not game.menu._in_lobby and t < 15.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("LOBBY verbunden: %s" % game.menu._in_lobby)
	await get_tree().create_timer(float(args.get("readydelay", "4"))).timeout
	print("LOBBY Spieler: %s" % str(game.menu.lobby_players().map(func(p): return "%s/%s/%s" % [p.name, p.state, p.ready])))
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
	if not game.menu._in_lobby:
		print("LOBBY nicht verbunden, Test abgebrochen")
		await _quit()
		return
	game.menu._ready_btn.pressed.emit()
	t = 0.0
	while not game.started and t < 30.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("LOBBY gestartet: %s nach %.1f s, Figur: %s/%s" % [game.started, t, GameState.outfit.get("hat"), GameState.outfit.get("top")])
	await get_tree().create_timer(3.0).timeout
	print("LOBBY Mitspieler im Spiel sichtbar: %d" % game.remote_players.size())
	await _quit()


## Kleidung: freischalten, anziehen, Kleiderschrank im Spiel (-- --wardrobetest [--shot=bild.png])
func _wardrobe_test(game: Game) -> void:
	print("KLEIDUNG Warnweste vorher frei: %s" % Outfit.unlocked("top", "hi_vis"))
	GameState.give("hi_vis")
	game.wear("hi_vis")
	print("KLEIDUNG nach Anziehen: top=%s, frei=%s" % [GameState.outfit.top, Outfit.unlocked("top", "hi_vis")])
	GameState.take("hi_vis")
	print("KLEIDUNG nach Weglegen noch frei (Kleiderschrank): %s" % Outfit.unlocked("top", "hi_vis"))
	var san := Outfit.sanitize({top = "fur_coat", hat = "fur_cap", legs = "lederhose"})
	print("KLEIDUNG gesperrtes wird ersetzt: %s/%s/%s" % [san.top, san.hat, san.legs])
	game.open_wardrobe()
	await get_tree().create_timer(0.5).timeout
	var ed: FigureEditor = game.find_children("*", "FigureEditor", true, false)[0]
	var o := ed.outfit.duplicate()
	o.hat = "cap"
	o.beard = "full"
	o.shirt = Outfit.PALETTES.shirt[2]
	ed.outfit = o
	ed.changed.emit(o)
	ed._select("hat")
	await get_tree().create_timer(1.0).timeout
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot.get_basename() + "_schrank.png")
	ed.finished.emit(ed.outfit, true)
	await get_tree().process_frame
	print("KLEIDUNG übernommen: hat=%s beard=%s, Kamera zurück: %s" % [GameState.outfit.hat, GameState.outfit.beard, game.rig.camera.current])

func _nan_watch(game: Node) -> void:
	var seen := {}
	while is_instance_valid(game):
		await get_tree().create_timer(0.5).timeout
		for n in game.find_children("*", "Node3D", true, false):
			var p: Vector3 = (n as Node3D).global_position
			if not p.is_finite() and not seen.has(n.get_path()):
				seen[n.get_path()] = true
				print("NAN: ", n.get_path(), " ", n.get_class(), " Eltern ", n.get_parent().name)
				if seen.size() > 5:
					return


func _report(game: Game) -> void:
	var p := game.player.global_position
	var c := game.car.global_position
	print("Spieler %s, Boden %.2f, am Boden: %s" % [p, game.world.height_at(p.x, p.z), game.player.is_on_floor()])
	print("Pickup %s, Boden %.2f, %.1f km/h, fährt: %s, aufrecht: %.2f, Untergrund: %s" % [c, game.world.height_at(c.x, c.z), game.car.speed_kmh(), game.driving, game.car.global_basis.y.y, WorldBuilder.TIER_NAMES[game.car.surface.tier]])
	print("Tiere: %d, Polizei: %d, Uhrzeit %s, Wetter %s" % [game.spawner.animals.size(), game.police.patrols.size(), GameState.clock_text(), GameState.weather])
	if not game.casino.poker_view.is_empty():
		print("Pokertisch: %s, Straße %d" % [game.casino.poker_view.players.map(func(x): return "%s %d" % [x.name, x.chips]), game.casino.poker_view.street])
	if Net.active():
		print("Mehrspieler: Modus %s, Mitspieler sichtbar %d, fremde Pickups %d, Name %s" % [Net.mode, game.remote_players.size(), game.remote_trucks.size(), GameState.player_name])
	print("Orte: Stadt %s, Tankstelle %s, Werkstatt %s, Bauplätze %d, Kontrolle %s, Läden %s" % [game.landmarks.city_center, game.landmarks.gas.pos, game.landmarks.garage.pos, game.landmarks.plots.size(), game.landmarks.checkpoint.get("pos", "-"), game.landmarks.shops.keys()])


## Spielt die wichtigsten Abläufe einmal durch (für Tests ohne Fenster: --headless -- --selftest)
func _selftest(game: Game) -> void:
	var step := func(t: String): print("TEST: ", t)
	GameState.money = 100000
	step.call("Einkaufen")
	for shop in ["gun", "super", "bauhaus", "gas", "butcher", "pub"]:
		game.open_shop(shop)
		await get_tree().process_frame
	Menus.close_all(game.hud)
	for id in ["ammo", "scope8", "sugar", "sugar", "yeast", "fruit", "fruit", "still", "stand", "campfire", "trailcam", "table", "frame", "jerrycan", "crate", "straps"]:
		var err := GameState.buy(id)
		if not err.is_empty():
			push_error("Kauf fehlgeschlagen: " + id)
		game.on_bought(id, "x")
	step.call("Schießen und Nachladen")
	game.player.hand.select("sniper")
	game.player.hand._fire()
	await get_tree().create_timer(0.7).timeout
	game.player.hand.try_reload()
	await get_tree().create_timer(2.5).timeout
	print("  Magazin: ", GameState.loaded)
	step.call("Jagd: Reh erlegen, ausnehmen, verkaufen")
	var f: Vector3 = game.player.global_position + Vector3(6, 0, 0)
	var deer := game.spawner.spawn("deer", Vector3(f.x, game.world.height_at(f.x, f.z) + 0.3, f.z), 5001, 3)
	await get_tree().physics_frame
	deer.hit(500.0, deer.global_position + Vector3.UP, Vector3.RIGHT)
	await get_tree().create_timer(0.3).timeout
	var carcass: Carcass = null
	for c in get_tree().get_nodes_in_group("carcass"):
		carcass = c
	if carcass == null:
		push_error("Kein Kadaver")
	else:
		game._harvest(carcass)
	print("  Fleisch: ", GameState.count("meat"), ", Fell: ", GameState.count("hide"))
	GameState.sell("meat", 55, GameState.count("meat"))
	game.on_sold("meat", 1, "butcher")
	step.call("Wildschwein auf die Ladefläche und verkaufen")
	var boar := game.spawner.spawn("boar", Vector3(f.x, game.world.height_at(f.x, f.z) + 0.3, f.z), 5002, 4)
	await get_tree().physics_frame
	boar.hit(500.0, boar.global_position, Vector3.RIGHT)
	await get_tree().create_timer(0.3).timeout
	for c in get_tree().get_nodes_in_group("carcass"):
		if not c.is_queued_for_deletion():
			game.car.load_cargo(c)
	game.sell_truck_cargo()
	step.call("Werkstatt")
	for u in Items.UPGRADES:
		GameState.truck.upgrades[u] = true
	game.car.rebuild()
	game.open_garage()
	await get_tree().process_frame
	step.call("Haus kaufen")
	game.buy_house(2)
	game.hud.close_dialog()
	await get_tree().process_frame
	var pl: Dictionary = game.landmarks.plots[GameState.house]
	print("  Haus auf Bauplatz ", GameState.house, ", drin: ", game.inside_own_house(pl.pos + Vector3.UP))
	step.call("Aufstellen: Kessel, Hochstand, Feuer, Kamera, Tisch")
	var far := Vector3(200, 0, 1500)
	far.y = game.world.height_at(far.x, far.z)
	for t in ["still", "stand", "campfire", "trailcam"]:
		var p := far + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		print("  ", t, " erlaubt: ", Placeables.check(t, p, game).is_empty())
		Net.request_place({uid = GameState.new_uid(), type = t, pos = [p.x, p.y, p.z], rot = 0.0, owner = GameState.player_name, data = {}})
	var hp: Vector3 = pl.pos + Vector3(0, 0.3, 0)
	print("  Tisch im Haus erlaubt: ", Placeables.check("table", hp, game).is_empty())
	await get_tree().process_frame
	var still: Dictionary = {}
	for e in GameState.placed:
		if e.type == "still":
			still = e
	Menus.still(game, still)
	await get_tree().process_frame
	Menus.close_all(game.hud)
	still.data.mash = "fruit"
	still.data.temp = 85.0
	still.data.progress = 0.0
	Menus.still(game, still)
	await get_tree().create_timer(0.5).timeout
	Menus.close_all(game.hud)
	game.still_explode(still)
	step.call("Polizeikontrolle")
	GameState.bac = 0.09
	GameState.give("moonshine", 3)
	game.police.chaser = game.police.checkpoint_car
	game.police._open_control(true)
	await get_tree().process_frame
	game.hud.close_dialog()
	game.police._start_chase()
	await get_tree().create_timer(0.5).timeout
	game.police._end()
	GameState.bac = 0.0
	step.call("Handy, Inventar, Aufträge")
	for app in ["home", "msg", "jobs", "photos", "cams", "settings"]:
		Phone.open(game, app)
		await get_tree().process_frame
	Menus.inventory(game)
	await get_tree().process_frame
	Menus.close_all(game.hud)
	game.missions.talk_to_pub()
	game.hud.close_dialog()
	for j in game.missions.offers():
		game.missions.accept(j)
	await get_tree().process_frame
	print("  Aufträge aktiv: ", GameState.side_jobs.size(), ", Kapitel: ", GameState.story.chapter, " ", game.missions.goals())
	step.call("Fahren, Ein-/Aussteigen, Radio, Seilwinde")
	game.enter_vehicle(game.car, "driver")
	print("  ", game.car.next_station())
	print("  ", game.car.toggle_winch())
	await get_tree().create_timer(0.3).timeout
	game.exit_vehicle()
	step.call("Trinken bis zur Ohnmacht, Fest")
	GameState.give("schnaps", 10)
	for i in 6:
		game.use_item("schnaps")
	print("  Promille: %.1f, ohnmächtig: %s" % [GameState.promille(), game.player.passed_out > 0.0])
	game.decorate_pub_trophy()
	game.start_festival()
	game.hud.close_dialog()
	step.call("Feuerwehrhaus und Glücksspiel")
	print("  Feuerwehrhaus: ", game.hall != null, " bei ", game.hall.global_position if game.hall else Vector3.ZERO)
	GameState.money = 5000
	game.casino.open_slots()
	await get_tree().process_frame
	var total := 0
	for i in 2000:
		total += Casino._slot_payout([game.casino._slot_symbol(), game.casino._slot_symbol(), game.casino._slot_symbol()], 10)
	print("  Spielautomat: Rücklauf %.0f %%" % (total / 200.0))
	Menus.close_all(game.hud)
	game.casino.open_roulette()
	await get_tree().process_frame
	game.casino.place_roulette_bet("Rot", Casino.RED, 2, 10)
	game.casino._spin_roulette(7)
	await get_tree().create_timer(4.3).timeout
	print("  Roulette: Geld %d" % GameState.money)
	Menus.close_all(game.hud)
	game.player.global_position = game.hall.door
	GameState.time = 21.0
	game.casino._sit_poker(250)
	var pk: PokerGame = game.casino.poker
	var hands := 0
	var t0 := Time.get_ticks_msec()
	while hands < 3 and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().create_timer(0.2).timeout
		var me := pk.index_of(GameState.player_name)
		if pk.turn == me and pk.street >= 0 and pk.street < 4:
			game.casino.poker_action("call")
		if pk.street == 4:
			hands = pk.hands_played
	print("  Poker: %d Hände, Tisch: %s" % [pk.hands_played, ", ".join(pk.players.map(func(x): return "%s %d" % [x.name, x.chips]))])
	print("  Wertung Royal Flush > Vierling: ", PokerGame.best_score([12, 11, 10, 9, 8]) > PokerGame.best_score([0, 13, 26, 39, 5]))
	game.casino.on_raid()
	game.casino.raid_t = 0.05
	await get_tree().create_timer(0.3).timeout
	game.hud.close_dialog()
	print("  Razzia: am Tisch = %s, Geld %d" % [game.casino.at_poker, GameState.money])
	Menus.close_all(game.hud)
	game.stand_up()
	step.call("Speichern und Laden")
	var before := GameState.money
	GameState.slot = "selbsttest"
	var was := active
	active = false
	GameState.save_game()
	GameState.money = 1
	GameState.load_game()
	active = was
	print("  Geld vorher %d, nachher %d" % [before, GameState.money])
	DirAccess.remove_absolute("user://saves/selbsttest.json")
	step.call("Mehrspieler: Server starten und stoppen")
	var test_peer := ENetMultiplayerPeer.new()
	print("  Server-Port frei: ", test_peer.create_server(24699) == OK)
	test_peer.close()
	print("SELBSTTEST FERTIG")


## Anhänger: kaufen, ankuppeln, ziehen, Ladung mit und ohne Gurte (-- --trailertest)
func _trailer_test(game: Game) -> void:
	GameState.money = 10000
	GameState.give("trailer")
	game.on_bought("trailer", "bauhaus")
	await get_tree().create_timer(1.0).timeout
	var t: Trailer = game.trailer
	print("TRAILER gekauft: %s, ankuppelbar: %s" % [t != null, t.can_couple(game.car) if t else false])
	# auf eine gerade Straße stellen und ankuppeln
	var sp: Dictionary = game.landmarks.spawn
	game.car.place_at(sp.car_pos + sp.car_dir * 10.0, sp.car_dir)
	await get_tree().create_timer(0.5).timeout
	t.couple(game.car)
	await get_tree().create_timer(1.0).timeout
	var d0: float = t.hitch_point().distance_to(game.car.global_transform * Truck.HITCH)
	print("TRAILER angekuppelt: %s, Abstand Kupplung %.2f m" % [t.towed_by != null, d0])
	# Wild aufladen (ohne Gurte)
	for k in 2:
		var deer := game.spawner.spawn("deer", game.player.global_position + Vector3(3 + k, 0, 0), 8800 + k, k)
		await get_tree().physics_frame
		var c: Carcass = deer.die(Vector3.RIGHT)
		await get_tree().physics_frame
		t.load_cargo(c)
	print("TRAILER Ladung: %d" % t.cargo.size())
	var start := t.global_position
	game.player.global_position = game.car.global_position + Vector3(2, 0.5, 0)
	game.enter_vehicle(game.car, "driver")
	Input.action_press("move_forward")
	await get_tree().create_timer(4.0).timeout
	Input.action_release("move_forward")
	var moved := t.global_position.distance_to(start)
	var gap := t.hitch_point().distance_to(game.car.global_transform * Truck.HITCH)
	print("TRAILER gezogen: %.0f m, Pickup %.0f km/h, Kupplungsabstand %.2f m, aufrecht %.2f, Ladung %d" % [moved, game.car.speed_kmh(), gap, t.global_basis.y.y, t.cargo.size()])
	# Holperstrecke simulieren: ohne Gurte fällt etwas runter, mit Gurten nicht
	t.set_strapped(false)
	var lost := 0
	t.cargo_lost.connect(func(_n): lost += 1)
	t.world = null
	t.strapped = false
	print("TRAILER Gurte: Pickup %s, Anhänger %s" % [game.car.strapped, t.strapped])
	t.set_strapped(true)
	t._check_cargo(1.0)
	print("TRAILER festgezurrt, Ladung bleibt: %d" % t.cargo.size())
	game.car.linear_velocity = Vector3.ZERO
	game.exit_vehicle()
	t.uncouple()
	print("TRAILER abgekuppelt: %s" % (t.towed_by == null))
	if args.has("shot"):
		# Blick auf Pickup und Anhänger
		if game.rig.first_person:
			game.rig.toggle_view()
		var dv: Vector3 = t.global_position - game.player.global_position
		game.rig.yaw = atan2(-dv.x, -dv.z) + 0.5
		game.rig.pitch = -0.35
		game.rig.distance = 10.0


## Hausinnenraum: Treppe, Truhe, neue Möbel (-- --housetest)
func _house_test(game: Game) -> void:
	GameState.money = 100000
	game.buy_house(4)  # Kärntner Bauernhaus, zwei Stockwerke
	game.hud.close_dialog()
	await get_tree().create_timer(0.5).timeout
	var h: Node3D = game.house_nodes[GameState.house]
	print("HAUS gebaut, Stockwerke: %d" % h.get_meta("levels"))
	# zur Treppe und hinauf laufen
	var bottom: Vector3 = h.global_transform * Vector3(-h.get_meta("half").x + 0.15 + HouseBuilder.STAIR_W * 0.5, 0.5, HouseBuilder.STAIR_FRONT + 0.6)
	game.player.global_position = bottom
	game.player.reset_physics_interpolation()
	var back: Vector3 = -h.global_basis.z
	game.rig.yaw = atan2(-back.x, -back.z)
	await get_tree().create_timer(0.3).timeout
	var y0 := game.player.global_position.y
	Input.action_press("move_forward")
	await get_tree().create_timer(2.6).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.5).timeout
	var climbed := game.player.global_position.y - y0
	print("HAUS Treppe: %.1f m hochgestiegen (Ziel %.1f), im Haus: %s" % [climbed, HouseBuilder.WALL_H, game.inside_own_house(game.player.global_position)])
	# Truhe: einlagern und herausnehmen
	GameState.give("meat", 5)
	ChestMenu.open(game, "Truhe", GameState.house_chest, func(): pass)
	GameState.take("meat", 5)
	GameState.house_chest["meat"] = 5
	Menus.close_all(game.hud)
	print("HAUS Truhe: %s" % [GameState.house_chest])
	# neue Möbel aufstellen
	var inside: Vector3 = h.global_transform * Vector3(1.0, 0.2, 0.5)
	for t in ["chest", "plant", "pelt_rug"]:
		print("  %s erlaubt: %s" % [t, Placeables.check(t, inside, game).is_empty()])
		Net.request_place({uid = GameState.new_uid(), type = t, pos = [inside.x, inside.y, inside.z], rot = 0.0, owner = GameState.player_name, data = {}})
		inside += h.global_basis.x * 1.3
	await get_tree().process_frame
	print("HAUS aufgestellt: %d Dinge" % GameState.placed.size())
	if args.has("shot"):
		game.player.global_position = h.global_transform * Vector3(0.5, 0.5, 2.5)
		game.player.reset_physics_interpolation()
		var look: Vector3 = -h.global_basis.z
		game.rig.yaw = atan2(-look.x, -look.z) + 0.35
		game.rig.pitch = -0.15
		await get_tree().create_timer(1.0).timeout


static func _floats(s: String) -> Array:
	return Array(s.split(",")).map(func(x): return float(x))


## Sauber beenden: erst vom Server trennen (sonst stürzt Godot ohne Fenster ab)
func _quit() -> void:
	await Net.quit_game()
