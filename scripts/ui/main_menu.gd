class_name MainMenu
extends CanvasLayer
## Titelbildschirm, Figur-Editor und Mehrspieler-Lobby.
## Titel: Logo oben rechts, Menü als Textliste rechts unten (die Figur steht dahinter in 3D auf
## einem Felsen über dem Dorf, siehe MenuStage). Unterseiten erscheinen als Glas-Panel rechts.
## Lobby: alle Spieler stehen vor dem Gasthaus, "Bereit" und großer "Spielen"-Knopf.

signal start(mode: String, address: String, slot: String, new_game: bool)
signal quit
signal play_from_lobby
signal leave_lobby

const FIGURE_FILE := "user://figur.json"

var stage: MenuStage
var _root: Control
var _title: Control
var _page_box: Control
var _status: Label
var _name := ""
var _ip := "127.0.0.1"
var _in_lobby := false
var _is_ready := false
var _countdown := -1.0
var _lobby_ui: Control
var _lobby_list: VBoxContainer
var _countdown_lbl: Label
var _ready_btn: Button
var _after_figure := "title"


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MenuStyle.theme()
	add_child(_root)
	_name = _load_name()
	var f := FileAccess.open("user://server_address.txt", FileAccess.READ)
	if f:
		_ip = f.get_as_text().strip_edges()
	load_figure()
	page_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Einblenden
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 1.6).finished.connect(fade.queue_free)


## Figur aus dem Menü (zuletzt im Editor gespeichert) laden
static func load_figure() -> void:
	if not FileAccess.file_exists(FIGURE_FILE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FIGURE_FILE))
	if typeof(d) == TYPE_DICTIONARY:
		GameState.outfit = Outfit.normalize(GameState._colors_in(d))


static func save_figure() -> void:
	var f := FileAccess.open(FIGURE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(GameState._colors_out(GameState.outfit)))


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_title = null
	_page_box = null
	_lobby_ui = null
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# ------------------------------------------------------------------ Titel

func page_home() -> void:
	_clear()
	_in_lobby = false
	if stage:
		stage.show_shot("title")
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)
	# Logo oben rechts
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.anchor_left = 0.52
	logo.anchor_right = 0.98
	logo.anchor_top = 0.02
	logo.anchor_bottom = 0.42
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(logo)
	# Menü rechts unten, rechtsbündig wie Text
	var list := VBoxContainer.new()
	list.anchor_left = 0.6
	list.anchor_right = 0.965
	list.anchor_top = 0.5
	list.anchor_bottom = 0.9
	list.alignment = BoxContainer.ALIGNMENT_END
	list.add_theme_constant_override("separation", 4)
	_title.add_child(list)
	var saves := GameState.list_saves()
	var first: Button
	if not saves.is_empty():
		var last: Dictionary = saves[0]
		first = _title_item(list, "Weiterspielen", func(): _go("single", "", last.slot, false))
		var sub := MenuStyle.label("%s  ·  Tag %d  ·  $%d" % [last.title, last.day, last.money], 15, MenuStyle.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		list.add_child(sub)
	var b_new := _title_item(list, "Neues Spiel", func(): page_new())
	if first == null:
		first = b_new
	if saves.size() > 1:
		_title_item(list, "Spielstände", func(): page_saves())
	_title_item(list, "Mehrspieler", func(): page_multi())
	_title_item(list, "Figur", func(): page_figure("title"))
	_title_item(list, "Einstellungen", func(): page_settings())
	_title_item(list, "Beenden", func(): quit.emit())
	list.add_child(_status)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# unten: Spielername links, Version rechts
	var who := HBoxContainer.new()
	who.anchor_top = 1.0
	who.anchor_bottom = 1.0
	who.offset_left = 32
	who.offset_bottom = -32
	who.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_title.add_child(who)
	who.add_child(MenuStyle.label("Spieler: " + (_name if not _name.is_empty() else "(noch kein Name)"), 18))
	var change := Button.new()
	change.text = "Name ändern"
	change.pressed.connect(func(): page_name("title"))
	who.add_child(change)
	var ver := MenuStyle.label("Version %s\nKartendaten © OpenStreetMap-Mitwirkende (ODbL)" % Net.VERSION, 13, Color(1, 1, 1, 0.8))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -420
	ver.offset_right = -32
	ver.offset_top = -74
	ver.offset_bottom = -32
	_title.add_child(ver)
	if first:
		first.call_deferred("grab_focus")


## Menüpunkt als Text mit Pfeil, wenn ausgewählt (wie im Titelbildschirm großer Abenteuer)
func _title_item(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	b.add_theme_color_override("font_hover_color", MenuStyle.GOLD)
	b.add_theme_color_override("font_focus_color", MenuStyle.GOLD)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 6)
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, empty)
	var mark := func(on: bool):
		b.text = ("➤  " if on else "") + text
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func():
		mark.call(true)
		Sfx.play_2d(self, Sfx.click(), -18.0, 1.6))
	b.focus_exited.connect(func(): mark.call(false))
	b.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -6.0)
		cb.call())
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ Unterseiten (Glas-Panel rechts)

func _page(title: String, width := 520.0) -> VBoxContainer:
	_clear()
	var panel := MenuStyle.panel(width)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -48
	_root.add_child(panel)
	_page_box = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(MenuStyle.label(title, 34, MenuStyle.GOLD))
	return vb


func _finish(vb: VBoxContainer) -> void:
	vb.add_child(_status)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(func():
		Sfx.play_2d(self, Sfx.click(), -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _field(parent: Control, label: String, value: String, placeholder: String, on_change: Callable, secret := false) -> LineEdit:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := MenuStyle.label(label)
	l.custom_minimum_size.x = 110
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.secret = secret
	e.placeholder_text = placeholder
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(on_change)
	h.add_child(e)
	return e


func page_name(back: String) -> void:
	var vb := _page("Wie heißt du?")
	vb.add_child(MenuStyle.label("Unter diesem Namen spielst du, auch auf Servern.", 16, MenuStyle.MUTED))
	var e := _field(vb, "Name", _name, "Dein Name", func(t): _name = t.strip_edges())
	e.call_deferred("grab_focus")
	var ok := func():
		if _name.is_empty():
			show_error("Bitte einen Namen eingeben.")
			return
		_store_name()
		if back == "multi":
			page_multi()
		else:
			page_home()
	e.text_submitted.connect(func(_t): ok.call())
	_button(vb, "Weiter", ok)
	_finish(vb)


func page_new() -> void:
	if _name.is_empty():
		page_name("title")
		return
	var vb := _page("Neues Spiel")
	var title := ["Mein Saint Leonard"]
	_field(vb, "Spielstand", title[0], "Name des Spielstands", func(t): title[0] = t)
	var go := MenuStyle.big_button("Los geht's", MenuStyle.GREEN, 26)
	go.pressed.connect(func():
		var t: String = str(title[0]).strip_edges()
		if t.is_empty():
			t = "Spielstand"
		GameState.slot_title = t
		_go("single", "", GameState.new_slot_name(t), true))
	vb.add_child(go)
	_button(vb, "Zurück", func(): page_home())
	_finish(vb)


func page_saves() -> void:
	var vb := _page("Spielstände", 640)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for sv in GameState.list_saves():
		var row := HBoxContainer.new()
		list.add_child(row)
		var info := MenuStyle.label("%s\n%s, Tag %d, $%d, Kapitel %d   (%s)" % [sv.title, sv.player, sv.day, sv.money, min(sv.chapter, 3), sv.saved.replace("T", " ").left(16)], 15)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_button(row, "Laden", func(): _go("single", "", sv.slot, false))
		_button(row, "Löschen", func():
			_confirm("Spielstand \"%s\" wirklich löschen? Das kann nicht rückgängig gemacht werden." % sv.title, func():
				GameState.delete_save(sv.slot)
				page_saves()))
	_button(vb, "Zurück", func(): page_home())
	_finish(vb)


func _confirm(text: String, yes: Callable) -> void:
	var vb := _page("Sicher?")
	var l := MenuStyle.label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	vb.add_child(l)
	_button(vb, "Ja, löschen", yes)
	_button(vb, "Nein", func(): page_saves())
	_finish(vb)


func page_multi() -> void:
	if _name.is_empty():
		page_name("multi")
		return
	var vb := _page("Mehrspieler", 560)
	var info := MenuStyle.label("Alle spielen auf einem gemeinsamen Server. Nach dem Verbinden wartest du in der Lobby vor dem Gasthaus, bis du loslegst.", 15, MenuStyle.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 520
	vb.add_child(info)
	_field(vb, "Server", _ip, "Adresse oder Adresse:Port", func(t): _ip = t.strip_edges())
	var pw := _field(vb, "Passwort", "", "falls der Server eines hat", func(_t): pass, true)
	var join := MenuStyle.big_button("Verbinden", MenuStyle.TEAL, 26)
	join.pressed.connect(func():
		Net.join_password = pw.text
		_save_ip()
		_go("client", _ip, "", false))
	vb.add_child(join)
	_button(vb, "Server auf diesem PC starten und verbinden", func():
		Net.join_password = ""
		_go("localserver", "127.0.0.1", "", false))
	var hint := MenuStyle.label("Ein Server auf diesem PC läuft im Hintergrund weiter, bis du ihn im Task-Manager beendest. Freunde verbinden sich mit deiner IP, z. B. über ZeroTier, Port 24680 (UDP).", 13, MenuStyle.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 520
	vb.add_child(hint)
	_button(vb, "Zurück", func(): page_home())
	_finish(vb)


func page_settings() -> void:
	var vb := _page("Einstellungen", 620)
	Menus.settings_ui(vb)
	# settings_ui ist für das helle Pausemenü gebaut: auf dem dunklen Glas helle Schrift
	for c in vb.find_children("*", "CheckBox", true, false):
		for st in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
			(c as CheckBox).add_theme_color_override(st, MenuStyle.TEXT)
		(c as CheckBox).add_theme_icon_override("unchecked", MenuStyle.check_icon(false))
		(c as CheckBox).add_theme_icon_override("checked", MenuStyle.check_icon(true))
	for l in vb.find_children("*", "Label", true, false):
		if not (l as Label).has_theme_color_override("font_color") or (l as Label).get_theme_color("font_color") == Hud.INK:
			(l as Label).add_theme_color_override("font_color", MenuStyle.TEXT)
	_button(vb, "Zurück", func(): page_home())
	_finish(vb)


# ------------------------------------------------------------------ Figur (Duckov-artig: Spiegel)

func page_figure(back: String) -> void:
	_clear()
	_after_figure = back
	if stage:
		stage.show_shot("figure")
	var ed := FigureEditor.new()
	_root.add_child(ed)
	ed.open(GameState.outfit)
	ed.changed.connect(func(o):
		GameState.outfit = o.duplicate()
		if stage:
			stage.refresh_hero())
	ed.rotate.connect(func(d):
		if stage and stage.hero:
			stage.hero_yaw += d
			stage.hero.rotation.y = stage.hero_yaw)
	ed.finished.connect(func(o, accepted):
		GameState.outfit = o.duplicate()
		if accepted:
			save_figure()
			Net.send_outfit()
		if stage:
			stage.refresh_hero()
		if _after_figure == "lobby":
			show_lobby()
		else:
			page_home())


# ------------------------------------------------------------------ Lobby (nach dem Verbinden)

func show_lobby() -> void:
	_clear()
	_in_lobby = true
	_countdown = -1.0
	if stage:
		stage.show_shot("lobby")
	_lobby_ui = Control.new()
	_lobby_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_lobby_ui)
	# oben links: Server und Spielerliste
	var top := VBoxContainer.new()
	top.position = Vector2(32, 26)
	_lobby_ui.add_child(top)
	top.add_child(MenuStyle.label("LOBBY", 52, MenuStyle.YELLOW))
	top.add_child(MenuStyle.label(Net.server_name, 22))
	var panel := MenuStyle.panel(330)
	top.add_child(panel)
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 6)
	panel.add_child(_lobby_list)
	# Mitte oben: Countdown
	_countdown_lbl = MenuStyle.label("", 38, MenuStyle.YELLOW)
	_countdown_lbl.add_theme_constant_override("outline_size", 10)
	_countdown_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.anchor_left = 0.25
	_countdown_lbl.anchor_right = 0.75
	_countdown_lbl.offset_top = 30
	_lobby_ui.add_child(_countdown_lbl)
	# unten links: Figur, Verlassen
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = 32
	left.offset_bottom = -32
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lobby_ui.add_child(left)
	var fig := MenuStyle.big_button("Figur ändern", MenuStyle.TEAL, 20)
	fig.pressed.connect(func(): page_figure("lobby"))
	left.add_child(fig)
	var leave := MenuStyle.big_button("Server verlassen", Color(0.3, 0.3, 0.32), 20)
	leave.pressed.connect(func():
		_in_lobby = false
		leave_lobby.emit())
	left.add_child(leave)
	# unten rechts: Bereit + SPIELEN
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -32
	right.offset_bottom = -32
	_lobby_ui.add_child(right)
	_ready_btn = MenuStyle.big_button("", MenuStyle.GREEN, 22)
	_ready_btn.pressed.connect(func():
		_is_ready = not _is_ready
		Net.send_lobby_state("lobby", _is_ready)
		_update_ready_btn()
		Sfx.play_2d(self, Sfx.click(), -4.0))
	right.add_child(_ready_btn)
	_update_ready_btn()
	var play := MenuStyle.big_button("SPIELEN", MenuStyle.YELLOW, 46, Color(0.12, 0.1, 0.05))
	play.custom_minimum_size = Vector2(330, 0)
	play.pressed.connect(func(): _play())
	right.add_child(play)
	var hint := MenuStyle.label("Sind alle in der Lobby bereit, geht es gemeinsam los.", 14, MenuStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hint)
	_lobby_ui.add_child(_status)
	_status.position = Vector2(32, 0)
	_status.anchor_top = 1.0
	_status.offset_top = -120
	refresh_lobby()


func _update_ready_btn() -> void:
	if not is_instance_valid(_ready_btn):
		return
	_ready_btn.text = "✓  Bereit" if _is_ready else "Bereit?"
	_ready_btn.modulate = Color(1, 1, 1) if _is_ready else Color(0.8, 0.8, 0.8)


## Spielerliste und Aufstellung neu, wenn sich jemand anmeldet, umzieht oder bereit ist
func refresh_lobby() -> void:
	if not _in_lobby or not is_instance_valid(_lobby_list):
		return
	var players := lobby_players()
	for c in _lobby_list.get_children():
		c.queue_free()
	_lobby_list.add_child(MenuStyle.label("%d Spieler online" % players.size(), 17, MenuStyle.MUTED))
	for p in players:
		var row := HBoxContainer.new()
		_lobby_list.add_child(row)
		var n := MenuStyle.label(("★ " if p.id == 0 else "") + str(p.name), 20)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var st := "im Spiel" if p.state == "game" else ("bereit" if p.ready else "wartet")
		var col := Color(0.6, 0.75, 1.0) if p.state == "game" else (MenuStyle.GREEN if p.ready else MenuStyle.MUTED)
		row.add_child(MenuStyle.label(st, 17, col))
	if stage:
		stage.set_lineup(players.filter(func(p): return p.state != "game"))  # wer schon spielt, steht nicht in der Lobby


## Ich zuerst (id 0), dann alle anderen in der Lobby, dann die schon im Spiel sind
func lobby_players() -> Array:
	var me := {id = 0, name = GameState.player_name, outfit = GameState._colors_out(GameState.outfit), state = "lobby", ready = _is_ready}
	var lobby := []
	var playing := []
	for id in Net.peers:
		if id == Net.my_id():
			continue
		var p: Dictionary = Net.peers[id]
		var e := {id = id, name = p.get("name", "?"), outfit = p.get("outfit", {}), state = p.get("state", "game"), ready = p.get("ready", false)}
		if e.state == "game":
			playing.append(e)
		else:
			lobby.append(e)
	return [me] + lobby + playing


func _process(delta: float) -> void:
	if not _in_lobby or not is_instance_valid(_countdown_lbl):
		return
	# alle in der Lobby bereit (und ich auch): gemeinsamer Countdown
	var all_ready := _is_ready
	for p in lobby_players():
		if p.state == "lobby" and not p.ready:
			all_ready = false
	if all_ready:
		if _countdown < 0.0:
			_countdown = 3.99
		_countdown -= delta
		_countdown_lbl.text = "Alle bereit! Los geht's in %d" % maxi(1, int(_countdown) + 1)
		if _countdown <= 0.0:
			_play()
	else:
		_countdown = -1.0
		_countdown_lbl.text = ""


func _play() -> void:
	if not _in_lobby:
		return
	_in_lobby = false
	Sfx.play_2d(self, Sfx.click(), -2.0)
	play_from_lobby.emit()


# ------------------------------------------------------------------ Start

func _load_name() -> String:
	var f := FileAccess.open("user://name.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""


func _store_name() -> void:
	GameState.player_name = _name
	var f := FileAccess.open("user://name.txt", FileAccess.WRITE)
	if f:
		f.store_string(_name)


func _save_ip() -> void:
	var f := FileAccess.open("user://server_address.txt", FileAccess.WRITE)
	if f:
		f.store_string(_ip)


func _go(mode: String, address: String, slot: String, new_game: bool) -> void:
	if _name.is_empty():
		page_name("title")
		return
	_store_name()
	start.emit(mode, address, slot, new_game)


func show_error(text: String) -> void:
	if _status and is_instance_valid(_status):
		_status.text = text
