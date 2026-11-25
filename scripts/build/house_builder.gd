class_name HouseBuilder
extends RefCounted
## Baut ein Spielerhaus auf einem Bauplatz: begehbar (Tür zur Straße), Fenster, Dach, Holzdielen,
## Wandvertäfelung, Deckenbalken, Küchenecke, Kachelofen, Werkbank, eingebaute Truhe und Bett.
## Zweistöckige Häuser haben ein Obergeschoss mit Treppe (oben stehen Bett und Truhe).
## Weitere Möbel stellt der Spieler frei auf. Lokale Achsen: +Z zeigt zur Straße (dort ist die Tür).

const WALL_H := 2.9
const STAIR_W := 1.1
const STAIR_FRONT := 1.9  # Treppe beginnt hier (z) und steigt nach hinten


static func build(parent: Node3D, plot: Dictionary, type_idx: int, owner_name: String, world: WorldBuilder) -> Node3D:
	var h: Dictionary = Items.HOUSES[type_idx]
	var size: Vector2 = h.size
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var levels := int(h.levels)
	var total_h := WALL_H * levels
	var t := 0.25  # Wandstärke
	var root := Node3D.new()
	root.name = "Haus_%d" % plot.idx
	parent.add_child(root)
	var p: Vector3 = plot.pos
	# höchster Punkt unter dem Haus, damit nichts im Hang versinkt
	var base := -INF
	for c in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz), Vector2.ZERO]:
		var w: Vector2 = Vector2(p.x, p.z) + (c as Vector2).rotated(-float(plot.yaw))
		base = maxf(base, world.height_at(w.x, w.y))
	root.global_position = Vector3(p.x, base, p.z)
	root.rotation.y = plot.yaw
	var wall_c: Color = h.wall
	var roof_c: Color = h.roof
	var floor_c := Color(0.62, 0.45, 0.28)
	# Sockel und Boden mit Dielen
	_b(root, Vector3(size.x + 0.4, 1.2, size.y + 0.4), Vector3(0, -0.45, 0), Color(0.6, 0.6, 0.58), true)
	_b(root, Vector3(size.x - 0.2, 0.05, size.y - 0.2), Vector3(0, 0.18, 0), floor_c)
	var plank := -hx + 0.5
	while plank < hx - 0.2:
		_b(root, Vector3(0.03, 0.01, size.y - 0.3), Vector3(plank, 0.21, 0), floor_c.darkened(0.25))
		plank += 0.5
	# Außenwände
	_b(root, Vector3(size.x, total_h, t), Vector3(0, total_h * 0.5 + 0.15, -hz), wall_c, true)
	for s in [-1, 1]:
		_b(root, Vector3(t, total_h, size.y), Vector3(hx * s, total_h * 0.5 + 0.15, 0), wall_c, true)
	var door_w := 1.4
	var side_w := (size.x - door_w) * 0.5
	for s in [-1, 1]:
		_b(root, Vector3(side_w, total_h, t), Vector3((door_w * 0.5 + side_w * 0.5) * s, total_h * 0.5 + 0.15, hz), wall_c, true)
	_b(root, Vector3(door_w, total_h - 2.3, t), Vector3(0, 2.3 + (total_h - 2.3) * 0.5 + 0.15, hz), wall_c, true)
	# Holzvertäfelung innen (unterer Meter jedes Stockwerks)
	var panel := Color(0.50, 0.33, 0.19)
	for lvl in levels:
		var py := 0.7 + lvl * WALL_H
		_b(root, Vector3(size.x - 0.5, 1.0, 0.03), Vector3(0, py, -hz + 0.14), panel)
		for s in [-1, 1]:
			_b(root, Vector3(0.03, 1.0, size.y - 0.5), Vector3((hx - 0.14) * s, py, 0), panel)
			_b(root, Vector3(side_w - 0.3, 1.0, 0.03), Vector3((door_w * 0.5 + side_w * 0.5) * s, py, hz - 0.14), panel)
	# Decken, Obergeschoss mit Treppenloch, Dach
	var ceil_c := Color(0.85, 0.82, 0.76)
	if levels >= 2:
		var hole_x := -hx + STAIR_W + 0.15  # rechte Kante des Treppenlochs
		var top_z := STAIR_FRONT - 3.7  # hinteres Ende der Treppe
		_b(root, Vector3(hx - hole_x, 0.15, size.y), Vector3((hole_x + hx) * 0.5, WALL_H + 0.15, 0), floor_c, true)
		_b(root, Vector3(hole_x + hx, 0.15, hz - STAIR_FRONT), Vector3((-hx + hole_x) * 0.5, WALL_H + 0.15, (STAIR_FRONT + hz) * 0.5), floor_c, true)
		_b(root, Vector3(hole_x + hx, 0.15, top_z + hz), Vector3((-hx + hole_x) * 0.5, WALL_H + 0.15, (top_z - hz) * 0.5), floor_c, true)
		_stairs(root, -hx + 0.15 + STAIR_W * 0.5, STAIR_FRONT, top_z)
		# Geländer am Treppenloch
		_b(root, Vector3(0.06, 0.9, STAIR_FRONT - top_z), Vector3(hole_x, WALL_H + 0.65, (STAIR_FRONT + top_z) * 0.5), Placeables.DARK_WOOD)
		_b(root, Vector3(size.x, 0.12, size.y), Vector3(0, total_h + 0.15, 0), ceil_c, true)
	else:
		_b(root, Vector3(size.x, 0.12, size.y), Vector3(0, WALL_H + 0.15, 0), ceil_c, true)
	for k in 4:
		_b(root, Vector3(size.x - 0.4, 0.16, 0.16), Vector3(0, total_h + 0.02, -hz + (k + 0.5) * size.y / 4.0), Placeables.DARK_WOOD)
	var roof_h := minf(size.x, size.y) * 0.32
	var top := total_h + 0.15
	var rl := sqrt(hz * hz + roof_h * roof_h) + 0.5
	var ang := atan2(roof_h, hz)
	for s in [-1, 1]:
		_b(root, Vector3(size.x + 0.8, 0.18, rl), Vector3(0, top + roof_h * 0.5, hz * 0.5 * s), roof_c, false, Vector3(ang * s, 0, 0))
	for k in 4:
		var f := (k + 0.5) / 4.0
		var gw := size.y * (1.0 - f)
		for s in [-1, 1]:
			_b(root, Vector3(t, roof_h / 4.0, gw), Vector3(hx * s, top + roof_h * f - roof_h / 8.0, 0), wall_c)
	# Fenster mit Fensterbrett
	var glass := Color(0.55, 0.72, 0.85)
	for lvl in levels:
		var y := 1.0 + lvl * WALL_H + 0.6
		for s in [-1, 1]:
			_b(root, Vector3(1.0, 1.0, 0.05), Vector3((door_w * 0.5 + side_w * 0.5) * s, y, hz + 0.14), glass)
			_b(root, Vector3(1.0, 1.0, 0.05), Vector3(hx * 0.5 * s, y, -hz - 0.14), glass)
			_b(root, Vector3(0.05, 1.0, 1.0), Vector3((hx + 0.14) * s, y, 0), glass)
			_b(root, Vector3(1.1, 0.05, 0.2), Vector3(hx * 0.5 * s, y - 0.55, -hz + 0.2), Placeables.WOOD)
	# Tür (offen) und Namensschild
	_b(root, Vector3(0.08, 2.2, 1.3), Vector3(door_w * 0.5 + 0.05, 1.25, hz + 0.6), Placeables.DARK_WOOD)
	var sign := Label3D.new()
	sign.text = owner_name
	sign.font_size = 48
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 2.55, hz + 0.16)
	sign.modulate = Color(1, 1, 1)
	sign.outline_size = 8
	root.add_child(sign)
	# Licht pro Stockwerk
	for lvl in levels:
		var light := OmniLight3D.new()
		light.position = Vector3(0, WALL_H - 0.3 + lvl * WALL_H, 0)
		light.omni_range = maxf(size.x, size.y)
		light.light_energy = 0.9
		light.light_color = Color(1.0, 0.88, 0.7)
		root.add_child(light)
	# Küchenecke vorne rechts: Arbeitsplatte, Herd, Kühlschrank
	var kx := hx - 0.55
	_b(root, Vector3(0.7, 0.9, 1.6), Vector3(kx, 0.63, hz - 1.3), Color(0.92, 0.9, 0.86), true)
	_b(root, Vector3(0.74, 0.05, 1.64), Vector3(kx, 1.1, hz - 1.3), Color(0.35, 0.3, 0.28))
	for k in 2:
		Placeables.cyl(root, 0.12, 0.02, Vector3(kx, 1.13, hz - 1.0 - k * 0.4), Color(0.1, 0.1, 0.1))
	_b(root, Vector3(0.7, 1.8, 0.7), Vector3(kx, 1.08, hz - 2.6), Color(0.95, 0.95, 0.96), true)
	_b(root, Vector3(0.03, 0.4, 0.05), Vector3(kx - 0.36, 1.3, hz - 2.35), Color(0.6, 0.6, 0.62))
	# Kachelofen hinten in der Mitte, Garderobe neben der Tür
	var stove := Placeables.model("stove")
	stove.position = Vector3(0.4, 0.18, -hz + 0.6)
	root.add_child(stove)
	Placeables.cyl(root, 0.03, 1.7, Vector3(-door_w * 0.5 - 0.6, 1.0, hz - 0.35), Placeables.DARK_WOOD)
	for k in 3:
		Placeables.box(root, Vector3(0.25, 0.03, 0.03), Vector3(-door_w * 0.5 - 0.6, 1.75, hz - 0.35), Placeables.DARK_WOOD, Vector3(0, k * PI / 3, 0))
	# Werkbank hinten links (unter der Treppe bzw. in der Ecke)
	var bench := Placeables.model("table")
	bench.position = Vector3(-hx + 1.0, 0.18, -hz + 0.8)
	root.add_child(bench)
	Placeables.box(bench, Vector3(1.2, 0.3, 0.3), Vector3(0, 1.0, -0.25), Color(0.4, 0.4, 0.42))
	# Bett und eingebaute Truhe: oben, falls es ein Obergeschoss gibt
	var up_y := 0.18 + (WALL_H + 0.05 if levels >= 2 else 0.0)
	var bed := Placeables.model("bed")
	bed.position = Vector3(hx - 0.9, up_y, -hz + 1.3)
	root.add_child(bed)
	var chest := Placeables.model("chest")
	chest.position = Vector3(hx - 0.9, up_y, -hz + 2.8)
	chest.rotation.y = -PI / 2
	root.add_child(chest)
	root.set_meta("bench", bench)
	root.set_meta("bed", bed)
	root.set_meta("chest", chest)
	root.set_meta("half", Vector2(hx, hz))
	root.set_meta("levels", levels)
	return root


static func _b(root: Node3D, sz: Vector3, pos: Vector3, col: Color, collide := false, rot := Vector3.ZERO) -> MeshInstance3D:
	return Placeables.box(root, sz, pos, col, rot, collide)


## Treppe nach hinten: sichtbare Stufen, begehbar über eine unsichtbare Rampe
static func _stairs(root: Node3D, x: float, front_z: float, back_z: float) -> void:
	var steps := 13
	var run := (front_z - back_z) / steps
	var rise := WALL_H / steps
	for k in steps:
		Placeables.box(root, Vector3(STAIR_W, rise, run + 0.02), Vector3(x, 0.18 + rise * (k + 0.5), front_z - run * (k + 0.5)), Placeables.WOOD)
	var len := sqrt(pow(front_z - back_z, 2) + WALL_H * WALL_H)
	var ramp := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(STAIR_W, 0.1, len)
	cs.shape = bs
	ramp.add_child(cs)
	ramp.position = Vector3(x, 0.18 + WALL_H * 0.5, (front_z + back_z) * 0.5)
	ramp.rotation.x = atan2(WALL_H, front_z - back_z)
	root.add_child(ramp)
