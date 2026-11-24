class_name PoliceManager
extends Node3D
## Polizei: Streifen auf Haupt- und (selten) Dorfstraßen, eine feste Kontrolle vor der Stadt,
## Anhalten, Alkotest, Durchsuchen, Bestechen, Reden oder Abhauen, Verfolgungsjagden.
## Feld- und Bergwege werden nie bestreift; wer dorthin flüchtet, hängt die Polizei leichter ab.
## Im Mehrspieler-Modus simuliert jeder Spieler seine eigene Polizei (wird nicht abgeglichen).

enum Phase { NONE, PULL_OVER, CONTROL, CHASE }

const ENABLED := false
const MAX_PATROLS := 2
const SPAWN_MIN := 350.0
const SPAWN_MAX := 750.0

var game: Node
var world: WorldBuilder
var landmarks: Landmarks
var patrols: Array[PoliceCar] = []
var checkpoint_car: PoliceCar
var phase := Phase.NONE
var chaser: PoliceCar
var open_fines := 0
var _timer := 2.0
var _phase_t := 0.0
var _lost_t := 0.0
var _busted_t := 0.0
var _checked_t := 0.0
var _endpoints := {}  # gerundeter Endpunkt -> [Straßen-Index]
var _rng := RandomNumberGenerator.new()


func setup(g: Node, w: WorldBuilder, lm: Landmarks) -> void:
	game = g
	world = w
	landmarks = lm
	_rng.randomize()
	if not ENABLED:
		return
	for ri in world.data.roads.size():
		var r: Dictionary = world.data.roads[ri]
		if r.tunnel or r.tier == 0 or r.tier > WorldBuilder.TIER_VILLAGE or r.kind.begins_with("motorway"):
			continue
		for e in [r.pts[0], r.pts[-1]]:
			var k := _key(Vector2(e[0], e[1]))
			if not _endpoints.has(k):
				_endpoints[k] = []
			_endpoints[k].append(ri)
	if not landmarks.checkpoint.is_empty():
		checkpoint_car = _spawn_car()
		var cp: Vector3 = landmarks.checkpoint.pos
		var cd: Vector2 = landmarks.checkpoint.dir
		var side := Vector2(-cd.y, cd.x)
		var pos := Vector2(cp.x, cp.z) + side * 6.0
		checkpoint_car.place_at(Vector3(pos.x, 0, pos.y), Vector3(cd.x, 0, cd.y))
		checkpoint_car.mode = PoliceCar.Mode.PARKED
		var officer := Npc.new("Polizei", {uniform = true, hat = "police"})
		add_child(officer)
		var op := Vector2(cp.x, cp.z) + side * 3.0 + cd * 3.0
		officer.global_position = Vector3(op.x, world.height_at(op.x, op.y), op.y)


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


func _spawn_car() -> PoliceCar:
	var c := PoliceCar.new()
	c.world = world
	add_child(c)
	return c


## Route über zusammenhängende Straßen (ca. 2 km), beginnend bei einer Straße
func _make_route(start_road: int, start_pt: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r: Dictionary = world.data.roads[start_road]
	var pts := WorldBuilder.to_v2_array(r.pts)
	# in die Richtung fahren, die mehr Strecke hat
	var k0 := 0
	for k in pts.size():
		if pts[k].distance_to(start_pt) < pts[k0].distance_to(start_pt):
			k0 = k
	if k0 > pts.size() / 2:
		pts.reverse()
		k0 = pts.size() - 1 - k0
	for k in range(k0, pts.size()):
		out.append(pts[k])
	var total := 0.0
	var current := start_road
	for i in 12:
		var end := out[out.size() - 1]
		var options: Array = _endpoints.get(_key(end), []).filter(func(x): return x != current)
		if options.is_empty():
			break
		# Hauptstraßen bevorzugen
		options.sort_custom(func(a, b): return world.data.roads[a].tier < world.data.roads[b].tier)
		var nxt: int = options[0] if _rng.randf() < 0.7 else options[_rng.randi() % options.size()]
		var np := WorldBuilder.to_v2_array(world.data.roads[nxt].pts)
		if np[0].distance_to(end) > np[np.size() - 1].distance_to(end):
			np.reverse()
		for k in range(1, np.size()):
			total += np[k].distance_to(np[k - 1])
			out.append(np[k])
		current = nxt
		if total > 2000.0:
			break
	return out


func _focus() -> Node3D:
	return game.car if game.driving else game.player


func _process(delta: float) -> void:
	if not ENABLED or get_tree().paused or not game.player:
		return
	_timer -= delta
	_checked_t = maxf(0.0, _checked_t - delta)
	match phase:
		Phase.PULL_OVER:
			_update_pull_over(delta)
		Phase.CHASE:
			_update_chase(delta)
	if _timer > 0.0:
		return
	_timer = 0.5
	_manage_patrols()
	if phase == Phase.NONE and game.driving:
		_watch()


func _manage_patrols() -> void:
	var f := _focus().global_position
	for c in patrols.duplicate():
		if not is_instance_valid(c):
			patrols.erase(c)
			continue
		if c.global_position.distance_to(f) > 1300.0 and c != chaser:
			patrols.erase(c)
			c.queue_free()
			continue
		if c.mode == PoliceCar.Mode.PATROL and c.route.size() < 2:
			var info := world.road_info(Vector2(c.global_position.x, c.global_position.z), 15.0)
			if info.road >= 0:
				c.route = _make_route(info.road, info.pos)
				c.route_i = 0
	var want := MAX_PATROLS + int(GameState.police_heat)
	if patrols.size() < want:
		_spawn_patrol(f)


func _spawn_patrol(f: Vector3) -> void:
	for attempt in 30:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var p := Vector2(f.x, f.z) + Vector2(cos(a), sin(a)) * d
		var info := world.road_info(p, 40.0)
		if info.road < 0 or info.tier == 0 or info.tier > WorldBuilder.TIER_VILLAGE:
			continue
		if info.tier == WorldBuilder.TIER_VILLAGE and _rng.randf() < 0.7:
			continue  # Dorfstraßen nur selten
		if world.data.roads[info.road].kind.begins_with("motorway") or world.border_distance(info.pos) < 50.0:
			continue
		var c := _spawn_car()
		c.place_at(Vector3(info.pos.x, 0, info.pos.y), Vector3(info.dir.x, 0, info.dir.y))
		c.route = _make_route(info.road, info.pos)
		c.cruise_kmh = 75.0 if info.tier == WorldBuilder.TIER_MAIN else 45.0
		patrols.append(c)
		return


## Verdächtiges Fahren erkennen
func _watch() -> void:
	var car: Truck = game.car
	var p := car.global_position
	var info := car.surface
	var v := absf(car.speed_kmh())
	# feste Kontrolle: jedes Fahrzeug wird aufgehalten
	if not landmarks.checkpoint.is_empty() and _checked_t <= 0.0:
		var cp: Vector3 = landmarks.checkpoint.pos
		if p.distance_to(cp) < 22.0:
			_start_pull_over(checkpoint_car, "Verkehrskontrolle! Bitte anhalten.")
			return
	for c in patrols:
		if not is_instance_valid(c):
			continue
		var d := c.global_position.distance_to(p)
		if d > 45.0:
			continue
		var reason := ""
		if info.tier == WorldBuilder.TIER_VILLAGE and v > 68.0:
			reason = "Zu schnell im Ortsgebiet"
		elif info.tier == WorldBuilder.TIER_MAIN and v > 118.0:
			reason = "Zu schnell"
		elif GameState.bac > 0.05 and _rng.randf() < 0.18 + GameState.drunkness() * 0.4:
			reason = "Schlangenlinien"
		elif GameState.is_night() and not car.lights_on and _rng.randf() < 0.3:
			reason = "Ohne Licht unterwegs"
		elif GameState.police_heat > 1.5 and _rng.randf() < 0.1:
			reason = "Fahndung"
		if not reason.is_empty():
			_start_pull_over(c, "Polizei: %s. Rechts ranfahren!" % reason)
			return


func _start_pull_over(c: PoliceCar, text: String) -> void:
	phase = Phase.PULL_OVER
	chaser = c
	_phase_t = 0.0
	_checked_t = 120.0
	if c != checkpoint_car:
		c.mode = PoliceCar.Mode.PURSUE
		c.target = game.car
		c.set_siren(true)
	game.hud.toast(text, 4.0)
	game.hud.set_alert("POLIZEI: Anhalten!")


func _update_pull_over(delta: float) -> void:
	_phase_t += delta
	if not is_instance_valid(chaser):
		_end()
		return
	var car: Truck = game.car
	var d := chaser.global_position.distance_to(car.global_position)
	if absf(car.speed_kmh()) < 5.0 and d < 28.0:
		_open_control(false)
		return
	var limit := 25.0 if chaser == checkpoint_car else 20.0
	if _phase_t > limit or (chaser == checkpoint_car and d > 60.0 and _phase_t > 2.0) or not game.driving:
		if not game.driving and d < 30.0:
			_open_control(false)
		else:
			_start_chase()


func _open_control(busted: bool) -> void:
	phase = Phase.CONTROL
	game.hud.set_alert("")
	var car: Truck = game.car
	var offences := []
	var fine := 0
	if GameState.bac > 0.05:
		var pm := GameState.promille()
		var f := 300 if pm < 1.2 else 800
		offences.append("Alkotest: %.1f Promille (%d €)" % [pm, f])
		fine += f
	var shine_inv := GameState.count("moonshine")
	var shine_cargo := 0
	for n in car.cargo:
		if n.get_meta("kind", "") == "moonshine":
			shine_cargo += int(n.get_meta("bottles", 1))
	var search := busted or _rng.randf() < 0.35 + GameState.police_heat * 0.15
	if search and (shine_inv + shine_cargo) > 0:
		offences.append("Schwarzgebrannter gefunden: %d Flaschen (500 €, beschlagnahmt)" % (shine_inv + shine_cargo))
		fine += 500
	if busted:
		offences.append("Flucht vor der Polizei (400 €)")
		fine += 400
	var text := "Führerschein und Zulassung, bitte.\n\n"
	if offences.is_empty():
		text += "Alles in Ordnung. Gute Fahrt!"
		game.hud.show_dialog("Verkehrskontrolle", text, [["Danke, Herr Inspektor", func(): _end()]])
		return
	text += "\n".join(offences) + "\n\nStrafe gesamt: %d €" % fine
	var confiscate := func():
		if search:
			GameState.take("moonshine", shine_inv)
			for n in car.cargo.duplicate():
				if n.get_meta("kind", "") == "moonshine":
					car.cargo.erase(n)
					n.queue_free()
	var opts := [
		["Kooperieren (%d € zahlen)" % fine, func():
			confiscate.call()
			_fine(fine)
			_end()],
		["Bestechen (200 €)", func(): _bribe(fine, confiscate)],
		["Reden und rausreden", func(): _talk(fine, confiscate)],
	]
	if not busted:
		opts.append(["Gas geben und abhauen!", func(): _start_chase()])
	game.hud.show_dialog("Verkehrskontrolle", text, opts)


func _fine(v: int) -> void:
	if not GameState.pay(v):
		open_fines += v - maxi(GameState.money, 0)
		GameState.pay(maxi(GameState.money, 0))
		game.hud.toast("Zu wenig Geld: %d € offene Strafe (Polizei in der Stadt)" % open_fines, 4.0)
	GameState.stats.fines += v
	GameState.police_heat = maxf(0.0, GameState.police_heat - 0.5)


func _bribe(fine: int, confiscate: Callable) -> void:
	if not GameState.pay(200):
		game.hud.show_dialog("Bestechung", "Mit leerer Brieftasche besticht man niemanden.", [["Zahlen (%d €)" % fine, func():
			confiscate.call()
			_fine(fine)
			_end()]])
		return
	if _rng.randf() < 0.55 - GameState.police_heat * 0.1:
		game.hud.show_dialog("Bestechung", "Der Inspektor schaut sich um und steckt das Geld ein.\n\"Ich hab nix gesehen. Fahrn's vorsichtig.\"", [["Weiterfahren", func(): _end()]])
	else:
		game.hud.show_dialog("Bestechung", "\"Wollen Sie mich bestechen?!\"\nZusätzlich 300 € wegen Bestechungsversuch.", [["Zahlen (%d €)" % (fine + 300), func():
			confiscate.call()
			_fine(fine + 300)
			_end()]])


func _talk(fine: int, confiscate: Callable) -> void:
	var chance := 0.3
	if GameState.outfit.get("hat", "") in ["hunter", "hunter_gams"]:
		chance += 0.12  # mit Jägerhut glaubt man einem eher
	if _rng.randf() < chance:
		game.hud.show_dialog("Rausreden", "\"Na gut, heute drück ich ein Auge zu. Aber nur heute!\"", [["Danke!", func(): _end()]])
	else:
		game.hud.show_dialog("Rausreden", "\"Das glauben Sie ja selbst nicht.\"", [["Zahlen (%d €)" % fine, func():
			confiscate.call()
			_fine(fine)
			_end()]])


func _start_chase() -> void:
	phase = Phase.CHASE
	game.hud.close_dialog()
	_lost_t = 0.0
	_busted_t = 0.0
	GameState.police_heat += 1.0
	if not is_instance_valid(chaser) or chaser == checkpoint_car:
		# ein Streifenwagen nimmt die Verfolgung auf
		var c := _spawn_car()
		var fp: Vector3 = (checkpoint_car.global_position if is_instance_valid(checkpoint_car) else game.car.global_position - game.car.global_basis.z * 60.0)
		c.place_at(fp + Vector3(3, 0, 3), game.car.global_position - fp)
		patrols.append(c)
		chaser = c
	chaser.mode = PoliceCar.Mode.PURSUE
	chaser.target = game.car if game.driving else game.player
	chaser.set_siren(true)
	game.hud.set_alert("VERFOLGUNG! Hänge die Polizei ab (Feldwege helfen)")


func _update_chase(delta: float) -> void:
	if not is_instance_valid(chaser):
		_end()
		return
	var focus := _focus()
	chaser.target = game.car if game.driving else game.player
	var d := chaser.global_position.distance_to(focus.global_position)
	var on_dirt: bool = game.driving and (game.car.surface.tier == 0 or game.car.surface.tier >= WorldBuilder.TIER_DIRT)
	if d > 350.0 or (on_dirt and d > 110.0):
		_lost_t += delta
		if _lost_t > (6.0 if on_dirt else 10.0):
			game.hud.toast("Polizei abgehängt!", 3.0)
			chaser.set_siren(false)
			chaser.mode = PoliceCar.Mode.PATROL
			chaser.route = PackedVector2Array()
			_end()
			return
	else:
		_lost_t = 0.0
	var v: float = absf(game.car.speed_kmh()) if game.driving else 0.0
	if d < 10.0 and v < 4.0:
		_busted_t += delta
		if _busted_t > 2.5:
			chaser.set_siren(false)
			_open_control(true)
	else:
		_busted_t = 0.0


func _end() -> void:
	phase = Phase.NONE
	game.hud.set_alert("")
	if is_instance_valid(chaser) and chaser != checkpoint_car:
		chaser.set_siren(false)
		chaser.mode = PoliceCar.Mode.PATROL
		chaser.route = PackedVector2Array()
	chaser = null


## Polizei fährt zu einem Vorfall (Explosion, Schüsse im Ort)
func dispatch(pos: Vector3, reason: String) -> void:
	if not ENABLED:
		return
	GameState.police_heat += 0.6
	var c := _spawn_car()
	var info := world.road_info(Vector2(pos.x, pos.z) + Vector2(250, 0), 300.0)
	var start := Vector3(info.pos.x, 0, info.pos.y) if info.road >= 0 else pos + Vector3(250, 0, 0)
	c.place_at(start, pos - start)
	c.mode = PoliceCar.Mode.GOTO
	c.goto_pos = pos
	c.set_siren(true)
	patrols.append(c)
	GameState.notify("Polizeifunk", "Einsatz: %s" % reason)
	get_tree().create_timer(60.0).timeout.connect(func():
		if is_instance_valid(c):
			c.set_siren(false)
			if c.global_position.distance_to(game.player.global_position) < 70.0 and phase == Phase.NONE:
				chaser = c
				_open_control(true)
			else:
				c.mode = PoliceCar.Mode.PATROL
				c.route = PackedVector2Array())


## Offene Strafen bei der Polizei in der Stadt zahlen
func pay_open_fines() -> String:
	if open_fines <= 0:
		return "Keine offenen Strafen."
	var v := mini(open_fines, maxi(GameState.money, 0))
	GameState.pay(v)
	open_fines -= v
	return "%d € bezahlt, offen: %d €" % [v, open_fines]
