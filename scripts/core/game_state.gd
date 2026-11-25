extends Node
## Spielstand (Autoload "GameState"): Geld, Inventar, Werte der Spielfigur, Pickup, Haus,
## Aufträge sowie die gemeinsame Welt (Uhrzeit, Wetter, aufgestellte Dinge, gekaufte Häuser).
## Im Mehrspieler-Modus speichert der Server die gemeinsame Welt und je Spieler ein Profil.

signal money_changed(value: int)
signal inventory_changed
signal noise_made(pos: Vector3, radius: float, kind: String)
signal message(from: String, text: String)
signal world_changed  # aufgestellte Dinge oder Häuser haben sich geändert
signal stats_changed

const SAVE_DIR := "user://saves"
const DAY_MINUTES := 24.0  # ein Spieltag dauert 24 echte Minuten
const MAG_SIZE := 5

# ---------------------------------------------------------------- Spielerprofil
var player_name := "Jäger"
var money := 600
var inv := {}  # id -> Anzahl
var inv_layout := {}  # id -> [x, y] im Rucksack-Raster
var loaded := MAG_SIZE  # Patronen im Magazin
var health := 100.0
var stamina := 100.0
var bac := 0.0  # Promille / 1000 (0.05 = 0,5 Promille)
var smoke_time := 0.0  # Sekunden ruhige Hand nach einer Zigarette
var cough_timer := 0.0
var outfit := {gender = "male", shirt = Color(0.35, 0.42, 0.25), pants = Color(0.30, 0.26, 0.20), skin = Color(0.98, 0.80, 0.66), hat = "hunter", hat_color = Color(0.22, 0.30, 0.18), jacket = false}
var truck := {paint = 0, upgrades = {}, fuel = 70.0, damage = 0.0, cargo = []}
var house := -1  # Bauplatz-Nummer des eigenen Hauses
var furniture: Array = []  # [{id, pos:[x,y,z], rot}]
var house_chest := {}  # Inhalt der eingebauten Truhe im eigenen Haus: id -> Anzahl
var photos: Array = []  # Pfade unter user://photos
var story := {chapter = 1, step = 0, done = false}
var side_jobs: Array = []
var stats := {deer = 0, boar = 0, rabbit = 0, bear = 0, bottles = 0, fines = 0}
var minimap_on := true

# ---------------------------------------------------------------- gemeinsame Welt
var time := 7.0  # Uhrzeit in Stunden
var day := 1
var weather := "fog"  # clear, cloudy, fog, rain
var wetness := 0.2  # 0 trocken .. 1 alles Matsch
var placed: Array = []  # [{uid, type, pos:[x,y,z], rot, owner, data:{}}]
var houses := {}  # Bauplatz (String) -> {owner, type}
var police_heat := 0.0  # steigt bei Explosionen, Verfolgungen

var slot := "einzelspieler"
var slot_title := "Einzelspieler"
var playtime := 0.0  # Sekunden
var pending := {}  # Start nach dem Neuladen der Szene: {slot, new}
var _weather_timer := 600.0
var _autosave := 60.0
var _next_uid := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	playtime += delta
	# Uhr
	time += delta * 24.0 / (DAY_MINUTES * 60.0)
	if time >= 24.0:
		time -= 24.0
		day += 1
	# Wetter
	_weather_timer -= delta
	if _weather_timer <= 0.0 and not Net.is_client():
		_weather_timer = _rng.randf_range(300.0, 720.0)
		var r := _rng.randf()
		weather = "rain" if r < 0.25 else "cloudy" if r < 0.5 else "clear"
		if time > 4.0 and time < 9.0 and _rng.randf() < 0.6:
			weather = "fog"
	var wet_target := 1.0 if weather == "rain" else 0.0
	wetness = move_toward(wetness, wet_target, delta / (120.0 if weather == "rain" else 600.0))
	# Körper
	bac = maxf(0.0, bac - delta * 0.0004)  # ca. 1 Promille in 4 Minuten
	smoke_time = maxf(0.0, smoke_time - delta)
	stamina = minf(100.0, stamina + delta * 4.0)
	if smoke_time > 0.0:
		cough_timer -= delta
	police_heat = maxf(0.0, police_heat - delta * 0.01)
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = 90.0
		save_game()


func is_night() -> bool:
	return time < 5.5 or time > 20.5


func clock_text() -> String:
	return "%02d:%02d" % [int(time), int(fmod(time, 1.0) * 60.0)]


func new_uid() -> int:
	_next_uid += 1
	return _next_uid + randi() % 1000 * 100000


# ---------------------------------------------------------------- Geld und Inventar

func add_money(v: int) -> void:
	money += v
	money_changed.emit(money)


func can_pay(v: int) -> bool:
	return money >= v


func pay(v: int) -> bool:
	if money < v:
		return false
	add_money(-v)
	return true


func count(id: String) -> int:
	return inv.get(id, 0)


func has(id: String, n := 1) -> bool:
	return count(id) >= n


func give(id: String, n := 1) -> void:
	inv[id] = count(id) + n
	if inv[id] <= 0:
		inv.erase(id)
	inventory_changed.emit()


func take(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	give(id, -n)
	return true


## Kaufen im Laden. Gibt eine Meldung zurück ("" = gekauft).
func buy(id: String) -> String:
	var it := Items.info(id)
	if not pay(it.price):
		return "Zu wenig Geld"
	var n: int = it.get("gives", 1)
	if id == "ammo":
		give("ammo", n)
	elif id == "cigarettes":
		give("cigarettes", n)
	else:
		give(id, 1)
	return ""


func sell(id: String, price: int, n := 1) -> bool:
	if not take(id, n):
		return false
	add_money(price * n)
	return true


# ---------------------------------------------------------------- Geräusche (verscheuchen Wild, locken Polizei)

func make_noise(pos: Vector3, radius: float, kind := "") -> void:
	noise_made.emit(pos, radius, kind)


func notify(from: String, text: String) -> void:
	message.emit(from, text)


# ---------------------------------------------------------------- Konsum

## Trinken: erhöht den Alkoholspiegel. Gibt Text für die Anzeige zurück.
func drink(id: String) -> String:
	if not take(id):
		return ""
	bac += Items.info(id).get("alcohol", 0.03)
	stats_changed.emit()
	return "%s getrunken (%.1f ‰)" % [Items.display(id), promille()]


func smoke() -> String:
	if not take("cigarettes"):
		return ""
	smoke_time = 90.0
	cough_timer = _rng.randf_range(8.0, 25.0)
	stats_changed.emit()
	return "Zigarette: ruhige Hand, aber Husten verscheucht Wild"


func eat(id: String) -> String:
	if not take(id):
		return ""
	var it := Items.info(id)
	health = minf(100.0, health + it.get("heal", 10))
	stamina = minf(100.0, stamina + it.get("stamina", 20))
	stats_changed.emit()
	return "%s gegessen" % it.name


func promille() -> float:
	return bac * 10.0


## 0..1: wie stark die Welt schwankt
func drunkness() -> float:
	return clampf((bac - 0.02) / 0.25, 0.0, 1.0)


func damage(v: float) -> void:
	health = maxf(0.0, health - v)
	stats_changed.emit()


# ---------------------------------------------------------------- Welt

func place(type: String, pos: Vector3, rot: float, data := {}) -> Dictionary:
	var e := {uid = new_uid(), type = type, pos = [pos.x, pos.y, pos.z], rot = rot, owner = player_name, data = data}
	placed.append(e)
	world_changed.emit()
	return e


func remove_placed(uid: int) -> void:
	for i in placed.size():
		if placed[i].uid == uid:
			placed.remove_at(i)
			world_changed.emit()
			return


func find_placed(uid: int) -> Dictionary:
	for e in placed:
		if e.uid == uid:
			return e
	return {}


# ---------------------------------------------------------------- Speichern

func profile_dict() -> Dictionary:
	return {
		player_name = player_name, money = money, inv = inv, inv_layout = inv_layout, loaded = loaded, health = health, bac = bac,
		outfit = _colors_out(outfit), truck = truck, house = house, furniture = furniture, house_chest = house_chest, photos = photos,
		story = story, side_jobs = side_jobs, stats = stats, minimap_on = minimap_on,
	}


func world_dict() -> Dictionary:
	return {time = time, day = day, weather = weather, wetness = wetness, placed = placed, houses = houses}


func apply_profile(d: Dictionary) -> void:
	for k in d:
		if k == "outfit":
			outfit = _colors_in(d.outfit)
		elif k in self:
			set(k, d[k])
	# JSON liefert Zahlen als float
	for id in inv.keys():
		inv[id] = int(inv[id])
	money = int(money)
	loaded = int(loaded)
	house = int(house)
	money_changed.emit(money)
	inventory_changed.emit()


func apply_world(d: Dictionary) -> void:
	for k in d:
		if k in self:
			set(k, d[k])
	day = int(day)
	for e in placed:
		e.uid = int(e.uid)
	world_changed.emit()


## DebugTools kann beim Beenden schon freigegeben sein (Autoloads werden rückwärts entfernt)
func _debug_active() -> bool:
	var d := get_node_or_null("/root/DebugTools")
	return d != null and d.get("active") == true


func save_game() -> void:
	if (_debug_active() and not Net.is_dedicated()) or Net.is_client():
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var d := {version = 1, profile = profile_dict(), world = world_dict(),
		meta = {title = slot_title, player = player_name, day = day, money = money, chapter = story.get("chapter", 1), saved = Time.get_datetime_string_from_system(false, true), playtime = playtime}}
	if Net.is_server():
		d.profiles = Net.profiles
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, slot], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> bool:
	var p := "%s/%s.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(p):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	apply_profile(d.get("profile", {}))
	apply_world(d.get("world", {}))
	var m: Dictionary = d.get("meta", {})
	slot_title = m.get("title", slot)
	playtime = float(m.get("playtime", 0.0))
	if d.has("profiles"):
		Net.profiles = d.profiles
	return true


## Alle Spielstände: [{slot, title, player, day, money, chapter, saved}] (neueste zuerst)
static func list_saves() -> Array:
	var out := []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json") or f.begins_with("server_") or f == "dedicated.json":
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR.path_join(f)))
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = d.get("meta", {})
		out.append({slot = f.get_basename(), title = m.get("title", f.get_basename()), player = m.get("player", "?"),
			day = int(m.get("day", 1)), money = int(m.get("money", 0)), chapter = int(m.get("chapter", 1)), saved = str(m.get("saved", "")),
			time = FileAccess.get_modified_time(SAVE_DIR.path_join(f))})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out


static func delete_save(s: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [SAVE_DIR, s])


static func new_slot_name(title: String) -> String:
	var clean := ""
	for ch in title.to_lower():
		clean += ch if ch in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	return "%s_%d" % [clean.left(20), Time.get_unix_time_from_system()]


func reset_new_game() -> void:
	playtime = 0.0
	money = 600
	inv = {"pistol": 1, "assault_rifle": 1, "sniper": 1, "ammo": 80, "knife": 1, "flashlight": 1, "beer": 3, "cigarettes": 10, "snack": 2}
	loaded = MAG_SIZE
	health = 100.0
	stamina = 100.0
	bac = 0.0
	truck = {paint = 0, upgrades = {}, fuel = 70.0, damage = 0.0, cargo = [], trailer = false}
	house = -1
	furniture = []
	story = {chapter = 1, step = 0, done = false}
	side_jobs = []
	stats = {deer = 0, boar = 0, rabbit = 0, bear = 0, bottles = 0, fines = 0}
	time = 7.0
	day = 1
	weather = "fog"
	placed = []
	houses = {}


static func _colors_out(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[k] = d[k].to_html() if d[k] is Color else d[k]
	return o


static func _colors_in(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		var v = d[k]
		o[k] = Color.html(v) if v is String and k not in ["hat", "gender"] and Color.html_is_valid(v) else v
	return o
