class_name MenuStyle
extends RefCounted
## Gemeinsamer Look für Titelbildschirm, Figur-Editor und Lobby: halbtransparente dunkle Glas-Panels,
## helle Schrift, große farbige Knöpfe.

const GLASS := Color(0.07, 0.10, 0.11, 0.78)
const GLASS_LIGHT := Color(0.14, 0.19, 0.2, 0.86)
const TEAL := Color(0.16, 0.48, 0.47)
const TEXT := Color(0.97, 0.95, 0.9)
const MUTED := Color(0.75, 0.78, 0.76)
const GOLD := Color(0.98, 0.8, 0.32)
const GREEN := Color(0.42, 0.78, 0.3)
const RED := Color(0.86, 0.3, 0.27)
const YELLOW := Color(0.99, 0.84, 0.18)


static func box(c: Color, radius := 14, border := 0, border_c := Color(1, 1, 1, 0.15)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_c
	return s


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	for st in ["font_color", "font_focus_color"]:
		t.set_color(st, "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	var normal := box(Color(1, 1, 1, 0.08), 10, 1)
	normal.set_content_margin_all(10)
	var hover := box(Color(1, 1, 1, 0.18), 10, 2, Color(1, 1, 1, 0.5))
	hover.set_content_margin_all(10)
	var pressed := box(TEAL, 10, 2, Color(1, 1, 1, 0.6))
	pressed.set_content_margin_all(10)
	var disabled := box(Color(1, 1, 1, 0.04), 10)
	disabled.set_content_margin_all(10)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	var line := box(Color(0, 0, 0, 0.35), 8, 1, Color(1, 1, 1, 0.25))
	line.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.45), 8, 2, GOLD))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.4))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_stylebox("panel", "PanelContainer", box(GLASS, 16, 1))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color(1, 1, 1))
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", TEXT)
	t.set_color("font_focus_color", "CheckBox", TEXT)
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(k, "CheckBox", StyleBoxEmpty.new())
	return t


static func label(text: String, size := 19, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## Großer farbiger Knopf (Spielen, Fertig, Abbrechen)
static func big_button(text: String, col: Color, size := 30, text_col := Color(1, 1, 1)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(st, text_col)
	var n := box(col, 14, 3, col.darkened(0.35))
	n.shadow_color = Color(0, 0, 0, 0.35)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 4)
	n.content_margin_left = 34
	n.content_margin_right = 34
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = col.lightened(0.15)
	h.border_color = Color(1, 1, 1, 0.9)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = col.darkened(0.15)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = col.darkened(0.5)
	b.add_theme_stylebox_override("disabled", d)
	return b


static func panel(min_w := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = min_w
	return p


## Helle Kästchen für CheckBoxen auf dunklem Glas (die Standard-Symbole sind dunkel)
static func check_icon(checked: bool) -> ImageTexture:
	var n := 20
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in n:
		for y in n:
			var edge := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			if edge:
				img.set_pixel(x, y, TEXT)
			elif checked:
				img.set_pixel(x, y, Color(0.42, 0.78, 0.3))
	if checked:
		for k in 8:
			for t in 2:
				img.set_pixel(5 + k / 2, 9 + k / 2 + t, Color(1, 1, 1))
				img.set_pixel(9 + k, 13 - k + t, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)
