class_name MainMenu
extends CanvasLayer
## Hauptmenü mit Seiten: Start (Weiterspielen), Spielstände (laden, löschen, neu), Mehrspieler,
## Figur, Einstellungen.

signal start(mode: String, address: String, slot: String, new_game: bool)
signal quit

const SHIRTS := [Color(0.35, 0.42, 0.25), Color(0.75, 0.20, 0.15), Color(0.20, 0.30, 0.55), Color(0.85, 0.65, 0.20), Color(0.30, 0.30, 0.32), Color(0.90, 0.90, 0.88), Color(0.45, 0.30, 0.18)]
const PANTS := [Color(0.30, 0.26, 0.20), Color(0.20, 0.25, 0.40), Color(0.15, 0.15, 0.16), Color(0.40, 0.35, 0.25)]
const SKINS := [Color(0.98, 0.80, 0.66), Color(0.90, 0.70, 0.55), Color(0.72, 0.52, 0.38), Color(0.50, 0.35, 0.25)]
const HATS := [["cap", "Kappe"], ["hunter", "Jägerhut"], ["hunter_gams", "Jägerhut mit Gamsbart"], ["none", "kein Hut"]]

var _root: Control
var _box: PanelContainer
var _body: VBoxContainer
var _status: Label
var _name := ""
var _ip := "127.0.0.1"


func _ready() -> void:
	layer = 10
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.06, 0.09, 0.08, 0.55)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Hud.make_theme()
	add_child(_root)
	_name = _load_name()
	page_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _page(title: String, width := 480.0) -> VBoxContainer:
	if _box:
		_box.queue_free()
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", Hud._style(Hud.PAPER))
	_box.custom_minimum_size = Vector2(width, 0)
	_root.add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_box.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 44 if title == "Saint Leonard" else 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	_body = vb
	_status = Label.new()
	_status.add_theme_color_override("font_color", Hud.RED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Hud._anchor(_box, Control.PRESET_CENTER, 0)
	return vb


func _finish_page() -> void:
	_body.add_child(_status)
	Hud._anchor(_box, Control.PRESET_CENTER, 0)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _name_row(parent: Control) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = "Name"
	l.custom_minimum_size.x = 70
	h.add_child(l)
	var e := LineEdit.new()
	e.text = _name
	e.placeholder_text = "Dein Name"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t): _name = t.strip_edges())
	h.add_child(e)


# ------------------------------------------------------------------ Seiten

func page_home() -> void:
	var vb := _page("Saint Leonard")
	var sub := Label.new()
	sub.text = "Jagen, Brennen, Offroad. Ein Dorf in Kärnten."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	vb.add_child(sub)
	_name_row(vb)
	var saves := GameState.list_saves()
	if not saves.is_empty():
		var last: Dictionary = saves[0]
		_button(vb, "Weiterspielen: %s (Tag %d, %d €)" % [last.title, last.day, last.money], func(): _go("single", "", last.slot, false))
	_button(vb, "Neues Spiel", func(): page_new())
	_button(vb, "Spielstände (%d)" % saves.size(), func(): page_saves(), not saves.is_empty())
	_button(vb, "Mehrspieler", func(): page_multi())
	_button(vb, "Figur anpassen", func(): page_figure())
	_button(vb, "Einstellungen", func(): page_settings())
	_button(vb, "Beenden", func(): quit.emit())
	var note := Label.new()
	note.text = "Kartendaten © OpenStreetMap-Mitwirkende (ODbL)"
	note.add_theme_font_size_override("font_size", 12)
	vb.add_child(note)
	_finish_page()


func page_new() -> void:
	var vb := _page("Neues Spiel")
	_name_row(vb)
	var h := HBoxContainer.new()
	vb.add_child(h)
	var l := Label.new()
	l.text = "Spielstand"
	l.custom_minimum_size.x = 100
	h.add_child(l)
	var e := LineEdit.new()
	e.text = "Mein Saint Leonard"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(e)
	_button(vb, "Los geht's", func():
		var title := e.text.strip_edges()
		if title.is_empty():
			title = "Spielstand"
		GameState.slot_title = title
		_go("single", "", GameState.new_slot_name(title), true))
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func page_saves() -> void:
	var vb := _page("Spielstände", 620)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for sv in GameState.list_saves():
		var row := HBoxContainer.new()
		list.add_child(row)
		var info := Label.new()
		info.text = "%s\n%s, Tag %d, %d €, Kapitel %d   (%s)" % [sv.title, sv.player, sv.day, sv.money, min(sv.chapter, 3), sv.saved.replace("T", " ").left(16)]
		info.add_theme_font_size_override("font_size", 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_button(row, "Laden", func(): _go("single", "", sv.slot, false))
		_button(row, "Löschen", func():
			_confirm("Spielstand \"%s\" wirklich löschen? Das kann nicht rückgängig gemacht werden." % sv.title, func():
				GameState.delete_save(sv.slot)
				page_saves()))
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func _confirm(text: String, yes: Callable) -> void:
	var vb := _page("Sicher?")
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	vb.add_child(l)
	_button(vb, "Ja, löschen", yes)
	_button(vb, "Nein", func(): page_saves())
	_finish_page()


func page_multi() -> void:
	var vb := _page("Mehrspieler")
	_name_row(vb)
	_button(vb, "Server hosten (Freunde treten bei, Port 24680)", func(): _go("host", "", "", false))
	var h := HBoxContainer.new()
	vb.add_child(h)
	var ip := LineEdit.new()
	ip.text = _ip
	ip.placeholder_text = "IP-Adresse (z. B. ZeroTier)"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip.text_changed.connect(func(t): _ip = t.strip_edges())
	h.add_child(ip)
	_button(h, "Beitreten", func(): _go("client", _ip, "", false))
	var hint := Label.new()
	hint.text = "Beim Hosten wird dein eigener Server-Spielstand verwendet. Beim Beitreten speichert der Server deinen Fortschritt unter deinem Namen."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 440
	hint.add_theme_font_size_override("font_size", 14)
	vb.add_child(hint)
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


func page_figure() -> void:
	var vb := _page("Figur anpassen", 520)
	_color_row(vb, "Hemd", "shirt", SHIRTS)
	_color_row(vb, "Hose", "pants", PANTS)
	_color_row(vb, "Haut", "skin", SKINS)
	var hr := HFlowContainer.new()
	vb.add_child(hr)
	var current := Label.new()
	for h in HATS:
		_button(hr, h[1], func():
			GameState.outfit.hat = h[0]
			current.text = "Hut: %s" % h[1])
	current.text = "Hut: %s" % GameState.outfit.get("hat", "cap")
	vb.add_child(current)
	_button(vb, "Fertig", func(): page_home())
	_finish_page()


func _color_row(parent: Control, title: String, key: String, colors: Array) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size.x = 60
	h.add_child(l)
	for c in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 32)
		var sb := Hud._style(c, 2)
		sb.set_content_margin_all(4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", Hud._style(c.lightened(0.2), 3))
		b.pressed.connect(func(): GameState.outfit[key] = c)
		h.add_child(b)


func page_settings() -> void:
	var vb := _page("Einstellungen", 560)
	Menus.settings_ui(vb)
	_button(vb, "Zurück", func(): page_home())
	_finish_page()


# ------------------------------------------------------------------ Start

func _load_name() -> String:
	var f := FileAccess.open("user://name.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""


func _go(mode: String, address: String, slot: String, new_game: bool) -> void:
	if _name.is_empty():
		show_error("Bitte zuerst einen Namen eingeben.")
		return
	GameState.player_name = _name
	var f := FileAccess.open("user://name.txt", FileAccess.WRITE)
	if f:
		f.store_string(_name)
	start.emit(mode, address, slot, new_game)


func show_error(text: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = text
