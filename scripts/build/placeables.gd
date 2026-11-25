class_name Placeables
extends RefCounted
## Baut Dinge, die Spieler aufstellen: Brennkessel, Hochstand, Wildkamera, Feuerstelle und Möbel.
## Jedes Objekt bekommt Meta "uid" (Eintrag in GameState.placed) und seine [F]-Aktionen.

const WOOD := Color(0.50, 0.33, 0.18)
const DARK_WOOD := Color(0.36, 0.23, 0.12)
const COPPER := Color(0.78, 0.45, 0.22)
const STONE := Color(0.52, 0.50, 0.48)

## Abstand zum nächsten Dorf, den ein Brennkessel mindestens haben muss
const STILL_MIN_DIST := 350.0


static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, collide := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = Toon.solid(c, true, 0.012)
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, r_top := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r if r_top < 0.0 else r_top
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = Toon.solid(c, true, 0.012)
	parent.add_child(mi)
	return mi


## Modell ohne Logik (auch für die Vorschau beim Aufstellen)
static func model(type: String) -> Node3D:
	var n := Node3D.new()
	match type:
		"still":
			cyl(n, 0.55, 0.9, Vector3(0, 0.75, 0), COPPER, 0.4)
			cyl(n, 0.2, 0.3, Vector3(0, 1.35, 0), COPPER, 0.08)
			box(n, Vector3(0.08, 0.08, 1.3), Vector3(0, 1.5, 0.6), COPPER, Vector3(0.4, 0, 0))
			cyl(n, 0.35, 0.9, Vector3(0, 0.45, 1.3), Color(0.40, 0.42, 0.45))  # Kühlfass
			cyl(n, 0.3, 0.7, Vector3(0.9, 0.35, 0.2), DARK_WOOD)  # Maischefass
			for k in 6:
				var a := TAU * k / 6.0
				box(n, Vector3(0.25, 0.2, 0.25), Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), STONE)
			box(n, Vector3(0.6, 0.15, 0.15), Vector3(0, 0.15, 0), DARK_WOOD, Vector3(0, 0.5, 0))
		"stand":
			for p in [Vector3(-0.9, 0, -0.9), Vector3(0.9, 0, -0.9), Vector3(-0.9, 0, 0.9), Vector3(0.9, 0, 0.9)]:
				box(n, Vector3(0.14, 4.0, 0.14), p * 0.9 + Vector3(0, 2.0, 0), WOOD, Vector3(-p.z * 0.06, 0, p.x * 0.06), true)
			box(n, Vector3(1.9, 0.1, 1.9), Vector3(0, 3.5, 0), WOOD, Vector3.ZERO, true)
			box(n, Vector3(1.9, 0.6, 0.08), Vector3(0, 3.85, 0.95), WOOD)
			for s in [-1, 1]:
				box(n, Vector3(0.08, 0.6, 1.9), Vector3(0.95 * s, 3.85, 0), WOOD)
			box(n, Vector3(2.1, 0.08, 2.1), Vector3(0, 4.9, 0), DARK_WOOD, Vector3(0.12, 0, 0))
			for s in [-1, 1]:
				box(n, Vector3(0.08, 1.4, 0.08), Vector3(0.9 * s, 4.2, -0.9), WOOD)
			# Leiter
			for s in [-0.25, 0.25]:
				box(n, Vector3(0.06, 3.7, 0.06), Vector3(s, 1.8, -1.35), WOOD, Vector3(-0.25, 0, 0))
			for k in 8:
				box(n, Vector3(0.55, 0.05, 0.05), Vector3(0, 0.3 + k * 0.42, -1.4 + k * 0.105), WOOD)
		"trailcam":
			box(n, Vector3(0.1, 1.2, 0.1), Vector3(0, 0.6, 0), DARK_WOOD)
			box(n, Vector3(0.2, 0.28, 0.14), Vector3(0, 1.1, 0.1), Color(0.25, 0.32, 0.2))
			cyl(n, 0.05, 0.04, Vector3(0, 1.12, 0.18), Color(0.05, 0.05, 0.05)).rotation.x = PI / 2
		"campfire":
			for k in 8:
				var a := TAU * k / 8.0
				box(n, Vector3(0.25, 0.18, 0.22), Vector3(cos(a) * 0.55, 0.09, sin(a) * 0.55), STONE, Vector3(0, a, 0))
			for k in 3:
				box(n, Vector3(0.12, 0.12, 0.8), Vector3(0, 0.12, 0), DARK_WOOD, Vector3(0, k * PI / 3, 0.15))
			for s in [-1, 1]:
				box(n, Vector3(0.06, 1.0, 0.06), Vector3(0.6 * s, 0.5, 0), DARK_WOOD)
			box(n, Vector3(1.3, 0.05, 0.05), Vector3(0, 0.95, 0), DARK_WOOD)
		"table":
			box(n, Vector3(1.4, 0.08, 0.8), Vector3(0, 0.75, 0), WOOD, Vector3.ZERO, true)
			for p in [Vector3(-0.6, 0, -0.32), Vector3(0.6, 0, -0.32), Vector3(-0.6, 0, 0.32), Vector3(0.6, 0, 0.32)]:
				box(n, Vector3(0.07, 0.72, 0.07), p + Vector3(0, 0.36, 0), DARK_WOOD)
		"chair":
			box(n, Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), WOOD)
			box(n, Vector3(0.45, 0.55, 0.06), Vector3(0, 0.75, -0.2), WOOD)
			for p in [Vector3(-0.19, 0, -0.19), Vector3(0.19, 0, -0.19), Vector3(-0.19, 0, 0.19), Vector3(0.19, 0, 0.19)]:
				box(n, Vector3(0.05, 0.45, 0.05), p + Vector3(0, 0.22, 0), DARK_WOOD)
		"bed":
			box(n, Vector3(1.0, 0.35, 2.0), Vector3(0, 0.2, 0), WOOD, Vector3.ZERO, true)
			box(n, Vector3(0.95, 0.15, 1.9), Vector3(0, 0.45, 0), Color(0.92, 0.92, 0.88))
			box(n, Vector3(0.95, 0.12, 1.2), Vector3(0, 0.55, 0.35), Color(0.65, 0.20, 0.18))
			box(n, Vector3(0.6, 0.12, 0.3), Vector3(0, 0.58, -0.75), Color(1, 1, 1))
			box(n, Vector3(1.0, 0.8, 0.08), Vector3(0, 0.5, -1.0), DARK_WOOD)
		"sofa":
			box(n, Vector3(2.0, 0.4, 0.9), Vector3(0, 0.25, 0), Color(0.35, 0.45, 0.30), Vector3.ZERO, true)
			box(n, Vector3(2.0, 0.6, 0.2), Vector3(0, 0.6, -0.38), Color(0.32, 0.42, 0.28))
			for s in [-1, 1]:
				box(n, Vector3(0.2, 0.55, 0.9), Vector3(0.95 * s, 0.45, 0), Color(0.32, 0.42, 0.28))
		"shelf":
			box(n, Vector3(1.0, 1.8, 0.35), Vector3(0, 0.9, 0), WOOD, Vector3.ZERO, true)
			for k in 4:
				box(n, Vector3(0.9, 0.04, 0.32), Vector3(0, 0.3 + k * 0.42, 0.02), DARK_WOOD)
			for k in 5:
				box(n, Vector3(0.08, 0.28, 0.2), Vector3(-0.35 + k * 0.12, 0.47, 0.05), Color.from_hsv(k * 0.2, 0.5, 0.7))
		"lamp":
			cyl(n, 0.18, 0.04, Vector3(0, 0.02, 0), DARK_WOOD)
			cyl(n, 0.025, 1.5, Vector3(0, 0.75, 0), Color(0.2, 0.2, 0.2))
			cyl(n, 0.25, 0.3, Vector3(0, 1.55, 0), Color(0.98, 0.9, 0.7), 0.15)
			var l := OmniLight3D.new()
			l.position = Vector3(0, 1.5, 0)
			l.omni_range = 7.0
			l.light_energy = 1.2
			l.light_color = Color(1.0, 0.85, 0.6)
			n.add_child(l)
		"rug":
			box(n, Vector3(2.0, 0.02, 1.4), Vector3(0, 0.01, 0), Color(0.62, 0.18, 0.15))
			box(n, Vector3(1.6, 0.025, 1.0), Vector3(0, 0.012, 0), Color(0.85, 0.72, 0.45))
		"stove":
			box(n, Vector3(1.2, 1.6, 0.8), Vector3(0, 0.8, 0), Color(0.30, 0.45, 0.35), Vector3.ZERO, true)
			box(n, Vector3(1.3, 0.12, 0.9), Vector3(0, 1.62, 0), Color(0.25, 0.38, 0.30))
			box(n, Vector3(0.4, 0.3, 0.05), Vector3(0, 0.5, 0.41), Color(0.1, 0.1, 0.1))
			box(n, Vector3(0.5, 0.25, 1.4), Vector3(0, 0.15, 0.95), Color(0.30, 0.45, 0.35))  # Ofenbank
		"frame":
			box(n, Vector3(0.6, 0.45, 0.04), Vector3(0, 0, 0), DARK_WOOD)
		"frame_big":
			box(n, Vector3(1.1, 0.8, 0.05), Vector3(0, 0, 0), Color(0.75, 0.6, 0.25))
		"chest":
			box(n, Vector3(1.0, 0.5, 0.55), Vector3(0, 0.25, 0), WOOD, Vector3.ZERO, true)
			box(n, Vector3(1.04, 0.14, 0.59), Vector3(0, 0.55, 0), DARK_WOOD)
			for x in [-0.42, 0.42]:
				box(n, Vector3(0.05, 0.66, 0.6), Vector3(x, 0.32, 0), Color(0.3, 0.3, 0.32))
			box(n, Vector3(0.12, 0.12, 0.03), Vector3(0, 0.45, 0.29), Color(0.85, 0.7, 0.25))
		"plant":
			cyl(n, 0.2, 0.35, Vector3(0, 0.17, 0), Color(0.7, 0.4, 0.25), 0.25)
			for k in 5:
				var a := TAU * k / 5.0
				var leaf := box(n, Vector3(0.08, 0.5, 0.2), Vector3(cos(a) * 0.12, 0.6, sin(a) * 0.12), Color(0.2, 0.55, 0.25), Vector3(0, -a, 0.4))
				leaf.rotation_order = EULER_ORDER_YXZ
		"trophy_boar":
			box(n, Vector3(0.55, 0.65, 0.05), Vector3(0, 0, 0), DARK_WOOD)
			var snout := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.2
			sm.height = 0.36
			snout.mesh = sm
			snout.position = Vector3(0, 0, 0.18)
			snout.scale = Vector3(1, 0.9, 1.5)
			snout.material_override = Toon.solid(Color(0.28, 0.22, 0.18))
			n.add_child(snout)
			for s in [-1, 1]:
				box(n, Vector3(0.03, 0.12, 0.03), Vector3(0.08 * s, -0.05, 0.42), Color(0.95, 0.93, 0.85), Vector3(0.6, 0, 0))
		"pelt_rug":
			for k in 10:
				var a := TAU * k / 10.0
				var r := 0.9 if k % 2 == 0 else 0.65
				box(n, Vector3(0.5, 0.02, 0.35), Vector3(cos(a) * r * 0.6, 0.01, sin(a) * r * 0.45), Color(0.48, 0.34, 0.22), Vector3(0, -a, 0))
			box(n, Vector3(1.3, 0.025, 0.9), Vector3(0, 0.012, 0), Color(0.52, 0.37, 0.24))
		"trophy":
			box(n, Vector3(0.5, 0.6, 0.05), Vector3(0, 0, 0), DARK_WOOD)
			var head := SphereMesh.new()
			head.radius = 0.15
			head.height = 0.3
			var hm := MeshInstance3D.new()
			hm.mesh = head
			hm.position = Vector3(0, 0, 0.15)
			hm.scale = Vector3(1, 1, 1.4)
			hm.material_override = Toon.solid(Color(0.55, 0.36, 0.20))
			n.add_child(hm)
			for s in [-1, 1]:
				for k in 3:
					box(n, Vector3(0.03, 0.3, 0.03), Vector3((0.12 + k * 0.06) * s, 0.2 + k * 0.08, 0.15), Color(0.85, 0.78, 0.62), Vector3(0, 0, -0.6 * s))
		"crate":
			box(n, Vector3(0.8, 0.5, 0.6), Vector3(0, 0.25, 0), Color(0.75, 0.55, 0.15))
			for k in 6:
				cyl(n, 0.04, 0.2, Vector3(-0.25 + (k % 3) * 0.25, 0.6, -0.12 + (k / 3) * 0.24), Color(0.3, 0.18, 0.08))
		"moonshine":
			box(n, Vector3(0.6, 0.35, 0.45), Vector3(0, 0.17, 0), Color(0.55, 0.40, 0.25))
			for k in 4:
				cyl(n, 0.06, 0.3, Vector3(-0.15 + (k % 2) * 0.3, 0.45, -0.1 + (k / 2) * 0.2), Color(0.85, 0.92, 0.95))
	return n


static func is_wall_item(type: String) -> bool:
	return type in ["frame", "frame_big", "trophy", "trophy_boar"]


## Darf hier aufgestellt werden? Gibt Fehlermeldung oder "" zurück.
static func check(type: String, pos: Vector3, game: Node) -> String:
	var p2 := Vector2(pos.x, pos.z)
	var w: WorldBuilder = game.world
	if not w.inside_border(p2):
		return "Außerhalb der Spielwelt"
	match type:
		"still":
			var lm: Landmarks = game.landmarks
			for c in [Vector2.ZERO, lm.home_center, lm.city_center, Vector2(lm.gas.pos.x, lm.gas.pos.z)]:
				if c.distance_to(p2) < STILL_MIN_DIST:
					return "Zu nah am Ort, die Polizei würde es merken (mind. %d m)" % STILL_MIN_DIST
		"table", "chair", "bed", "sofa", "shelf", "lamp", "rug", "stove", "frame", "frame_big", "trophy", "trophy_boar", "pelt_rug", "chest", "plant":
			if not game.inside_own_house(pos):
				return "Möbel nur im eigenen Haus"
	return ""
