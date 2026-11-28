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
static var _still_mats := {}


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


static func _std_mat(c: Color, metallic := 0.0, roughness := 0.75, alpha := 1.0, emit := Color.BLACK, emit_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_energy
	return m


static func _poly_cyl(parent: Node3D, r_bot: float, r_top: float, h: float, segs: int, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r_bot
	m.top_radius = r_top
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _poly_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _tube_seg(parent: Node3D, a: Vector3, b: Vector3, r: float, segs: int, mat: Material) -> void:
	var diff := b - a
	var length := diff.length()
	if length < 0.002:
		return
	var mi := _poly_cyl(parent, r, r, length, segs, (a + b) * 0.5, mat)
	var up := diff / length
	var ref := Vector3.RIGHT if absf(up.y) > 0.98 else Vector3.UP
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	mi.basis = Basis(x, up, z)


static func _try_load_glb(type: String) -> Node3D:
	var model_map := {
		moonshine_keg = "moonshine_keg",
		empty_keg = "moonshine_keg",
		moonshine = "moonshine",
		empty_bottle = "moonshine",
	}
	var glb_name: String = str(model_map.get(type, type))
	var glb_path := "res://assets/models/%s.glb" % glb_name
	if not ResourceLoader.exists(glb_path):
		return null
	var target_heights := {
		still = 1.6, still_pot = 1.4, bottling_table = 1.0, stand = 4.9, trailcam = 1.2, campfire = 1.0,
		moonshine_keg = 0.48, empty_keg = 0.48, moonshine = 0.30, empty_bottle = 0.30,
	}
	var target_h: float = float(target_heights.get(type, 1.2))
	var root := Node3D.new()
	var model_node := AssetLoader.load_model(glb_path, target_h, func() -> Node3D: return Node3D.new(), false)
	if model_node == null or model_node.get_child_count() == 0:
		root.free()
		return null
	root.add_child(model_node)
	# Unterkante exakt auf y = 0 ausrichten
	var min_y := INF
	for mi in model_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst and mesh_inst.mesh:
			var aabb := mesh_inst.mesh.get_aabb()
			var xf := model_node.transform * mesh_inst.transform
			min_y = minf(min_y, (xf * aabb.position).y)
	if is_finite(min_y):
		model_node.position.y -= min_y
	if type in ["moonshine_keg", "empty_keg"]:
		root.add_to_group("carryable_keg")
		root.set_meta("kind", type)
		var sb := StaticBody3D.new()
		sb.collision_layer = 16
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cyl_s := CylinderShape3D.new()
		cyl_s.radius = 0.24
		cyl_s.height = 0.48
		cs.shape = cyl_s
		cs.position = Vector3(0.0, 0.24, 0.0)
		sb.add_child(cs)
		root.add_child(sb)
	return root


static func _build_still(n: Node3D) -> void:
	if _still_mats.is_empty():
		_still_mats = {
			copper = _std_mat(Color(0.80, 0.44, 0.21), 0.85, 0.30),
			iron = _std_mat(Color(0.16, 0.16, 0.18), 0.70, 0.75),
			wood = _std_mat(Color(0.48, 0.31, 0.17), 0.0, 0.82),
			dark_wood = _std_mat(Color(0.28, 0.18, 0.10), 0.0, 0.88),
			water = _std_mat(Color(0.45, 0.72, 0.85, 0.72), 0.05, 0.15, 0.72),
			glass = _std_mat(Color(0.84, 0.93, 0.96, 0.42), 0.05, 0.10, 0.42),
			lid_grey = _std_mat(Color(0.55, 0.57, 0.60), 0.55, 0.45),
			ember_mat = _std_mat(Color(1.0, 0.38, 0.06), 0.0, 0.9, 1.0, Color(1.0, 0.38, 0.06), 2.8),
			flame_mat = _std_mat(Color(1.0, 0.72, 0.14, 0.85), 0.0, 0.9, 0.85, Color(1.0, 0.58, 0.10), 3.4),
		}
	var copper: StandardMaterial3D = _still_mats.copper
	var iron: StandardMaterial3D = _still_mats.iron
	var wood: StandardMaterial3D = _still_mats.wood
	var dark_wood: StandardMaterial3D = _still_mats.dark_wood
	var water: StandardMaterial3D = _still_mats.water
	var glass: StandardMaterial3D = _still_mats.glass
	var lid_grey: StandardMaterial3D = _still_mats.lid_grey
	var ember_mat: StandardMaterial3D = _still_mats.ember_mat
	var flame_mat: StandardMaterial3D = _still_mats.flame_mat

	# Teil 1: Kupferkessel & Feuerstelle (links)
	var pot_grp := Node3D.new()
	pot_grp.name = "StillPot"
	n.add_child(pot_grp)
	var px := -0.45
	# Vierbein-Metallständer
	_poly_cyl(pot_grp, 0.35, 0.35, 0.04, 10, Vector3(px, 0.38, 0.0), iron)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var top_p := Vector3(px + cos(a) * 0.32, 0.38, sin(a) * 0.32)
		var bot_p := Vector3(px + cos(a) * 0.41, 0.0, sin(a) * 0.41)
		_tube_seg(pot_grp, bot_p, top_p, 0.024, 6, iron)
	# Feuerschale mit Griff und Holz/Kohle
	_poly_cyl(pot_grp, 0.24, 0.30, 0.08, 10, Vector3(px, 0.05, 0.0), iron)
	_poly_box(pot_grp, Vector3(0.14, 0.025, 0.035), Vector3(px - 0.35, 0.08, 0.0), iron)
	for k in 4:
		var a := k * PI * 0.42
		_poly_box(pot_grp, Vector3(0.06, 0.05, 0.22), Vector3(px + cos(a) * 0.06, 0.10, sin(a) * 0.06), dark_wood, Vector3(0.1, a, 0.05))
	# Aktives Feuer & Glut-Licht (nur sichtbar wenn Brand läuft)
	var fire_grp := Node3D.new()
	fire_grp.name = "StillFire"
	fire_grp.visible = false
	pot_grp.add_child(fire_grp)
	_poly_cyl(fire_grp, 0.18, 0.14, 0.03, 8, Vector3(px, 0.11, 0.0), ember_mat)
	for k in 3:
		var fa := k * TAU / 3.0
		_poly_cyl(fire_grp, 0.07, 0.01, 0.18, 5, Vector3(px + cos(fa) * 0.06, 0.20, sin(fa) * 0.06), flame_mat)
	var fire_light := OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.position = Vector3(px, 0.24, 0.0)
	fire_light.light_color = Color(1.0, 0.52, 0.16)
	fire_light.omni_range = 4.5
	fire_light.light_energy = 1.6
	fire_grp.add_child(fire_light)
	# Bauchiger facettierter Kupferkessel (10 Segmente) + Griffe + Halsring + Zwiebelhelm
	_poly_cyl(pot_grp, 0.28, 0.36, 0.26, 10, Vector3(px, 0.53, 0.0), copper)
	_poly_cyl(pot_grp, 0.36, 0.24, 0.26, 10, Vector3(px, 0.79, 0.0), copper)
	for s in [-1.0, 1.0]:
		_poly_box(pot_grp, Vector3(0.08, 0.03, 0.09), Vector3(px + s * 0.37, 0.68, 0.0), copper)
	_poly_cyl(pot_grp, 0.25, 0.25, 0.05, 10, Vector3(px, 0.94, 0.0), iron)
	_poly_cyl(pot_grp, 0.20, 0.27, 0.16, 10, Vector3(px, 1.04, 0.0), copper)
	_poly_cyl(pot_grp, 0.27, 0.08, 0.22, 10, Vector3(px, 1.23, 0.0), copper)
	# Deko am Boden: kleine Holzkiste + 2 Einmachgläser
	_poly_box(pot_grp, Vector3(0.28, 0.18, 0.22), Vector3(-0.78, 0.09, 0.32), wood)
	for j in 2:
		var jx := -0.83 + j * 0.10
		_poly_cyl(pot_grp, 0.036, 0.036, 0.10, 8, Vector3(jx, 0.23, 0.32), glass)
		_poly_cyl(pot_grp, 0.038, 0.038, 0.02, 8, Vector3(jx, 0.29, 0.32), lid_grey)

	# Teil 2: Kupferrohr, Spirale & Kühlfass auf Palette (rechts)
	var cond_grp := Node3D.new()
	cond_grp.name = "StillCondenser"
	n.add_child(cond_grp)
	var cx := 0.48
	# Holzpalette mit erhöhtem Rand
	_poly_box(cond_grp, Vector3(0.84, 0.06, 0.84), Vector3(cx, 0.03, 0.0), dark_wood)
	for s in [-0.39, 0.39]:
		_poly_box(cond_grp, Vector3(0.84, 0.04, 0.06), Vector3(cx, 0.08, s), wood)
		_poly_box(cond_grp, Vector3(0.06, 0.04, 0.84), Vector3(cx + s, 0.08, 0.0), wood)
	# Rustikales Holzfass (12 Dauben-Segmente) + 2 Metallreifen + Wasser innen
	_poly_cyl(cond_grp, 0.33, 0.36, 0.42, 12, Vector3(cx, 0.29, 0.0), wood)
	_poly_cyl(cond_grp, 0.36, 0.33, 0.42, 12, Vector3(cx, 0.71, 0.0), wood)
	_poly_cyl(cond_grp, 0.355, 0.355, 0.04, 12, Vector3(cx, 0.26, 0.0), iron)
	_poly_cyl(cond_grp, 0.365, 0.365, 0.04, 12, Vector3(cx, 0.74, 0.0), iron)
	_poly_cyl(cond_grp, 0.30, 0.30, 0.03, 12, Vector3(cx, 0.87, 0.0), water)
	# Geschwungenes Kupferrohr mit 2 Ringflanschen
	var pipe_pts := [
		Vector3(px, 1.33, 0.0), Vector3(px + 0.04, 1.50, 0.0), Vector3(px + 0.24, 1.60, 0.0),
		Vector3(0.02, 1.59, 0.0), Vector3(cx - 0.16, 1.50, 0.0), Vector3(cx, 1.34, 0.0),
	]
	for i in pipe_pts.size() - 1:
		_tube_seg(cond_grp, pipe_pts[i], pipe_pts[i + 1], 0.03, 8, copper)
	_poly_cyl(cond_grp, 0.055, 0.055, 0.03, 8, pipe_pts[1], iron, Vector3(0, 0, -0.35))
	_poly_cyl(cond_grp, 0.055, 0.055, 0.03, 8, pipe_pts[4], iron, Vector3(0, 0, 0.45))
	# Vertikale Kupferspirale (4.5 Windungen) taucht ins Kühlfass ein
	var coil_steps := 18
	var prev_cp := Vector3(cx, 1.34, 0.0)
	for i in range(1, coil_steps + 1):
		var u := float(i) / float(coil_steps)
		var ang := u * 4.5 * TAU
		var r := lerpf(0.04, 0.16, minf(1.0, u * 4.0))
		var cp := Vector3(cx + cos(ang) * r, lerpf(1.30, 0.56, u), sin(ang) * r)
		_tube_seg(cond_grp, prev_cp, cp, 0.02, 6, copper)
		prev_cp = cp
	# Kupfer-Zapfhahn vorne unten + kleines Glasgefäß darunter
	_poly_cyl(cond_grp, 0.022, 0.022, 0.10, 6, Vector3(cx, 0.24, 0.37), copper, Vector3(PI * 0.5, 0, 0))
	_poly_cyl(cond_grp, 0.016, 0.016, 0.06, 6, Vector3(cx, 0.21, 0.41), copper)
	_poly_cyl(cond_grp, 0.055, 0.048, 0.11, 8, Vector3(cx, 0.115, 0.41), glass)

	# Angepasste Gesamt-CollisionShape3D (~1.85m breit, 1.55m hoch)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.85, 1.55, 1.0)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.775, 0.0)
	sb.add_child(cs)
	n.add_child(sb)


## Modell ohne Logik (auch für die Vorschau beim Aufstellen)
static func model(type: String) -> Node3D:
	var glb := _try_load_glb(type)
	if glb != null:
		return glb
	var n := Node3D.new()
	match type:
		"still":
			_build_still(n)
		"still_pot":
			_build_still(n)
			var cond := n.get_node_or_null("StillCondenser")
			if cond:
				cond.visible = false
		"bottling_table":
			box(n, Vector3(1.5, 0.08, 0.85), Vector3(0, 0.78, 0), WOOD, Vector3.ZERO, true)
			for p in [Vector3(-0.65, 0, -0.34), Vector3(0.65, 0, -0.34), Vector3(-0.65, 0, 0.34), Vector3(0.65, 0, 0.34)]:
				box(n, Vector3(0.08, 0.75, 0.08), p + Vector3(0, 0.375, 0), DARK_WOOD)
			cyl(n, 0.14, 0.18, Vector3(-0.35, 0.91, 0.0), COPPER, 0.04)  # Trichter
			for k in 3:
				var b_vis := _try_load_glb("moonshine")
				if b_vis:
					b_vis.position = Vector3(0.18 + k * 0.18, 0.82, -0.08 + (k % 2) * 0.16)
					n.add_child(b_vis)
				else:
					cyl(n, 0.045, 0.22, Vector3(0.18 + k * 0.18, 0.93, -0.08 + (k % 2) * 0.16), Color(0.84, 0.93, 0.96))
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
		"moonshine_keg", "empty_keg":
			var is_full := type == "moonshine_keg"
			var keg_col := Color(0.45, 0.30, 0.16) if is_full else Color(0.55, 0.42, 0.28)
			cyl(n, 0.28, 0.52, Vector3(0, 0.26, 0), keg_col, 0.26)
			cyl(n, 0.29, 0.05, Vector3(0, 0.10, 0), Color(0.28, 0.29, 0.31))
			cyl(n, 0.29, 0.05, Vector3(0, 0.42, 0), Color(0.28, 0.29, 0.31))
			cyl(n, 0.25, 0.04, Vector3(0, 0.53, 0), Color(0.22, 0.23, 0.25) if is_full else Color(0.42, 0.44, 0.46))
			box(n, Vector3(0.06, 0.06, 0.12), Vector3(0, 0.18, 0.29), Color(0.75, 0.60, 0.22))
			n.add_to_group("carryable_keg")
			n.set_meta("kind", type)
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
		"still", "still_pot":
			var lm: Landmarks = game.landmarks
			for c in [Vector2.ZERO, lm.home_center, lm.city_center, Vector2(lm.gas.pos.x, lm.gas.pos.z)]:
				if c.distance_to(p2) < STILL_MIN_DIST:
					return "Zu nah am Ort, die Polizei würde es merken (mind. %d m)" % STILL_MIN_DIST
		"table", "chair", "bed", "sofa", "shelf", "lamp", "rug", "stove", "frame", "frame_big", "trophy", "trophy_boar", "pelt_rug", "chest", "plant":
			if not game.inside_own_house(pos):
				return "Möbel nur im eigenen Haus"
	return ""
