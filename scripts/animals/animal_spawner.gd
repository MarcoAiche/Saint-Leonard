class_name AnimalSpawner
extends Node3D
## Hält rund um die Spieler genug Wild: Rehe in Wald- und Feldnähe, Wildschweine im Wald,
## Hasen auf Wiesen, Bären nur in den Südbergen. Morgens und abends ist mehr Wild unterwegs.
## Tiere weit weg von allen Spielern verschwinden wieder. Im Mehrspieler-Modus macht das nur der Server.

const SPAWN_MIN := 140.0
const SPAWN_MAX := 450.0
const DESPAWN := 540.0

var world: WorldBuilder
var landmarks: Landmarks
var players: Array[Node3D] = []
var animals := {}  # net_id -> Animal
var legend_wanted := false
var died_hook: Callable
var _timer := 1.0
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func setup(w: WorldBuilder, lm: Landmarks) -> void:
	world = w
	landmarks = lm
	_rng.randomize()


func _targets() -> Dictionary:
	var dawn_dusk := (GameState.time > 5.0 and GameState.time < 9.0) or (GameState.time > 18.0 and GameState.time < 21.5)
	return {
		deer = 14 if dawn_dusk else 9,
		boar = 5 if GameState.is_night() else 4,
		fox = 4,
		rabbit = 6,
		bear = 2,
		bigfoot = 1,
		legend = 1 if legend_wanted else 0,
	}


func _process(delta: float) -> void:
	if players.is_empty() or Net.is_client():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.8
	# weit entfernte Tiere entfernen
	for id in animals.keys():
		var a: Animal = animals[id]
		if not is_instance_valid(a):
			animals.erase(id)
			continue
		if _min_dist(a.global_position) > DESPAWN and a.species != "legend":
			animals.erase(id)
			Net.animal_despawned(id)
			a.queue_free()
	var counts := {}
	for a in animals.values():
		counts[a.species] = counts.get(a.species, 0) + 1
	var want := _targets()
	var order := want.keys()
	order.shuffle()
	for sp in order:
		if counts.get(sp, 0) < want[sp] and _try_spawn(sp):
			return  # eins pro Durchgang


func _min_dist(p: Vector3) -> float:
	var best := INF
	for pl in players:
		if is_instance_valid(pl):
			best = minf(best, pl.global_position.distance_to(p))
	return best


func _try_spawn(sp: String) -> bool:
	var valid := players.filter(func(p): return is_instance_valid(p))
	if valid.is_empty():
		return false
	var center: Node3D = valid[_rng.randi() % valid.size()]
	for attempt in 20:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var p := Vector2(center.global_position.x, center.global_position.z) + Vector2(cos(a), sin(a)) * d
		if sp in ["legend", "bigfoot"]:
			# Riesenhirsch & Bigfoot: in den grünen Südbergen (z > 700, Höhe > 90m)
			p = Vector2(_rng.randf_range(-600, 900), _rng.randf_range(1200, 2400))
		if not _ok(sp, p):
			continue
		if _min_dist(Vector3(p.x, world.height_at(p.x, p.y), p.y)) < SPAWN_MIN * 0.8 and sp != "legend":
			continue
		spawn(sp, Vector3(p.x, world.height_at(p.x, p.y) + 0.3, p.y), _next_id, _rng.randi())
		_next_id += 1
		return true
	return false


func _ok(sp: String, p: Vector2) -> bool:
	if world.border_distance(p) < 80.0:
		return false
	if landmarks.near_village(p) and sp != "rabbit":
		return false
	if world.road_info(p, 15.0).tier != 0:
		return false
	var kind := world.kind_at(p.x, p.y)
	if kind in ["water", "residential", "industrial", "parking", "cemetery"]:
		return false
	if world.slope_at(p.x, p.y) > 0.6:
		return false
	match sp:
		"boar":
			return kind in ["forest", "scrub"] or world.is_swamp(p)
		"rabbit":
			return kind in ["meadow", "farmland", "grass", "scrub"]
		"bear", "bigfoot", "legend":
			return (kind == "forest" or kind == "scrub") and landmarks.in_mountains(p)
		_:
			return kind in ["forest", "meadow", "farmland", "scrub", "grass"]


func spawn(sp: String, pos: Vector3, id: int, seed_v: int, is_remote := false) -> Animal:
	var a := Animal.new()
	a.setup(sp, world, landmarks, seed_v)
	a.net_id = id
	a.remote = is_remote
	a.name = "Tier_%d" % id
	add_child(a)
	a.global_position = pos
	a.rotation.y = _rng.randf() * TAU
	animals[id] = a
	a.died.connect(func(an, c):
		animals.erase(an.net_id)
		if died_hook.is_valid():
			died_hook.call(an, c))
	if not is_remote:
		Net.animal_spawned(sp, pos, id, seed_v)
	return a


func legend_alive() -> bool:
	for a in animals.values():
		if is_instance_valid(a) and a.species == "legend":
			return true
	return false


func legend_pos() -> Vector3:
	for a in animals.values():
		if is_instance_valid(a) and a.species == "legend":
			return a.global_position
	return Vector3.INF
