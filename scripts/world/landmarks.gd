class_name Landmarks
extends Node3D
## Spielorte aus dem Konzept, gesetzt auf die echte Karte:
##  - Saint Leonard (Heimatdorf: Riegersdorf + St. Leonhard) mit Gasthaus Pirtscher, Werkstatt und 10 Bauplätzen
##  - Tankstelle auf halbem Weg (echte Tankstelle bei Hart, an der Gail)
##  - die Stadt im Nordosten (Fürnitz) mit Supermarkt, Bauhaus, Waffengeschäft, Fleischerei und Polizei
##  - Polizeikontrolle an der Hauptstraße vor der Stadt
## Alles wird beim Start aus den Weltdaten berechnet (gleiches Ergebnis bei jedem Start).

const CITY_PLACE := "Fürnitz"
const HOME_PLACE := "Sankt Leonhard bei Siebenbrünn"
const PUB_NAME := "Gasthaus Pirtscher"
const GAS_POI := "Eni Austria GmbH"
const SHOP_ORDER := ["bauhaus", "super", "gun", "butcher", "police"]
const SHOP_SIGNS := {
	"bauhaus": ["BAUHAUS", Color(0.85, 0.10, 0.10)],
	"super": ["SUPERMARKT", Color(0.95, 0.75, 0.10)],
	"gun": ["WAFFEN & JAGD", Color(0.20, 0.35, 0.20)],
	"butcher": ["FLEISCHEREI", Color(0.70, 0.15, 0.15)],
	"police": ["POLIZEI", Color(0.15, 0.30, 0.65)],
}

var world: WorldBuilder
var game: Node
var city_center := Vector2.ZERO
var home_center := Vector2.ZERO
var pub := {}  # {pos: Vector3, door: Vector3}
var gas := {}  # {pos: Vector3, pumps: [Vector3], shop: Vector3}
var garage := {}  # {pos: Vector3, yaw, door: Vector3}
var shops := {}  # id -> {pos: Vector3, door: Vector3, yaw}
var plots: Array = []  # [{pos: Vector3, yaw, size: Vector2, idx}]
var checkpoint := {}  # {pos: Vector3, dir: Vector2}
var spawn := {}  # {pos: Vector3, yaw, car_pos: Vector3, car_dir: Vector3}

var _bld_grid := {}  # Gebäude-Mittelpunkte zum schnellen Prüfen freier Flächen
var _rng := RandomNumberGenerator.new()


func setup(w: WorldBuilder, g: Node) -> void:
	world = w
	game = g
	_rng.seed = 4711
	_index_buildings()
	city_center = _place_pos(CITY_PLACE, Vector2(2700, -1490))
	home_center = _place_pos(HOME_PLACE, Vector2(1170, 10))
	_find_pub()
	_find_city_shops()
	_find_gas_station()
	_find_garage()
	_find_plots()
	_find_checkpoint()
	_build_props()


func _place_pos(place_name: String, fallback: Vector2) -> Vector2:
	for pl in world.data.places:
		if pl.name == place_name:
			return Vector2(pl.pos[0], pl.pos[1])
	return fallback


func v3(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, world.height_at(p.x, p.y) + lift, p.y)


# ------------------------------------------------------------------ freie Flächen

func _index_buildings() -> void:
	for b in world.data.buildings:
		var poly := WorldBuilder.to_v2_array(b.pts)
		var c := Vector2.ZERO
		for p in poly:
			c += p / poly.size()
		var r := 0.0
		for p in poly:
			r = maxf(r, p.distance_to(c))
		var key := Vector2i(floori(c.x / 50.0), floori(c.y / 50.0))
		if not _bld_grid.has(key):
			_bld_grid[key] = []
		_bld_grid[key].append([c, r, b])


func buildings_near(p: Vector2, radius: float) -> Array:
	var out := []
	var k := Vector2i(floori(p.x / 50.0), floori(p.y / 50.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for e in _bld_grid.get(k + Vector2i(dx, dz), []):
				if e[0].distance_to(p) - e[1] < radius:
					out.append(e)
	return out


## Freier, flacher Platz neben einer Straße. Gibt {} zurück, wenn nichts passt.
func find_spot(center: Vector2, r_min: float, r_max: float, half: float, max_tier := 2, tries := 400, avoid: Array = []) -> Dictionary:
	for t in tries:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(r_min, r_max)
		var p := center + Vector2(cos(a), sin(a)) * d
		if world.border_distance(p) < 60.0:
			continue
		var kind := world.kind_at(p.x, p.y)
		if kind in ["water", "forest", "industrial", "cemetery", "parking"]:
			continue
		if world.slope_at(p.x, p.y) > 0.12:
			continue
		var road := world.road_info(p, 40.0)
		if road.tier == 0 or road.tier > max_tier or road.dist < half + 3.0 or road.dist > half + 22.0:
			continue
		if not buildings_near(p, half + 6.0).is_empty():
			continue
		var bad := false
		for q in avoid:
			if q.distance_to(p) < half * 2.0 + 14.0:
				bad = true
				break
		if bad:
			continue
		# Fläche frei von Straßen
		var ok := true
		for c in [Vector2(half, half), Vector2(-half, half), Vector2(half, -half), Vector2(-half, -half)]:
			if world.road_info(p + c, 2.0).tier != 0:
				ok = false
		if not ok:
			continue
		var to_road: Vector2 = (road.pos - p).normalized()
		return {pos = p, yaw = atan2(to_road.x, to_road.y), road = road}
	return {}


# ------------------------------------------------------------------ Orte suchen

func _find_pub() -> void:
	var p := world.poi_position(PUB_NAME)
	var road := world.nearest_road(p, ["residential", "unclassified", "tertiary", "primary", "service"])
	var door: Vector2 = p + (road.pos - p).normalized() * 5.0
	for e in buildings_near(p, 2.0):
		door = _door_point(e[2], road.pos)
	pub = {pos = v3(p), door = v3(door)}
	var side := Vector2(-road.dir.y, road.dir.x)
	if side.dot(p - road.pos) < 0:
		side = -side
	var pp: Vector2 = road.pos + side * 1.5
	var cp: Vector2 = road.pos + road.dir * 7.0 - side * 1.2
	spawn = {pos = v3(pp, 0.5), car_pos = Vector3(cp.x, 0, cp.y), car_dir = Vector3(road.dir.x, 0, road.dir.y), look = (cp - pp).normalized()}


## Punkt am Gebäuderand, der einer Straße am nächsten ist (dort ist die Tür)
func _door_point(b: Dictionary, toward: Vector2) -> Vector2:
	var poly := WorldBuilder.to_v2_array(b.pts)
	var best := poly[0]
	for k in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(toward, poly[k], poly[(k + 1) % poly.size()])
		if q.distance_to(toward) < best.distance_to(toward):
			best = q
	return best


func _find_city_shops() -> void:
	var cands := []
	for e in buildings_near(city_center, 700.0):
		if e[0].distance_to(city_center) > 700.0:
			continue
		var b: Dictionary = e[2]
		var area := WorldBuilder._poly_area(WorldBuilder.to_v2_array(b.pts))
		if area < 140.0 or area > 4000.0:
			continue
		var road := world.road_info(e[0], 30.0)
		if road.tier == 0 or road.tier > 2:
			continue
		cands.append([area, e, road])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var used: Array[Vector2] = []
	for id in SHOP_ORDER:
		for c in cands:
			var p: Vector2 = c[1][0]
			var ok := true
			for u in used:
				if u.distance_to(p) < 70.0:
					ok = false
			if not ok:
				continue
			used.append(p)
			var door := _door_point(c[1][2], c[2].pos)
			var out: Vector2 = (c[2].pos - door).normalized()
			shops[id] = {pos = v3(p), door = v3(door + out * 1.5), yaw = atan2(out.x, out.y), wall = door, height = float(c[1][2].wall)}
			break
	# Sollte etwas fehlen: freien Platz nehmen und eigene Halle bauen
	for id in SHOP_ORDER:
		if not shops.has(id):
			var s := find_spot(city_center, 50.0, 500.0, 9.0, 2, 400, used)
			if not s.is_empty():
				used.append(s.pos)
				var dir := Vector2(sin(s.yaw), cos(s.yaw))
				shops[id] = {pos = v3(s.pos), door = v3(s.pos + dir * 10.5), yaw = s.yaw, wall = s.pos + dir * 9.0, height = 6.0, own = true}


func _find_gas_station() -> void:
	var p := world.poi_position(GAS_POI)
	if p == Vector2.ZERO:
		p = (home_center + city_center) * 0.5
	var road := world.nearest_road(p, ["primary", "secondary", "tertiary", "trunk"])
	var side: Vector2 = (p - road.pos).normalized()
	var base: Vector2 = road.pos + side * 9.0
	var pumps := []
	for k in [-1, 1]:
		var q: Vector2 = base + road.dir * 4.0 * k
		pumps.append(v3(q))
	gas = {pos = v3(base), pumps = pumps, shop = v3(base + side * 9.0), dir = road.dir, side = side}


func _find_garage() -> void:
	var s := find_spot(home_center, 40.0, 450.0, 8.0, 2)
	if s.is_empty():
		s = {pos = home_center + Vector2(30, 30), yaw = 0.0}
	var dir := Vector2(sin(s.yaw), cos(s.yaw))
	garage = {pos = v3(s.pos), yaw = s.yaw, door = v3(s.pos + dir * 7.0), bay = v3(s.pos + dir * 11.0)}


func _find_plots() -> void:
	var avoid: Array = [Vector2(garage.pos.x, garage.pos.z)]
	var centers := [Vector2.ZERO, home_center, (home_center + Vector2.ZERO) * 0.5]
	var k := 0
	while plots.size() < Items.HOUSES.size() and k < 60:
		var c: Vector2 = centers[k % centers.size()]
		var s := find_spot(c, 60.0, 650.0, 9.0, 2, 300, avoid)
		k += 1
		if s.is_empty():
			continue
		avoid.append(s.pos)
		plots.append({pos = v3(s.pos), yaw = s.yaw, idx = plots.size()})


func _find_checkpoint() -> void:
	# Hauptstraße 500 bis 900 m vor der Stadt, Richtung Tankstelle
	var gp := Vector2(gas.pos.x, gas.pos.z)
	var best := {}
	var best_score := INF
	for ri in world.data.roads.size():
		var r: Dictionary = world.data.roads[ri]
		if r.tier != WorldBuilder.TIER_MAIN or r.kind.begins_with("motorway") or r.bridge or r.tunnel:
			continue
		for pt in r.pts:
			var p := Vector2(pt[0], pt[1])
			var dc := p.distance_to(city_center)
			if dc < 450.0 or dc > 1000.0 or world.border_distance(p) < 80.0:
				continue
			var score := absf(dc - 650.0) + p.distance_to(gp) * 0.3
			if score < best_score:
				best_score = score
				best = {p = p}
	if best.is_empty():
		checkpoint = {}
		return
	var info := world.road_info(best.p, 5.0)
	checkpoint = {pos = v3(info.pos), dir = info.dir}


## In den Südbergen (Bären, Riesenhirsch, Bergpfade)
func in_mountains(p: Vector2) -> bool:
	return p.y > 700.0 and world.height_at(p.x, p.y) > 90.0


func near_village(p: Vector2) -> bool:
	return p.distance_to(Vector2.ZERO) < 300.0 or p.distance_to(home_center) < 300.0 or p.distance_to(city_center) < 500.0


# ------------------------------------------------------------------ Bauen

func _mat(c: Color) -> StandardMaterial3D:
	return Toon.solid(c, false)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, collide := false, rot := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation.y = rot
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _sign(parent: Node3D, text: String, color: Color, pos: Vector3, yaw: float, width := 7.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	_box(holder, Vector3(width, 1.4, 0.2), Vector3.ZERO, color)
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = minf(0.012, width * 0.88 / (text.length() * 96.0 * 0.62))
	l.outline_size = 0
	l.modulate = Color.WHITE
	l.position = Vector3(0, 0, 0.12)
	l.double_sided = false
	holder.add_child(l)


func _npc(parent: Node3D, npc_name: String, pos: Vector3, yaw: float, outfit := {}) -> Npc:
	var n := Npc.new(npc_name, outfit)
	parent.add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	return n


func _build_props() -> void:
	var I: Interactions = game.interactions

	# Gasthaus Pirtscher: Wirt vor der Tür
	var wirt_pos: Vector3 = pub.door + (Vector3(spawn.pos) - pub.door).normalized() * 1.2
	var sepp := _npc(self, "Wirt Sepp", Vector3(wirt_pos.x, world.height_at(wirt_pos.x, wirt_pos.z), wirt_pos.z), 0.0, {shirt = Color(0.9, 0.9, 0.88), pants = Color(0.2, 0.2, 0.2), hat = "none"})
	sepp.important = true
	I.add(wirt_pos, 3.0, "Gasthaus Pirtscher: Wirt Sepp", func(): game.open_shop("pub"))

	# Spielautomaten beim Gasthaus, an der Tankstelle und beim Supermarkt
	var spots := [wirt_pos + Vector3(1.6, 0, 1.2)]
	if shops.has("super"):
		var sd: Vector3 = shops.super.door
		spots.append(sd + Vector3(sin(shops.super.yaw + PI / 2), 0, cos(shops.super.yaw + PI / 2)) * 2.2)
	for sp in spots:
		_slot_machine(Vector3(sp.x, world.height_at(sp.x, sp.z), sp.z))

	# Stadtläden
	for id in shops:
		var s: Dictionary = shops[id]
		var door: Vector3 = s.door
		var dir := Vector2(sin(s.yaw), cos(s.yaw))
		if s.get("own", false):
			_hall(s)
		var sign_pos: Vector2 = s.wall + dir * 0.4
		var top: float = world.height_at(sign_pos.x, sign_pos.y) + minf(float(s.height), 7.0) + 0.9
		_sign(self, SHOP_SIGNS[id][0], SHOP_SIGNS[id][1], Vector3(sign_pos.x, top, sign_pos.y), s.yaw, 8.0)
		var outfit := {shirt = SHOP_SIGNS[id][1].lightened(0.3), hat = "none"}
		if id == "police":
			outfit = {uniform = true, hat = "police"}
		var npc_name: String = {"bauhaus": "Bauhaus-Verkäufer", "super": "Kassiererin", "gun": "Büchsenmacher", "butcher": "Fleischer Franz", "police": "Polizeiinspektion"}[id]
		var shop_npc := _npc(self, npc_name, Vector3(door.x, world.height_at(door.x, door.z), door.z), s.yaw, outfit)
		shop_npc.important = true
		if id == "police":
			I.add(door, 3.0, "Polizei: Strafen bezahlen", func(): game.police_desk())
		else:
			I.add(door, 3.0, Items.SHOP_NAMES[id], func(): game.open_shop(id))
		# Ankauf vom Pickup (ganzes Wild bei der Fleischerei)
		if id == "butcher":
			I.add(door, 14.0, "Wild von der Ladefläche verkaufen", func(): game.sell_truck_cargo(), func(): game.truck_has_game_near(door, 14.0))

	# Tankstelle
	var gnode := Node3D.new()
	gnode.name = "Tankstelle"
	add_child(gnode)
	var gp: Vector3 = gas.pos
	var gdir: Vector2 = gas.dir
	var gyaw := atan2(gdir.x, gdir.y)
	_box(gnode, Vector3(16, 0.6, 9), gp + Vector3(0, 5.2, 0), Color(0.95, 0.95, 0.95), false, gyaw)  # Dach
	_box(gnode, Vector3(16.2, 0.4, 9.2), gp + Vector3(0, 5.6, 0), Color(0.95, 0.75, 0.1), false, gyaw)
	for k in [-1, 1]:
		var post: Vector3 = gp + Vector3(gdir.x, 0, gdir.y) * 6.5 * k
		_box(gnode, Vector3(0.4, 5.2, 0.4), post + Vector3(0, 2.6, 0), Color(0.8, 0.8, 0.8), true)
	for pp in gas.pumps:
		var pump: Vector3 = Vector3(pp.x, world.height_at(pp.x, pp.z), pp.z)
		_box(gnode, Vector3(0.9, 1.8, 0.6), pump + Vector3(0, 0.9, 0), Color(0.9, 0.2, 0.15), true, gyaw)
		_box(gnode, Vector3(0.7, 0.4, 0.62), pump + Vector3(0, 1.4, 0), Color(0.2, 0.2, 0.22), false, gyaw)
		I.add(pump + Vector3(0, 1, 0), 7.0, func(): return game.fuel_prompt(), func(): game.refuel(), func(): game.truck_near(pump, 9.0))
	var shop_p: Vector3 = gas.shop
	_box(gnode, Vector3(9, 3.4, 6), Vector3(shop_p.x, world.height_at(shop_p.x, shop_p.z) + 1.5, shop_p.z), Color(0.92, 0.90, 0.85), true, gyaw)
	var side: Vector2 = gas.side
	var gas_door := Vector3(shop_p.x - side.x * 3.6, 0, shop_p.z - side.y * 3.6)
	gas_door.y = world.height_at(gas_door.x, gas_door.z)
	_sign(gnode, "TANKSTELLE", Color(0.10, 0.45, 0.25), Vector3(shop_p.x - side.x * 3.1, gas_door.y + 3.8, shop_p.z - side.y * 3.1), atan2(-side.x, -side.y), 7.0)
	_npc(gnode, "Tankwart Hias", gas_door, atan2(-side.x, -side.y), {shirt = Color(0.1, 0.45, 0.25), hat = "cap", hat_color = Color(0.1, 0.4, 0.2)})
	I.add(gas_door, 3.0, "Tankstelle (Shop)", func(): game.open_shop("gas"))
	var gsm: Vector3 = gas_door + Vector3(gas.dir.x, 0, gas.dir.y) * 2.2
	_slot_machine(Vector3(gsm.x, world.height_at(gsm.x, gsm.z), gsm.z))
	gas.door = gas_door

	# Werkstatt
	var wnode := Node3D.new()
	wnode.name = "Werkstatt"
	add_child(wnode)
	var wp: Vector3 = garage.pos
	var wy: float = garage.yaw
	var fwd := Vector3(sin(wy), 0, cos(wy))
	var rgt := Vector3(fwd.z, 0, -fwd.x)
	var base_y := world.height_at(wp.x, wp.z) - 0.3
	var c := Vector3(wp.x, base_y, wp.z)
	_box(wnode, Vector3(12, 0.3, 12), c + Vector3(0, 0.15, 0), Color(0.6, 0.6, 0.6), true, wy)  # Boden
	_box(wnode, Vector3(12, 5, 0.4), c - fwd * 6 + Vector3(0, 2.5, 0), Color(0.75, 0.72, 0.68), true, wy)
	for s in [-1, 1]:
		_box(wnode, Vector3(0.4, 5, 12), c + rgt * 6 * s + Vector3(0, 2.5, 0), Color(0.75, 0.72, 0.68), true, wy)
	_box(wnode, Vector3(12.6, 0.4, 12.6), c + Vector3(0, 5.2, 0), Color(0.35, 0.35, 0.38), true, wy)
	_sign(wnode, "WERKSTATT", Color(0.2, 0.2, 0.25), c + fwd * 6.2 + Vector3(0, 5.8, 0), wy, 7.0)
	_npc(wnode, "Mechaniker Gust", c + fwd * 2.0 - rgt * 4.5 + Vector3(0, 0.3, 0), wy, {shirt = Color(0.2, 0.3, 0.55), pants = Color(0.2, 0.3, 0.55), hat = "none"})
	I.add(c + Vector3(0, 1, 0), 9.0, "Werkstatt: Pickup umbauen", func(): game.open_garage(), func(): game.truck_near(c, 10.0))
	I.add(c + fwd * 2.0 - rgt * 4.5, 3.0, "Mechaniker: Pickup holen / reparieren", func(): game.open_garage())

	# Bauplätze
	for pl in plots:
		var pnode := Node3D.new()
		pnode.name = "Bauplatz_%d" % pl.idx
		add_child(pnode)
		pl.node = pnode
		game.refresh_plot(pl)

	# Polizeikontrolle
	if not checkpoint.is_empty():
		var cnode := Node3D.new()
		cnode.name = "Kontrolle"
		add_child(cnode)
		var cp: Vector3 = checkpoint.pos
		var cd: Vector2 = checkpoint.dir
		var cside := Vector2(-cd.y, cd.x)
		for k in range(-3, 4):
			var q: Vector2 = Vector2(cp.x, cp.z) + cd * k * 3.0 + cside * 1.8
			var cone := _box(cnode, Vector3(0.3, 0.6, 0.3), v3(q, 0.3), Color(1.0, 0.45, 0.05))
			cone.position.y += 0.05
		checkpoint.node = cnode


func _slot_machine(p: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	Placeables.box(n, Vector3(0.8, 1.7, 0.6), Vector3(0, 0.85, 0), Color(0.75, 0.1, 0.15), Vector3.ZERO, true)
	Placeables.box(n, Vector3(0.6, 0.35, 0.62), Vector3(0, 1.25, 0), Color(0.95, 0.95, 0.9))
	Placeables.box(n, Vector3(0.7, 0.2, 0.62), Vector3(0, 1.6, 0), Color(1.0, 0.85, 0.2))
	game.interactions.add(Vector3(0, 1, 0), 2.0, "Spielautomat", func(): game.casino.open_slots(), null, n)


func _hall(s: Dictionary) -> void:
	var p: Vector3 = s.pos
	_box(self, Vector3(18, 6, 14), Vector3(p.x, world.height_at(p.x, p.z) + 2.8, p.z), Color(0.85, 0.85, 0.82), true, s.yaw)


## Plakat bzw. Haus auf einem Bauplatz (wird nach dem Kauf neu gebaut)
func plot_sign(pl: Dictionary) -> void:
	var n: Node3D = pl.node
	var p: Vector3 = pl.pos
	var dir := Vector2(sin(pl.yaw), cos(pl.yaw))
	var front: Vector2 = Vector2(p.x, p.z) + dir * 7.0
	_box(n, Vector3(0.15, 1.6, 0.15), v3(front, 0.8), WorldBuilder.WOOD)
	_sign(n, "BAUPLATZ %d" % (pl.idx + 1), Color(0.85, 0.10, 0.10), v3(front, 1.9), pl.yaw, 3.6)
