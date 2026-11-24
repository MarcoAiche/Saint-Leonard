class_name ItemIcons
extends RefCounted
## Zeichnet einfache Symbole für Gegenstände (keine Bilddateien nötig).

static func draw_icon(c: CanvasItem, r: Rect2, id: String) -> void:
	var cx := r.get_center()
	var w := r.size.x
	var h := r.size.y
	var s := minf(w, h)
	var dark := Color(0.08, 0.08, 0.08)
	match id:
		"beer", "schnaps", "moonshine":
			var col: Color = {beer = Color(0.45, 0.28, 0.08), schnaps = Color(0.85, 0.92, 0.95), moonshine = Color(0.95, 0.97, 1.0)}[id]
			var bw := s * 0.42
			var body := Rect2(cx.x - bw * 0.5, r.position.y + h * 0.35, bw, h * 0.6)
			c.draw_rect(body, col)
			c.draw_rect(Rect2(cx.x - bw * 0.18, r.position.y + h * 0.08, bw * 0.36, h * 0.3), col)
			c.draw_rect(Rect2(body.position.x, body.position.y + body.size.y * 0.3, bw, body.size.y * 0.35), Color(0.95, 0.9, 0.7) if id != "moonshine" else Color(0.7, 0.6, 0.4))
			if id == "moonshine":
				c.draw_string(ThemeDB.fallback_font, Vector2(body.position.x + 2, body.position.y + body.size.y * 0.6), "XXX", HORIZONTAL_ALIGNMENT_LEFT, -1, int(bw * 0.4), dark)
		"cigarettes":
			c.draw_rect(Rect2(cx - Vector2(s * 0.3, s * 0.38), Vector2(s * 0.6, s * 0.76)), Color(0.95, 0.95, 0.93))
			c.draw_rect(Rect2(cx - Vector2(s * 0.3, s * 0.38), Vector2(s * 0.6, s * 0.3)), Color(0.8, 0.15, 0.12))
			for k in 3:
				c.draw_rect(Rect2(cx + Vector2(-s * 0.2 + k * s * 0.14, -s * 0.48), Vector2(s * 0.08, s * 0.14)), Color(0.85, 0.6, 0.3))
		"snack":
			c.draw_circle(cx, s * 0.36, Color(0.82, 0.58, 0.28))
			c.draw_rect(Rect2(cx - Vector2(s * 0.34, s * 0.04), Vector2(s * 0.68, s * 0.1)), Color(0.75, 0.3, 0.3))
		"meat", "meat_cooked":
			var mc := Color(0.75, 0.2, 0.2) if id == "meat" else Color(0.55, 0.3, 0.15)
			c.draw_circle(cx + Vector2(-s * 0.08, 0), s * 0.32, mc)
			c.draw_circle(cx + Vector2(s * 0.18, -s * 0.05), s * 0.22, mc)
			c.draw_circle(cx + Vector2(-s * 0.1, -s * 0.05), s * 0.1, Color(0.95, 0.85, 0.8))
		"hide":
			var pts := PackedVector2Array()
			for k in 10:
				var a := TAU * k / 10.0
				var rr := s * (0.42 if k % 2 == 0 else 0.3)
				pts.append(cx + Vector2(cos(a), sin(a)) * rr)
			c.draw_colored_polygon(pts, Color(0.55, 0.38, 0.22))
		"antlers", "legend_antlers", "trophy":
			var ac := Color(0.9, 0.85, 0.7)
			var big := 1.3 if id == "legend_antlers" else 1.0
			for side in [-1, 1]:
				var base := cx + Vector2(side * s * 0.08, s * 0.3)
				var top := cx + Vector2(side * s * 0.35 * big, -s * 0.35)
				c.draw_line(base, top, ac, 3.0)
				for k in 3:
					var p: Vector2 = base.lerp(top, 0.3 + k * 0.25)
					c.draw_line(p, p + Vector2(side * s * 0.12, -s * 0.12), ac, 2.0)
			if id == "trophy":
				c.draw_rect(Rect2(cx + Vector2(-s * 0.15, s * 0.25), Vector2(s * 0.3, s * 0.2)), Color(0.4, 0.25, 0.12))
		"tusks":
			for side in [-1, 1]:
				c.draw_arc(cx + Vector2(side * s * 0.12, 0), s * 0.25, PI * 0.5, PI * 1.3 if side < 0 else -PI * 0.3, 10, Color(0.95, 0.93, 0.85), 3.0)
		"ammo":
			c.draw_rect(Rect2(cx - Vector2(s * 0.4, s * 0.1), Vector2(s * 0.8, s * 0.45)), Color(0.35, 0.45, 0.3))
			for k in 4:
				var x := cx.x - s * 0.3 + k * s * 0.2
				c.draw_rect(Rect2(x - s * 0.05, cx.y - s * 0.42, s * 0.1, s * 0.34), Color(0.85, 0.7, 0.3))
		"sugar", "grain", "yeast", "fruit":
			var col2: Color = {sugar = Color(0.95, 0.95, 0.95), grain = Color(0.8, 0.7, 0.45), yeast = Color(0.9, 0.85, 0.6), fruit = Color(0.85, 0.3, 0.2)}[id]
			if id == "fruit":
				c.draw_rect(Rect2(cx - Vector2(s * 0.4, s * 0.1), Vector2(s * 0.8, s * 0.4)), Color(0.6, 0.45, 0.25))
				for k in 3:
					c.draw_circle(cx + Vector2(-s * 0.22 + k * s * 0.22, -s * 0.12), s * 0.13, col2 if k != 1 else Color(0.9, 0.75, 0.2))
			else:
				c.draw_rect(Rect2(cx - Vector2(s * 0.3, s * 0.4), Vector2(s * 0.6, s * 0.8)), col2)
				c.draw_rect(Rect2(cx - Vector2(s * 0.3, s * 0.05), Vector2(s * 0.6, s * 0.15)), Color(0.3, 0.4, 0.7))
		"jerrycan":
			c.draw_rect(Rect2(cx - Vector2(s * 0.32, s * 0.3), Vector2(s * 0.64, s * 0.7)), Color(0.75, 0.12, 0.1))
			c.draw_rect(Rect2(cx + Vector2(-s * 0.2, -s * 0.42), Vector2(s * 0.25, s * 0.12)), Color(0.75, 0.12, 0.1))
		"rifle":
			c.draw_rect(Rect2(r.position + Vector2(w * 0.05, h * 0.45), Vector2(w * 0.9, h * 0.1)), Color(0.25, 0.25, 0.27))
			c.draw_rect(Rect2(r.position + Vector2(w * 0.55, h * 0.45), Vector2(w * 0.4, h * 0.35)), Color(0.5, 0.3, 0.15))
			c.draw_rect(Rect2(r.position + Vector2(w * 0.35, h * 0.25), Vector2(w * 0.28, h * 0.14)), Color(0.15, 0.15, 0.17))
		"binoculars", "scope8":
			for k in ([-1, 1] if id == "binoculars" else [0]):
				c.draw_rect(Rect2(cx + Vector2(k * s * 0.22 - s * 0.16, -s * 0.2), Vector2(s * 0.32 if id == "binoculars" else s * 0.9, s * 0.4)), Color(0.2, 0.25, 0.2))
		"knife":
			c.draw_rect(Rect2(cx - Vector2(s * 0.45, s * 0.07), Vector2(s * 0.5, s * 0.14)), Color(0.8, 0.8, 0.85))
			c.draw_rect(Rect2(cx + Vector2(s * 0.05, -s * 0.09), Vector2(s * 0.4, s * 0.18)), Color(0.45, 0.28, 0.14))
		"flashlight":
			c.draw_rect(Rect2(cx - Vector2(s * 0.45, s * 0.09), Vector2(s * 0.7, s * 0.18)), Color(0.25, 0.25, 0.28))
			c.draw_rect(Rect2(cx + Vector2(s * 0.25, -s * 0.15), Vector2(s * 0.2, s * 0.3)), Color(0.95, 0.9, 0.5))
		"hunter_hat":
			c.draw_rect(Rect2(cx + Vector2(-s * 0.45, s * 0.1), Vector2(s * 0.9, s * 0.1)), Color(0.25, 0.32, 0.2))
			c.draw_rect(Rect2(cx + Vector2(-s * 0.25, -s * 0.25), Vector2(s * 0.5, s * 0.36)), Color(0.28, 0.35, 0.22))
			c.draw_circle(cx + Vector2(s * 0.28, -s * 0.3), s * 0.1, Color(0.5, 0.42, 0.35))
		"jacket":
			c.draw_rect(Rect2(cx - Vector2(s * 0.3, s * 0.35), Vector2(s * 0.6, s * 0.7)), Color(0.45, 0.30, 0.18))
			c.draw_rect(Rect2(cx - Vector2(s * 0.45, s * 0.35), Vector2(s * 0.15, s * 0.5)), Color(0.45, 0.30, 0.18))
			c.draw_rect(Rect2(cx + Vector2(s * 0.3, -s * 0.35), Vector2(s * 0.15, s * 0.5)), Color(0.45, 0.30, 0.18))
		"crate":
			c.draw_rect(Rect2(cx - Vector2(s * 0.4, s * 0.25), Vector2(s * 0.8, s * 0.55)), Color(0.8, 0.6, 0.15))
			for k in 4:
				c.draw_rect(Rect2(cx + Vector2(-s * 0.32 + k * s * 0.18, -s * 0.42), Vector2(s * 0.1, s * 0.2)), Color(0.35, 0.2, 0.08))
		"straps":
			c.draw_arc(cx, s * 0.32, 0, TAU, 20, Color(0.95, 0.75, 0.1), 4.0)
			c.draw_rect(Rect2(cx + Vector2(s * 0.2, -s * 0.08), Vector2(s * 0.2, s * 0.16)), Color(0.6, 0.6, 0.62))
		"frame":
			c.draw_rect(Rect2(cx - Vector2(s * 0.38, s * 0.3), Vector2(s * 0.76, s * 0.6)), Color(0.4, 0.25, 0.12))
			c.draw_rect(Rect2(cx - Vector2(s * 0.28, s * 0.2), Vector2(s * 0.56, s * 0.4)), Color(0.6, 0.75, 0.9))
		_:
			# Aufstellbares und Möbel: Umriss mit Anfangsbuchstabe
			c.draw_rect(Rect2(cx - Vector2(s * 0.35, s * 0.35), Vector2(s * 0.7, s * 0.7)), Color(0, 0, 0, 0.25))
			c.draw_rect(Rect2(cx - Vector2(s * 0.35, s * 0.35), Vector2(s * 0.7, s * 0.7)), Color(1, 1, 1, 0.5), false, 2.0)
			var letter := Items.display(id).left(1)
			c.draw_string(ThemeDB.fallback_font, cx + Vector2(-s * 0.15, s * 0.18), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.5), Color(1, 1, 1, 0.85))
