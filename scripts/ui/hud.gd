class_name Hud
extends CanvasLayer
## Bedienoberfläche: Ortsanzeige, Minimap, Tacho, Hinweise, Steuerungshilfe und Pausemenü.

signal resume_requested
signal quit_requested

const INK := Color(0.14, 0.11, 0.11)
const PAPER := Color(1.0, 0.97, 0.90, 0.94)
const ACCENT := Color(0.98, 0.78, 0.25)

const HELP_WALK := "[W A S D]  laufen\n[Shift]  rennen\n[Leertaste]  springen\n[F]  ins Auto einsteigen\n[M]  Karte\n[Maus]  umsehen\n[Mausrad]  zoomen\n[F1]  Hilfe ein/aus\n[Esc]  Pause"
const HELP_DRIVE := "[W]  Gas\n[S]  Bremse / Rückwärts\n[A D]  lenken\n[Leertaste]  Handbremse\n[H]  hupen\n[R]  Auto aufstellen\n[F]  aussteigen\n[M]  Karte\n[F1]  Hilfe ein/aus\n[Esc]  Pause"

var minimap: Minimap
var big_map: Minimap
var _map_panel: Control
var _place: Label
var _sub: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _speedo: PanelContainer
var _speed_label: Label
var _speed_bar: ProgressBar
var _help: PanelContainer
var _help_label: Label
var _pause: Control
var _toast: Label
var _toast_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# Ort oben links
	var place_panel := _panel(root)
	_anchor(place_panel, Control.PRESET_TOP_LEFT)
	var vb := VBoxContainer.new()
	place_panel.add_child(vb)
	_place = Label.new()
	_place.add_theme_font_size_override("font_size", 26)
	_place.text = "Riegersdorf"
	vb.add_child(_place)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 16)
	_sub.add_theme_color_override("font_color", INK.lightened(0.3))
	vb.add_child(_sub)

	# Minimap und Steuerungshilfe oben rechts
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	_anchor(right, Control.PRESET_TOP_RIGHT)
	var map_panel := _panel(right)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(210, 210)
	map_panel.add_child(minimap)
	_help = _panel(right)
	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 15)
	_help.add_child(_help_label)

	# Hinweis unten Mitte
	_prompt = _panel(root, ACCENT)
	_anchor(_prompt, Control.PRESET_CENTER_BOTTOM, 40)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt.add_child(_prompt_label)
	_prompt.visible = false

	# Kurze Meldung oben Mitte
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", INK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)
	_anchor(_toast, Control.PRESET_CENTER_TOP, 30)

	# Tacho unten rechts
	_speedo = _panel(root)
	_speedo.custom_minimum_size = Vector2(190, 0)
	var sv := VBoxContainer.new()
	_speedo.add_child(sv)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	sv.add_child(row)
	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 52)
	_speed_label.text = "0"
	row.add_child(_speed_label)
	var unit := Label.new()
	unit.text = " km/h"
	unit.add_theme_font_size_override("font_size", 18)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit)
	_speed_bar = ProgressBar.new()
	_speed_bar.max_value = 130
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size.y = 12
	sv.add_child(_speed_bar)
	_anchor(_speedo, Control.PRESET_BOTTOM_RIGHT)
	_speedo.visible = false

	# Große Karte (M)
	_map_panel = ColorRect.new()
	(_map_panel as ColorRect).color = Color(0.05, 0.08, 0.15, 0.5)
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.visible = false
	root.add_child(_map_panel)
	var frame := _panel(_map_panel)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 80
	frame.offset_top = 60
	frame.offset_right = -80
	frame.offset_bottom = -60
	var mv := VBoxContainer.new()
	frame.add_child(mv)
	var mt := Label.new()
	mt.text = "Karte  (M zum Schließen)"
	mt.add_theme_font_size_override("font_size", 22)
	mv.add_child(mt)
	big_map = Minimap.new()
	big_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(big_map)

	_build_pause(root)
	set_driving(false)


## Verankert ein Element an einer Bildschirmecke; es wächst von dort nach innen.
static func _anchor(c: Control, preset: Control.LayoutPreset, margin := 20) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	match preset:
		Control.PRESET_TOP_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH


func _panel(parent: Control, bg := PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(bg))
	parent.add_child(p)
	return p


static func _style(bg: Color, border := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", INK)
	t.set_stylebox("normal", "Button", _style(PAPER))
	t.set_stylebox("hover", "Button", _style(ACCENT))
	t.set_stylebox("pressed", "Button", _style(ACCENT.darkened(0.15)))
	t.set_stylebox("focus", "Button", _style(ACCENT))
	var bar_bg := _style(Color(0.85, 0.82, 0.75), 2)
	bar_bg.set_content_margin_all(0)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := _style(Color(0.35, 0.75, 0.35), 0)
	bar_fill.set_content_margin_all(0)
	bar_fill.set_corner_radius_all(6)
	bar_fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


func _build_pause(root: Control) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.05, 0.08, 0.15, 0.45)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var box := _panel(_pause)
	box.custom_minimum_size = Vector2(320, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var title := Label.new()
	title.text = "Saint-Leonard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)
	var buttons := [
		["Weiterspielen", func(): resume_requested.emit()],
		["Steuerung ein/aus", func(): toggle_help()],
		["Beenden", func(): quit_requested.emit()],
	]
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		btn.pressed.connect(func(): Sfx.play_2d(self, Sfx.click(), -6.0))
		vb.add_child(btn)
	_anchor(box, Control.PRESET_CENTER, 0)


# ------------------------------------------------------------------ von außen

func set_driving(on: bool) -> void:
	_speedo.visible = on
	_help_label.text = HELP_DRIVE if on else HELP_WALK
	minimap.meters_per_px = 2.6 if on else 1.4


func set_place(title: String, sub: String, warn := false) -> void:
	_place.text = title
	_sub.text = sub
	_sub.visible = not sub.is_empty()
	_sub.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1) if warn else INK.lightened(0.3))


func toggle_map() -> void:
	_map_panel.visible = not _map_panel.visible
	Sfx.play_2d(self, Sfx.click(), -8.0)


func set_prompt(text: String) -> void:
	_prompt.visible = not text.is_empty()
	_prompt_label.text = text


func set_speed(kmh: float) -> void:
	_speed_label.text = str(roundi(absf(kmh)))
	_speed_bar.value = absf(kmh)


func toast(text: String, seconds := 2.5) -> void:
	_toast.text = text
	_toast_time = seconds
	_toast.modulate.a = 1.0


func toggle_help() -> void:
	_help.visible = not _help.visible


func show_pause(on: bool) -> void:
	_pause.visible = on


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
