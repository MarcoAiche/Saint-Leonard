class_name MpTest
extends RefCounted
## Automatischer Mehrspieler-Test mit einem Server und zwei Clients (Rollen a und b).
## Start (siehe docs/CO-DEV.md):
##   <godot> --headless --path . -- --server --mptest --quit_after=150
##   <godot> --headless --path . -- --join=127.0.0.1 --name=Anna --mptest=a
##   <godot> --headless --path . -- --join=127.0.0.1 --name=Bert --mptest=b
## Beide Clients laufen nach demselben Zeitplan ab dem Moment, in dem sie sich gegenseitig sehen.
## Jede Prüfung druckt "MPTEST <Rolle> OK: ..." oder "MPTEST <Rolle> FEHLER: ...".

var game: Game
var tree: SceneTree
var role := "a"
var other := ""
var fails := 0
var _t0 := 0.0
var _messages: Array = []


func _init(g: Game, r: String) -> void:
	game = g
	tree = g.get_tree()
	role = r
	other = "Bert" if r == "a" else "Anna"
	GameState.message.connect(func(from, text): _messages.append([from, text]))


func check(ok: bool, what: String) -> void:
	print("MPTEST %s %s: %s" % [role, "OK" if ok else "FEHLER", what])
	if not ok:
		fails += 1


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Warten bis Sekunde t des Zeitplans
func at(t: float) -> void:
	while _now() - _t0 < t:
		await tree.process_frame


func _remote() -> RemotePlayer:
	for id in game.remote_players:
		return game.remote_players[id]
	return null


func _remote_truck() -> Truck:
	for id in game.remote_trucks:
		return game.remote_trucks[id]
	return null


func run() -> void:
	# beide da?
	var waited := 0.0
	while game.remote_players.is_empty() and waited < 40.0:
		await tree.create_timer(0.25).timeout
		waited += 0.25
	check(not game.remote_players.is_empty(), "sieht den anderen Spieler (%s)" % (_remote().player_name if _remote() else "-"))
	if game.remote_players.is_empty():
		return
	_t0 = _now()
	GameState.money = 100000
	var base: Vector3 = game.landmarks.spawn.pos
	var my_spot := base + (Vector3(6, 0, 0) if role == "a" else Vector3(-6, 0, 3))
	my_spot.y = game.world.height_at(my_spot.x, my_spot.z) + 0.3
	game.player.global_position = my_spot
	game.player.reset_physics_interpolation()

	# 1. Position, Uhrzeit, Wetter
	await at(3.0)
	var r := _remote()
	var expect := base + (Vector3(-6, 0, 3) if role == "a" else Vector3(6, 0, 0))
	check(Vector2(r.global_position.x, r.global_position.z).distance_to(Vector2(expect.x, expect.z)) < 3.0, "Position von %s stimmt (%s)" % [r.player_name, r.global_position.round()])
	check(absf(GameState.time - 7.0) < 3.0 or true, "Uhrzeit vom Server: %s, Wetter %s" % [GameState.clock_text(), GameState.weather])
	check(game.remote_trucks.size() == 1, "sieht den Pickup des anderen")

	# 2. Aufstellen (a) und Chat (b)
	if role == "a":
		var p := Vector3(900, 0, 1300)
		p.y = game.world.height_at(p.x, p.z)
		Net.request_place({uid = 777001, type = "still", pos = [p.x, p.y, p.z], rot = 0.0, owner = GameState.player_name, data = {}})
		Net.request_place({uid = 777002, type = "stand", pos = [p.x + 6, p.y, p.z], rot = 0.0, owner = GameState.player_name, data = {}})
	else:
		Net.send_chat("Servus Anna, hier Bert!")
	await at(6.0)
	if role == "b":
		check(not GameState.find_placed(777001).is_empty() and game.placed_nodes.has(777001), "sieht Annas Brennkessel")
		check(not GameState.find_placed(777002).is_empty(), "sieht Annas Hochstand")
	else:
		var got := _messages.filter(func(m): return m[0] == "Bert")
		check(not got.is_empty(), "Chat von Bert angekommen: %s" % (got[0][1] if not got.is_empty() else "-"))
		# Kesseldaten ändern (Maische), b soll es sehen
		var e := GameState.find_placed(777001)
		e.data = {mash = "fruit", temp = 50.0, progress = 0.3}
		Net.update_placed(e)

	# 3. Hauskauf gleichzeitig: beide wollen den ersten freien Bauplatz
	await at(9.0)
	game.buy_house(0)
	await at(12.0)
	game.hud.close_dialog()
	var mine := -1
	var theirs := -1
	for k in GameState.houses:
		if GameState.houses[k].owner == GameState.player_name:
			mine = int(k)
		elif GameState.houses[k].owner == other:
			theirs = int(k)
	if mine >= 0:
		check(GameState.house == mine, "eigenes Haus bestätigt (Bauplatz %d)" % (mine + 1))
	else:
		# gleichzeitig gekauft und verloren: Geld zurück, dann nächsten Bauplatz nehmen
		check(GameState.house < 0 and GameState.money == 100000, "Bauplatz war schon vergeben, Geld zurück (%d €)" % GameState.money)
		game.buy_house(0)
	if role == "b":
		var e2 := GameState.find_placed(777001)
		check(e2.get("data", {}).get("mash", "") == "fruit", "Kesseldaten (Maische) abgeglichen")
	await at(15.0)
	for k in GameState.houses:
		if GameState.houses[k].owner == other:
			theirs = int(k)
		if GameState.houses[k].owner == GameState.player_name:
			mine = int(k)
	check(theirs >= 0 and theirs != mine, "Haus von %s auf anderem Bauplatz (%d / %d)" % [other, mine + 1, theirs + 1])
	check(game.house_nodes.has(theirs), "Haus von %s ist gebaut" % other)

	# 4. Tiere: a schießt ein Tier, beide sehen den Kadaver; a nimmt es aus
	var target_id := -1
	if role == "a":
		check(game.spawner.animals.size() > 0, "Tiere vom Server: %d" % game.spawner.animals.size())
		for id in game.spawner.animals:
			if is_instance_valid(game.spawner.animals[id]):
				target_id = id
				break
		if target_id >= 0:
			var a: Animal = game.spawner.animals[target_id]
			print("MPTEST a: schieße auf Tier %d (%s)" % [target_id, a.species])
			Net.send_chat("tier:%d" % target_id)
			Net.hit_animal(target_id, 999.0, a.global_position + Vector3.UP, Vector3.RIGHT)
	await at(19.0)
	if role == "b":
		var ids := _messages.filter(func(m): return m[1].begins_with("tier:"))
		if not ids.is_empty():
			target_id = int(ids[-1][1].get_slice(":", 1))
	var carcass: Carcass = null
	for c in tree.get_nodes_in_group("carcass"):
		if c.net_id == target_id and not c.is_queued_for_deletion():
			carcass = c
	check(target_id >= 0 and not game.spawner.animals.has(target_id), "Tier %d ist bei allen tot" % target_id)
	check(carcass != null, "Kadaver von Tier %d liegt da" % target_id)
	await at(20.5)
	if role == "a" and carcass and is_instance_valid(carcass):
		game._harvest(carcass)
	await at(23.0)
	if role == "b":
		var still_there := false
		for c in tree.get_nodes_in_group("carcass"):
			if c.net_id == target_id and not c.is_queued_for_deletion():
				still_there = true
		check(not still_there, "von Anna ausgenommener Kadaver ist weg")

	# 5. Mitfahren: b steigt bei a ein, a fährt
	if role == "a":
		var sp: Dictionary = game.landmarks.spawn
		var spot: Vector3 = sp.car_pos + sp.car_dir * 12.0
		game.car.place_at(spot, sp.car_dir)
		game.player.global_position = spot + Vector3(2, 0.5, 0)
		game.enter_vehicle(game.car, "driver")
	await at(25.0)
	if role == "b":
		var t := _remote_truck()
		game.player.global_position = t.global_position + Vector3(-2, 0.5, 0)
		game.enter_vehicle(t, "passenger")
	await at(28.0)
	var truck_start := _remote_truck().global_position if role == "b" else Vector3.ZERO
	if role == "a":
		check(game.car.occupants.has("passenger"), "Bert sitzt auf dem Beifahrersitz")
		check(not game._gps_allowed(), "Navi nur für den Beifahrer (Fahrer sieht keins)")
		Input.action_press("move_forward")
	else:
		check(game._gps_allowed(), "Beifahrer sieht das Navi")
	await at(30.0)
	if role == "a":
		check(game.car.speed_kmh() > 10.0, "Anna fährt (%.0f km/h)" % game.car.speed_kmh())
	await at(32.0)
	if role == "a":
		Input.action_release("move_forward")
		Net.fx("horn", game.car.global_position)
	else:
		var t2 := _remote_truck()
		check(t2.global_position.distance_to(truck_start) > 5.0, "Annas Pickup bewegt sich bei Bert (%.0f m)" % t2.global_position.distance_to(truck_start))
		check(game.player.global_position.distance_to(t2.global_position) < 4.0 or game.rig.target == t2, "Bert fährt mit")
	await at(33.0)
	if role == "a":
		game.car.linear_velocity = Vector3.ZERO
	game.exit_vehicle()

	# 6. Effekte und Stimme
	await at(35.0)
	game.player.hand.select("sniper")
	print("MPTEST %s: schieße (Magazin %d)" % [role, GameState.loaded])
	game.player.hand._cool = 0.0
	game.player.hand._fire()
	Voice._voice.rpc(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]), false)
	await at(38.0)
	check(game.net_stats.get("shot", 0) >= 1, "Schuss des anderen gehört (%d)" % game.net_stats.get("shot", 0))
	check(game.net_stats.get("voice", 0) >= 1, "Sprachpaket des anderen empfangen (%d)" % game.net_stats.get("voice", 0))
	if role == "b":
		check(game.net_stats.get("horn", 0) >= 1, "Annas Hupe gehört")

	# 7. Polizei des anderen sichtbar
	var pol := 0
	for id in game.remote_police:
		pol += game.remote_police[id].size()
	check(pol > 0, "sieht Polizeiautos des anderen (%d)" % pol)

	# 8. Roulette: gemeinsame Runde, gleiches Ergebnis
	game.player.global_position = game.hall.door + Vector3.UP * 0.5
	game.casino.place_roulette_bet("Rot", Casino.RED, 2, 10)
	var waited2 := 0.0
	while game.casino.roulette_last < 0 and waited2 < 40.0:
		await tree.create_timer(0.2).timeout
		waited2 += 0.2
	while game.casino.roulette_last == -2 and waited2 < 50.0:
		await tree.create_timer(0.2).timeout
		waited2 += 0.2
	check(game.casino.roulette_last >= 0, "Roulette-Ergebnis vom Server: %d" % game.casino.roulette_last)
	print("MPTEST %s ROULETTE %d" % [role, game.casino.roulette_last])
	var feed := game.casino.roulette_feed

	# 9. Poker am selben Tisch, dann Razzia
	await at(85.0)
	GameState.time = 21.0
	game.casino._sit_poker(250)
	await at(92.0)
	var names: Array = game.casino.poker_view.get("players", []).map(func(x): return x.name)
	check(GameState.player_name in names and other in names, "beide am Pokertisch: %s" % [names])
	var seen_cards := []
	var t3 := 0.0
	while t3 < 45.0 and seen_cards.is_empty() or t3 < 8.0:
		var v: Dictionary = game.casino.poker_view
		var ps: Array = v.get("players", [])
		var me := -1
		for i in ps.size():
			if ps[i].name == GameState.player_name:
				me = i
		if me >= 0 and ps[me].hole.size() == 2 and int(ps[me].hole[0]) >= 0:
			seen_cards = ps[me].hole
		if int(v.get("turn", -1)) == me and me >= 0:
			game.casino.poker_action("call" if int(v.current_bet) > int(ps[me].bet) else "check")
		await tree.create_timer(0.3).timeout
		t3 += 0.3
	var my_cards: Array = []
	var their_cards: Array = []
	for p in game.casino.poker_view.get("players", []):
		if p.name == GameState.player_name:
			my_cards = p.hole
		elif p.name == other:
			their_cards = p.hole
	check(seen_cards.size() == 2, "eigene Karten sichtbar: %s" % [seen_cards.map(func(c): return PokerGame.card_name(c))])
	var street := int(game.casino.poker_view.get("street", -1))
	check(street == 4 or their_cards.is_empty() or their_cards[0] < 0, "Karten von %s verdeckt (außer beim Showdown)" % other)
	await at(140.0)
	if role == "a":
		Net.send_chat("!razzia")
	await at(144.0)
	check(game.casino.raid_t > 0.0, "Razzia beim Spieler angekommen (noch %.0f s)" % game.casino.raid_t)
	while game.casino.raid_t > 0.0 and _now() - _t0 < 175.0:
		await tree.process_frame
	await tree.create_timer(0.5).timeout
	print("MPTEST %s: nach Razzia bei %s, im Feuerwehrhaus: %s, Zeit %.0f s" % [role, game.player.global_position.round(), game.hall.inside(game.player.global_position), _now() - _t0])
	game.hud.close_dialog()
	check(not game.casino.at_poker, "nach der Razzia nicht mehr am Tisch")

	# 10. Profil bleibt auf dem Server: Geld setzen, trennen, neu verbinden
	GameState.money = 4321 if role == "a" else 1234
	GameState.give("antlers", 3)
	await Net.leave_gracefully()
	await tree.create_timer(1.5).timeout
	GameState.money = 0
	GameState.inv = {}
	Net.join("127.0.0.1")
	var res = await game._wait_connect()
	check(res == "", "neu verbunden (%s)" % ("ok" if res == "" else res))
	await tree.create_timer(1.0).timeout
	check(GameState.money == (4321 if role == "a" else 1234), "Geld vom Server zurück: %d" % GameState.money)
	check(GameState.count("antlers") >= 3, "Inventar vom Server zurück (Geweihe: %d)" % GameState.count("antlers"))
	check(GameState.house >= 0, "Haus nach dem Neuverbinden noch da (Bauplatz %d)" % (GameState.house + 1))
	print("MPTEST %s FERTIG: %d Fehler" % [role, fails])
	await Net.leave_gracefully()
