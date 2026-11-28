class_name Minimap
extends Control
## Karte, Norden oben. Straßen, Bäche, Häuser und die Spielgrenze kommen aus den Weltdaten.
## full = true: ganze Karte mit Ortsnamen (Taste M, Klick setzt Wegpunkt), sonst kleine Karte um die Spielfigur.
## Zeigt Läden, Tankstelle, Werkstatt, Bauplätze, Mitspieler und den Wegpunkt (Navi).

signal clicked(world_pos: Vector2)

var world: WorldBuilder
var full := false
var center := Vector2.ZERO  # Weltposition (x, z) in der Mitte
var player_pos := Vector2.ZERO
var heading := Vector2(0, 1)
var meters_per_px := 1.6
var waypoint := Vector2.INF
var others: Array = []  # [[Position, Name]]
var show_route := true
var _marks: Array = []  # [Position, Farbe, Kürzel, Name]

var _roads: Array = []  # [PackedVector2Array, Breite, Farbe, Rect2, rank]
var _water: Array = []
var _houses: ArrayMesh
var _pois: Array = []  # [Position, Farbe, Name]
var _border := PackedVector2Array()
var _outside: ArrayMesh
var _fitted := false
var _dragging := false
var _max_mpp := 20.0
const MIN_MPP := 0.25


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
		_roads.append([line, maxf(r.width * 1.6, 3.0), col, _bounds(line), rank])
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
	var lm = w.get_parent().get("landmarks")
	if lm:
		for id in lm.shops:
			var sp: Vector3 = lm.shops[id].door
			_marks.append([Vector2(sp.x, sp.z), Landmarks.SHOP_SIGNS[id][1], Landmarks.SHOP_SIGNS[id][0].left(1), Items.SHOP_NAMES.get(id, "Polizei")])
		_marks.append([Vector2(lm.gas.pos.x, lm.gas.pos.z), Color(0.1, 0.5, 0.25), "T", "Tankstelle"])
		_marks.append([Vector2(lm.garage.pos.x, lm.garage.pos.z), Color(0.25, 0.25, 0.3), "W", "Werkstatt"])
		_marks.append([Vector2(lm.pub.pos.x, lm.pub.pos.z), Color(1, 0.6, 0.1), "G", "Gasthaus Pirtscher"])
		var fh = w.get_parent().get("hall")
		if fh:
			_marks.append([Vector2(fh.global_position.x, fh.global_position.z), Color(0.85, 0.1, 0.1), "F", "Feuerwehrhaus Korpitsch"])
		for pl in lm.plots:
			_marks.append([Vector2(pl.pos.x, pl.pos.z), Color(0.6, 0.45, 0.3), str(pl.idx + 1), ""])
		if lm.caravan_pos != Vector3.ZERO:
			_marks.append([Vector2(lm.caravan_pos.x, lm.caravan_pos.z), Color(0.95, 0.45, 0.85), "C", "Wohnwagen"])
	_border = w.border.duplicate()
	_border.append(w.border[0])
	# Fläche außerhalb der Grenze abdunkeln: großes Rechteck minus Spielgebiet. Damit kein Loch
	# entsteht, wird das Rechteck senkrecht durch das Spielgebiet geteilt (funktioniert auch für
	# lang gezogene Grenzen wie die Erweiterung bis Villach).
	var outside := PackedVector2Array()
	var br := _bounds(w.border)
	var big := br.grow(30000.0)
	var cut := br.get_center().x
	for half in [Rect2(big.position, Vector2(cut - big.position.x, big.size.y)), Rect2(Vector2(cut, big.position.y), Vector2(big.end.x - cut, big.size.y))]:
		var rect := PackedVector2Array([half.position, Vector2(half.end.x, half.position.y), half.end, Vector2(half.position.x, half.end.y)])
		for poly in Geometry2D.clip_polygons(rect, w.border):
			if Geometry2D.is_polygon_clockwise(poly) != Geometry2D.is_polygon_clockwise(rect):
				continue  # Loch (sollte durch die Teilung nicht vorkommen)
			var idx := Geometry2D.triangulate_polygon(poly)
			for i in idx:
				outside.append(poly[i])
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
	if not world:
		return
	var r := _bounds(world.border)
	center = r.get_center()
	meters_per_px = maxf(r.size.x / maxf(size.x - 60.0, 1.0), r.size.y / maxf(size.y - 60.0, 1.0))
	_max_mpp = maxf(meters_per_px * 1.2, 2.0)
	_fitted = true


func zoom_by(factor: float, screen_pos := Vector2.INF) -> void:
	if screen_pos == Vector2.INF:
		screen_pos = size * 0.5
	var world_before := center + (screen_pos - size * 0.5) * meters_per_px
	meters_per_px = clampf(meters_per_px * factor, MIN_MPP, _max_mpp)
	center = world_before - (screen_pos - size * 0.5) * meters_per_px
	queue_redraw()


func center_on_player() -> void:
	center = player_pos
	if meters_per_px > 2.2:
		meters_per_px = 1.6
	queue_redraw()


func zoom_percent() -> int:
	if _max_mpp <= MIN_MPP:
		return 100
	return roundi((_max_mpp / maxf(meters_per_px, MIN_MPP)) * 100.0)


var _redraw_t := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if full and not _fitted and size.x > 10.0:
		fit_border()
	_redraw_t += delta
	if _redraw_t >= 0.15:
		_redraw_t = 0.0
		queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p - center) / meters_per_px


func _gui_input(event: InputEvent) -> void:
	if not full:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(0.82, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.22, event.position)
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if waypoint != Vector2.INF and to_screen(waypoint).distance_to(event.position) < 16.0:
				clicked.emit(Vector2.INF)
			else:
				clicked.emit(center + (event.position - size * 0.5) * meters_per_px)
	elif event is InputEventMouseMotion and _dragging:
		center -= event.relative * meters_per_px
		queue_redraw()


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
		if full and meters_per_px > 2.2 and r.size() > 4 and int(r[4]) < 3:
			continue
		if view.intersects(r[3]):
			draw_polyline(r[0], r[2], maxf(r[1], lw * 2.0))
	draw_mesh(_houses, null, Transform2D(), Color(0.85, 0.45, 0.35))
	draw_mesh(_outside, null, Transform2D(), Color(0.05, 0.08, 0.12, 0.45))
	draw_polyline(_border, Color(0.95, 0.25, 0.2), 3.0 * meters_per_px)
	for p in _pois:
		draw_circle(p[0], (5.0 if full else 9.0) * meters_per_px, p[1])
	draw_set_transform(Vector2.ZERO)

	var font0 := get_theme_default_font()
	for m in _marks:
		var sp := to_screen(m[0])
		if Rect2(Vector2.ZERO, s).grow(10).has_point(sp):
			draw_circle(sp, 9.0, m[1])
			draw_arc(sp, 9.0, 0, TAU, 16, Color(0.1, 0.1, 0.1), 1.5)
			draw_string(font0, sp + Vector2(-4, 5), m[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			if full and not m[3].is_empty():
				draw_string(font0, sp + Vector2(12, 5), m[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.12, 0.1, 0.1))
	for o in others:
		var op := to_screen(o[0])
		draw_circle(op, 6.0, Color(0.2, 0.6, 1.0))
		draw_arc(op, 6.0, 0, TAU, 12, Color.WHITE, 2.0)
		if full:
			draw_string(font0, op + Vector2(9, 5), o[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.2, 0.5))
	if waypoint != Vector2.INF and show_route:
		var wp := to_screen(waypoint)
		var me := to_screen(player_pos)
		var r := Rect2(Vector2.ZERO, s).grow(-12)
		var shown := wp
		if not r.has_point(wp):
			# Pfeil am Rand
			var dir := (wp - me).normalized()
			shown = me + dir * minf(s.x, s.y) * 0.45
		draw_dashed_line(me, shown, Color(0.95, 0.2, 0.6), 3.0, 8.0)
		draw_circle(shown, 7.0, Color(0.95, 0.2, 0.6))

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
