extends Node
## Entwickler-Werkzeug: zeichnet Titel-Logo und Spielsymbol und speichert sie als Bilder.
##   godot --path . res://tools/make_logo.tscn
## Ergebnis: assets/ui/logo.png (Titelbildschirm), assets/ui/icon.png (512 px),
## assets/ui/icon.ico (Windows-Exe). Schrift: Book Antiqua / Georgia (nur beim Erzeugen nötig).

const CREAM := Color(0.97, 0.92, 0.80)
const GOLD := Color(0.80, 0.60, 0.20)
const DARK := Color(0.17, 0.10, 0.06)

var font: SystemFont


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Book Antiqua", "Palatino Linotype", "Georgia", "Cambria", "serif"])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	await _render(Vector2i(1600, 760), _draw_logo, "res://assets/ui/logo.png")
	var icon := await _render(Vector2i(512, 512), _draw_icon, "res://assets/ui/icon.png")
	var small := icon.duplicate() as Image
	small.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	_save_ico(small, "res://assets/ui/icon.ico")
	print("Logo und Symbol gespeichert")
	get_tree().quit()


func _render(sz: Vector2i, painter: Callable, path: String) -> Image:
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var canvas := Control.new()
	canvas.size = Vector2(sz)
	canvas.draw.connect(func(): painter.call(canvas))
	vp.add_child(canvas)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	vp.queue_free()
	return img


# ------------------------------------------------------------------ Logo

func _draw_logo(c: Control) -> void:
	var w := c.size.x
	_antlers(c, Vector2(w * 0.5, 238), 0.7, true)
	_spaced(c, "SAINT", Vector2(w * 0.5, 368), 92, 26.0)
	_title(c, "LEONARD", Vector2(w * 0.5, 560), 236)
	# Band mit Untertitel
	var y := 628.0
	var half := 330.0
	for s in [-1, 1]:
		c.draw_line(Vector2(w * 0.5 + s * half, y), Vector2(w * 0.5 + s * 560, y), DARK, 9.0, true)
		c.draw_line(Vector2(w * 0.5 + s * half, y), Vector2(w * 0.5 + s * 560, y), GOLD, 4.0, true)
		_diamond(c, Vector2(w * 0.5 + s * 572, y), 12.0)
	_spaced(c, "EIN DORF IN KÄRNTEN", Vector2(w * 0.5, y + 15), 40, 7.0, 10)


## Großer Titel mit Schatten, dunkler und goldener Kontur
func _title(c: Control, text: String, center: Vector2, size: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(center.x - tw * 0.5, center.y)
	c.draw_string_outline(font, p + Vector2(8, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 30, Color(0, 0, 0, 0.35))
	c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 30, DARK)
	c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, GOLD)
	c.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CREAM)
	# Glanz: obere Hälfte heller
	c.draw_string(font, p + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.18))


## Text mit Buchstabenabstand, mittig
func _spaced(c: Control, text: String, center: Vector2, size: int, spacing: float, outline := 16) -> void:
	var total := 0.0
	for ch in text:
		total += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	total -= spacing
	var x := center.x - total * 0.5
	for ch in text:
		var p := Vector2(x, center.y)
		c.draw_string_outline(font, p + Vector2(4, 5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.3))
		c.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, DARK)
		c.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(outline / 3, 3), GOLD)
		c.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CREAM)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing


func _diamond(c: Control, p: Vector2, r: float) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	var big := PackedVector2Array()
	for q in pts:
		big.append(p + (q - p) * 1.6)
	c.draw_colored_polygon(big, DARK)
	c.draw_colored_polygon(pts, GOLD)


## Hirschgeweih (beide Stangen), Wurzel bei base
func _antlers(c: Control, base: Vector2, s: float, with_skull: bool) -> void:
	var layers := [[DARK, 1.0], [GOLD, 0.72], [CREAM, 0.45]]
	for layer in layers:
		for side in [-1, 1]:
			_antler(c, base, side, s, layer[0], layer[1])
	if with_skull:
		# kleiner Stirnschild zwischen den Stangen
		var r := 26.0 * s
		var pts := PackedVector2Array([base + Vector2(-r, -r * 0.6), base + Vector2(r, -r * 0.6), base + Vector2(r * 0.55, r * 0.9), base + Vector2(0, r * 1.5), base + Vector2(-r * 0.55, r * 0.9)])
		var outer := PackedVector2Array()
		for q in pts:
			outer.append(base + (q - base) * 1.35)
		c.draw_colored_polygon(outer, DARK)
		c.draw_colored_polygon(pts, GOLD)


func _antler(c: Control, base: Vector2, side: int, s: float, col: Color, wf: float) -> void:
	var beam := [Vector2(18, -10), Vector2(85, -55), Vector2(150, -125), Vector2(190, -205), Vector2(200, -275)]
	var tines := [[1, Vector2(70, -140)], [2, Vector2(110, -215)], [3, Vector2(150, -285)], [4, Vector2(255, -300)], [4, Vector2(180, -330)]]
	var pts := PackedVector2Array()
	for q in beam:
		pts.append(base + Vector2(q.x * side, q.y) * s)
	var widths := [40.0, 34.0, 28.0, 23.0, 19.0]
	for k in range(pts.size() - 1):
		c.draw_line(pts[k], pts[k + 1], col, widths[k] * wf * s, true)
		c.draw_circle(pts[k + 1], widths[k] * wf * s * 0.5, col)
	c.draw_circle(pts[0], widths[0] * wf * s * 0.5, col)
	for t in tines:
		var from: Vector2 = pts[t[0]]
		var to: Vector2 = base + Vector2(t[1].x * side, t[1].y) * s
		var mid := from.lerp(to, 0.5) + Vector2(-8 * side, 0) * s
		c.draw_line(from, mid, col, 20.0 * wf * s, true)
		c.draw_circle(mid, 10.0 * wf * s, col)
		c.draw_line(mid, to, col, 14.0 * wf * s, true)
		c.draw_circle(to, 7.0 * wf * s, col)


# ------------------------------------------------------------------ Spielsymbol

func _draw_icon(c: Control) -> void:
	var sz := c.size.x
	var r := sz * 0.18
	# abgerundetes Quadrat mit Abendhimmel-Verlauf
	var rect := _rounded(Rect2(8, 8, sz - 16, sz - 16), r)
	var cols := PackedColorArray()
	for q in rect:
		var t := q.y / sz
		cols.append(Color(0.98, 0.70, 0.36).lerp(Color(0.36, 0.24, 0.42), t))
	c.draw_polygon(rect, cols)
	# Sonne
	c.draw_circle(Vector2(sz * 0.5, sz * 0.6), sz * 0.2, Color(1.0, 0.86, 0.55, 0.9))
	# Berge
	var far := PackedVector2Array([Vector2(8, sz * 0.72), Vector2(sz * 0.2, sz * 0.52), Vector2(sz * 0.36, sz * 0.64), Vector2(sz * 0.55, sz * 0.46), Vector2(sz * 0.78, sz * 0.62), Vector2(sz - 8, sz * 0.5), Vector2(sz - 8, sz - 8), Vector2(8, sz - 8)])
	c.draw_colored_polygon(_clip(far, rect), Color(0.33, 0.30, 0.42))
	var near := PackedVector2Array([Vector2(8, sz * 0.82), Vector2(sz * 0.3, sz * 0.7), Vector2(sz * 0.6, sz * 0.8), Vector2(sz - 8, sz * 0.68), Vector2(sz - 8, sz - 8), Vector2(8, sz - 8)])
	c.draw_colored_polygon(_clip(near, rect), Color(0.17, 0.24, 0.18))
	# Geweih
	_antlers(c, Vector2(sz * 0.5, sz * 0.74), 0.72, true)
	# Rand
	var ring := rect.duplicate()
	ring.append(rect[0])
	c.draw_polyline(ring, DARK, 10.0, true)


func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(r.size.x - rad, rad), -PI / 2], [r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI / 2], [r.position + Vector2(rad, rad), PI]]
	for cc in corners:
		for k in 9:
			var a: float = cc[1] + k * (PI / 2) / 8.0
			pts.append(cc[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _clip(poly: PackedVector2Array, to: PackedVector2Array) -> PackedVector2Array:
	var res := Geometry2D.intersect_polygons(poly, to)
	return res[0] if not res.is_empty() else poly


## ICO-Datei mit eingebettetem PNG (Windows Vista und neuer)
func _save_ico(img: Image, path: String) -> void:
	var png := img.save_png_to_buffer()
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_16(0)
	f.store_16(1)
	f.store_16(1)
	f.store_8(0)  # 256
	f.store_8(0)
	f.store_8(0)
	f.store_8(0)
	f.store_16(1)
	f.store_16(32)
	f.store_32(png.size())
	f.store_32(22)
	f.store_buffer(png)
	f.close()
