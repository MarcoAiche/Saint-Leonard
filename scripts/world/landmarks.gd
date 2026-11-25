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
var atv_spawn := {}  # {pos: Vector3, yaw: float}
var butcher_zones: Array = []  # [{pos: Vector3, ring: MeshInstance3D, fill: MeshInstance3D}]

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
	_npc(self, "Wirt Sepp", Vector3(wirt_pos.x, world.height_at(wirt_pos.x, wirt_pos.z), wirt_pos.z), 0.0, {shirt = Color(0.9, 0.9, 0.88), pants = Color(0.2, 0.2, 0.2), hat = "none"})
	I.add(wirt_pos, 3.0, "Gasthaus Pirtscher: Wirt Sepp", func(): game.open_shop("pub"))

	# Spielautomaten beim Gasthaus, an der Tankstelle und beim Supermarkt
	var spots := [wirt_pos + Vector3(1.6, 0, 1.2)]
	if shops.has("super"):
		var sd: Vector3 = shops.super.door
		spots.append(sd + Vector3(sin(shops.super.yaw + PI / 2), 0, cos(shops.super.yaw + PI / 2)) * 2.2)
	for sp in spots:
		_slot_machine(Vector3(sp.x, world.height_at(sp.x, sp.z), sp.z))

	_build_hub_landmarks(I)

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
		_npc(self, npc_name, Vector3(door.x, world.height_at(door.x, door.z), door.z), s.yaw, outfit)
		if id == "police":
			I.add(door, 3.0, "Polizei: Strafen bezahlen", func(): game.police_desk())
		else:
			I.add(door, 3.0, Items.SHOP_NAMES[id], func(): game.open_shop(id))
		# Ankauf vom Pickup (ganzes Wild bei der Fleischerei)
		if id == "butcher":
			I.add(door, 14.0, "Wild von der Ladefläche verkaufen", func(): game.sell_truck_cargo(), func(): game.truck_has_game_near(door, 14.0))
			_add_butcher_dropzone(Vector2(door.x, door.z) + dir * 2.2)

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
			var q: Vector2 = Vector2(cp.x, cp.z) + cd * k * 3.0 + cside * 0.0
			var cone := _box(cnode, Vector3(0.3, 0.6, 0.3), v3(q, 0.3), Color(1.0, 0.45, 0.05))
			cone.position.y += 0.05
		checkpoint.node = cnode


func _slot_machine(p: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var visual := AssetLoader.load_model("res://assets/models/landmarks/lucky_buck_slot.glb", 1.8, func() -> Node3D:
		var fb := Node3D.new()
		Placeables.box(fb, Vector3(0.8, 1.7, 0.6), Vector3(0, 0.85, 0), Color(0.659, 0.125, 0.125), Vector3.ZERO, true)
		Placeables.box(fb, Vector3(0.6, 0.35, 0.62), Vector3(0, 1.25, 0), Color(0.95, 0.95, 0.9))
		Placeables.box(fb, Vector3(0.7, 0.2, 0.62), Vector3(0, 1.6, 0), Color(1.0, 0.85, 0.2))
		return fb
	)
	n.add_child(visual)
	game.interactions.add(Vector3(0, 1, 0), 2.0, func() -> String:
		var pl = game.get("player")
		if pl and pl.carrying is Carcass:
			return "LUCKY BUCK: Kadaver einwerfen (+$%d Pot)" % (pl.carrying as Carcass).sell_value()
		return "Spielautomat (LUCKY BUCK)"
	, func():
		var pl = game.get("player")
		if pl and pl.carrying is Carcass:
			var c := pl.carrying as Carcass
			pl.carrying = null
			var pot := c.sell_value()
			Net.carcass_removed(c.net_id)
			c.queue_free()
			GameState.add_money(pot)
			game.hud.toast("LUCKY BUCK: +$%d POT eingeworfen!" % pot, 3.0)
		game.casino.open_slots()
	, null, n)


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


func _find_hub_spot(center: Vector2, r_min: float, r_max: float, half: float, avoid: Array) -> Dictionary:
	for max_slope in [0.22, 0.45]:
		for t in 500:
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(r_min, r_max)
			var p := center + Vector2(cos(a), sin(a)) * d
			if world.border_distance(p) < 60.0:
				continue
			var kind := world.kind_at(p.x, p.y)
			if kind in ["water", "industrial", "cemetery", "parking"]:
				continue
			if world.slope_at(p.x, p.y) > max_slope:
				continue
			var road := world.road_info(p, 45.0)
			if road.tier == 0 or road.dist < half + 4.0 or road.dist > half + 32.0:
				continue
			if not buildings_near(p, half + 6.5).is_empty():
				continue
			var ok := true
			for c in [Vector2(half, half), Vector2(-half, half), Vector2(half, -half), Vector2(-half, -half)]:
				if world.road_info(p + c, 2.5).tier != 0:
					ok = false
					break
			if not ok:
				continue
			for q in avoid:
				if (q as Vector2).distance_to(p) < half * 2.0 + 9.0:
					ok = false
					break
			if not ok:
				continue
			var to_road: Vector2 = (road.pos - p).normalized()
			return {pos = p, yaw = atan2(to_road.x, to_road.y)}
	return {}


func _foundation_skirt(parent: Node3D, w: float, d: float, col: Color) -> void:
	_box(parent, Vector3(w, 1.4, d), Vector3(0, -0.65, 0), col, true)


func _build_hub_landmarks(I: Interactions) -> void:
	var pub_2d := Vector2(pub.pos.x, pub.pos.z)
	var avoid: Array = [Vector2(pub.door.x, pub.door.z), Vector2(spawn.pos.x, spawn.pos.z)]

	# 1. Hunting Lodge Akzente direkt am Gasthaus Pirtscher
	var lodge := Node3D.new()
	lodge.name = "HuntingLodgeProps"
	add_child(lodge)
	var ld: Vector3 = pub.door
	var lyaw := atan2(spawn.pos.x - ld.x, spawn.pos.z - ld.z)
	var lpos := Vector3(ld.x, world.height_at(ld.x, ld.z), ld.z)
	var lfwd := Vector3(sin(lyaw), 0, cos(lyaw))
	var lrgt := Vector3(lfwd.z, 0, -lfwd.x)
	_sign(lodge, "HUNTING LODGE", Color(0.290, 0.188, 0.102), lpos + Vector3(0, 4.4, 0) + lfwd * 0.4, lyaw, 5.2)
	for s: float in [-3.4, 3.4]:
		var pbase: Vector3 = lpos + lrgt * s + lfwd * 0.8
		pbase.y = world.height_at(pbase.x, pbase.z)
		_box(lodge, Vector3(0.42, 0.9, 0.42), pbase + Vector3(0, 0.45, 0), Color(0.478, 0.510, 0.549), false)
		_box(lodge, Vector3(0.22, 2.3, 0.22), pbase + Vector3(0, 2.0, 0), Color(0.549, 0.369, 0.204), false)
		var lant := _box(lodge, Vector3(0.26, 0.34, 0.26), pbase + Vector3(0, 2.9, 0) + lfwd * 0.25, Color(1.0, 0.80, 0.333))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.667, 0.267)  # #FFAA44
		light.light_energy = 1.6
		light.omni_range = 9.0
		lant.add_child(light)

	# 2. Butcher "GASTON" Food Truck
	var gspot := _find_hub_spot(pub_2d, 14.0, 55.0, 4.2, avoid)
	if not gspot.is_empty():
		avoid.append(gspot.pos)
		var gp2: Vector2 = gspot.pos
		var gy := world.height_at(gp2.x, gp2.y)
		var tn := Node3D.new()
		tn.name = "ButcherFoodTruck"
		tn.position = Vector3(gp2.x, gy, gp2.y)
		tn.rotation.y = gspot.yaw
		add_child(tn)
		_foundation_skirt(tn, 6.2, 3.2, Color(0.48, 0.46, 0.42))
		var truck_vis := AssetLoader.load_model("res://assets/models/landmarks/gaston_food_truck.glb", 3.6, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(5.6, 2.4, 2.5), Vector3(0, 1.55, 0), Color(0.937, 0.910, 0.847), true)   # #EFE8D8 Cream van
			_box(fb, Vector3(5.7, 0.55, 2.56), Vector3(0, 0.65, 0), Color(0.722, 0.157, 0.157), true) # #B82828 Crimson skirt
			_box(fb, Vector3(1.6, 1.7, 2.4), Vector3(3.4, 1.2, 0), Color(0.937, 0.910, 0.847), true)  # Cab
			_box(fb, Vector3(3.2, 0.18, 1.1), Vector3(0.2, 2.35, 1.75), Color(0.722, 0.157, 0.157))   # Awning
			_box(fb, Vector3(2.0, 0.9, 0.28), Vector3(0.0, 3.2, 0), Color(0.784, 0.220, 0.220))       # #C83838 Steak sign
			_box(fb, Vector3(0.45, 0.45, 0.34), Vector3(1.1, 3.2, 0), Color(0.941, 0.929, 0.902))     # #F0EDE6 Bone
			for wx in [-1.8, 2.6]:
				for wz in [-1.2, 1.2]:
					_box(fb, Vector3(0.75, 0.75, 0.32), Vector3(wx, 0.38, wz), Color(0.165, 0.173, 0.188))
			return fb
		)
		tn.add_child(truck_vis)
		_sign(tn, "GASTON BUTCHER", Color(0.722, 0.157, 0.157), Vector3(0, 3.9, 1.3), 0.0, 4.4)
		var g_npc_pos := tn.to_global(Vector3(0.4, 0.0, 2.1))
		g_npc_pos.y = world.height_at(g_npc_pos.x, g_npc_pos.z)
		_npc(self, "GASTON", g_npc_pos, gspot.yaw, {shirt = Color(0.941, 0.941, 0.925), pants = Color(0.18, 0.18, 0.20), hat = "none"})
		I.add(g_npc_pos, 3.5, "Butcher Gaston: Wild verkaufen", func(): game.open_shop("butcher"))
		var g_fwd := Vector2(sin(gspot.yaw), cos(gspot.yaw))
		var dz_2d := Vector2(g_npc_pos.x, g_npc_pos.z) + g_fwd * 2.0
		if world.road_info(dz_2d, 3.5).tier != 0:
			dz_2d = Vector2(g_npc_pos.x, g_npc_pos.z) - g_fwd * 1.2
		_add_butcher_dropzone(dz_2d)
		_log_hub_pos("GASTON Drop-Zone (Roter Kreis)", dz_2d)
		print("Hub [GASTON Food Truck]: (%.1f, %.1f) | %.1fm von Gasthaus Pirtscher" % [gp2.x, gp2.y, gp2.distance_to(pub_2d)])

	# 3. Outdoor Weapon Shack
	var wspot := _find_hub_spot(pub_2d, 16.0, 65.0, 4.0, avoid)
	if not wspot.is_empty():
		avoid.append(wspot.pos)
		var wp2: Vector2 = wspot.pos
		var wy := world.height_at(wp2.x, wp2.y)
		var wn := Node3D.new()
		wn.name = "WeaponShack"
		wn.position = Vector3(wp2.x, wy, wp2.y)
		wn.rotation.y = wspot.yaw
		add_child(wn)
		_foundation_skirt(wn, 5.4, 4.2, Color(0.38, 0.32, 0.26))
		var shack_vis := AssetLoader.load_model("res://assets/models/landmarks/weapon_shack.glb", 3.4, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(5.0, 3.0, 0.3), Vector3(0, 1.5, -1.7), Color(0.431, 0.294, 0.184), true)  # #6E4B2F Back wall
			for sx in [-2.35, 2.35]:
				_box(fb, Vector3(0.3, 3.0, 3.4), Vector3(sx, 1.5, 0), Color(0.431, 0.294, 0.184), true)
			_box(fb, Vector3(5.6, 0.28, 4.2), Vector3(0, 3.2, 0), Color(0.361, 0.239, 0.133), true)    # Roof
			_box(fb, Vector3(4.2, 1.0, 0.9), Vector3(0, 0.5, 1.35), Color(0.549, 0.384, 0.220), true)   # Counter
			_box(fb, Vector3(0.9, 0.55, 0.6), Vector3(-1.1, 1.28, 1.35), Color(0.306, 0.408, 0.220))  # #4E6838 Olive ammo crate
			_box(fb, Vector3(0.8, 0.50, 0.55), Vector3(0.9, 1.25, 1.35), Color(0.659, 0.157, 0.157))  # #A82828 Red crate
			_box(fb, Vector3(0.75, 1.0, 0.75), Vector3(2.9, 0.5, 1.1), Color(0.549, 0.384, 0.220), true)  # #8C6238 Barrel
			return fb
		)
		wn.add_child(shack_vis)
		_sign(wn, "WEAPON SHACK", Color(0.306, 0.408, 0.220), Vector3(0, 3.9, 1.9), 0.0, 4.4)
		var gs_pos := wn.to_global(Vector3(0, 0, 2.3))
		gs_pos.y = world.height_at(gs_pos.x, gs_pos.z)
		_npc(self, "Gunsmith", gs_pos, wspot.yaw, {shirt = Color(0.306, 0.353, 0.220), pants = Color(0.165, 0.173, 0.188), hat = "none"})
		I.add(gs_pos, 3.5, "Weapon Shack: Waffen & Munition", func(): game.open_shop("gun"))
		print("Hub [Weapon Shack]: (%.1f, %.1f) | %.1fm von Gasthaus Pirtscher" % [wp2.x, wp2.y, wp2.distance_to(pub_2d)])

	# 4. Camper RV
	var rvspot := _find_hub_spot(pub_2d, 18.0, 75.0, 4.2, avoid)
	if not rvspot.is_empty():
		avoid.append(rvspot.pos)
		var rp2: Vector2 = rvspot.pos
		var ry := world.height_at(rp2.x, rp2.y)
		var rn := Node3D.new()
		rn.name = "CamperRV"
		rn.position = Vector3(rp2.x, ry, rp2.y)
		rn.rotation.y = rvspot.yaw
		add_child(rn)
		_foundation_skirt(rn, 6.2, 2.8, Color(0.45, 0.45, 0.44))
		var rv_vis := AssetLoader.load_model("res://assets/models/landmarks/camper_rv.glb", 2.9, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(5.8, 2.3, 2.4), Vector3(0, 1.55, 0), Color(0.918, 0.925, 0.910), true)   # #EAECE8 White RV
			_box(fb, Vector3(5.85, 0.55, 2.44), Vector3(0, 0.95, 0), Color(0.298, 0.651, 0.659))      # #4CA6A8 Turquoise stripe
			for wx in [-1.6, 1.6]:
				for wz in [-1.15, 1.15]:
					_box(fb, Vector3(0.7, 0.7, 0.28), Vector3(wx, 0.35, wz), Color(0.14, 0.14, 0.16))
			return fb
		)
		rn.add_child(rv_vis)
		print("Hub [Camper RV]: (%.1f, %.1f) | %.1fm von Gasthaus Pirtscher" % [rp2.x, rp2.y, rp2.distance_to(pub_2d)])

	# 5. Campfire & Wooden Rocking Chair
	var cfspot := _find_hub_spot(pub_2d, 10.0, 45.0, 2.8, avoid)
	if not cfspot.is_empty():
		var cp2: Vector2 = cfspot.pos
		var cy := world.height_at(cp2.x, cp2.y)
		var cn := Node3D.new()
		cn.name = "CampfireSpot"
		cn.position = Vector3(cp2.x, cy, cp2.y)
		cn.rotation.y = cfspot.yaw
		add_child(cn)
		var cf_vis := AssetLoader.load_model("res://assets/models/props/campfire.glb", 0.6, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(1.2, 0.25, 1.2), Vector3(0, 0.1, 0), Color(0.478, 0.510, 0.549), true)
			_box(fb, Vector3(0.45, 0.65, 0.45), Vector3(0, 0.45, 0), Color(1.0, 0.467, 0.067))  # #FF7711
			return fb
		)
		cn.add_child(cf_vis)
		var fl := OmniLight3D.new()
		fl.position = Vector3(0, 0.6, 0)
		fl.light_color = Color(0.910, 0.416, 0.125)  # #E86A20
		fl.light_energy = 1.8
		fl.omni_range = 10.0
		cn.add_child(fl)
		var fl_tw := cn.create_tween().set_loops()
		fl_tw.tween_property(fl, "light_energy", 2.3, 0.18)
		fl_tw.tween_property(fl, "light_energy", 1.4, 0.22)
		# Aufsteigende Lagerfeuer-Funken (#FFEE88)
		var sparks := GPUParticles3D.new()
		sparks.amount = 16
		sparks.lifetime = 1.4
		sparks.position = Vector3(0, 0.5, 0)
		var spm := ParticleProcessMaterial.new()
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		spm.emission_sphere_radius = 0.25
		spm.direction = Vector3.UP
		spm.spread = 22.0
		spm.initial_velocity_min = 0.9
		spm.initial_velocity_max = 1.8
		spm.gravity = Vector3(0, 0.2, 0)
		sparks.process_material = spm
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(1.0, 0.933, 0.533)  # #FFEE88
		sm.material = smat
		sparks.draw_pass_1 = sm
		cn.add_child(sparks)
		var fire_sfx := AudioStreamPlayer3D.new()
		fire_sfx.stream = Sfx.campfire()
		fire_sfx.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
		fire_sfx.unit_size = 4.0
		fire_sfx.max_distance = 18.0
		fire_sfx.volume_db = -4.0
		fire_sfx.autoplay = true
		cn.add_child(fire_sfx)
		# Rocking Chair neben dem Lagerfeuer
		var chair := AssetLoader.load_model("res://assets/models/props/rocking_chair.glb", 1.1, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(0.7, 0.12, 0.7), Vector3(0, 0.48, 0), Color(0.549, 0.369, 0.204), true)
			_box(fb, Vector3(0.7, 0.75, 0.12), Vector3(0, 0.9, -0.3), Color(0.549, 0.369, 0.204), true)
			_box(fb, Vector3(0.1, 0.12, 1.0), Vector3(-0.3, 0.08, 0), Color(0.361, 0.239, 0.133))
			_box(fb, Vector3(0.1, 0.12, 1.0), Vector3(0.3, 0.08, 0), Color(0.361, 0.239, 0.133))
			return fb
		)
		chair.position = Vector3(1.6, 0, 0)
		cn.add_child(chair)
		var chair_world := cn.to_global(Vector3(1.6, 0.5, 0))
		I.add(chair_world, 2.4, "Schaukelstuhl (Sitzen & Schaukeln)", func():
			var pl = game.get("player")
			if pl and pl.has_method("knockdown"):
				pl.sitting = true
				pl.global_position = Vector3(chair_world.x, world.height_at(chair_world.x, chair_world.z) + 0.1, chair_world.z)
				var tw := create_tween()
				tw.tween_property(chair, "rotation:x", deg_to_rad(-18.0), 0.55)
				tw.tween_property(chair, "rotation:x", deg_to_rad(28.0), 0.65)
				tw.tween_property(chair, "rotation:x", deg_to_rad(-42.0), 0.55)
				tw.tween_callback(func():
					pl.sitting = false
					pl.knockdown(2.0, "Schaukelstuhl gekippt!", Vector3(0, 2.2, 0))
					var rtw := create_tween()
					rtw.tween_property(chair, "rotation:x", 0.0, 1.0).set_delay(1.5)
				)
		)
		_log_hub_pos("GASTON Food Truck", Vector2(gspot.pos.x, gspot.pos.y))
		_log_hub_pos("Weapon Shack", Vector2(wspot.pos.x, wspot.pos.y))
		_log_hub_pos("Camper RV", Vector2(rvspot.pos.x, rvspot.pos.y))
		_log_hub_pos("Campfire & Rocking Chair", cp2)

	# 6. Dept. of Wildlife Field Office 07 Trailer + Kegel
	var wfo_center := Vector2(gas.pos.x, gas.pos.z) if not gas.is_empty() else pub_2d
	var fspot := _find_hub_spot(wfo_center, 18.0, 80.0, 4.5, avoid)
	if not fspot.is_empty():
		var fp2: Vector2 = fspot.pos
		var fy := world.height_at(fp2.x, fp2.y)
		var fn := Node3D.new()
		fn.name = "WildlifeFieldOffice07"
		fn.position = Vector3(fp2.x, fy, fp2.y)
		fn.rotation.y = fspot.yaw
		add_child(fn)
		_foundation_skirt(fn, 6.4, 3.0, Color(0.55, 0.57, 0.60))
		var wfo_vis := AssetLoader.load_model("res://assets/models/landmarks/wildlife_office_07.glb", 3.2, func() -> Node3D:
			var fb := Node3D.new()
			_box(fb, Vector3(6.0, 2.4, 2.5), Vector3(0, 1.5, 0), Color(0.863, 0.886, 0.910), true)  # #DCE2E8
			for kx in [-2.2, 2.2]:
				var cone := _box(fb, Vector3(0.32, 0.65, 0.32), Vector3(kx, 0.32, 1.6), Color(1.0, 0.416, 0.102))  # #FF6A1A
				_box(cone, Vector3(0.28, 0.16, 0.33), Vector3(0, 0.08, 0), Color(1, 1, 1))
			return fb
		)
		fn.add_child(wfo_vis)
		_sign(fn, "DEPT. OF WILDLIFE / FIELD OFFICE 07", Color(0.22, 0.28, 0.35), Vector3(0, 3.1, 1.32), 0.0, 5.4)
		var ag_pos := fn.to_global(Vector3(0.0, 0.0, 2.0))
		ag_pos.y = world.height_at(ag_pos.x, ag_pos.z)
		_npc(self, "Wildlife Agent", ag_pos, fspot.yaw, {shirt = Color(0.94, 0.94, 0.94), pants = Color(0.094, 0.094, 0.102), jacket = false, hat = "none", glasses = true})
		_log_hub_pos("Wildlife Field Office 07", fp2)

	# 7. Green 4x4 ATV / Quad Bike am Camp Hub
	var aspot := _find_hub_spot(pub_2d, 10.0, 38.0, 2.2, avoid)
	if not aspot.is_empty():
		var ap2: Vector2 = aspot.pos
		atv_spawn = {pos = Vector3(ap2.x, world.height_at(ap2.x, ap2.y) + 0.6, ap2.y), yaw = aspot.yaw}
		_log_hub_pos("Green 4x4 ATV", ap2)
	_log_hub_pos("Swamp Biome (West/NW Gail)", Vector2(-220.0, -180.0))
	_log_hub_pos("Southern Mountains (Bear/Bigfoot)", Vector2(200.0, 1400.0))


func _log_hub_pos(label: String, p2: Vector2) -> void:
	var sp2 := Vector2(spawn.pos.x, spawn.pos.z)
	var d := p2 - sp2
	var ang := rad_to_deg(atan2(d.x, -d.y))
	if ang < 0.0:
		ang += 360.0
	var dirs := ["N", "NO", "O", "SO", "S", "SW", "W", "NW"]
	var compass: String = dirs[int(round(ang / 45.0)) % 8]
	print("HUB_POS | %s | (%.1f, %.1f) | %.1fm | %s" % [label, p2.x, p2.y, d.length(), compass])


func _add_butcher_dropzone(p2: Vector2) -> void:
	var y := world.height_at(p2.x, p2.y) + 0.04
	var holder := Node3D.new()
	holder.name = "ButcherDropZone"
	holder.position = Vector3(p2.x, y, p2.y)
	# An Bodenneigung anpassen
	var h_x := world.height_at(p2.x + 1.0, p2.y) - world.height_at(p2.x - 1.0, p2.y)
	var h_z := world.height_at(p2.x, p2.y + 1.0) - world.height_at(p2.x, p2.y - 1.0)
	var nrm := Vector3(-h_x, 2.0, -h_z).normalized()
	if nrm.y > 0.5:
		var up := nrm
		var fwd := Vector3.FORWARD.slide(up).normalized()
		if fwd.length_squared() > 0.01:
			holder.basis = Basis(fwd.cross(up).normalized(), up, fwd)
	add_child(holder)

	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = 1.05
	fill_mesh.bottom_radius = 1.05
	fill_mesh.height = 0.025
	fill_mesh.radial_segments = 28
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = Color(0.851, 0.169, 0.169, 0.36)  # #D92B2B
	var fill_mi := MeshInstance3D.new()
	fill_mi.mesh = fill_mesh
	fill_mi.material_override = fill_mat
	fill_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(fill_mi)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.96
	ring_mesh.outer_radius = 1.08
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.851, 0.169, 0.169, 1.0)  # #D92B2B
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring_mesh
	ring_mi.position.y = 0.02
	ring_mi.material_override = ring_mat
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring_mi)

	var lbl := Label3D.new()
	lbl.text = "WILD HIER ABLEGEN"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.92, 0.88)
	lbl.position = Vector3(0, 0.55, 0)
	holder.add_child(lbl)

	butcher_zones.append({pos = Vector3(p2.x, y, p2.y), ring = ring_mi, fill = fill_mi})


func flash_butcher_zone(zone: Dictionary) -> void:
	var ring_mi: MeshInstance3D = zone.ring
	var fill_mi: MeshInstance3D = zone.fill
	if ring_mi and fill_mi:
		(ring_mi.material_override as StandardMaterial3D).albedo_color = Color(0.20, 0.92, 0.38, 1.0)
		(fill_mi.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.80, 0.20, 0.55)
		get_tree().create_timer(0.65).timeout.connect(func():
			if is_instance_valid(ring_mi) and is_instance_valid(fill_mi):
				(ring_mi.material_override as StandardMaterial3D).albedo_color = Color(0.851, 0.169, 0.169, 1.0)
				(fill_mi.material_override as StandardMaterial3D).albedo_color = Color(0.851, 0.169, 0.169, 0.36)
		)
