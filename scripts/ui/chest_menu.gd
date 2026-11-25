class_name ChestMenu
extends RefCounted
## Truhe: Dinge aus dem Rucksack einlagern und wieder herausnehmen.
## storage ist ein Dictionary id -> Anzahl (eingebaute Truhe: GameState.house_chest,
## aufgestellte Truhen: data.items des Eintrags). on_change wird nach jeder Änderung aufgerufen.

static func open(game: Node, title: String, storage: Dictionary, on_change: Callable) -> void:
	var hud: Hud = game.hud
	var body := Menus.window(hud, title, 640)
	var reopen := func(): open(game, title, storage, on_change)
	Menus.heading(body, "In der Truhe")
	if storage.is_empty():
		Menus.text(body, "Leer.", 14)
	var stored := storage.keys()
	stored.sort()
	for id in stored:
		var n := int(storage[id])
		Menus.row(body, "%s  x%d" % [Items.display(id), n], "Herausnehmen", func():
			GameState.give(id, n)
			storage.erase(id)
			on_change.call()
			reopen.call())
	Menus.heading(body, "Im Rucksack")
	var ids := GameState.inv.keys()
	ids.sort()
	for key in ids:
		var id := str(key)
		if id in ["rifle", "knife"]:
			continue  # Ausrüstung bleibt am Mann
		var n := GameState.count(id)
		Menus.row(body, "%s  x%d" % [Items.display(id), n], "Einlagern", func():
			if GameState.take(id, n):
				storage[id] = int(storage.get(id, 0)) + n
				on_change.call()
			reopen.call())
