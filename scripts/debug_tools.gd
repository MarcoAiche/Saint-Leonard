extends Node
## Entwickler-Helfer (Autoload). Nur aktiv mit Startparametern nach "--":
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
	if args.has("showmenu"):
		await get_tree().create_timer(1.5).timeout
		if args.get("showmenu") == "saves":
			game.menu.page_saves()
		elif args.get("showmenu") == "settings":
			game.menu.page_settings()
		await get_tree().create_timer(0.5).timeout
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
		get_tree().quit()
		return
	if args.has("mptest") and Net.is_client():
		var t := MpTest.new(game, str(args.mptest))
		await t.run()
		get_tree().quit()
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
	get_tree().quit()


## Sucht Knoten mit ungültiger Position (NaN) und meldet sie einmal
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


static func _floats(s: String) -> Array:
	return Array(s.split(",")).map(func(x): return float(x))
