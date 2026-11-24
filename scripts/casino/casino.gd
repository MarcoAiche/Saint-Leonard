class_name Casino
extends Node
## Glücksspiel: Spielautomaten (Gasthaus, Tankstelle, Stadt, Feuerwehrhaus), Roulette (im
## Mehrspieler eine gemeinsame Runde für alle am Server) und die illegale Pokerrunde im
## Feuerwehrhaus Korpitsch (20 bis 4 Uhr) mit Razzia-Gefahr. Gespielt wird nur mit Spielgeld.

const SLOT_SYMBOLS := ["seven", "antlers", "hunter_hat", "edelweiss", "beer", "cherry"]
const SLOT_WEIGHTS := [1, 2, 3, 4, 5, 6]
const SLOT_PAY3 := {seven = 50, antlers = 25, hunter_hat = 15, edelweiss = 10, beer = 5, cherry = 3}
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const ROULETTE_BET_TIME := 20.0
const ROULETTE_SPIN_TIME := 6.0
const RAID_TIME := 20.0

var game: Node
var hall: FireHall
var poker: PokerGame  # läuft beim Server bzw. im Einzelspieler
var poker_view := {}  # zuletzt bekannter Tischzustand (für die Anzeige)
var at_poker := false
var poker_buyin := 0
var roulette_bets: Array = []  # eigene Einsätze [{label, numbers, pays, amount}]
var roulette_feed: Array = []  # Einsätze aller (Anzeige)
var roulette_phase := "bets"
var roulette_t := ROULETTE_BET_TIME
var roulette_last := -1
var raid_t := 0.0
var noise := 0.0  # wie auffällig die Spielrunde im Feuerwehrhaus ist
var _rng := RandomNumberGenerator.new()
var _ui: Control
var _poker_t := 0.0


func setup(g: Node, h: FireHall) -> void:
	game = g
	hall = h
	_rng.randomize()


func poker_open() -> bool:
	return GameState.time >= 20.0 or GameState.time < 4.0 or DebugTools.active


# ------------------------------------------------------------------ Spielautomat

func open_slots() -> void:
	var hud: Hud = game.hud
	var body := Menus.window(hud, "Spielautomat \"Goldener Hirsch\"", 560)
	var reels := SlotReels.new()
	reels.custom_minimum_size = Vector2(500, 190)
	body.add_child(reels)
	var info := Menus.text(body, "Drei gleiche: 7 = 50×, Geweih = 25×, Jägerhut = 15×, Edelweiß = 10×, Bier = 5×, Kirschen = 3×\nZwei gleiche: 1,2× (Kirschen 1,5×)", 14)
	info.custom_minimum_size.x = 500
	var result := Menus.text(body, "Einsatz wählen und drehen!", 20)
	var row := HBoxContainer.new()
	body.add_child(row)
	for bet in [1, 5, 10, 50, 100]:
		var b := Button.new()
		b.text = "%d € drehen" % bet
		b.disabled = not GameState.can_pay(bet)
		b.pressed.connect(func():
			if reels.spinning or not GameState.pay(bet):
				return
			Sfx.play_2d(body, Sfx.slot_spin(), -6.0)
			var res := [_slot_symbol(), _slot_symbol(), _slot_symbol()]
			result.text = "..."
			reels.spin(res, func():
				var win := _slot_payout(res, bet)
				if win > 0:
					GameState.add_money(win)
					result.text = "Gewonnen: %d €!" % win
					Sfx.play_2d(body, Sfx.jingle(win >= bet * 10), -4.0)
					if win >= bet * 25:
						game.hud.toast("JACKPOT! %d €" % win, 3.0)
				else:
					result.text = "Nix. Noch einmal?"
				for c in row.get_children():
					(c as Button).disabled = not GameState.can_pay(int((c as Button).text.to_int()))
				var money := body.get_parent().get_parent().find_child("Geld", true, false) as Label
				if money:
					money.text = "%d €" % GameState.money)
			GameState.make_noise(hall.global_position if hall and hall.inside(game.player.global_position) else game.player.global_position, 20.0, "slot"))
		row.add_child(b)


func _slot_symbol() -> String:
	var total := 0
	for w in SLOT_WEIGHTS:
		total += w
	var r := _rng.randi_range(1, total)
	for i in SLOT_SYMBOLS.size():
		r -= SLOT_WEIGHTS[i]
		if r <= 0:
			return SLOT_SYMBOLS[i]
	return "cherry"


static func _slot_payout(res: Array, bet: int) -> int:
	if res[0] == res[1] and res[1] == res[2]:
		return bet * int(SLOT_PAY3[res[0]])
	var counts := {}
	for s in res:
		counts[s] = counts.get(s, 0) + 1
	for s in counts:
		if counts[s] == 2:
			return int(bet * (1.5 if s == "cherry" else 1.2))
	return 0


# ------------------------------------------------------------------ Roulette

func open_roulette() -> void:
	var hud: Hud = game.hud
	var body := Menus.window(hud, "Roulette", 860)
	var wheel := RouletteWheel.new()
	wheel.custom_minimum_size = Vector2(820, 230)
	wheel.casino = self
	body.add_child(wheel)
	var chip := [5]
	var chips_row := HBoxContainer.new()
	body.add_child(chips_row)
	var chip_label := Label.new()
	chip_label.text = "Chip: 5 €"
	chip_label.custom_minimum_size.x = 110
	chips_row.add_child(chip_label)
	for v in [1, 5, 10, 50, 100]:
		var b := Button.new()
		b.text = "%d €" % v
		b.pressed.connect(func():
			chip[0] = v
			chip_label.text = "Chip: %d €" % v)
		chips_row.add_child(b)
	var status := Menus.text(body, "", 16)
	# Zahlenfeld
	var grid := GridContainer.new()
	grid.columns = 13
	body.add_child(grid)
	var zero := Button.new()
	zero.text = "0"
	zero.add_theme_stylebox_override("normal", _cell_style(Color(0.1, 0.5, 0.2)))
	zero.add_theme_color_override("font_color", Color.WHITE)
	zero.pressed.connect(func(): place_roulette_bet("0", [0], 36, chip[0]))
	grid.add_child(zero)
	for row in 3:
		if row > 0:
			grid.add_child(Control.new())
		for col in 12:
			var n := col * 3 + (3 - row)
			var b := Button.new()
			b.text = str(n)
			b.custom_minimum_size = Vector2(54, 34)
			b.add_theme_stylebox_override("normal", _cell_style(Color(0.75, 0.1, 0.1) if n in RED else Color(0.1, 0.1, 0.12)))
			b.add_theme_color_override("font_color", Color.WHITE)
			b.pressed.connect(func(): place_roulette_bet(str(n), [n], 36, chip[0]))
			grid.add_child(b)
	var outside := HFlowContainer.new()
	body.add_child(outside)
	var reds: Array = RED.duplicate()
	var blacks: Array = range(1, 37).filter(func(x): return not x in RED)
	var bets := [
		["Rot", reds, 2], ["Schwarz", blacks, 2],
		["Gerade", range(2, 37, 2), 2], ["Ungerade", range(1, 37, 2), 2],
		["1 bis 18", range(1, 19), 2], ["19 bis 36", range(19, 37), 2],
		["1. Dutzend", range(1, 13), 3], ["2. Dutzend", range(13, 25), 3], ["3. Dutzend", range(25, 37), 3],
	]
	for bt in bets:
		var b := Button.new()
		b.text = bt[0]
		b.pressed.connect(func(): place_roulette_bet(bt[0], bt[1], bt[2], chip[0]))
		outside.add_child(b)
	var spin := Button.new()
	spin.text = "Drehen!" if not Net.active() else "Die Kugel rollt alle %d s für alle" % int(ROULETTE_BET_TIME + ROULETTE_SPIN_TIME)
	spin.disabled = Net.active()
	spin.custom_minimum_size.y = 46
	spin.pressed.connect(func():
		if roulette_bets.is_empty():
			game.hud.toast("Zuerst setzen!")
			return
		_spin_roulette(_rng.randi_range(0, 36)))
	body.add_child(spin)
	var clear := Button.new()
	clear.text = "Einsätze zurücknehmen"
	clear.pressed.connect(func():
		if roulette_phase == "bets":
			for bt in roulette_bets:
				GameState.add_money(bt.amount)
			roulette_bets.clear())
	body.add_child(clear)
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	body.add_child(timer)
	timer.timeout.connect(func():
		var mine := 0
		for bt in roulette_bets:
			mine += bt.amount
		var t := "Deine Einsätze: %d €  (%s)" % [mine, ", ".join(roulette_bets.map(func(x): return "%d € %s" % [x.amount, x.label]))] if mine > 0 else "Keine Einsätze."
		if Net.active():
			t = ("Einsätze möglich: %d s\n" % ceili(roulette_t) if roulette_phase == "bets" else "Nichts geht mehr!\n") + t
			if not roulette_feed.is_empty():
				t += "\nAm Tisch: " + ", ".join(roulette_feed.slice(maxi(0, roulette_feed.size() - 6)))
		status.text = t
		wheel.queue_redraw())


static func _cell_style(c: Color) -> StyleBoxFlat:
	var sb := Hud._style(c, 1)
	sb.set_content_margin_all(4)
	sb.set_corner_radius_all(4)
	sb.shadow_size = 0
	return sb


func place_roulette_bet(label: String, numbers: Array, pays: int, amount: int) -> void:
	if roulette_phase != "bets":
		game.hud.toast("Nichts geht mehr!")
		return
	if not GameState.pay(amount):
		game.hud.toast("Zu wenig Geld")
		return
	roulette_bets.append({label = label, numbers = numbers, pays = pays, amount = amount})
	Sfx.play_2d(game, Sfx.chips(), -6.0)
	if Net.active():
		Net.roulette_bet("%s: %d € auf %s" % [GameState.player_name, amount, label])


## Kugel fällt auf result (im Mehrspieler vom Server bestimmt)
func _spin_roulette(result: int) -> void:
	roulette_phase = "spin"
	if Net.is_dedicated():
		# Server: nur den Takt weiterführen
		get_tree().create_timer(ROULETTE_SPIN_TIME).timeout.connect(func():
			roulette_phase = "bets"
			roulette_t = ROULETTE_BET_TIME)
		return
	Sfx.play_2d(game, Sfx.roulette_ball(), -4.0)
	get_tree().create_timer(ROULETTE_SPIN_TIME if Net.active() else 4.0).timeout.connect(func(): _roulette_result(result))
	roulette_last = -2  # dreht
	if hall and game.player and hall.inside(game.player.global_position):
		noise += 0.3


func _roulette_result(result: int) -> void:
	roulette_last = result
	var win := 0
	for bt in roulette_bets:
		if result in bt.numbers:
			win += bt.amount * bt.pays
	roulette_bets.clear()
	roulette_feed.clear()
	roulette_phase = "bets"
	roulette_t = ROULETTE_BET_TIME
	var col := "Grün" if result == 0 else ("Rot" if result in RED else "Schwarz")
	if win > 0:
		GameState.add_money(win)
		game.hud.toast("%d %s: Du gewinnst %d €!" % [result, col, win], 3.0)
		Sfx.play_2d(game, Sfx.jingle(win >= 100), -4.0)
	else:
		game.hud.toast("%d %s" % [result, col], 2.0)


## Server: gemeinsamer Roulette-Takt
func _process(delta: float) -> void:
	if Net.active():
		roulette_t -= delta
		if Net.is_server() and roulette_phase == "bets" and roulette_t <= 0.0:
			Net.roulette_spin(_rng.randi_range(0, 36))
	_process_poker(delta)
	_process_raid(delta)


func on_net_roulette_spin(result: int) -> void:
	_spin_roulette(result)


# ------------------------------------------------------------------ Poker

func open_poker() -> void:
	if not poker_open():
		game.hud.toast("Pokerrunde gibt's erst ab 20 Uhr (bis 4 Uhr früh)", 2.5)
		return
	if not at_poker:
		var hud: Hud = game.hud
		hud.show_dialog("Pokerrunde", "Texas Hold'em, Blinds 5/10. Mit wie viel Geld setzt du dich hin?\nAchtung: Wird die Runde zu laut, kommt die Polizei.", [
			["100 €", func(): _sit_poker(100)], ["250 €", func(): _sit_poker(250)], ["500 €", func(): _sit_poker(500)], ["Doch nicht", func(): pass]])
		return
	_show_poker_ui()


func _sit_poker(amount: int) -> void:
	if not GameState.pay(amount):
		game.hud.toast("Zu wenig Geld")
		return
	at_poker = true
	poker_buyin = amount
	if Net.is_client():
		Net.poker_cmd("sit", amount)
	else:
		_server_poker_cmd(GameState.player_name, Net.my_id(), "sit", amount)
	game.sit_down(hall.global_transform * (hall.poker_seat + Vector3(0, 0, 1.6)), hall.global_rotation.y + PI)
	_show_poker_ui()


func leave_poker() -> void:
	if not at_poker:
		return
	at_poker = false
	if Net.is_client():
		Net.poker_cmd("leave", 0)
	else:
		_server_poker_cmd(GameState.player_name, Net.my_id(), "leave", 0)
	game.stand_up()


func poker_action(action: String, amount := 0) -> void:
	if Net.is_client():
		Net.poker_cmd(action, amount)
	else:
		_server_poker_cmd(GameState.player_name, Net.my_id(), action, amount)


## Läuft auf dem Server bzw. im Einzelspieler
func _server_poker_cmd(pname: String, peer: int, cmd: String, amount: int) -> void:
	if poker == null:
		poker = PokerGame.new()
		poker.changed.connect(_broadcast_poker)
		poker.hand_finished.connect(func(s): _on_hand_finished(s))
		for n in PokerGame.NPCS.slice(0, 3):
			poker.add_player(n.name, _rng.randi_range(200, 450), true)
	match cmd:
		"sit":
			poker.add_player(pname, amount, false, peer)
			if poker.can_start():
				poker.start_hand()
		"leave":
			var chips := poker.remove_player(pname)
			_cash_out(pname, peer, chips)
		"seized":
			poker.remove_player(pname)  # Razzia: Chips beschlagnahmt
		_:
			var i := poker.index_of(pname)
			if i >= 0:
				poker.act(i, cmd, amount)
	_broadcast_poker()


func _cash_out(pname: String, peer: int, chips: int) -> void:
	if Net.is_server():
		Net.poker_cashout(peer, chips)
		return
	if pname == GameState.player_name or peer == Net.my_id():
		GameState.add_money(chips)
		game.hud.toast("Du stehst mit %d € auf (Einsatz war %d €)" % [chips, poker_buyin], 3.0)
	else:
		Net.poker_cashout(peer, chips)


func on_net_cashout(chips: int) -> void:
	GameState.add_money(chips)
	game.hud.toast("Du stehst mit %d € auf" % chips, 3.0)


func _broadcast_poker() -> void:
	if poker == null:
		return
	poker_view = poker.view_for(GameState.player_name)
	if Net.is_server():
		for p in poker.players:
			if not p.npc and not p.sitting_out and p.peer != 0 and Net.peers.has(p.peer):
				Net.poker_state(p.peer, poker.view_for(p.name))
	if is_instance_valid(_ui):
		_ui.queue_redraw()


func on_net_poker_state(view: Dictionary) -> void:
	poker_view = view
	if is_instance_valid(_ui):
		_ui.queue_redraw()


func _on_hand_finished(summary: String) -> void:
	noise += 1.0
	if hall:
		GameState.make_noise(hall.global_position, 40.0, "poker")
	# Razzia? Je länger und lauter, desto wahrscheinlicher
	var chance := 0.03 + noise * 0.012 + GameState.police_heat * 0.03
	if raid_t <= 0.0 and _rng.randf() < chance:
		start_raid()
	# nächste Hand nach einer kurzen Pause
	get_tree().create_timer(4.0).timeout.connect(func():
		if poker and poker.can_start() and _humans_at_table() > 0:
			poker.start_hand())
	if is_instance_valid(_ui):
		_ui.queue_redraw()
	if at_poker and not Net.is_client():
		game.hud.toast(summary.split("\n")[0], 3.0)


func _humans_at_table() -> int:
	var n := 0
	for p in poker.players:
		if not p.npc and not p.sitting_out:
			n += 1
	return n


func _process_poker(delta: float) -> void:
	if poker and not Net.is_client():
		poker.npc_step(delta)
		_poker_t += delta
	if at_poker and not poker_open() and not DebugTools.active:
		game.hud.toast("Sperrstunde! Die Pokerrunde löst sich auf.", 3.0)
		leave_poker()


func _show_poker_ui() -> void:
	var hud: Hud = game.hud
	var body := Menus.window(hud, "Pokerrunde im Feuerwehrhaus", 900)
	var table := PokerTable.new()
	table.casino = self
	table.custom_minimum_size = Vector2(860, 420)
	body.add_child(table)
	_ui = table
	var row := HBoxContainer.new()
	body.add_child(row)
	var raise := HSlider.new()
	raise.min_value = PokerGame.BIG
	raise.max_value = 500
	raise.step = 5
	raise.value = PokerGame.BIG * 2
	raise.custom_minimum_size = Vector2(200, 30)
	var raise_lbl := Label.new()
	raise_lbl.text = "+%d" % raise.value
	raise.value_changed.connect(func(v): raise_lbl.text = "+%d" % v)
	for a in [["Aussteigen", "fold"], ["Schieben / Mitgehen", "call"], ["Erhöhen", "raise"], ["Alles!", "allin"]]:
		var b := Button.new()
		b.text = a[0]
		b.pressed.connect(func():
			var act: String = a[1]
			if act == "call" and int(poker_view.get("current_bet", 0)) <= _my_bet():
				act = "check"
			poker_action(act, int(raise.value))
			Sfx.play_2d(body, Sfx.chips(), -8.0))
		row.add_child(b)
	row.add_child(raise)
	row.add_child(raise_lbl)
	var leave := Button.new()
	leave.text = "Aufstehen und auszahlen"
	leave.pressed.connect(func():
		leave_poker()
		Menus.close_all(hud))
	body.add_child(leave)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	body.add_child(t)
	t.timeout.connect(func(): table.queue_redraw())


func _my_bet() -> int:
	for p in poker_view.get("players", []):
		if p.name == GameState.player_name:
			return int(p.bet)
	return 0


# ------------------------------------------------------------------ Razzia

func start_raid() -> void:
	if Net.is_server():
		print("[Server] Razzia im Feuerwehrhaus!")
		raid_t = RAID_TIME + 60.0  # Pause bis zur nächsten möglichen Razzia
		Net.raid()
		return
	on_raid()


func on_raid() -> void:
	if raid_t > 0.0:
		return
	raid_t = RAID_TIME
	noise = 0.0
	game.hud.set_alert("RAZZIA! Polizei unterwegs zum Feuerwehrhaus (%d s)" % int(RAID_TIME))
	Sfx.play_2d(game, Sfx.siren(), -6.0)
	GameState.notify("Kommandant Ferdl", "Heast, de Polizei kummt! Schnell weg do!")
	if game.police and hall:
		game.police.dispatch(hall.door, "Illegales Glücksspiel im Feuerwehrhaus Korpitsch")


func _process_raid(delta: float) -> void:
	if raid_t <= 0.0:
		return
	if Net.is_dedicated():
		raid_t -= delta
		return
	raid_t -= delta
	game.hud.set_alert("RAZZIA! Polizei kommt (%d s): weg vom Feuerwehrhaus!" % ceili(raid_t))
	if raid_t <= 0.0:
		game.hud.set_alert("")
		var caught: bool = hall != null and game.player != null and hall.inside(game.player.global_position)
		if caught:
			var lost := 0
			if at_poker:
				at_poker = false
				if poker and not Net.is_client():
					poker.remove_player(GameState.player_name)  # Chips werden beschlagnahmt
				elif Net.is_client():
					Net.poker_cmd("seized", 0)
				lost = poker_buyin
				game.stand_up()
				Menus.close_all(game.hud)
			for bt in roulette_bets:
				lost += bt.amount
			roulette_bets.clear()
			game.police._fine(300)
			game.hud.show_dialog("Razzia!", "Erwischt beim illegalen Glücksspiel.\nDer Einsatz (%d €) wird beschlagnahmt, dazu 300 € Strafe." % lost, [["Mist", func(): pass]])
		else:
			game.hud.toast("Glück gehabt, die Polizei hat niemanden erwischt.", 3.0)


# ------------------------------------------------------------------ Anzeigen

class SlotReels extends Control:
	var spinning := false
	var _shown := ["seven", "beer", "cherry"]
	var _t := 0.0
	var _target: Array = []
	var _cb: Callable
	var _stops := [0.8, 1.3, 1.8]

	func spin(result: Array, cb: Callable) -> void:
		spinning = true
		_target = result
		_cb = cb
		_t = 0.0

	func _process(delta: float) -> void:
		if not spinning:
			return
		_t += delta
		for i in 3:
			if _t < _stops[i]:
				_shown[i] = Casino.SLOT_SYMBOLS[randi() % Casino.SLOT_SYMBOLS.size()]
			else:
				_shown[i] = _target[i]
		queue_redraw()
		if _t >= _stops[2] + 0.1:
			spinning = false
			_cb.call()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.05, 0.08))
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(0.95, 0.8, 0.2), false, 4.0)
		var w := (size.x - 60) / 3.0
		for i in 3:
			var r := Rect2(Vector2(20 + i * (w + 10), 20), Vector2(w, size.y - 40))
			draw_rect(r, Color(0.97, 0.95, 0.9))
			draw_rect(r, Color(0.2, 0.2, 0.2), false, 2.0)
			var s: String = _shown[i]
			var inner := r.grow(-25)
			match s:
				"seven":
					draw_string(get_theme_default_font(), inner.get_center() + Vector2(-22, 32), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(0.85, 0.1, 0.1))
				"cherry":
					draw_line(inner.get_center() + Vector2(-15, 10), inner.get_center() + Vector2(5, -35), Color(0.2, 0.5, 0.2), 4.0)
					draw_line(inner.get_center() + Vector2(20, 10), inner.get_center() + Vector2(5, -35), Color(0.2, 0.5, 0.2), 4.0)
					draw_circle(inner.get_center() + Vector2(-15, 20), 20, Color(0.8, 0.05, 0.1))
					draw_circle(inner.get_center() + Vector2(20, 20), 20, Color(0.8, 0.05, 0.1))
				"edelweiss":
					for k in 8:
						var a := TAU * k / 8.0
						draw_circle(inner.get_center() + Vector2(cos(a), sin(a)) * 28, 16, Color(0.98, 0.98, 0.98))
						draw_arc(inner.get_center() + Vector2(cos(a), sin(a)) * 28, 16, 0, TAU, 12, Color(0.6, 0.6, 0.6), 1.5)
					draw_circle(inner.get_center(), 14, Color(0.9, 0.8, 0.3))
				_:
					ItemIcons.draw_icon(self, inner, s)
		if spinning:
			for i in 3:
				if _t < _stops[i]:
					var r2 := Rect2(Vector2(20 + i * (w + 10), 20), Vector2(w, size.y - 40))
					for k in 6:
						var y := fmod(_t * 900.0 + k * 30.0, r2.size.y)
						draw_line(Vector2(r2.position.x, r2.position.y + y), Vector2(r2.end.x, r2.position.y + y), Color(0, 0, 0, 0.15), 3.0)


class RouletteWheel extends Control:
	var casino: Casino
	var _angle := 0.0

	func _process(delta: float) -> void:
		if casino and casino.roulette_last == -2:
			_angle += delta * 9.0
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.35, 0.18))
		var c := Vector2(130, size.y * 0.5)
		var r := size.y * 0.45
		draw_circle(c, r + 8, Color(0.35, 0.2, 0.1))
		var order := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
		for i in order.size():
			var a0 := _angle + TAU * i / order.size()
			var a1 := _angle + TAU * (i + 1) / order.size()
			var n: int = order[i]
			var col := Color(0.1, 0.55, 0.2) if n == 0 else (Color(0.75, 0.08, 0.08) if n in Casino.RED else Color(0.08, 0.08, 0.1))
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]), col)
		draw_circle(c, r * 0.45, Color(0.45, 0.28, 0.12))
		draw_circle(c, r * 0.15, Color(0.85, 0.7, 0.3))
		if casino.roulette_last == -2:
			var ba := -_angle * 1.7
			draw_circle(c + Vector2(cos(ba), sin(ba)) * r * 0.82, 6, Color.WHITE)
		var font := get_theme_default_font()
		var txt := "Letzte Zahl: -" if casino.roulette_last < 0 else "Letzte Zahl: %d" % casino.roulette_last
		if casino.roulette_last == -2:
			txt = "Die Kugel rollt ..."
		draw_string(font, Vector2(280, 60), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		draw_string(font, Vector2(280, 100), "Zahl: 35 zu 1   Dutzend: 2 zu 1   Rot/Schwarz, Gerade/Ungerade, 1-18/19-36: 1 zu 1", HORIZONTAL_ALIGNMENT_LEFT, 520, 14, Color(0.9, 0.95, 0.9))
		draw_string(font, Vector2(280, 140), "Geld: %d €" % GameState.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))


class PokerTable extends Control:
	var casino: Casino

	func _card(pos: Vector2, c: int, big := false) -> void:
		var sz := Vector2(52, 74) if big else Vector2(40, 56)
		var r := Rect2(pos, sz)
		if c < 0:
			draw_rect(r, Color(0.6, 0.1, 0.12))
			draw_rect(r.grow(-4), Color(0.85, 0.75, 0.3), false, 2.0)
			return
		draw_rect(r, Color(0.98, 0.97, 0.94))
		draw_rect(r, Color(0.2, 0.2, 0.2), false, 1.5)
		var col := Color(0.8, 0.05, 0.05) if PokerGame.is_red(c) else Color(0.08, 0.08, 0.1)
		draw_string(get_theme_default_font(), pos + Vector2(5, 26 if big else 22), PokerGame.card_name(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 18, col)

	func _draw() -> void:
		var v: Dictionary = casino.poker_view
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.1, 0.08))
		var center := size * 0.5
		var font := get_theme_default_font()
		var pts := PackedVector2Array()
		for k in 48:
			var a := TAU * k / 48.0
			pts.append(center + Vector2(cos(a) * size.x * 0.42, sin(a) * size.y * 0.36))
		draw_colored_polygon(pts, Color(0.08, 0.38, 0.2))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.4, 0.25, 0.12), 10.0)
		if v.is_empty():
			draw_string(font, center + Vector2(-120, 0), "Warte auf die nächste Hand ...", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			return
		var comm: Array = v.community
		for i in comm.size():
			_card(center + Vector2(-140 + i * 58, -40), comm[i], true)
		draw_string(font, center + Vector2(-60, 60), "Pot: %d €" % v.pot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))
		var street_names := ["Preflop", "Flop", "Turn", "River", "Showdown"]
		if int(v.street) >= 0:
			draw_string(font, center + Vector2(-60, -60), street_names[clampi(int(v.street), 0, 4)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.95, 0.85))
		var ps: Array = v.players
		for i in ps.size():
			var p: Dictionary = ps[i]
			var a := PI * 0.5 + TAU * i / maxf(ps.size(), 1)
			var pos := center + Vector2(cos(a) * size.x * 0.4, sin(a) * size.y * 0.38) - Vector2(60, 30)
			var me: bool = p.name == GameState.player_name
			var box := Rect2(pos, Vector2(130, 92))
			draw_rect(box, Color(0.98, 0.78, 0.25, 0.9) if int(v.turn) == i else Color(0, 0, 0, 0.55))
			draw_string(font, pos + Vector2(6, 18), ("%s%s" % [p.name, " (D)" if int(v.dealer) == i else ""]), HORIZONTAL_ALIGNMENT_LEFT, 120, 15, Color(0.1, 0.1, 0.1) if int(v.turn) == i else Color.WHITE)
			var status := "raus" if p.folded else ("ALL-IN" if p.all_in else "%d €" % p.chips)
			draw_string(font, pos + Vector2(6, 36), status + ("  Einsatz %d" % p.bet if p.bet > 0 else ""), HORIZONTAL_ALIGNMENT_LEFT, 124, 13, Color(0.1, 0.1, 0.1) if int(v.turn) == i else Color(0.9, 0.9, 0.8))
			var hole: Array = p.hole
			for k in hole.size():
				_card(pos + Vector2(6 + k * 44, 40), hole[k], false)
			if p.hand != "":
				draw_string(font, pos + Vector2(6, 108), p.hand, HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color(1, 0.95, 0.6))
			if me:
				draw_rect(box, Color(0.3, 0.8, 1.0), false, 2.0)
		var lines: Array = v.log
		for k in mini(lines.size(), 6):
			draw_string(font, Vector2(10, 18 + k * 16), lines[lines.size() - mini(lines.size(), 6) + k], HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Color(0.85, 0.85, 0.8))
