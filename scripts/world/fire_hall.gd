class_name FireHall
extends Node3D
## Feuerwehrhaus Korpitsch: Treffpunkt der Spieler. Begehbare Halle mit offenem Tor, Schlauchturm,
## Bar (Kommandant Ferdl), Pokertisch (illegal, ab 20 Uhr), Roulette, Spielautomat, Biertischgarnitur
## vor dem Tor und dem alten Löschfahrzeug. Steht dort, wo das echte Gebäude in den Kartendaten ist.
## Lokale Achsen: +Z zeigt zum Tor (zur Straße).

const OSM_ID := 424764105
const SIZE := Vector2(11.0, 9.0)
const WALL_H := 4.2

var game: Node
var world: WorldBuilder
var door := Vector3.ZERO  # Weltposition vor dem Tor
var poker_seat := Vector3.ZERO
var base_y := 0.0
var _rng := RandomNumberGenerator.new()


## Lage aus den Kartendaten bestimmen (Gebäude-Umriss, Tor zur nächsten Straße)
static func find(w: WorldBuilder) -> Dictionary:
	for b in w.data.buildings:
		if int(b.id) != OSM_ID:
			continue
		var poly := WorldBuilder.to_v2_array(b.pts)
		var c := Vector2.ZERO
		for p in poly:
			c += p / poly.size()
		var road := w.road_info(c, 60.0)
		var to_road: Vector2 = (road.pos - c).normalized() if road.tier != 0 else Vector2(-1, 0)
		return {pos = c, yaw = atan2(to_road.x, to_road.y)}
	return {}


func setup(g: Node, w: WorldBuilder, info: Dictionary) -> void:
	game = g
	world = w
	_rng.seed = 112
	var c: Vector2 = info.pos
	rotation.y = info.yaw
	var hx := SIZE.x * 0.5
	var hz := SIZE.y * 0.5
	base_y = -INF
	for k in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz), Vector2.ZERO]:
		var wp := c + (k as Vector2).rotated(-float(info.yaw))
		base_y = maxf(base_y, w.height_at(wp.x, wp.y))
	global_position = Vector3(c.x, base_y, c.y)
	_build()
	door = global_transform * Vector3(0, 0, hz + 2.0)


func _box(size: Vector3, pos: Vector3, col: Color, collide := false, rot := Vector3.ZERO) -> MeshInstance3D:
	return Placeables.box(self, size, pos, col, rot, collide)


func _local(p: Vector3) -> Vector3:
	return global_transform * p


func _build() -> void:
	var hx := SIZE.x * 0.5
	var hz := SIZE.y * 0.5
	var wall := Color(0.93, 0.90, 0.82)
	var red := Color(0.78, 0.12, 0.10)
	var floor_c := Color(0.55, 0.55, 0.56)
	var t := 0.3
	# Sockel, Boden, Vorplatz
	_box(Vector3(SIZE.x + 0.4, 1.4, SIZE.y + 0.4), Vector3(0, -0.6, 0), Color(0.6, 0.6, 0.58), true)
	_box(Vector3(SIZE.x - 0.2, 0.05, SIZE.y - 0.2), Vector3(0, 0.13, 0), floor_c)
	_box(Vector3(SIZE.x + 4.0, 0.3, 6.0), Vector3(0, -0.05, hz + 3.0), Color(0.5, 0.5, 0.52), true)
	# Wände, vorne ein großes Tor (4 m breit, 3,4 m hoch)
	_box(Vector3(SIZE.x, WALL_H, t), Vector3(0, WALL_H * 0.5 + 0.1, -hz), wall, true)
	for s in [-1, 1]:
		_box(Vector3(t, WALL_H, SIZE.y), Vector3(hx * s, WALL_H * 0.5 + 0.1, 0), wall, true)
	var gate := 4.0
	var side := (SIZE.x - gate) * 0.5
	for s in [-1, 1]:
		_box(Vector3(side, WALL_H, t), Vector3((gate * 0.5 + side * 0.5) * s, WALL_H * 0.5 + 0.1, hz), wall, true)
	_box(Vector3(gate, WALL_H - 3.4, t), Vector3(0, 3.5 + (WALL_H - 3.4) * 0.5, hz), wall, true)
	_box(Vector3(gate + 0.2, 0.5, 0.4), Vector3(0, 3.3, hz - 0.1), red)  # hochgerolltes Tor
	# rote Streifen außen
	for s in [-1, 1]:
		_box(Vector3(0.05, 0.35, SIZE.y), Vector3((hx + 0.16) * s, 1.0, 0), red)
	_box(Vector3(SIZE.x, 0.35, 0.05), Vector3(0, 1.0, -hz - 0.16), red)
	# Satteldach
	var rh := 2.2
	var rl := sqrt(hx * hx + rh * rh) + 0.5
	var ang := atan2(rh, hx)
	for s in [-1, 1]:
		_box(Vector3(rl, 0.2, SIZE.y + 0.8), Vector3(hx * 0.5 * s, WALL_H + rh * 0.5 + 0.1, 0), Color(0.35, 0.18, 0.14), true, Vector3(0, 0, -ang * s))
	_box(Vector3(SIZE.x, 0.15, SIZE.y), Vector3(0, WALL_H + 0.1, 0), Color(0.8, 0.78, 0.72))  # Decke
	for k in 4:
		var f := (k + 0.5) / 4.0
		for zz in [-hz, hz]:
			_box(Vector3(SIZE.x * (1.0 - f), rh / 4.0, t), Vector3(0, WALL_H + rh * f - rh / 8.0 + 0.1, zz), wall)
	# Schlauchturm hinten links mit Sirene
	_box(Vector3(2.4, 10.0, 2.4), Vector3(-hx + 1.2, 5.0, -hz - 1.0), wall, true)
	_box(Vector3(2.8, 0.3, 2.8), Vector3(-hx + 1.2, 10.15, -hz - 1.0), Color(0.35, 0.18, 0.14))
	_box(Vector3(0.6, 0.5, 0.6), Vector3(-hx + 1.2, 10.55, -hz - 1.0), Color(0.3, 0.3, 0.32))
	for k in 3:
		_box(Vector3(0.7, 0.9, 0.05), Vector3(-hx + 1.2, 3.0 + k * 2.5, -hz - 2.22), Color(0.4, 0.55, 0.7))
	# Schild über dem Tor
	var sign := Label3D.new()
	sign.text = "FF KORPITSCH"
	sign.font_size = 110
	sign.pixel_size = 0.009
	sign.modulate = red
	sign.outline_size = 14
	sign.outline_modulate = Color(1, 1, 1)
	sign.position = Vector3(0, 4.2, hz + 0.2)
	add_child(sign)
	var emblem := _box(Vector3(0.9, 0.9, 0.05), Vector3(0, 5.3, hz + 0.18), red)
	emblem.rotation.z = PI / 4

	# Licht
	for x in [-2.5, 2.5]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, WALL_H - 0.4, 0)
		l.omni_range = 9.0
		l.light_energy = 1.3
		l.light_color = Color(1.0, 0.88, 0.7)
		add_child(l)
	# Lichterkette vor dem Tor
	for k in 9:
		var p := Vector3(-4.0 + k, 3.0 - absf(k - 4) * 0.08, hz + 2.6)
		var bulb := _box(Vector3(0.12, 0.12, 0.12), p, Color.from_hsv(k / 9.0, 0.6, 1.0))
		var m := bulb.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color.from_hsv(k / 9.0, 0.6, 1.0)
		m.emission_energy_multiplier = 2.0
	for s in [-1, 1]:
		_box(Vector3(0.1, 3.1, 0.1), Vector3(4.5 * s, 1.55, hz + 2.6), Placeables.DARK_WOOD)

	var I: Interactions = game.interactions
	# Bar hinten links
	var bar := Vector3(-hx + 2.4, 0.15, -hz + 1.3)
	_box(Vector3(3.4, 1.1, 0.7), bar + Vector3(0, 0.55, 0.3), Placeables.WOOD, true)
	_box(Vector3(3.6, 0.08, 0.9), bar + Vector3(0, 1.12, 0.3), Placeables.DARK_WOOD)
	_box(Vector3(3.2, 1.4, 0.3), bar + Vector3(0, 1.6, -0.75), Placeables.DARK_WOOD)
	for k in 8:
		Placeables.cyl(self, 0.05, 0.28, bar + Vector3(-1.3 + k * 0.37, 1.95, -0.65), Color.from_hsv(0.08 + k * 0.05, 0.6, 0.6))
	var kommandant := Npc.new("Kommandant Ferdl", {shirt = Color(0.12, 0.15, 0.25), pants = Color(0.12, 0.15, 0.25), hat = "none"})
	kommandant.important = true
	add_child(kommandant)
	kommandant.position = bar + Vector3(0, 0, -0.35)
	I.add(bar + Vector3(0, 1, 1.0), 2.6, "Bar: Kommandant Ferdl", func(): game.open_shop("fire"), null, self)
	# Pokertisch in der Mitte rechts
	var pk := Vector3(2.4, 0.15, -1.2)
	var felt := Placeables.cyl(self, 1.3, 0.1, pk + Vector3(0, 0.8, 0), Color(0.1, 0.4, 0.2))
	felt.scale = Vector3(1.4, 1, 1)
	Placeables.cyl(self, 1.38, 0.08, pk + Vector3(0, 0.76, 0), Placeables.DARK_WOOD).scale = Vector3(1.4, 1, 1)
	Placeables.cyl(self, 0.2, 0.75, pk + Vector3(0, 0.38, 0), Placeables.DARK_WOOD)
	for k in 5:
		var a := TAU * k / 5.0
		var ch := Placeables.model("chair")
		ch.position = pk + Vector3(cos(a) * 2.1, 0, sin(a) * 1.6)
		ch.rotation.y = -a - PI / 2
		add_child(ch)
	var lamp := OmniLight3D.new()
	lamp.position = pk + Vector3(0, 2.4, 0)
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.omni_range = 4.0
	lamp.light_energy = 1.5
	add_child(lamp)
	poker_seat = pk
	I.add(pk + Vector3(0, 1, 0), 3.0, func(): return "Poker spielen (illegal)" if game.casino.poker_open() else "Poker gibt's erst ab 20 Uhr", func(): game.casino.open_poker(), null, self)
	# Roulette vorne links
	var rt := Vector3(-2.6, 0.15, 1.8)
	_box(Vector3(2.6, 0.85, 1.3), rt + Vector3(0, 0.42, 0), Placeables.DARK_WOOD, true)
	_box(Vector3(2.5, 0.04, 1.2), rt + Vector3(0, 0.86, 0), Color(0.1, 0.45, 0.22))
	Placeables.cyl(self, 0.45, 0.12, rt + Vector3(-0.8, 0.94, 0), Color(0.35, 0.2, 0.1))
	Placeables.cyl(self, 0.3, 0.13, rt + Vector3(-0.8, 0.95, 0), Color(0.7, 0.1, 0.1))
	I.add(rt + Vector3(0, 1, 0), 2.6, "Roulette", func(): game.casino.open_roulette(), null, self)
	# Spielautomat an der rechten Wand
	var sm := Vector3(hx - 0.6, 0.15, 2.4)
	_slot_machine(sm, -PI / 2)
	I.add(sm + Vector3(-0.6, 1, 0), 2.0, "Spielautomat", func(): game.casino.open_slots(), null, self)
	# Darts und Plakat
	var dart := Placeables.cyl(self, 0.25, 0.04, Vector3(hx - 0.2, 1.7, -1.5), Color(0.15, 0.15, 0.15))
	dart.rotation = Vector3(0, 0, PI / 2)
	_box(Vector3(0.03, 1.0, 0.7), Vector3(-hx + 0.18, 1.8, 0.5), Color(0.95, 0.85, 0.3))
	var poster := Label3D.new()
	poster.text = "FEUERWEHR-\nFEST\nSa 20 Uhr"
	poster.font_size = 40
	poster.pixel_size = 0.005
	poster.modulate = Color(0.6, 0.1, 0.05)
	poster.position = Vector3(-hx + 0.21, 1.8, 0.5)
	poster.rotation.y = PI / 2
	add_child(poster)
	# Biertischgarnitur vor dem Tor
	var bt := Vector3(3.5, 0.0, hz + 3.6)
	_box(Vector3(2.2, 0.06, 0.7), bt + Vector3(0, 0.75, 0), Placeables.WOOD)
	for s in [-1, 1]:
		_box(Vector3(0.06, 0.72, 0.6), bt + Vector3(0.9 * s, 0.36, 0), Placeables.DARK_WOOD)
		_box(Vector3(2.2, 0.05, 0.3), bt + Vector3(0, 0.45, 0.65 * s), Placeables.WOOD)
	for k in 3:
		Placeables.cyl(self, 0.04, 0.2, bt + Vector3(-0.6 + k * 0.6, 0.88, 0.1 * (k - 1)), Color(0.45, 0.28, 0.08))
	for s in [-1, 1]:
		var seat_pos := bt + Vector3(0, 0, 0.65 * s)
		I.add(seat_pos + Vector3(0, 0.5, 0), 1.3, "Hinsetzen", func(): game.sit_down(_local(seat_pos), global_rotation.y + (PI if s > 0 else 0.0)), null, self)
	# Altes Löschfahrzeug
	_fire_truck(Vector3(-4.8, 0.0, hz + 3.4))


func _slot_machine(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	Placeables.box(n, Vector3(0.8, 1.7, 0.6), Vector3(0, 0.85, 0), Color(0.75, 0.1, 0.15), Vector3.ZERO, true)
	Placeables.box(n, Vector3(0.6, 0.35, 0.05), Vector3(0, 1.25, 0.31), Color(0.95, 0.95, 0.9))
	for k in 3:
		Placeables.box(n, Vector3(0.15, 0.25, 0.06), Vector3(-0.18 + k * 0.18, 1.25, 0.32), Color.from_hsv(k * 0.3, 0.7, 0.9))
	Placeables.box(n, Vector3(0.7, 0.2, 0.05), Vector3(0, 1.6, 0.31), Color(1.0, 0.85, 0.2))
	Placeables.cyl(n, 0.03, 0.4, Vector3(0.48, 1.2, 0), Color(0.7, 0.7, 0.7))
	var knob := Placeables.cyl(n, 0.07, 0.1, Vector3(0.48, 1.45, 0), Color(0.9, 0.1, 0.1))
	knob.scale = Vector3(1, 1, 1)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.4, 0.6)
	l.omni_range = 2.5
	l.light_color = Color(1.0, 0.6, 0.8)
	l.light_energy = 0.8
	n.add_child(l)


func _fire_truck(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var red := Color(0.8, 0.1, 0.08)
	_tb(n, Vector3(2.3, 1.6, 6.5), Vector3(0, 1.4, 0), red, true)
	_tb(n, Vector3(2.32, 1.0, 1.8), Vector3(0, 2.4, 2.3), red)
	_tb(n, Vector3(2.34, 0.6, 1.5), Vector3(0, 2.5, 2.4), Color(0.5, 0.65, 0.75))
	_tb(n, Vector3(2.0, 0.25, 4.0), Vector3(0, 2.35, -1.0), Color(0.75, 0.75, 0.78))  # Leiter
	for k in 8:
		_tb(n, Vector3(2.0, 0.06, 0.06), Vector3(0, 2.5, -2.8 + k * 0.5), Color(0.6, 0.6, 0.62))
	_tb(n, Vector3(2.34, 0.15, 6.52), Vector3(0, 1.0, 0), Color(0.95, 0.95, 0.95))
	for x in [-0.6, 0.6]:
		_tb(n, Vector3(0.3, 0.15, 0.3), Vector3(x, 3.0, 2.6), Color(0.2, 0.4, 1.0))
	for wp in [Vector3(1.05, 0.55, 2.0), Vector3(-1.05, 0.55, 2.0), Vector3(1.05, 0.55, -2.0), Vector3(-1.05, 0.55, -2.0)]:
		var tire := Placeables.cyl(n, 0.55, 0.4, wp, Color(0.1, 0.1, 0.1))
		tire.rotation.z = PI / 2
	var lbl := Label3D.new()
	lbl.text = "FF KORPITSCH"
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.modulate = Color(1, 1, 1)
	lbl.position = Vector3(1.17, 1.4, 0)
	lbl.rotation.y = PI / 2
	n.add_child(lbl)


func _tb(n: Node3D, size: Vector3, pos: Vector3, col: Color, collide := false) -> MeshInstance3D:
	return Placeables.box(n, size, pos, col, Vector3.ZERO, collide)


## Ist jemand in der Halle? (für Razzien)
func inside(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) < SIZE.x * 0.5 + 1.0 and absf(l.z) < SIZE.y * 0.5 + 4.0
