class_name Minimap
extends Control
## Karte, Norden oben. Straßen, Bäche, Häuser und die Spielgrenze kommen aus den Weltdaten.
## full = true: ganze Karte mit Ortsnamen (Taste M), sonst kleine Karte um die Spielfigur.

var world: WorldBuilder
var full := false
var center := Vector2.ZERO  # Weltposition (x, z) in der Mitte
var player_pos := Vector2.ZERO
var heading := Vector2(0, 1)
var meters_per_px := 1.6

var _roads: Array = []  # [PackedVector2Array, Breite, Farbe, Rect2]
var _water: Array = []
var _houses: ArrayMesh
var _pois: Array = []  # [Position, Farbe, Name]
var _border := PackedVector2Array()
var _outside: ArrayMesh


func setup(w: WorldBuilder, full_map := false) -> void:
	world = w
	full = full_map
	clip_contents = true
	for r in w.data.roads:
		if r.tunnel or not WorldBuilder.ROAD_STYLE.has(r.kind):
			continue
		var line := WorldBuilder.to_v2_array(r.pts)
		var col: Color = WorldBuilder.ROAD_STYLE[r.kind][1].lightened(0.35)
		var rank: int = WorldBuilder.ROAD_STYLE[r.kind][0]
		if full and rank < 3:
			continue
		_roads.append([line, maxf(r.width * 1.6, 3.0), col, _bounds(line)])
	for r in w.data.rails:
		if r.kind == "rail" and not r.tunnel:
			var line := WorldBuilder.to_v2_array(r.pts)
			_roads.append([line, 3.0, Color(0.45, 0.35, 0.3), _bounds(line)])
	for wl in w.data.water_lines:
		var line := WorldBuilder.to_v2_array(wl.pts)
		_water.append([line, maxf(wl.width, 4.0), _bounds(line)])
	var verts := PackedVector2Array()
	for b in w.data.buildings:
		var poly := WorldBuilder.to_v2_array(b.pts)
		for i in Geometry2D.triangulate_polygon(poly):
			verts.append(poly[i])
	_houses = _mesh(verts)
	for p in w.data.pois:
		var col := Color(1, 0.6, 0.1) if p.kind in ["pub", "restaurant", "bar", "cafe"] else Color(0.95, 0.2, 0.15) if p.kind == "fire_station" else Color.TRANSPARENT
		if col.a > 0:
			_pois.append([Vector2(p.pos[0], p.pos[1]), col, p.name])
	_border = w.border.duplicate()
	_border.append(w.border[0])
	# Fläche außerhalb der Grenze abdunkeln: Ring aus Streifen von der Grenze nach außen
	var outside := PackedVector2Array()
	var c := Vector2.ZERO
	for p in w.border:
		c += p / w.border.size()
	for k in w.border.size():
		var a := w.border[k]
		var b := w.border[(k + 1) % w.border.size()]
		var fa := a + (a - c).normalized() * 30000.0
		var fb := b + (b - c).normalized() * 30000.0
		outside.append_array([a, b, fb, a, fb, fa])
	_outside = _mesh(outside)


static func _bounds(line: PackedVector2Array) -> Rect2:
	var r := Rect2(line[0], Vector2.ZERO)
	for p in line:
		r = r.expand(p)
	return r


static func _mesh(verts: PackedVector2Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Ganze Spielgrenze passend einpassen
func fit_border() -> void:
	var r := _bounds(world.border)
	center = r.get_center()
	meters_per_px = maxf(r.size.x / maxf(size.x - 60.0, 1.0), r.size.y / maxf(size.y - 60.0, 1.0))


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		if full:
			fit_border()
		queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p - center) / meters_per_px


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.55, 0.78, 0.40))
	if not world:
		return
	var k := 1.0 / meters_per_px
	draw_set_transform(s * 0.5 - center * k, 0.0, Vector2(k, k))
	var view := Rect2(center - s * 0.5 * meters_per_px, s * meters_per_px).grow(20.0)
	var lw := 1.0 if not full else meters_per_px * 0.6
	for wl in _water:
		if view.intersects(wl[2]):
			draw_polyline(wl[0], Color(0.3, 0.6, 0.95), maxf(wl[1], lw * 3.0))
	for r in _roads:
		if view.intersects(r[3]):
			draw_polyline(r[0], r[2], maxf(r[1], lw * 2.0))
	draw_mesh(_houses, null, Transform2D(), Color(0.85, 0.45, 0.35))
	draw_mesh(_outside, null, Transform2D(), Color(0.05, 0.08, 0.12, 0.45))
	draw_polyline(_border, Color(0.95, 0.25, 0.2), 3.0 * meters_per_px)
	for p in _pois:
		draw_circle(p[0], (5.0 if full else 9.0) * meters_per_px, p[1])
	draw_set_transform(Vector2.ZERO)

	var font := get_theme_default_font()
	if full:
		for pl in world.data.places:
			var sp := to_screen(Vector2(pl.pos[0], pl.pos[1]))
			if Rect2(Vector2.ZERO, s).has_point(sp):
				draw_string_outline(font, sp + Vector2(-40, 0), pl.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(1, 1, 1, 0.9))
				draw_string(font, sp + Vector2(-40, 0), pl.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.12, 0.1, 0.1))
		for p in _pois:
			var sp := to_screen(p[0])
			draw_string(font, sp + Vector2(8, 5), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.12, 0.1, 0.1))

	# Pfeil für die Spielfigur
	var c := to_screen(player_pos)
	var f := heading.normalized() if heading.length() > 0.01 else Vector2(0, 1)
	var r := Vector2(-f.y, f.x)
	var sc := 1.3 if full else 1.0
	var tip := c + f * 11.0 * sc
	var pts := PackedVector2Array([tip, c - f * 7.0 * sc + r * 8.0 * sc, c - f * 3.0 * sc, c - f * 7.0 * sc - r * 8.0 * sc])
	draw_colored_polygon(pts, Color(1, 0.95, 0.3))
	pts.append(tip)
	draw_polyline(pts, Color(0.12, 0.1, 0.1), 2.0)
	draw_string(font, Vector2(s.x * 0.5 - 6, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.12, 0.1, 0.1))
