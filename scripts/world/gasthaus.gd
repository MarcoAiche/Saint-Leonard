@tool
class_name Gasthaus
extends Node3D
## Gasthaus Pirtscher (Riegersdorf 1), begehbar: Gaststube mit Schank (Kellnerin Gerti, gleiches
## Angebot wie bei Wirt Sepp), Tischen und Eckbank, Stammtisch mit Stammgästen, Kachelofen,
## Herrgottswinkel, Geweihluster und einer freien Wand für die Trophäen (Issue #9).
## Steht auf dem echten Grundriss aus den Kartendaten; Wirt Sepp bleibt vor der Tür.
## Lokale Achsen: +Z zeigt zur Straße (dort ist die Tür).

const OSM_ID := 282883314
const WALL_H := 3.3  # Gaststube
const UPPER_H := 2.8  # Obergeschoss (nur von außen)

var game: Node
var world: WorldBuilder
@export var size := Vector2(13.6, 16.0)
var door := Vector3.ZERO  # Weltposition vor der Tür
var trophy_wall := Transform3D.IDENTITY  # lokale Lage der Trophäenwand (Mitte, Blick in den Raum)
var board: TrophyBoard


## Lage und Größe aus dem Gebäude in den Kartendaten (Tür auf der Straßenseite)
static func find(w: WorldBuilder) -> Dictionary:
	for b in w.data.buildings:
		if int(b.id) != OSM_ID:
			continue
		var poly := WorldBuilder.to_v2_array(b.pts)
		var o := WorldBuilder._obb(poly)
		var c: Vector2 = o.c
		var road := w.road_info(c, 80.0)
		var to_road: Vector2 = (road.pos - c).normalized() if road.tier != 0 else Vector2(0, 1)
		var u: Vector2 = o.u
		var v: Vector2 = o.v
		var front: Vector2
		var sz: Vector2
		if absf(to_road.dot(u)) > absf(to_road.dot(v)):
			front = u * signf(to_road.dot(u))
			sz = Vector2(o.hw * 2.0, o.hl * 2.0)
		else:
			front = v * signf(to_road.dot(v))
			sz = Vector2(o.hl * 2.0, o.hw * 2.0)
		sz = Vector2(clampf(sz.x, 11.0, 22.0), clampf(sz.y, 9.0, 16.0))
		return {pos = c, yaw = atan2(front.x, front.y), size = sz}
	return {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_clear_generated()
		_build()


func _clear_generated() -> void:
	for ch in get_children():
		if ch.owner == null:
			remove_child(ch)
			ch.queue_free()


func setup_in_scene(g: Node, w: WorldBuilder) -> void:
	game = g
	world = w
	_clear_generated()
	_build()
	door = global_transform * Vector3(0, 0, size.y * 0.5 + 1.5)


func setup(g: Node, w: WorldBuilder, info: Dictionary) -> void:
	game = g
	world = w
	size = info.size
	var c: Vector2 = info.pos
	rotation.y = info.yaw
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var base := -INF
	for k in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz), Vector2.ZERO]:
		var wp := c + (k as Vector2).rotated(-float(info.yaw))
		base = maxf(base, w.height_at(wp.x, wp.y))
	global_position = Vector3(c.x, base, c.y)
	_build()
	door = global_transform * Vector3(0, 0, hz + 1.5)


func _box(sz: Vector3, pos: Vector3, col: Color, collide := false, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	return Placeables.box(parent, sz, pos, col, rot, collide)


func _build() -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var t := 0.3
	var white := Color(0.97, 0.95, 0.9)
	var wood := Placeables.WOOD
	var dark := Placeables.DARK_WOOD
	var roof := Color(0.6, 0.2, 0.15)
	var total := WALL_H + UPPER_H
	# Sockel, Boden, Decke
	_box(Vector3(size.x + 0.4, 1.4, size.y + 0.4), Vector3(0, -0.6, 0), Color(0.62, 0.6, 0.58), true)
	_box(Vector3(size.x - 0.2, 0.05, size.y - 0.2), Vector3(0, 0.13, 0), Color(0.55, 0.38, 0.22))
	# Stufe vor der Tür, begehbar über eine flache unsichtbare Rampe
	_box(Vector3(2.4, 0.5, 1.0), Vector3(0, -0.15, hz + 0.7), Color(0.55, 0.54, 0.52))
	var ramp := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 0.1, 2.6)
	cs.shape = bs
	ramp.add_child(cs)
	ramp.position = Vector3(0, -0.12, hz + 1.3)
	ramp.rotation.x = atan2(0.5, 2.5)
	add_child(ramp)
	var plank := -hx + 0.45
	while plank < hx - 0.2:
		_box(Vector3(0.03, 0.01, size.y - 0.4), Vector3(plank, 0.16, 0), Color(0.4, 0.27, 0.15))
		plank += 0.45
	_box(Vector3(size.x, 0.2, size.y), Vector3(0, WALL_H + 0.1, 0), Color(0.62, 0.45, 0.28), true)  # Holzdecke
	for k in 5:
		_box(Vector3(size.x - 0.6, 0.22, 0.22), Vector3(0, WALL_H - 0.08, -hz + (k + 0.5) * size.y / 5.0), dark)
	# Außenwände (zwei Stockwerke), Tür vorne in der Mitte
	_box(Vector3(size.x, total, t), Vector3(0, total * 0.5 + 0.1, -hz), white, true)
	for s in [-1, 1]:
		_box(Vector3(t, total, size.y), Vector3(hx * s, total * 0.5 + 0.1, 0), white, true)
	var door_w := 1.8
	var side := (size.x - door_w) * 0.5
	for s in [-1, 1]:
		_box(Vector3(side, total, t), Vector3((door_w * 0.5 + side * 0.5) * s, total * 0.5 + 0.1, hz), white, true)
	_box(Vector3(door_w, total - 2.5, t), Vector3(0, 2.5 + (total - 2.5) * 0.5 + 0.1, hz), white, true)
	# Holzvertäfelung innen
	_box(Vector3(size.x - 0.6, 1.2, 0.04), Vector3(0, 0.75, -hz + 0.17), wood)
	for s in [-1, 1]:
		_box(Vector3(0.04, 1.2, size.y - 0.6), Vector3((hx - 0.17) * s, 0.75, 0), wood)
		_box(Vector3(side - 0.3, 1.2, 0.04), Vector3((door_w * 0.5 + side * 0.5) * s, 0.75, hz - 0.17), wood)
	# Fenster mit grünen Fensterläden
	var glass := Color(0.55, 0.72, 0.85)
	var shutter := Color(0.2, 0.42, 0.25)
	for lvl in 2:
		var y := 1.7 + lvl * WALL_H
		var n_front := int(size.x / 3.5)
		for k in n_front:
			var x := -hx + (k + 0.5) * size.x / n_front
			if absf(x) < door_w and lvl == 0:
				continue
			for zz in [hz + 0.17, -hz - 0.17]:
				_box(Vector3(1.0, 1.2, 0.05), Vector3(x, y, zz), glass)
				for s in [-1, 1]:
					_box(Vector3(0.45, 1.25, 0.06), Vector3(x + 0.75 * s, y, zz), shutter)
		var n_side := int(size.y / 3.5)
		for k in n_side:
			var z := -hz + (k + 0.5) * size.y / n_side
			for s in [-1, 1]:
				_box(Vector3(0.05, 1.2, 1.0), Vector3((hx + 0.17) * s, y, z), glass)
	# Satteldach mit Holzgiebel
	var rh := minf(size.x, size.y) * 0.3
	var top := total + 0.1
	var rl := sqrt(hz * hz + rh * rh) + 0.6
	var ang := atan2(rh, hz)
	for s in [-1, 1]:
		_box(Vector3(size.x + 1.0, 0.22, rl), Vector3(0, top + rh * 0.5, hz * 0.5 * s), roof, true, Vector3(ang * s, 0, 0))
	for k in 5:
		var f := (k + 0.5) / 5.0
		for s in [-1, 1]:
			_box(Vector3(t, rh / 5.0, size.y * (1.0 - f)), Vector3(hx * s, top + rh * f - rh / 10.0, 0), wood)
	# Schild und Wirtshausschild
	var sign := Label3D.new()
	sign.text = "GASTHAUS PIRTSCHER"
	sign.font_size = 96
	sign.pixel_size = minf(0.01, (size.x - 2.0) * 0.85 / (18.0 * 96.0 * 0.6))
	sign.modulate = Color(0.45, 0.15, 0.08)
	sign.outline_size = 10
	sign.outline_modulate = Color(1, 0.95, 0.85)
	sign.position = Vector3(0, WALL_H + 0.6, hz + 0.2)
	add_child(sign)
	_box(Vector3(0.08, 0.08, 1.0), Vector3(door_w * 0.5 + 0.6, 2.9, hz + 0.6), dark)
	var board := _box(Vector3(0.05, 0.8, 0.8), Vector3(door_w * 0.5 + 0.6, 2.4, hz + 1.0), Color(0.85, 0.7, 0.3))
	board.rotation.y = PI / 2
	# Licht
	for x in [-hx * 0.5, hx * 0.5]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, WALL_H - 0.5, 0)
		l.omni_range = maxf(size.x, size.y) * 0.7
		l.light_energy = 1.2
		l.light_color = Color(1.0, 0.82, 0.6)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 35.0
		l.distance_fade_length = 15.0
		add_child(l)
	_geweihluster(Vector3(0, WALL_H - 0.6, 0))
	_furnish(hx, hz)


func _furnish(hx: float, hz: float) -> void:
	var wood := Placeables.WOOD
	var dark := Placeables.DARK_WOOD
	var I: Interactions = game.interactions if (not Engine.is_editor_hint() and game != null) else null
	# Schank hinten links: Theke, Zapfhähne, Flaschenregal, Kellnerin
	var bx := -hx + 3.2
	var bz := -hz + 1.6
	_box(Vector3(4.2, 1.15, 0.7), Vector3(bx, 0.7, bz + 0.5), wood, true)
	_box(Vector3(4.4, 0.08, 0.9), Vector3(bx, 1.3, bz + 0.5), dark)
	for k in 3:
		Placeables.cyl(self, 0.04, 0.35, Vector3(bx - 0.6 + k * 0.6, 1.5, bz + 0.4), Color(0.8, 0.8, 0.82))
	_box(Vector3(4.0, 1.8, 0.35), Vector3(bx, 2.0, -hz + 0.35), dark)
	for k in 12:
		Placeables.cyl(self, 0.05, 0.3, Vector3(bx - 1.7 + (k % 6) * 0.68, 1.65 + (k / 6) * 0.6, -hz + 0.4), Color.from_hsv(0.05 + k * 0.04, 0.55, 0.55))
	if I != null:
		var gerti := Npc.new("Kellnerin Gerti", {shirt = Color(0.95, 0.95, 0.92), pants = Color(0.15, 0.35, 0.2), hat = "none"})
		add_child(gerti)
		gerti.position = Vector3(bx, 0.15, bz - 0.2)
		I.add(Vector3(bx, 1.0, bz + 1.2), 2.8, "Schank: Kellnerin Gerti", func(): game.open_shop("pub"), null, self)
	# Tische mit Bänken
	var tables := [Vector3(2.0, 0, -1.5), Vector3(2.0, 0, 2.0), Vector3(-1.5, 0, 2.2)]
	for tp in tables:
		_table_with_benches(tp + Vector3(0, 0.15, 0))
	# Eckbank mit Herrgottswinkel vorne rechts
	var ex := hx - 0.6
	var ez := hz - 0.6
	_box(Vector3(0.6, 0.45, 3.0), Vector3(ex, 0.38, ez - 1.6), wood, true)
	_box(Vector3(3.0, 0.45, 0.6), Vector3(ex - 1.6, 0.38, ez), wood, true)
	_box(Vector3(1.4, 0.06, 1.2), Vector3(ex - 1.4, 0.9, ez - 1.4), wood, true)
	_box(Vector3(0.1, 0.85, 0.1), Vector3(ex - 1.4, 0.48, ez - 1.4), dark)
	var cross := Node3D.new()
	cross.position = Vector3(hx - 0.3, 2.5, hz - 0.3)
	cross.rotation.y = -PI / 4
	add_child(cross)
	_box(Vector3(0.06, 0.6, 0.05), Vector3.ZERO, dark, false, Vector3.ZERO, cross)
	_box(Vector3(0.35, 0.06, 0.05), Vector3(0, 0.12, 0), dark, false, Vector3.ZERO, cross)
	for s in [-1, 1]:
		var seat := Vector3(ex - 1.4, -0.3, ez - 1.4) + (Vector3(1.3, 0, 0) if s > 0 else Vector3(0, 0, 1.3))
		if I != null:
			I.add(seat + Vector3(0, 0.5, 0), 1.2, "Hinsetzen", func(): game.sit_down(global_transform * seat, global_rotation.y + (PI / 2 if s > 0 else 0.0)), null, self)
	# Stammtisch mit Stammgästen
	var st := Vector3(-1.8, 0.15, -2.0)
	Placeables.cyl(self, 0.9, 0.08, st + Vector3(0, 0.78, 0), wood)
	Placeables.cyl(self, 0.15, 0.75, st + Vector3(0, 0.38, 0), dark)
	var plate := Label3D.new()
	plate.text = "STAMMTISCH"
	plate.font_size = 40
	plate.pixel_size = 0.005
	plate.modulate = Color(0.95, 0.85, 0.4)
	plate.position = st + Vector3(0, 1.25, 0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(plate)
	var guests := [["Altbauer Hubert", Color(0.35, 0.3, 0.25), "hunter"], ["Lois vom Berg", Color(0.6, 0.25, 0.2), "cap"], ["Pensionist Ferdinand", Color(0.4, 0.45, 0.55), "none"]]
	for k in guests.size():
		var a := TAU * k / 3.0 + 0.4
		var pos := st + Vector3(cos(a) * 1.4, -0.45, sin(a) * 1.4)
		_box(Vector3(0.45, 0.45, 0.45), st + Vector3(cos(a) * 1.4, 0.07, sin(a) * 1.4), Placeables.DARK_WOOD)
		if I != null:
			var g := SittingNpc.new(guests[k][0], {shirt = guests[k][1], hat = guests[k][2], hat_color = Color(0.25, 0.32, 0.2)})
			add_child(g)
			g.position = pos
			g.rotation.y = atan2(st.x - pos.x, st.z - pos.z)
		Placeables.cyl(self, 0.04, 0.2, st + Vector3(cos(a) * 0.5, 0.92, sin(a) * 0.5), Color(0.45, 0.28, 0.08))  # Bierglas
	# Kachelofen mit Ofenbank hinten rechts
	var stove := Placeables.model("stove")
	stove.position = Vector3(hx - 1.5, 0.15, -hz + 0.9)
	add_child(stove)
	# Trophäenwand: linke Wand, frei für Geweihe (Issue #9)
	trophy_wall = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-hx + 0.25, 2.2, 1.0))
	_box(Vector3(0.04, 1.9, 4.6), Vector3(-hx + 0.2, 2.25, 1.0), dark)
	if I != null:
		board = TrophyBoard.new()
		board.name = "Trophaeenwand"
		board.setup(game, self, trophy_wall)


func _table_with_benches(p: Vector3) -> void:
	var wood := Placeables.WOOD
	_box(Vector3(1.8, 0.07, 0.9), p + Vector3(0, 0.78, 0), wood, true)
	for s in [-1, 1]:
		_box(Vector3(0.08, 0.75, 0.7), p + Vector3(0.75 * s, 0.38, 0), Placeables.DARK_WOOD)
		_box(Vector3(1.8, 0.06, 0.35), p + Vector3(0, 0.45, 0.75 * s), wood)
		_box(Vector3(0.08, 0.45, 0.3), p + Vector3(0, 0.22, 0.75 * s), Placeables.DARK_WOOD)
		var seat := p + Vector3(0.4, -0.45, 0.75 * s)
		if not Engine.is_editor_hint() and game != null:
			game.interactions.add(seat + Vector3(0, 0.6, 0), 1.0, "Hinsetzen", func(): game.sit_down(global_transform * seat, global_rotation.y + (PI if s > 0 else 0.0)), null, self)
	Placeables.cyl(self, 0.04, 0.2, p + Vector3(-0.3, 0.92, 0.1), Color(0.45, 0.28, 0.08))


## Geweihluster: Leuchter aus Geweihstangen über der Gaststube
func _geweihluster(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var antler := Color(0.88, 0.8, 0.62)
	Placeables.cyl(n, 0.02, 0.6, Vector3(0, 0.3, 0), Color(0.2, 0.2, 0.2))
	for k in 6:
		var a := TAU * k / 6.0
		var arm := _box(Vector3(0.05, 0.05, 0.6), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), antler, false, Vector3(0, -a + PI / 2, 0.3), n)
		arm.rotation_order = EULER_ORDER_YXZ
		var bulb := _box(Vector3(0.08, 0.1, 0.08), Vector3(cos(a) * 0.6, 0.12, sin(a) * 0.6), Color(1, 0.9, 0.6), false, Vector3.ZERO, n)
		var m := bulb.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(1, 0.85, 0.5)
		m.emission_energy_multiplier = 2.0


## Stammgast, der am Tisch sitzt
class SittingNpc extends Npc:
	func _ready() -> void:
		super._ready()
		look_at_player = false

	func _process(delta: float) -> void:
		super._process(delta)
		model.animate(delta, 0.0, true, false, true)
		model.position.y = 0.0
