class_name WorldBuilder
extends Node3D
## Baut die Spielwelt aus data/riegersdorf.json (erzeugt von tools/build_world_data.mjs):
## Gelände in Kacheln, Berge rundherum, Straßen, Bahn, Bäche, Häuser mit Fenstern, Türen und Balkonen,
## Bäume, Beschriftungen und die Spielgrenze.
## Weil das Bauen einige Sekunden dauert, wird das Ergebnis in data/world_baked.scn gespeichert
## und beim nächsten Start nur noch geladen (neu gebaut wird, wenn sich Daten oder BUILD_VERSION ändern).
## Koordinaten: x = Osten, z = Süden, y = Höhe über dem tiefsten Punkt, alles in Metern.

@export_file("*.json") var data_path := "res://data/riegersdorf.json"
@export var baked_path := "res://data/world_baked.scn"
@export var show_labels := true

const BUILD_VERSION := 26
const WORLD_SEED := 20261125
const LAYER_TREES := 1
const LAYER_ROCKS := 2
const LAYER_BUSHES := 3
const LAYER_GRASS := 4
const LAYER_FLOWERS := 5
const MAP_SCALE := 1.7
## Gebäude, die das Spiel selbst (begehbar) nachbaut: Feuerwehrhaus Korpitsch
const SKIP_BUILDINGS := [424764105, 282883314]  # Feuerwehrhaus, Gasthaus Pirtscher (eigene Modelle)
const CHUNK := 250.0
const C_GRASS := Color(0.388, 0.722, 0.106)  # #63B81B Meadow Grass Base
const KIND_COLORS := {
	"grass": Color(0.388, 0.722, 0.106),     # #63B81B
	"meadow": Color(0.431, 0.784, 0.118),    # #6EC81E
	"farmland": Color(0.28, 0.20, 0.13),
	"scrub": Color(0.290, 0.365, 0.247),     # #4A5D3F
	"residential": Color(0.43, 0.66, 0.18),
	"industrial": Color(0.60, 0.58, 0.48),
	"cemetery": Color(0.36, 0.58, 0.22),
	"forest": Color(0.243, 0.482, 0.071),    # #3E7B12 Shaded Meadow / Forest
	"pitch": Color(0.388, 0.722, 0.106),
	"parking": Color(0.50, 0.50, 0.51),
	"water": Color(0.251, 0.722, 0.878),     # #40B8E0 River Water
}
## Straßenklassen laut Spielkonzept
const TIER_MAIN := 1  # Hauptstraße (Asphalt, Mittellinie): viel Polizei, Kontrollen
const TIER_VILLAGE := 2  # Dorfstraße: wenig Polizei
const TIER_DIRT := 3  # Feld- und Waldweg: keine Polizei, holprig
const TIER_EXTREME := 4  # Bergpfad: nur mit Umbauten befahrbar
const TIER_NAMES := ["Gelände", "Hauptstraße", "Dorfstraße", "Schotterweg", "Bergpfad"]
const ROAD_STYLE := {
	# Art: [Rang, Belag, Rand, Mittellinie]
	"motorway": [9, Color(0.34, 0.34, 0.38), Color(0.88, 0.88, 0.84), true],
	"trunk": [8, Color(0.35, 0.35, 0.39), Color(0.88, 0.88, 0.84), true],
	"primary": [8, Color(0.36, 0.36, 0.40), Color(0.85, 0.85, 0.80), true],
	"secondary": [7, Color(0.37, 0.37, 0.41), Color(0.85, 0.85, 0.80), true],
	"tertiary": [6, Color(0.39, 0.39, 0.43), Color(0.82, 0.82, 0.78), false],
	"motorway_link": [6, Color(0.36, 0.36, 0.40), Color(0.85, 0.85, 0.80), false],
	"trunk_link": [6, Color(0.36, 0.36, 0.40), Color(0.85, 0.85, 0.80), false],
	"primary_link": [6, Color(0.36, 0.36, 0.40), Color(0.85, 0.85, 0.80), false],
	"secondary_link": [6, Color(0.37, 0.37, 0.41), Color(0.85, 0.85, 0.80), false],
	"tertiary_link": [5, Color(0.39, 0.39, 0.43), Color(0.82, 0.82, 0.78), false],
	"unclassified": [5, Color(0.41, 0.41, 0.45), Color(0.70, 0.68, 0.60), false],
	"residential": [5, Color(0.41, 0.41, 0.45), Color(0.70, 0.68, 0.60), false],
	"living_street": [5, Color(0.41, 0.41, 0.45), Color(0.70, 0.68, 0.60), false],
	"service": [4, Color(0.46, 0.45, 0.47), null, false],
	"track": [3, Color(0.769, 0.675, 0.525), null, false],   # #C4AC86 Dirt Roads
	"extreme": [3, Color(0.46, 0.42, 0.38), null, false],
	"cycleway": [2, Color(0.62, 0.42, 0.40), null, false],
	"path": [1, Color(0.784, 0.690, 0.533), null, false],    # #C8B088 Clearings / Paths
	"footway": [1, Color(0.70, 0.66, 0.58), null, false],
	"steps": [1, Color(0.66, 0.64, 0.60), null, false],
}
const WALL_COLORS := [
	Color(0.97, 0.93, 0.82), Color(0.98, 0.97, 0.93), Color(0.98, 0.89, 0.66),
	Color(0.96, 0.82, 0.70), Color(0.84, 0.88, 0.90), Color(0.93, 0.86, 0.76),
	Color(0.90, 0.95, 0.85), Color(0.99, 0.93, 0.88),
]
const ROOF_COLORS := [
	Color(0.74, 0.27, 0.20), Color(0.62, 0.22, 0.17), Color(0.45, 0.28, 0.22),
	Color(0.33, 0.33, 0.36), Color(0.80, 0.38, 0.24), Color(0.55, 0.24, 0.20),
]
const WOOD := Color(0.55, 0.35, 0.20)
const SHUTTER_COLORS := [Color(0.24, 0.45, 0.28), Color(0.50, 0.30, 0.17), Color(0.62, 0.20, 0.17)]
const DWELLINGS := ["yes", "house", "residential", "detached", "apartments", "farm", "semidetached_house",
	"terrace", "school", "commercial", "retail", "hotel", "pub", "restaurant", "office", "public",
	"community_centre", "fire_station", "bank", "civic", "kindergarten", "dormitory"]

var data: Dictionary
var heights := PackedFloat32Array()
var classes := PackedByteArray()
var kinds: Array = []
var x0 := 0.0
var z0 := 0.0
var nx := 0
var nz := 0
var step := 5.0
var border := PackedVector2Array()

var _content: Node3D
var _obstacle_grid := {}
var _trunk_shapes: Array[CollisionShape3D] = []
var _rock_shapes: Array[CollisionShape3D] = []
var _col_timer := 0.0
var _exclusion_rects: Array = []
var _flatten_zones: Array = []
var _exclusion_hash := ""


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	if not load_data():
		return
	_collect_building_exclusions()
	_apply_terrain_flattening()
	if not _load_baked():
		build()
		_save_baked()
	_setup_obstacle_colliders()
	print("Welt bereit in %d ms" % (Time.get_ticks_msec() - t0))
	if OS.get_cmdline_user_args().has("--bake-and-quit") and DisplayServer.get_name() != "headless":
		get_tree().quit(0)


func _exit_tree() -> void:
	_obstacle_grid.clear()
	_trunk_shapes.clear()
	_rock_shapes.clear()


func _physics_process(delta: float) -> void:
	if _obstacle_grid.is_empty():
		return
	_col_timer -= delta
	if _col_timer > 0.0:
		return
	_col_timer = 0.05
	var center_pos := Vector3.ZERO
	var found := false
	var cam_rig := get_parent().get_node_or_null("CameraRig")
	if cam_rig and cam_rig.get("target") is Node3D:
		center_pos = (cam_rig.get("target") as Node3D).global_position
		found = true
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			center_pos = cam.global_position
			found = true
	if found:
		_update_obstacle_colliders(center_pos)


func _setup_obstacle_colliders() -> void:
	if _content == null:
		return
	_obstacle_grid.clear()
	var stack: Array[Node] = [_content]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			var nm := mmi.name
			var is_tree := nm.begins_with("B_") or nm.begins_with("TP") or nm.begins_with("TD") or nm.begins_with("TS")
			var is_rock := nm.begins_with("RK")
			if (is_tree or is_rock) and mmi.multimesh != null:
				var kind := 0.0 if is_tree else 1.0
				var base := mmi.position
				var mm := mmi.multimesh
				for i in mm.instance_count:
					var p := base + mm.get_instance_transform(i).origin
					var key := Vector2i(floori(p.x / 50.0), floori(p.z / 50.0))
					if not _obstacle_grid.has(key):
						_obstacle_grid[key] = []
					_obstacle_grid[key].append(Vector4(p.x, p.y, p.z, kind))
		for child in n.get_children():
			stack.append(child)

	var body := StaticBody3D.new()
	body.name = "ObstacleColliderPool"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var cyl := CylinderShape3D.new()
	cyl.radius = 0.40
	cyl.height = 4.0
	for _i in 24:
		var cs := CollisionShape3D.new()
		cs.shape = cyl
		cs.position = Vector3(0.0, -5000.0, 0.0)
		body.add_child(cs)
		_trunk_shapes.append(cs)

	var sph := SphereShape3D.new()
	sph.radius = 0.95
	for _i in 8:
		var cs := CollisionShape3D.new()
		cs.shape = sph
		cs.position = Vector3(0.0, -5000.0, 0.0)
		body.add_child(cs)
		_rock_shapes.append(cs)

	var sample_trees: Array[String] = []
	var sample_rocks: Array[String] = []
	var gkeys := _obstacle_grid.keys()
	gkeys.sort()
	for k in gkeys:
		for v: Vector4 in _obstacle_grid[k]:
			if v.w < 0.5 and sample_trees.size() < 3:
				sample_trees.append("(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z])
			elif v.w >= 0.5 and sample_rocks.size() < 3:
				sample_rocks.append("(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z])
		if sample_trees.size() >= 3 and sample_rocks.size() >= 3:
			break
	print("DETERMINISTIC SAMPLE TREES: ", sample_trees)
	print("DETERMINISTIC SAMPLE ROCKS: ", sample_rocks)


func _update_obstacle_colliders(center: Vector3) -> void:
	var ckey := Vector2i(floori(center.x / 50.0), floori(center.z / 50.0))
	var trees: Array = []
	var rocks: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for v: Vector4 in _obstacle_grid.get(ckey + Vector2i(dx, dz), []):
				var d2 := (v.x - center.x) * (v.x - center.x) + (v.z - center.z) * (v.z - center.z)
				if d2 > 3600.0:
					continue
				if v.w < 0.5:
					trees.append([d2, v])
				else:
					rocks.append([d2, v])
	trees.sort_custom(func(a, b): return a[0] < b[0])
	rocks.sort_custom(func(a, b): return a[0] < b[0])
	for i in _trunk_shapes.size():
		if i < trees.size():
			var v: Vector4 = trees[i][1]
			_trunk_shapes[i].position = Vector3(v.x, v.y + 2.0, v.z)
		else:
			_trunk_shapes[i].position = Vector3(0.0, -5000.0, 0.0)
	for i in _rock_shapes.size():
		if i < rocks.size():
			var v: Vector4 = rocks[i][1]
			_rock_shapes[i].position = Vector3(v.x, v.y + 0.65, v.z)
		else:
			_rock_shapes[i].position = Vector3(0.0, -5000.0, 0.0)


func load_data() -> bool:
	var text := FileAccess.get_file_as_string(data_path)
	if text.is_empty():
		push_error("Weltdaten fehlen: %s (node tools/build_world_data.mjs ausführen)" % data_path)
		return false
	data = JSON.parse_string(text)
	_apply_map_scale(MAP_SCALE)
	var g: Dictionary = data.grid
	x0 = g.x0
	z0 = g.z0
	nx = int(g.nx)
	nz = int(g.nz)
	step = g.step
	heights = Marshalls.base64_to_raw(g.heights).to_float32_array()
	classes = Marshalls.base64_to_raw(g.classes)
	kinds = g.kinds
	border = to_v2_array(data.border)
	_index_roads()
	_smooth_and_carve_roads()
	_index_trees()
	return true


## Glättet Straßen-Höhenprofile entlang der Mittellinie und ebnet das Terrain unter Straßen
## (0° Querneigung) mit einem 4,5 m breiten Smoothstep-Übergang ins umliegende Gelände ein.
func _smooth_and_carve_roads() -> void:
	var t0 := Time.get_ticks_msec()
	var total := nx * nz
	var sum_w := PackedFloat32Array()
	var sum_wh := PackedFloat32Array()
	var max_w := PackedFloat32Array()
	sum_w.resize(total)
	sum_wh.resize(total)
	max_w.resize(total)

	for pass_idx in 4:
		sum_w.fill(0.0)
		sum_wh.fill(0.0)
		max_w.fill(0.0)
		for r in data.roads:
			if r.bridge or not ROAD_STYLE.has(r.kind):
				continue
			var is_tun: bool = bool(r.get("tunnel", false)) or bool(r.get("covered", false)) or int(r.get("layer", 0)) < 0
			var road_pass := 3 if is_tun else (0 if int(r.get("tier", TIER_DIRT)) >= TIER_DIRT else (1 if int(r.get("tier", TIER_VILLAGE)) == TIER_VILLAGE else 2))
			if road_pass != pass_idx:
				continue
			var line := _resample(r.pts, 2.5 if is_tun else 4.0)
			if line.size() < 2:
				continue
			var ys := PackedFloat32Array()
			if is_tun:
				# +12m Portal-Vorlauf vorne und hinten, ungestörte Ein-/Ausfahrt bei 25m
				var dir_in := (line[0] - line[1]).normalized()
				var dir_out := (line[-1] - line[-2]).normalized()
				var p_in := line[0] + dir_in * 12.0
				var p_out := line[-1] + dir_out * 12.0
				var p_start := line[0] + dir_in * 25.0
				var p_end := line[-1] + dir_out * 25.0
				var h_start := minf(height_at(p_start.x, p_start.y), height_at(line[0].x, line[0].y))
				var h_end := minf(height_at(p_end.x, p_end.y), height_at(line[-1].x, line[-1].y))
				var tun_line := PackedVector2Array()
				for s in range(5, 0, -1):
					tun_line.append(line[0].lerp(p_in, float(s) / 5.0))
				tun_line.append_array(line)
				for s in range(1, 6):
					tun_line.append(line[-1].lerp(p_out, float(s) / 5.0))
				var tun_ys := PackedFloat32Array()
				var deck_ys := PackedFloat32Array()
				tun_ys.resize(tun_line.size())
				deck_ys.resize(tun_line.size())
				for k in tun_line.size():
					var tk := float(k + 5) / float(tun_line.size() + 9)
					var fy := lerpf(h_start, h_end, tk)
					var dy := fy + 6.0 + 0.55
					var pt := tun_line[k]
					for rl in data.rails:
						if rl.tunnel or rl.bridge or rl.kind == "platform":
							continue
						var rpts: Array = rl.pts
						for m in range(1, rpts.size()):
							var ra := Vector2(rpts[m - 1][0], rpts[m - 1][1])
							var rb := Vector2(rpts[m][0], rpts[m][1])
							if Geometry2D.get_closest_point_to_segment(pt, ra, rb).distance_to(pt) <= 10.0:
								var rail_h := height_at(pt.x, pt.y)
								dy = maxf(dy, rail_h)
								fy = minf(fy, dy - 6.55)
								break
					tun_ys[k] = fy
					deck_ys[k] = dy
				r["_tunnel_line"] = tun_line
				r["_tunnel_ys"] = tun_ys
				r["_tunnel_deck_ys"] = deck_ys
				# Terrain außerhalb p_in/p_out bündig an Bodenplatte (-0.05m), innerhalb auf (floor_y - 1.5m) ausfräsen
				var ext := PackedVector2Array([p_start])
				ys.append(h_start)
				for s in range(1, 5):
					var p_r := p_start.lerp(p_in, float(s) / 5.0)
					var fy_r := lerpf(h_start, tun_ys[0], float(s) / 5.0)
					ext.append(p_r)
					ys.append(fy_r - 0.05 * (float(s) / 5.0))
				ext.append_array(tun_line)
				for k in tun_ys.size():
					var t_in := clampf(float(k) / 5.0, 0.0, 1.0)
					var t_out := clampf(float(tun_ys.size() - 1 - k) / 5.0, 0.0, 1.0)
					var carve_depth := 0.05 + 1.45 * minf(t_in, t_out)
					ys.append(tun_ys[k] - carve_depth)
				for s in range(1, 5):
					var p_r := p_out.lerp(p_end, float(s) / 5.0)
					var fy_r := lerpf(tun_ys[-1], h_end, float(s) / 5.0)
					ext.append(p_r)
					ys.append(fy_r - 0.05 * (1.0 - float(s) / 5.0))
				ext.append(p_end)
				ys.append(h_end)
				line = ext
			else:
				ys.resize(line.size())
				var s_dist := PackedFloat32Array()
				s_dist.resize(line.size())
				for k in line.size():
					ys[k] = height_at(line[k].x, line[k].y)
					s_dist[k] = 0.0 if k == 0 else s_dist[k - 1] + line[k].distance_to(line[k - 1])
				# Longitudinale Glättung (+/- 20 m Hauptstraßen, +/- 18 m Nebenstraßen) gegen Mulden an Kreuzungen
				var win_r := 20.0 if int(r.get("tier", TIER_DIRT)) == TIER_MAIN else 18.0
				for _pass in 2:
					var next_ys := ys.duplicate()
					for k in range(1, line.size() - 1):
						var w_sum := 0.0
						var wh_sum := 0.0
						var sk := s_dist[k]
						var m := k
						while m >= 0 and sk - s_dist[m] <= win_r:
							var d := sk - s_dist[m]
							var wt := 1.0 - (d / (win_r + 0.5))
							w_sum += wt
							wh_sum += wt * ys[m]
							m -= 1
						m = k + 1
						while m < line.size() and s_dist[m] - sk <= win_r:
							var d := s_dist[m] - sk
							var wt := 1.0 - (d / (win_r + 0.5))
							w_sum += wt
							wh_sum += wt * ys[m]
							m += 1
						if w_sum > 0.0:
							next_ys[k] = wh_sum / w_sum
					ys = next_ys
				# Lokal begrenzte Sehnen-Auffüllung (Valley-Fill) nur für kurze Senken <= 25.0 m
				var is_valley_fill_road: bool = r.kind in ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential"]
				if is_valley_fill_road:
					var filled_ys := ys.duplicate()
					for k in range(1, line.size() - 1):
						var sk := s_dist[k]
						var best_y := ys[k]
						var ka := k - 1
						while ka >= 0 and sk - s_dist[ka] <= 25.0:
							var sa := s_dist[ka]
							var kb := k + 1
							while kb < line.size() and s_dist[kb] - sa <= 25.0:
								var span := s_dist[kb] - sa
								if span > 0.1:
									var t_c := (sk - sa) / span
									var h_chord := lerpf(ys[ka], ys[kb], t_c)
									if h_chord > best_y:
										best_y = h_chord
								kb += 1
							ka -= 1
						filled_ys[k] = best_y
					ys = filled_ys

			var wall_hw_tun := float(r.width) * 0.5 + 0.95 + 0.55
			var is_vf_road: bool = (not is_tun) and (r.kind in ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential"])
			var half_w := (wall_hw_tun + 4.5) if is_tun else (float(r.width) * 0.5 + (1.0 if is_vf_road else 1.6))
			var outer_w := half_w + (2.5 if is_tun else (1.0 if is_vf_road else 4.5))
			var rank_w := 1.0 + float(ROAD_STYLE[r.kind][0]) * 1.5
			var outer_w2 := outer_w * outer_w
			for k in range(1, line.size()):
				var a := line[k - 1]
				var b := line[k]
				var ab := b - a
				var ab_len2 := ab.length_squared()
				if ab_len2 < 0.0001:
					continue
				var h_a := ys[k - 1]
				var h_b := ys[k]
				var i0 := clampi(floori((minf(a.x, b.x) - outer_w - x0) / step), 0, nx - 1)
				var i1 := clampi(ceili((maxf(a.x, b.x) + outer_w - x0) / step), 0, nx - 1)
				var j0 := clampi(floori((minf(a.y, b.y) - outer_w - z0) / step), 0, nz - 1)
				var j1 := clampi(ceili((maxf(a.y, b.y) + outer_w - z0) / step), 0, nz - 1)
				for j in range(j0, j1 + 1):
					var pz := z0 + j * step
					var row := j * nx
					for i in range(i0, i1 + 1):
						var px := x0 + i * step
						var apx := px - a.x
						var apz := pz - a.y
						var t := clampf((apx * ab.x + apz * ab.y) / ab_len2, 0.0, 1.0)
						var dx := apx - ab.x * t
						var dz := apz - ab.y * t
						var d2 := dx * dx + dz * dz
						if d2 > outer_w2:
							continue
						var d := sqrt(d2)
						var w := 1.0 if d <= half_w else 1.0 - smoothstep(half_w, outer_w, d)
						var idx := row + i
						var th := lerpf(h_a, h_b, t)
						if is_tun:
							# Schmaler Tunnel-Einschnitt dominiert lokal, damit der Bahndamm seitlich stehen bleibt
							sum_w[idx] = maxf(sum_w[idx], 1.0) + w * 200.0
							sum_wh[idx] += w * 200.0 * th
							if w > max_w[idx]:
								max_w[idx] = w
						else:
							sum_w[idx] += w * rank_w
							sum_wh[idx] += w * rank_w * th
							if w > max_w[idx]:
								max_w[idx] = w

		for idx in total:
			var sw := sum_w[idx]
			if sw > 0.001:
				heights[idx] = lerpf(heights[idx], sum_wh[idx] / sw, clampf(max_w[idx], 0.0, 1.0))
	print("  Straßen-Glättung & Carving: %d ms" % (Time.get_ticks_msec() - t0))


func _apply_map_scale(s: float) -> void:
	if is_equal_approx(s, 1.0):
		return
	var g: Dictionary = data.grid
	g.x0 = float(g.x0) * s
	g.z0 = float(g.z0) * s
	g.step = float(g.step) * s
	for p in data.border:
		p[0] = float(p[0]) * s
		p[1] = float(p[1]) * s
	for arr in [data.roads, data.rails, data.water_lines]:
		for r in arr:
			r.width = float(r.width) * s
			for pt in r.pts:
				pt[0] = float(pt[0]) * s
				pt[1] = float(pt[1]) * s
	# Häuser behalten ihre Größe, aber ihre Position/Abstände skalieren mit
	for b in data.buildings:
		var pts: Array = b.pts
		if pts.is_empty():
			continue
		var cx := 0.0
		var cz := 0.0
		for pt in pts:
			cx += float(pt[0])
			cz += float(pt[1])
		cx /= pts.size()
		cz /= pts.size()
		var dx := cx * (s - 1.0)
		var dz := cz * (s - 1.0)
		for pt in pts:
			pt[0] = float(pt[0]) + dx
			pt[1] = float(pt[1]) + dz
	for arr2 in [data.pois, data.places]:
		for item in arr2:
			item.pos[0] = float(item.pos[0]) * s
			item.pos[1] = float(item.pos[1]) * s


## Straßenklasse aus OSM-Art, Belag und Steigung
func _road_tier(r: Dictionary) -> int:
	var k: String = r.kind
	if k in ["motorway", "trunk", "primary", "secondary", "motorway_link", "trunk_link", "primary_link", "secondary_link"]:
		return TIER_MAIN
	var surface: String = str(r.surface) if r.get("surface") != null else ""
	var grade: String = str(r.tracktype) if r.get("tracktype") != null else ""
	if k in ["tertiary", "tertiary_link", "unclassified", "residential", "living_street"]:
		return TIER_VILLAGE
	if k == "service":
		return TIER_DIRT if surface in ["unpaved", "gravel", "ground", "dirt", "grass", "compacted"] else TIER_VILLAGE
	if grade in ["grade4", "grade5"]:
		return TIER_EXTREME
	if k in ["track", "path"]:
		# steile Wege in den Bergen sind Bergpfade
		var pts: Array = r.pts
		var a := Vector2(pts[0][0], pts[0][1])
		var b := Vector2(pts[-1][0], pts[-1][1])
		var len := maxf(a.distance_to(b), 1.0)
		if absf(height_at(a.x, a.y) - height_at(b.x, b.y)) / len > 0.14:
			return TIER_EXTREME
	return TIER_DIRT


# ------------------------------------------------------------------ Schneller Zugriff auf Straßen und Bäume

const ROAD_CELL := 64.0
const TREE_CELL := 32.0
var _road_grid := {}  # Vector2i -> Array von Vector2i(Straße, Segment)
var _tree_pos := PackedFloat32Array()
var _tree_grid := {}  # Vector2i -> PackedInt32Array


func _index_roads() -> void:
	_road_grid.clear()
	for ri in data.roads.size():
		var r: Dictionary = data.roads[ri]
		r.tier = _road_tier(r)
		var pts: Array = r.pts
		for k in range(1, pts.size()):
			var a := Vector2(pts[k - 1][0], pts[k - 1][1])
			var b := Vector2(pts[k][0], pts[k][1])
			var lo := Vector2i(floori((minf(a.x, b.x) - 10.0) / ROAD_CELL), floori((minf(a.y, b.y) - 10.0) / ROAD_CELL))
			var hi := Vector2i(floori((maxf(a.x, b.x) + 10.0) / ROAD_CELL), floori((maxf(a.y, b.y) + 10.0) / ROAD_CELL))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not _road_grid.has(key):
						_road_grid[key] = []
					_road_grid[key].append(Vector2i(ri, k))


func _index_trees() -> void:
	_tree_pos = Marshalls.base64_to_raw(data.trees).to_float32_array()
	_tree_grid.clear()
	var tmp := {}
	for k in range(0, _tree_pos.size(), 4):
		var key := Vector2i(floori(_tree_pos[k] / TREE_CELL), floori(_tree_pos[k + 1] / TREE_CELL))
		if not tmp.has(key):
			tmp[key] = []
		tmp[key].append(k)
	for key in tmp:
		_tree_grid[key] = PackedInt32Array(tmp[key])


## Straße unter / neben einem Punkt (schnell): {tier, kind, name, dist, pos, dir, road}
## tier 0 = keine Straße in der Nähe (Gelände)
func road_info(p: Vector2, max_dist := 12.0) -> Dictionary:
	var best := {tier = 0, kind = "", name = "", dist = INF, pos = p, dir = Vector2.RIGHT, road = -1}
	var key := Vector2i(floori(p.x / ROAD_CELL), floori(p.y / ROAD_CELL))
	if not _road_grid.has(key):
		return best
	for e: Vector2i in _road_grid[key]:
		var r: Dictionary = data.roads[e.x]
		var pts: Array = r.pts
		var a := Vector2(pts[e.y - 1][0], pts[e.y - 1][1])
		var b := Vector2(pts[e.y][0], pts[e.y][1])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d: float = q.distance_to(p) - r.width * 0.5
		if d < best.dist and d < max_dist:
			best = {tier = r.tier, kind = r.kind, name = r.name if r.name else "", dist = maxf(d, 0.0), pos = q, dir = (b - a).normalized(), road = e.x}
	return best


## Bäume im Umkreis (für Seilwinde und Platzierung)
func trees_near(p: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var lo := Vector2i(floori((p.x - radius) / TREE_CELL), floori((p.y - radius) / TREE_CELL))
	var hi := Vector2i(floori((p.x + radius) / TREE_CELL), floori((p.y + radius) / TREE_CELL))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cz)
			if not _tree_grid.has(key):
				continue
			for k in _tree_grid[key]:
				var t := Vector2(_tree_pos[k], _tree_pos[k + 1])
				if t.distance_to(p) <= radius:
					out.append(t)
	return out


## Flächenart an einem Punkt (forest, meadow, residential ...)
func kind_at(x: float, z: float) -> String:
	var i := clampi(roundi((x - x0) / step), 0, nx - 1)
	var j := clampi(roundi((z - z0) / step), 0, nz - 1)
	return kinds[classes[j * nx + i]]


## Steigung (0 = flach, 1 = 45°)
func slope_at(x: float, z: float) -> float:
	var dx := height_at(x + 2.0, z) - height_at(x - 2.0, z)
	var dz := height_at(x, z + 2.0) - height_at(x, z - 2.0)
	return Vector2(dx, dz).length() / 4.0


func ground_normal(x: float, z: float) -> Vector3:
	return Vector3(height_at(x - 1.0, z) - height_at(x + 1.0, z), 2.0, height_at(x, z - 1.0) - height_at(x, z + 1.0)).normalized()


# ------------------------------------------------------------------ Speichern / Laden

func _load_baked() -> bool:
	if OS.get_cmdline_user_args().has("--rebuild") or OS.get_cmdline_user_args().has("--force-bake") or not ResourceLoader.exists(baked_path):
		return false
	if FileAccess.get_modified_time(baked_path) < FileAccess.get_modified_time(data_path):
		return false
	var scene := load(baked_path) as PackedScene
	if scene == null:
		return false
	var node := scene.instantiate()
	if node.get_meta("version", 0) != BUILD_VERSION or str(node.get_meta("exclusion_hash", "")) != _exclusion_hash:
		node.free()
		return false
	_content = node
	add_child(_content)
	return true


func _save_baked(_force := false) -> void:
	if OS.has_feature("template"):
		return
	if DisplayServer.get_name() == "headless":
		push_warning("Welt-Bake im Headless-Modus blockiert (Dummy-Renderer würde MultiMesh-Transforms nullen).")
		return
	_set_owner_recursive(_content, _content)
	_content.set_meta("version", BUILD_VERSION)
	_content.set_meta("exclusion_hash", _exclusion_hash)
	var scene := PackedScene.new()
	if scene.pack(_content) != OK:
		push_warning("Welt konnte nicht gepackt werden")
		return
	var err := ResourceSaver.save(scene, baked_path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_warning("Welt konnte nicht gespeichert werden: %s" % err)
		return
	var hf := FileAccess.open(baked_path + ".hash", FileAccess.WRITE)
	if hf != null:
		hf.store_string(_exclusion_hash)
		hf.close()


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)


# ------------------------------------------------------------------ Abfragen

func height_at(x: float, z: float) -> float:
	var fx := clampf((x - x0) / step, 0.0, nx - 1.001)
	var fz := clampf((z - z0) / step, 0.0, nz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var ax := fx - i
	var az := fz - j
	var o := j * nx + i
	# Gleiche Dreiecksaufteilung wie das Geländemesh
	if ax + az <= 1.0:
		return heights[o] + (heights[o + 1] - heights[o]) * ax + (heights[o + nx] - heights[o]) * az
	var d := heights[o + nx + 1]
	return d + (heights[o + nx] - d) * (1.0 - ax) + (heights[o + 1] - d) * (1.0 - az)


func inside_border(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, border)


## Abstand zur Spielgrenze (positiv = innen)
func border_distance(p: Vector2) -> float:
	var best := INF
	for k in border.size():
		var q := Geometry2D.get_closest_point_to_segment(p, border[k], border[(k + 1) % border.size()])
		best = minf(best, q.distance_to(p))
	return best if inside_border(p) else -best


## Border-sicherer, bodengenauer Spawn-Transform (Terrain + Physics-Raycast nach unten, mit Fallback auf Heimat-Spawn)
func find_safe_spawn_transform(pos: Vector3, yaw: float, fallback_pos: Vector3, fallback_yaw: float, clearance := 1.0, exclude: Array = []) -> Transform3D:
	var use_pos := pos
	var use_yaw := yaw if is_finite(yaw) else fallback_yaw
	var valid := use_pos.is_finite() and inside_border(Vector2(use_pos.x, use_pos.z))
	if not valid:
		use_pos = fallback_pos
		use_yaw = fallback_yaw
	var ground_y := height_at(use_pos.x, use_pos.z)
	if is_inside_tree() and get_world_3d() != null:
		var space := get_world_3d().direct_space_state
		if space != null:
			var from_p := Vector3(use_pos.x, ground_y + 30.0, use_pos.z)
			var to_p := Vector3(use_pos.x, ground_y - 20.0, use_pos.z)
			var query := PhysicsRayQueryParameters3D.create(from_p, to_p, 1, exclude)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var hy: float = hit.position.y
				if absf(hy - ground_y) < 15.0:
					ground_y = maxf(ground_y, hy)
	var b := Basis(Vector3.UP, use_yaw)
	return Transform3D(b, Vector3(use_pos.x, ground_y + clearance, use_pos.z))


## Nächster Punkt auf einer Straße: {pos, dir, name, kind, dist}
func nearest_road(p: Vector2, kinds_filter: Array = [], max_dist := 200.0) -> Dictionary:
	var best := {dist = INF, name = ""}
	for r in data.roads:
		if not kinds_filter.is_empty() and not r.kind in kinds_filter:
			continue
		var pts: Array = r.pts
		var first: Array = pts[0]
		if absf(first[0] - p.x) > 3000.0 or absf(first[1] - p.y) > 3000.0:
			continue
		for k in range(1, pts.size()):
			var a := Vector2(pts[k - 1][0], pts[k - 1][1])
			var b := Vector2(pts[k][0], pts[k][1])
			if absf(a.x - p.x) > max_dist + 300.0 or absf(a.y - p.y) > max_dist + 300.0:
				continue
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := q.distance_to(p)
			if d < best.dist:
				best = {pos = q, dir = (b - a).normalized(), name = r.name if r.name else "", kind = r.kind, dist = d}
	return best


## Nächster benannter Ort (Gasthaus, Feuerwehr, Kirche ...): {name, kind, dist}
func nearest_poi(p: Vector2) -> Dictionary:
	var best := {dist = INF, name = ""}
	for poi in data.pois:
		var d := p.distance_to(Vector2(poi.pos[0], poi.pos[1]))
		if d < best.dist:
			best = {name = poi.name, kind = poi.kind, dist = d}
	return best


## Nächstes Dorf / nächster Ortsteil: {name, dist}
func nearest_place(p: Vector2) -> Dictionary:
	var best := {dist = INF, name = "Riegersdorf"}
	for pl in data.places:
		var d := p.distance_to(Vector2(pl.pos[0], pl.pos[1]))
		if d < best.dist:
			best = {name = pl.name, dist = d}
	return best


func poi_position(poi_name: String) -> Vector2:
	for poi in data.pois:
		if poi.name == poi_name:
			return Vector2(poi.pos[0], poi.pos[1])
	return Vector2.ZERO


static func hash01(a: float, b := 0.0) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - floorf(v)


static func to_v2_array(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	return out


func _chunk_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori((x - x0) / CHUNK), floori((z - z0) / CHUNK))


func _buf(dict: Dictionary, x: float, z: float) -> MeshBuffer:
	var k := _chunk_key(x, z)
	if not dict.has(k):
		dict[k] = MeshBuffer.new()
	return dict[k]


func _group(group_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = group_name
	_content.add_child(n)
	return n


func _mesh_node(parent: Node, mesh: Mesh, node_name: String, collide := false, vis_end := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
		mi.visibility_range_end_margin = 60.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	if collide:
		mi.create_trimesh_collision()
	return mi


# ------------------------------------------------------------------ Bauen

func build() -> void:
	_content = Node3D.new()
	_content.name = "Welt"
	add_child(_content)
	var steps := [
		["Gelände", _build_terrain], ["Berge", _build_far_terrain], ["Wasser", _build_water],
		["Straßen", _build_lines], ["Häuser", _build_buildings], ["Bäume", _build_trees],
		["Gras & Blumen", _build_foliage], ["Felder", _build_fields], ["Grenze", _build_border], ["Schilder", _build_labels], ["POIs", _build_pois],
	]
	for s in steps:
		var t := Time.get_ticks_msec()
		s[1].call()
		print("  %s: %d ms" % [s[0], Time.get_ticks_msec() - t])


func is_snow(_p: Vector2) -> bool:
	return false


func is_swamp(p: Vector2) -> bool:
	return p.x < -120.0 and p.y < -80.0 and height_at(p.x, p.y) < 16.0


func _terrain_color(i: int, j: int) -> Color:
	var kind: String = kinds[classes[j * nx + i]]
	var c: Color = KIND_COLORS.get(kind, C_GRASS)
	var x := x0 + i * step
	var z := z0 + j * step
	var y := heights[j * nx + i]
	if slope_at(x, z) > 1.08:
		c = Color(0.431, 0.451, 0.431)  # #6E736E Steile Felswand
	elif (z > 700.0 and y > 90.0) or kind == "forest":
		c = Color(0.243, 0.490, 0.125).lerp(Color(0.306, 0.604, 0.133), hash01(x * 0.05, z * 0.05))  # #3E7D20 -> #4E9A22
	elif x < -120.0 and z < -80.0 and y < 16.0 and kind != "water":
		c = Color(0.290, 0.365, 0.247)  # #4A5D3F Swamp Olive
	elif kind == "farmland":
		# Satte Ackererde mit Pflugfurchen-Struktur
		var a := hash01(floorf(x / 120.0), floorf(z / 120.0)) * PI
		var furrow := sin((x * cos(a) + z * sin(a)) * 1.4)
		c = c.darkened(0.22) if furrow > 0.0 else c.lightened(0.06)
	var n := hash01(x * 0.37, z * 0.21)
	return c.lightened(n * 0.06) if n > 0.5 else c.darkened((0.5 - n) * 0.08)


func _build_terrain() -> void:
	var group := _group("Gelaende")
	var cells := int(CHUNK / step)
	for cj in range(0, nz - 1, cells):
		for ci in range(0, nx - 1, cells):
			var w := mini(cells, nx - 1 - ci) + 1
			var h := mini(cells, nz - 1 - cj) + 1
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			verts.resize(w * h)
			normals.resize(w * h)
			colors.resize(w * h)
			for lj in h:
				var j := cj + lj
				for li in w:
					var i := ci + li
					var o := j * nx + i
					var k := lj * w + li
					verts[k] = Vector3(x0 + i * step, heights[o], z0 + j * step)
					var hl := heights[o - 1] if i > 0 else heights[o]
					var hr := heights[o + 1] if i < nx - 1 else heights[o]
					var hu := heights[o - nx] if j > 0 else heights[o]
					var hd := heights[o + nx] if j < nz - 1 else heights[o]
					normals[k] = Vector3(hl - hr, 2.0 * step, hu - hd).normalized()
					colors[k] = _terrain_color(i, j)
			var indices := PackedInt32Array()
			indices.resize((w - 1) * (h - 1) * 6)
			var q := 0
			for lj in h - 1:
				for li in w - 1:
					var a := lj * w + li
					indices[q] = a; indices[q + 1] = a + 1; indices[q + 2] = a + w
					indices[q + 3] = a + 1; indices[q + 4] = a + w + 1; indices[q + 5] = a + w
					q += 6
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, Toon.terrain_material())
			_mesh_node(group, mesh, "T_%d_%d" % [ci / cells, cj / cells])

	# Kollision als Höhenfeld
	var body := StaticBody3D.new()
	body.name = "GelaendeKollision"
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.position = Vector3(x0 + (nx - 1) * step * 0.5, 0, z0 + (nz - 1) * step * 0.5)
	body.add_child(cs)
	_content.add_child(body)


## Grobe Landschaft bis 9 km weit (Dobratsch, Karawanken), liegt unter dem genauen Gelände
func _build_far_terrain() -> void:
	var f: Dictionary = data.far
	var fn := int(f.n)
	var fs: float = f.step
	var fx0: float = f.x0
	var fz0: float = f.z0
	var fh := Marshalls.base64_to_raw(f.heights).to_float32_array()
	var base: float = data.info.base_height
	var inner := Rect2(x0 + step, z0 + step, (nx - 3) * step, (nz - 3) * step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(fn * fn)
	normals.resize(fn * fn)
	colors.resize(fn * fn)
	for j in fn:
		for i in fn:
			var o := j * fn + i
			var x := fx0 + i * fs
			var z := fz0 + j * fs
			var y := fh[o]
			if inner.grow(fs).has_point(Vector2(x, z)):
				y = minf(y, height_at(x, z)) - 4.0
			verts[o] = Vector3(x, y, z)
			var hl := fh[o - 1] if i > 0 else fh[o]
			var hr := fh[o + 1] if i < fn - 1 else fh[o]
			var hu := fh[o - fn] if j > 0 else fh[o]
			var hd := fh[o + fn] if j < fn - 1 else fh[o]
			var n := Vector3(hl - hr, 2.0 * fs, hu - hd).normalized()
			normals[o] = n
			var abs_h := y + base
			var c := Color(0.306, 0.604, 0.133)  # #4E9A22 Alpine green
			if n.y < 0.68:
				c = Color(0.431, 0.451, 0.431)   # #6E736E Steep cliff rock
			elif abs_h > 900.0 or n.y < 0.88:
				c = Color(0.243, 0.490, 0.125)   # #3E7D20 Deep forest green
			c = c.darkened(hash01(x * 0.01, z * 0.013) * 0.08)
			colors[o] = c
	var indices := PackedInt32Array()
	for j in fn - 1:
		for i in fn - 1:
			var a := j * fn + i
			var cx := fx0 + (i + 0.5) * fs
			var cz := fz0 + (j + 0.5) * fs
			if inner.grow(-fs).has_point(Vector2(cx, cz)):
				continue  # dort liegt das genaue Gelände
			indices.append_array([a, a + 1, a + fn, a + 1, a + fn + 1, a + fn])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Toon.terrain_material())
	var mi := _mesh_node(_content, mesh, "Berge")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_water() -> void:
	# Nur kartierte Flüsse & Bäche (water_lines in _build_lines); keine stehenden Wasser-Polygone
	return


# ------------------------------------------------------------------ Straßen, Bahn, Bäche

func _resample(pts: Array, max_seg := 1.8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(pts.size()):
		var p := Vector2(pts[k][0], pts[k][1])
		if k > 0:
			var prev := Vector2(pts[k - 1][0], pts[k - 1][1])
			var n := int(ceil(prev.distance_to(p) / max_seg))
			for s in range(1, n):
				out.append(prev.lerp(p, float(s) / n))
		out.append(p)
	return out


## Band entlang einer Linie, dem Gelände folgend, aufgeteilt auf Kacheln.
## dash > 0 ergibt eine Strichlinie, caps rundet die Enden ab (saubere Kreuzungen).
func _ribbon(bufs: Dictionary, line: PackedVector2Array, width: float, yoff: float, color: Color,
		offset := 0.0, dash := 0.0, bridge := false, caps := false, sample_width := -1.0, skirt_drop := 0.0, tunnel_grid: Dictionary = {}, use_edge_max := true, suppress_on_asphalt := false) -> void:
	if line.size() < 2:
		return
	var hw := width * 0.5
	var sw := (sample_width if sample_width > 0.0 else width) * 0.5
	var h_start := height_at(line[0].x, line[0].y)
	var h_end := height_at(line[line.size() - 1].x, line[line.size() - 1].y)
	var total := 0.0
	var lens := PackedFloat32Array([0.0])
	for k in range(1, line.size()):
		total += line[k].distance_to(line[k - 1])
		lens.append(total)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var ys := PackedFloat32Array()
	for k in line.size():
		var dir: Vector2
		if k == 0:
			dir = line[1] - line[0]
		elif k == line.size() - 1:
			dir = line[k] - line[k - 1]
		else:
			dir = (line[k + 1] - line[k]).normalized() + (line[k] - line[k - 1]).normalized()
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		var p := line[k] + side * offset
		var y: float
		if bridge:
			var t := lens[k] / maxf(total, 0.01)
			y = lerpf(h_start, h_end, t) + sin(t * PI) * minf(total * 0.02, 1.5) + yoff
		else:
			var in_tunnel := false
			var tun_y := 0.0
			var tkey := Vector2i(floori(p.x / ROAD_CELL), floori(p.y / ROAD_CELL))
			for tz: Dictionary in tunnel_grid.get(tkey, []):
				var q := Geometry2D.get_closest_point_to_segment(p, tz.a, tz.b)
				if q.distance_to(p) <= float(tz.hw):
					var seg_l: float = maxf(0.001, (tz.b - tz.a).length())
					var t_seg := clampf((q - tz.a).length() / seg_l, 0.0, 1.0)
					tun_y = lerpf(float(tz.y0), float(tz.y1), t_seg)
					in_tunnel = true
					break
			if in_tunnel:
				y = tun_y + yoff
			elif suppress_on_asphalt:
				var ri := road_info(p, 0.6)
				if ri.tier > 0 and ri.tier <= TIER_VILLAGE and ri.dist <= 0.4:
					y = height_at(p.x, p.y) - 0.046
				else:
					y = height_at(p.x, p.y) + yoff
			elif not use_edge_max:
				y = height_at(p.x, p.y) + yoff
			else:
				y = maxf(height_at(p.x - side.x * sw, p.y - side.y * sw), height_at(p.x + side.x * sw, p.y + side.y * sw))
				y = maxf(y, height_at(p.x, p.y)) + yoff
		ys.append(y)
		var l := p - side * hw
		var r := p + side * hw
		left.append(Vector3(l.x, y, l.y))
		right.append(Vector3(r.x, y, r.y))
	for k in range(1, line.size()):
		if dash > 0.0 and int(floor((lens[k - 1] + lens[k]) * 0.5 / dash)) % 2 == 1:
			continue
		var m := (line[k] + line[k - 1]) * 0.5
		var buf := _buf(bufs, m.x, m.y)
		if bridge or dash > 0.0:
			buf.add_quad(left[k - 1], right[k - 1], right[k], left[k], color, Vector3.UP)
		else:
			# Volle Kern-Fahrbahn (+0.038m) + 0.9m Außen-Bankett (+0.012m) je Seite
			var c0 := (left[k - 1] + right[k - 1]) * 0.5
			var c1 := (left[k] + right[k]) * 0.5
			var s0 := (right[k - 1] - left[k - 1]).normalized()
			var s1 := (right[k] - left[k]).normalized()
			var lc0 := left[k - 1] + Vector3(0, 0.026, 0)
			var lc1 := left[k] + Vector3(0, 0.026, 0)
			var rc0 := right[k - 1] + Vector3(0, 0.026, 0)
			var rc1 := right[k] + Vector3(0, 0.026, 0)
			var lo0 := left[k - 1] - s0 * 0.9
			var lo1 := left[k] - s1 * 0.9
			var ro0 := right[k - 1] + s0 * 0.9
			var ro1 := right[k] + s1 * 0.9
			var cc0 := c0 + Vector3(0, 0.026, 0)
			var cc1 := c1 + Vector3(0, 0.026, 0)
			var v0 := lens[k - 1]
			var v1 := lens[k]
			buf.add_quad_uv(lo0, lc0, lc1, lo1, Vector2(0.0, v0), Vector2(0.15, v0), Vector2(0.15, v1), Vector2(0.0, v1), color, Vector3.UP)
			buf.add_quad_uv(lc0, cc0, cc1, lc1, Vector2(0.15, v0), Vector2(0.5, v0), Vector2(0.5, v1), Vector2(0.15, v1), color, Vector3.UP)
			buf.add_quad_uv(cc0, rc0, rc1, cc1, Vector2(0.5, v0), Vector2(0.85, v0), Vector2(0.85, v1), Vector2(0.5, v1), color, Vector3.UP)
			buf.add_quad_uv(rc0, ro0, ro1, rc1, Vector2(0.85, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.85, v1), color, Vector3.UP)
	if caps and not bridge:
		for e in [0, line.size() - 1]:
			var c := Vector3(line[e].x, ys[e], line[e].y)
			var buf := _buf(bufs, c.x, c.z)
			var seg := 8
			for s in seg:
				var a0 := TAU * s / seg
				var a1 := TAU * (s + 1) / seg
				buf.add_tri(c, c + Vector3(cos(a0), 0, sin(a0)) * hw, c + Vector3(cos(a1), 0, sin(a1)) * hw, color, Vector3.UP)


func _commit_chunks(bufs: Dictionary, parent: Node3D, prefix: String, material: Material, collide := false, vis_end := 0.0) -> void:
	for k in bufs:
		var b: MeshBuffer = bufs[k]
		if not b.is_empty():
			_mesh_node(parent, b.to_mesh(material), "%s_%d_%d" % [prefix, k.x, k.y], collide, vis_end)


func _build_lines() -> void:
	var group := _group("Strassen")
	var roads_asphalt := {}
	var roads_dirt := {}
	var bridge_bufs := {}
	var sorted: Array = data.roads.filter(func(r): return ROAD_STYLE.has(r.kind))
	sorted.sort_custom(func(a, b): return ROAD_STYLE[a.kind][0] < ROAD_STYLE[b.kind][0])
	var tunnel_zones: Array = []  # [{a: Vector2, b: Vector2, hw: float, clear_hw: float, wall_hw: float, y0: float, y1: float, deck_y: float}]
	for r in sorted:
		if r.bridge or r.kind in ["footway", "steps", "cycleway", "path"]:
			continue
		var is_tun: bool = bool(r.get("tunnel", false)) or bool(r.get("covered", false)) or int(r.get("layer", 0)) < 0
		if not is_tun:
			continue
		var tline: PackedVector2Array = r.get("_tunnel_line", _resample(r.pts, 2.5))
		var tys: PackedFloat32Array = r.get("_tunnel_ys", PackedFloat32Array())
		var tdys: PackedFloat32Array = r.get("_tunnel_deck_ys", PackedFloat32Array())
		if tline.size() < 2:
			continue
		_build_tunnel_tube(bridge_bufs, tline, float(r.width), tunnel_zones, tys, tdys)
	var tunnel_grid := {}
	for tz: Dictionary in tunnel_zones:
		var pad: float = float(tz.wall_hw) + 4.5
		var lo := Vector2i(floori((minf(tz.a.x, tz.b.x) - pad) / ROAD_CELL), floori((minf(tz.a.y, tz.b.y) - pad) / ROAD_CELL))
		var hi := Vector2i(floori((maxf(tz.a.x, tz.b.x) + pad) / ROAD_CELL), floori((maxf(tz.a.y, tz.b.y) + pad) / ROAD_CELL))
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cz)
				if not tunnel_grid.has(key):
					tunnel_grid[key] = []
				tunnel_grid[key].append(tz)
	print("  Tunnel-Zonen: %d (Grid-Zellen: %d)" % [tunnel_zones.size(), tunnel_grid.size()])

	# Brücken behalten ihren Rand, normale Straßen liegen flächenbündig mit weichem Shader-Rand
	for r in sorted:
		if not r.bridge:
			continue
		var style: Array = ROAD_STYLE[r.kind]
		if style[2] == null:
			continue
		_ribbon(bridge_bufs, _resample(r.pts), r.width + 1.0, 0.04, style[2], 0.0, 0.0, true, true, r.width)
	for r in sorted:
		var style: Array = ROAD_STYLE["extreme"] if r.tier == TIER_EXTREME else ROAD_STYLE[r.kind]
		if r.kind == "service" and r.tier == TIER_DIRT:
			style = ROAD_STYLE["track"]
		var line := _resample(r.pts)
		var is_dirt: bool = r.tier >= TIER_DIRT
		var target := bridge_bufs if r.bridge else (roads_dirt if is_dirt else roads_asphalt)
		var y: float
		if r.bridge:
			y = 0.04 + float(style[0]) * 0.002
		elif is_dirt:
			# Feld-/Wald-/Radwege strikt unter Asphalt (+0.012m Kernfläche, auf Asphalt -0.02m)
			y = -0.014 + float(style[0]) * 0.0005
		elif r.tier == TIER_MAIN:
			# Hauptstraßen (+0.060m Kernfläche) über Nebenstraßen
			y = 0.034 + float(style[0]) * 0.0005
		else:
			# Nebenstraßen (+0.045m Kernfläche) über Feldwegen
			y = 0.019 + float(style[0]) * 0.0005
		_ribbon(target, line, r.width, y, style[1], 0.0, 0.0, r.bridge, r.bridge, -1.0, 0.0, tunnel_grid, not is_dirt, is_dirt and not r.bridge)
		if style[3] and r.bridge:
			_ribbon(target, line, 0.18, y + 0.012, Color(0.96, 0.96, 0.9), 0.0, 3.0, true, false, r.width)
	_commit_chunks(roads_asphalt, group, "SA", _road_shader_material(false))
	_commit_chunks(roads_dirt, group, "SD", _road_shader_material(true))

	var rails := {}
	for r in data.rails:
		if r.tunnel:
			continue
		var line := _resample(r.pts, 2.0)
		if r.kind == "platform":
			_ribbon(rails, line, r.width, 0.75, Color(0.72, 0.70, 0.66))
			continue
		if r.bridge and line.size() >= 2:
			var p_start := line[0]
			var p_end := line[line.size() - 1]
			var p_mid := line[line.size() / 2]
			var deck_y := maxf(maxf(height_at(p_start.x, p_start.y), height_at(p_end.x, p_end.y)) + 0.35, height_at(p_mid.x, p_mid.y) + 4.9)
			var deck_col := Color(0.56, 0.56, 0.54)
			var bw := float(r.width) + 1.4
			var bhw := bw * 0.5
			for k in range(1, line.size()):
				var a := line[k - 1]
				var b := line[k]
				var dir := (b - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				var al := Vector3(a.x - side.x * bhw, deck_y, a.y - side.y * bhw)
				var ar := Vector3(a.x + side.x * bhw, deck_y, a.y + side.y * bhw)
				var bl := Vector3(b.x - side.x * bhw, deck_y, b.y - side.y * bhw)
				var br := Vector3(b.x + side.x * bhw, deck_y, b.y + side.y * bhw)
				var mid := (a + b) * 0.5
				var bbuf := _buf(bridge_bufs, mid.x, mid.y)
				bbuf.add_quad(al, ar, br, bl, deck_col, Vector3.UP)
				bbuf.add_quad(al - Vector3(0, 0.45, 0), ar - Vector3(0, 0.45, 0), br - Vector3(0, 0.45, 0), bl - Vector3(0, 0.45, 0), deck_col.darkened(0.25), Vector3.DOWN)
			# Brückenpfeiler an den beiden Brückenenden (abseits der Unterführungsstraße)
			for ep in [p_start, p_end]:
				var h_bot := height_at(ep.x, ep.y) - 0.5
				var pier_h := maxf(0.5, deck_y - h_bot)
				var ob := {c = ep, u = (p_end - p_start).normalized(), v = Vector2(-(p_end - p_start).y, p_end.x - p_start.x).normalized(), hl = 0.7, hw = bhw - 0.15}
				_box(_buf(bridge_bufs, ep.x, ep.y), ob, h_bot, deck_y, deck_col.darkened(0.15))
				var r_y := deck_y + 0.08
				var _unused := pier_h
				var _u2 := r_y
			for k in range(1, line.size()):
				var a := line[k - 1]
				var b := line[k]
				var mid := (a + b) * 0.5
				var dir := (b - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				for rail_off: float in [-0.72, 0.72]:
					var p0: Vector2 = a + side * rail_off
					var p1: Vector2 = b + side * rail_off
					var rl := Vector3(p0.x - side.x * 0.06, deck_y + 0.12, p0.y - side.y * 0.06)
					var rr := Vector3(p0.x + side.x * 0.06, deck_y + 0.12, p0.y + side.y * 0.06)
					var r2l := Vector3(p1.x - side.x * 0.06, deck_y + 0.12, p1.y - side.y * 0.06)
					var r2r := Vector3(p1.x + side.x * 0.06, deck_y + 0.12, p1.y + side.y * 0.06)
					_buf(rails, mid.x, mid.y).add_quad(rl, rr, r2r, r2l, Color(0.75, 0.76, 0.80), Vector3.UP)
			continue
		if line.size() < 2:
			continue
		var r_ys := PackedFloat32Array()
		r_ys.resize(line.size())
		var in_cut := PackedByteArray()
		in_cut.resize(line.size())
		for k in line.size():
			var pt := line[k]
			var min_deck := -INF
			var pt_key := Vector2i(floori(pt.x / ROAD_CELL), floori(pt.y / ROAD_CELL))
			for tz: Dictionary in tunnel_grid.get(pt_key, []):
				var d := Geometry2D.get_closest_point_to_segment(pt, tz.a, tz.b).distance_to(pt)
				if d <= float(tz.wall_hw) + 3.0:
					in_cut[k] = 1
					min_deck = maxf(min_deck, float(tz.deck_y))
			r_ys[k] = maxf(height_at(pt.x, pt.y), min_deck)
		# Natürliches Bahndamm-Profil über den schmalen Tunnel-Einschnitt hinweg unverändert fortführen
		var k := 0
		while k < line.size():
			if in_cut[k] == 1:
				var k0 := maxi(0, k - 1)
				var k1 := k
				while k1 < line.size() - 1 and in_cut[k1] == 1:
					k1 += 1
				var h0 := r_ys[k0]
				var h1 := r_ys[k1]
				for m in range(k0, k1 + 1):
					var t := float(m - k0) / maxf(1.0, float(k1 - k0))
					r_ys[m] = maxf(r_ys[m], lerpf(h0, h1, t))
				k = k1 + 1
			else:
				k += 1
		var seg_dist := 0.0
		var top_hw := maxf(float(r.width) * 0.5, 2.2)
		var emb_col := Color(0.40, 0.37, 0.31)
		for m in range(1, line.size()):
			var a := line[m - 1]
			var b := line[m]
			var seg_len := a.distance_to(b)
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			if dir.length_squared() < 0.001:
				continue
			var side := Vector2(-dir.y, dir.x)
			var ya := r_ys[m - 1]
			var yb := r_ys[m]
			var rbuf := _buf(rails, mid.x, mid.y)
			# Bahndamm-Unterbau innerhalb von (wall_hw + 3.0 m) um eine tunnel_zone komplett weglassen
			var inside_tunnel_box := false
			var mid_key := Vector2i(floori(mid.x / ROAD_CELL), floori(mid.y / ROAD_CELL))
			var near_tuns: Array = tunnel_grid.get(mid_key, [])
			for tz: Dictionary in near_tuns:
				var skip_w := float(tz.wall_hw) + 3.0
				if Geometry2D.get_closest_point_to_segment(a, tz.a, tz.b).distance_to(a) <= skip_w \
						or Geometry2D.get_closest_point_to_segment(mid, tz.a, tz.b).distance_to(mid) <= skip_w \
						or Geometry2D.get_closest_point_to_segment(b, tz.a, tz.b).distance_to(b) <= skip_w:
					inside_tunnel_box = true
					break
			if not inside_tunnel_box:
				var h_emb_a := maxf(0.0, ya - minf(height_at(a.x - side.x * top_hw, a.y - side.y * top_hw), height_at(a.x + side.x * top_hw, a.y + side.y * top_hw)))
				var h_emb_b := maxf(0.0, yb - minf(height_at(b.x - side.x * top_hw, b.y - side.y * top_hw), height_at(b.x + side.x * top_hw, b.y + side.y * top_hw)))
				var bot_hw_a := top_hw + maxf(3.2, h_emb_a * 1.4 + 2.0)
				var bot_hw_b := top_hw + maxf(3.2, h_emb_b * 1.4 + 2.0)
				var al_top := Vector3(a.x - side.x * top_hw, ya + 0.12, a.y - side.y * top_hw)
				var ar_top := Vector3(a.x + side.x * top_hw, ya + 0.12, a.y + side.y * top_hw)
				var bl_top := Vector3(b.x - side.x * top_hw, yb + 0.12, b.y - side.y * top_hw)
				var br_top := Vector3(b.x + side.x * top_hw, yb + 0.12, b.y + side.y * top_hw)
				var al_bp := a - side * bot_hw_a
				var ar_bp := a + side * bot_hw_a
				var bl_bp := b - side * bot_hw_b
				var br_bp := b + side * bot_hw_b
				var al_by := minf(height_at(al_bp.x, al_bp.y), ya) - 2.0
				var ar_by := minf(height_at(ar_bp.x, ar_bp.y), ya) - 2.0
				var bl_by := minf(height_at(bl_bp.x, bl_bp.y), yb) - 2.0
				var br_by := minf(height_at(br_bp.x, br_bp.y), yb) - 2.0
				for tz: Dictionary in near_tuns:
					var buf_w := float(tz.wall_hw) + 4.0
					if Geometry2D.get_closest_point_to_segment(al_bp, tz.a, tz.b).distance_to(al_bp) <= buf_w or Geometry2D.get_closest_point_to_segment(a, tz.a, tz.b).distance_to(a) <= buf_w:
						al_by = maxf(al_by, float(tz.deck_y))
					if Geometry2D.get_closest_point_to_segment(ar_bp, tz.a, tz.b).distance_to(ar_bp) <= buf_w or Geometry2D.get_closest_point_to_segment(a, tz.a, tz.b).distance_to(a) <= buf_w:
						ar_by = maxf(ar_by, float(tz.deck_y))
					if Geometry2D.get_closest_point_to_segment(bl_bp, tz.a, tz.b).distance_to(bl_bp) <= buf_w or Geometry2D.get_closest_point_to_segment(b, tz.a, tz.b).distance_to(b) <= buf_w:
						bl_by = maxf(bl_by, float(tz.deck_y))
					if Geometry2D.get_closest_point_to_segment(br_bp, tz.a, tz.b).distance_to(br_bp) <= buf_w or Geometry2D.get_closest_point_to_segment(b, tz.a, tz.b).distance_to(b) <= buf_w:
						br_by = maxf(br_by, float(tz.deck_y))
				var al_bot := Vector3(al_bp.x, al_by, al_bp.y)
				var ar_bot := Vector3(ar_bp.x, ar_by, ar_bp.y)
				var bl_bot := Vector3(bl_bp.x, bl_by, bl_bp.y)
				var br_bot := Vector3(br_bp.x, br_by, br_bp.y)
				var n_left := Vector3(-side.x * 0.7, 0.7, -side.y * 0.7).normalized()
				var n_right := Vector3(side.x * 0.7, 0.7, side.y * 0.7).normalized()
				rbuf.add_quad(al_bot, al_top, bl_top, bl_bot, emb_col, n_left)
				rbuf.add_quad(ar_top, ar_bot, br_bot, br_top, emb_col, n_right)
			# Schotterbett
			rbuf.add_quad(
				Vector3(a.x - side.x * top_hw, ya + 0.12, a.y - side.y * top_hw),
				Vector3(a.x + side.x * top_hw, ya + 0.12, a.y + side.y * top_hw),
				Vector3(b.x + side.x * top_hw, yb + 0.12, b.y + side.y * top_hw),
				Vector3(b.x - side.x * top_hw, yb + 0.12, b.y - side.y * top_hw),
				Color(0.55, 0.50, 0.46), Vector3.UP)
			# Schwellen (gestrichelt)
			if int(floor((seg_dist + seg_len * 0.5) / 0.7)) % 2 == 0:
				rbuf.add_quad(
					Vector3(a.x - side.x * 1.2, ya + 0.16, a.y - side.y * 1.2),
					Vector3(a.x + side.x * 1.2, ya + 0.16, a.y + side.y * 1.2),
					Vector3(b.x + side.x * 1.2, yb + 0.16, b.y + side.y * 1.2),
					Vector3(b.x - side.x * 1.2, yb + 0.16, b.y - side.y * 1.2),
					Color(0.42, 0.33, 0.27), Vector3.UP)
			# Schienen
			for rail_off: float in [-0.72, 0.72]:
				var p0: Vector2 = a + side * rail_off
				var p1: Vector2 = b + side * rail_off
				rbuf.add_quad(
					Vector3(p0.x - side.x * 0.06, ya + 0.26, p0.y - side.y * 0.06),
					Vector3(p0.x + side.x * 0.06, ya + 0.26, p0.y + side.y * 0.06),
					Vector3(p1.x + side.x * 0.06, yb + 0.26, p1.y + side.y * 0.06),
					Vector3(p1.x - side.x * 0.06, yb + 0.26, p1.y - side.y * 0.06),
					Color(0.75, 0.76, 0.80), Vector3.UP)
			seg_dist += seg_len
	_commit_chunks(rails, group, "Bahn", Toon.material())
	# Brücken bekommen eine eigene Kollision, sonst fällt man ins Tal
	_commit_chunks(bridge_bufs, group, "Bruecke", Toon.material(), true)

	var water := {}
	for w in data.water_lines:
		var line := _resample(w.pts, 3.0)
		_ribbon(water, line, w.width + 1.2, 0.03, Color(0.784, 0.722, 0.580))  # #C8B894 Pale Sand
		_ribbon(water, line, w.width, 0.045, Color(0.251, 0.722, 0.878))       # #40B8E0 Cyan River
	_commit_chunks(water, group, "Bach", Toon.water())


# ------------------------------------------------------------------ Gebäude

## Kleinstes umschließendes Rechteck: {c, u (lange Achse), v, hl, hw, area}
static func _obb(poly: PackedVector2Array) -> Dictionary:
	var hull := Geometry2D.convex_hull(poly)
	var best := {}
	var best_area := INF
	for k in range(hull.size() - 1):
		var e := hull[k + 1] - hull[k]
		if e.length_squared() < 1e-6:
			continue
		var u := e.normalized()
		var v := Vector2(-u.y, u.x)
		var min_u := INF
		var max_u := -INF
		var min_v := INF
		var max_v := -INF
		for p in hull:
			var a := p.dot(u)
			var b := p.dot(v)
			min_u = minf(min_u, a)
			max_u = maxf(max_u, a)
			min_v = minf(min_v, b)
			max_v = maxf(max_v, b)
		var area := (max_u - min_u) * (max_v - min_v)
		if area < best_area:
			best_area = area
			var c := u * (min_u + max_u) * 0.5 + v * (min_v + max_v) * 0.5
			var hl := (max_u - min_u) * 0.5
			var hw := (max_v - min_v) * 0.5
			if hw > hl:
				best = {c = c, u = v, v = -u, hl = hw, hw = hl, area = area}
			else:
				best = {c = c, u = u, v = v, hl = hl, hw = hw, area = area}
	return best


static func _poly_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


func _build_tunnel_tube(bufs: Dictionary, line: PackedVector2Array, road_w: float, tunnel_zones: Array,
		floor_ys := PackedFloat32Array(), deck_top_ys := PackedFloat32Array()) -> void:
	var clear_h := 6.00  # Mindestens 6.0m lichte Durchfahrtshöhe
	var deck_thick := 0.55
	var hw := road_w * 0.5 + 0.95  # Platz für Fahrbahn + Gehsteig/Bankett
	var wall_w := 0.55
	var conc := Color(0.62, 0.62, 0.60)
	var conc_dark := Color(0.46, 0.46, 0.45)
	var conc_wall := Color(0.55, 0.55, 0.53)
	var conc_floor := Color(0.38, 0.38, 0.40)

	var ys := PackedFloat32Array()
	ys.resize(line.size())
	var dys := PackedFloat32Array()
	dys.resize(line.size())
	for k in line.size():
		ys[k] = floor_ys[k] if floor_ys.size() == line.size() else height_at(line[k].x, line[k].y)
		var dt := deck_top_ys[k] if deck_top_ys.size() == line.size() else ys[k] + clear_h + deck_thick
		dys[k] = maxf(ys[k] + clear_h, dt - deck_thick)

	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var dir := (b - a).normalized()
		if dir.length_squared() < 0.001:
			continue
		var side := Vector2(-dir.y, dir.x)
		var mid := (a + b) * 0.5
		var buf := _buf(bufs, mid.x, mid.y)
		var y0 := ys[k - 1]
		var y1 := ys[k]
		var dy0 := dys[k - 1]
		var dy1 := dys[k]
		tunnel_zones.append({a = a, b = b, hw = hw + wall_w + 1.5, clear_hw = hw, wall_hw = hw + wall_w, y0 = y0, y1 = y1, deck_y = maxf(dy0, dy1) + deck_thick})

		# Durchgehende Tunnel-Bodenplatte (mit eigener Kollision über bridge_bufs)
		var fl0 := Vector3(a.x - side.x * hw, y0, a.y - side.y * hw)
		var fr0 := Vector3(a.x + side.x * hw, y0, a.y + side.y * hw)
		var fl1 := Vector3(b.x - side.x * hw, y1, b.y - side.y * hw)
		var fr1 := Vector3(b.x + side.x * hw, y1, b.y + side.y * hw)
		buf.add_quad(fl0, fr0, fr1, fl1, conc_floor, Vector3.UP)

		# Linke & rechte Beton-Stützmauer
		for sgn: float in [-1.0, 1.0]:
			var in_off := sgn * hw
			var out_off := sgn * (hw + wall_w)
			var bi0 := Vector3(a.x + side.x * in_off, y0 - 0.5, a.y + side.y * in_off)
			var bi1 := Vector3(b.x + side.x * in_off, y1 - 0.5, b.y + side.y * in_off)
			var ti0 := Vector3(a.x + side.x * in_off, dy0, a.y + side.y * in_off)
			var ti1 := Vector3(b.x + side.x * in_off, dy1, b.y + side.y * in_off)
			var bo0 := Vector3(a.x + side.x * out_off, y0 - 0.5, a.y + side.y * out_off)
			var bo1 := Vector3(b.x + side.x * out_off, y1 - 0.5, b.y + side.y * out_off)
			var to0 := Vector3(a.x + side.x * out_off, dy0 + deck_thick, a.y + side.y * out_off)
			var to1 := Vector3(b.x + side.x * out_off, dy1 + deck_thick, b.y + side.y * out_off)
			var n_in := Vector3(-side.x * sgn, 0, -side.y * sgn)
			buf.add_quad(bi0, bi1, ti1, ti0, conc_wall, n_in)
			buf.add_quad(bo0, to0, to1, bo1, conc_dark, -n_in)
			buf.add_quad(ti0, ti1, to1, to0, conc, Vector3.UP)

		# Geschlossene Betondecke + Lärmschutzwand-Brüstung oben
		var l_in0 := Vector3(a.x - side.x * hw, dy0, a.y - side.y * hw)
		var r_in0 := Vector3(a.x + side.x * hw, dy0, a.y + side.y * hw)
		var l_in1 := Vector3(b.x - side.x * hw, dy1, b.y - side.y * hw)
		var r_in1 := Vector3(b.x + side.x * hw, dy1, b.y + side.y * hw)
		var l_top0 := l_in0 + Vector3(0, deck_thick, 0)
		var r_top0 := r_in0 + Vector3(0, deck_thick, 0)
		var l_top1 := l_in1 + Vector3(0, deck_thick, 0)
		var r_top1 := r_in1 + Vector3(0, deck_thick, 0)
		buf.add_quad(l_in0, l_in1, r_in1, r_in0, conc_dark, Vector3.DOWN)
		buf.add_quad(l_top0, r_top0, r_top1, l_top1, conc, Vector3.UP)

	# Portale: rot-weißer Höhen-Warnbalken + schräge Flügelmauern
	for idx in [0, line.size() - 1]:
		var ep := line[idx]
		var out_dir := (line[0] - line[1]).normalized() if idx == 0 else (line[-1] - line[-2]).normalized()
		var side := Vector2(-out_dir.y, out_dir.x)
		var ey := ys[idx]
		var edy := dys[idx]
		var pbuf := _buf(bufs, ep.x, ep.y)
		# Rot-weißer Warnstreifen am Portal
		var strips := 6
		for s in strips:
			var f0 := -hw + (2.0 * hw) * float(s) / strips
			var f1 := -hw + (2.0 * hw) * float(s + 1) / strips
			var wcol := Color(0.85, 0.14, 0.14) if s % 2 == 0 else Color(0.95, 0.95, 0.95)
			var p0 := Vector3(ep.x + side.x * f0, edy, ep.y + side.y * f0)
			var p1 := Vector3(ep.x + side.x * f1, edy, ep.y + side.y * f1)
			var p2 := p1 + Vector3(0, 0.32, 0)
			var p3 := p0 + Vector3(0, 0.32, 0)
			pbuf.add_quad(p0, p1, p2, p3, wcol, Vector3(out_dir.x, 0, out_dir.y))
		# Schräge Flügelmauern (4.2m lang, nach außen aufgefächert)
		for sgn: float in [-1.0, 1.0]:
			var w_in := ep + side * (sgn * hw)
			var w_out := ep + out_dir * 4.2 + side * (sgn * (hw + 1.7))
			var wm := (w_in + w_out) * 0.5
			var ob := {c = wm, u = (w_out - w_in).normalized(), v = Vector2(-(w_out - w_in).y, w_out.x - w_in.x).normalized(), hl = w_in.distance_to(w_out) * 0.5, hw = 0.28}
			_box(pbuf, ob, ey - 0.5, ey + 2.6, conc_wall)


func _collect_building_exclusions() -> void:
	_exclusion_rects.clear()
	_flatten_zones.clear()
	var seen_nodes := {}
	var parent := get_parent()
	var overlays := parent.get_node_or_null("WorldOverlays") if parent != null else null
	if overlays != null:
		for child in overlays.get_children():
			if child.name == "MapMarkers":
				_collect_marker_zones(child)
			elif child.name == "Vehicles":
				continue
			elif child.name == "Shops":
				var ts := child.get_node_or_null("Tankstelle") as Node3D
				if ts != null and ts.visible and not seen_nodes.has(ts):
					seen_nodes[ts] = true
					_register_gas_station_zone(ts)
			elif child.name in ["StLeonhardProps", "KleinstadtProps"]:
				for prop in child.get_children():
					if prop is Node3D and not seen_nodes.has(prop):
						seen_nodes[prop] = true
						_register_overlay_node(prop as Node3D)
			elif child is Node3D and not seen_nodes.has(child):
				seen_nodes[child] = true
				_register_overlay_node(child as Node3D)
	else:
		for p in ["res://scenes/world_overlays/st_leonhard_props.tscn", "res://scenes/world_overlays/kleinstadt_props.tscn"]:
			if ResourceLoader.exists(p):
				var packed := ResourceLoader.load(p) as PackedScene
				if packed != null:
					var inst := packed.instantiate()
					if inst != null:
						for prop in inst.get_children():
							if prop is Node3D:
								_register_overlay_node(prop as Node3D)
						inst.free()
	if parent != null:
		var ignored_main := ["World", "Sun", "WorldEnvironment", "EditorWorldPreview", "WorldOverlays", "Orte", "Wild", "Auftraege", "Himmel", "CameraRig", "Spieler", "Pickup", "ATV"]
		for child in parent.get_children():
			if child is Node3D and not child.name in ignored_main and not seen_nodes.has(child):
				if child.name.to_lower().begins_with("flattenzone") or _has_any_mesh(child):
					seen_nodes[child] = true
					_register_overlay_node(child as Node3D)
	_exclusion_rects.sort_custom(func(a, b): return str(a.name) < str(b.name) or (str(a.name) == str(b.name) and a.min_x < b.min_x))
	_flatten_zones.sort_custom(func(a, b): return str(a.name) < str(b.name) or (str(a.name) == str(b.name) and a.min_x < b.min_x))
	var sig_parts: Array[String] = []
	for r in _exclusion_rects:
		sig_parts.append("EX:%s:%.2f,%.2f,%.2f,%.2f" % [r.name, r.min_x, r.max_x, r.min_z, r.max_z])
	for fz in _flatten_zones:
		sig_parts.append("FL:%s:%.2f,%.2f,%.2f,%.2f,%.3f" % [fz.name, fz.min_x, fz.max_x, fz.min_z, fz.max_z, fz.target_y])
	_exclusion_hash = "|".join(sig_parts).sha256_text()


func _has_any_mesh(root_node: Node) -> bool:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			return true
		for ch in n.get_children():
			stack.append(ch)
	return false


func _collect_marker_zones(node: Node) -> void:
	for c in node.get_children():
		if c is Marker3D and c.visible:
			var lname := c.name.to_lower()
			var p := (c as Marker3D).global_position
			if lname.begins_with("clearbuilding"):
				_exclusion_rects.append({
					name = c.name,
					min_x = p.x - 10.0,
					max_x = p.x + 10.0,
					min_z = p.z - 10.0,
					max_z = p.z + 10.0,
				})
			elif lname.begins_with("flattenzone"):
				_flatten_zones.append({
					name = c.name,
					min_x = p.x - 10.0,
					max_x = p.x + 10.0,
					min_z = p.z - 10.0,
					max_z = p.z + 10.0,
					target_y = p.y,
				})
		_collect_marker_zones(c)


func _register_overlay_node(node: Node3D) -> void:
	if not node.visible:
		return
	var bounds := _compute_global_xz_bounds(node)
	var is_flatten_only := node.name.to_lower().begins_with("flattenzone")
	var ex_buf := 3.2
	var flat_buf := 2.0
	if not bounds.valid:
		var p := node.global_position
		if not is_flatten_only:
			_exclusion_rects.append({
				name = node.name,
				min_x = p.x - 10.0,
				max_x = p.x + 10.0,
				min_z = p.z - 10.0,
				max_z = p.z + 10.0,
			})
		_flatten_zones.append({
			name = node.name,
			min_x = p.x - 10.0,
			max_x = p.x + 10.0,
			min_z = p.z - 10.0,
			max_z = p.z + 10.0,
			target_y = p.y,
		})
		print("Overlay building/zone detected: %s pos=(%.2f, %.2f, %.2f) target_y=%.2f (fallback 10m)" % [node.name, p.x, p.y, p.z, p.y])
	else:
		if not is_flatten_only:
			_exclusion_rects.append({
				name = node.name,
				min_x = bounds.min_x - ex_buf,
				max_x = bounds.max_x + ex_buf,
				min_z = bounds.min_z - ex_buf,
				max_z = bounds.max_z + ex_buf,
			})
		_flatten_zones.append({
			name = node.name,
			min_x = bounds.min_x - flat_buf,
			max_x = bounds.max_x + flat_buf,
			min_z = bounds.min_z - flat_buf,
			max_z = bounds.max_z + flat_buf,
			target_y = bounds.min_y,
		})
		print("Overlay building/zone detected: %s xz=[%.1f..%.1f, %.1f..%.1f] target_y=%.2f" % [node.name, bounds.min_x, bounds.max_x, bounds.min_z, bounds.max_z, bounds.min_y])


func _compute_global_xz_bounds(root_node: Node3D) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var min_z := INF
	var max_z := -INF
	var has_mesh := false
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var aabb: AABB = mi.mesh.get_aabb()
				var xf: Transform3D = mi.global_transform
				for ix in 2:
					for iy in 2:
						for iz in 2:
							var corner := Vector3(
								aabb.position.x + aabb.size.x * float(ix),
								aabb.position.y + aabb.size.y * float(iy),
								aabb.position.z + aabb.size.z * float(iz)
							)
							var wp: Vector3 = xf * corner
							min_x = minf(min_x, wp.x)
							max_x = maxf(max_x, wp.x)
							min_y = minf(min_y, wp.y)
							min_z = minf(min_z, wp.z)
							max_z = maxf(max_z, wp.z)
							has_mesh = true
		for ch in n.get_children():
			stack.append(ch)
	return {valid = has_mesh, min_x = min_x, max_x = max_x, min_y = min_y, min_z = min_z, max_z = max_z}


func _register_gas_station_zone(ts: Node3D) -> void:
	var xf := ts.global_transform
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for sx in [-26.09, 26.09]:
		for sz in [-26.09, 26.09]:
			var wp := xf * Vector3(sx, 0.0, sz)
			min_x = minf(min_x, wp.x)
			max_x = maxf(max_x, wp.x)
			min_z = minf(min_z, wp.z)
			max_z = maxf(max_z, wp.z)
	var ex_buf := 4.0
	_exclusion_rects.append({
		name = "Tankstelle",
		min_x = min_x - ex_buf,
		max_x = max_x + ex_buf,
		min_z = min_z - ex_buf,
		max_z = max_z + ex_buf,
	})
	var asphalt_y := ts.global_position.y + 3.8704
	_flatten_zones.append({
		name = "Tankstelle",
		min_x = min_x,
		max_x = max_x,
		min_z = min_z,
		max_z = max_z,
		target_y = asphalt_y,
		falloff = 16.0,
	})
	print("Gas station flatten/exclusion zone: xz=[%.1f..%.1f, %.1f..%.1f] asphalt_y=%.2f falloff=16.0m" % [min_x, max_x, min_z, max_z, asphalt_y])


func _apply_terrain_flattening() -> void:
	if _flatten_zones.is_empty() or heights.is_empty():
		return
	for fz in _flatten_zones:
		var falloff := float(fz.get("falloff", 5.0))
		var i0 := maxi(0, floori((fz.min_x - falloff - x0) / step))
		var i1 := mini(nx - 1, ceili((fz.max_x + falloff - x0) / step))
		var j0 := maxi(0, floori((fz.min_z - falloff - z0) / step))
		var j1 := mini(nz - 1, ceili((fz.max_z + falloff - z0) / step))
		for j in range(j0, j1 + 1):
			var pz := z0 + j * step
			var dz := maxf(fz.min_z - pz, maxf(0.0, pz - fz.max_z))
			for i in range(i0, i1 + 1):
				var px := x0 + i * step
				var dx := maxf(fz.min_x - px, maxf(0.0, px - fz.max_x))
				var dist := sqrt(dx * dx + dz * dz)
				var idx := j * nx + i
				if dist <= 0.0:
					heights[idx] = fz.target_y
				elif dist < falloff:
					var t := dist / falloff
					var w := t * t * (3.0 - 2.0 * t)
					heights[idx] = lerpf(fz.target_y, heights[idx], w)


func _is_point_excluded(x: float, z: float, extra := 0.0) -> bool:
	for r in _exclusion_rects:
		if x >= r.min_x - extra and x <= r.max_x + extra and z >= r.min_z - extra and z <= r.max_z + extra:
			return true
	return false


func _is_building_excluded(center: Vector2, poly: PackedVector2Array) -> bool:
	if _exclusion_rects.is_empty():
		return false
	var bmin_x := INF
	var bmax_x := -INF
	var bmin_z := INF
	var bmax_z := -INF
	for p in poly:
		bmin_x = minf(bmin_x, p.x)
		bmax_x = maxf(bmax_x, p.x)
		bmin_z = minf(bmin_z, p.y)
		bmax_z = maxf(bmax_z, p.y)
	for r in _exclusion_rects:
		if bmax_x < r.min_x or bmin_x > r.max_x or bmax_z < r.min_z or bmin_z > r.max_z:
			continue
		if center.x >= r.min_x and center.x <= r.max_x and center.y >= r.min_z and center.y <= r.max_z:
			return true
		var rpoly := PackedVector2Array([
			Vector2(r.min_x, r.min_z),
			Vector2(r.max_x, r.min_z),
			Vector2(r.max_x, r.max_z),
			Vector2(r.min_x, r.max_z),
		])
		if not Geometry2D.intersect_polygons(poly, rpoly).is_empty():
			return true
	return false


func _build_buildings() -> void:
	var group := _group("Haeuser")
	var walls := {}
	var roofs := {}
	var details := {}
	var skipped_overlay := 0
	for b in data.buildings:
		var poly := to_v2_array(b.pts)
		if poly.size() < 3:
			continue
		var c := Vector2.ZERO
		for p in poly:
			c += p / poly.size()
		if c.x < x0 + 5 or c.y < z0 + 5 or c.x > x0 + (nx - 2) * step or c.y > z0 + (nz - 2) * step:
			continue
		if int(b.id) in SKIP_BUILDINGS:
			continue
		if _is_building_excluded(c, poly):
			skipped_overlay += 1
			continue
		_house(b, poly, _buf(walls, c.x, c.y), _buf(roofs, c.x, c.y), _buf(details, c.x, c.y))
	if skipped_overlay > 0 or not _exclusion_rects.is_empty():
		print("Skipped %d OSM buildings due to overlay replacements (zones=%d)" % [skipped_overlay, _exclusion_rects.size()])
	for k in walls:
		var mesh: ArrayMesh = (walls[k] as MeshBuffer).to_mesh(Toon.material(false))
		(roofs[k] as MeshBuffer).commit(mesh, Toon.material(false, true))
		_mesh_node(group, mesh, "H_%d_%d" % [k.x, k.y], true)
		if not (details[k] as MeshBuffer).is_empty():
			_mesh_node(group, (details[k] as MeshBuffer).to_mesh(Toon.material()), "F_%d_%d" % [k.x, k.y], false, 700.0)


func _house(b: Dictionary, poly: PackedVector2Array, walls: MeshBuffer, roofs: MeshBuffer, det: MeshBuffer) -> void:
	var seed: float = fmod(float(b.id), 100000.0)
	var g_min := INF
	var g_max := -INF
	for p in poly:
		var h := height_at(p.x, p.y)
		g_min = minf(g_min, h)
		g_max = maxf(g_max, h)
	var base := g_min - 0.6
	var ground := g_max
	var top := ground + float(b.wall)
	var levels: int = int(b.get("levels", 2))
	var type: String = b.type
	var dwelling := type in DWELLINGS
	var wall_c: Color = WALL_COLORS[int(hash01(seed) * WALL_COLORS.size())]
	var roof_c: Color = ROOF_COLORS[int(hash01(seed, 3.0) * ROOF_COLORS.size())]
	var plinth_c := Color(0.62, 0.60, 0.57)
	match type:
		"garage", "garages", "carport", "shed", "hut", "roof":
			wall_c = Color(0.82, 0.80, 0.76)
			roof_c = Color(0.40, 0.40, 0.43)
		"barn", "farm_auxiliary", "stable", "cowshed":
			wall_c = WOOD
			roof_c = Color(0.45, 0.30, 0.22)
		"church", "chapel":
			wall_c = Color(0.99, 0.98, 0.94)
			roof_c = Color(0.36, 0.36, 0.40)
		"industrial", "warehouse", "commercial", "retail":
			wall_c = Color(0.80, 0.82, 0.84) if hash01(seed, 9.0) > 0.5 else Color(0.88, 0.84, 0.74)
			roof_c = Color(0.50, 0.52, 0.55)
		"fire_station":
			wall_c = Color(0.95, 0.88, 0.80)
			roof_c = Color(0.70, 0.18, 0.15)

	# Offene Vordächer & Carports (z. B. Tankstellen-Dächer): 4 schlanke Pfeiler + schwebende Dachplatte
	var is_canopy := type in ["roof", "carport", "canopy"]
	if not is_canopy and poly.size() >= 4:
		var c_pts := Vector2.ZERO
		for p in poly:
			c_pts += p / poly.size()
		for poi in data.pois:
			if poi.kind == "fuel" and c_pts.distance_to(Vector2(poi.pos[0], poi.pos[1])) < 18.0 and _poly_area(poly) < 350.0:
				is_canopy = true
				break
	if is_canopy:
		var ob := _obb(poly)
		var roof_y0 := ground + 4.2
		var roof_y1 := roof_y0 + 0.55
		_box(roofs, ob, roof_y0, roof_y1, roof_c)
		var px_off := maxf(0.25, ob.hl - 0.55)
		var pz_off := maxf(0.25, ob.hw - 0.55)
		for sx: float in [-px_off, px_off]:
			for sz: float in [-pz_off, pz_off]:
				var pc: Vector2 = ob.c + ob.u * sx + ob.v * sz
				_box(walls, {c = pc, u = ob.u, v = ob.v, hl = 0.18, hw = 0.18}, base, roof_y0 + 0.05, Color(0.78, 0.80, 0.82))
		return

	# Wände mit dunklerem Sockel
	var longest := -1
	var longest_len := 0.0
	var edges: Array = []
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		var e := q - p
		if e.length_squared() < 1e-4:
			continue
		var n2 := Vector2(e.y, -e.x).normalized()
		if Geometry2D.is_point_in_polygon((p + q) * 0.5 + n2 * 0.05, poly):
			n2 = -n2
		var n := Vector3(n2.x, 0, n2.y)
		var plinth_top := ground + 0.45
		walls.add_quad(Vector3(p.x, base, p.y), Vector3(q.x, base, q.y), Vector3(q.x, plinth_top, q.y), Vector3(p.x, plinth_top, p.y), plinth_c, n)
		walls.add_quad(Vector3(p.x, plinth_top, p.y), Vector3(q.x, plinth_top, q.y), Vector3(q.x, top, q.y), Vector3(p.x, top, p.y), wall_c, n)
		edges.append([p, q, n2])
		if e.length() > longest_len:
			longest_len = e.length()
			longest = edges.size() - 1

	# Fenster, Tür, Fensterläden
	if dwelling and float(b.wall) >= 2.5:
		var shutters := hash01(seed, 5.0) > 0.45
		var shutter_c: Color = SHUTTER_COLORS[int(hash01(seed, 6.0) * SHUTTER_COLORS.size())]
		var floor_h := float(b.wall) / levels
		for ei in edges.size():
			var p: Vector2 = edges[ei][0]
			var q: Vector2 = edges[ei][1]
			var n2: Vector2 = edges[ei][2]
			var len := p.distance_to(q)
			var count := int((len - 0.8) / 3.0)
			if count < 1:
				continue
			var dir := (q - p) / len
			for f in levels:
				var y0 := ground + f * floor_h + 0.95
				if y0 + 1.2 > top - 0.25:
					break
				for w in count:
					var t := (w + 0.5) / count
					var at := p + dir * len * t
					if ei == longest and f == 0 and w == count / 2:
						_door(det, at, dir, n2, ground)
						continue
					_window(det, at, dir, n2, y0, shutters, shutter_c)
		if longest >= 0 and int((longest_len - 0.8) / 3.0) < 1:
			var e: Array = edges[longest]
			_door(det, (e[0] + e[1]) * 0.5, (e[1] - e[0]).normalized(), e[2], ground)
	elif type in ["garage", "garages"] and longest >= 0:
		var e: Array = edges[longest]
		var dir: Vector2 = (e[1] - e[0]).normalized()
		_wall_rect(det, (e[0] + e[1]) * 0.5, dir, e[2], ground + 0.05, minf(2.5, longest_len - 0.6), 2.1, Color(0.72, 0.72, 0.74), 0.04)
	elif type in ["barn", "farm_auxiliary", "stable"] and longest >= 0:
		var e: Array = edges[longest]
		var dir: Vector2 = (e[1] - e[0]).normalized()
		_wall_rect(det, (e[0] + e[1]) * 0.5, dir, e[2], ground + 0.05, minf(3.5, longest_len - 1.0), 3.0, WOOD.darkened(0.35), 0.04)

	# Dach
	var obb := _obb(poly)
	var rect_like := not obb.is_empty() and _poly_area(poly) / maxf(obb.area, 0.01) > 0.72
	var roof: String = b.roof
	if rect_like and roof in ["gabled", "hipped", "half-hipped", "gambrel", "mansard", "skillion", "saltbox"]:
		var hipped := roof == "hipped" or (roof == "gabled" and dwelling and hash01(seed, 8.0) > 0.8)
		_gable_roof(walls, roofs, obb, top, wall_c, roof_c, hipped, hash01(seed, 4.0) > 0.55 and dwelling)
		if dwelling and levels >= 2 and hash01(seed, 2.0) > 0.45 and obb.hl > 3.0:
			_balcony(walls, obb, ground + float(b.wall) / levels, hash01(seed, 7.0) > 0.5)
		if dwelling and hash01(seed, 11.0) > 0.25:
			var cpos: Vector2 = obb.c + obb.u * obb.hl * (hash01(seed, 12.0) - 0.5) * 0.8 + obb.v * obb.hw * 0.35
			var ridge_y: float = top + obb.hw * 0.75
			var cy: float = ridge_y - obb.hw * 0.35 * 0.75
			_box(walls, {c = cpos, u = obb.u, v = obb.v, hl = 0.3, hw = 0.3}, cy - 0.5, ridge_y + 0.7, Color(0.55, 0.30, 0.25))
	elif rect_like and roof == "pyramidal":
		_pyramid_roof(roofs, obb, top, roof_c, obb.hw * 0.9)
	else:
		_flat_roof(roofs, poly, top, roof_c.darkened(0.1) if roof != "flat" else Color(0.55, 0.55, 0.57))

	if type == "church" and not obb.is_empty():
		var u: Vector2 = obb.u
		var ts := minf(obb.hw * 1.6, 5.5)
		var tc: Vector2 = obb.c + u * (obb.hl - ts * 0.5)
		var tower := {c = tc, u = u, v = obb.v, hl = ts * 0.5, hw = ts * 0.5}
		_box(walls, tower, base, top + 13.0, wall_c)
		_pyramid_roof(roofs, tower, top + 13.0, Color(0.30, 0.36, 0.34), 9.0, 0.3)
		# Uhr
		for s in [-1.0, 1.0]:
			var face: Vector2 = tc + obb.v * s * (ts * 0.5)
			_wall_rect(det, face, u, obb.v * s, top + 10.0, 1.6, 1.6, Color(0.95, 0.93, 0.85), 0.05)


## Rechteck flach auf einer Wand (Fenster, Tür, Tor). pos = Mitte unten auf der Wandlinie.
func _wall_rect(buf: MeshBuffer, pos: Vector2, dir: Vector2, n2: Vector2, y0: float, w: float, h: float, color: Color, out: float) -> void:
	var o := pos + n2 * out
	var a := o - dir * w * 0.5
	var b := o + dir * w * 0.5
	buf.add_quad(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y0 + h, b.y), Vector3(a.x, y0 + h, a.y), color, Vector3(n2.x, 0, n2.y))


func _window(buf: MeshBuffer, pos: Vector2, dir: Vector2, n2: Vector2, y0: float, shutters: bool, shutter_c: Color) -> void:
	_wall_rect(buf, pos, dir, n2, y0 - 0.1, 1.15, 1.4, Color(0.98, 0.98, 0.96), 0.03)
	_wall_rect(buf, pos, dir, n2, y0, 0.92, 1.18, Color(0.30, 0.45, 0.62), 0.05)
	_wall_rect(buf, pos, dir, n2, y0 + 0.56, 0.92, 0.06, Color(0.98, 0.98, 0.96), 0.06)  # Sprosse
	if shutters:
		for s in [-1.0, 1.0]:
			_wall_rect(buf, pos + dir * s * 0.82, dir, n2, y0 - 0.08, 0.42, 1.36, shutter_c, 0.04)


func _door(buf: MeshBuffer, pos: Vector2, dir: Vector2, n2: Vector2, ground: float) -> void:
	_wall_rect(buf, pos, dir, n2, ground, 1.35, 2.35, Color(0.96, 0.95, 0.92), 0.03)
	_wall_rect(buf, pos, dir, n2, ground, 1.05, 2.15, Color(0.45, 0.27, 0.15), 0.05)
	_wall_rect(buf, pos + dir * 0.32, dir, n2, ground + 1.0, 0.1, 0.1, Color(0.95, 0.80, 0.30), 0.07)  # Klinke


func _gable_roof(walls: MeshBuffer, roofs: MeshBuffer, o: Dictionary, top: float, wall_c: Color, roof_c: Color,
		hipped: bool, wooden_gable: bool) -> void:
	var c3 := func(p: Vector2, y: float) -> Vector3: return Vector3(p.x, y, p.y)
	var c: Vector2 = o.c
	var u: Vector2 = o.u
	var v: Vector2 = o.v
	var hl: float = o.hl
	var hw: float = o.hw
	var pitch := 0.75  # tan(~37°)
	var rh := hw * pitch
	var ov := 0.6
	var ridge_y := top + rh
	var eave_y := top - ov * pitch
	var under := roof_c.darkened(0.45)
	var fascia := roof_c.darkened(0.25)
	var hip := hw if hipped else 0.0  # Walmdach: First kürzer
	var r0: Vector2 = c - u * (hl + ov - hip)
	var r1: Vector2 = c + u * (hl + ov - hip)
	for s in [-1.0, 1.0]:
		var e0: Vector2 = c - u * (hl + ov) + v * s * (hw + ov)
		var e1: Vector2 = c + u * (hl + ov) + v * s * (hw + ov)
		var n := Vector3(v.x * s, 1.0 / pitch, v.y * s).normalized()
		roofs.add_quad_2s(c3.call(e0, eave_y), c3.call(e1, eave_y), c3.call(r1, ridge_y), c3.call(r0, ridge_y), roof_c, n, under)
		# Dachkante
		walls.add_quad(c3.call(e0, eave_y - 0.2), c3.call(e1, eave_y - 0.2), c3.call(e1, eave_y), c3.call(e0, eave_y), fascia, Vector3(v.x * s, 0, v.y * s))
	for s in [-1.0, 1.0]:
		var n := Vector3(u.x * s, 0, u.y * s)
		if hipped:
			var e0: Vector2 = c + u * s * (hl + ov) - v * (hw + ov)
			var e1: Vector2 = c + u * s * (hl + ov) + v * (hw + ov)
			var r: Vector2 = r1 if s > 0 else r0
			roofs.add_tri(c3.call(e0, eave_y), c3.call(e1, eave_y), c3.call(r, ridge_y), roof_c.darkened(0.06), (n + Vector3.UP * 1.3).normalized())
			roofs.add_tri(c3.call(e0, eave_y), c3.call(e1, eave_y), c3.call(r, ridge_y), under, -(n + Vector3.UP * 1.3).normalized())
		else:
			var g: Vector2 = c + u * s * hl
			walls.add_tri(c3.call(g - v * hw, top), c3.call(g + v * hw, top), c3.call(g, ridge_y), WOOD if wooden_gable else wall_c, n)
			# Giebelseite des Dachüberstands schließen
			var gp: Vector2 = c + u * s * (hl + ov)
			roofs.add_tri(c3.call(gp - v * (hw + ov), eave_y), c3.call(gp + v * (hw + ov), eave_y), c3.call(gp, ridge_y), under, -n)


func _balcony(buf: MeshBuffer, o: Dictionary, y: float, side_pos: bool) -> void:
	var s := 1.0 if side_pos else -1.0
	var u: Vector2 = o.u
	var v: Vector2 = o.v
	var len: float = o.hl * 2.0 * 0.7
	var depth := 1.3
	var c: Vector2 = o.c + v * s * (o.hw + depth * 0.5)
	_box(buf, {c = c, u = u, v = v, hl = len * 0.5, hw = depth * 0.5}, y - 0.2, y, WOOD.darkened(0.15))
	# Geländer aus Holz
	var rail_c := WOOD.lightened(0.05)
	var front: Vector2 = c + v * s * (depth * 0.5 - 0.06)
	_box(buf, {c = front, u = u, v = v, hl = len * 0.5, hw = 0.06}, y, y + 0.95, rail_c)
	for e in [-1.0, 1.0]:
		var sc: Vector2 = c + u * e * (len * 0.5 - 0.06)
		_box(buf, {c = sc, u = u, v = v, hl = 0.06, hw = depth * 0.5}, y, y + 0.95, rail_c)
	# Blumenkasten
	_box(buf, {c = front + v * s * 0.15, u = u, v = v, hl = len * 0.4, hw = 0.12}, y + 0.7, y + 0.95, Color(0.85, 0.20, 0.25))


func _pyramid_roof(roofs: MeshBuffer, o: Dictionary, top: float, roof_c: Color, rh: float, ov := 0.4) -> void:
	var c: Vector2 = o.c
	var u: Vector2 = o.u
	var v: Vector2 = o.v
	var hl: float = o.hl + ov
	var hw: float = o.hw + ov
	var corners := [c - u * hl - v * hw, c + u * hl - v * hw, c + u * hl + v * hw, c - u * hl + v * hw]
	var apex := Vector3(c.x, top + rh, c.y)
	for k in 4:
		var p: Vector2 = corners[k]
		var q: Vector2 = corners[(k + 1) % 4]
		var mid := (p + q) * 0.5 - c
		var n := Vector3(mid.x, 0, mid.y).normalized() + Vector3.UP * 0.6
		roofs.add_tri(Vector3(p.x, top, p.y), Vector3(q.x, top, q.y), apex, roof_c, n)
		roofs.add_tri(Vector3(p.x, top, p.y), Vector3(q.x, top, q.y), apex, roof_c.darkened(0.45), -n)


func _flat_roof(roofs: MeshBuffer, poly: PackedVector2Array, top: float, color: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var a := poly[idx[t]]
		var b := poly[idx[t + 1]]
		var c := poly[idx[t + 2]]
		roofs.add_tri(Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(c.x, top, c.y), color, Vector3.UP)


func _box(buf: MeshBuffer, o: Dictionary, y0: float, y1: float, color: Color) -> void:
	var c: Vector2 = o.c
	var u: Vector2 = o.u * o.hl
	var v: Vector2 = o.v * o.hw
	var pts := [c - u - v, c + u - v, c + u + v, c - u + v]
	for k in 4:
		var p: Vector2 = pts[k]
		var q: Vector2 = pts[(k + 1) % 4]
		var mid := (p + q) * 0.5 - c
		buf.add_quad(Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y1, q.y), Vector3(p.x, y1, p.y), color, Vector3(mid.x, 0, mid.y))
	var top: Array[Vector3] = []
	var bot: Array[Vector3] = []
	for p: Vector2 in pts:
		top.append(Vector3(p.x, y1, p.y))
		bot.append(Vector3(p.x, y0, p.y))
	buf.add_quad(top[0], top[1], top[2], top[3], color, Vector3.UP)
	buf.add_quad(bot[0], bot[1], bot[2], bot[3], color.darkened(0.3), Vector3.DOWN)


# ------------------------------------------------------------------ Bäume

func _tree_meshes() -> Array[ArrayMesh]:
	var pine := _make_pine_mesh("Pine_2.gltf")
	var dec := _make_deciduous_mesh("CommonTree_1.gltf")
	if pine != null and dec != null:
		return [pine, dec]
	var trunk_c := Color(0.45, 0.30, 0.18)
	var fir := MeshBuffer.new()
	_cone(fir, Vector3.ZERO, 0.28, 3.0, 6, trunk_c)
	_cone(fir, Vector3(0, 2.0, 0), 2.4, 4.2, 8, Color(0.13, 0.28, 0.16))
	_cone(fir, Vector3(0, 4.4, 0), 1.9, 3.8, 8, Color(0.15, 0.31, 0.18))
	_cone(fir, Vector3(0, 6.6, 0), 1.3, 3.4, 8, Color(0.17, 0.34, 0.19))
	var leaf := MeshBuffer.new()
	_cone(leaf, Vector3.ZERO, 0.3, 3.4, 6, trunk_c, 0.2)
	_blob(leaf, Vector3(0, 4.6, 0), 2.6, Color(0.28, 0.46, 0.20))
	return [fir.to_mesh(Toon.material()), leaf.to_mesh(Toon.material())]


func _cone(buf: MeshBuffer, base: Vector3, r: float, h: float, sides: int, color: Color, top_r := 0.0) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := base + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := base + Vector3(cos(a1), 0, sin(a1)) * r
		var n := Vector3(cos((a0 + a1) * 0.5), r / h, sin((a0 + a1) * 0.5))
		if top_r <= 0.0:
			buf.add_tri(p0, p1, base + Vector3.UP * h, color, n)
		else:
			var q0 := base + Vector3(cos(a0) * top_r, h, sin(a0) * top_r)
			var q1 := base + Vector3(cos(a1) * top_r, h, sin(a1) * top_r)
			buf.add_quad(p0, p1, q1, q0, color, n)
		buf.add_tri(p0, p1, base, color.darkened(0.3), Vector3.DOWN)


func _blob(buf: MeshBuffer, c: Vector3, r: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 1.7
	mesh.radial_segments = 8
	mesh.rings = 4
	var arr := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]] + c
		var b := v[idx[t + 1]] + c
		var d := v[idx[t + 2]] + c
		var shade := 1.0 - 0.12 * hash01(a.x + b.y, d.z)
		buf.add_tri(a, b, d, Color(color.r * shade, color.g * shade, color.b * shade), (a + b + d) / 3.0 - c)


var _bld_cull_grid := {}  # Vector2i -> Array[{min, max, poly}]


func _index_buildings_cull() -> void:
	if not _bld_cull_grid.is_empty():
		return
	const CELL := 48.0
	var add_poly := func(poly: PackedVector2Array):
		if poly.size() < 3:
			return
		var mn := poly[0]
		var mx := poly[0]
		for p in poly:
			mn = mn.min(p)
			mx = mx.max(p)
		var entry := {min = mn, max = mx, poly = poly}
		var c0 := Vector2i(floori((mn.x - 4.0) / CELL), floori((mn.y - 4.0) / CELL))
		var c1 := Vector2i(floori((mx.x + 4.0) / CELL), floori((mx.y + 4.0) / CELL))
		for cz in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var key := Vector2i(cx, cz)
				if not _bld_cull_grid.has(key):
					_bld_cull_grid[key] = []
				_bld_cull_grid[key].append(entry)
	for b in data.buildings:
		add_poly.call(to_v2_array(b.pts))
	# Platzhalter-Wohnwagen (300.3, 1536.3), 10m x 20m
	add_poly.call(PackedVector2Array([
		Vector2(295.3, 1526.3), Vector2(305.3, 1526.3),
		Vector2(305.3, 1546.3), Vector2(295.3, 1546.3)
	]))


func _near_building(px: float, pz: float, margin := 3.0) -> bool:
	if _bld_cull_grid.is_empty():
		_index_buildings_cull()
	var pt := Vector2(px, pz)
	var m2 := margin * margin
	var key := Vector2i(floori(px / 48.0), floori(pz / 48.0))
	for e: Dictionary in _bld_cull_grid.get(key, []):
		var mn: Vector2 = e.min
		var mx: Vector2 = e.max
		if px < mn.x - margin or px > mx.x + margin or pz < mn.y - margin or pz > mx.y + margin:
			continue
		var poly: PackedVector2Array = e.poly
		if Geometry2D.is_point_in_polygon(pt, poly):
			return true
		if margin > 0.0:
			var n := poly.size()
			for i in n:
				var cp := Geometry2D.get_closest_point_to_segment(pt, poly[i], poly[(i + 1) % n])
				if cp.distance_squared_to(pt) <= m2:
					return true
	return false


func _near_farmland(px: float, pz: float, buf := 1.5) -> bool:
	if kind_at(px, pz) == "farmland":
		return true
	if buf > 0.0:
		for ox: float in [-buf, buf]:
			if kind_at(px + ox, pz) == "farmland" or kind_at(px, pz + ox) == "farmland":
				return true
	return false


func _build_trees() -> void:
	var group := _group("Baeume")
	var meshes := _tree_meshes()
	var t := Marshalls.base64_to_raw(data.trees).to_float32_array()
	var per_chunk := {}  # Vector2i -> [Array fir, Array leaf]
	for k in range(0, t.size(), 4):
		var x := t[k] * MAP_SCALE
		var z := t[k + 1] * MAP_SCALE
		if _near_farmland(x, z, 1.5) or _near_building(x, z, 3.0) or _is_point_excluded(x, z, 1.0):
			continue
		var key := _chunk_key(x, z)
		if not per_chunk.has(key):
			per_chunk[key] = [[], []]
		var s := t[k + 3]
		var basis := Basis(Vector3.UP, hash01(z, x) * TAU).scaled(Vector3(s, s * (0.9 + hash01(x * 3.0) * 0.3), s))
		per_chunk[key][0 if t[k + 2] > 0.5 else 1].append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.2, z)))
	var keys := per_chunk.keys()
	keys.sort()
	for key in keys:
		for which in 2:
			var xfs: Array = per_chunk[key][which]
			if xfs.is_empty():
				continue
			var avg := Vector3.ZERO
			for xf: Transform3D in xfs:
				avg += xf.origin / xfs.size()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = false
			mm.mesh = meshes[which]
			mm.instance_count = xfs.size()
			var local_aabb := AABB(Vector3.ZERO, Vector3.ONE * 0.1)
			for k in xfs.size():
				var xf: Transform3D = xfs[k]
				xf.origin -= avg
				mm.set_instance_transform(k, xf)
				local_aabb = local_aabb.expand(xf.origin)
			local_aabb = local_aabb.grow(15.0)
			mm.custom_aabb = local_aabb
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "B_%d_%d_%d" % [key.x, key.y, which]
			mmi.position = avg
			mmi.multimesh = mm
			mmi.custom_aabb = local_aabb
			mmi.visibility_range_end = 450.0
			mmi.visibility_range_end_margin = 50.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			group.add_child(mmi)


func _debug_log_mesh(label: String, mesh: Mesh) -> void:
	if mesh == null:
		print("DEBUG MESH [%s]: NULL" % label)
		return
	var verts := 0
	var has_tex := false
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
			verts += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var mat := mesh.surface_get_material(s)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			has_tex = true
	print("DEBUG MESH [%s]: surfaces=%d, verts=%d, aabb=%s, has_tex=%s" % [label, mesh.get_surface_count(), verts, mesh.get_aabb().size, has_tex])


func _build_foliage() -> void:
	var group := _group("Foliage")
	var grass_meshes: Array[ArrayMesh] = [
		_make_grass_tuft_mesh("Grass_Common_Short.gltf"),
		_make_grass_tuft_mesh("Grass_Wispy_Short.gltf"),
	]
	var flower_meshes: Array[ArrayMesh] = [
		_make_flower_mesh("Flower_3_Group.gltf"),
		_make_flower_mesh("Flower_4_Group.gltf"),
	]
	var bush_meshes: Array[ArrayMesh] = [
		_load_nature_mesh("Bush_Common.gltf", 1.35, true),
		_load_nature_mesh("Bush_Common_Flowers.gltf", 1.35, true),
		_load_nature_mesh("Fern_1.gltf", 0.75, true),
	]
	var pine_meshes: Array[ArrayMesh] = [
		_make_pine_mesh("Pine_1.gltf"),
		_make_pine_mesh("Pine_3.gltf"),
		_make_pine_mesh("Pine_4.gltf"),
	]
	var dec_meshes: Array[ArrayMesh] = [
		_make_deciduous_mesh("CommonTree_1.gltf"),
		_make_deciduous_mesh("CommonTree_3.gltf"),
	]
	var swamp_meshes: Array[ArrayMesh] = [
		_load_nature_mesh("DeadTree_1.gltf", 10.0, false),
		_load_nature_mesh("TwistedTree_2.gltf", 10.0, true),
	]
	var rock_meshes: Array[ArrayMesh] = [
		_load_nature_mesh("Rock_Medium_1.gltf", 1.6, false),
		_load_nature_mesh("Rock_Medium_2.gltf", 1.9, false),
	]
	_debug_log_mesh("Pine_1.gltf", pine_meshes[0])
	_debug_log_mesh("CommonTree_1.gltf", dec_meshes[0])
	_debug_log_mesh("Grass_Common_Short.gltf", grass_meshes[0])
	_debug_log_mesh("Rock_Medium_1.gltf", rock_meshes[0])

	const T_CHUNK := 450.0
	const F_CHUNK := 280.0
	var max_x := x0 + (nx - 2) * step
	var max_z := z0 + (nz - 2) * step
	var total_grass := 0
	var total_flowers := 0
	var total_bushes := 0
	var total_trees := 0
	var total_rocks := 0
	var total_mmi := 0

	# Grobe Chunks (450m) für Bäume & Felsen -> minimaler Node-Overhead bei voller Sichtweite
	var tcx0 := floori(x0 / T_CHUNK)
	var tcz0 := floori(z0 / T_CHUNK)
	var tcx1 := floori(max_x / T_CHUNK)
	var tcz1 := floori(max_z / T_CHUNK)
	for cz in range(tcz0, tcz1 + 1):
		for cx in range(tcx0, tcx1 + 1):
			var p_buckets: Array = [[], [], []]
			var d_buckets: Array = [[], []]
			var s_buckets: Array = [[], []]
			var r_buckets: Array = [[], []]

			var rng_t := RandomNumberGenerator.new()
			rng_t.seed = _layer_seed(LAYER_TREES, cx, cz)
			for _i in 650:
				var tree_count: int = p_buckets[0].size() + p_buckets[1].size() + p_buckets[2].size() + d_buckets[0].size() + d_buckets[1].size() + s_buckets[0].size() + s_buckets[1].size()
				if tree_count >= 60:
					break
				var px := cx * T_CHUNK + rng_t.randf() * T_CHUNK
				var pz := cz * T_CHUNK + rng_t.randf() * T_CHUNK
				if px < x0 + 5.0 or pz < z0 + 5.0 or px > max_x or pz > max_z:
					continue
				if kind_at(px, pz) in ["water", "parking", "industrial", "cemetery", "farmland"] or _near_farmland(px, pz, 1.5) or slope_at(px, pz) > 0.42:
					continue
				if road_info(Vector2(px, pz), 7.5).tier != 0 or _near_building(px, pz, 3.0) or _is_point_excluded(px, pz, 1.0):
					continue
				var py := height_at(px, pz) - 0.1
				var tsc := rng_t.randf_range(0.85, 1.25)
				var txf := Transform3D(Basis(Vector3.UP, rng_t.randf() * TAU).scaled(Vector3(tsc, tsc, tsc)), Vector3(px, py, pz))
				if is_swamp(Vector2(px, pz)):
					s_buckets[rng_t.randi() % 2].append(txf)
				elif rng_t.randf() < 0.55:
					p_buckets[rng_t.randi() % 3].append(txf)
				else:
					d_buckets[rng_t.randi() % 2].append(txf)
				total_trees += 1

			var rng_r := RandomNumberGenerator.new()
			rng_r.seed = _layer_seed(LAYER_ROCKS, cx, cz)
			for _i in 350:
				if (r_buckets[0].size() + r_buckets[1].size()) >= 40:
					break
				var px := cx * T_CHUNK + rng_r.randf() * T_CHUNK
				var pz := cz * T_CHUNK + rng_r.randf() * T_CHUNK
				if px < x0 + 5.0 or pz < z0 + 5.0 or px > max_x or pz > max_z:
					continue
				if kind_at(px, pz) in ["water", "parking", "industrial", "cemetery", "farmland"] or _near_farmland(px, pz, 1.5) or slope_at(px, pz) > 0.42:
					continue
				if road_info(Vector2(px, pz), 6.5).tier != 0 or _near_building(px, pz, 3.0) or _is_point_excluded(px, pz, 0.5):
					continue
				var py := height_at(px, pz) - 0.1
				var rxf := Transform3D(Basis(Vector3.UP, rng_r.randf() * TAU).scaled(Vector3.ONE * rng_r.randf_range(0.8, 1.4)), Vector3(px, py, pz))
				r_buckets[rng_r.randi() % 2].append(rxf)
				total_rocks += 1

			for i in 2:
				if not d_buckets[i].is_empty():
					_commit_foliage_mm(group, "TD%d_%d_%d" % [i, cx, cz], dec_meshes[i], Array(d_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 620.0)
					total_mmi += 1
				if not s_buckets[i].is_empty():
					_commit_foliage_mm(group, "TS%d_%d_%d" % [i, cx, cz], swamp_meshes[i], Array(s_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 620.0)
					total_mmi += 1
				if not r_buckets[i].is_empty() and rock_meshes[i] != null:
					_commit_foliage_mm(group, "RK%d_%d_%d" % [i, cx, cz], rock_meshes[i], Array(r_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 480.0)
					total_mmi += 1
			for i in 3:
				if not p_buckets[i].is_empty():
					_commit_foliage_mm(group, "TP%d_%d_%d" % [i, cx, cz], pine_meshes[i], Array(p_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 620.0)
					total_mmi += 1

	# Chunks (280m) für Gras, Blumen & Büsche -> ~10x weniger Nodes als 100m-Chunks
	var cx0 := floori(x0 / F_CHUNK)
	var cz0 := floori(z0 / F_CHUNK)
	var cx1 := floori(max_x / F_CHUNK)
	var cz1 := floori(max_z / F_CHUNK)
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var b_buckets: Array = [[], [], []]
			var g_buckets: Array = [[], []]
			var f_buckets: Array = [[], []]

			var rng_b := RandomNumberGenerator.new()
			rng_b.seed = _layer_seed(LAYER_BUSHES, cx, cz)
			for _i in 220:
				if (b_buckets[0].size() + b_buckets[1].size() + b_buckets[2].size()) >= 42:
					break
				var px := cx * F_CHUNK + rng_b.randf() * F_CHUNK
				var pz := cz * F_CHUNK + rng_b.randf() * F_CHUNK
				if px < x0 + 5.0 or pz < z0 + 5.0 or px > max_x or pz > max_z:
					continue
				if kind_at(px, pz) in ["water", "parking", "industrial", "cemetery", "farmland"] or _near_farmland(px, pz, 1.5) or slope_at(px, pz) > 0.42:
					continue
				if road_info(Vector2(px, pz), 6.5).tier != 0 or _near_building(px, pz, 3.0) or _is_point_excluded(px, pz, 0.5):
					continue
				var py := height_at(px, pz)
				var bxf := Transform3D(Basis(Vector3.UP, rng_b.randf() * TAU).scaled(Vector3.ONE * rng_b.randf_range(0.85, 1.25)), Vector3(px, py, pz))
				b_buckets[rng_b.randi() % 3].append(bxf)
				total_bushes += 1

			var rng_g := RandomNumberGenerator.new()
			rng_g.seed = _layer_seed(LAYER_GRASS, cx, cz)
			for _i in 950:
				if (g_buckets[0].size() + g_buckets[1].size()) >= 550:
					break
				var px := cx * F_CHUNK + rng_g.randf() * F_CHUNK
				var pz := cz * F_CHUNK + rng_g.randf() * F_CHUNK
				if px < x0 + 5.0 or pz < z0 + 5.0 or px > max_x or pz > max_z:
					continue
				if kind_at(px, pz) in ["water", "parking", "industrial", "cemetery", "farmland"] or _near_farmland(px, pz, 1.5) or slope_at(px, pz) > 0.42:
					continue
				if road_info(Vector2(px, pz), 5.8).tier != 0 or _near_building(px, pz, 0.8):
					continue
				var py := height_at(px, pz) - 0.04
				var sc := rng_g.randf_range(0.85, 1.45)
				var gxf := Transform3D(Basis(Vector3.UP, rng_g.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(px, py, pz))
				g_buckets[rng_g.randi() % 2].append(gxf)
				total_grass += 1

			var rng_f := RandomNumberGenerator.new()
			rng_f.seed = _layer_seed(LAYER_FLOWERS, cx, cz)
			for _i in 220:
				if (f_buckets[0].size() + f_buckets[1].size()) >= 85:
					break
				var px := cx * F_CHUNK + rng_f.randf() * F_CHUNK
				var pz := cz * F_CHUNK + rng_f.randf() * F_CHUNK
				if px < x0 + 5.0 or pz < z0 + 5.0 or px > max_x or pz > max_z:
					continue
				if kind_at(px, pz) in ["water", "parking", "industrial", "cemetery", "farmland"] or _near_farmland(px, pz, 1.5) or slope_at(px, pz) > 0.42:
					continue
				if road_info(Vector2(px, pz), 5.8).tier != 0 or _near_building(px, pz, 0.8):
					continue
				var py := height_at(px, pz) - 0.02
				var fxf := Transform3D(Basis(Vector3.UP, rng_f.randf() * TAU).scaled(Vector3.ONE * rng_f.randf_range(0.9, 1.3)), Vector3(px, py, pz))
				f_buckets[rng_f.randi() % 2].append(fxf)
				total_flowers += 1

			for i in 2:
				if not g_buckets[i].is_empty():
					_commit_foliage_mm(group, "G%d_%d_%d" % [i, cx, cz], grass_meshes[i], Array(g_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 280.0)
					total_mmi += 1
				if not f_buckets[i].is_empty():
					_commit_foliage_mm(group, "W%d_%d_%d" % [i, cx, cz], flower_meshes[i], Array(f_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 260.0)
					total_mmi += 1
			for i in 3:
				if not b_buckets[i].is_empty() and bush_meshes[i] != null:
					_commit_foliage_mm(group, "BF%d_%d_%d" % [i, cx, cz], bush_meshes[i], Array(b_buckets[i], TYPE_TRANSFORM3D, &"", null), [], 270.0)
					total_mmi += 1
	print("DEBUG FOLIAGE TOTALS: trees=%d, grass=%d, flowers=%d, bushes=%d, rocks=%d | mmi_nodes=%d" % [total_trees, total_grass, total_flowers, total_bushes, total_rocks, total_mmi])


func _make_crop_mesh(is_corn: bool) -> ArrayMesh:
	var buf := MeshBuffer.new()
	if is_corn:
		var stalk_c := Color(0.32, 0.56, 0.16)
		var leaf_c := stalk_c.lightened(0.08)
		var cob_c := Color(0.88, 0.72, 0.22)
		buf.add_quad_2s(Vector3(-0.07, 0.0, 0), Vector3(0.07, 0.0, 0), Vector3(0.04, 1.5, 0), Vector3(-0.04, 1.5, 0), stalk_c, Vector3.BACK, stalk_c)
		buf.add_quad_2s(Vector3(0, 0.0, -0.07), Vector3(0, 0.0, 0.07), Vector3(0, 1.5, 0.04), Vector3(0, 1.5, -0.04), stalk_c, Vector3.RIGHT, stalk_c)
		buf.add_quad_2s(Vector3(-0.24, 0.85, 0), Vector3(0.24, 0.92, 0), Vector3(0.22, 1.02, 0.06), Vector3(-0.22, 0.95, 0.06), leaf_c, Vector3.BACK, leaf_c)
		buf.add_quad_2s(Vector3(0.03, 0.80, -0.05), Vector3(0.11, 0.80, -0.05), Vector3(0.10, 1.02, -0.05), Vector3(0.04, 1.02, -0.05), cob_c, Vector3.BACK, cob_c)
	else:
		var wheat_c := Color(0.82, 0.70, 0.26)
		var stem_c := Color(0.64, 0.56, 0.22)
		for ox: float in [-0.14, 0.0, 0.14]:
			var oz: float = ox * 0.4
			buf.add_quad_2s(Vector3(ox - 0.03, 0.0, oz), Vector3(ox + 0.03, 0.0, oz), Vector3(ox + 0.02, 0.72, oz), Vector3(ox - 0.02, 0.72, oz), stem_c, Vector3.BACK, stem_c)
			buf.add_quad_2s(Vector3(ox - 0.05, 0.68, oz), Vector3(ox + 0.05, 0.68, oz), Vector3(ox + 0.03, 0.88, oz), Vector3(ox - 0.03, 0.88, oz), wheat_c, Vector3.BACK, wheat_c)
	return buf.to_mesh(Toon.material())


func _build_fields() -> void:
	var group := _group("Felder")
	var corn_mesh := _make_crop_mesh(true)
	var wheat_mesh := _make_crop_mesh(false)
	const F_CHUNK := 200.0
	var max_x := x0 + (nx - 1) * step - 5.0
	var max_z := z0 + (nz - 1) * step - 5.0
	var cx0 := floori(x0 / F_CHUNK)
	var cx1 := floori(max_x / F_CHUNK)
	var cz0 := floori(z0 / F_CHUNK)
	var cz1 := floori(max_z / F_CHUNK)
	var total_crops := 0
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var corn_xfs: Array[Transform3D] = []
			var wheat_xfs: Array[Transform3D] = []
			var x_start := maxf(x0 + 6.0, cx * F_CHUNK)
			var x_end := minf(max_x, (cx + 1) * F_CHUNK)
			var z_start := maxf(z0 + 6.0, cz * F_CHUNK)
			var z_end := minf(max_z, (cz + 1) * F_CHUNK)
			var px := x_start
			while px < x_end:
				var pz := z_start
				while pz < z_end:
					if kind_at(px, pz) == "farmland" and slope_at(px, pz) < 0.25:
						if road_info(Vector2(px, pz), 7.0).tier == 0 and not _near_building(px, pz, 3.0):
							var patch := hash01(floorf(px / 120.0), floorf(pz / 120.0))
							var is_corn := patch > 0.55
							var jitter := (hash01(px * 0.7, pz * 0.3) - 0.5) * 0.45
							var py := height_at(px + jitter, pz + jitter)
							var sc := 0.88 + hash01(px * 0.13, pz * 0.29) * 0.28
							var xf := Transform3D(Basis(Vector3.UP, patch * TAU).scaled(Vector3.ONE * sc), Vector3(px + jitter, py, pz + jitter))
							if is_corn:
								corn_xfs.append(xf)
							else:
								wheat_xfs.append(xf)
							total_crops += 1
					pz += 2.8
				px += 2.8
			if not corn_xfs.is_empty():
				_commit_foliage_mm(group, "FD0_%d_%d" % [cx, cz], corn_mesh, corn_xfs, [], 175.0)
			if not wheat_xfs.is_empty():
				_commit_foliage_mm(group, "FD1_%d_%d" % [cx, cz], wheat_mesh, wheat_xfs, [], 175.0)
	print("  Felder-Pflanzen: %d" % total_crops)


func _road_shader_material(is_dirt: bool) -> ShaderMaterial:
	var sh := Shader.new()
	if is_dirt:
		sh.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float edge = min(u, 1.0 - u);
	float grit = n2(vec2(u * 14.0, v * 1.4)) * 0.65 + n2(vec2(u * 42.0, v * 4.5)) * 0.35;
	float rut = exp(-pow((u - 0.32) * 11.0, 2.0)) + exp(-pow((u - 0.68) * 11.0, 2.0));
	float mid_grass = exp(-pow((u - 0.5) * 9.0, 2.0)) * 0.55;
	vec3 base = COLOR.rgb * (0.82 + grit * 0.30);
	base = mix(base, base * vec3(0.75, 0.68, 0.60), clamp(rut * 0.65, 0.0, 0.7));
	base = mix(base, vec3(0.28, 0.42, 0.16), mid_grass * grit);
	// Volle Kern-Fahrbahn (u in [0.15, 0.85]) strikt ALPHA = 1.0; Ausblendung nur im Außen-Bankett
	float alpha = edge >= 0.15 ? 1.0 : smoothstep(0.01, 0.15, edge + (grit - 0.5) * 0.06);
	ALBEDO = base;
	ROUGHNESS = 0.94;
	ALPHA = alpha;
}"""
	else:
		sh.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float edge = min(u, 1.0 - u);
	float grain = n2(vec2(u * 26.0, v * 3.2)) * 0.6 + n2(vec2(u * 75.0, v * 9.0)) * 0.4;
	float tracks = exp(-pow((u - 0.34) * 12.0, 2.0)) + exp(-pow((u - 0.66) * 12.0, 2.0));
	vec3 base = COLOR.rgb * (0.78 + grain * 0.26);
	base = mix(base, base * 0.76, clamp(tracks * 0.45, 0.0, 0.5));
	float dash = step(0.42, fract(v * 0.18));
	float mid_line = step(abs(u - 0.5), 0.015) * dash * (0.65 + 0.35 * grain);
	float side_line = (step(abs(u - 0.185), 0.012) + step(abs(u - 0.815), 0.012)) * 0.55 * grain;
	base = mix(base, vec3(0.88, 0.88, 0.84), clamp(mid_line + side_line, 0.0, 0.88));
	// Außen-Bankett (u < 0.15 / u > 0.85): Kies-Übergang mit weichem Alpha-Fade; Kern strikt ALPHA = 1.0
	vec3 shoulder_col = mix(vec3(0.38, 0.35, 0.29), vec3(0.32, 0.42, 0.18), grain * 0.35);
	base = edge < 0.15 ? mix(shoulder_col, base, smoothstep(0.09, 0.15, edge)) : base;
	float alpha = edge >= 0.15 ? 1.0 : smoothstep(0.01, 0.15, edge + (grain - 0.5) * 0.05);
	ALBEDO = base;
	ROUGHNESS = 0.88 - tracks * 0.08;
	ALPHA = alpha;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


static func _layer_seed(layer_id: int, cx: int, cz: int) -> int:
	return ((layer_id * 73856093) ^ (cx * 19349663) ^ (cz * 83492791) ^ WORLD_SEED) & 0x7FFFFFFF


func _commit_foliage_mm(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array[Transform3D], _cols: Array[Color], vis_end: float) -> void:
	var avg := Vector3.ZERO
	for xf in xfs:
		avg += xf.origin / xfs.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	var local_aabb := AABB(Vector3.ZERO, Vector3.ONE * 0.1)
	for i in xfs.size():
		var xf := xfs[i]
		xf.origin -= avg
		mm.set_instance_transform(i, xf)
		local_aabb = local_aabb.expand(xf.origin)
	local_aabb = local_aabb.grow(15.0)
	mm.custom_aabb = local_aabb
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.position = avg
	mmi.multimesh = mm
	mmi.custom_aabb = local_aabb
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 18.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(mmi)


func _load_nature_mesh(filename: String, target_height: float, foliage_alpha: bool) -> ArrayMesh:
	var fallback := func() -> ArrayMesh:
		return ArrayMesh.new()
	var path := "res://assets/packs/nature_megakit/%s" % filename
	if ResourceLoader.exists(path):
		return AssetLoader.load_mesh(path, target_height, fallback, foliage_alpha) as ArrayMesh
	return null


func _make_pine_mesh(variant := "Pine_1.gltf") -> ArrayMesh:
	var fallback := func() -> ArrayMesh:
		var buf := MeshBuffer.new()
		_cone(buf, Vector3.ZERO, 0.28, 3.2, 6, Color(0.431, 0.231, 0.118))       # #6E3B1E Trunk
		_cone(buf, Vector3(0, 2.2, 0), 2.3, 3.6, 7, Color(0.176, 0.431, 0.133))  # #2D6E22
		_cone(buf, Vector3(0, 4.4, 0), 1.8, 3.4, 7, Color(0.220, 0.490, 0.149))
		_cone(buf, Vector3(0, 6.4, 0), 1.2, 3.0, 7, Color(0.263, 0.549, 0.165))  # #438C2A
		return buf.to_mesh(Toon.material(false))
	var paths: Array[String] = [
		"res://assets/packs/nature_megakit/%s" % variant,
		"res://assets/packs/nature_megakit/Pine_2.gltf",
		"res://assets/nature/Pine_2.gltf",
		"res://assets/models/nature/pine_tree.glb",
	]
	return AssetLoader.load_first_existing_mesh(paths, 14.0, fallback, true) as ArrayMesh


func _make_deciduous_mesh(variant := "CommonTree_1.gltf") -> ArrayMesh:
	var fallback := func() -> ArrayMesh:
		var buf := MeshBuffer.new()
		_cone(buf, Vector3.ZERO, 0.28, 3.6, 6, Color(0.545, 0.353, 0.169), 0.18)  # #8B5A2B Trunk
		_blob(buf, Vector3(0, 4.6, 0), 2.5, Color(0.349, 0.659, 0.157))           # #59A828 Canopy
		_blob(buf, Vector3(0.9, 4.0, 0.6), 1.5, Color(0.388, 0.722, 0.106))
		return buf.to_mesh(Toon.material(false))
	var paths: Array[String] = [
		"res://assets/packs/nature_megakit/%s" % variant,
		"res://assets/packs/nature_megakit/CommonTree_1.gltf",
		"res://assets/nature/CommonTree_1.gltf",
		"res://assets/models/nature/deciduous_tree.glb",
	]
	return AssetLoader.load_first_existing_mesh(paths, 11.5, fallback, true) as ArrayMesh


func _make_grass_tuft_mesh(variant := "Grass_Common_Short.gltf") -> ArrayMesh:
	var fallback := func() -> ArrayMesh:
		var buf := MeshBuffer.new()
		for a in [0.0, 2.1, 4.2]:
			var dir := Vector3(cos(a), 0.0, sin(a))
			var side := Vector3(-dir.z, 0.0, dir.x) * 0.08
			var p0 := -side + dir * 0.04
			var p1 := side + dir * 0.04
			var tip := dir * 0.16 + Vector3(0.0, 0.42, 0.0)
			buf.add_tri(p0, p1, tip, Color.WHITE, Vector3.UP)
			buf.add_tri(p1, p0, tip, Color.WHITE, Vector3.UP)
		return buf.to_mesh(Toon.material(false, true))
	var paths: Array[String] = [
		"res://assets/packs/nature_megakit/%s" % variant,
		"res://assets/packs/nature_megakit/Grass_Common_Short.gltf",
		"res://assets/models/nature/grass_tuft.glb",
	]
	return AssetLoader.load_first_existing_mesh(paths, 0.48, fallback, true) as ArrayMesh


func _make_flower_mesh(variant := "Flower_3_Group.gltf") -> ArrayMesh:
	var fallback := func() -> ArrayMesh:
		var buf := MeshBuffer.new()
		var c := Vector3(0.0, 0.24, 0.0)
		for k in 4:
			var a0 := TAU * k / 4.0
			var a1 := TAU * (k + 1) / 4.0
			var p0 := c + Vector3(cos(a0), 0.04, sin(a0)) * 0.13
			var p1 := c + Vector3(cos(a1), 0.04, sin(a1)) * 0.13
			buf.add_tri(c, p0, p1, Color.WHITE, Vector3.UP)
			buf.add_tri(c, p1, p0, Color.WHITE, Vector3.UP)
		return buf.to_mesh(Toon.material(false, true))
	var paths: Array[String] = [
		"res://assets/packs/nature_megakit/%s" % variant,
		"res://assets/packs/nature_megakit/Flower_3_Group.gltf",
		"res://assets/models/nature/wildflower.glb",
	]
	return AssetLoader.load_first_existing_mesh(paths, 0.38, fallback, true) as ArrayMesh


# ------------------------------------------------------------------ Grenze

const BORDER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.32, 0.22, 1.0);
void fragment() {
	float stripe = step(0.5, fract(UV.x * 0.25 - TIME * 0.15));
	float fade = 1.0 - smoothstep(60.0, 260.0, length(VERTEX));
	ALBEDO = mix(color.rgb, vec3(1.0), stripe * 0.45);
	ALPHA = (1.0 - UV.y) * (0.35 + 0.25 * stripe) * fade;
}
"""


func _build_border() -> void:
	var group := _group("Grenze")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var line := PackedVector2Array(border)
	line.append(border[0])
	var pts := _resample(Array(line).map(func(p): return [p.x, p.y]), 4.0)
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var b := pts[k]
		var d := a.distance_to(b)
		var ya := height_at(a.x, a.y)
		var yb := height_at(b.x, b.y)
		var v := [
			[Vector3(a.x, ya - 1.0, a.y), Vector2(dist, 1.0)], [Vector3(b.x, yb - 1.0, b.y), Vector2(dist + d, 1.0)],
			[Vector3(b.x, yb + 7.0, b.y), Vector2(dist + d, 0.0)], [Vector3(a.x, ya + 7.0, a.y), Vector2(dist, 0.0)],
		]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(v[i][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[i][0])
		dist += d
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BORDER_SHADER
	mat.shader = sh
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	var mi := _mesh_node(group, mesh, "Wand")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Unsichtbare Wände: hohe Kisten entlang jeder Grenzstrecke
	var body := StaticBody3D.new()
	body.name = "GrenzKollision"
	group.add_child(body)
	for k in border.size():
		var a := border[k]
		var b := border[(k + 1) % border.size()]
		var mid := (a + b) * 0.5
		var shape := BoxShape3D.new()
		shape.size = Vector3(a.distance_to(b) + 2.0, 1200.0, 2.0)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(mid.x, height_at(mid.x, mid.y), mid.y)
		cs.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		body.add_child(cs)


# ------------------------------------------------------------------ Beschriftungen

func _label(parent: Node, text: String, pos: Vector3, size: int, color: Color, vis_end: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = 14
	l.pixel_size = 0.0009
	l.modulate = color
	l.outline_modulate = Color(0.12, 0.1, 0.1)
	l.fixed_size = true
	l.position = pos
	l.visibility_range_end = vis_end
	l.visibility_range_end_margin = 40.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(l)


func _build_pois() -> void:
	var group := _group("POIs")
	for poi in data.pois:
		var nm: String = str(poi.get("name", ""))
		if nm not in ["Supermarkt", "Baumarkt"]:
			continue
		var anchor := Node3D.new()
		anchor.name = nm
		var px: float = float(poi.pos[0])
		var pz: float = float(poi.pos[1])
		anchor.position = Vector3(px, height_at(px, pz), pz)
		if poi.has("id"):
			anchor.set_meta("poi_id", str(poi.id))
		if poi.has("category"):
			anchor.set_meta("category", str(poi.category))
		group.add_child(anchor)


func _build_labels() -> void:
	if not show_labels:
		return
	var group := _group("Schilder")
	var seen := {}
	for p in data.pois:
		if seen.has(p.name) or p.kind in ["parking", "bench", "waste_basket", "shelter", "vending_machine", "atm"]:
			continue
		seen[p.name] = true
		_label(group, p.name, Vector3(p.pos[0], height_at(p.pos[0], p.pos[1]) + 14.0, p.pos[1]), 46, Color(1, 0.97, 0.85), 400.0)
	for p in data.places:
		if seen.has(p.name):
			continue
		seen[p.name] = true
		_label(group, p.name, Vector3(p.pos[0], height_at(p.pos[0], p.pos[1]) + 45.0, p.pos[1]), 64, Color(1, 1, 1), 1600.0)
