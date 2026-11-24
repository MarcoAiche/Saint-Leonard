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

const BUILD_VERSION := 5
const CHUNK := 250.0
const C_GRASS := Color(0.40, 0.58, 0.26)
const KIND_COLORS := {
	"grass": Color(0.40, 0.58, 0.26),
	"meadow": Color(0.45, 0.62, 0.28),
	"farmland": Color(0.66, 0.62, 0.36),
	"scrub": Color(0.33, 0.47, 0.24),
	"residential": Color(0.43, 0.58, 0.29),
	"industrial": Color(0.60, 0.58, 0.48),
	"cemetery": Color(0.36, 0.52, 0.28),
	"forest": Color(0.24, 0.36, 0.18),
	"pitch": Color(0.34, 0.58, 0.26),
	"parking": Color(0.50, 0.50, 0.51),
	"water": Color(0.22, 0.42, 0.58),
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
	"track": [3, Color(0.55, 0.45, 0.32), null, false],
	"extreme": [3, Color(0.46, 0.42, 0.38), null, false],
	"cycleway": [2, Color(0.62, 0.42, 0.40), null, false],
	"path": [1, Color(0.72, 0.62, 0.45), null, false],
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


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	if not load_data():
		return
	if not _load_baked():
		build()
		_save_baked()
	print("Welt bereit in %d ms" % (Time.get_ticks_msec() - t0))


func load_data() -> bool:
	var text := FileAccess.get_file_as_string(data_path)
	if text.is_empty():
		push_error("Weltdaten fehlen: %s (node tools/build_world_data.mjs ausführen)" % data_path)
		return false
	data = JSON.parse_string(text)
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
	_index_trees()
	return true


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
		if r.tunnel:
			continue
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
	if OS.get_cmdline_user_args().has("--rebuild") or not ResourceLoader.exists(baked_path):
		return false
	if FileAccess.get_modified_time(baked_path) < FileAccess.get_modified_time(data_path):
		return false
	var scene := load(baked_path) as PackedScene
	if scene == null:
		return false
	var node := scene.instantiate()
	if node.get_meta("version", 0) != BUILD_VERSION:
		node.free()
		return false
	_content = node
	add_child(_content)
	return true


func _save_baked() -> void:
	if OS.has_feature("template"):
		return  # exportiertes Spiel: nichts speichern
	_set_owner_recursive(_content, _content)
	_content.set_meta("version", BUILD_VERSION)
	var scene := PackedScene.new()
	if scene.pack(_content) != OK:
		push_warning("Welt konnte nicht gepackt werden")
		return
	var err := ResourceSaver.save(scene, baked_path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_warning("Welt konnte nicht gespeichert werden: %s" % err)


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


## Nächster Punkt auf einer Straße: {pos, dir, name, kind, dist}
func nearest_road(p: Vector2, kinds_filter: Array = [], max_dist := 200.0) -> Dictionary:
	var best := {dist = INF, name = ""}
	for r in data.roads:
		if r.tunnel or (not kinds_filter.is_empty() and not r.kind in kinds_filter):
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
		["Grenze", _build_border], ["Schilder", _build_labels],
	]
	for s in steps:
		var t := Time.get_ticks_msec()
		s[1].call()
		print("  %s: %d ms" % [s[0], Time.get_ticks_msec() - t])


func _terrain_color(i: int, j: int) -> Color:
	var kind: String = kinds[classes[j * nx + i]]
	var c: Color = KIND_COLORS.get(kind, C_GRASS)
	var x := x0 + i * step
	var z := z0 + j * step
	if kind == "farmland":
		# Ackerstreifen, Richtung je Feld leicht anders
		var a := hash01(floorf(x / 120.0), floorf(z / 120.0)) * PI
		if int(floor((x * cos(a) + z * sin(a)) / 7.0)) % 2 == 0:
			c = c.darkened(0.08)
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
			mesh.surface_set_material(0, Toon.material())
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
			var c := Color(0.50, 0.74, 0.32)
			if abs_h > 1950.0:
				c = Color(0.95, 0.96, 0.98)
			elif abs_h > 1650.0 and n.y < 0.8:
				c = Color(0.62, 0.60, 0.58)
			elif n.y < 0.93 or abs_h > 900.0:
				c = Color(0.22, 0.44, 0.22)
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
	mesh.surface_set_material(0, Toon.material())
	var mi := _mesh_node(_content, mesh, "Berge")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_water() -> void:
	var buf := MeshBuffer.new()
	for poly_arr in data.water_areas:
		var poly := to_v2_array(poly_arr)
		if poly.size() < 3:
			continue
		var idx := Geometry2D.triangulate_polygon(poly)
		for t in range(0, idx.size(), 3):
			var p := [poly[idx[t]], poly[idx[t + 1]], poly[idx[t + 2]]]
			var v: Array[Vector3] = []
			for q: Vector2 in p:
				v.append(Vector3(q.x, height_at(q.x, q.y) + 0.25, q.y))
			buf.add_tri(v[0], v[1], v[2], Color(0.25, 0.55, 0.85), Vector3.UP)
	if not buf.is_empty():
		_mesh_node(_content, buf.to_mesh(Toon.water()), "Gewaesser")


# ------------------------------------------------------------------ Straßen, Bahn, Bäche

func _resample(pts: Array, max_seg := 2.5) -> PackedVector2Array:
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
		offset := 0.0, dash := 0.0, bridge := false, caps := false, sample_width := -1.0) -> void:
	if line.size() < 2:
		return
	var hw := width * 0.5
	# Höhe wird über diese Breite bestimmt (Rand und Belag gleich, sonst schaut der Rand durch)
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
		_buf(bufs, m.x, m.y).add_quad(left[k - 1], right[k - 1], right[k], left[k], color, Vector3.UP)
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
	var roads := {}
	var bridges := MeshBuffer.new()
	var bridge_bufs := {}
	var sorted: Array = data.roads.filter(func(r): return not r.tunnel and ROAD_STYLE.has(r.kind))
	sorted.sort_custom(func(a, b): return ROAD_STYLE[a.kind][0] < ROAD_STYLE[b.kind][0])
	# Erst alle Ränder, dann die Beläge nach Rang: so überdecken sich Kreuzungen sauber
	for r in sorted:
		var style: Array = ROAD_STYLE[r.kind]
		if style[2] == null:
			continue
		var line := _resample(r.pts)
		var target := bridge_bufs if r.bridge else roads
		_ribbon(target, line, r.width + 1.0, 0.04, style[2], 0.0, 0.0, r.bridge, true, r.width)
	for r in sorted:
		var style: Array = ROAD_STYLE["extreme"] if r.tier == TIER_EXTREME else ROAD_STYLE[r.kind]
		if r.kind == "service" and r.tier == TIER_DIRT:
			style = ROAD_STYLE["track"]
		var line := _resample(r.pts)
		var target := bridge_bufs if r.bridge else roads
		var y: float = 0.07 + style[0] * 0.004
		_ribbon(target, line, r.width, y, style[1], 0.0, 0.0, r.bridge, true)
		if style[3]:
			_ribbon(target, line, 0.18, y + 0.012, Color(0.96, 0.96, 0.9), 0.0, 3.0, r.bridge, false, r.width)
	_commit_chunks(roads, group, "S", Toon.material())
	# Brücken bekommen eine eigene Kollision, sonst fällt man ins Tal
	_commit_chunks(bridge_bufs, group, "Bruecke", Toon.material(), true)

	var rails := {}
	for r in data.rails:
		if r.tunnel:
			continue
		var line := _resample(r.pts, 3.0)
		if r.kind == "platform":
			_ribbon(rails, line, r.width, 0.75, Color(0.72, 0.70, 0.66))
			continue
		_ribbon(rails, line, r.width, 0.12, Color(0.55, 0.50, 0.46), 0.0, 0.0, r.bridge)
		_ribbon(rails, line, 2.4, 0.16, Color(0.42, 0.33, 0.27), 0.0, 0.7, r.bridge)  # Schwellen
		for side in [-0.72, 0.72]:
			_ribbon(rails, line, 0.12, 0.26, Color(0.75, 0.76, 0.80), side, 0.0, r.bridge)
	_commit_chunks(rails, group, "Bahn", Toon.material())

	var water := {}
	for w in data.water_lines:
		var line := _resample(w.pts, 3.0)
		_ribbon(water, line, w.width + 1.2, 0.03, Color(0.42, 0.36, 0.26))  # Ufer
		_ribbon(water, line, w.width, 0.045, Color(0.28, 0.58, 0.88))
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


func _build_buildings() -> void:
	var group := _group("Haeuser")
	var walls := {}
	var roofs := {}
	var details := {}
	for b in data.buildings:
		var poly := to_v2_array(b.pts)
		if poly.size() < 3:
			continue
		var c := Vector2.ZERO
		for p in poly:
			c += p / poly.size()
		if c.x < x0 + 5 or c.y < z0 + 5 or c.x > x0 + (nx - 2) * step or c.y > z0 + (nz - 2) * step:
			continue
		_house(b, poly, _buf(walls, c.x, c.y), _buf(roofs, c.x, c.y), _buf(details, c.x, c.y))
	for k in walls:
		var mesh: ArrayMesh = (walls[k] as MeshBuffer).to_mesh(Toon.material(true))
		(roofs[k] as MeshBuffer).commit(mesh, Toon.material(true, true))
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


func _build_trees() -> void:
	var group := _group("Baeume")
	var meshes := _tree_meshes()
	var t := Marshalls.base64_to_raw(data.trees).to_float32_array()
	var per_chunk := {}  # Vector2i -> [Array fir, Array leaf]
	for k in range(0, t.size(), 4):
		var x := t[k]
		var z := t[k + 1]
		var key := _chunk_key(x, z)
		if not per_chunk.has(key):
			per_chunk[key] = [[], []]
		var s := t[k + 3]
		var basis := Basis(Vector3.UP, hash01(z, x) * TAU).scaled(Vector3(s, s * (0.9 + hash01(x * 3.0) * 0.3), s))
		per_chunk[key][0 if t[k + 2] > 0.5 else 1].append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.2, z)))
	for key in per_chunk:
		for which in 2:
			var xfs: Array = per_chunk[key][which]
			if xfs.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = meshes[which]
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, xfs[k])
				var tint := 0.88 + hash01(xfs[k].origin.x, xfs[k].origin.z) * 0.24
				mm.set_instance_color(k, Color(tint, tint, tint * 0.95))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "B_%d_%d_%d" % [key.x, key.y, which]
			mmi.multimesh = mm
			mmi.visibility_range_end = 1300.0
			mmi.visibility_range_end_margin = 100.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			group.add_child(mmi)


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
