class_name PokerGame
extends RefCounted
## Texas Hold'em (No Limit, Blinds 5/10) für die illegale Pokerrunde im Feuerwehrhaus.
## Läuft beim Server bzw. im Einzelspieler lokal. Menschen und NPCs sitzen gemeinsam am Tisch.
## Karten sind Zahlen 0..51: Rang = c % 13 (0 = 2, 12 = Ass), Farbe = c / 13.

signal changed
signal hand_finished(summary: String)

const SMALL := 5
const BIG := 10
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "B", "D", "K", "A"]
const SUITS := ["♣", "♦", "♥", "♠"]
const HAND_NAMES := ["Höchste Karte", "Ein Paar", "Zwei Paare", "Drilling", "Straße", "Flush", "Full House", "Vierling", "Straight Flush"]
const NPCS := [
	{name = "Hias", style = 0.5}, {name = "Mitzi", style = 0.3}, {name = "Lois", style = 0.8}, {name = "Resi", style = 0.4},
]

var players: Array = []  # {name, chips, npc, peer, hole, folded, all_in, bet, total, acted, style, sitting_out}
var community: Array = []
var deck: Array = []
var pot := 0
var current_bet := 0
var min_raise := BIG
var dealer := -1
var turn := -1
var street := -1  # -1 keine Hand, 0 Preflop, 1 Flop, 2 Turn, 3 River, 4 Showdown
var log_lines: Array = []
var showdown_info := {}  # Spielerindex -> Handname (nach dem Showdown)
var hands_played := 0
var _rng := RandomNumberGenerator.new()
var _npc_wait := 0.0


func _init() -> void:
	_rng.randomize()


static func card_name(c: int) -> String:
	return RANKS[c % 13] + SUITS[c / 13]


static func is_red(c: int) -> bool:
	return c / 13 in [1, 2]


func add_player(pname: String, chips: int, npc := false, peer := 0) -> int:
	for p in players:
		if p.name == pname:
			p.chips += chips
			p.sitting_out = false
			changed.emit()
			return players.find(p)
	var style := 0.5
	if npc:
		for n in NPCS:
			if n.name == pname:
				style = n.style
	players.append({name = pname, chips = chips, npc = npc, peer = peer, hole = [], folded = true, all_in = false, bet = 0, total = 0, acted = false, style = style, sitting_out = false})
	_log("%s setzt sich mit %d € an den Tisch." % [pname, chips])
	changed.emit()
	return players.size() - 1


## Mensch steht auf: Chips gehen zurück (wird nach der Hand entfernt)
func remove_player(pname: String) -> int:
	for i in players.size():
		var p: Dictionary = players[i]
		if p.name == pname:
			var chips: int = p.chips
			if street >= 0 and street < 4 and not p.folded:
				p.folded = true
				_log("%s steht auf." % pname)
				if turn == i:
					_next_turn()
			p.chips = 0
			p.sitting_out = true
			changed.emit()
			return chips
	return 0


func index_of(pname: String) -> int:
	for i in players.size():
		if players[i].name == pname:
			return i
	return -1


func _log(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 12:
		log_lines.pop_front()


func active_count() -> int:
	var n := 0
	for p in players:
		if not p.sitting_out and p.chips > 0:
			n += 1
	return n


func can_start() -> bool:
	return street == -1 or street == 4


# ------------------------------------------------------------------ Ablauf

func start_hand() -> bool:
	# leere Plätze und Pleite-NPCs auffüllen
	players = players.filter(func(p): return not p.sitting_out and (p.chips > 0 or p.npc))
	for p in players:
		if p.npc and p.chips < BIG * 2:
			p.chips = _rng.randi_range(150, 400)
			_log("%s holt frisches Geld aus der Jacke." % p.name)
	if active_count() < 2:
		return false
	hands_played += 1
	showdown_info = {}
	deck = range(52)
	for i in range(51, 0, -1):
		var j := _rng.randi_range(0, i)
		var t: int = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	community = []
	pot = 0
	for p in players:
		p.hole = []
		p.folded = p.chips <= 0
		p.all_in = false
		p.bet = 0
		p.total = 0
		p.acted = false
	dealer = _next_seat(dealer)
	for k in 2:
		for p in players:
			if not p.folded:
				p.hole.append(deck.pop_back())
	street = 0
	var sb := _next_seat(dealer)
	var bb := _next_seat(sb)
	if active_count() == 2:
		sb = dealer
		bb = _next_seat(dealer)
	_post(sb, SMALL)
	_post(bb, BIG)
	current_bet = BIG
	min_raise = BIG
	turn = _next_seat(bb)
	_log("--- Neue Hand. Geber: %s ---" % players[dealer].name)
	changed.emit()
	return true


func _next_seat(from: int) -> int:
	for k in range(1, players.size() + 1):
		var i := (from + k) % players.size()
		if players[i].chips > 0 or (street >= 0 and not players[i].folded and not players[i].all_in):
			if not players[i].sitting_out:
				return i
	return from


func _post(i: int, amount: int) -> void:
	var p: Dictionary = players[i]
	var a := mini(amount, p.chips)
	p.chips -= a
	p.bet += a
	p.total += a
	pot += a
	if p.chips == 0:
		p.all_in = true


func to_call(i: int) -> int:
	return maxi(0, current_bet - int(players[i].bet))


## Aktion eines Spielers: fold, check, call, raise (amount = Erhöhung um), allin
func act(i: int, action: String, amount := 0) -> bool:
	if i != turn or street < 0 or street > 3:
		return false
	var p: Dictionary = players[i]
	var need := to_call(i)
	match action:
		"fold":
			p.folded = true
			_log("%s steigt aus." % p.name)
		"check":
			if need > 0:
				return false
			_log("%s schiebt." % p.name)
		"call":
			_post(i, need)
			_log("%s geht mit (%d)." % [p.name, need] if need > 0 else "%s schiebt." % p.name)
		"raise", "allin":
			var raise_by := amount if action == "raise" else int(p.chips) - need
			raise_by = maxi(raise_by, 0)
			if action == "raise" and raise_by < min_raise and need + raise_by < int(p.chips):
				raise_by = min_raise
			var total_put := mini(need + raise_by, int(p.chips))
			_post(i, total_put)
			if p.bet > current_bet:
				min_raise = maxi(min_raise, int(p.bet) - current_bet)
				current_bet = p.bet
				for q in players:
					if q != p:
						q.acted = false
			_log("%s erhöht auf %d%s." % [p.name, p.bet, " (alles!)" if p.all_in else ""])
		_:
			return false
	p.acted = true
	_next_turn()
	changed.emit()
	return true


func _in_hand() -> Array:
	return players.filter(func(p): return not p.folded)


func _next_turn() -> void:
	var alive := _in_hand()
	if alive.size() == 1:
		_win_uncontested(alive[0])
		return
	# Straße fertig? Alle Aktiven haben gehandelt und gleich viel gesetzt
	var done := true
	for p in alive:
		if p.all_in:
			continue
		if not p.acted or p.bet != current_bet:
			done = false
	var can_act := alive.filter(func(p): return not p.all_in)
	if done or can_act.size() == 0 or (can_act.size() == 1 and can_act[0].bet >= current_bet and can_act[0].acted):
		_next_street()
		return
	for k in range(1, players.size() + 1):
		var i := (turn + k) % players.size()
		var p: Dictionary = players[i]
		if not p.folded and not p.all_in:
			turn = i
			return


func _next_street() -> void:
	for p in players:
		p.bet = 0
		p.acted = false
	current_bet = 0
	min_raise = BIG
	street += 1
	match street:
		1:
			community.append_array([deck.pop_back(), deck.pop_back(), deck.pop_back()])
			_log("Flop: " + " ".join(community.map(func(c): return card_name(c))))
		2, 3:
			community.append(deck.pop_back())
			_log(("Turn: " if street == 2 else "River: ") + card_name(community[-1]))
		_:
			_showdown()
			return
	# wenn höchstens einer noch setzen kann: automatisch weiter
	var can_act := _in_hand().filter(func(p): return not p.all_in)
	if can_act.size() <= 1:
		_next_street()
		return
	turn = dealer
	for k in range(1, players.size() + 1):
		var i := (dealer + k) % players.size()
		if not players[i].folded and not players[i].all_in:
			turn = i
			break


func _win_uncontested(p: Dictionary) -> void:
	p.chips += pot
	_log("%s gewinnt %d € (alle anderen sind raus)." % [p.name, pot])
	var s := "%s gewinnt %d €" % [p.name, pot]
	pot = 0
	street = 4
	turn = -1
	changed.emit()
	hand_finished.emit(s)


func _showdown() -> void:
	street = 4
	turn = -1
	var alive := _in_hand()
	var scores := {}
	for p in alive:
		var sc := best_score(p.hole + community)
		scores[players.find(p)] = sc
		showdown_info[players.find(p)] = HAND_NAMES[sc / 759375]
	# Töpfe nach Einsatzhöhe aufteilen (Nebentöpfe bei All-in)
	var levels := []
	for p in players:
		if p.total > 0 and not levels.has(p.total):
			levels.append(p.total)
	levels.sort()
	var prev := 0
	var summary := []
	for lv in levels:
		var part := 0
		for p in players:
			part += mini(p.total, lv) - mini(p.total, prev)
		var contenders := alive.filter(func(p): return p.total >= lv)
		if contenders.is_empty() or part <= 0:
			prev = lv
			continue
		var best := -1
		for p in contenders:
			best = maxi(best, scores[players.find(p)])
		var winners := contenders.filter(func(p): return scores[players.find(p)] == best)
		for w in winners:
			w.chips += part / winners.size()
		summary.append("%s gewinnt %d € mit %s" % [" und ".join(winners.map(func(w): return w.name)), part, HAND_NAMES[best / 759375]])
		prev = lv
	pot = 0
	for line in summary:
		_log(line)
	changed.emit()
	hand_finished.emit("\n".join(summary))


# ------------------------------------------------------------------ Bewertung

## Beste Wertung aus 5 bis 7 Karten (höher = besser)
static func best_score(cards: Array) -> int:
	var best := -1
	var n := cards.size()
	if n <= 5:
		return _score5(cards)
	for a in n:
		for b in range(a + 1, n):
			var five := []
			for k in n:
				if k != a and k != b:
					five.append(cards[k])
			best = maxi(best, _score5(five))
	return best


static func _score5(c: Array) -> int:
	var ranks := c.map(func(x): return x % 13)
	ranks.sort()
	ranks.reverse()
	var flush := true
	for x in c:
		if x / 13 != c[0] / 13:
			flush = false
	var counts := {}
	for r in ranks:
		counts[r] = counts.get(r, 0) + 1
	var uniq := counts.keys()
	uniq.sort_custom(func(a, b): return counts[a] > counts[b] if counts[a] != counts[b] else a > b)
	var straight_high := -1
	if uniq.size() == 5:
		if ranks[0] - ranks[4] == 4:
			straight_high = ranks[0]
		elif ranks == [12, 3, 2, 1, 0]:
			straight_high = 3
	var cat := 0
	var order: Array = uniq
	if straight_high >= 0 and flush:
		cat = 8
		order = [straight_high]
	elif counts[uniq[0]] == 4:
		cat = 7
	elif counts[uniq[0]] == 3 and counts[uniq[1]] == 2:
		cat = 6
	elif flush:
		cat = 5
		order = ranks
	elif straight_high >= 0:
		cat = 4
		order = [straight_high]
	elif counts[uniq[0]] == 3:
		cat = 3
	elif counts[uniq[0]] == 2 and counts[uniq[1]] == 2:
		cat = 2
	elif counts[uniq[0]] == 2:
		cat = 1
	else:
		order = ranks
	var score := cat
	for k in 5:
		score = score * 15 + (order[k] + 1 if k < order.size() else 0)
	return score


# ------------------------------------------------------------------ NPCs

## Stärke 0..1 der eigenen Hand (grob)
func _strength(i: int) -> float:
	var p: Dictionary = players[i]
	var h: Array = p.hole
	if community.is_empty():
		var r1: int = h[0] % 13
		var r2: int = h[1] % 13
		var s := (maxi(r1, r2) + minf(r1, r2) * 0.5) / 18.0
		if r1 == r2:
			s += 0.35 + r1 * 0.02
		if h[0] / 13 == h[1] / 13:
			s += 0.08
		if absi(r1 - r2) == 1:
			s += 0.05
		return clampf(s, 0.0, 1.0)
	var sc := best_score(h + community)
	var cat := sc / 759375
	var board_cat := best_score(community) / 759375 if community.size() >= 5 else 0
	var s2: float = [0.15, 0.45, 0.65, 0.75, 0.82, 0.86, 0.92, 0.97, 1.0][cat]
	if cat <= board_cat:
		s2 *= 0.6  # die Hand liegt am Tisch, nicht bei mir
	return s2


## Entscheidung für den NPC am Zug. Gibt true zurück, wenn gehandelt wurde.
func npc_step(delta: float) -> bool:
	if turn < 0 or street < 0 or street > 3:
		return false
	var p: Dictionary = players[turn]
	if not p.npc:
		return false
	_npc_wait += delta
	if _npc_wait < 1.1:
		return false
	_npc_wait = 0.0
	var st := _strength(turn) + _rng.randf_range(-0.12, 0.12)
	var need := to_call(turn)
	var pot_odds := float(need) / float(maxi(pot + need, 1))
	var bluff: bool = _rng.randf() < 0.08 * (1.0 + p.style)
	if st > 0.8 or (bluff and need == 0):
		var r := int(maxf(min_raise, pot * (0.5 + p.style * 0.5)))
		if st > 0.95 and _rng.randf() < 0.3:
			return act(turn, "allin")
		return act(turn, "raise", r)
	if need == 0:
		return act(turn, "check")
	if st > pot_odds + 0.25 or (need <= BIG and st > 0.3):
		return act(turn, "call")
	return act(turn, "fold")


# ------------------------------------------------------------------ Abgleich

## Zustand für einen Spieler (fremde Karten nur beim Showdown sichtbar)
func view_for(pname: String) -> Dictionary:
	var ps := []
	for i in players.size():
		var p: Dictionary = players[i]
		var show: bool = p.name == pname or (street == 4 and not p.folded and showdown_info.has(i))
		ps.append({name = p.name, chips = p.chips, npc = p.npc, folded = p.folded, all_in = p.all_in, bet = p.bet,
			hole = p.hole if show else ([-1, -1] if not p.hole.is_empty() else []), hand = showdown_info.get(i, "")})
	return {players = ps, community = community, pot = pot, current_bet = current_bet, min_raise = min_raise,
		dealer = dealer, turn = turn, street = street, log = log_lines}
