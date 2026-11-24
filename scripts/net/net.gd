extends Node
## Mehrspieler (Autoload "Net") mit Godots ENet.
##  - Einzelspieler: alles lokal
##  - Host: Server und Spieler in einem
##  - Dedizierter Server: godot --headless -- --server  (Welt läuft 24/7, speichert alle Profile)
##  - Client: verbindet sich per IP (z. B. über ZeroTier oder den eigenen Server)
## Der Server ist zuständig für Tiere, aufgestellte Dinge, Häuser, Uhrzeit und Wetter sowie die Profile
## (Geld, Inventar, Pickup) aller Spieler, gespeichert nach Spielername.
## Jeder Spieler schickt seine eigene Position und die seines Pickups; die Polizei ist pro Spieler lokal.

signal connected
signal connection_failed(reason: String)
signal player_joined(id: int, pname: String)
signal player_left(id: int)
signal chat(from: String, text: String)

const PORT := 24680
const MAX_PLAYERS := 16
const SEND_RATE := 15.0

var mode := "single"  # single, host, client, server
var profiles := {}  # Spielername -> Profil (nur Server)
var peers := {}  # peer id -> {name, outfit}
var game: Node
var _send_t := 0.0
var _animal_t := 0.0
var _world_t := 0.0
var _profile_t := 0.0


func active() -> bool:
	return mode != "single"


func _exit_tree() -> void:
	leave()


func connected_ok() -> bool:
	return active() and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_server() -> bool:
	return mode == "host" or mode == "server"


func is_client() -> bool:
	return mode == "client"


func is_dedicated() -> bool:
	return mode == "server"


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("Verbindung fehlgeschlagen"))
	multiplayer.server_disconnected.connect(func():
		mode = "single"
		GameState.notify("Mehrspieler", "Verbindung zum Server getrennt"))
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		mode = "server"


# ------------------------------------------------------------------ Starten

func host(port := PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return "Server konnte nicht starten (Port %d belegt?)" % port
	multiplayer.multiplayer_peer = peer
	mode = "host"
	peers[1] = {name = GameState.player_name, outfit = GameState._colors_out(GameState.outfit)}
	return ""


func start_dedicated(port := PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return "Server konnte nicht starten"
	multiplayer.multiplayer_peer = peer
	mode = "server"
	print("Saint Leonard Server läuft auf Port %d" % port)
	return ""


func join(address: String, port := PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Verbindung zu %s nicht möglich" % address
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return ""


func leave() -> void:
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


# ------------------------------------------------------------------ Verbinden

func _on_connected() -> void:
	_register.rpc_id(1, GameState.player_name, GameState._colors_out(GameState.outfit))


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if peers.has(id):
		GameState.notify("Mehrspieler", "%s hat das Spiel verlassen" % peers[id].name)
	peers.erase(id)
	player_left.emit(id)


@rpc("any_peer", "reliable")
func _register(pname: String, outfit: Dictionary) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	# doppelte Namen vermeiden
	while pname in player_names():
		pname += "_"
	peers[id] = {name = pname, outfit = outfit}
	var prof: Dictionary = profiles.get(pname, {})
	var animals := []
	if game and game.spawner:
		for a in game.spawner.animals.values():
			if is_instance_valid(a):
				animals.append([a.species, a.global_position, a.net_id, 0])
	_welcome.rpc_id(id, pname, prof, GameState.world_dict(), peers, animals)
	_peer_info.rpc(id, pname, outfit)
	player_joined.emit(id, pname)
	GameState.notify("Mehrspieler", "%s ist da" % pname)


@rpc("authority", "reliable")
func _welcome(pname: String, prof: Dictionary, world: Dictionary, all_peers: Dictionary, animals: Array) -> void:
	GameState.player_name = pname
	if prof.is_empty():
		GameState.reset_new_game()
	else:
		GameState.apply_profile(prof)
	GameState.apply_world(world)
	peers = all_peers
	connected.emit()
	for id in peers:
		if id != my_id():
			player_joined.emit(id, peers[id].name)
	if game:
		for a in animals:
			game.spawner.spawn(a[0], a[1], a[2], a[3], true)


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
	if is_client() and not peers.has(my_id()) and peers.is_empty():
		return  # noch nicht angemeldet
	_send_t -= delta
	if _send_t <= 0.0 and not is_dedicated():
		_send_t = 1.0 / SEND_RATE
		game.send_net_state()
	if is_server():
		_animal_t -= delta
		if _animal_t <= 0.0:
			_animal_t = 0.12
			_send_animals()
		_world_t -= delta
		if _world_t <= 0.0:
			_world_t = 5.0
			_world_tick.rpc(GameState.time, GameState.day, GameState.weather, GameState.wetness)
	else:
		_profile_t -= delta
		if _profile_t <= 0.0:
			_profile_t = 20.0
			_save_profile.rpc_id(1, GameState.player_name, GameState.profile_dict())


@rpc("authority", "unreliable")
func _world_tick(t: float, d: int, w: String, wet: float) -> void:
	GameState.time = t
	GameState.day = d
	GameState.weather = w
	GameState.wetness = wet


@rpc("any_peer", "reliable")
func _save_profile(pname: String, prof: Dictionary) -> void:
	if is_server():
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
func hurt_player(id: int, dmg: float) -> void:
	_hurt.rpc_id(id, dmg)


@rpc("any_peer", "reliable")
func _hurt(dmg: float) -> void:
	GameState.damage(dmg)


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
	if is_server() and not GameState.houses.has(str(plot)):
		_apply_house(plot, type, pname)


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
	GameState.notify(from, text)
	chat.emit(from, text)
