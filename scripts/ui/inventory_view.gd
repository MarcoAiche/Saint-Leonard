class_name InventoryView
extends Control
## Inventar im Raster (wie in Tarkov): links Ausrüstung, rechts der Rucksack mit Kästchen.
## Gegenstände sind unterschiedlich groß, gleiche Dinge liegen gestapelt (Zahl unten rechts).
## Ziehen mit der Maus verschiebt, Rechtsklick öffnet Aktionen, Darüberfahren zeigt Infos.

signal action(id: String, what: String)

const CELL := 56
const COLS := 10
const ROWS := 8
const EQUIP := [["sniper", "Scharfschützengewehr", Vector2i(5, 2)], ["knife", "Messer", Vector2i(2, 1)],
	["flashlight", "Lampe", Vector2i(2, 1)], ["scope8", "Optik 8x", Vector2i(2, 1)]]
const SIZES := {
	ammo = Vector2i(1, 1), beer = Vector2i(1, 2), schnaps = Vector2i(1, 2), moonshine = Vector2i(1, 2), cigarettes = Vector2i(1, 1),
	snack = Vector2i(1, 1), meat_cooked = Vector2i(2, 1), meat = Vector2i(2, 2), hide = Vector2i(2, 2), antlers = Vector2i(2, 2),
	tusks = Vector2i(1, 1), legend_antlers = Vector2i(3, 2), sugar = Vector2i(1, 2), yeast = Vector2i(1, 1), fruit = Vector2i(2, 2),
	grain = Vector2i(2, 2), jerrycan = Vector2i(2, 2), still = Vector2i(3, 3), stand = Vector2i(3, 3), trailcam = Vector2i(1, 2),
	campfire = Vector2i(2, 2), straps = Vector2i(1, 1), crate = Vector2i(2, 2), table = Vector2i(3, 2), chair = Vector2i(2, 2),
	bed = Vector2i(3, 3), sofa = Vector2i(3, 2), shelf = Vector2i(2, 3), lamp = Vector2i(1, 3), rug = Vector2i(2, 1),
	stove = Vector2i(2, 3), frame = Vector2i(1, 1), trophy = Vector2i(2, 2), jacket = Vector2i(2, 2), hunter_hat = Vector2i(2, 1),
}
const KIND_COLORS := {
	drink = Color(0.30, 0.42, 0.55), smoke = Color(0.55, 0.30, 0.30), food = Color(0.55, 0.45, 0.25), ammo = Color(0.45, 0.42, 0.28),
	ingredient = Color(0.42, 0.48, 0.32), placeable = Color(0.38, 0.32, 0.26), furniture = Color(0.40, 0.33, 0.45),
	loot = Color(0.50, 0.28, 0.24), outfit = Color(0.28, 0.40, 0.30), tool = Color(0.33, 0.35, 0.38), cargo = Color(0.50, 0.40, 0.20),
	weapon = Color(0.25, 0.27, 0.25),
}

var game: Node
var _layout := {}  # id -> Vector2i (Position im Raster)
var _grid_origin := Vector2(300, 50)
var _equip_rects := {}  # id -> Rect2
var _hover := ""
var _drag := ""
var _drag_offset := Vector2.ZERO
var _mouse := Vector2.ZERO
var _popup: PopupMenu


func setup(g: Node) -> void:
	game = g
	custom_minimum_size = Vector2(_grid_origin.x + COLS * CELL + 20, _grid_origin.y + ROWS * CELL + 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in GameState.inv_layout:
		var v: Array = GameState.inv_layout[id]
		_layout[id] = Vector2i(int(v[0]), int(v[1]))
	_popup = PopupMenu.new()
	add_child(_popup)
	_popup.id_pressed.connect(_on_popup)
	_relayout()
	var y := 50.0
	for e in EQUIP:
		var sz: Vector2i = e[2]
		_equip_rects[e[0]] = Rect2(Vector2(10, y + 18), Vector2(sz.x * 52, sz.y * 52))
		y += sz.y * 52 + 30


static func size_of(id: String) -> Vector2i:
	return SIZES.get(id, Vector2i(1, 1))


func _grid_ids() -> Array:
	var ids := []
	for key in GameState.inv:
		var id := str(key)
		if Items.info(id).kind in ["weapon"] or id in ["knife", "flashlight", "scope8"]:
			continue
		ids.append(id)
	ids.sort_custom(func(a, b):
		var sa := size_of(a)
		var sb := size_of(b)
		return sa.x * sa.y > sb.x * sb.y if sa.x * sa.y != sb.x * sb.y else str(a) < str(b))
	return ids


func _occupied(skip := "") -> Dictionary:
	var occ := {}
	for id in _layout:
		if id == skip or not GameState.inv.has(id):
			continue
		var p: Vector2i = _layout[id]
		var s := size_of(id)
		for x in s.x:
			for y in s.y:
				occ[p + Vector2i(x, y)] = id
	return occ


func _fits(id: String, p: Vector2i, occ: Dictionary) -> bool:
	var s := size_of(id)
	if p.x < 0 or p.y < 0 or p.x + s.x > COLS or p.y + s.y > ROWS:
		return false
	for x in s.x:
		for y in s.y:
			if occ.has(p + Vector2i(x, y)):
				return false
	return true


## Neue Gegenstände an den ersten freien Platz, entfernte vergessen
func _relayout() -> void:
	for id in _layout.keys():
		if not GameState.inv.has(id):
			_layout.erase(id)
	for id in _grid_ids():
		if _layout.has(id):
			continue
		var occ := _occupied()
		var placed := false
		for y in ROWS:
			for x in COLS:
				if not placed and _fits(id, Vector2i(x, y), occ):
					_layout[id] = Vector2i(x, y)
					placed = true
		if not placed:
			_layout[id] = Vector2i(-99, -99)  # passt nicht mehr (wird unten aufgelistet)
	_save_layout()


func _save_layout() -> void:
	var d := {}
	for id in _layout:
		d[id] = [_layout[id].x, _layout[id].y]
	GameState.inv_layout = d


func _cell_rect(id: String) -> Rect2:
	var p: Vector2i = _layout.get(id, Vector2i(-99, -99))
	var s := size_of(id)
	return Rect2(_grid_origin + Vector2(p) * CELL, Vector2(s) * CELL).grow(-2)


func _item_at(pos: Vector2) -> String:
	for id in _equip_rects:
		if GameState.has(id) and _equip_rects[id].has_point(pos):
			return id
	for id in _layout:
		if GameState.inv.has(id) and _cell_rect(id).has_point(pos):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		var h := _item_at(_mouse)
		if h != _hover or _drag != "":
			_hover = h
			tooltip_text = _tooltip(h)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var id := _item_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and id != "" and _layout.has(id):
			_drag = id
			_drag_offset = event.position - _cell_rect(id).position
		elif event.button_index == MOUSE_BUTTON_LEFT and id != "" and _equip_rects.has(id):
			action.emit(id, "equip")
		elif event.button_index == MOUSE_BUTTON_RIGHT and id != "":
			_open_popup(id, event.global_position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag != "":
		var cell := Vector2i(((event.position - _drag_offset - _grid_origin) / CELL + Vector2(0.5, 0.5)).floor())
		if _fits(_drag, cell, _occupied(_drag)):
			_layout[_drag] = cell
			_save_layout()
			Sfx.play_2d(self, Sfx.click(), -12.0, 0.8)
		_drag = ""
		queue_redraw()


func _open_popup(id: String, at: Vector2) -> void:
	_popup.clear()
	_popup.set_meta("id", id)
	var it := Items.info(id)
	match it.kind:
		"drink": _popup.add_item("Trinken", 0)
		"smoke": _popup.add_item("Rauchen", 0)
		"food": _popup.add_item("Essen", 0)
		"placeable", "furniture": _popup.add_item("Aufstellen", 1)
		"outfit": _popup.add_item("Anziehen", 2)
	if id == "jerrycan":
		_popup.add_item("Pickup betanken", 3)
	if id in ["sniper", "pistol", "assault_rifle"]:
		_popup.add_item("In die Hand nehmen", 4)
	if not id in ["sniper", "knife"]:
		_popup.add_item("Eins wegwerfen", 9)
	_popup.position = Vector2i(at)
	_popup.popup()


func _on_popup(pid: int) -> void:
	var id: String = _popup.get_meta("id")
	var what: String = {0: "use", 1: "place", 2: "wear", 3: "jerrycan", 4: "equip", 9: "drop"}.get(pid, "")
	action.emit(id, what)


func _tooltip(id: String) -> String:
	if id.is_empty():
		return ""
	var it := Items.info(id)
	var lines := ["%s  (x%d)" % [it.name, GameState.count(id)]]
	match it.kind:
		"drink": lines.append("Alkohol: +%.1f ‰" % (it.get("alcohol", 0.0) * 10.0))
		"food": lines.append("Gesundheit +%d" % [it.get("heal", 0)])
		"smoke": lines.append("90 s ruhige Hand, Husten verscheucht Wild")
		"placeable", "furniture": lines.append("Rechtsklick: Aufstellen")
		"outfit": lines.append("Rechtsklick: Anziehen")
	if it.get("illegal", false):
		lines.append("Illegal! Die Polizei beschlagnahmt das.")
	var sells: Dictionary = it.get("sell", {})
	for shop in sells:
		lines.append("Verkauf: $%d (%s)" % [sells[shop], Items.SHOP_NAMES.get(shop, shop)])
	return "\n".join(lines)


func _draw() -> void:
	var font := get_theme_default_font()
	var ink := Color(0.92, 0.92, 0.88)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.10, 0.96))
	draw_string(font, Vector2(10, 30), "AUSRÜSTUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	draw_string(font, _grid_origin + Vector2(0, -16), "RUCKSACK  %d × %d" % [COLS, ROWS], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	# Ausrüstung
	for e in EQUIP:
		var r: Rect2 = _equip_rects[e[0]]
		draw_string(font, r.position + Vector2(0, -4), e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink.darkened(0.3))
		draw_rect(r, Color(0.18, 0.19, 0.18))
		draw_rect(r, Color(0.35, 0.36, 0.34), false, 1.0)
		if GameState.has(e[0]):
			var active: bool = game.player and game.player.hand.slot == e[0]
			ItemIcons.draw_icon(self, r.grow(-4), e[0])
			if active:
				draw_rect(r, Color(0.98, 0.78, 0.25), false, 2.0)
	if game.player:
		var hat: String = GameState.outfit.get("hat", "")
		draw_string(font, Vector2(10, size.y - 40), "Hut: %s   Jacke: %s" % [{cap = "Kappe", hunter = "Jägerhut", hunter_gams = "Jägerhut mit Gamsbart", none = "keiner"}.get(hat, hat), "ja" if GameState.outfit.get("jacket", false) else "nein"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink.darkened(0.2))
		draw_string(font, Vector2(10, size.y - 20), "Patronen im Magazin: %d/%d" % [GameState.loaded, GameState.MAG_SIZE], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink.darkened(0.2))
	# Raster
	for x in COLS:
		for y in ROWS:
			var c := Rect2(_grid_origin + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			draw_rect(c, Color(0.16, 0.17, 0.16))
			draw_rect(c, Color(0.26, 0.27, 0.25), false, 1.0)
	var overflow := []
	for id in _layout:
		if not GameState.inv.has(id):
			continue
		if _layout[id].x < 0:
			overflow.append(id)
			continue
		if id == _drag:
			continue
		_draw_item(id, _cell_rect(id), id == _hover)
	if _drag != "":
		var s := size_of(_drag)
		var cell := Vector2i(((_mouse - _drag_offset - _grid_origin) / CELL + Vector2(0.5, 0.5)).floor())
		var ok := _fits(_drag, cell, _occupied(_drag))
		draw_rect(Rect2(_grid_origin + Vector2(cell) * CELL, Vector2(s) * CELL), Color(0.3, 0.8, 0.3, 0.25) if ok else Color(0.9, 0.2, 0.2, 0.25))
		_draw_item(_drag, Rect2(_mouse - _drag_offset, Vector2(s) * CELL).grow(-2), true)
	if not overflow.is_empty():
		var t := "Kein Platz mehr: " + ", ".join(overflow.map(func(x): return "%s x%d" % [Items.display(x), GameState.count(x)]))
		draw_string(font, _grid_origin + Vector2(0, ROWS * CELL + 22), t, HORIZONTAL_ALIGNMENT_LEFT, COLS * CELL, 13, Color(1, 0.6, 0.4))
	draw_string(font, _grid_origin + Vector2(0, ROWS * CELL + 44), "Ziehen: verschieben   Rechtsklick: benutzen   Linksklick auf Ausrüstung: in die Hand", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink.darkened(0.35))


func _draw_item(id: String, r: Rect2, hover: bool) -> void:
	var it := Items.info(id)
	var bg: Color = KIND_COLORS.get(it.kind, Color(0.3, 0.3, 0.3))
	draw_rect(r, bg.darkened(0.25) if not hover else bg)
	draw_rect(r, bg.lightened(0.3), false, 1.5)
	ItemIcons.draw_icon(self, r.grow(-6), id)
	var font := get_theme_default_font()
	var short: String = it.name.split(" ")[0].left(12)
	draw_string(font, r.position + Vector2(4, 14), short, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 11, Color(1, 1, 1, 0.9))
	var n := GameState.count(id)
	if n > 1:
		draw_string(font, r.end - Vector2(28, 5), str(n), HORIZONTAL_ALIGNMENT_RIGHT, 24, 14, Color(1, 0.95, 0.6))
