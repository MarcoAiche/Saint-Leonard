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
var slot_bet := 10
var slot_history: Array = []  # [{bet, win, text}]
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

static func _slot_box_style(bg: Color, border_col: Color, border_w := 1, radius := 12, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func _slot_btn(text: String, bg: Color, fg: Color, border_col: Color, pad_x := 16, pad_y := 8, radius := 10) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.54))
	var n := _slot_box_style(bg, border_col, 1, radius, pad_y)
	n.content_margin_left = pad_x
	n.content_margin_right = pad_x
	var h := _slot_box_style(bg.lightened(0.08), border_col.lightened(0.15), 1, radius, pad_y)
	h.content_margin_left = pad_x
	h.content_margin_right = pad_x
	var d := _slot_box_style(Color(0.10, 0.12, 0.15, 0.7), Color(1, 1, 1, 0.05), 1, radius, pad_y)
	d.content_margin_left = pad_x
	d.content_margin_right = pad_x
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	return b


func open_slots() -> void:
	var hud: Hud = game.hud
	Menus.close_all(hud)
	var gold := Color(0.95, 0.79, 0.31)
	var emerald := Color(0.06, 0.73, 0.51)
	var text_main := Color(0.88, 0.90, 0.94)
	var text_dim := Color(0.62, 0.66, 0.74)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.05, 0.07, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.menu_root.add_child(backdrop)

	var win_panel := PanelContainer.new()
	win_panel.custom_minimum_size = Vector2(1260, 0)
	win_panel.add_theme_stylebox_override("panel", _slot_box_style(Color(0.06, 0.08, 0.11, 0.98), Color(0.95, 0.79, 0.31, 0.45), 2, 18, 0))
	backdrop.add_child(win_panel)
	Hud._anchor(win_panel, Control.PRESET_CENTER, 0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 0)
	win_panel.add_child(root_vb)

	# --- TOP HEADER ---
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _slot_box_style(Color(0.04, 0.06, 0.08, 0.98), Color(0.95, 0.79, 0.31, 0.2), 1, 16, 16))
	root_vb.add_child(header_panel)
	var header_hb := HBoxContainer.new()
	header_hb.add_theme_constant_override("separation", 16)
	header_panel.add_child(header_hb)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vb.add_theme_constant_override("separation", 2)
	header_hb.add_child(title_vb)
	var title_l := Label.new()
	title_l.text = "SPIELAUTOMAT GOLDENER HIRSCH"
	title_l.add_theme_font_size_override("font_size", 22)
	title_l.add_theme_color_override("font_color", gold)
	title_vb.add_child(title_l)
	var sub_l := Label.new()
	sub_l.text = "SAINT LEONARD"
	sub_l.add_theme_font_size_override("font_size", 11)
	sub_l.add_theme_color_override("font_color", Color(0.95, 0.79, 0.31, 0.7))
	title_vb.add_child(sub_l)

	var cash_box := PanelContainer.new()
	cash_box.add_theme_stylebox_override("panel", _slot_box_style(Color(0.02, 0.09, 0.05, 0.95), Color(0.06, 0.73, 0.51, 0.35), 1, 10, 10))
	header_hb.add_child(cash_box)
	var cash_hb := HBoxContainer.new()
	cash_hb.add_theme_constant_override("separation", 8)
	cash_box.add_child(cash_hb)
	var cash_cap := Label.new()
	cash_cap.text = "GUTHABEN:"
	cash_cap.add_theme_font_size_override("font_size", 12)
	cash_cap.add_theme_color_override("font_color", emerald)
	cash_hb.add_child(cash_cap)
	var money_lbl := Label.new()
	money_lbl.name = "Geld"
	money_lbl.text = "$%d" % GameState.money
	money_lbl.add_theme_font_size_override("font_size", 18)
	money_lbl.add_theme_color_override("font_color", Color.WHITE)
	cash_hb.add_child(money_lbl)

	var close_top := _slot_btn("Schließen [Esc]", Color(0.14, 0.16, 0.20), text_main, Color(1, 1, 1, 0.14), 14, 9, 10)
	close_top.add_theme_font_size_override("font_size", 13)
	close_top.pressed.connect(func(): Menus.close_all(hud))
	header_hb.add_child(close_top)

	# --- 3-COLUMN ARENA ---
	var arena_margin := MarginContainer.new()
	arena_margin.add_theme_constant_override("margin_left", 20)
	arena_margin.add_theme_constant_override("margin_right", 20)
	arena_margin.add_theme_constant_override("margin_top", 18)
	arena_margin.add_theme_constant_override("margin_bottom", 18)
	root_vb.add_child(arena_margin)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 18)
	arena_margin.add_child(arena)

	# LEFT CARD: Gewinn-Legende
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(290, 0)
	left_card.add_theme_stylebox_override("panel", _slot_box_style(Color(0.08, 0.10, 0.13, 0.96), Color(0.95, 0.79, 0.31, 0.22), 1, 14, 14))
	arena.add_child(left_card)
	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 8)
	left_card.add_child(left_vb)

	var leg_title := Label.new()
	leg_title.text = "Gewinn-Legende"
	leg_title.add_theme_font_size_override("font_size", 20)
	leg_title.add_theme_color_override("font_color", gold)
	left_vb.add_child(leg_title)

	var cap3 := Label.new()
	cap3.text = "3 GLEICHE"
	cap3.add_theme_font_size_override("font_size", 13)
	cap3.add_theme_color_override("font_color", Color(0.95, 0.79, 0.31, 0.85))
	left_vb.add_child(cap3)

	var legend_rows := [
		["7  Kaiserliche 7", "50×", Color(0.95, 0.42, 0.42)],
		["Geweih", "25×", gold],
		["Jägerhut", "15×", Color(0.25, 0.82, 0.55)],
		["Edelweiß", "10×", Color(0.55, 0.82, 0.98)],
		["Bier", "5×", Color(0.98, 0.72, 0.25)],
		["Kirschen", "3×", Color(0.96, 0.45, 0.55)],
	]
	for lr in legend_rows:
		var rbox := PanelContainer.new()
		rbox.add_theme_stylebox_override("panel", _slot_box_style(Color(0.13, 0.15, 0.19, 0.75), Color(1, 1, 1, 0.06), 1, 8, 8))
		left_vb.add_child(rbox)
		var rhb := HBoxContainer.new()
		rbox.add_child(rhb)
		var nl := Label.new()
		nl.text = lr[0]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", lr[2])
		rhb.add_child(nl)
		var ml := Label.new()
		ml.text = lr[1]
		ml.add_theme_font_size_override("font_size", 16)
		ml.add_theme_color_override("font_color", gold)
		rhb.add_child(ml)

	var cap2 := Label.new()
	cap2.text = "2 GLEICHE"
	cap2.add_theme_font_size_override("font_size", 13)
	cap2.add_theme_color_override("font_color", Color(0.95, 0.79, 0.31, 0.85))
	left_vb.add_child(cap2)
	for lr2 in [["2 Beliebige", "1,2×"], ["2× Kirschen", "1,5×"]]:
		var rbox2 := PanelContainer.new()
		rbox2.add_theme_stylebox_override("panel", _slot_box_style(Color(0.11, 0.13, 0.17, 0.65), Color(1, 1, 1, 0.05), 1, 8, 8))
		left_vb.add_child(rbox2)
		var rhb2 := HBoxContainer.new()
		rbox2.add_child(rhb2)
		var nl2 := Label.new()
		nl2.text = lr2[0]
		nl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl2.add_theme_font_size_override("font_size", 15)
		nl2.add_theme_color_override("font_color", text_dim)
		rhb2.add_child(nl2)
		var ml2 := Label.new()
		ml2.text = lr2[1]
		ml2.add_theme_font_size_override("font_size", 15)
		ml2.add_theme_color_override("font_color", gold)
		rhb2.add_child(ml2)

	var pay_note := Label.new()
	pay_note.text = "Gewinnlinie: Mitte waagerecht (1 Payline)"
	pay_note.add_theme_font_size_override("font_size", 13)
	pay_note.add_theme_color_override("font_color", text_dim)
	pay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vb.add_child(pay_note)

	# CENTER CABINET
	var cab := PanelContainer.new()
	cab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_theme_stylebox_override("panel", _slot_box_style(Color(0.09, 0.11, 0.14, 0.98), Color(0.95, 0.79, 0.31, 0.42), 2, 16, 16))
	arena.add_child(cab)
	var cab_vb := VBoxContainer.new()
	cab_vb.add_theme_constant_override("separation", 12)
	cab.add_child(cab_vb)

	var plaque := PanelContainer.new()
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plaque.add_theme_stylebox_override("panel", _slot_box_style(Color(0.06, 0.08, 0.11), Color(0.95, 0.79, 0.31, 0.55), 1, 18, 8))
	cab_vb.add_child(plaque)
	var plaque_lbl := Label.new()
	plaque_lbl.text = "  ★  GOLDENER HIRSCH  ★  "
	plaque_lbl.add_theme_font_size_override("font_size", 17)
	plaque_lbl.add_theme_color_override("font_color", gold)
	plaque.add_child(plaque_lbl)

	var reels := SlotReels.new()
	reels.custom_minimum_size = Vector2(520, 300)
	cab_vb.add_child(reels)

	var cab_foot := HBoxContainer.new()
	cab_vb.add_child(cab_foot)
	var cf_l := Label.new()
	cf_l.text = "KLASSISCHER WALZENLAUF"
	cf_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cf_l.add_theme_font_size_override("font_size", 11)
	cf_l.add_theme_color_override("font_color", text_dim)
	cab_foot.add_child(cf_l)
	var cf_r := Label.new()
	cf_r.text = "SAINT LEONARD"
	cf_r.add_theme_font_size_override("font_size", 11)
	cf_r.add_theme_color_override("font_color", Color(0.95, 0.79, 0.31, 0.8))
	cab_foot.add_child(cf_r)

	# RIGHT CARD: Ergebnis & Letzte Runden
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(290, 0)
	right_card.add_theme_stylebox_override("panel", _slot_box_style(Color(0.08, 0.10, 0.13, 0.96), Color(0.95, 0.79, 0.31, 0.22), 1, 14, 14))
	arena.add_child(right_card)
	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	right_card.add_child(right_vb)

	var res_title := Label.new()
	res_title.text = "Ergebnis & Runden"
	res_title.add_theme_font_size_override("font_size", 20)
	res_title.add_theme_color_override("font_color", gold)
	right_vb.add_child(res_title)

	var res_box := PanelContainer.new()
	res_box.add_theme_stylebox_override("panel", _slot_box_style(Color(0.06, 0.08, 0.11), Color(0.95, 0.79, 0.31, 0.3), 1, 10, 12))
	right_vb.add_child(res_box)
	var res_vb := VBoxContainer.new()
	res_vb.add_theme_constant_override("separation", 4)
	res_box.add_child(res_vb)
	var res_cap := Label.new()
	res_cap.text = "RUNDENERGEBNIS"
	res_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_cap.add_theme_font_size_override("font_size", 12)
	res_cap.add_theme_color_override("font_color", text_dim)
	res_vb.add_child(res_cap)
	var result := Label.new()
	result.text = "Bereit!"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", 21)
	result.add_theme_color_override("font_color", gold)
	res_vb.add_child(result)
	var result_sub := Label.new()
	result_sub.text = "Einsatz wählen und drehen"
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_sub.add_theme_font_size_override("font_size", 14)
	result_sub.add_theme_color_override("font_color", text_dim)
	res_vb.add_child(result_sub)

	var hist_cap := Label.new()
	hist_cap.text = "LETZTE 4 RUNDEN"
	hist_cap.add_theme_font_size_override("font_size", 13)
	hist_cap.add_theme_color_override("font_color", text_dim)
	right_vb.add_child(hist_cap)

	var hist_box := VBoxContainer.new()
	hist_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist_box.add_theme_constant_override("separation", 6)
	right_vb.add_child(hist_box)

	var render_history := func():
		for c in hist_box.get_children():
			c.queue_free()
		if slot_history.is_empty():
			var empty_l := Label.new()
			empty_l.text = "Noch keine Runden gespielt."
			empty_l.add_theme_font_size_override("font_size", 12)
			empty_l.add_theme_color_override("font_color", text_dim)
			hist_box.add_child(empty_l)
			return
		for h in slot_history:
			var hb_card := PanelContainer.new()
			var won: bool = int(h.win) > 0
			hb_card.add_theme_stylebox_override("panel", _slot_box_style(Color(0.11, 0.14, 0.17, 0.7), Color(0.06, 0.73, 0.51, 0.28) if won else Color(1, 1, 1, 0.06), 1, 8, 7))
			hist_box.add_child(hb_card)
			var hvb := VBoxContainer.new()
			hvb.add_theme_constant_override("separation", 2)
			hb_card.add_child(hvb)
			var top_r := HBoxContainer.new()
			hvb.add_child(top_r)
			var hl := Label.new()
			hl.text = "Einsatz $%d" % int(h.bet)
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hl.add_theme_font_size_override("font_size", 12)
			hl.add_theme_color_override("font_color", text_main if won else text_dim)
			top_r.add_child(hl)
			var hv := Label.new()
			hv.text = "+$%d" % int(h.win) if won else "-$%d" % int(h.bet)
			hv.add_theme_font_size_override("font_size", 12)
			hv.add_theme_color_override("font_color", emerald if won else text_dim)
			top_r.add_child(hv)
	render_history.call()

	# --- BOTTOM ACTION BAR ---
	var foot_panel := PanelContainer.new()
	foot_panel.add_theme_stylebox_override("panel", _slot_box_style(Color(0.04, 0.06, 0.08, 0.98), Color(0.95, 0.79, 0.31, 0.2), 1, 16, 14))
	root_vb.add_child(foot_panel)
	var foot_hb := HBoxContainer.new()
	foot_hb.add_theme_constant_override("separation", 16)
	foot_panel.add_child(foot_hb)

	var bet_hb := HBoxContainer.new()
	bet_hb.add_theme_constant_override("separation", 8)
	bet_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_hb.add_child(bet_hb)
	var bet_cap := Label.new()
	bet_cap.text = "EINSATZ:"
	bet_cap.add_theme_font_size_override("font_size", 12)
	bet_cap.add_theme_color_override("font_color", text_dim)
	bet_hb.add_child(bet_cap)

	var bet_buttons := []
	var spin_btn := _slot_btn("DREHEN", gold, Color(0.14, 0.10, 0.0), gold, 36, 12, 12)
	spin_btn.custom_minimum_size = Vector2(210, 48)
	spin_btn.add_theme_font_size_override("font_size", 20)

	var refresh_bets := func():
		for pair in bet_buttons:
			var b: Button = pair[0]
			var v: int = pair[1]
			var active := v == slot_bet
			var styled := _slot_btn("$%d" % v, gold if active else Color(0.14, 0.16, 0.20), Color(0.14, 0.10, 0.0) if active else text_main, gold if active else Color(1, 1, 1, 0.12), 14, 9, 10)
			b.add_theme_stylebox_override("normal", styled.get_theme_stylebox("normal"))
			b.add_theme_stylebox_override("hover", styled.get_theme_stylebox("hover"))
			b.add_theme_color_override("font_color", styled.get_theme_color("font_color"))
			b.disabled = not GameState.can_pay(v)
		spin_btn.disabled = reels.spinning or not GameState.can_pay(slot_bet)

	for bet in [1, 5, 10, 50, 100]:
		var b := _slot_btn("$%d" % bet, Color(0.14, 0.16, 0.20), text_main, Color(1, 1, 1, 0.12), 14, 9, 10)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			slot_bet = bet
			Sfx.play_2d(win_panel, Sfx.click(), -8.0)
			refresh_bets.call())
		bet_hb.add_child(b)
		bet_buttons.append([b, bet])

	var spin_vb := VBoxContainer.new()
	spin_vb.add_theme_constant_override("separation", 2)
	foot_hb.add_child(spin_vb)
	spin_vb.add_child(spin_btn)
	var space_hint := Label.new()
	space_hint.text = "SHORTCUT: [LEERTASTE]"
	space_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	space_hint.add_theme_font_size_override("font_size", 10)
	space_hint.add_theme_color_override("font_color", text_dim)
	spin_vb.add_child(space_hint)

	var close_bot := _slot_btn("Schließen", Color(0.14, 0.16, 0.20), text_main, Color(1, 1, 1, 0.14), 18, 10, 10)
	close_bot.add_theme_font_size_override("font_size", 14)
	close_bot.pressed.connect(func(): Menus.close_all(hud))
	foot_hb.add_child(close_bot)

	var do_spin := func():
		var bet := slot_bet
		if reels.spinning or not GameState.pay(bet):
			return
		money_lbl.text = "$%d" % GameState.money
		Sfx.play_2d(win_panel, Sfx.slot_spin(), -6.0)
		var res := [_slot_symbol(), _slot_symbol(), _slot_symbol()]
		result.text = "Walzen laufen..."
		result.add_theme_color_override("font_color", gold)
		result_sub.text = "Einsatz: $%d" % bet
		refresh_bets.call()
		reels.spin(res, func():
			var win := _slot_payout(res, bet)
			if win > 0:
				GameState.add_money(win)
				result.text = "Gewonnen: $%d!" % win
				result.add_theme_color_override("font_color", emerald)
				result_sub.text = "Glückwunsch! (+$%d)" % (win - bet)
				Sfx.play_2d(win_panel, Sfx.jingle(win >= bet * 10), -4.0)
				var ptw := win_panel.create_tween()
				ptw.tween_property(win_panel, "scale", Vector2(1.03, 1.03), 0.10)
				ptw.tween_property(win_panel, "scale", Vector2.ONE, 0.14)
				if win >= bet * 25:
					game.hud.toast("JACKPOT! $%d" % win, 3.0)
			else:
				result.text = "Kein Gewinn"
				result.add_theme_color_override("font_color", text_dim)
				result_sub.text = "Noch einmal mit [Leertaste]?"
			slot_history.push_front({bet = bet, win = win})
			if slot_history.size() > 4:
				slot_history.resize(4)
			render_history.call()
			money_lbl.text = "$%d" % GameState.money
			refresh_bets.call())
		GameState.make_noise(hall.global_position if hall and hall.inside(game.player.global_position) else game.player.global_position, 20.0, "slot")

	spin_btn.pressed.connect(do_spin)
	win_panel.gui_input.connect(func(ev):
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_SPACE:
			do_spin.call())
	spin_btn.grab_focus()
	refresh_bets.call()


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
	chip_label.text = "Chip: $5"
	chip_label.custom_minimum_size.x = 110
	chips_row.add_child(chip_label)
	for v in [1, 5, 10, 50, 100]:
		var b := Button.new()
		b.text = "$%d" % v
		b.pressed.connect(func():
			chip[0] = v
			chip_label.text = "Chip: $%d" % v)
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
		var t := "Deine Einsätze: $%d  (%s)" % [mine, ", ".join(roulette_bets.map(func(x): return "$%d %s" % [x.amount, x.label]))] if mine > 0 else "Keine Einsätze."
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
		Net.roulette_bet("%s: $%d auf %s" % [GameState.player_name, amount, label])


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
		game.hud.toast("%d %s: Du gewinnst $%d!" % [result, col, win], 3.0)
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
			["$100", func(): _sit_poker(100)], ["$250", func(): _sit_poker(250)], ["$500", func(): _sit_poker(500)], ["Doch nicht", func(): pass]])
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
		game.hud.toast("Du stehst mit $%d auf (Einsatz war $%d)" % [chips, poker_buyin], 3.0)
	else:
		Net.poker_cashout(peer, chips)


func on_net_cashout(chips: int) -> void:
	GameState.add_money(chips)
	game.hud.toast("Du stehst mit $%d auf" % chips, 3.0)


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
			game.hud.show_dialog("Razzia!", "Erwischt beim illegalen Glücksspiel.\nDer Einsatz ($%d) wird beschlagnahmt, dazu $300 Strafe." % lost, [["Mist", func(): pass]])
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

	func _draw_sym(sym: String, center: Vector2, sz: float) -> void:
		var inner := Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		match sym:
			"seven":
				draw_string(get_theme_default_font(), center + Vector2(-sz * 0.25, sz * 0.34), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz * 0.9), Color(0.95, 0.35, 0.35))
			"cherry":
				var s := sz / 76.0
				draw_line(center + Vector2(-12 * s, 8 * s), center + Vector2(4 * s, -26 * s), Color(0.25, 0.65, 0.3), 3.0 * s)
				draw_line(center + Vector2(14 * s, 8 * s), center + Vector2(4 * s, -26 * s), Color(0.25, 0.65, 0.3), 3.0 * s)
				draw_circle(center + Vector2(-12 * s, 14 * s), 14 * s, Color(0.92, 0.2, 0.3))
				draw_circle(center + Vector2(14 * s, 14 * s), 14 * s, Color(0.92, 0.2, 0.3))
			"edelweiss":
				var s := sz / 76.0
				for k in 8:
					var a := TAU * k / 8.0
					draw_circle(center + Vector2(cos(a), sin(a)) * 20 * s, 11 * s, Color(0.96, 0.98, 1.0))
				draw_circle(center, 10 * s, Color(0.95, 0.8, 0.3))
			_:
				ItemIcons.draw_icon(self, inner, sym)

	func _draw() -> void:
		var gold := Color(0.95, 0.79, 0.31)
		var labels := {seven = "7", antlers = "GEWEIH", hunter_hat = "JÄGERHUT", edelweiss = "EDELWEISS", beer = "BIER", cherry = "KIRSCHEN"}
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08))
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.95, 0.79, 0.31, 0.35), false, 2.0)
		var w := (size.x - 72) / 3.0
		var syms := Casino.SLOT_SYMBOLS
		for i in 3:
			var rx := 24.0 + i * (w + 12.0)
			var r := Rect2(Vector2(rx, 14), Vector2(w, size.y - 28))
			draw_rect(r, Color(0.10, 0.12, 0.16))
			draw_rect(r, Color(1, 1, 1, 0.08), false, 1.5)
			var s: String = _shown[i]
			var idx := syms.find(s)
			var prev_s: String = syms[(idx + syms.size() - 1) % syms.size()]
			var next_s: String = syms[(idx + 1) % syms.size()]
			var cx := rx + w * 0.5
			var cy := size.y * 0.5
			# Top & bottom neighbor symbols (dimmed via dark overlay)
			_draw_sym(prev_s, Vector2(cx, cy - 92), 42.0)
			_draw_sym(next_s, Vector2(cx, cy + 92), 42.0)
			draw_rect(Rect2(Vector2(rx, 14), Vector2(w, 66)), Color(0.05, 0.07, 0.10, 0.72))
			draw_rect(Rect2(Vector2(rx, size.y - 80), Vector2(w, 66)), Color(0.05, 0.07, 0.10, 0.72))
			# Center payline frame & symbol
			var cbox := Rect2(Vector2(cx - 46, cy - 52), Vector2(92, 92))
			draw_rect(cbox, Color(0.95, 0.79, 0.31, 0.14))
			draw_rect(cbox, Color(0.95, 0.79, 0.31, 0.45), false, 1.5)
			_draw_sym(s, Vector2(cx, cy - 6), 64.0)
			draw_string(get_theme_default_font(), Vector2(rx + 6, cy + 56), labels.get(s, s.to_upper()), HORIZONTAL_ALIGNMENT_CENTER, w - 12, 13, gold)
		# Golden center payline + PAY / LINE badges
		var py := size.y * 0.5 - 6.0
		draw_line(Vector2(6, py), Vector2(size.x - 6, py), Color(0.95, 0.79, 0.31, 0.55), 2.5)
		draw_rect(Rect2(Vector2(4, py - 10), Vector2(30, 20)), gold)
		draw_string(get_theme_default_font(), Vector2(4, py + 4), "PAY", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color(0.14, 0.10, 0.0))
		draw_rect(Rect2(Vector2(size.x - 34, py - 10), Vector2(30, 20)), gold)
		draw_string(get_theme_default_font(), Vector2(size.x - 34, py + 4), "LINE", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color(0.14, 0.10, 0.0))
		if spinning:
			for i in 3:
				if _t < _stops[i]:
					var r2 := Rect2(Vector2(24.0 + i * (w + 12.0), 14), Vector2(w, size.y - 28))
					for k in 7:
						var y := fmod(_t * 900.0 + k * 34.0, r2.size.y)
						draw_line(Vector2(r2.position.x, r2.position.y + y), Vector2(r2.end.x, r2.position.y + y), Color(0.95, 0.79, 0.31, 0.14), 2.5)


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
		draw_string(font, Vector2(280, 140), "Geld: $%d" % GameState.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))


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
		draw_string(font, center + Vector2(-60, 60), "Pot: $%d" % v.pot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.4))
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
			var status := "raus" if p.folded else ("ALL-IN" if p.all_in else "$%d" % p.chips)
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
