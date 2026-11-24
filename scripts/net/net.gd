extends Node
## Mehrspieler (Autoload "Net") mit Godots ENet. Es gibt genau einen Server, mit dem sich alle verbinden:
##  - Einzelspieler: alles lokal, kein Netz
##  - Server: godot --headless --path . -- --server [--port=24680] [--password=geheim] [--name=...] [--max=16]
##    (oder Einstellungen in user://server.cfg). Die Welt läuft rund um die Uhr und speichert alles.
##  - Client: verbindet sich mit Adresse (und Passwort). Im Hauptmenü kann man auch einen Server
##    auf dem eigenen PC starten lassen, dann verbinden sich alle (auch man selbst) mit diesem.
## Der Server ist zuständig für Tiere, aufgestellte Dinge, Häuser, Uhrzeit und Wetter, Roulette, Poker,
## Razzien und die Profile (Geld, Inventar, Pickup) aller Spieler, gespeichert nach Spielername.
## Jeder Spieler schickt seine eigene Position, die seines Pickups und seiner Polizeiautos.

signal connected
signal connection_failed(reason: String)
signal disconnected(reason: String)
signal player_joined(id: int, pname: String)
signal player_left(id: int)
signal chat(from: String, text: String)

const VERSION := "0.5"
const PORT := 24680
const MAX_PLAYERS := 16
const SEND_RATE := 15.0
const SERVER_CFG := "user://server.cfg"

var mode := "single"  # single, client, server
var profiles := {}  # Spielername -> Profil (nur Server)
var peers := {}  # peer id -> {name, outfit}
var game: Node
var server_name := "Saint Leonard"
var password := ""
var port := PORT
var max_players := MAX_PLAYERS
var join_password := ""  # Passwort, mit dem sich dieser Client anmeldet
var _send_t := 0.0
var _police_t := 0.0
var _animal_t := 0.0
var _world_t := 0.0
var _profile_t := 0.0
var _status_t := 10.0
var _leaving := false
var _rejected := ""


func active() -> bool:
	return mode != "single"


func _exit_tree() -> void:
	leave()


func connected_ok() -> bool:
	return active() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_server() -> bool:
	return mode == "server"


func is_client() -> bool:
	return mode == "client"


func is_dedicated() -> bool:
	return mode == "server"


func my_id() -> int:
	return multiplayer.get_unique_id() if active() and multiplayer.multiplayer_peer else 1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func():
		mode = "single"
		connection_failed.emit("Server nicht erreichbar"))
	multiplayer.server_disconnected.connect(func():
		var reason := _rejected if not _rejected.is_empty() else "Verbindung zum Server verloren"
		_rejected = ""
		mode = "single"
		peers.clear()
		multiplayer.multiplayer_peer = null
		if not _leaving:
			disconnected.emit(reason))
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		mode = "server"
		_load_server_config()


## Server-Einstellungen: user://server.cfg, Startparameter überschreiben sie
func _load_server_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SERVER_CFG) == OK:
		server_name = cfg.get_value("server", "name", server_name)
		password = cfg.get_value("server", "password", password)
		port = int(cfg.get_value("server", "port", port))
		max_players = int(cfg.get_value("server", "max_players", max_players))
	else:
		cfg.set_value("server", "name", server_name)
		cfg.set_value("server", "password", "")
		cfg.set_value("server", "port", PORT)
		cfg.set_value("server", "max_players", MAX_PLAYERS)
		cfg.save(SERVER_CFG)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.get_slice("=", 1))
		elif a.begins_with("--password="):
			password = a.get_slice("=", 1)
		elif a.begins_with("--name="):
			server_name = a.get_slice("=", 1)
		elif a.begins_with("--max="):
			max_players = int(a.get_slice("=", 1))


# ------------------------------------------------------------------ Starten

func start_dedicated() -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		return "Server konnte nicht starten (Port %d belegt?)" % port
	multiplayer.multiplayer_peer = peer
	mode = "server"
	print("[Server] \"%s\" läuft auf Port %d, Version %s, max. %d Spieler%s" % [server_name, port, VERSION, max_players, ", mit Passwort" if not password.is_empty() else ""])
	print("[Server] Spielstände: %s" % ProjectSettings.globalize_path(GameState.SAVE_DIR))
	return ""


## Adresse "host" oder "host:port"
func join(address: String, pw := "") -> String:
	var host := address.strip_edges()
	var p := PORT
	if ":" in host and host.count(":") == 1:
		p = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	if host.is_empty():
		return "Bitte eine Serveradresse eingeben"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, p)
	if err != OK:
		return "Verbindung zu %s nicht möglich" % address
	join_password = pw
	_leaving = false
	_rejected = ""
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return ""


## Sauber trennen: Profil noch an den Server schicken
func leave_gracefully() -> void:
	if is_client() and connected_ok():
		_leaving = true
		_save_profile.rpc_id(1, GameState.player_name, GameState.profile_dict())
		for i in 10:
			await get_tree().process_frame
	leave()


func leave() -> void:
	_leaving = true
	if is_server():
		GameState.save_game()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = "single"
	peers.clear()


func player_names() -> Array:
	var out := []
	for id in peers:
		out.append(peers[id].name)
	return out


func peer_of(pname: String) -> int:
	for id in peers:
		if peers[id].name == pname:
			return id
	return 0


# ------------------------------------------------------------------ Anmelden

func _on_connected() -> void:
	_register.rpc_id(1, GameState.player_name, GameState._colors_out(GameState.outfit), VERSION, join_password)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if peers.has(id):
		var n: String = peers[id].name
		if is_server():
			print("[Server] %s hat das Spiel verlassen (%d online)" % [n, peers.size() - 1])
		else:
			GameState.notify("Mehrspieler", "%s hat das Spiel verlassen" % n)
	peers.erase(id)
	player_left.emit(id)
	if is_server():
		GameState.save_game()
		if game and game.casino and game.casino.poker:
			for p in game.casino.poker.players:
				if p.peer == id:
					game.casino.poker.remove_player(p.name)


@rpc("any_peer", "reliable")
func _register(pname: String, outfit: Dictionary, version: String, pw: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if version != VERSION:
		reason = "Falsche Spielversion (Server %s, du %s)" % [VERSION, version]
	elif not password.is_empty() and pw != password:
		reason = "Falsches Passwort"
	elif pname.strip_edges().is_empty():
		reason = "Bitte einen Namen eingeben"
	elif pname in player_names():
		reason = "Der Name \"%s\" ist schon online" % pname
	elif peers.size() >= max_players:
		reason = "Server voll"
	if not reason.is_empty():
		print("[Server] Abgelehnt: %s (%s)" % [pname, reason])
		_reject.rpc_id(id, reason)
		get_tree().create_timer(0.5).timeout.connect(func():
			if multiplayer.multiplayer_peer:
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))
		return
	peers[id] = {name = pname, outfit = outfit}
	var prof: Dictionary = profiles.get(pname, {})
	var animals := []
	if game and game.spawner:
		for a in game.spawner.animals.values():
			if is_instance_valid(a):
				animals.append([a.species, a.global_position, a.net_id, 0])
	var extra := {server_name = server_name, roulette_t = game.casino.roulette_t if game and game.casino else 20.0}
	_welcome.rpc_id(id, pname, prof, GameState.world_dict(), peers, animals, extra)
	_peer_info.rpc(id, pname, outfit)
	player_joined.emit(id, pname)
	print("[Server] %s ist da (%s, %d online)" % [pname, "bekanntes Profil" if not prof.is_empty() else "neues Profil", peers.size()])


@rpc("authority", "reliable")
func _reject(reason: String) -> void:
	_rejected = reason
	connection_failed.emit(reason)


@rpc("authority", "reliable")
func _welcome(pname: String, prof: Dictionary, world: Dictionary, all_peers: Dictionary, animals: Array, extra: Dictionary) -> void:
	GameState.player_name = pname
	if prof.is_empty():
		var outfit := GameState.outfit.duplicate()
		GameState.reset_new_game()
		GameState.outfit = outfit
	else:
		GameState.apply_profile(prof)
	GameState.apply_world(world)
	server_name = extra.get("server_name", "Saint Leonard")
	peers = all_peers
	connected.emit()
	for id in peers:
		if id != my_id():
			player_joined.emit(id, peers[id].name)
	if game:
		for a in animals:
			game.spawner.spawn(a[0], a[1], a[2], a[3], true)
		if game.casino:
			game.casino.roulette_t = float(extra.get("roulette_t", 20.0))


@rpc("authority", "reliable", "call_remote")
func _peer_info(id: int, pname: String, outfit: Dictionary) -> void:
	if id == my_id():
		return
	peers[id] = {name = pname, outfit = outfit}
	player_joined.emit(id, pname)


# ------------------------------------------------------------------ laufender Abgleich

func _process(delta: float) -> void:
	if not active() or not multiplayer.multiplayer_peer or not game:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_client() and not peers.has(my_id()):
		return  # noch nicht angemeldet
	if is_client():
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = 1.0 / SEND_RATE
			game.send_net_state()
		_police_t -= delta
		if _police_t <= 0.0:
			_police_t = 0.2
			game.send_police_state()
		_profile_t -= delta
		if _profile_t <= 0.0:
			_profile_t = 20.0
			_save_profile.rpc_id(1, GameState.player_name, GameState.profile_dict())
	else:
		_animal_t -= delta
		if _animal_t <= 0.0:
			_animal_t = 0.12
			_send_animals()
		_world_t -= delta
		if _world_t <= 0.0:
			_world_t = 5.0
			_world_tick.rpc(GameState.time, GameState.day, GameState.weather, GameState.wetness)
		_status_t -= delta
		if _status_t <= 0.0:
			_status_t = 60.0
			print("[Server] %s, Tag %d, %s: %d online %s, %d Tiere, %d aufgestellt, %d Häuser" % [GameState.clock_text(), GameState.day, GameState.weather,
				peers.size(), player_names(), game.spawner.animals.size() if game.spawner else 0, GameState.placed.size(), GameState.houses.size()])


@rpc("authority", "unreliable")
func _world_tick(t: float, d: int, w: String, wet: float) -> void:
	GameState.time = t
	GameState.day = d
	GameState.weather = w
	GameState.wetness = wet


@rpc("any_peer", "reliable")
func _save_profile(pname: String, prof: Dictionary) -> void:
	if not is_server():
		return
	# nur das eigene Profil darf gespeichert werden
	var id := multiplayer.get_remote_sender_id()
	if peers.has(id) and peers[id].name == pname:
		profiles[pname] = prof


## Spielerzustand: Position, Blick, Zustand (Bits: 1 fährt, 2 geduckt, 4 zielt, 8 ohnmächtig), Sitz
@rpc("any_peer", "unreliable_ordered")
func pstate(pos: Vector3, yaw: float, pitch: float, flags: int, seat_owner: int, seat: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if game:
		game.on_remote_player(id, pos, yaw, pitch, flags, seat_owner, seat)


## Pickup eines Spielers
@rpc("any_peer", "unreliable_ordered")
func vstate(xf: Transform3D, vel: Vector3, look: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if game:
		game.on_remote_truck(id, xf, vel, look)


func _send_animals() -> void:
	if not game or not game.spawner:
		return
	var data := PackedFloat32Array()
	for a in game.spawner.animals.values():
		if not is_instance_valid(a):
			continue
		var p: Vector3 = a.global_position
		data.append_array([a.net_id, p.x, p.y, p.z, a.rotation.y, Vector2(a.velocity.x, a.velocity.z).length()])
	if not data.is_empty():
		_animal_states.rpc(data)


@rpc("authority", "unreliable_ordered")
func _animal_states(data: PackedFloat32Array) -> void:
	if game:
		game.on_animal_states(data)


func animal_spawned(sp: String, pos: Vector3, id: int, seed_v: int) -> void:
	if is_server() and active():
		_animal_spawn.rpc(sp, pos, id, seed_v)


@rpc("authority", "reliable")
func _animal_spawn(sp: String, pos: Vector3, id: int, seed_v: int) -> void:
	if game:
		game.spawner.spawn(sp, pos, id, seed_v, true)


func animal_despawned(id: int) -> void:
	if is_server() and active():
		_animal_despawn.rpc(id)


@rpc("authority", "reliable")
func _animal_despawn(id: int) -> void:
	if game and game.spawner.animals.has(id):
		var a = game.spawner.animals[id]
		game.spawner.animals.erase(id)
		if is_instance_valid(a):
			a.queue_free()


## Treffer auf ein Tier (Client -> Server)
func hit_animal(id: int, dmg: float, point: Vector3, dir: Vector3) -> void:
	_hit.rpc_id(1, id, dmg, point, dir)


@rpc("any_peer", "reliable")
func _hit(id: int, dmg: float, point: Vector3, dir: Vector3) -> void:
	if not is_server() or not game:
		return
	var a = game.spawner.animals.get(id)
	if is_instance_valid(a):
		a.hit(dmg, point, dir, null)  # Tod wird über Game.on_animal_died an alle gemeldet


func animal_killed_on_server(id: int, dir: Vector3) -> void:
	if is_server() and active():
		_animal_died.rpc(id, dir)


@rpc("authority", "reliable")
func _animal_died(id: int, dir: Vector3) -> void:
	if game:
		game.on_remote_animal_died(id, dir)


## Kadaver weg (ausgenommen, verladen)
func carcass_removed(id: int) -> void:
	if active():
		_carcass_gone.rpc(id)


@rpc("any_peer", "reliable", "call_remote")
func _carcass_gone(id: int) -> void:
	if game:
		game.on_carcass_gone(id)


## Geräusch beim Server melden (Tiere hören dort)
func send_noise(pos: Vector3, radius: float, kind: String) -> void:
	if is_client():
		_noise.rpc_id(1, pos, radius, kind)


@rpc("any_peer", "unreliable")
func _noise(pos: Vector3, radius: float, kind: String) -> void:
	if is_server():
		GameState.noise_made.emit(pos, radius, kind)


## Schaden an einem Mitspieler (Wildschwein, Bär)
func hurt_player(id: int, dmg: float, killer_id := 0) -> void:
	_hurt.rpc_id(id, dmg, killer_id)


@rpc("any_peer", "reliable")
func _hurt(dmg: float, killer_id := 0) -> void:
	if killer_id > 0 and get_tree().current_scene:
		get_tree().current_scene.set("last_damage_source", "player:%d" % killer_id)
	GameState.damage(dmg)


func charge_friendly_fire(killer_id: int, amount: int) -> void:
	_friendly_fire_fee.rpc_id(killer_id, amount)


@rpc("any_peer", "reliable")
func _friendly_fire_fee(amount: int) -> void:
	GameState.add_money(-mini(amount, maxi(GameState.money, 0)))
	if get_tree().current_scene and get_tree().current_scene.get("hud"):
		get_tree().current_scene.hud.toast("Friendly Fire! Du zahlst %d € für deinen Mitspieler." % amount, 4.0)


# ------------------------------------------------------------------ Welt: Aufstellen, Häuser

func request_place(entry: Dictionary) -> void:
	if is_client():
		_req_place.rpc_id(1, entry)
	else:
		_apply_place(entry)


@rpc("any_peer", "reliable")
func _req_place(entry: Dictionary) -> void:
	if is_server():
		_apply_place(entry)


func _apply_place(entry: Dictionary) -> void:
	GameState.placed.append(entry)
	GameState.world_changed.emit()
	if active():
		_placed_add.rpc(entry)


@rpc("authority", "reliable", "call_remote")
func _placed_add(entry: Dictionary) -> void:
	if GameState.find_placed(int(entry.uid)).is_empty():
		GameState.placed.append(entry)
		GameState.world_changed.emit()


func request_remove(uid: int) -> void:
	if is_client():
		_req_remove.rpc_id(1, uid)
	else:
		GameState.remove_placed(uid)
		if active():
			_placed_remove.rpc(uid)


@rpc("any_peer", "reliable")
func _req_remove(uid: int) -> void:
	if is_server():
		request_remove(uid)


@rpc("authority", "reliable", "call_remote")
func _placed_remove(uid: int) -> void:
	GameState.remove_placed(uid)


func update_placed(entry: Dictionary) -> void:
	if active():
		_placed_data.rpc(int(entry.uid), entry.data)


@rpc("any_peer", "reliable", "call_remote")
func _placed_data(uid: int, data: Dictionary) -> void:
	var e := GameState.find_placed(uid)
	if not e.is_empty():
		e.data = data


func request_house(plot: int, type: int) -> void:
	if is_client():
		_req_house.rpc_id(1, plot, type, GameState.player_name)
	else:
		_apply_house(plot, type, GameState.player_name)


@rpc("any_peer", "reliable")
func _req_house(plot: int, type: int, pname: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var ok := not GameState.houses.has(str(plot))
	for k in GameState.houses:
		if GameState.houses[k].owner == pname:
			ok = false  # jeder nur ein Haus
	if ok:
		_apply_house(plot, type, pname)
	_house_result.rpc_id(id, plot, type, ok)


@rpc("authority", "reliable")
func _house_result(plot: int, type: int, ok: bool) -> void:
	if game:
		game.on_house_result(plot, type, ok)


func _apply_house(plot: int, type: int, pname: String) -> void:
	GameState.houses[str(plot)] = {owner = pname, type = type}
	GameState.world_changed.emit()
	if active():
		_house_set.rpc(plot, type, pname)


@rpc("authority", "reliable", "call_remote")
func _house_set(plot: int, type: int, pname: String) -> void:
	GameState.houses[str(plot)] = {owner = pname, type = type}
	GameState.world_changed.emit()


# ------------------------------------------------------------------ Chat

func send_chat(text: String) -> void:
	_chat.rpc(GameState.player_name, text)
	GameState.notify(GameState.player_name, text)


@rpc("any_peer", "reliable", "call_remote")
func _chat(from: String, text: String) -> void:
	if is_server():
		print("[Server] Chat %s: %s" % [from, text])
		if text == "!razzia" and DebugTools.args.has("mptest") and game and game.casino:
			game.casino.start_raid()
		return
	GameState.notify(from, text)
	chat.emit(from, text)


# ------------------------------------------------------------------ Glücksspiel

func roulette_bet(text: String) -> void:
	_roulette_bet.rpc(text)
	_roulette_bet_local(text)


@rpc("any_peer", "reliable", "call_remote")
func _roulette_bet(text: String) -> void:
	_roulette_bet_local(text)


func _roulette_bet_local(text: String) -> void:
	if game and game.casino:
		game.casino.roulette_feed.append(text)


## Server: Kugel für alle werfen
func roulette_spin(result: int) -> void:
	if not is_server():
		return
	_roulette_spin.rpc(result)
	if game and game.casino:
		game.casino.on_net_roulette_spin(result)


@rpc("authority", "reliable", "call_remote")
func _roulette_spin(result: int) -> void:
	if game and game.casino:
		game.casino.on_net_roulette_spin(result)


## Pokeraktion an den Server (sit, leave, fold, check, call, raise, allin, seized)
func poker_cmd(cmd: String, amount: int) -> void:
	_poker_cmd.rpc_id(1, GameState.player_name, cmd, amount)


@rpc("any_peer", "reliable")
func _poker_cmd(pname: String, cmd: String, amount: int) -> void:
	if is_server() and game and game.casino:
		game.casino._server_poker_cmd(pname, multiplayer.get_remote_sender_id(), cmd, amount)


func poker_state(peer: int, view: Dictionary) -> void:
	_poker_state.rpc_id(peer, view)


@rpc("authority", "reliable")
func _poker_state(view: Dictionary) -> void:
	if game and game.casino:
		game.casino.on_net_poker_state(view)


func poker_cashout(peer: int, chips: int) -> void:
	_poker_cashout.rpc_id(peer, chips)


@rpc("authority", "reliable")
func _poker_cashout(chips: int) -> void:
	if game and game.casino:
		game.casino.on_net_cashout(chips)


func raid() -> void:
	_raid.rpc()


@rpc("authority", "reliable", "call_remote")
func _raid() -> void:
	if game and game.casino:
		game.casino.on_raid()


# ------------------------------------------------------------------ Effekte und Polizei der anderen

## Schuss, Hupe, Explosion, Rülpser: alle anderen hören bzw. sehen es
func fx(kind: String, pos: Vector3) -> void:
	if connected_ok():
		_fx.rpc(kind, pos)


@rpc("any_peer", "unreliable", "call_remote")
func _fx(kind: String, pos: Vector3) -> void:
	if game and not is_dedicated():
		game.on_fx(kind, pos)


## Polizeiautos eines Spielers: [[Transform3D, Sirene], ...]
func police_state(cars: Array) -> void:
	_police.rpc(cars)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _police(cars: Array) -> void:
	if game and not is_dedicated():
		game.on_remote_police(multiplayer.get_remote_sender_id(), cars)
