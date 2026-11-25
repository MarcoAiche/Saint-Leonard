class_name TrophyBoard
extends Node3D
## Trophäenwand im Gasthaus Pirtscher (Issue #9). Beim Ausnehmen wird jede Trophäe vermessen
## (Rehbock: Geweihpunkte, Keiler: Waffen in cm, Bär: Schädel in cm, Fuchs: Balg in cm).
## Kapitale Stücke und seltene Tiere kommen in GameState.trophies und werden im Gasthaus
## aufgehängt. Die Wand zeigt die besten Stücke mit Schild, das Trophäenbuch alle Rekorde.
## Der Riesenhirsch aus Kapitel 3 bekommt den Ehrenplatz in der Mitte.

const SHOWN := 8  # Plätze an der Wand (ohne Ehrenplatz)
## Was als Trophäe zählt: Mindestwert, Einheit, Anzeigename
const KINDS := {
	deer = {min = 120.0, unit = "Pkt", name = "Rehbock"},
	boar = {min = 20.0, unit = "cm", name = "Keiler"},
	bear = {min = 0.0, unit = "cm", name = "Braunbär"},
	fox = {min = 0.0, unit = "cm", name = "Fuchs"},
	legend = {min = 0.0, unit = "Pkt", name = "Riesenhirsch"},
}

var game: Node
var _mounts: Node3D


## Vermessung eines erlegten Tiers (gleiche Werte bei allen Mitspielern, weil von net_id abhängig).
## Leeres Dictionary, wenn es keine Trophäe gibt (Geiß, Bache, Hase).
static func measure(species: String, male: bool, seed: int) -> Dictionary:
	if not KINDS.has(species):
		return {}
	if species in ["deer", "boar"] and not male:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed * 7919 + species.hash())
	var tri := (rng.randf() + rng.randf() + rng.randf()) / 3.0  # meist Mittelmaß, selten kapital
	var score := 0.0
	match species:
		"deer": score = lerpf(70.0, 190.0, tri)
		"boar": score = lerpf(12.0, 28.0, tri)
		"bear": score = lerpf(52.0, 68.0, tri)
		"fox": score = lerpf(95.0, 125.0, tri)
		"legend": score = lerpf(235.0, 260.0, tri)
	score = snappedf(score, 0.1)
	var k: Dictionary = KINDS[species]
	return {sp = species, score = score, unit = k.unit, worthy = score >= float(k.min)}


static func label(t: Dictionary) -> String:
	return "%s  %.1f %s" % [KINDS[t.sp].name, float(t.score), t.unit]


## Beim Ausnehmen: Trophäe merken (noch nicht aufgehängt). Gibt den Toast-Text zurück.
static func record(species: String, male: bool, seed: int) -> String:
	var m := measure(species, male, seed)
	if m.is_empty() or not m.worthy:
		return ""
	var t := {sp = m.sp, score = m.score, unit = m.unit, day = GameState.day, hung = false}
	GameState.trophies.append(t)
	var best := best_of(m.sp, t)
	var rec := " Neuer Rekord!" if best.is_empty() or float(m.score) > float(best.score) else ""
	return "Trophäe: %s.%s Häng sie im Gasthaus Pirtscher auf." % [label(t), rec]


## Bestes bisheriges Stück einer Art (ohne das gerade erlegte)
static func best_of(sp: String, except := {}) -> Dictionary:
	var best := {}
	for t in GameState.trophies:
		if t.sp != sp or is_same(t, except):
			continue
		if best.is_empty() or float(t.score) > float(best.score):
			best = t
	return best


static func legend_delivered() -> bool:
	return GameState.story.get("done_legend_deliver", false)


static func pending() -> Array:
	return GameState.trophies.filter(func(t): return not t.hung and (t.sp != "legend" or legend_delivered()))


func setup(g: Node, gasthaus: Node3D, wall: Transform3D) -> void:
	game = g
	gasthaus.add_child(self)
	transform = wall
	var I: Interactions = game.interactions
	I.add(Vector3(0, -1.0, 1.4), 2.6, func(): return "Trophäen aufhängen (%d)" % pending().size(), func(): hang_all(), func(): not pending().is_empty(), self)
	I.add(Vector3(0, -1.0, 1.4), 2.6, "Trophäenbuch ansehen", func(): open_book(), func(): pending().is_empty(), self)
	refresh()


func hang_all() -> void:
	var n := 0
	for t in pending():
		t.hung = true
		n += 1
	refresh()
	game.hud.toast("%d Trophäe%s aufgehängt" % [n, "" if n == 1 else "n"], 2.5)
	Sfx.play_3d(self, Sfx.click(), -4.0, 0.6)


## Wand neu bestücken: Ehrenplatz Riesenhirsch, dann die besten Stücke
func refresh() -> void:
	if _mounts:
		_mounts.queue_free()
	_mounts = Node3D.new()
	add_child(_mounts)
	var hung: Array = GameState.trophies.filter(func(t): return t.hung)
	hung.sort_custom(func(a, b): return _rank(a) > _rank(b))
	var legend := {}
	for t in hung:
		if t.sp == "legend":
			legend = t
			break
	if legend.is_empty() and legend_delivered():
		legend = {sp = "legend", score = 0.0, unit = "Pkt", day = 0, hung = true}
	if not legend.is_empty():
		_mount(legend, Vector3(0, 0.55, 0), 1.5)
	var others := hung.filter(func(t): return t.sp != "legend")
	var slots := [-1.95, -1.15, 1.15, 1.95]
	for k in mini(others.size(), SHOWN):
		var x: float = slots[k % 4]
		var y := 0.5 if k < 4 else -0.4
		_mount(others[k], Vector3(x, y, 0), 1.0)
	if hung.is_empty() and legend.is_empty():
		var hint := Label3D.new()
		hint.text = "Trophäenwand\nnoch leer"
		hint.font_size = 36
		hint.pixel_size = 0.006
		hint.modulate = Color(0.95, 0.88, 0.65)
		hint.position = Vector3(0, 0, 0.05)
		_mounts.add_child(hint)


## Rang an der Wand: Seltenheit vor Größe
func _rank(t: Dictionary) -> float:
	var base := {legend = 4000.0, bear = 3000.0, fox = 1000.0, boar = 2000.0, deer = 1500.0}
	return float(base.get(t.sp, 0.0)) + float(t.score) * (5.0 if t.sp == "boar" else 1.0)


func _mount(t: Dictionary, pos: Vector3, scale_f: float) -> void:
	var n := model(t.sp, float(t.score))
	n.position = pos
	n.scale = Vector3.ONE * scale_f
	_mounts.add_child(n)
	var plate := Label3D.new()
	plate.text = KINDS[t.sp].name + ("
%.1f %s" % [float(t.score), t.unit] if float(t.score) > 0.0 else "")
	plate.font_size = 24
	plate.pixel_size = 0.0035
	plate.modulate = Color(0.95, 0.85, 0.45)
	plate.outline_size = 6
	plate.outline_modulate = Color(0.15, 0.1, 0.05)
	plate.position = pos + Vector3(0, -0.38 * scale_f, 0.06)
	_mounts.add_child(plate)


## Wandschild mit Kopf. Geweih und Waffen wachsen mit dem Messwert.
static func model(sp: String, score: float) -> Node3D:
	var n := Node3D.new()
	var dark := Placeables.DARK_WOOD
	var bone := Color(0.88, 0.8, 0.62)
	Placeables.box(n, Vector3(0.45, 0.55, 0.05), Vector3.ZERO, dark)
	match sp:
		"deer", "legend":
			_head(n, Color(0.55, 0.36, 0.2) if sp == "deer" else Color(0.45, 0.28, 0.15), Vector3(1, 1, 1.4), 0.14)
			var f := clampf((score - 70.0) / 120.0, 0.0, 1.0) if sp == "deer" else 1.4
			var tines := 2 + int(f * 3.0)
			var h := 0.22 + f * 0.18
			for s in [-1, 1]:
				var beam := Placeables.box(n, Vector3(0.035, h, 0.035), Vector3(0.09 * s, 0.12 + h * 0.5, 0.14), bone, Vector3(0, 0, -0.35 * s))
				for k in tines:
					var y := -h * 0.5 + h * (k + 1) / (tines + 1.0)
					Placeables.box(beam, Vector3(0.025, 0.1 + f * 0.04, 0.025), Vector3(0.04 * s, y, 0.02), bone, Vector3(0, 0, -0.9 * s))
		"boar":
			_head(n, Color(0.28, 0.22, 0.18), Vector3(1, 0.9, 1.5), 0.17)
			var tl := 0.06 + clampf((score - 12.0) / 16.0, 0.0, 1.0) * 0.1
			for s in [-1, 1]:
				Placeables.box(n, Vector3(0.03, tl, 0.03), Vector3(0.07 * s, -0.04, 0.38), Color(0.95, 0.93, 0.85), Vector3(0.6, 0, 0.3 * s))
		"bear":
			_head(n, Color(0.35, 0.24, 0.15), Vector3(1.1, 1, 1.2), 0.19)
			for s in [-1, 1]:
				Placeables.cyl(n, 0.05, 0.04, Vector3(0.13 * s, 0.17, 0.1), Color(0.3, 0.2, 0.12))
		"fox":
			_head(n, Color(0.75, 0.32, 0.12), Vector3(0.9, 0.85, 1.6), 0.12)
			for s in [-1, 1]:
				Placeables.box(n, Vector3(0.05, 0.1, 0.03), Vector3(0.07 * s, 0.14, 0.12), Color(0.7, 0.3, 0.1), Vector3(0, 0, -0.3 * s))
			Placeables.box(n, Vector3(0.04, 0.04, 0.04), Vector3(0, -0.02, 0.31), Color(0.1, 0.1, 0.1))
	return n


static func _head(n: Node3D, col: Color, sc: Vector3, r: float) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	m.mesh = s
	m.position = Vector3(0, 0, r * sc.z)
	m.scale = sc
	m.material_override = Toon.solid(col)
	n.add_child(m)


## Trophäenbuch: alle Stücke, beste je Art zuerst
func open_book() -> void:
	var body := Menus.window(game.hud, "Trophäenbuch Gasthaus Pirtscher", 620)
	if GameState.trophies.is_empty():
		Menus.text(body, "Noch keine Trophäen. Kapitale Böcke (ab 120 Pkt), Keiler mit Waffen ab 20 cm, Bären und Füchse kommen hier an die Wand.", 15)
		return
	for sp in ["legend", "bear", "boar", "deer", "fox"]:
		var list: Array = GameState.trophies.filter(func(t): return t.sp == sp)
		if list.is_empty():
			continue
		list.sort_custom(func(a, b): return float(a.score) > float(b.score))
		Menus.heading(body, "%s (%d)" % [KINDS[sp].name, list.size()])
		for k in mini(list.size(), 5):
			var t: Dictionary = list[k]
			Menus.text(body, "%s%.1f %s   Tag %d%s" % ["Rekord: " if k == 0 else "", float(t.score), t.unit, int(t.day), "" if t.hung else "   (noch nicht aufgehängt)"], 15)
