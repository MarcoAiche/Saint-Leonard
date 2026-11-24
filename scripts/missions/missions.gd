class_name Missions
extends Node
## Hauptgeschichte "Rettet das Gasthaus Pirtscher" (3 Kapitel) und Nebenaufträge
## (Bestellungen von Fleischerei und Gasthaus, Gestrandete, Festgefahrene, Mutproben der Tankstelle).
## Fortschritt liegt in GameState.story und GameState.side_jobs.

const CHAPTERS := [
	{title = "Kapitel 1: Ankommen", goals = [
		["talk", "Sprich mit Wirt Sepp vor dem Gasthaus Pirtscher"],
		["sold_meat", "Erlege ein Reh und verkaufe das Fleisch bei der Fleischerei in der Stadt"],
		["mud_tires", "Lass in der Werkstatt Geländereifen einbauen"],
		["house", "Kauf dir im Bauhaus ein Starterhaus für Saint Leonard"],
	]},
	{title = "Kapitel 2: Der geheime Kessel", goals = [
		["buy_still", "Kauf im Bauhaus einen Brennkessel-Bausatz"],
		["ingredients", "Kauf im Supermarkt Zucker (2), Hefe (1) und Obst (2)"],
		["place_still", "Stell den Kessel versteckt im Wald auf, weit weg vom Dorf"],
		["brew5", "Brenne mindestens 5 Flaschen Schwarzgebrannten"],
		["deliver5", "Bring 5 Flaschen zu Wirt Sepp (an der Polizei vorbei)"],
	]},
	{title = "Kapitel 3: Die Legende und das Fest", goals = [
		["legend", "Spür in den Südbergen den Riesenhirsch auf und erlege ihn"],
		["legend_deliver", "Bring das Geweih für die Trophäenwand zu Sepp"],
		["crates", "Kauf 4 Festkisten Bier im Supermarkt und bring sie mit dem Pickup zum Gasthaus"],
		["festival", "Großrazzia! Fahr nach 19 Uhr mit dem Pickup zum Fest beim Gasthaus"],
	]},
]
const STORY_TEXT := [
	"\"Servus! Schön, dass wieder wer Junger nach Saint Leonard zieht. Aber ich sag's dir ehrlich: Das Gasthaus ist pleite. Der Inspektor aus der Stadt will zusperren. Wenn du mir hilfst, hilf ich dir. Schau, dass du Fuß fasst: Geh jagen, verkauf das Fleisch beim Franz in der Stadt, mach deinen Pickup geländetauglich und kauf dir ein Häusl.\"",
	"\"Du hast dich gut eingelebt! Jetzt brauch ich was Stärkeres für die Gäste. Bau dir einen Brennkessel, irgendwo tief im Wald, wo keiner schaut. Und pass auf: Wenn der Kessel zu heiß wird, kracht's, und dann ist die Polizei da.\"",
	"\"Die Leut' reden nur noch von meinem Schnaps! Jetzt fehlt nur noch eins: Oben in den Bergen soll ein Riesenhirsch stehen. So ein Geweih an der Wand, und wir machen ein Fest, das die ganze Stadt sieht. Aber Vorsicht, der Inspektor schickt die Polizei.\"",
]

var game: Node
var _poll := 1.0
var _job_npcs := {}  # job id -> Node3D
var _dare_road_t := 0.0
var _festival_done := false


func setup(g: Node) -> void:
	game = g
	_refresh_side_npcs()


func chapter() -> Dictionary:
	var c: int = int(GameState.story.chapter) - 1
	if c < 0 or c >= CHAPTERS.size():
		return {}
	return CHAPTERS[c]


func goal_done(id: String) -> bool:
	return GameState.story.get("done_" + id, false)


func _complete(id: String) -> void:
	if goal_done(id):
		return
	var ch := chapter()
	var known := false
	for g in ch.get("goals", []):
		if g[0] == id:
			known = true
	if not known:
		return
	GameState.story["done_" + id] = true
	game.hud.toast("Auftrag erledigt!", 2.5)
	GameState.notify("Aufträge", "Erledigt: %s" % _goal_text(id))
	# Kapitel fertig?
	for g in ch.goals:
		if not goal_done(g[0]):
			return
	var reward: int = [300, 600, 1500][int(GameState.story.chapter) - 1]
	GameState.add_money(reward)
	GameState.notify("Wirt Sepp", "%s geschafft! Danke dir. %d € für dich." % [ch.title, reward])
	GameState.story.chapter = int(GameState.story.chapter) + 1
	if GameState.story.chapter > CHAPTERS.size():
		GameState.story.done = true
		GameState.notify("Wirt Sepp", "Das Gasthaus Pirtscher ist gerettet! Ab heute zahlt ihr bei mir nix mehr.")
	else:
		GameState.story.talked = false
	_on_chapter_start()


func _goal_text(id: String) -> String:
	for ch in CHAPTERS:
		for g in ch.goals:
			if g[0] == id:
				return g[1]
	return id


func _on_chapter_start() -> void:
	game.spawner.legend_wanted = int(GameState.story.chapter) == 3 and not goal_done("legend")
	if int(GameState.story.chapter) == 2:
		GameState.story.bottles_start = GameState.stats.bottles


## Liste der Ziele fürs Handy: [[Text, erledigt], ...]
func goals() -> Array:
	var out := []
	for g in chapter().get("goals", []):
		out.append([g[1], goal_done(g[0])])
	return out


func pub_talk_text() -> String:
	if GameState.story.get("done", false):
		return "Sepp: \"Auf Saint Leonard!\""
	var c: int = int(GameState.story.chapter)
	if not GameState.story.get("talked", false):
		return "Sepp hat dir was zu erzählen (%s)" % chapter().title
	if c == 2 and not goal_done("deliver5") and GameState.count("moonshine") >= 5:
		return "5 Flaschen Schwarzgebrannten abgeben"
	if c == 3 and not goal_done("legend_deliver") and GameState.has("legend_antlers"):
		return "Riesengeweih übergeben"
	if c == 3 and goal_done("legend_deliver") and not goal_done("crates") and GameState.count("crate") >= 4:
		return "4 Festkisten abliefern"
	for j in GameState.side_jobs:
		if j.type == "pub_order" and j.state == "active" and _has_need(j.need):
			return "Bestellung abliefern (%d €)" % j.reward
	return ""


func talk_to_pub() -> void:
	var c: int = int(GameState.story.chapter)
	if not GameState.story.get("done", false) and not GameState.story.get("talked", false):
		GameState.story.talked = true
		game.hud.show_dialog("Wirt Sepp", STORY_TEXT[clampi(c - 1, 0, 2)], [["Pack ma's!", func(): pass]])
		if c == 1:
			_complete("talk")
		if c == 3:
			game.spawner.legend_wanted = true
		return
	if c == 2 and GameState.count("moonshine") >= 5 and not goal_done("deliver5"):
		GameState.take("moonshine", 5)
		_complete("deliver5")
		return
	if c == 3 and GameState.has("legend_antlers") and not goal_done("legend_deliver"):
		GameState.take("legend_antlers")
		game.decorate_pub_trophy()
		_complete("legend_deliver")
		return
	if c == 3 and goal_done("legend_deliver") and GameState.count("crate") >= 4 and not goal_done("crates"):
		if not game.truck_near(game.landmarks.pub.door, 30.0):
			game.hud.toast("Der Pickup mit den Kisten muss vorm Gasthaus stehen")
			return
		GameState.take("crate", 4)
		_complete("crates")
		GameState.police_heat = 3.0
		GameState.notify("Polizeifunk", "Großkontrolle im ganzen Bezirk angeordnet!")
		return
	for j in GameState.side_jobs:
		if j.type == "pub_order" and j.state == "active" and _has_need(j.need):
			_finish_job(j)
			return


## Ereignisse aus dem Spiel
func event(name: String, data := {}) -> void:
	match name:
		"sold":
			if data.get("id", "") == "meat":
				_complete("sold_meat")
		"sold_carcass":
			_complete("sold_meat")
		"upgrade":
			if data.get("id", "") == "mud_tires":
				_complete("mud_tires")
		"house":
			_complete("house")
		"bought":
			if data.get("id", "") == "still":
				_complete("buy_still")
		"placed":
			if data.get("type", "") == "still":
				_complete("place_still")
		"legend_killed":
			_complete("legend")
	# Nebenaufträge an Läden abgeben
	if name == "shop_open":
		for j in GameState.side_jobs:
			if j.type == "butcher_order" and j.state == "active" and data.get("id", "") == "butcher" and _has_need(j.need):
				_finish_job(j)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or not game or not game.player:
		return
	_poll = 1.0
	if GameState.story.get("done", false):
		return
	var c: int = int(GameState.story.chapter)
	if c == 1 and GameState.house >= 0:
		_complete("house")
	if c == 2:
		if GameState.has("sugar", 2) and GameState.has("yeast") and GameState.has("fruit", 2):
			_complete("ingredients")
		if GameState.stats.bottles - int(GameState.story.get("bottles_start", 0)) >= 5:
			_complete("brew5")
		for e in GameState.placed:
			if e.type == "still":
				_complete("place_still")
	if c == 3:
		if GameState.has("legend_antlers"):
			_complete("legend")
		if goal_done("crates") and not goal_done("festival") and GameState.time >= 19.0 and game.driving and game.truck_near(game.landmarks.pub.door, 25.0):
			_complete("festival")
			game.start_festival()
	_update_side_jobs()


# ------------------------------------------------------------------ Nebenaufträge

func offers() -> Array:
	# pro Tag drei Angebote, bestimmt durch den Tag
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.day * 7919
	var out := []
	var types := ["butcher_order", "pub_order", "stranded", "stuck", "dare"]
	for k in 3:
		var t: String = types[rng.randi() % types.size()]
		var id := "%d_%d" % [GameState.day, k]
		var taken := false
		for j in GameState.side_jobs:
			if j.id == id:
				taken = true
		if not taken:
			out.append(_make_job(t, id, rng))
	return out


func _make_job(t: String, id: String, rng: RandomNumberGenerator) -> Dictionary:
	match t:
		"butcher_order":
			var n := rng.randi_range(2, 4)
			return {id = id, type = t, text = "Fleischerei Franz: Bring %d Stück Wildfleisch" % n, reward = 70 * n + 60, need = {meat = n}, state = "offer"}
		"pub_order":
			return {id = id, type = t, text = "Wirt Sepp: 2 Flaschen Schwarzgebrannter und 2 Grillfleisch", reward = 320, need = {moonshine = 2, meat_cooked = 2}, state = "offer"}
		"stranded":
			var p := _remote_spot(rng)
			return {id = id, type = t, text = "Pannenhilfe: Jemand hat in den Bergen keinen Sprit mehr. Bring einen Reservekanister.", reward = 180, target = [p.x, p.y], state = "offer"}
		"stuck":
			var p2 := _remote_spot(rng)
			return {id = id, type = t, text = "Festgefahren: Ein Bauer steckt im Matsch. Zieh ihn mit der Seilwinde raus.", reward = 220, target = [p2.x, p2.y], state = "offer"}
		_:
			var p3 := _remote_spot(rng, true)
			return {id = id, type = "dare", text = "Tankwart Hias: \"Bring die Kiste zur Hütte in den Bergen. Aber nur über Feldwege, ja?\"", reward = 380, target = [p3.x, p3.y], state = "offer"}


func _remote_spot(rng: RandomNumberGenerator, mountains := false) -> Vector2:
	var w: WorldBuilder = game.world
	for i in 200:
		var p := Vector2(rng.randf_range(-1800, 3000), rng.randf_range(-2000, 2600))
		if w.border_distance(p) < 100.0:
			continue
		if mountains and not game.landmarks.in_mountains(p):
			continue
		var info := w.road_info(p, 30.0)
		if info.tier >= WorldBuilder.TIER_DIRT:
			return info.pos
	return Vector2(400, 900)


func accept(job: Dictionary) -> void:
	var active := GameState.side_jobs.filter(func(j): return j.state == "active")
	if active.size() >= 3:
		game.hud.toast("Höchstens 3 Aufträge gleichzeitig")
		return
	job.state = "active"
	GameState.side_jobs.append(job)
	if job.type == "dare":
		GameState.give("crate")
		job.dirty = 0.0
	_refresh_side_npcs()
	GameState.notify("Aufträge", "Angenommen: %s" % job.text)
	if job.has("target"):
		game.set_waypoint(Vector2(job.target[0], job.target[1]))


func abandon(job: Dictionary) -> void:
	job.state = "failed"
	_refresh_side_npcs()


func _has_need(need: Dictionary) -> bool:
	for k in need:
		if GameState.count(k) < int(need[k]):
			return false
	return true


func _finish_job(j: Dictionary) -> void:
	for k in j.get("need", {}):
		GameState.take(k, int(j.need[k]))
	j.state = "done"
	GameState.add_money(int(j.reward))
	GameState.notify("Aufträge", "Erledigt: +%d €" % int(j.reward))
	game.hud.toast("Auftrag erledigt: +%d €" % int(j.reward), 3.0)
	_refresh_side_npcs()


func _update_side_jobs() -> void:
	for j in GameState.side_jobs:
		if j.state != "active":
			continue
		if j.type == "dare":
			# Asphalt ist verboten
			if game.driving and game.car.surface.tier in [WorldBuilder.TIER_MAIN, WorldBuilder.TIER_VILLAGE]:
				j.dirty = float(j.get("dirty", 0.0)) + 1.0
				if int(j.dirty) % 3 == 1:
					game.hud.toast("Mutprobe: Runter von der Straße! (%d/8)" % int(j.dirty))
				if j.dirty > 8.0:
					j.state = "failed"
					GameState.take("crate")
					GameState.notify("Tankwart Hias", "Haha, auf der Straße erwischt! Mutprobe verloren.")
			var t := Vector3(j.target[0], 0, j.target[1])
			var pp: Vector3 = game.player.global_position
			if Vector2(pp.x, pp.z).distance_to(Vector2(t.x, t.z)) < 25.0 and GameState.has("crate"):
				GameState.take("crate")
				_finish_job(j)


func _refresh_side_npcs() -> void:
	for id in _job_npcs.keys():
		if is_instance_valid(_job_npcs[id]):
			_job_npcs[id].queue_free()
	_job_npcs.clear()
	if not game or not game.world:
		return
	for j in GameState.side_jobs:
		if j.state != "active" or not j.has("target"):
			continue
		var p := Vector2(j.target[0], j.target[1])
		var w: WorldBuilder = game.world
		var holder := Node3D.new()
		game.add_child(holder)
		holder.global_position = Vector3(p.x, w.height_at(p.x, p.y), p.y)
		_job_npcs[j.id] = holder
		match j.type:
			"stranded", "stuck":
				var car := Placeables.model("crate")
				var body := Placeables.box(holder, Vector3(1.8, 1.3, 4.0), Vector3(3, 0.6 if j.type == "stranded" else 0.1, 0), Color(0.55, 0.6, 0.62), Vector3(0, 0.3, 0.12 if j.type == "stuck" else 0.0), true)
				body.name = "Auto"
				car.queue_free()
				var npc := Npc.new("Bauer Lois" if j.type == "stuck" else "Wanderin Resi", {shirt = Color(0.6, 0.3, 0.5), hat = "none"})
				holder.add_child(npc)
				var job: Dictionary = j
				if j.type == "stranded":
					game.interactions.add(Vector3.ZERO, 4.0, "Reservekanister übergeben", func():
						if GameState.take("jerrycan"):
							_finish_job(job)
						else:
							game.hud.toast("Du brauchst einen Reservekanister (Tankstelle)"), null, holder)
				else:
					game.interactions.add(Vector3(3, 0, 0), 9.0, "Mit der Seilwinde rausziehen", func():
						if game.truck_near(holder.global_position, 25.0) and GameState.truck.upgrades.has("winch"):
							_finish_job(job)
						else:
							game.hud.toast("Pickup mit Seilwinde in die Nähe bringen (Werkstatt: Seilwinde)"), null, holder)
			"dare":
				var hut := Node3D.new()
				holder.add_child(hut)
				Placeables.box(hut, Vector3(4, 2.6, 3.5), Vector3(0, 1.3, 0), Color(0.45, 0.30, 0.18), Vector3.ZERO, true)
				Placeables.box(hut, Vector3(4.6, 0.2, 4.2), Vector3(0, 2.9, 0), Color(0.3, 0.3, 0.32), Vector3(0.2, 0, 0))
