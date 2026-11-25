class_name Outfit
extends RefCounted
## Kleiderschrank: alle Teile der Spielfigur, Farbpaletten und was man dafür freischalten muss.
## GameState.outfit speichert pro Kategorie die gewählte Variante und die Farben.
## Freigeschaltet ist eine Variante ohne "unlock" immer, sonst wenn man das Teil besitzt
## (Bauhaus: Arbeitskleidung, Supermarkt: Freizeit, Werkbank: aus Fell und Leder hergestellt).

## Kategorien für den Editor: id, Name, Varianten-Schlüssel (oder ""), Farb-Schlüssel
const CATEGORIES := [
	{id = "body", name = "Körper", key = "gender", colors = ["skin"]},
	{id = "hair", name = "Haare", key = "hair", colors = ["hair_color"]},
	{id = "face", name = "Gesicht", key = "beard", colors = ["hair_color"], extra = "glasses"},
	{id = "hat", name = "Kopf", key = "hat", colors = ["hat_color"]},
	{id = "top", name = "Oberteil", key = "top", colors = ["shirt"]},
	{id = "legs", name = "Hose", key = "legs", colors = ["pants"]},
	{id = "back", name = "Rücken", key = "back", colors = []},
]

const STYLES := {
	gender = [
		{id = "male", name = "Mann"},
		{id = "female", name = "Frau"},
	],
	hair = [
		{id = "short", name = "Kurz"},
		{id = "side", name = "Seitenscheitel"},
		{id = "long", name = "Lang"},
		{id = "bald", name = "Glatze"},
	],
	beard = [
		{id = "none", name = "Glatt rasiert"},
		{id = "moustache", name = "Schnauzer"},
		{id = "full", name = "Vollbart"},
		{id = "goatee", name = "Kinnbart"},
	],
	glasses = [
		{id = "none", name = "Keine Brille"},
		{id = "glasses", name = "Brille"},
		{id = "sunglasses", name = "Sonnenbrille", unlock = "sunglasses"},
	],
	hat = [
		{id = "none", name = "Ohne"},
		{id = "cap", name = "Kappe"},
		{id = "hunter", name = "Jägerhut"},
		{id = "hunter_gams", name = "Jägerhut mit Gamsbart", unlock = "hunter_hat"},
		{id = "beanie", name = "Haube", unlock = "beanie"},
		{id = "work_helmet", name = "Bauhelm", unlock = "work_helmet"},
		{id = "fur_cap", name = "Fellmütze", unlock = "fur_cap"},
	],
	top = [
		{id = "shirt", name = "Hemd"},
		{id = "hoodie", name = "Kapuzenpulli", unlock = "hoodie"},
		{id = "trachten", name = "Trachtenjanker", unlock = "trachten"},
		{id = "hi_vis", name = "Warnweste", unlock = "hi_vis"},
		{id = "work_jacket", name = "Arbeitsjacke", unlock = "work_jacket"},
		{id = "jacket", name = "Lederjacke", unlock = "jacket"},
		{id = "leather_vest", name = "Lederweste", unlock = "leather_vest"},
		{id = "fur_coat", name = "Pelzmantel", unlock = "fur_coat"},
	],
	legs = [
		{id = "pants", name = "Hose"},
		{id = "work_pants", name = "Arbeitshose mit Werkzeuggurt", unlock = "work_pants"},
		{id = "lederhose", name = "Lederhose", unlock = "lederhose"},
	],
	back = [
		{id = "none", name = "Nichts"},
		{id = "backpack", name = "Rucksack"},
		{id = "fur_pack", name = "Fellrucksack", unlock = "fur_pack"},
	],
}

const PALETTES := {
	skin = [Color(0.98, 0.84, 0.72), Color(0.98, 0.80, 0.66), Color(0.90, 0.68, 0.52), Color(0.78, 0.56, 0.40), Color(0.60, 0.40, 0.27), Color(0.42, 0.28, 0.19)],
	hair_color = [Color(0.12, 0.10, 0.09), Color(0.30, 0.20, 0.12), Color(0.52, 0.34, 0.18), Color(0.85, 0.68, 0.40), Color(0.72, 0.30, 0.14), Color(0.62, 0.62, 0.62), Color(0.92, 0.92, 0.90)],
	shirt = [Color(0.35, 0.42, 0.25), Color(0.22, 0.30, 0.18), Color(0.78, 0.18, 0.14), Color(0.20, 0.32, 0.58), Color(0.92, 0.90, 0.85), Color(0.18, 0.18, 0.20), Color(0.95, 0.62, 0.15), Color(0.48, 0.30, 0.55), Color(0.55, 0.70, 0.82), Color(0.62, 0.48, 0.32)],
	pants = [Color(0.30, 0.26, 0.20), Color(0.20, 0.26, 0.42), Color(0.16, 0.16, 0.18), Color(0.36, 0.40, 0.26), Color(0.55, 0.48, 0.36), Color(0.45, 0.30, 0.18)],
	shoes = [Color(0.22, 0.16, 0.12), Color(0.12, 0.12, 0.13), Color(0.45, 0.32, 0.20), Color(0.30, 0.34, 0.24)],
	hat_color = [Color(0.22, 0.30, 0.18), Color(0.20, 0.22, 0.30), Color(0.55, 0.15, 0.12), Color(0.18, 0.18, 0.20), Color(0.85, 0.80, 0.70), Color(0.95, 0.55, 0.12)],
}

const COLOR_NAMES := {skin = "Hautton", hair_color = "Haarfarbe", shirt = "Farbe", pants = "Hosenfarbe", shoes = "Schuhe", hat_color = "Farbe"}

## Standard-Figur (neue Spieler)
const DEFAULT := {
	gender = "male", hair = "short", beard = "moustache", glasses = "none", hat = "hunter", top = "shirt", legs = "pants", back = "none",
	skin = Color(0.98, 0.80, 0.66), hair_color = Color(0.30, 0.20, 0.12), shirt = Color(0.35, 0.42, 0.25),
	pants = Color(0.30, 0.26, 0.20), shoes = Color(0.22, 0.16, 0.12), hat_color = Color(0.22, 0.30, 0.18),
}


## Fehlende Einträge auffüllen und alte Spielstände übernehmen (jacket = true -> Lederjacke)
static func normalize(o: Dictionary) -> Dictionary:
	var out := DEFAULT.duplicate()
	for k in o:
		out[k] = o[k]
	if o.get("jacket", false) and not o.has("top"):
		out.top = "jacket"
	out.erase("jacket")
	for k in ["skin", "hair_color", "shirt", "pants", "shoes", "hat_color"]:
		if out[k] is String:
			out[k] = Color.html(out[k])
	return out


static func style(key: String, id: String) -> Dictionary:
	for s in STYLES.get(key, []):
		if s.id == id:
			return s
	return {}


static func unlocked(key: String, id: String) -> bool:
	var s := style(key, id)
	if s.is_empty():
		return false
	if not s.has("unlock"):
		return true
	return GameState.has(s.unlock) or s.unlock in GameState.wardrobe


## Wie bekommt man das Teil? (für gesperrte Varianten im Editor)
static func unlock_hint(key: String, id: String) -> String:
	var s := style(key, id)
	if not s.has("unlock"):
		return ""
	var item: String = s.unlock
	if Items.RECIPES.has(item):
		var parts := []
		for k in Items.RECIPES[item]:
			parts.append("%dx %s" % [Items.RECIPES[item][k], Items.display(k)])
		return "An der Werkbank herstellen: " + ", ".join(parts)
	var shops: Array = Items.info(item).get("shops", [])
	if not shops.is_empty():
		return "Zu kaufen: %s, %d €" % [Items.SHOP_NAMES.get(shops[0], shops[0]), int(Items.info(item).price)]
	return "Noch nicht freigeschaltet"


## Nicht freigeschaltete Teile durch Standard ersetzen (z. B. nach dem Laden eines anderen Profils)
static func sanitize(o: Dictionary) -> Dictionary:
	var out := normalize(o)
	for key in STYLES:
		if key == "gender":
			continue
		if not unlocked(key, str(out.get(key, ""))):
			out[key] = DEFAULT[key] if unlocked(key, DEFAULT[key]) else STYLES[key][0].id
	return out


## Kleidungsstück aus dem Rucksack anziehen (oder wieder ausziehen)
static func wear(item: String) -> String:
	if not item in GameState.wardrobe:
		GameState.wardrobe.append(item)
	for key in STYLES:
		for s in STYLES[key]:
			if s.get("unlock", "") == item:
				var o := normalize(GameState.outfit)
				if o[key] == s.id:
					o[key] = DEFAULT[key] if DEFAULT[key] != s.id else STYLES[key][0].id
					GameState.outfit = o
					return "%s ausgezogen" % s.name
				o[key] = s.id
				GameState.outfit = o
				return "%s angezogen" % s.name
	return ""


# ------------------------------------------------------------------ Modelle
# Maße der 3D-Figur (gemessen): Kopf ist ein Würfel von ca. 0,53 m über dem Kopfknochen
# (x ±0,27, y 0,01 bis 0,54, z -0,24 bis 0,28), der Rumpf ca. 0,34 x 0,30 x 0,34 m über dem
# Rumpfknochen (x ±0,17, y 0 bis 0,30, z -0,15 bis 0,19). +Z zeigt nach vorne.

## Kopfschmuck, Haare, Bart, Brille (Ursprung: Kopfknochen)
static func build_head(parent: Node3D, o: Dictionary, female: bool, layer: int) -> void:
	var hair_c: Color = o.hair_color
	var hat_c: Color = o.hat_color
	var hat := str(o.hat)
	# Haare (die Frau hat eigene Haare im Modell)
	if not female and hat in ["none", "cap", "hunter", "hunter_gams"]:
		match str(o.hair):
			"short":
				_b(parent, Vector3(0.56, 0.05, 0.54), Vector3(0, 0.555, 0.02), hair_c, layer)
				_b(parent, Vector3(0.56, 0.22, 0.05), Vector3(0, 0.43, -0.255), hair_c, layer)
			"side":
				_b(parent, Vector3(0.56, 0.07, 0.54), Vector3(0, 0.565, 0.02), hair_c, layer)
				_b(parent, Vector3(0.3, 0.06, 0.12), Vector3(0.1, 0.56, 0.25), hair_c, layer, Vector3(0, 0, -0.15))
				_b(parent, Vector3(0.56, 0.26, 0.05), Vector3(0, 0.42, -0.255), hair_c, layer)
			"long":
				_b(parent, Vector3(0.57, 0.06, 0.55), Vector3(0, 0.56, 0.02), hair_c, layer)
				_b(parent, Vector3(0.57, 0.46, 0.06), Vector3(0, 0.33, -0.26), hair_c, layer)
				for s in [-1, 1]:
					_b(parent, Vector3(0.05, 0.3, 0.26), Vector3(0.29 * s, 0.38, -0.1), hair_c, layer)
	# Bart
	if not female:
		match str(o.beard):
			"moustache":
				_b(parent, Vector3(0.2, 0.04, 0.04), Vector3(0, 0.15, 0.295), hair_c, layer)
			"full":
				_b(parent, Vector3(0.5, 0.15, 0.05), Vector3(0, 0.1, 0.29), hair_c, layer)
				_b(parent, Vector3(0.26, 0.08, 0.06), Vector3(0, 0.01, 0.27), hair_c, layer)
				for s in [-1, 1]:
					_b(parent, Vector3(0.04, 0.2, 0.22), Vector3(0.275 * s, 0.16, 0.15), hair_c, layer)
			"goatee":
				_b(parent, Vector3(0.16, 0.03, 0.03), Vector3(0, 0.15, 0.295), hair_c, layer)
				_b(parent, Vector3(0.09, 0.1, 0.04), Vector3(0, 0.06, 0.29), hair_c, layer)
	# Brille
	match str(o.glasses):
		"glasses", "sunglasses":
			var frame_c := Color(0.12, 0.12, 0.13)
			var lens_c := Color(0.08, 0.08, 0.1) if o.glasses == "sunglasses" else Color(0.75, 0.88, 0.95)
			for s in [-1, 1]:
				_b(parent, Vector3(0.15, 0.1, 0.02), Vector3(0.12 * s, 0.29, 0.29), frame_c, layer)
				_b(parent, Vector3(0.11, 0.065, 0.02), Vector3(0.12 * s, 0.29, 0.297), lens_c, layer)
				_b(parent, Vector3(0.02, 0.02, 0.28), Vector3(0.28 * s, 0.31, 0.14), frame_c, layer)
			_b(parent, Vector3(0.08, 0.02, 0.02), Vector3(0, 0.31, 0.29), frame_c, layer)
	# Kopfbedeckung
	match hat:
		"cap":
			_b(parent, Vector3(0.58, 0.11, 0.56), Vector3(0, 0.59, 0.02), hat_c, layer)
			_b(parent, Vector3(0.42, 0.03, 0.2), Vector3(0, 0.55, 0.37), hat_c.darkened(0.2), layer)
		"hunter", "hunter_gams":
			_cyl(parent, 0.42, 0.42, 0.03, Vector3(0, 0.555, 0.02), Color(0.24, 0.30, 0.20), layer)
			_cyl(parent, 0.2, 0.27, 0.19, Vector3(0, 0.66, 0.02), Color(0.26, 0.33, 0.22), layer)
			_cyl(parent, 0.255, 0.27, 0.045, Vector3(0, 0.59, 0.02), Color(0.35, 0.22, 0.12), layer)
			_b(parent, Vector3(0.03, 0.22, 0.05), Vector3(-0.24, 0.7, -0.03), Color(0.18, 0.40, 0.20), layer, Vector3(0, 0, 0.4))
			if hat == "hunter_gams":
				var g := _sphere(parent, 0.075, Vector3(0, 0.79, -0.17), Color(0.42, 0.36, 0.30), layer)
				g.scale = Vector3(0.7, 1.6, 0.7)
				g.rotation.x = -0.35
		"beanie":
			_b(parent, Vector3(0.58, 0.14, 0.56), Vector3(0, 0.6, 0.02), hat_c, layer)
			_b(parent, Vector3(0.59, 0.05, 0.57), Vector3(0, 0.54, 0.02), hat_c.darkened(0.15), layer)
			_sphere(parent, 0.06, Vector3(0, 0.7, 0.02), hat_c.lightened(0.3), layer)
		"work_helmet":
			var dome := _sphere(parent, 0.33, Vector3(0, 0.54, 0.02), Color(0.98, 0.82, 0.12), layer)
			dome.scale = Vector3(1.0, 0.55, 0.9)
			_b(parent, Vector3(0.52, 0.02, 0.16), Vector3(0, 0.545, 0.33), Color(0.95, 0.78, 0.1), layer)
		"fur_cap":
			var fur := Color(0.45, 0.32, 0.2)
			_b(parent, Vector3(0.6, 0.16, 0.57), Vector3(0, 0.61, 0.02), fur, layer)
			_b(parent, Vector3(0.62, 0.06, 0.1), Vector3(0, 0.55, 0.27), fur.lightened(0.15), layer)
			for s in [-1, 1]:
				_b(parent, Vector3(0.05, 0.2, 0.22), Vector3(0.3 * s, 0.43, 0.0), fur, layer)
			_b(parent, Vector3(0.06, 0.13, 0.03), Vector3(0, 0.72, -0.12), fur.darkened(0.2), layer)  # Schwanz
		"police":
			_cyl(parent, 0.3, 0.29, 0.1, Vector3(0, 0.6, 0.02), Color(0.12, 0.16, 0.28), layer)
			_b(parent, Vector3(0.36, 0.02, 0.16), Vector3(0, 0.55, 0.33), Color(0.05, 0.05, 0.08), layer)


## Oberteil, Hosenteile und Rucksack (Ursprung: Rumpfknochen)
static func build_body(parent: Node3D, o: Dictionary, female: bool, layer: int) -> void:
	var w := 0.82 if female else 1.0
	var shirt: Color = o.shirt
	match str(o.top):
		"hoodie":
			_b(parent, Vector3(0.3 * w, 0.09, 0.14), Vector3(0, 0.31, -0.15), shirt.darkened(0.1), layer)  # Kapuze
			_b(parent, Vector3(0.18 * w, 0.06, 0.02), Vector3(0, 0.09, 0.2), shirt.darkened(0.15), layer)  # Tasche
			for s in [-1, 1]:
				_b(parent, Vector3(0.012, 0.09, 0.012), Vector3(0.03 * s, 0.24, 0.2), Color(0.95, 0.95, 0.95), layer)
		"trachten":
			var loden := Color(0.42, 0.46, 0.38)
			_shell(parent, w, 0.26, loden, layer)
			_b(parent, Vector3(0.03, 0.22, 0.02), Vector3(0, 0.18, 0.215), Color(0.18, 0.32, 0.2), layer)
			for k in 4:
				_sphere(parent, 0.012, Vector3(0.03, 0.26 - k * 0.05, 0.22), Color(0.85, 0.85, 0.82), layer)
			_b(parent, Vector3(0.36 * w, 0.03, 0.38), Vector3(0, 0.31, 0.02), Color(0.18, 0.32, 0.2), layer)
		"hi_vis":
			var neon := Color(0.85, 0.98, 0.15)
			_shell(parent, w, 0.22, neon, layer, false)
			for y in [0.12, 0.2]:
				_b(parent, Vector3(0.4 * w, 0.02, 0.4), Vector3(0, y, 0.02), Color(0.82, 0.84, 0.86), layer)
		"work_jacket":
			_shell(parent, w, 0.26, Color(0.16, 0.22, 0.36), layer)
			_b(parent, Vector3(0.4 * w, 0.03, 0.4), Vector3(0, 0.22, 0.02), Color(0.95, 0.5, 0.1), layer)
			_b(parent, Vector3(0.02, 0.22, 0.02), Vector3(0, 0.17, 0.215), Color(0.6, 0.6, 0.62), layer)
		"jacket":
			var leather := Color(0.45, 0.28, 0.16)
			_shell(parent, w, 0.26, leather, layer)
			_b(parent, Vector3(0.26 * w, 0.05, 0.06), Vector3(0, 0.31, 0.17), leather.darkened(0.2), layer)  # Kragen
			_b(parent, Vector3(0.02, 0.22, 0.02), Vector3(0.03, 0.17, 0.215), Color(0.7, 0.7, 0.7), layer)
		"leather_vest":
			var lv := Color(0.5, 0.33, 0.18)
			for s in [-1, 1]:
				_b(parent, Vector3(0.1 * w, 0.22, 0.38), Vector3(0.11 * w * s, 0.2, 0.02), lv, layer)
			_b(parent, Vector3(0.36 * w, 0.22, 0.04), Vector3(0, 0.2, -0.17), lv, layer)
		"fur_coat":
			var fur := Color(0.46, 0.34, 0.22)
			_shell(parent, w * 1.15, 0.3, fur, layer)
			_b(parent, Vector3(0.44 * w, 0.08, 0.44), Vector3(0, 0.3, 0.02), Color(0.86, 0.79, 0.66), layer)  # Fellkragen
			for k in 3:
				_b(parent, Vector3(0.05, 0.03, 0.02), Vector3(0, 0.22 - k * 0.07, 0.24), Color(0.25, 0.18, 0.1), layer)
	match str(o.legs):
		"work_pants":
			_b(parent, Vector3(0.39 * w, 0.04, 0.39), Vector3(0, 0.08, 0.02), Color(0.2, 0.18, 0.16), layer)  # Gurt
			_b(parent, Vector3(0.07, 0.08, 0.05), Vector3(0.16 * w, 0.04, 0.15), Color(0.55, 0.4, 0.2), layer)  # Tasche
			_b(parent, Vector3(0.015, 0.1, 0.015), Vector3(0.14 * w, 0.1, 0.19), Color(0.6, 0.6, 0.62), layer)  # Hammer
		"lederhose":
			var strap := Color(0.35, 0.22, 0.12)
			for s in [-1, 1]:
				_b(parent, Vector3(0.03, 0.24, 0.02), Vector3(0.07 * s, 0.19, 0.205), strap, layer)
				_b(parent, Vector3(0.03, 0.24, 0.02), Vector3(0.07 * s, 0.19, -0.165), strap, layer)
			_b(parent, Vector3(0.15, 0.03, 0.02), Vector3(0, 0.22, 0.212), Color(0.9, 0.85, 0.7), layer)  # Brustlatz
	match str(o.back):
		"backpack":
			_b(parent, Vector3(0.26 * w, 0.26, 0.13), Vector3(0, 0.17, -0.23), Color(0.3, 0.36, 0.24), layer)
			_b(parent, Vector3(0.2 * w, 0.08, 0.04), Vector3(0, 0.1, -0.31), Color(0.25, 0.3, 0.2), layer)
		"fur_pack":
			_b(parent, Vector3(0.28 * w, 0.28, 0.14), Vector3(0, 0.17, -0.24), Color(0.5, 0.36, 0.22), layer)
			_b(parent, Vector3(0.3 * w, 0.06, 0.16), Vector3(0, 0.33, -0.24), Color(0.3, 0.2, 0.12), layer)


## Jacke als Hülle um den Rumpf (+ Ärmelansatz)
static func _shell(parent: Node3D, w: float, h: float, c: Color, layer: int, sleeves := true) -> void:
	_b(parent, Vector3(0.38 * w, h, 0.38), Vector3(0, 0.31 - h * 0.5, 0.02), c, layer)
	if sleeves:
		for s in [-1, 1]:
			_b(parent, Vector3(0.08, 0.1, 0.13), Vector3(0.2 * w * s, 0.25, 0.02), c, layer)




static func _mat(c: Color) -> StandardMaterial3D:
	return Toon.solid(c, true, 0.012)


static func _b(parent: Node3D, sz: Vector3, pos: Vector3, c: Color, layer: int, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = sz
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _mat(c)
	mi.layers = layer
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, c: Color, layer: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	mi.layers = layer
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, pos: Vector3, c: Color, layer: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	mi.layers = layer
	parent.add_child(mi)
	return mi
