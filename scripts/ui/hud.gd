class_name Hud
extends CanvasLayer
## Bedienoberfläche: Ort, Uhrzeit und Wetter, Geld, Gesundheit/Ausdauer/Promille, Munition,
## Minimap (N ein/aus), Fadenkreuz, Zielfernrohr- und Fernglas-Ansicht, Tacho mit Tank und Schaden,
## Hinweise, Polizei-Warnung, Dialoge, Fortschrittsbalken, Steuerungshilfe, Pausemenü, große Karte.
## Fenster (Laden, Werkstatt, Inventar, Handy ...) liegen in "menu_root" und werden von Menus gebaut.

signal resume_requested
signal quit_requested
signal save_requested
signal menu_requested

const INK := Color(0.14, 0.11, 0.11)
const PAPER := Color(1.0, 0.97, 0.90, 0.94)
const ACCENT := Color(0.98, 0.78, 0.25)
const RED := Color(0.85, 0.15, 0.1)

const HELP_WALK := "[W A S D]  laufen   [Shift] rennen   [C] ducken\n[Maus links] schießen   [rechts] zielen\n[1-4] Waffen  [5] Fernglas  [6] nichts  [R] laden\n[L] Taschenlampe   [V] Ansicht\n[F] benutzen / einsteigen / tragen\n[I] Inventar   [P] Handy   [M] Karte\n[Z] rauchen   [X] trinken   [N] Minimap\n[F1] Hilfe   [Esc] Pause"
const HELP_DRIVE := "[W] Gas   [S] Bremse/Rückwärts   [A D] lenken\n[Leertaste] Handbremse   [H] hupen\n[L] Licht   [K] Radio   [T] Seilwinde\n[R] aufstellen   [V] Ansicht\n[F] aussteigen   [G] Ladefläche\n[M] Karte   [P] Handy   [F1] Hilfe"

var minimap: Minimap
var big_map: Minimap
var menu_root: Control
var root: Control
var _map_panel: Control
var _place: Label
var _sub: Label
var _clock: Label
var _money: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _speedo: PanelContainer
var _speed_label: Label
var _speed_bar: ProgressBar
var _fuel_bar: ProgressBar
var _dmg_bar: ProgressBar
var _surface_label: Label
var _help: PanelContainer
var _help_label: Label
var _map_holder: PanelContainer
var _pause: Control
var _toast: Label
var _toast_time := 0.0
var _alert: Label
var _crosshair: Control
var _scope: Control
var _bino: Control
var _hp_bar: ProgressBar
var _st_bar: ProgressBar
var _bac_label: Label
var _ammo: Label
var _progress: ProgressBar
var _dialog: PanelContainer
var _fade: ColorRect
var _msg_box: VBoxContainer
var _status: PanelContainer
var _hit: Control
var _drunk_fx: ColorRect
const DRUNK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 wob = vec2(sin(TIME * 1.3 + uv.y * 7.0), cos(TIME * 1.1 + uv.x * 6.0)) * 0.005 * amount;
	vec2 dbl = vec2(0.014 * sin(TIME * 0.6), 0.005 * cos(TIME * 0.8)) * amount;
	float blur = amount * 1.1;
	vec3 a = textureLod(screen_tex, uv + wob, blur).rgb;
	vec3 b = textureLod(screen_tex, uv + wob + dbl, blur).rgb;
	vec3 col = mix(a, b, 0.5 * amount);
	float v = smoothstep(0.95, 0.25, length(uv - 0.5));
	col *= mix(1.0, v, 0.55 * amount);
	col = mix(col, col * vec3(1.08, 1.0, 0.88) + vec3(0.03, 0.0, 0.02), amount * 0.7);
	COLOR = vec4(col, 1.0);
}
"""
var _hit_t := 0.0
var _hit_kill := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	add_child(root)

	# Rausch: Bild verschwimmt, doppelt, schwankt (unter allen anderen Anzeigen)
	_drunk_fx = ColorRect.new()
	_drunk_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drunk_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DRUNK_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = sh
	_drunk_fx.material = smat
	_drunk_fx.visible = false
	root.add_child(_drunk_fx)
	_scope = _scope_overlay(true)
	_bino = _scope_overlay(false)
	_crosshair = _make_crosshair()
	_hit = Control.new()
	_hit.set_anchors_preset(Control.PRESET_CENTER)
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit)
	_hit.draw.connect(func():
		if _hit_t <= 0.0:
			return
		var c := Color(0.9, 0.1, 0.1, _hit_t * 2.0) if _hit_kill else Color(1, 1, 1, _hit_t * 2.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_hit.draw_line(d * 7.0, d * 16.0, c, 3.0))

	# Ort, Uhrzeit, Geld oben links
	var place_panel := panel(root)
	_anchor(place_panel, Control.PRESET_TOP_LEFT)
	var vb := VBoxContainer.new()
	place_panel.add_child(vb)
	_place = Label.new()
	_place.add_theme_font_size_override("font_size", 24)
	vb.add_child(_place)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 15)
	_sub.add_theme_color_override("font_color", INK.lightened(0.3))
	vb.add_child(_sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 16)
	row.add_child(_clock)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 16)
	_money.add_theme_color_override("font_color", Color(0.1, 0.45, 0.15))
	row.add_child(_money)

	# Status unten links
	_status = panel(root)
	_status.custom_minimum_size = Vector2(230, 0)
	var sv := VBoxContainer.new()
	_status.add_child(sv)
	_hp_bar = _bar(sv, "Gesundheit", Color(0.85, 0.25, 0.2))
	_st_bar = _bar(sv, "Ausdauer", Color(0.3, 0.6, 0.9))
	var r2 := HBoxContainer.new()
	sv.add_child(r2)
	_ammo = Label.new()
	_ammo.add_theme_font_size_override("font_size", 18)
	r2.add_child(_ammo)
	_bac_label = Label.new()
	_bac_label.add_theme_font_size_override("font_size", 16)
	_bac_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bac_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(_bac_label)
	_anchor(_status, Control.PRESET_BOTTOM_LEFT)

	# Minimap und Hilfe oben rechts
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	_anchor(right, Control.PRESET_TOP_RIGHT)
	_map_holder = panel(right)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(210, 210)
	_map_holder.add_child(minimap)
	_help = panel(right)
	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 14)
	_help.add_child(_help_label)
	_help.visible = false

	# Nachrichten (Handy-Benachrichtigungen) rechts unter der Minimap
	_msg_box = VBoxContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.custom_minimum_size = Vector2(320, 0)
	root.add_child(_msg_box)
	_msg_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	_msg_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# Hinweis unten Mitte
	_prompt = panel(root, ACCENT)
	_anchor(_prompt, Control.PRESET_CENTER_BOTTOM, 40)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt.add_child(_prompt_label)
	_prompt.visible = false

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(300, 16)
	_progress.show_percentage = false
	_progress.visible = false
	root.add_child(_progress)
	_anchor(_progress, Control.PRESET_CENTER_BOTTOM, 110)

	# Kurze Meldung oben Mitte
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", INK)
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_toast)
	_anchor(_toast, Control.PRESET_CENTER_TOP, 30)

	_alert = Label.new()
	_alert.add_theme_font_size_override("font_size", 26)
	_alert.add_theme_color_override("font_color", Color(1, 1, 1))
	_alert.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.6))
	_alert.add_theme_constant_override("outline_size", 12)
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_alert)
	_anchor(_alert, Control.PRESET_CENTER_TOP, 75)

	# Tacho unten rechts
	_speedo = panel(root)
	_speedo.custom_minimum_size = Vector2(210, 0)
	var spv := VBoxContainer.new()
	_speedo.add_child(spv)
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_END
	spv.add_child(srow)
	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 48)
	_speed_label.text = "0"
	srow.add_child(_speed_label)
	var unit := Label.new()
	unit.text = " km/h"
	unit.add_theme_font_size_override("font_size", 18)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	srow.add_child(unit)
	_speed_bar = ProgressBar.new()
	_speed_bar.max_value = 140
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size.y = 10
	spv.add_child(_speed_bar)
	_fuel_bar = _bar(spv, "Tank", Color(0.9, 0.6, 0.1))
	_dmg_bar = _bar(spv, "Schaden", Color(0.75, 0.2, 0.2))
	_surface_label = Label.new()
	_surface_label.add_theme_font_size_override("font_size", 14)
	spv.add_child(_surface_label)
	_anchor(_speedo, Control.PRESET_BOTTOM_RIGHT)
	_speedo.visible = false

	# Große Karte (M)
	_map_panel = ColorRect.new()
	(_map_panel as ColorRect).color = Color(0.05, 0.08, 0.15, 0.5)
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.visible = false
	root.add_child(_map_panel)
	var frame := panel(_map_panel)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 80
	frame.offset_top = 60
	frame.offset_right = -80
	frame.offset_bottom = -60
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var mv := VBoxContainer.new()
	frame.add_child(mv)
	var mt := Label.new()
	mt.text = "Karte  (M schließen, Klick setzt Wegpunkt)"
	mt.add_theme_font_size_override("font_size", 20)
	mv.add_child(mt)
	big_map = Minimap.new()
	big_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	big_map.mouse_filter = Control.MOUSE_FILTER_STOP
	mv.add_child(big_map)

	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_root)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_build_pause(root)
	set_driving(false)
	GameState.message.connect(func(from, text): notify(from, text))


func _bar(parent: Control, title: String, color: Color) -> ProgressBar:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 92
	l.add_theme_font_size_override("font_size", 14)
	h.add_child(l)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(110, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := _style(color, 0)
	fill.set_content_margin_all(0)
	fill.set_corner_radius_all(6)
	fill.shadow_size = 0
	b.add_theme_stylebox_override("fill", fill)
	h.add_child(b)
	return b


func _make_crosshair() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	c.draw.connect(func():
		c.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.85))
		c.draw_arc(Vector2.ZERO, 4.0, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.5))
	return c


func _scope_overlay(rifle: bool) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	c.draw.connect(func():
		var s := c.size
		var center := s * 0.5
		var r := s.y * 0.46
		var black := Color(0, 0, 0)
		# Rand schwarz
		if rifle:
			var pts := PackedVector2Array()
			for k in 65:
				pts.append(center + Vector2(cos(TAU * k / 64.0), sin(TAU * k / 64.0)) * r)
			c.draw_rect(Rect2(0, 0, center.x - r, s.y), black)
			c.draw_rect(Rect2(center.x + r, 0, s.x - center.x - r, s.y), black)
			for k in 64:
				var a0 := TAU * k / 64.0
				var a1 := TAU * (k + 1) / 64.0
				var p0 := center + Vector2(cos(a0), sin(a0)) * r
				var p1 := center + Vector2(cos(a1), sin(a1)) * r
				var q0 := center + Vector2(cos(a0), sin(a0)) * s.x
				var q1 := center + Vector2(cos(a1), sin(a1)) * s.x
				c.draw_colored_polygon(PackedVector2Array([p0, p1, q1, q0]), black)
			c.draw_arc(center, r, 0, TAU, 96, Color(0.05, 0.05, 0.05), 6.0)
			# Absehen 4
			c.draw_line(center - Vector2(r, 0), center - Vector2(18, 0), black, 4.0)
			c.draw_line(center + Vector2(18, 0), center + Vector2(r, 0), black, 4.0)
			c.draw_line(center + Vector2(0, 18), center + Vector2(0, r), black, 5.0)
			c.draw_line(center - Vector2(0, 40), center - Vector2(0, 2), black, 1.5)
			c.draw_line(center - Vector2(16, 0), center + Vector2(16, 0), black, 1.5)
			c.draw_circle(center, 1.5, Color(0.9, 0.1, 0.1))
		else:
			for side in [-1, 1]:
				var cc := center + Vector2(r * 0.62 * side, 0)
				c.draw_arc(cc, r * 0.8, 0, TAU, 96, black, 4.0)
			c.draw_rect(Rect2(0, 0, s.x, s.y * 0.04), black)
			c.draw_rect(Rect2(0, s.y * 0.96, s.x, s.y * 0.04), black)
			c.draw_line(center - Vector2(30, 0), center + Vector2(30, 0), Color(0, 0, 0, 0.6), 1.0))
	return c


## Verankert ein Element an einer Bildschirmecke; es wächst von dort nach innen.
static func _anchor(c: Control, preset: Control.LayoutPreset, margin := 20) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	match preset:
		Control.PRESET_TOP_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_TOP:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH


func panel(parent: Control, bg := PAPER) -> PanelContainer:
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


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK.lightened(0.5))
	t.set_stylebox("normal", "Button", _style(PAPER, 2))
	t.set_stylebox("hover", "Button", _style(ACCENT, 2))
	t.set_stylebox("pressed", "Button", _style(ACCENT.darkened(0.15), 2))
	t.set_stylebox("focus", "Button", _style(ACCENT, 2))
	t.set_stylebox("disabled", "Button", _style(Color(0.85, 0.83, 0.78), 2))
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		(t.get_stylebox(k, "Button") as StyleBoxFlat).set_content_margin_all(8)
		(t.get_stylebox(k, "Button") as StyleBoxFlat).shadow_size = 2
	var line := _style(Color(1, 1, 1), 2)
	line.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_color("font_color", "LineEdit", INK)
	var bar_bg := _style(Color(0.85, 0.82, 0.75), 2)
	bar_bg.set_content_margin_all(0)
	bar_bg.set_corner_radius_all(6)
	bar_bg.shadow_size = 0
	var bar_fill := _style(Color(0.35, 0.75, 0.35), 0)
	bar_fill.set_content_margin_all(0)
	bar_fill.set_corner_radius_all(6)
	bar_fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t


func _build_pause(parent: Control) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.05, 0.08, 0.15, 0.45)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	parent.add_child(_pause)
	var box := panel(_pause)
	box.custom_minimum_size = Vector2(340, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var title := Label.new()
	title.text = "Saint Leonard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)
	var settings_box := VBoxContainer.new()
	settings_box.visible = false
	var buttons := [
		["Weiterspielen", func(): resume_requested.emit()],
		["Speichern", func(): save_requested.emit()],
		["Einstellungen", func(): settings_box.visible = not settings_box.visible],
		["Steuerung anzeigen", func(): toggle_help()],
		["Speichern und zum Hauptmenü", func(): menu_requested.emit()],
		["Speichern und beenden", func(): quit_requested.emit()],
	]
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		btn.pressed.connect(func(): Sfx.play_2d(self, Sfx.click(), -6.0))
		vb.add_child(btn)
	vb.add_child(settings_box)
	Menus.settings_ui(settings_box)
	settings_box.visibility_changed.connect(func(): _anchor(box, Control.PRESET_CENTER, 0))
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
	_sub.add_theme_color_override("font_color", RED if warn else INK.lightened(0.3))


func toggle_map() -> void:
	_map_panel.visible = not _map_panel.visible
	Sfx.play_2d(self, Sfx.click(), -8.0)


func map_open() -> bool:
	return _map_panel.visible


func set_minimap(on: bool) -> void:
	_map_holder.visible = on


func set_prompt(text: String) -> void:
	_prompt.visible = not text.is_empty()
	_prompt_label.text = text


func set_progress(v: float) -> void:
	_progress.visible = v > 0.0
	_progress.value = v * 100.0


func set_speed(kmh: float, fuel: float, damage: float, surface: String) -> void:
	_speed_label.text = str(roundi(absf(kmh)))
	_speed_bar.value = absf(kmh)
	_fuel_bar.value = fuel / Truck.TANK * 100.0
	_dmg_bar.value = damage
	_surface_label.text = surface


func set_alert(text: String) -> void:
	_alert.text = text


func toast(text: String, seconds := 2.5) -> void:
	_toast.text = text
	_toast_time = seconds
	_toast.modulate.a = 1.0


## Benachrichtigung am Rand (wie am Handy)
func notify(from: String, text: String) -> void:
	var p := panel(_msg_box)
	var l := Label.new()
	l.text = "%s\n%s" % [from, text]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	l.add_theme_font_size_override("font_size", 14)
	p.add_child(l)
	Sfx.play_2d(self, Sfx.ping(), -10.0)
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(p, "modulate:a", 0.0, 1.0)
	tw.tween_callback(p.queue_free)
	while _msg_box.get_child_count() > 4:
		_msg_box.get_child(0).free()


func toggle_help() -> void:
	_help.visible = not _help.visible


func show_pause(on: bool) -> void:
	_pause.visible = on


func set_fade(a: float) -> void:
	_fade.color.a = a


## Ansicht durch Zielfernrohr / Fernglas / Fadenkreuz
func set_view(first_person: bool, aiming: bool, slot: String, driving: bool) -> void:
	_scope.visible = aiming and WeaponHand.has_scope(slot)
	_bino.visible = aiming and slot == "binoculars"
	_crosshair.visible = first_person and not driving and slot != "none" and not _scope.visible and not _bino.visible
	if _scope.visible:
		_scope.queue_redraw()
	if _bino.visible:
		_bino.queue_redraw()


func update_status() -> void:
	_clock.text = "%s  Tag %d  %s" % [GameState.clock_text(), GameState.day, {clear = "sonnig", cloudy = "bewölkt", fog = "Nebel", rain = "Regen"}.get(GameState.weather, "")]
	_money.text = "%d €" % GameState.money
	_hp_bar.value = GameState.health
	_st_bar.value = GameState.stamina
	_ammo.text = "Patronen %d/%d" % [GameState.loaded, GameState.count("ammo")] if (GameState.has("rifle") or GameState.has("pistol") or GameState.has("assault_rifle") or GameState.has("sniper")) else ""
	var pm := GameState.promille()
	_bac_label.text = "%.1f ‰" % pm if pm >= 0.1 else ""
	_bac_label.add_theme_color_override("font_color", RED if pm >= 0.5 else INK)


# ------------------------------------------------------------------ Dialoge

## Dialog mit Text und Knöpfen: options = [[Text, Callable], ...]
func show_dialog(title: String, text: String, options: Array) -> void:
	close_dialog()
	_dialog = panel(menu_root)
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.custom_minimum_size = Vector2(520, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_dialog.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	vb.add_child(t)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 490
	vb.add_child(l)
	for o in options:
		var b := Button.new()
		b.text = o[0]
		var cb: Callable = o[1]
		b.pressed.connect(func():
			Sfx.play_2d(self, Sfx.click(), -6.0)
			close_dialog()
			cb.call())
		vb.add_child(b)
	_anchor(_dialog, Control.PRESET_CENTER, 0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
	_restore_mouse()


func dialog_open() -> bool:
	return is_instance_valid(_dialog)


func menus_open() -> bool:
	for c in menu_root.get_children():
		if not c.is_queued_for_deletion():
			return true
	return false


func _restore_mouse() -> void:
	await get_tree().process_frame
	if not menus_open() and not _pause.visible and not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Trefferanzeige (rot = tödlich)
func hitmarker(kill := false) -> void:
	_hit_t = 0.5
	_hit_kill = kill
	_hit.queue_redraw()


func _process(delta: float) -> void:
	var d := GameState.drunkness()
	_drunk_fx.visible = d > 0.02
	if _drunk_fx.visible:
		(_drunk_fx.material as ShaderMaterial).set_shader_parameter("amount", d)
	if _hit_t > 0.0:
		_hit_t -= delta
		_hit.queue_redraw()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	if _alert.text != "":
		_alert.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
