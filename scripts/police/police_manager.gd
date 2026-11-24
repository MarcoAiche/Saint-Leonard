class_name PoliceManager
extends Node3D
## Polizei: Streifen auf Haupt- und (selten) Dorfstraßen, Kontrollen, Verfolgungsjagden,
## Schuss-/Explosions-Einsätze, Festnahmen und Strafen.

enum Phase { NONE, PULL_OVER, CONTROL, CHASE }

const MAX_PATROLS_RADIUS := 200.0
const BASE_PATROLS := 3
const MAX_CHASERS := 6
const SPAWN_MIN := 160.0
const SPAWN_MAX := 500.0
const DESPAWN_DIST := 900.0
const WEAPON_IDS := ["pistol", "rifle", "assault_rifle", "sniper"]

## Vorgegebene Kontrollpunkte (Koordinaten + Fahrtrichtung + Favoriten-Gewicht).
## Wenn leer, wird der dynamische Punkt aus Landmarks verwendet.
const CHECKPOINT_SPOTS: Array[Dictionary] = []

var game: Node
var world: WorldBuilder
var landmarks: Landmarks
var patrols: Array[PoliceCar] = []
var chasers: Array[PoliceCar] = []
var checkpoint_car: PoliceCar
var active_checkpoint := {}
var phase := Phase.NONE
var chaser: PoliceCar
var open_fines := 0
var impounded_until := 0.0
var _timer := 2.0
var _phase_t := 0.0
var _lost_t := 0.0
var _busted_t := 0.0
var _checked_t := 0.0
var _hidden_roll_t := 0.0
var _chase_dist := 0.0
var _last_chase_pos := Vector3.ZERO
var _near_house_shots := 0
var _house_shot_limit := 6
var _shot_watch_cars: Array[Dictionary] = []
var _endpoints := {}
var _all_endpoints := {}
var _rng := RandomNumberGenerator.new()


func setup(g: Node, w: WorldBuilder, lm: Landmarks) -> void:
	game = g
	world = w
	landmarks = lm
	_rng.randomize()
	_house_shot_limit = _rng.randi_range(4, 15)
	for ri in world.data.roads.size():
		var r: Dictionary = world.data.roads[ri]
		if r.tunnel or r.tier == 0 or r.kind.begins_with("motorway"):
			continue
		for e in [r.pts[0], r.pts[-1]]:
			var k := _key(Vector2(e[0], e[1]))
			if not _all_endpoints.has(k):
				_all_endpoints[k] = []
			_all_endpoints[k].append(ri)
			if r.tier <= WorldBuilder.TIER_VILLAGE:
				if not _endpoints.has(k):
					_endpoints[k] = []
				_endpoints[k].append(ri)
	_spawn_checkpoint()
	var start_focus := Vector3(landmarks.spawn.pos)
	for i in 2:
		_spawn_patrol(start_focus)


func _spawn_checkpoint() -> void:
	if not CHECKPOINT_SPOTS.is_empty():
		var total_w := 0.0
		for s in CHECKPOINT_SPOTS:
			total_w += float(s.get("weight", 1.0))
		var pick := _rng.randf() * total_w
		var acc := 0.0
		for s in CHECKPOINT_SPOTS:
			acc += float(s.get("weight", 1.0))
			if pick <= acc:
				var p2: Vector2 = s.pos
				active_checkpoint = {
					pos = Vector3(p2.x, world.height_at(p2.x, p2.y), p2.y),
					dir = (s.dir as Vector2).normalized(),
				}
				break
	elif not landmarks.checkpoint.is_empty():
		active_checkpoint = landmarks.checkpoint
	if active_checkpoint.is_empty():
		return
	checkpoint_car = _spawn_car()
	var cp: Vector3 = active_checkpoint.pos
	var cd: Vector2 = active_checkpoint.dir
	var side := Vector2(-cd.y, cd.x)
	var pos := Vector2(cp.x, cp.z) + side * 6.0
	checkpoint_car.place_at(Vector3(pos.x, 0, pos.y), Vector3(cd.x, 0, cd.y))
	checkpoint_car.mode = PoliceCar.Mode.PARKED
	var officer := Npc.new("Polizei", {uniform = true, hat = "police"})
	add_child(officer)
	var op := Vector2(cp.x, cp.z) + side * 2.5 + cd * 2.0
	officer.global_position = Vector3(op.x, world.height_at(op.x, op.y), op.y)


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))


func _spawn_car() -> PoliceCar:
	var c := PoliceCar.new()
	c.world = world
	add_child(c)
	return c


func _make_route(start_road: int, start_pt: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r: Dictionary = world.data.roads[start_road]
	var pts := WorldBuilder.to_v2_array(r.pts)
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
		var nxt: int = options[_rng.randi() % options.size()]
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


func _make_route_to(from_pt: Vector2, to_pt: Vector2, allow_dirt := false) -> PackedVector2Array:
	var start_info := world.road_info(from_pt, 80.0)
	if start_info.road < 0:
		return PackedVector2Array()
	var goal_info := world.road_info(to_pt, 400.0)
	var goal_pt: Vector2 = goal_info.pos if goal_info.road >= 0 else to_pt
	var goal_road: int = goal_info.road
	if start_info.road == goal_road:
		var pts := WorldBuilder.to_v2_array(world.data.roads[start_info.road].pts)
		var k0 := 0
		var k1 := 0
		for k in pts.size():
			if pts[k].distance_to(start_info.pos) < pts[k0].distance_to(start_info.pos):
				k0 = k
			if pts[k].distance_to(goal_pt) < pts[k1].distance_to(goal_pt):
				k1 = k
		var single := PackedVector2Array()
		var step := 1 if k1 >= k0 else -1
		var idx := k0
		while true:
			single.append(pts[idx])
			if idx == k1:
				break
			idx += step
		if single.size() >= 2:
			return single
	var ep_map: Dictionary = _all_endpoints if allow_dirt else _endpoints
	var g_score := {}
	var parent := {}
	var closed := {}
	var open: Array[Dictionary] = []
	var s_pts := WorldBuilder.to_v2_array(world.data.roads[start_info.road].pts)
	var start_key := _key(start_info.pos)
	for end_pt in [s_pts[0], s_pts[-1]]:
		var ek := _key(end_pt)
		var d0: float = (start_info.pos as Vector2).distance_to(end_pt)
		g_score[ek] = d0
		parent[ek] = {prev = start_key, road = start_info.road, to_pt = end_pt}
		open.append({key = ek, pt = end_pt, f = d0 + end_pt.distance_to(goal_pt)})
	var best_key := start_key
	var best_h: float = (start_info.pos as Vector2).distance_to(goal_pt)
	var iters := 0
	while not open.is_empty() and iters < 180:
		iters += 1
		var bi := 0
		for j in range(1, open.size()):
			if open[j].f < open[bi].f:
				bi = j
		var cur: Dictionary = open[bi]
		open.remove_at(bi)
		var ck: Vector2i = cur.key
		if closed.has(ck):
			continue
		closed[ck] = true
		var cp: Vector2 = cur.pt
		var h := cp.distance_to(goal_pt)
		if h < best_h:
			best_h = h
			best_key = ck
		if h < 35.0:
			break
		for ri in ep_map.get(ck, []):
			var np := WorldBuilder.to_v2_array(world.data.roads[ri].pts)
			var end_pt := np[-1] if np[0].distance_to(cp) < np[-1].distance_to(cp) else np[0]
			var nk := _key(end_pt)
			if closed.has(nk):
				continue
			var seg_len := 0.0
			for k in range(1, np.size()):
				seg_len += np[k].distance_to(np[k - 1])
			var ng: float = float(g_score.get(ck, INF)) + seg_len
			if ng < float(g_score.get(nk, INF)):
				g_score[nk] = ng
				parent[nk] = {prev = ck, road = ri, to_pt = end_pt}
				open.append({key = nk, pt = end_pt, f = ng + end_pt.distance_to(goal_pt)})
	var chain: Array[Dictionary] = []
	var trace := best_key
	while parent.has(trace) and trace != start_key:
		var edge: Dictionary = parent[trace]
		chain.append(edge)
		trace = edge.prev
		if chain.size() > 60:
			break
	chain.reverse()
	if chain.is_empty():
		var k0 := 0
		var k1 := 0
		for k in s_pts.size():
			if s_pts[k].distance_to(start_info.pos) < s_pts[k0].distance_to(start_info.pos):
				k0 = k
			if s_pts[k].distance_to(goal_pt) < s_pts[k1].distance_to(goal_pt):
				k1 = k
		var fallback := PackedVector2Array()
		var step := 1 if k1 >= k0 else -1
		var idx := k0
		while true:
			fallback.append(s_pts[idx])
			if idx == k1:
				break
			idx += step
		return fallback
	var out := PackedVector2Array()
	var cur_pt: Vector2 = start_info.pos
	for ei in chain.size():
		var edge := chain[ei]
		var np := WorldBuilder.to_v2_array(world.data.roads[edge.road].pts)
		var target_end: Vector2 = edge.to_pt
		if np[0].distance_to(target_end) < np[-1].distance_to(target_end):
			np.reverse()
		var start_k := 0
		if ei == 0:
			for k in np.size():
				if np[k].distance_to(cur_pt) < np[start_k].distance_to(cur_pt):
					start_k = k
		for k in range(start_k, np.size()):
			var pt := np[k]
			if out.is_empty() or out[-1].distance_to(pt) > 1.0:
				out.append(pt)
		cur_pt = target_end
	return out


func _focus() -> Node3D:
	return game.car if game.driving else game.player


func cool_heat() -> void:
	GameState.police_heat = 0.0


func _process(delta: float) -> void:
	if get_tree().paused or not game.player:
		return
	_timer -= delta
	_checked_t = maxf(0.0, _checked_t - delta)
	_hidden_roll_t = maxf(0.0, _hidden_roll_t - delta)
	_update_shot_watches(delta)
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


func _update_shot_watches(delta: float) -> void:
	var p := _focus().global_position
	var v: float = absf(game.car.speed_kmh()) if game.driving else game.player.velocity.length() * 3.6
	for w in _shot_watch_cars.duplicate():
		if not is_instance_valid(w.car):
			_shot_watch_cars.erase(w)
			continue
		var c: PoliceCar = w.car
		w.ttl -= delta
		if w.ttl <= 0.0:
			c.set_siren(false)
			c.mode = PoliceCar.Mode.PATROL
			c.route = PackedVector2Array()
			_shot_watch_cars.erase(w)
			continue
		if c.global_position.distance_to(p) < 16.0 and v < 4.0 and phase == Phase.NONE:
			w.stand_t += delta
			if w.stand_t >= 5.0:
				_shot_watch_cars.erase(w)
				chaser = c
				_arrest(true, 1000, "Schusswaffengebrauch / Polizei-Einsatz")
		else:
			w.stand_t = 0.0


func _manage_patrols() -> void:
	var f := _focus().global_position
	var nearby := 0
	for c in patrols.duplicate():
		if not is_instance_valid(c):
			patrols.erase(c)
			continue
		var d: float = c.global_position.distance_to(f)
		if d > DESPAWN_DIST and c != chaser and not chasers.has(c) and c.mode == PoliceCar.Mode.PATROL:
			patrols.erase(c)
			c.queue_free()
			continue
		if d <= MAX_PATROLS_RADIUS:
			nearby += 1
		if c.mode == PoliceCar.Mode.PATROL and c.route.size() < 2:
			var info := world.road_info(Vector2(c.global_position.x, c.global_position.z), 15.0)
			if info.road >= 0:
				c.route = _make_route(info.road, info.pos)
				c.route_i = 0
	var max_near := 1
	if GameState.police_heat >= 2.0:
		max_near = 2
	var want_total := mini(5, BASE_PATROLS + int(GameState.police_heat * 0.5))
	if patrols.size() < want_total:
		_spawn_patrol(f, nearby >= max_near)


func _spawn_patrol(f: Vector3, outside_near := false) -> void:
	for attempt in 30:
		var a := _rng.randf() * TAU
		var min_d := 215.0 if outside_near else SPAWN_MIN
		var d := _rng.randf_range(min_d, SPAWN_MAX)
		var p := Vector2(f.x, f.z) + Vector2(cos(a), sin(a)) * d
		var info := world.road_info(p, 50.0)
		if info.road < 0 or info.tier == 0 or info.tier > WorldBuilder.TIER_VILLAGE:
			continue
		if world.data.roads[info.road].kind.begins_with("motorway") or world.border_distance(info.pos) < 50.0:
			continue
		if outside_near and info.pos.distance_to(Vector2(f.x, f.z)) < MAX_PATROLS_RADIUS:
			continue
		var near_spot := 0
		for existing in patrols:
			if is_instance_valid(existing) and existing.global_position.distance_to(Vector3(info.pos.x, existing.global_position.y, info.pos.y)) < MAX_PATROLS_RADIUS:
				near_spot += 1
		if near_spot >= 2:
			continue
		var route := _make_route(info.road, info.pos)
		if route.size() < 2:
			continue
		var fwd := (route[1] - route[0]).normalized()
		if fwd.length_squared() < 0.01:
			fwd = info.dir
		var c := _spawn_car()
		c.place_at(Vector3(info.pos.x, 0, info.pos.y), Vector3(fwd.x, 0, fwd.y))
		c.route = route
		c.route_i = 0
		c.cruise_kmh = 75.0 if info.tier == WorldBuilder.TIER_MAIN else 45.0
		patrols.append(c)
		return


func _moonshine_counts(car: Truck) -> Dictionary:
	var inv := GameState.count("moonshine")
	var cargo := 0
	for n in car.cargo:
		if n.get_meta("kind", "") == "moonshine":
			cargo += int(n.get_meta("bottles", 1))
	var in_hand: bool = is_instance_valid(game.player) and game.player.hand != null and game.player.hand.slot == "moonshine"
	return {inv = inv, cargo = cargo, open = in_hand or cargo > 0, hidden = inv > 0 and not in_hand}


func _watch() -> void:
	var car: Truck = game.car
	var p := car.global_position
	var info := car.surface
	var v := absf(car.speed_kmh())
	if not active_checkpoint.is_empty() and _checked_t <= 0.0:
		var cp: Vector3 = active_checkpoint.pos
		var cd: Vector2 = active_checkpoint.dir
		var fwd := Vector2(car.global_basis.z.x, car.global_basis.z.z)
		if p.distance_to(cp) < 24.0 and fwd.dot(cd) > -0.2:
			_checked_t = 90.0
			if _rng.randf() < 0.80:
				_start_pull_over(checkpoint_car, "Verkehrskontrolle! Bitte anhalten.", true)
				return
	var shine := _moonshine_counts(car)
	var crashed := (Time.get_ticks_msec() * 0.001 - car.last_crash_t) < 4.0
	for c in patrols:
		if not is_instance_valid(c):
			continue
		if c.global_position.distance_to(p) > 50.0:
			continue
		var reason := ""
		if info.tier == WorldBuilder.TIER_VILLAGE and v > 65.0:
			reason = "Zu schnell im Ortsgebiet"
		elif info.tier == WorldBuilder.TIER_MAIN and v > 118.0:
			reason = "Zu schnell"
		elif GameState.bac > 0.05:
			reason = "Schlangenlinien / Alkoholverdacht"
		elif GameState.is_night() and not car.lights_on:
			reason = "Ohne Licht unterwegs"
		elif crashed:
			reason = "Unfall / Von der Fahrbahn abgekommen"
		elif shine.open:
			reason = "Verdächtige Ladung (Schwarzgebrannter)"
		elif shine.hidden and _hidden_roll_t <= 0.0:
			_hidden_roll_t = 12.0
			if _rng.randf() < 0.60:
				reason = "Routinekontrolle"
		elif GameState.police_heat > 1.5:
			reason = "Fahndung"
		if not reason.is_empty():
			_start_pull_over(c, "Polizei: %s! Sofort anhalten!" % reason, false)
			return


func _start_pull_over(c: PoliceCar, text: String, is_checkpoint := false) -> void:
	phase = Phase.PULL_OVER
	chaser = c
	_phase_t = 0.0
	_checked_t = 120.0
	c.set_meta("is_checkpoint", is_checkpoint)
	if c != checkpoint_car:
		c.mode = PoliceCar.Mode.PURSUE
		c.target = game.car
		c.set_siren(true)
	game.hud.toast(text, 4.0)
	game.hud.set_alert("POLIZEI: Sofort anhalten!")


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
	var is_cp := bool(chaser.get_meta("is_checkpoint", false))
	var limit := 14.0 if is_cp else 12.0
	if _phase_t > limit or (is_cp and d > 50.0 and _phase_t > 2.0) or not game.driving:
		if not game.driving and d < 30.0:
			_open_control(false)
		else:
			_start_chase()


func _open_control(busted: bool) -> void:
	phase = Phase.CONTROL
	game.hud.set_alert("")
	if busted:
		_arrest(true)
		return
	var is_cp := is_instance_valid(chaser) and (chaser == checkpoint_car or bool(chaser.get_meta("is_checkpoint", false)))
	var car: Truck = game.car
	var shine := _moonshine_counts(car)
	var search_chance := 0.50 if (shine.open or shine.hidden or GameState.police_heat > 0.5) else 0.25
	_show_control_dialog(is_cp, 0, search_chance)


func _show_control_dialog(is_cp: bool, rude_count: int, search_chance: float) -> void:
	var car: Truck = game.car
	var shine := _moonshine_counts(car)
	var total_shine: int = shine.inv + shine.cargo
	var offences := []
	var fine := 0
	var pm := GameState.promille()
	var impound := false
	if is_cp or GameState.bac > 0.05:
		if pm >= 1.0:
			offences.append("Alkotest: %.2f Promille (1.000 € + Fahrzeug beschlagnahmt)" % pm)
			fine += 1000
			impound = true
		elif pm >= 0.5:
			offences.append("Alkotest: %.2f Promille (500 €)" % pm)
			fine += 500
	var do_search: bool = bool(shine.open) or _rng.randf() < search_chance
	if do_search and total_shine > 0:
		var sf := total_shine * 50
		offences.append("Schwarzgebrannter: %d Flaschen (%d € + beschlagnahmt)" % [total_shine, sf])
		fine += sf
	var confiscate := func():
		if do_search:
			GameState.take("moonshine", shine.inv)
			for n in car.cargo.duplicate():
				if n.get_meta("kind", "") == "moonshine":
					car.cargo.erase(n)
					n.queue_free()
		if impound:
			_impound_car()
	var text := "Führerschein und Fahrzeugpapiere, bitte.\n\n"
	if offences.is_empty():
		text += "Alles in Ordnung. Gute Weiterfahrt!"
		game.hud.show_dialog("Verkehrskontrolle", text, [["Danke, Herr Inspektor", func(): _end()]])
		return
	text += "\n".join(offences) + "\n\nStrafe gesamt: %d €" % fine
	var opts := [
		["Höflich kooperieren (%d € zahlen)" % fine, func():
			confiscate.call()
			_fine(fine)
			_end()],
		["Bestechen (200 €)", func(): _bribe(fine, confiscate)],
		["Höflich rausreden", func(): _talk(fine, confiscate, rude_count)],
		["Frech antworten", func():
			_show_control_dialog(is_cp, rude_count + 1, 0.90)],
		["Gas geben und abhauen!", func(): _start_chase()],
	]
	if is_cp:
		opts.insert(1, ["\"Ich wurde gerade erst kontrolliert!\"", func():
			if _rng.randf() < 0.90:
				game.hud.show_dialog("Verkehrskontrolle", "\"Na gut, fahren Sie weiter.\"", [["Danke!", func(): _end()]])
			else:
				game.hud.show_dialog("Verkehrskontrolle", "\"Das prüfen wir trotzdem!\"", [["Weiter", func(): _show_control_dialog(false, rude_count, 0.90)]])])
	game.hud.show_dialog("Verkehrskontrolle", text, opts)


func _impound_car() -> void:
	impounded_until = Time.get_ticks_msec() * 0.001 + 300.0
	if game.driving:
		game.exit_vehicle()
	game.hud.toast("Fahrzeug wegen Alkohol am Steuer für 5 Minuten sichergestellt!", 5.0)
	var guard := _spawn_car()
	var cp: Vector3 = game.car.global_position
	var info := world.road_info(Vector2(cp.x, cp.z), 40.0)
	guard.place_at(Vector3(info.pos.x, 0, info.pos.y), Vector3(info.dir.x, 0, info.dir.y))
	guard.route = _make_route(info.road, info.pos)
	guard.cruise_kmh = 40.0
	patrols.append(guard)


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
	if _rng.randf() < 0.64:
		game.hud.show_dialog("Bestechung", "Der Inspektor steckt die 200 € ein.\n\"Ich hab nix gesehen. Fahrn's vorsichtig.\"", [["Weiterfahren", func(): _end()]])
	else:
		game.hud.show_dialog("Bestechung", "\"Wollen Sie mich bestechen?!\"\nZusätzlich 300 € wegen Bestechungsversuch.", [["Zahlen (%d €)" % (fine + 300), func():
			confiscate.call()
			_fine(fine + 300)
			_end()]])


func _talk(fine: int, confiscate: Callable, rude_count := 0) -> void:
	var chance := 0.35 - rude_count * 0.20
	if GameState.outfit.get("hat", "") in ["hunter", "hunter_gams"]:
		chance += 0.12
	if _rng.randf() < maxf(0.05, chance):
		game.hud.show_dialog("Rausreden", "\"Na gut, heute drück ich ein Auge zu. Aber nur heute!\"", [["Danke!", func(): _end()]])
	else:
		game.hud.show_dialog("Rausreden", "\"Das glauben Sie ja selbst nicht.\"", [["Zahlen (%d €)" % fine, func():
			confiscate.call()
			_fine(fine)
			_end()]])


func _arrest(flee_busted: bool, extra_fine := 0, extra_reason := "") -> void:
	phase = Phase.CONTROL
	game.hud.set_alert("")
	if game.driving:
		game.exit_vehicle()
	var offences := []
	var fine := extra_fine
	if not extra_reason.is_empty() and extra_fine > 0:
		offences.append("%s (%d €)" % [extra_reason, extra_fine])
	var pm := GameState.promille()
	if pm >= 1.0:
		offences.append("Alkohol: %.2f Promille (1.000 €)" % pm)
		fine += 1000
	elif pm >= 0.5:
		offences.append("Alkohol: %.2f Promille (500 €)" % pm)
		fine += 500
	var shine := _moonshine_counts(game.car)
	var total_shine: int = shine.inv + shine.cargo
	if total_shine > 0:
		var sf := total_shine * 50
		offences.append("Schwarzgebrannter: %d Flaschen (%d € + beschlagnahmt)" % [total_shine, sf])
		fine += sf
	if flee_busted and extra_fine == 0:
		offences.append("Flucht vor der Polizei (1.000 €)")
		fine += 1000
	var w_count := confiscate_weapons_and_moonshine()
	if w_count > 0:
		offences.append("Waffen beschlagnahmt (%d Stück)" % w_count)
	offences.append("Bearbeitungsgebühr (+50 €)")
	fine += 50
	_fine(fine)
	var station: Vector3 = landmarks.shops.police.door if landmarks.shops.has("police") else Vector3(landmarks.spawn.pos)
	game.player.global_position = station + Vector3(0, 0.5, 0)
	game.player.velocity = Vector3.ZERO
	game.hud.show_dialog("Verhaftung – Polizeiinspektion", "\n".join(offences) + "\n\nGesamtstrafe: %d €" % fine, [["Verstanden", func(): _end()]])


func confiscate_weapons_and_moonshine() -> int:
	var w_removed := 0
	for wid in WEAPON_IDS:
		var n := GameState.count(wid)
		if n > 0:
			GameState.take(wid, n)
			w_removed += n
	var m_inv := GameState.count("moonshine")
	if m_inv > 0:
		GameState.take("moonshine", m_inv)
	if is_instance_valid(game.car):
		for n in game.car.cargo.duplicate():
			if n.get_meta("kind", "") == "moonshine":
				game.car.cargo.erase(n)
				n.queue_free()
	return w_removed


func _start_chase() -> void:
	phase = Phase.CHASE
	game.hud.close_dialog()
	_lost_t = 0.0
	_busted_t = 0.0
	_chase_dist = 0.0
	_last_chase_pos = _focus().global_position
	GameState.police_heat += 1.0
	if not is_instance_valid(chaser) or chaser == checkpoint_car:
		var c := _spawn_car()
		var fp: Vector3 = (checkpoint_car.global_position if is_instance_valid(checkpoint_car) else game.car.global_position - game.car.global_basis.z * 60.0)
		c.place_at(fp + Vector3(3, 0, 3), game.car.global_position - fp)
		patrols.append(c)
		chaser = c
	if not chasers.has(chaser):
		chasers.append(chaser)
	chaser.mode = PoliceCar.Mode.PURSUE
	chaser.target = _focus()
	chaser.set_siren(true)
	game.hud.set_alert("VERFOLGUNG! Hänge die Polizei ab (Feldwege helfen)")


func _spawn_reinforcement(focus_pos: Vector3) -> void:
	if chasers.size() >= MAX_CHASERS:
		return
	for attempt in 20:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(350.0, 550.0)
		var p := Vector2(focus_pos.x, focus_pos.z) + Vector2(cos(a), sin(a)) * d
		var info := world.road_info(p, 50.0)
		if info.road < 0 or info.tier == 0 or info.tier > WorldBuilder.TIER_VILLAGE:
			continue
		var route := _make_route_to(info.pos, Vector2(focus_pos.x, focus_pos.z), false)
		var fwd: Vector2 = (route[1] - route[0]).normalized() if route.size() >= 2 else (info.dir as Vector2)
		if fwd.length_squared() < 0.01:
			fwd = info.dir
		var c := _spawn_car()
		c.place_at(Vector3(info.pos.x, 0, info.pos.y), Vector3(fwd.x, 0, fwd.y))
		c.mode = PoliceCar.Mode.PURSUE
		c.target = _focus()
		c.route = route
		c.route_i = 0
		c.set_siren(true)
		patrols.append(c)
		chasers.append(c)
		game.hud.toast("Polizeiverstärkung ist unterwegs!", 3.0)
		return


func _update_chase(delta: float) -> void:
	if not is_instance_valid(chaser):
		_end()
		return
	var focus := _focus()
	var fp := focus.global_position
	var min_d := INF
	for c in chasers.duplicate():
		if not is_instance_valid(c):
			chasers.erase(c)
			continue
		c.target = focus
		var d: float = c.global_position.distance_to(fp)
		if not game.driving and d < 25.0:
			var off: Node3D = c.dismount_officer(game, self, GameState.police_heat >= 2.0)
			if is_instance_valid(off):
				off.set("target", game.player)
				min_d = minf(min_d, off.global_position.distance_to(fp))
			else:
				min_d = minf(min_d, d)
		else:
			if is_instance_valid(c.dismounted_officer):
				c.remount_officer()
				c.mode = PoliceCar.Mode.PURSUE
			if d > 40.0 and (c.route.is_empty() or c.route_i >= c.route.size() - 1):
				c.route = _make_route_to(Vector2(c.global_position.x, c.global_position.z), Vector2(fp.x, fp.z), c.allow_dirt)
				c.route_i = 0
			min_d = minf(min_d, d)
	var on_dirt: bool = game.driving and (game.car.surface.tier == 0 or game.car.surface.tier >= WorldBuilder.TIER_DIRT)
	if min_d > 350.0 or (on_dirt and min_d > 110.0):
		_lost_t += delta
		if _lost_t > (6.0 if on_dirt else 10.0):
			game.hud.toast("Polizei abgehängt!", 3.0)
			_end()
			return
	else:
		_lost_t = 0.0
	var v: float = absf(game.car.speed_kmh()) if game.driving else game.player.velocity.length() * 3.6
	if min_d < 5.0 and v < 4.0:
		_busted_t += delta
		if _busted_t >= 2.3:
			_arrest(true)
	else:
		_busted_t = 0.0


func _end() -> void:
	phase = Phase.NONE
	game.hud.set_alert("")
	for c in chasers:
		if is_instance_valid(c) and c != checkpoint_car:
			c.remount_officer()
			c.set_siren(false)
			c.mode = PoliceCar.Mode.PATROL
			c.route = PackedVector2Array()
	chasers.clear()
	chaser = null


func _is_alerted() -> bool:
	return phase != Phase.NONE or not _shot_watch_cars.is_empty() or not chasers.is_empty()


func on_player_shot(pos: Vector3) -> void:
	if _is_alerted():
		return
	var near_patrol := false
	for c in patrols:
		if is_instance_valid(c) and c.global_position.distance_to(pos) <= 100.0:
			near_patrol = true
			break
	if near_patrol:
		dispatch(pos, "Schüsse in der Nähe einer Streife")
		return
	var p2 := Vector2(pos.x, pos.z)
	var near_houses := landmarks.near_village(p2) or p2.distance_to(landmarks.home_center) <= 999.0 or p2.distance_to(landmarks.city_center) <= 999.0
	if near_houses:
		_near_house_shots += 1
		if _near_house_shots >= _house_shot_limit:
			_near_house_shots = 0
			_house_shot_limit = _rng.randi_range(4, 15)
			dispatch(pos, "Schüsse im Ortsgebiet")


func on_police_attacked(hit_car: PoliceCar = null) -> void:
	GameState.police_heat += 2.0
	if is_instance_valid(hit_car):
		chaser = hit_car
		if not chasers.has(hit_car):
			chasers.append(hit_car)
		if is_instance_valid(hit_car.dismounted_officer):
			hit_car.dismounted_officer.hostile = true
	for c in chasers:
		if is_instance_valid(c) and is_instance_valid(c.dismounted_officer):
			c.dismounted_officer.set("hostile", true)
	if phase != Phase.CHASE:
		_start_chase()


func on_officer_killed(off: Node3D) -> void:
	if is_instance_valid(off.get("car")):
		(off.get("car") as PoliceCar).officer_dead = true
	GameState.police_heat += 3.0
	game.hud.toast("Polizist erschossen! Verstärkung rückt per Streifenwagen an!", 4.0)
	for i in 2:
		_spawn_reinforcement(_focus().global_position)
	if phase != Phase.CHASE:
		_start_chase()


func dispatch(pos: Vector3, reason: String) -> void:
	if _is_alerted():
		return
	GameState.police_heat += 0.6
	var c := _spawn_car()
	var info := world.road_info(Vector2(pos.x, pos.z) + Vector2(250, 0), 300.0)
	var start := Vector3(info.pos.x, 0, info.pos.y) if info.road >= 0 else pos + Vector3(250, 0, 0)
	var road_goal := world.road_info(Vector2(pos.x, pos.z), 300.0)
	var goal_v3 := Vector3(road_goal.pos.x, world.height_at(road_goal.pos.x, road_goal.pos.y), road_goal.pos.y) if road_goal.road >= 0 else pos
	var route := _make_route_to(Vector2(start.x, start.z), Vector2(goal_v3.x, goal_v3.z), false)
	var fwd := Vector3(route[1].x - route[0].x, 0, route[1].y - route[0].y).normalized() if route.size() >= 2 else (goal_v3 - start).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	c.place_at(start, fwd)
	c.mode = PoliceCar.Mode.GOTO
	c.goto_pos = goal_v3
	c.route = route
	c.route_i = 0
	c.set_siren(true)
	patrols.append(c)
	GameState.notify("Polizeifunk", "Einsatz: %s" % reason)
	_shot_watch_cars.append({car = c, stand_t = 0.0, ttl = 60.0})


func dispatch_explosion(pos: Vector3) -> void:
	GameState.police_heat += 1.5
	var c := _spawn_car()
	var info := world.road_info(Vector2(pos.x, pos.z) + Vector2(280, 0), 350.0)
	var start := Vector3(info.pos.x, 0, info.pos.y) if info.road >= 0 else pos + Vector3(280, 0, 0)
	var route := _make_route_to(Vector2(start.x, start.z), Vector2(pos.x, pos.z), true)
	var fwd := Vector3(route[1].x - route[0].x, 0, route[1].y - route[0].y).normalized() if route.size() >= 2 else (pos - start).normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	c.place_at(start, fwd)
	c.allow_dirt = true
	c.mode = PoliceCar.Mode.GOTO
	c.goto_pos = pos
	c.route = route
	c.route_i = 0
	c.set_siren(true)
	patrols.append(c)
	GameState.notify("Polizeifunk", "Einsatz: Kesselexplosion / Rauchsäule!")
	get_tree().create_timer(300.0).timeout.connect(func():
		if is_instance_valid(c):
			c.allow_dirt = false
			c.set_siren(false)
			c.mode = PoliceCar.Mode.PATROL
			c.route = PackedVector2Array())
	get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(c) and c.global_position.distance_to(game.player.global_position) < 25.0 and phase == Phase.NONE:
			chaser = c
			_arrest(false, 5000, "Illegale Schnapsbrennerei (Explosion)"))


func pay_open_fines() -> String:
	if open_fines <= 0:
		return "Keine offenen Strafen."
	var v := mini(open_fines, maxi(GameState.money, 0))
	GameState.pay(v)
	open_fines -= v
	return "%d € bezahlt, offen: %d €" % [v, open_fines]
