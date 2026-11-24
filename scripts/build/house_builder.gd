class_name HouseBuilder
extends RefCounted
## Baut ein Spielerhaus auf einem Bauplatz: begehbar (Tür zur Straße), Fenster, Dach,
## Holzboden, Licht, Werkbank und Bett. Möbel stellt der Spieler selbst auf.
## Lokale Achsen: +Z zeigt zur Straße (dort ist die Tür).

static func build(parent: Node3D, plot: Dictionary, type_idx: int, owner_name: String, world: WorldBuilder) -> Node3D:
	var h: Dictionary = Items.HOUSES[type_idx]
	var size: Vector2 = h.size
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var wall_h := 2.9
	var total_h := wall_h * int(h.levels)
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
	# Sockel und Boden
	Placeables.box(root, Vector3(size.x + 0.4, 1.2, size.y + 0.4), Vector3(0, -0.45, 0), Color(0.6, 0.6, 0.58), Vector3.ZERO, true)
	Placeables.box(root, Vector3(size.x - 0.2, 0.05, size.y - 0.2), Vector3(0, 0.18, 0), floor_c)
	# Rückwand und Seiten
	Placeables.box(root, Vector3(size.x, total_h, t), Vector3(0, total_h * 0.5 + 0.15, -hz), wall_c, Vector3.ZERO, true)
	for s in [-1, 1]:
		Placeables.box(root, Vector3(t, total_h, size.y), Vector3(hx * s, total_h * 0.5 + 0.15, 0), wall_c, Vector3.ZERO, true)
	# Vorderwand mit Türöffnung (1,4 m breit)
	var door_w := 1.4
	var side_w := (size.x - door_w) * 0.5
	for s in [-1, 1]:
		Placeables.box(root, Vector3(side_w, total_h, t), Vector3((door_w * 0.5 + side_w * 0.5) * s, total_h * 0.5 + 0.15, hz), wall_c, Vector3.ZERO, true)
	Placeables.box(root, Vector3(door_w, total_h - 2.3, t), Vector3(0, 2.3 + (total_h - 2.3) * 0.5 + 0.15, hz), wall_c, Vector3.ZERO, true)
	# Decke (innen) und Dach
	Placeables.box(root, Vector3(size.x, 0.12, size.y), Vector3(0, wall_h + 0.15, 0), Color(0.85, 0.82, 0.76), Vector3.ZERO, true)
	var roof_h := minf(size.x, size.y) * 0.32
	var top := total_h + 0.15
	var rl := sqrt(hz * hz + roof_h * roof_h) + 0.5
	var ang := atan2(roof_h, hz)
	for s in [-1, 1]:
		Placeables.box(root, Vector3(size.x + 0.8, 0.18, rl), Vector3(0, top + roof_h * 0.5, hz * 0.5 * s), roof_c, Vector3(ang * s, 0, 0))
	# Giebelwände (als Stufen angedeutet)
	for k in 4:
		var f := (k + 0.5) / 4.0
		var w := size.y * (1.0 - f)
		for s in [-1, 1]:
			Placeables.box(root, Vector3(t, roof_h / 4.0, w), Vector3(hx * s, top + roof_h * f - roof_h / 8.0, 0), wall_c)
	# Fenster
	var glass := Color(0.55, 0.72, 0.85)
	for lvl in int(h.levels):
		var y := 1.0 + lvl * wall_h + 0.6
		for s in [-1, 1]:
			Placeables.box(root, Vector3(1.0, 1.0, 0.05), Vector3((door_w * 0.5 + side_w * 0.5) * s, y, hz + 0.14), glass)
			Placeables.box(root, Vector3(1.0, 1.0, 0.05), Vector3(hx * 0.5 * s, y, -hz - 0.14), glass)
			Placeables.box(root, Vector3(0.05, 1.0, 1.0), Vector3((hx + 0.14) * s, y, 0), glass)
	# Tür (offen) und Namensschild
	Placeables.box(root, Vector3(0.08, 2.2, 1.3), Vector3(door_w * 0.5 + 0.05, 1.25, hz + 0.6), Placeables.DARK_WOOD, Vector3(0, 0, 0))
	var sign := Label3D.new()
	sign.text = owner_name
	sign.font_size = 48
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 2.55, hz + 0.16)
	sign.modulate = Color(1, 1, 1)
	sign.outline_size = 8
	root.add_child(sign)
	# Licht innen
	var light := OmniLight3D.new()
	light.position = Vector3(0, wall_h - 0.2, 0)
	light.omni_range = maxf(size.x, size.y)
	light.light_energy = 0.9
	light.light_color = Color(1.0, 0.88, 0.7)
	root.add_child(light)
	# Werkbank und Bett
	var bench := Placeables.model("table")
	bench.position = Vector3(-hx + 1.0, 0.18, -hz + 0.8)
	root.add_child(bench)
	Placeables.box(bench, Vector3(1.2, 0.3, 0.3), Vector3(0, 1.0, -0.25), Color(0.4, 0.4, 0.42))
	var bed := Placeables.model("bed")
	bed.position = Vector3(hx - 0.9, 0.18, -hz + 1.3)
	root.add_child(bed)
	root.set_meta("bench", bench)
	root.set_meta("bed", bed)
	root.set_meta("half", Vector2(hx, hz))
	return root
