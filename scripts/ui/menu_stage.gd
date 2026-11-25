class_name MenuStage
extends Node3D
## 3D-Bühne hinter dem Hauptmenü. Drei Einstellungen, zwischen denen die Kamera fährt:
##   "title"  - die eigene Figur steht auf einem Felsen über dem Dorf und schaut in den Sonnenuntergang
##   "figure" - Standspiegel neben dem Gasthaus, die Figur steht im Rahmen (Figur-Editor)
##   "lobby"  - alle Spieler stehen vor dem Gasthaus Pirtscher in einer Reihe, der Pickup dahinter

const MENU_TIME := 19.0  # tief stehende Abendsonne

var game: Node
var world: WorldBuilder
var cam: Camera3D
var shot := ""
var hero: CharacterModel
var hero_yaw := 0.0  # im Figur-Editor mit der Maus gedreht
var hero_root: Node3D  # Halter (die Figur selbst setzt beim Animieren ihre eigene Höhe)
var _hidden_labels: Array[Node3D] = []
var _hero_spot := Transform3D.IDENTITY  # Felsen über dem Dorf
var _stage := Transform3D.IDENTITY  # vor dem Gasthaus, +Z schaut zur Kamera
var _mirror := Transform3D.IDENTITY
var _lineup := {}  # peer id (0 = ich) -> {model, label, key}
var _truck: Truck
var _rock_node: Node3D
var _mirror_node: Node3D
var _birds: Array[Node3D] = []
var _t := 0.0
var _cam_tw: Tween
var _saved_time := -1.0
var _saved_weather := ""


func setup(g: Node, w: WorldBuilder) -> void:
	game = g
	world = w
	_saved_time = GameState.time
	_saved_weather = GameState.weather
	GameState.time = MENU_TIME
	GameState.weather = "clear"
	GameState.wetness = 0.0
	cam = Camera3D.new()
	cam.name = "Menuekamera"
	cam.far = 6000.0
	cam.fov = 55.0
	add_child(cam)
	cam.make_current()
	hero_root = Node3D.new()
	hero_root.name = "Figur"
	add_child(hero_root)
	# Ortsschilder der Karte stören im Titelbild
	for l in world.find_children("*", "Label3D", true, false):
		if (l as Label3D).fixed_size and (l as Label3D).visible:
			l.visible = false
			_hidden_labels.append(l)
	_find_spots()
	_build_rock()
	_build_mirror()
	_build_birds()
	refresh_hero()
	show_shot("title", true)


## Menü verlassen: Tageszeit und Wetter zurück (falls kein Spielstand sie neu setzt)
func _exit_tree() -> void:
	for l in _hidden_labels:
		if is_instance_valid(l):
			l.visible = true


func restore_world() -> void:
	if _saved_time >= 0.0:
		GameState.time = _saved_time
		GameState.weather = _saved_weather


# ------------------------------------------------------------------ Orte

func _gasthaus() -> Node3D:
	return game.get("gasthaus") as Node3D


func _find_spots() -> void:
	var g := _gasthaus()
	var center := Vector3(0, 0, 0)
	var front := Vector3(0, 0, 1)
	if g:
		center = g.global_position
		front = g.global_basis.z
		front.y = 0
		front = front.normalized()
	# Bühne: 9 m vor der Tür, Spieler schauen von der Tür weg (zur Kamera)
	var door: Vector3 = g.get("door") if g else center + front * 6.0
	var sp := door + front * 7.5
	sp.y = world.height_at(sp.x, sp.z)
	_stage = Transform3D(Basis.looking_at(-front, Vector3.UP), sp)
	# Spiegel: seitlich der Bühne
	var side := front.cross(Vector3.UP).normalized()
	var mp := sp + side * 9.0 + front * 2.0
	# Spiegel auf die Wiese stellen, nicht auf die Straße (Kamera steht 4 m davor)
	for k in 24:
		var cand: Vector3 = sp + side * (9.0 + (k % 6) * 4.0) * (1.0 if k < 12 else -1.0) + front * (2.0 + (k / 6 % 2) * 6.0)
		var cam_pos := cand + front * 4.5
		if world.road_info(Vector2(cand.x, cand.z), 9.0).tier == 0 and world.road_info(Vector2(cam_pos.x, cam_pos.z), 6.0).tier == 0:
			mp = cand
			break
	mp.y = world.height_at(mp.x, mp.z) + 0.2  # liegt auf einer eigenen Wiese über Straße oder Platz
	_mirror = Transform3D(Basis.looking_at(-front, Vector3.UP), mp)
	# Aussichtspunkt: höchster Punkt im Ring um das Dorf, mit freiem Blick auf das Gasthaus
	var best_score := -INF
	var best := center + Vector3(150, 0, 0)
	for ring in [140.0, 190.0, 240.0, 300.0]:
		for k in 36:
			var a := TAU * k / 36.0
			var p: Vector3 = center + Vector3(cos(a), 0, sin(a)) * ring
			var h := world.height_at(p.x, p.z)
			var rise := h - center.y
			if rise < 8.0 or not _clear_view(Vector3(p.x, h + 1.8, p.z), center + Vector3(0, 6, 0)):
				continue
			var road := world.road_info(Vector2(p.x, p.z), 14.0)
			if road.tier != 0:
				continue
			var score: float = rise - ring * 0.05
			if score > best_score:
				best_score = score
				best = Vector3(p.x, h, p.z)
	best.y = world.height_at(best.x, best.z)
	var look := center - best
	look.y = 0
	_hero_spot = Transform3D(Basis.looking_at(look.normalized(), Vector3.UP), best + Vector3(0, 0.9, 0))


## Gelände zwischen zwei Punkten nicht im Weg?
func _clear_view(a: Vector3, b: Vector3) -> bool:
	for k in range(1, 24):
		var p := a.lerp(b, k / 24.0)
		if world.height_at(p.x, p.z) > p.y - 0.5:
			return false
	return true


# ------------------------------------------------------------------ Kulissen

func _build_rock() -> void:
	var rock := Node3D.new()
	rock.name = "Aussichtsfelsen"
	add_child(rock)
	_rock_node = rock
	rock.global_transform = _hero_spot
	var stone := Color(0.5, 0.48, 0.45)
	Placeables.box(rock, Vector3(2.6, 1.6, 2.2), Vector3(0, -0.8, 0), stone, Vector3(0.05, 0.3, -0.04))
	Placeables.box(rock, Vector3(1.6, 1.2, 1.6), Vector3(-1.2, -0.9, 0.9), stone.darkened(0.1), Vector3(0.2, 0.7, 0.1))
	Placeables.box(rock, Vector3(1.8, 1.0, 1.3), Vector3(1.3, -1.0, -0.6), stone.lightened(0.05), Vector3(-0.1, -0.4, 0.15))
	for k in 9:
		var a := TAU * k / 9.0
		var grass := Placeables.box(rock, Vector3(0.03, 0.3, 0.03), Vector3(cos(a) * 1.5, -0.15, sin(a) * 1.3), Color(0.35, 0.5, 0.22), Vector3(0.3 * cos(a), 0, 0.3 * sin(a)))
		grass.scale.y = 0.6 + (k % 3) * 0.3


## Standspiegel aus Holz (wie ein großer Bilderrahmen), die Figur steht darin
func _build_mirror() -> void:
	var m := Node3D.new()
	m.name = "Standspiegel"
	add_child(m)
	_mirror_node = m
	m.global_transform = _mirror
	var wood := Color(0.86, 0.84, 0.8)
	var t := 0.12
	Placeables.box(m, Vector3(t, 2.5, t), Vector3(-0.85, 1.25, -0.3), wood)
	Placeables.box(m, Vector3(t, 2.5, t), Vector3(0.85, 1.25, -0.3), wood)
	Placeables.box(m, Vector3(1.82, t, t), Vector3(0, 2.5, -0.3), wood)
	Placeables.box(m, Vector3(1.82, t, t), Vector3(0, 0.02, -0.3), wood)
	Placeables.box(m, Vector3(1.6, 2.36, 0.03), Vector3(0, 1.26, -0.38), Color(0.62, 0.68, 0.72))
	for s in [-1, 1]:
		Placeables.box(m, Vector3(0.1, 0.1, 0.9), Vector3(0.85 * s, 0.05, -0.55), wood)
	# Wiese unter dem Spiegel (liegt über Straße oder Platz) mit ein paar Blumen
	Placeables.box(m, Vector3(18, 0.3, 14), Vector3(0, -0.15, 2.0), Color(0.33, 0.52, 0.24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 40:
		var fp := Vector3(rng.randf_range(-7, 7), 0.0, rng.randf_range(-3, 3.5))
		if absf(fp.x) < 1.2 and fp.z < 1.5:
			continue
		var col: Color = [Color(0.98, 0.95, 0.9), Color(0.98, 0.85, 0.25), Color(0.7, 0.5, 0.9)][k % 3]
		Placeables.box(m, Vector3(0.02, 0.16, 0.02), fp + Vector3(0, 0.08, 0), Color(0.25, 0.45, 0.2))
		Placeables.box(m, Vector3(0.08, 0.04, 0.08), fp + Vector3(0, 0.17, 0), col)
		# Holzpfähle mit Seil wie ein kleiner Ring
	for k in 4:
		var x := -2.4 + k * 1.6
		Placeables.cyl(m, 0.1, 0.9, Vector3(x, 0.45, -2.2), Color(0.42, 0.3, 0.2))
	Placeables.box(m, Vector3(5.0, 0.05, 0.05), Vector3(0.0, 0.75, -2.2), Color(0.55, 0.45, 0.3))


func _build_birds() -> void:
	for k in 7:
		var b := Node3D.new()
		add_child(b)
		for s in [-1, 1]:
			var wing := Placeables.box(b, Vector3(0.9, 0.05, 0.25), Vector3(0.42 * s, 0, 0), Color(0.15, 0.12, 0.12), Vector3(0, 0, 0.35 * s))
			wing.name = "Fluegel%d" % s
		b.set_meta("phase", k * 0.9)
		b.set_meta("r", 30.0 + k * 9.0)
		b.set_meta("h", 28.0 + (k % 3) * 7.0)
		_birds.append(b)


func _process(delta: float) -> void:
	_t += delta
	GameState.time = MENU_TIME + sin(_t * 0.02) * 0.05
	var c := _hero_spot.origin + _hero_spot.basis.z * -80.0
	for b in _birds:
		var ph: float = b.get_meta("phase") + _t * 0.12
		var r: float = b.get_meta("r")
		b.global_position = c + Vector3(cos(ph) * r, b.get_meta("h") + sin(ph * 2.0) * 2.0, sin(ph) * r * 0.6)
		b.rotation.y = -ph
		var flap := sin(_t * 6.0 + ph * 3.0) * 0.5
		for w in b.get_children():
			w.rotation.z = flap * (1.0 if w.name.ends_with("1") and not w.name.ends_with("-1") else -1.0)
	if hero:
		hero.animate(delta, 0.0)
	for id in _lineup:
		(_lineup[id].model as CharacterModel).animate(delta, 0.0)


# ------------------------------------------------------------------ Figur

## Eigene Figur neu aufbauen (nach Änderungen im Editor) und an den passenden Ort stellen
func refresh_hero() -> void:
	if hero:
		hero.queue_free()
	hero = CharacterModel.new(GameState.outfit)
	hero_root.add_child(hero)
	_place_hero()
	if _lineup.has(0):
		_set_lineup_model(0, GameState.outfit)


func _place_hero() -> void:
	if not hero:
		return
	match shot:
		"figure":
			hero_root.global_transform = _mirror
			hero_root.visible = true
		"lobby":
			hero_root.visible = false  # in der Lobby steht die Figur in der Reihe
		_:
			# schaut ins Tal (Rücken zur Kamera)
			hero_root.global_transform = Transform3D(_hero_spot.basis.rotated(Vector3.UP, PI), _hero_spot.origin)
			hero_root.visible = true
	hero.rotation = Vector3(0, hero_yaw if shot == "figure" else 0.0, 0)


func show_shot(name: String, instant := false) -> void:
	shot = name
	_place_hero()
	if _truck:
		_truck.visible = name == "lobby"
	_rock_node.visible = name == "title"
	_mirror_node.visible = name == "figure"
	for id in _lineup:
		_lineup[id].holder.visible = name == "lobby"
		_lineup[id].label.visible = name == "lobby"
	var target := _shot_xf(name)
	if _cam_tw:
		_cam_tw.kill()
	if instant:
		cam.global_transform = target
		return
	var from := cam.global_transform
	_cam_tw = create_tween()
	_cam_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_method(func(f: float): cam.global_transform = from.interpolate_with(target, f), 0.0, 1.0, 1.6)


func _shot_xf(name: String) -> Transform3D:
	match name:
		"figure":
			# Figur in der Bildmitte, leicht von oben, etwas Platz links für die Menüs
			var b := _mirror.basis
			var p := _mirror.origin + b.z * 4.2 + Vector3.UP * 1.25 + b.x * -0.9
			return Transform3D(Basis.looking_at(_mirror.origin + Vector3.UP * 0.75 + b.x * -0.9 - p, Vector3.UP), p)
		"lobby":
			var b := _stage.basis
			var p := _stage.origin + b.z * 6.4 + Vector3.UP * 1.5
			return Transform3D(Basis.looking_at(_stage.origin + Vector3.UP * 0.75 - p, Vector3.UP), p)
		_:
			# hinter und rechts neben der Figur, Blick über das Tal; Figur im linken Bilddrittel
			var b := _hero_spot.basis
			var p := _hero_spot.origin + b.z * 5.8 + b.x * 1.5 + Vector3.UP * 1.25
			var look := _hero_spot.origin + b.z * -45.0 + b.x * 7.0 + Vector3.UP * -4.0
			return Transform3D(Basis.looking_at(look - p, Vector3.UP), p)


# ------------------------------------------------------------------ Lobby

## Spieler in der Lobby aufstellen: ich in der Mitte, die anderen links und rechts daneben.
## players: Array von {id, name, outfit, state, ready}
func set_lineup(players: Array) -> void:
	if _truck == null:
		_truck = Truck.new()
		_truck.world = world
		_truck.puppet = true
		_truck.name = "LobbyPickup"
		add_child(_truck)
		var tp := _stage.origin - _stage.basis.z * 4.0 + _stage.basis.x * 3.2
		tp.y = world.height_at(tp.x, tp.z) + 0.6
		_truck.puppet_to(Transform3D(_stage.basis.rotated(Vector3.UP, 0.5), tp))
	var seen := {}
	for k in players.size():
		var p: Dictionary = players[k]
		var id: int = p.id
		seen[id] = true
		if not _lineup.has(id):
			var lbl := Label3D.new()
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.font_size = 44
			lbl.pixel_size = 0.005
			lbl.outline_size = 12
			add_child(lbl)
			var holder := Node3D.new()
			add_child(holder)
			_lineup[id] = {model = null, holder = holder, label = lbl, key = ""}
		var e: Dictionary = _lineup[id]
		var key := str(p.outfit)
		if e.key != key:
			e.key = key
			_set_lineup_model(id, p.outfit)
		# Formation: 0, -1, +1, -2, +2 ... leicht nach hinten versetzt
		var slot := 0 if k == 0 else (((k + 1) / 2) * (-1 if k % 2 == 1 else 1))
		var pos := _stage.origin + _stage.basis.x * (slot * 1.35) - _stage.basis.z * (absf(slot) * 0.45)
		pos.y = world.height_at(pos.x, pos.z)
		var holder: Node3D = e.holder
		holder.global_transform = Transform3D(_stage.basis.rotated(Vector3.UP, -slot * 0.12), pos)
		var lbl: Label3D = e.label
		var status := "im Spiel" if p.state == "game" else ("BEREIT" if p.ready else "wartet")
		lbl.text = "%s\n%s" % [p.name, status]
		lbl.modulate = Color(0.55, 0.95, 0.45) if p.ready and p.state != "game" else (Color(0.75, 0.8, 1.0) if p.state == "game" else Color(1, 0.95, 0.8))
		lbl.global_position = pos + Vector3.UP * 1.75
		holder.visible = shot == "lobby"
		lbl.visible = shot == "lobby"
	for id in _lineup.keys():
		if not seen.has(id):
			_lineup[id].holder.queue_free()
			_lineup[id].label.queue_free()
			_lineup.erase(id)


func _set_lineup_model(id: int, outfit: Dictionary) -> void:
	var e: Dictionary = _lineup[id]
	var old: CharacterModel = e.model
	var m := CharacterModel.new(GameState._colors_in(outfit))
	(e.holder as Node3D).add_child(m)
	if old:
		old.queue_free()
	e.model = m
