class_name Game
extends Node3D
## Hauptszene "Saint Leonard": baut aus Welt, Orten, Tieren, Polizei, Aufträgen, Wetter und
## Oberfläche das Spiel zusammen und regelt alles, was der Spieler mit [F] und anderen Tasten tut.
## Mehrspieler: Net (Autoload) ruft die on_remote_*-Funktionen auf.

const ENTER_DISTANCE := 4.0
const RIFLE_DAMAGE := 120.0

@onready var world: WorldBuilder = $World
@onready var sun: DirectionalLight3D = $Sun
@onready var env_node: WorldEnvironment = $WorldEnvironment

var interactions := Interactions.new()
var landmarks: Landmarks
var spawner: AnimalSpawner
var police: PoliceManager
var missions: Missions
var casino: Casino
var hall: FireHall
var gasthaus: Gasthaus
var sitting := false
var sky: SkyCycle
var player: Player
var car: Truck
var atv: ATV
var rig: CameraRig
var hud: Hud
var menu: MainMenu
var menu_stage: MenuStage
var _wardrobe_cam: Camera3D
var driving := false
var seat := ""  # "" zu Fuß, sonst Sitz im eigenen oder fremden Fahrzeug
var seat_truck: Vehicle = null
var started := false
var waypoint := Vector2.INF

var placed_nodes := {}  # uid -> Node3D
var house_nodes := {}  # Bauplatz -> Node3D
var remote_players := {}  # peer id -> RemotePlayer
var remote_trucks := {}  # peer id -> Truck
var remote_police := {}  # peer id -> Array[PoliceCar]
var trailer: Trailer  # eigener Anhänger (falls gekauft)
var remote_trailers := {}  # peer id -> Trailer
var net_stats := {}  # Zähler für Tests: empfangene Effekte, Stimme
var _placing := ""
var _ghost: Node3D
var _ghost_rot := 0.0
var _harvest_t := 0.0
var _harvest_target: Carcass = null
var _place_timer := 0.0
var _dropzone_t := 0.0
var _current_interaction := {}
var _festival: Node3D
var _default_car_xf := Transform3D.IDENTITY
var _default_atv_xf := Transform3D.IDENTITY


func _ready() -> void:
	Controls.setup()
	Net.game = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	if world.data.is_empty():
		return
	landmarks = Landmarks.new()
	landmarks.name = "Orte"
	add_child(landmarks)
	spawner = AnimalSpawner.new()
	spawner.name = "Wild"
	spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spawner)
	missions = Missions.new()
	missions.name = "Auftraege"
	add_child(missions)
	sky = SkyCycle.new()
	sky.name = "Himmel"
	add_child(sky)
	sky.setup(sun, env_node.environment)

	GameState.world_changed.connect(_sync_world)
	GameState.message.connect(func(from, text): Phone.log_message(from, text))
	Net.player_left.connect(_on_player_left)

	if Net.is_dedicated():
		_start_dedicated()
		return
	hud = Hud.new()
	add_child(hud)
	hud.visible = false
	landmarks.setup(world, self)
	spawner.setup(world, landmarks)
	_setup_hall()

	if DebugTools.active and not DebugTools.args.has("showmenu"):
		GameState.reset_new_game()
		if DebugTools.args.has("name"):
			GameState.player_name = DebugTools.args.name
		if DebugTools.args.has("localserver"):
			print("Lokaler Server: ", start_local_server())
			var ok := false
			for attempt in 10:
				await get_tree().create_timer(2.0).timeout
				Net.join("127.0.0.1")
				if await _wait_connect() == "":
					ok = true
					break
				Net.leave()
			print("Verbindung zum lokalen Server: ", ok)
		elif DebugTools.args.has("join"):
			Net.join(DebugTools.args.join, DebugTools.args.get("password", ""))
			var res = await _wait_connect()
			print("Verbindung: ", "ok" if res == "" else res)
			if res != "":
				get_tree().quit(2)
				return
		_start_game()
		return
	# Nach "Hauptmenü" oder "Laden" wird die Szene neu geladen; ein gewählter Spielstand startet direkt
	if not GameState.pending.is_empty():
		var pend: Dictionary = GameState.pending
		GameState.pending = {}
		_on_menu_start("single", "", pend.slot, pend.get("new", false), false)
		return
	var saves := GameState.list_saves()
	if not saves.is_empty():
		GameState.slot = saves[0].slot
		GameState.load_game()
	Settings.apply(get_tree())
	MainMenu.load_figure()
	_open_menu()
	if not Net.peers_changed.is_connected(_on_peers_changed_menu):
		Net.peers_changed.connect(_on_peers_changed_menu)
	if not Net.disconnected.is_connected(_on_net_disconnected_menu):
		Net.disconnected.connect(_on_net_disconnected_menu)


func _on_peers_changed_menu() -> void:
	if menu and is_instance_valid(menu):
		menu.refresh_lobby()


func _on_net_disconnected_menu(reason: String) -> void:
	if menu and is_instance_valid(menu) and not started:
		menu.page_home()
		menu.show_error("Verbindung getrennt: %s" % reason)


func _open_menu() -> void:
	if menu_stage and is_instance_valid(menu_stage):
		remove_child(menu_stage)
		menu_stage.queue_free()
		menu_stage = null
	if menu and is_instance_valid(menu):
		remove_child(menu)
		menu.queue_free()
		menu = null
	# Hintergrund fürs Menü: 3D-Bühne (Figur auf dem Felsen, Spiegel, Lobby vor dem Gasthaus)
	menu_stage = MenuStage.new()
	menu_stage.name = "Menuebuehne"
	add_child(menu_stage)
	menu_stage.setup(self, world)
	menu = MainMenu.new()
	menu.stage = menu_stage
	add_child(menu)
	menu.start.connect(_on_menu_start)
	menu.quit.connect(func(): Net.quit_game())
	menu.play_from_lobby.connect(_play_from_lobby)
	menu.leave_lobby.connect(_leave_lobby)


func _return_to_menu() -> void:
	var t0 := Time.get_ticks_msec()
	GameState.save_game()
	var t_save := Time.get_ticks_msec()
	await Net.leave_gracefully()
	var t_net := Time.get_ticks_msec()
	started = false
	seat = ""
	seat_truck = null
	get_tree().paused = false
	if hud:
		hud.show_pause(false)
		hud.visible = false
	if not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player and is_instance_valid(player):
		player.queue_free()
	player = null
	for v in [car, atv]:
		if v and is_instance_valid(v):
			interactions.remove_node(v)
			if v.get_parent() and v.get_parent().name == "Vehicles":
				v.player_input = false
				v.driving = false
				v.linear_velocity = Vector3.ZERO
				v.angular_velocity = Vector3.ZERO
				if v is Truck:
					for c in (v as Truck).cargo:
						if is_instance_valid(c):
							c.queue_free()
					(v as Truck).cargo.clear()
				v.global_transform = _default_car_xf if v == car else _default_atv_xf
				v.reset_physics_interpolation()
			else:
				v.queue_free()
	if trailer and is_instance_valid(trailer):
		interactions.remove_node(trailer)
		trailer.queue_free()
	car = null
	atv = null
	trailer = null
	if rig and is_instance_valid(rig):
		rig.queue_free()
	rig = null
	if police and is_instance_valid(police):
		police.queue_free()
	police = null
	for id in remote_trucks:
		if is_instance_valid(remote_trucks[id]):
			remote_trucks[id].queue_free()
	remote_trucks.clear()
	for node in get_tree().get_nodes_in_group("carcass"):
		if is_instance_valid(node):
			node.queue_free()
	for uid in placed_nodes.keys():
		var pn: Node3D = placed_nodes[uid]
		if is_instance_valid(pn):
			interactions.remove_node(pn)
			pn.queue_free()
	placed_nodes.clear()
	if spawner:
		spawner.animals.clear()
		spawner.legend_wanted = false
		for ch in spawner.get_children():
			ch.queue_free()
		spawner.players.clear()
	Animal.threats.clear()
	_open_menu()
	print("[PERF] Save: %d ms | Net leave: %d ms | Menu return total: %d ms" % [t_save - t0, t_net - t_save, Time.get_ticks_msec() - t0])


func _on_menu_start(mode: String, address: String, slot: String, new_game: bool, keep_outfit := true) -> void:
	var outfit := GameState.outfit.duplicate()
	var title := GameState.slot_title
	var err := ""
	match mode:
		"single":
			GameState.slot = slot if not slot.is_empty() else "einzelspieler"
			if new_game or not GameState.load_game():
				GameState.reset_new_game()
				GameState.slot_title = title if new_game else "Einzelspieler"
				GameState.save_game(true)
		"localserver", "client":
			if mode == "localserver":
				var started_err := start_local_server()
				if not started_err.is_empty():
					menu.show_error(started_err)
					return
				address = "127.0.0.1"
			var res := ""
			# ein frisch gestarteter Server braucht ein paar Sekunden
			for attempt in (8 if mode == "localserver" else 1):
				menu.show_error("Verbinde mit %s ..." % address)
				if mode == "localserver":
					await get_tree().create_timer(2.0).timeout
				err = Net.join(address, Net.join_password)
				if not err.is_empty():
					break
				res = await _wait_connect()
				if res == "":
					break
				Net.leave()
			if err.is_empty() and res != "":
				menu.show_error(res)
				return
	if not err.is_empty():
		menu.show_error(err)
		return
	if keep_outfit:
		GameState.outfit = outfit
	# nur Kleidung, die man in diesem Spielstand auch besitzt
	GameState.outfit = Outfit.sanitize(GameState.outfit)
	if mode != "single" and menu:
		# Mehrspieler: erst in die Lobby vor dem Gasthaus
		Net.send_outfit()
		Net.send_lobby_state("lobby", false)
		menu.show_lobby()
		return
	_close_menu()
	_start_game()


func _close_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if menu_stage:
		menu_stage.queue_free()
		menu_stage = null
	Settings.apply(get_tree())


## Lobby: "Spielen" gedrückt oder alle bereit
func _play_from_lobby() -> void:
	if not Net.connected_ok():
		menu.page_home()
		menu.show_error("Keine Verbindung mehr zum Server")
		return
	_close_menu()
	_start_game()


func _leave_lobby() -> void:
	Net.leave()
	MainMenu.load_figure()
	menu.page_home()


## Kleiderschrank im Spiel: Kamera schaut die eigene Figur von vorne an, daneben der Figur-Editor
func open_wardrobe() -> void:
	if _wardrobe_cam or not player:
		return
	Menus.close_all(hud)
	hud.visible = false
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fwd := Vector3(player.facing.x, 0, player.facing.z).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, 1)
	var side := fwd.cross(Vector3.UP)
	_wardrobe_cam = Camera3D.new()
	add_child(_wardrobe_cam)
	var eye := player.global_position + fwd * 5.0 + side * 0.9 + Vector3.UP * 1.6
	_wardrobe_cam.look_at_from_position(eye, player.global_position + side * 0.9 + Vector3.UP * 1.1)
	_wardrobe_cam.make_current()
	player.model.rotation.y = atan2(fwd.x, fwd.z)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var ed := FigureEditor.new()
	layer.add_child(ed)
	ed.open(GameState.outfit)
	ed.changed.connect(func(o):
		GameState.outfit = o.duplicate()
		player.rebuild_model()
		player.model.rotation.y = atan2(fwd.x, fwd.z))
	ed.rotate.connect(func(d): player.model.rotate_y(d))
	ed.finished.connect(func(o, accepted):
		GameState.outfit = o.duplicate()
		player.rebuild_model()
		if accepted:
			Net.send_outfit()
			hud.toast("Neu eingekleidet", 1.5)
		layer.queue_free()
		_wardrobe_cam.queue_free()
		_wardrobe_cam = null
		rig.camera.make_current()
		hud.visible = true
		player.input_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


## Startet einen Server auf diesem PC (eigener Prozess ohne Fenster)
func start_local_server() -> String:
	var args := PackedStringArray()
	args.append("--headless")
	if not OS.has_feature("template"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--server"])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		return "Server konnte nicht gestartet werden"
	GameState.set_meta("local_server_pid", pid)
	return ""


func _wait_connect() -> String:
	var result := [""]
	var done := [false]
	var ok_cb := func(): done[0] = true
	var fail_cb := func(reason): result[0] = reason; done[0] = true
	Net.connected.connect(ok_cb, CONNECT_ONE_SHOT)
	Net.connection_failed.connect(fail_cb, CONNECT_ONE_SHOT)
	var t := 0.0
	while not done[0] and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if not done[0]:
		return "Keine Antwort vom Server"
	return result[0]


func _start_dedicated() -> void:
	landmarks.setup(world, self)
	spawner.setup(world, landmarks)
	_setup_hall()
	GameState.slot = "dedicated"
	if DebugTools.args.has("mptest"):
		GameState.slot = "mptest_server"  # Testlauf: eigener, frischer Spielstand
		DirAccess.remove_absolute("%s/mptest_server.json" % GameState.SAVE_DIR)
	GameState.load_game()
	var err := Net.start_dedicated()
	if not err.is_empty():
		push_error(err)
		get_tree().quit(1)
	missions.set_process(false)
	spawner.died_hook = _on_animal_died
	_sync_world()
	started = true


## Feuerwehrhaus Korpitsch und Glücksspiel
func _setup_hall() -> void:
	casino = Casino.new()
	casino.name = "Casino"
	casino.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(casino)
	var scene_hall := get_node_or_null("WorldOverlays/Shops/FeuerwehrhausKorpitsch") as FireHall
	if scene_hall != null:
		hall = scene_hall
		hall.setup_in_scene(self, world)
	else:
		var info := FireHall.find(world)
		if not info.is_empty():
			hall = FireHall.new()
			hall.name = "FeuerwehrhausKorpitsch"
			add_child(hall)
			hall.setup(self, world, info)
	casino.setup(self, hall)
	var scene_gh := get_node_or_null("WorldOverlays/Shops/GasthausPirtscher") as Gasthaus
	if scene_gh != null:
		gasthaus = scene_gh
		gasthaus.setup_in_scene(self, world)
	else:
		var g_info := Gasthaus.find(world)
		if not g_info.is_empty():
			gasthaus = Gasthaus.new()
			gasthaus.name = "GasthausPirtscher"
			add_child(gasthaus)
			gasthaus.setup(self, world, g_info)


## Hinsetzen (Bank, Pokertisch): Figur sitzt, Kamera bleibt frei
func sit_down(pos: Vector3, yaw: float) -> void:
	if seat != "":
		return
	sitting = true
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.input_enabled = false
	player.sitting = true
	player.model.rotation.y = yaw
	player.reset_physics_interpolation()
	hud.toast("[F] Aufstehen", 1.5)


func stand_up() -> void:
	if not sitting:
		return
	sitting = false
	player.sitting = false
	player.input_enabled = true
	player.global_position += player.facing * 0.6 + Vector3.UP * 0.3


func get_map_marker(marker_name: String) -> Marker3D:
	var overlays := get_node_or_null("WorldOverlays/MapMarkers")
	if overlays == null:
		return null
	var found := overlays.find_child(marker_name, true, false)
	if found is Marker3D and (found as Marker3D).visible:
		return found as Marker3D
	return null


func _start_game() -> void:
	started = true
	if Net.is_client():
		Net.send_lobby_state("game", false)
	hud.visible = true
	var sp: Dictionary = landmarks.spawn
	var look: Vector2 = sp.look
	var fb_player_pos: Vector3 = sp.pos
	var fb_player_yaw := atan2(-look.x, -look.y)
	var player_marker := get_map_marker("PlayerSpawn")
	if player_marker != null:
		fb_player_pos = player_marker.global_position
		fb_player_yaw = player_marker.global_rotation.y
	player = Player.new()
	player.name = "Spieler"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.add_to_group("player_body")
	add_child(player)
	var p_xf := world.find_safe_spawn_transform(GameState.player_pos, GameState.player_rot_y, fb_player_pos, fb_player_yaw, 0.25)
	player.global_position = p_xf.origin
	player.rotation.y = p_xf.basis.get_euler().y
	player.reset_physics_interpolation()
	player.shot.connect(_on_shot)

	var scene_car := get_node_or_null("WorldOverlays/Vehicles/Pickup") as Truck
	if scene_car != null:
		car = scene_car
		if _default_car_xf == Transform3D.IDENTITY:
			_default_car_xf = car.global_transform
	else:
		car = Truck.new()
		car.name = "Pickup"
		add_child(car)
	car.world = world
	car.owner_name = GameState.player_name
	car.player_input = true

	var scene_atv := get_node_or_null("WorldOverlays/Vehicles/ATV") as ATV
	if scene_atv != null:
		atv = scene_atv
		if _default_atv_xf == Transform3D.IDENTITY:
			_default_atv_xf = atv.global_transform
		atv.world = world
		var fb_atv_pos := _default_atv_xf.origin
		var fb_atv_yaw := _default_atv_xf.basis.get_euler().y
		var atv_saved: Dictionary = GameState.vehicles_state.get("atv", {})
		var atv_pos := GameState._v3_from_arr(atv_saved.get("pos", null))
		var atv_yaw := float(atv_saved.get("rot", fb_atv_yaw))
		atv.global_transform = world.find_safe_spawn_transform(atv_pos, atv_yaw, fb_atv_pos, fb_atv_yaw, 1.0, [atv.get_rid()])
		atv.reset_physics_interpolation()
		Animal.threats.append(atv)
	elif not landmarks.atv_spawn.is_empty():
		atv = ATV.new()
		atv.name = "ATV"
		atv.world = world
		add_child(atv)
		var fb_atv_pos: Vector3 = landmarks.atv_spawn.pos
		var fb_atv_yaw: float = landmarks.atv_spawn.yaw
		var atv_marker := get_map_marker("AtvSpawn")
		if atv_marker != null:
			fb_atv_pos = atv_marker.global_position
			fb_atv_yaw = atv_marker.global_rotation.y
		var atv_saved: Dictionary = GameState.vehicles_state.get("atv", {})
		var atv_pos := GameState._v3_from_arr(atv_saved.get("pos", null))
		var atv_yaw := float(atv_saved.get("rot", fb_atv_yaw))
		atv.global_transform = world.find_safe_spawn_transform(atv_pos, atv_yaw, fb_atv_pos, fb_atv_yaw, 1.0, [atv.get_rid()])
		atv.reset_physics_interpolation()
		Animal.threats.append(atv)
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	car.add_to_group("vehicle")
	var fb_car_pos: Vector3 = _default_car_xf.origin if scene_car != null else sp.car_pos
	var fb_car_yaw: float = _default_car_xf.basis.get_euler().y if scene_car != null else atan2(sp.car_dir.x, sp.car_dir.z)
	if scene_car == null:
		var car_marker := get_map_marker("CarSpawn")
		if car_marker == null:
			car_marker = get_map_marker("TruckSpawn")
		if car_marker != null:
			fb_car_pos = car_marker.global_position
			fb_car_yaw = car_marker.global_rotation.y
	var tr_saved: Dictionary = GameState.vehicles_state.get("truck", {})
	var tr_pos := GameState._v3_from_arr(tr_saved.get("pos", null))
	var tr_yaw := float(tr_saved.get("rot", fb_car_yaw))
	car.global_transform = world.find_safe_spawn_transform(tr_pos, tr_yaw, fb_car_pos, fb_car_yaw, 1.2, [car.get_rid()])
	car.reset_physics_interpolation()
	if not car.has_meta("_cargo_lost_connected"):
		car.set_meta("_cargo_lost_connected", true)
		car.cargo_lost.connect(func(_n): hud.toast("Ladung verloren! (Spanngurte im Bauhaus)", 3.0))
	interactions.add(Truck.BED_SLOTS[0] + Vector3(0.45, 0.6, -0.4), 2.6, func(): return "Ladung lösen" if car.strapped else "Ladung festzurren", func(): _toggle_straps(car), func(): GameState.has("straps") and seat == "", car)
	interactions.add(Vector3(0, 0.5, 0), 3.2, "Fahrzeug aufstellen [E]", func(): car.respawn_safe(fb_car_pos, fb_car_yaw), func(): seat == "" and car.global_basis.y.y < 0.65, car)
	if GameState.truck.get("trailer", false):
		_spawn_trailer()
		var tl_saved: Dictionary = GameState.vehicles_state.get("trailer", {})
		var tl_pos := GameState._v3_from_arr(tl_saved.get("pos", null))
		if tl_pos.is_finite() and trailer:
			trailer.global_transform = world.find_safe_spawn_transform(tl_pos, float(tl_saved.get("rot", fb_car_yaw)), car.global_position - car.global_basis.z * 7.0, car.rotation.y, 0.8, [trailer.get_rid()])
			trailer.reset_physics_interpolation()

	rig = CameraRig.new()
	rig.name = "Kamera"
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)
	player.attach_camera(rig)
	rig.yaw = fb_player_yaw
	rig.set_target(player, 1.65, 5.0, false, _foot_fp)
	if not GameState.about_to_save.is_connected(_sync_state_for_save):
		GameState.about_to_save.connect(_sync_state_for_save)

	Animal.threats.assign([player, car])
	spawner.players.assign([player])
	police = PoliceManager.new()
	police.name = "Polizei"
	police.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(police)
	police.setup(self, world, landmarks)
	missions.setup(self)
	missions._on_chapter_start()
	spawner.died_hook = _on_animal_died

	if hud.minimap.world == null:
		hud.minimap.setup(world)
		hud.big_map.setup(world, true)
		hud.big_map.clicked.connect(func(p): set_waypoint(p))
		hud.resume_requested.connect(func(): set_paused(false))
		hud.quit_requested.connect(func(): Net.quit_game())
		hud.save_requested.connect(func():
			GameState.save_game()
			hud.toast("Gespeichert: %s" % GameState.slot_title, 2.0))
		hud.menu_requested.connect(_return_to_menu)
		Net.disconnected.connect(func(reason):
			if not started or DebugTools.active:
				return
			get_tree().paused = false
			hud.show_dialog("Verbindung getrennt", "%s.
Dein Fortschritt ist bis zur letzten Sicherung auf dem Server gespeichert." % reason, [["Zum Hauptmenü", _return_to_menu]]))
	hud.set_minimap(GameState.minimap_on)
	_sync_world()
	for d in GameState.dead_animals:
		if typeof(d) == TYPE_DICTIONARY:
			Animal.spawn_saved_carcass(spawner, world, d)

	if get_node_or_null("AmbienceAudio") == null:
		var amb := AudioStreamPlayer.new()
		amb.name = "AmbienceAudio"
		amb.stream = Sfx.ambience()
		amb.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
		amb.volume_db = -14.0
		amb.autoplay = true
		add_child(amb)

	if not GameState.story.get("talked", false) and int(GameState.story.chapter) == 1:
		hud.toast("Willkommen in Saint Leonard! Sprich mit Wirt Sepp (F).", 6.0)
	else:
		hud.toast("Willkommen zurück, %s!" % GameState.player_name, 4.0)
	if not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ Eingaben

func _unhandled_input(event: InputEvent) -> void:
	if not started or Net.is_dedicated():
		return
	if event.is_action_pressed("pause"):
		if _placing != "":
			_stop_placing()
		elif hud.menus_open():
			Menus.close_all(hud)
		elif hud.map_open():
			hud.toggle_map()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			set_paused(not get_tree().paused)
		return
	if get_tree().paused:
		return
	if hud.menus_open():
		return
	if _placing != "":
		_placing_input(event)
		return
	if player.passed_out > 0.0:
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("map"):
		hud.toggle_map()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hud.map_open() else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("phone"):
		Phone.open(self)
	elif event.is_action_pressed("inventory"):
		Menus.inventory(self)
	elif event.is_action_pressed("toggle_view"):
		if seat == "":
			rig.toggle_view()
	elif event.is_action_pressed("minimap"):
		toggle_minimap()
	elif event.is_action_pressed("mute"):
		Voice.muted = not Voice.muted
		hud.toast("Mikrofon stumm" if Voice.muted else "Mikrofon an")
	elif event.is_action_pressed("lights"):
		if seat == "driver":
			car.set_lights(not car.lights_on)
		elif seat == "":
			player.hand.toggle_flashlight()
	elif seat == "driver":
		_vehicle_input(event)
	elif seat == "":
		_foot_input(event)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not hud.map_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _foot_input(event: InputEvent) -> void:
	var slot_labels := {
		sniper = "Scharfschützengewehr",
		pistol = "Pistole",
		shotgun = "Schrotflinte",
		bolt_action = "Jagdgewehr (Bolt-Action)",
		assault_rifle = "AK-47 Sturmgewehr",
		lmg = "LMG Maschinengewehr",
		bazooka = "Bazooka / RPG",
		plasma_blaster = "Alien Plasma Blaster",
		none = "Hände frei",
	}
	if event.is_action_pressed("slot_1"):
		_select_slot("sniper", slot_labels.sniper)
	elif event.is_action_pressed("slot_2"):
		_select_slot("pistol", slot_labels.pistol)
	elif event.is_action_pressed("slot_3"):
		_select_slot("assault_rifle", slot_labels.assault_rifle)
	elif event.is_action_pressed("slot_4"):
		_select_slot("shotgun", slot_labels.shotgun)
	elif event.is_action_pressed("slot_5"):
		_select_slot("bolt_action", slot_labels.bolt_action)
	elif event.is_action_pressed("slot_6"):
		_select_slot("lmg", slot_labels.lmg)
	elif event.is_action_pressed("slot_7"):
		_select_slot("bazooka", slot_labels.bazooka)
	elif event.is_action_pressed("slot_8"):
		_select_slot("plasma_blaster", slot_labels.plasma_blaster)
	elif event.is_action_pressed("slot_9"):
		_select_slot("none", slot_labels.none)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and rig.first_person and not player.hand.aiming:
		var order := ["sniper", "pistol", "assault_rifle", "shotgun", "bolt_action", "lmg", "bazooka", "plasma_blaster", "none"].filter(func(s): return s == "none" or GameState.has(s))
		var i: int = order.find(player.hand.slot)
		var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		var nxt: String = order[(i + step + order.size()) % order.size()]
		_select_slot(nxt, slot_labels[nxt])
	elif event.is_action_pressed("reload"):
		player.hand.try_reload()
	elif event.is_action_pressed("crouch"):
		player.toggle_crouch()
	elif event.is_action_pressed("smoke"):
		use_item("cigarettes")
	elif event.is_action_pressed("drink"):
		for id in ["beer", "schnaps", "moonshine"]:
			if GameState.has(id):
				use_item(id)
				break
	elif event.is_action_pressed("cargo"):
		_cargo_action()


func _select_slot(s: String, label: String) -> void:
	var err: String = player.hand.select(s)
	hud.toast(err if not err.is_empty() else label, 1.2)


func _sync_state_for_save() -> void:
	if player and is_instance_valid(player):
		GameState.player_pos = seat_truck.global_position if seat_truck and is_instance_valid(seat_truck) else player.global_position
		GameState.player_rot_y = player.rotation.y
	var vs := {}
	if car and is_instance_valid(car):
		vs["truck"] = {
			pos = [car.global_position.x, car.global_position.y, car.global_position.z],
			rot = car.rotation.y,
			fuel = GameState.truck.get("fuel", Truck.TANK),
			damage = GameState.truck.get("damage", 0.0),
			cargo = GameState.truck.get("cargo", []),
		}
	if atv and is_instance_valid(atv):
		vs["atv"] = {
			pos = [atv.global_position.x, atv.global_position.y, atv.global_position.z],
			rot = atv.rotation.y,
		}
	if trailer and is_instance_valid(trailer):
		vs["trailer"] = {
			pos = [trailer.global_position.x, trailer.global_position.y, trailer.global_position.z],
			rot = trailer.rotation.y,
			hitched = trailer.towed_by != null,
		}
	GameState.vehicles_state = vs
	var da := []
	for node in get_tree().get_nodes_in_group("carcass"):
		var c := node as Carcass
		if c == null or c.sold or c.carried or c.get_parent() != spawner:
			continue
		da.append({
			species = c.species,
			male = c.male,
			net_id = c.net_id,
			pos = [c.global_position.x, c.global_position.y, c.global_position.z],
			rot = [c.rotation.x, c.rotation.y, c.rotation.z],
		})
	GameState.dead_animals = da


func _vehicle_input(event: InputEvent) -> void:
	var veh: Vehicle = seat_truck if seat_truck else car
	if veh == null:
		return
	if event.is_action_pressed("reset_vehicle"):
		var why := veh.can_flip()
		if why.is_empty():
			var sp: Dictionary = landmarks.spawn
			veh.respawn_safe(sp.car_pos, atan2(sp.car_dir.x, sp.car_dir.z))
		else:
			hud.toast(why, 1.5)
	elif event.is_action_pressed("horn"):
		veh.honk()
		Net.fx("horn", veh.global_position)
	elif event.is_action_pressed("radio"):
		hud.toast(veh.next_station())
	elif event.is_action_pressed("winch"):
		hud.toast(veh.toggle_winch(), 3.0)


func set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)
	if on:
		GameState.save_game()
	if not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func toggle_minimap() -> void:
	GameState.minimap_on = not GameState.minimap_on
	hud.set_minimap(GameState.minimap_on)


func set_waypoint(p: Vector2) -> void:
	waypoint = p
	hud.minimap.waypoint = p
	hud.big_map.waypoint = p
	var clr := hud.root.find_child("ClearWaypoint", true, false) as Button
	if clr:
		clr.disabled = p == Vector2.INF


# ------------------------------------------------------------------ Interaktion [F]

func _interact() -> void:
	if sitting:
		if casino.at_poker:
			casino.leave_poker()
		stand_up()
		return
	if seat != "":
		exit_vehicle()
		return
	if player.on_stand:
		var st := player.on_stand
		player.on_stand = null
		player.global_position = st.global_transform * Vector3(0, 0.2, -2.2)
		player.reset_physics_interpolation()
		return
	if player.carrying:
		_drop_carried()
		return
	if not _current_interaction.is_empty():
		(_current_interaction.action as Callable).call()
		return
	# Einsteigen
	if atv and player.global_position.distance_to(atv.global_position) < ENTER_DISTANCE:
		enter_vehicle(atv, "driver")
		return
	if player.global_position.distance_to(car.global_position) < ENTER_DISTANCE:
		enter_vehicle(car, "driver")
		return
	for id in remote_trucks:
		var t: Truck = remote_trucks[id]
		if player.global_position.distance_to(t.global_position) < ENTER_DISTANCE:
			var free := ["passenger", "bed_l", "bed_r"].filter(func(s): return not t.occupants.has(s))
			if not free.is_empty():
				enter_vehicle(t, free[0])
			return


## Was man gerade mit [F] tun kann (ohne Einsteigen)
func _update_interaction() -> String:
	_current_interaction = {}
	if sitting:
		return "[F] Aufstehen" + (" und auszahlen   (Pokertisch: Esc schließt das Fenster)" if casino.at_poker else "")
	if seat != "":
		return "[F] Aussteigen"
	if player.on_stand:
		return "[F] Vom Hochstand steigen"
	if player.carrying:
		if car.global_position.distance_to(player.global_position) < 5.0:
			return "[G] Auf die Ladefläche laden   [F] Ablegen"
		return "[F] Ablegen"
	var e := interactions.nearest(player.global_position)
	if not e.is_empty():
		_current_interaction = e
		return "[F] " + Interactions.text_of(e)
	# Kadaver
	var c := _nearest_carcass(2.8)
	if c:
		return "[F] %s ausnehmen (halten)   [G] tragen" % c.display_name()
	if atv and player.global_position.distance_to(atv.global_position) < ENTER_DISTANCE:
		return "[F] ATV fahren / Einsteigen"
	if player.global_position.distance_to(car.global_position) < ENTER_DISTANCE:
		var t := "[F] Einsteigen"
		if not car.cargo.is_empty():
			t += "   [G] Abladen"
		return t
	for id in remote_trucks:
		if player.global_position.distance_to(remote_trucks[id].global_position) < ENTER_DISTANCE:
			return "[F] Mitfahren bei %s" % Net.peers.get(id, {name = "?"}).name
	return ""


func _nearest_carcass(r: float) -> Carcass:
	var best: Carcass = null
	var bd := r
	for c in get_tree().get_nodes_in_group("carcass"):
		if c.carried or c.get_parent() is Truck:
			continue
		var d: float = c.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = c
	return best


func _cargo_action() -> void:
	if trailer and player.carrying and trailer.global_position.distance_to(player.global_position) < 3.5 and trailer.has_space():
		var tn := player.carrying
		player.carrying = null
		trailer.load_cargo(tn)
		if tn is Carcass:
			Net.carcass_removed((tn as Carcass).net_id)
		hud.toast("Auf den Anhänger geladen")
		return
	if trailer and not player.carrying and _nearest_carcass(2.8) == null and trailer.global_position.distance_to(player.global_position) < 3.5 and not trailer.cargo.is_empty():
		var un := trailer.unload_last()
		trailer.remove_child(un)
		add_child(un)
		un.scale = Vector3.ONE
		if un is Carcass:
			player.carrying = un
		else:
			un.global_position = player.global_position + player.facing * 1.5
		return
	if player.carrying:
		if car.global_position.distance_to(player.global_position) < 5.0 and car.has_space():
			var n := player.carrying
			player.carrying = null
			car.load_cargo(n)
			if n is Carcass:
				Net.carcass_removed((n as Carcass).net_id)
			hud.toast("Aufgeladen")
		return
	var c := _nearest_carcass(2.8)
	if c:
		c.set_carried(true)
		player.carrying = c
		player.hand.select("none")
		return
	if car.global_position.distance_to(player.global_position) < 5.0 and not car.cargo.is_empty():
		var n := car.unload_last()
		if n:
			car.remove_child(n)
			add_child(n)
			n.scale = Vector3.ONE
			if n is Carcass:
				player.carrying = n
			else:
				n.global_position = player.global_position + player.facing * 1.5


func _drop_carried() -> void:
	var c := player.carrying
	player.carrying = null
	if c is Carcass:
		c.set_carried(false)
		c.global_position = player.global_position + player.facing * 1.2 + Vector3.UP * 0.5


func _process_harvest(delta: float) -> void:
	var c := _nearest_carcass(2.8)
	var holding := Input.is_action_pressed("interact") and c != null and _current_interaction.is_empty() and seat == "" and player.carrying == null and not hud.menus_open()
	if holding and c == _harvest_target:
		_harvest_t += delta
		if not GameState.has("knife"):
			hud.toast("Dafür brauchst du ein Jagdmesser (Waffengeschäft)")
			_harvest_t = 0.0
		if _harvest_t >= 3.0:
			_harvest(c)
			_harvest_t = 0.0
	else:
		_harvest_target = c if holding else null
		_harvest_t = 0.0
	hud.set_progress(_harvest_t / 3.0)


func _harvest(c: Carcass) -> void:
	var loot := c.loot()
	var parts := []
	for id in loot:
		GameState.give(id, int(loot[id]))
		parts.append("%dx %s" % [loot[id], Items.display(id)])
	if c.species == "legend":
		missions.event("legend_killed")
	hud.toast("Ausgenommen: " + ", ".join(parts), 3.5)
	var trophy := TrophyBoard.record(c.species, c.male, c.net_id)
	if trophy != "":
		GameState.notify("Wirt Sepp", trophy)
	Net.carcass_removed(c.net_id)
	c.queue_free()


# ------------------------------------------------------------------ Fahrzeuge

var _foot_fp := true

func enter_vehicle(t: Vehicle, s: String) -> void:
	if seat == "":
		_foot_fp = rig.first_person
	seat = s
	seat_truck = t
	if spawner:
		var idx := spawner.players.find(player)
		if idx >= 0:
			spawner.players[idx] = t
	driving = s == "driver" and (t == car or t == atv)
	player.visible = false
	player.input_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	player.hand.select("none")
	player.hand.aiming = false
	if driving:
		t.driving = true
		t.player_input = true
		if t is ATV:
			(t as ATV).set_rider(true, GameState.outfit)
		if GameState.is_night():
			t.set_lights(true)
	Sfx.play_3d(t, Sfx.door(), -2.0)
	rig.seat_offset = (ATV.SEATS[s] if t is ATV else Truck.SEATS[s]) + Vector3(0, 0.6, 0)
	rig.set_target(t, 1.9, 6.5 if t is ATV else 9.0, true, false)
	rig.yaw = 0.0
	hud.set_driving(driving)


func exit_vehicle() -> void:
	var t := seat_truck
	if driving and absf(t.speed_kmh()) > 15.0:
		hud.toast("Zuerst langsamer werden!", 1.5)
		return
	if driving:
		t.driving = false
		if t is ATV:
			(t as ATV).set_rider(false)
		if t is Truck:
			(t as Truck).winching = false
	var side := -1.0 if seat == "passenger" else 1.0
	var p := t.global_position + t.global_basis.x * 2.2 * side
	if seat.begins_with("bed"):
		p = t.global_position - t.global_basis.z * 3.5
	player.global_position = Vector3(p.x, maxf(world.height_at(p.x, p.z), t.global_position.y - 0.5) + 0.3, p.z)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	Sfx.play_3d(t, Sfx.door(), -2.0, 1.1)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.collision_layer = 2
	player.input_enabled = true
	player.visible = true
	seat = ""
	if spawner and seat_truck:
		var idx := spawner.players.find(seat_truck)
		if idx >= 0:
			spawner.players[idx] = player
	seat_truck = null
	driving = false
	rig.set_target(player, 1.65, 5.0, false, _foot_fp)
	hud.set_driving(false)
	if GameState.has("sniper"):
		player.hand.select("sniper")


func truck_near(p: Vector3, r: float) -> bool:
	return car and car.global_position.distance_to(p) < r


func truck_has_game_near(p: Vector3, r: float) -> bool:
	if trailer and trailer.global_position.distance_to(p) < r:
		for n in trailer.cargo:
			if n is Carcass:
				return true
	if not truck_near(p, r):
		return false
	for n in car.cargo:
		if n is Carcass:
			return true
	return false


func _process_butcher_dropzones(dt: float) -> void:
	if landmarks == null or landmarks.butcher_zones.is_empty():
		return
	for n in get_tree().get_nodes_in_group("carcass"):
		if not (n is Carcass):
			continue
		var c := n as Carcass
		if c.sold or c.is_queued_for_deletion():
			continue
		if c.carried or c == player.carrying:
			c.set_meta("dropzone_t", 0.0)
			continue
		var in_zone: Dictionary = {}
		for z in landmarks.butcher_zones:
			var zp: Vector3 = z.node.global_position if (z.has("node") and is_instance_valid(z.node)) else z.pos
			if Vector2(c.global_position.x - zp.x, c.global_position.z - zp.z).length() <= 1.6 and absf(c.global_position.y - zp.y) < 2.5:
				in_zone = z
				break
		if in_zone.is_empty():
			c.set_meta("dropzone_t", 0.0)
			continue
		var t: float = float(c.get_meta("dropzone_t", 0.0)) + dt
		c.set_meta("dropzone_t", t)
		if t >= 0.3:
			c.sold = true
			c.remove_from_group("carcass")
			var val := c.sell_value()
			var cname := c.display_name()
			TrophyBoard.record(c.species, c.male, c.net_id)
			Net.carcass_removed(c.net_id)
			c.queue_free()
			GameState.add_money(val)
			hud.toast("+$%d — %s verkauft!" % [val, cname], 3.5)
			Sfx.play_2d(self, Sfx.jingle(false), -2.0)
			landmarks.flash_butcher_zone(in_zone)
			missions.event("sold_carcass")


func sell_single_carcass(c: Carcass, holder: Node) -> void:
	if not is_instance_valid(c) or c.sold or c.is_queued_for_deletion():
		return
	c.sold = true
	c.remove_from_group("carcass")
	var val := c.sell_value()
	if holder == player and player.carrying == c:
		player.carrying = null
	elif holder and "cargo" in holder:
		holder.cargo.erase(c)
	Net.carcass_removed(c.net_id)
	c.queue_free()
	GameState.add_money(val)
	hud.toast("GASTON: \"$%d. Ze texture... mon dieu!\"" % val, 3.0)
	missions.event("sold_carcass")


func sell_truck_cargo() -> void:
	var total := 0
	var count := 0
	if player.carrying is Carcass:
		var c := player.carrying as Carcass
		if not c.sold and not c.is_queued_for_deletion():
			c.sold = true
			c.remove_from_group("carcass")
			player.carrying = null
			total += c.sell_value()
			count += 1
			Net.carcass_removed(c.net_id)
			c.queue_free()
	var holders: Array = [car]
	if trailer:
		holders.append(trailer)
	for h in holders:
		for n in h.cargo.duplicate():
			if n is Carcass:
				var cc := n as Carcass
				if cc.sold or cc.is_queued_for_deletion():
					h.cargo.erase(n)
					continue
				cc.sold = true
				cc.remove_from_group("carcass")
				total += cc.sell_value()
				count += 1
				h.cargo.erase(n)
				Net.carcass_removed(cc.net_id)
				cc.queue_free()
	if count == 0:
		open_shop("butcher")
		return
	GameState.add_money(total)
	hud.toast("GASTON: \"$%d. Ze texture... mon dieu!\" (%d Stück)" % [total, count], 3.5)
	missions.event("sold_carcass")


func fuel_prompt() -> String:
	var need := int(ceil(Truck.TANK - float(GameState.truck.fuel)))
	return "Volltanken (%d l, $%d)" % [need, int(need * 1.85)]


func refuel() -> void:
	var need := Truck.TANK - float(GameState.truck.fuel)
	var cost := int(need * 1.85)
	if need < 1.0:
		hud.toast("Der Tank ist voll")
		return
	if not GameState.pay(cost):
		var liters := float(maxi(GameState.money, 0)) / 1.85
		GameState.pay(maxi(GameState.money, 0))
		GameState.truck.fuel = float(GameState.truck.fuel) + liters
		hud.toast("Für %d l hat's gereicht" % int(liters))
		return
	GameState.truck.fuel = Truck.TANK
	hud.toast("Vollgetankt: $%d" % cost)


func use_jerrycan() -> void:
	if GameState.take("jerrycan"):
		GameState.truck.fuel = minf(Truck.TANK, float(GameState.truck.fuel) + 20.0)
		hud.toast("20 l nachgefüllt")


func tow_truck_to_garage() -> void:
	var bay: Vector3 = landmarks.garage.bay
	car.place_at(bay, Vector3(sin(landmarks.garage.yaw), 0, cos(landmarks.garage.yaw)))
	hud.toast("Der Pickup steht vor der Werkstatt")


func tow_truck_to_player() -> void:
	var p := player.global_position + player.facing * 6.0
	var info := world.road_info(Vector2(p.x, p.z), 60.0)
	if info.tier != 0:
		p = Vector3(info.pos.x, 0, info.pos.y)
	car.place_at(p, Vector3(info.dir.x, 0, info.dir.y) if info.tier != 0 else player.facing)
	GameState.truck.fuel = maxf(float(GameState.truck.fuel), 10.0)
	hud.toast("Pannenhilfe: Pickup steht bereit (10 l im Tank)")


# ------------------------------------------------------------------ Läden, Werkstatt, Häuser

func open_shop(id: String) -> void:
	missions.event("shop_open", {id = id})
	Menus.shop(self, id)


## Eigenen Anhänger hinter den Pickup stellen
func _spawn_trailer() -> void:
	if trailer:
		return
	trailer = Trailer.new()
	trailer.name = "Anhaenger"
	trailer.world = world
	trailer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(trailer)
	var back: Vector3 = car.global_position - car.global_basis.z * 7.0
	back.y = world.height_at(back.x, back.z) + 0.8
	trailer.global_transform = Transform3D(car.global_basis.orthonormalized(), back)
	trailer.reset_physics_interpolation()
	trailer.cargo_lost.connect(func(_n): hud.toast("Ladung vom Anhänger gefallen! (Spanngurte)", 3.0))
	interactions.add(Trailer.HITCH + Vector3(0, 0.4, 0), 3.0, func(): return "Anhänger abkuppeln" if trailer.towed_by else "Anhänger ankuppeln",
		func(): _toggle_hitch(), func(): seat == "" and (trailer.towed_by != null or trailer.can_couple(car)), trailer)
	interactions.add(Vector3(0, 1.0, -0.4), 2.4, func(): return "Ladung lösen" if trailer.strapped else "Ladung festzurren", func(): _toggle_straps(trailer), func(): GameState.has("straps") and seat == "", trailer)


func _toggle_hitch() -> void:
	if trailer.towed_by:
		trailer.uncouple()
		hud.toast("Anhänger abgekuppelt", 1.5)
	elif trailer.can_couple(car):
		trailer.couple(car)
		Sfx.play_3d(trailer, Sfx.door(), -2.0, 1.4)
		hud.toast("Anhänger angekuppelt", 1.5)


func _toggle_straps(v: Node3D) -> void:
	v.set_strapped(not v.strapped)
	Sfx.play_3d(v, Sfx.click(), -4.0, 0.7)
	hud.toast("Ladung festgezurrt" if v.strapped else "Gurte gelöst", 1.5)


func on_bought(item: String, _shop: String) -> void:
	if item == "trailer":
		GameState.take("trailer")
		if GameState.truck.get("trailer", false):
			GameState.add_money(int(Items.info("trailer").price))
			hud.toast("Du hast schon einen Anhänger")
			return
		GameState.truck.trailer = true
		_spawn_trailer()
		set_waypoint(Vector2(trailer.global_position.x, trailer.global_position.z))
		hud.toast("Der Anhänger steht hinter deinem Pickup", 3.0)
		return
	missions.event("bought", {id = item})
	if item in ["sniper", "pistol", "assault_rifle"]:
		player.hand.select(item)


func on_sold(item: String, n: int, _shop: String) -> void:
	missions.event("sold", {id = item, n = n})


func open_garage() -> void:
	Menus.garage(self)


func police_desk() -> void:
	hud.show_dialog("Polizeiinspektion", police.pay_open_fines(), [["OK", func(): pass]])


func buy_house(type_idx: int) -> void:
	var h: Dictionary = Items.HOUSES[type_idx]
	if GameState.house >= 0:
		hud.toast("Du hast schon ein Haus")
		return
	# freien Bauplatz nahe Saint Leonard nehmen
	var plot := -1
	for pl in landmarks.plots:
		if not GameState.houses.has(str(pl.idx)):
			plot = pl.idx
			break
	if plot < 0:
		hud.toast("Kein Bauplatz mehr frei")
		return
	if not GameState.pay(h.price):
		hud.toast("Zu wenig Geld")
		return
	GameState.house = plot
	Net.request_house(plot, type_idx)
	if Net.is_client():
		hud.toast("Kaufvertrag geht an die Gemeinde ...", 2.0)
		return
	_house_bought(plot, type_idx)


## Antwort des Servers auf einen Hauskauf
func on_house_result(plot: int, type_idx: int, ok: bool) -> void:
	if ok:
		_house_bought(plot, type_idx)
		return
	GameState.house = -1
	GameState.add_money(int(Items.HOUSES[type_idx].price))
	hud.show_dialog("Bauplatz vergeben", "Jemand war schneller (oder du hast schon ein Haus). Das Geld bekommst du zurück.", [["OK", func(): pass]])


func _house_bought(plot: int, type_idx: int) -> void:
	var h: Dictionary = Items.HOUSES[type_idx]
	missions.event("house")
	var pl: Dictionary = landmarks.plots[plot]
	set_waypoint(Vector2(pl.pos.x, pl.pos.z))
	hud.show_dialog("Haus gekauft", "%s auf Bauplatz %d gehört jetzt dir! Der Wegpunkt zeigt hin.\nMöbel gibt es im Bauhaus, an der Werkbank stellst du Trophäen, Kleidung und Grillfleisch her, im Bett schläfst du bis zum Morgen." % [h.name, plot + 1], [["Super", func(): pass]])


func refresh_plot(pl: Dictionary) -> void:
	var n: Node3D = pl.node
	for c in n.get_children():
		c.queue_free()
	interactions.remove_node(n)
	var key := str(pl.idx)
	if GameState.houses.has(key):
		var info: Dictionary = GameState.houses[key]
		var house := HouseBuilder.build(n, pl, int(info.type), str(info.owner), world)
		house_nodes[pl.idx] = house
		if info.owner == GameState.player_name:
			var bench: Node3D = house.get_meta("bench")
			var bed: Node3D = house.get_meta("bed")
			interactions.add(Vector3(0, 1, 0.8), 2.2, "Werkbank", func(): Menus.inventory(self), null, bench)
			interactions.add(Vector3(0, 0.6, 0), 2.2, "Schlafen bis zum Morgen", func(): _sleep(), null, bed)
			var chest: Node3D = house.get_meta("chest")
			interactions.add(Vector3(0, 0.5, 0), 1.8, "Truhe öffnen", func(): ChestMenu.open(self, "Truhe", GameState.house_chest, func(): pass), null, chest)
	else:
		house_nodes.erase(pl.idx)
		landmarks.plot_sign(pl)


func inside_own_house(p: Vector3) -> bool:
	if GameState.house < 0 or not house_nodes.has(GameState.house):
		return false
	var h: Node3D = house_nodes[GameState.house]
	var local := h.global_transform.affine_inverse() * p
	var half: Vector2 = h.get_meta("half")
	return absf(local.x) < half.x and absf(local.z) < half.y and local.y > -1.0 and local.y < 7.0


func _sleep() -> void:
	hud.set_fade(1.0)
	var target := 7.0
	if GameState.time > target:
		GameState.day += 1
	GameState.time = target
	GameState.health = 100.0
	GameState.stamina = 100.0
	GameState.bac = 0.0
	GameState.save_game()
	await get_tree().create_timer(1.0).timeout
	hud.set_fade(0.0)
	hud.toast("Guten Morgen! Tag %d" % GameState.day, 3.0)


func wear(id: String) -> void:
	var msg := Outfit.wear(id)
	player.rebuild_model()
	Net.send_outfit()
	if msg != "":
		hud.toast(msg, 1.5)


func decorate_pub_trophy() -> void:
	var t := Placeables.model("trophy")
	add_child(t)
	var door: Vector3 = landmarks.pub.door
	var pubp: Vector3 = landmarks.pub.pos
	var out := (door - pubp)
	out.y = 0
	out = out.normalized()
	t.global_position = door + Vector3.UP * 3.2 - out * 0.1
	t.scale = Vector3.ONE * 2.5
	t.look_at(t.global_position + out, Vector3.UP)
	t.rotate_object_local(Vector3.UP, PI)
	if gasthaus and gasthaus.board:
		gasthaus.board.refresh.call_deferred()  # Ehrenplatz für den Riesenhirsch


func start_festival() -> void:
	if _festival:
		return
	_festival = Node3D.new()
	add_child(_festival)
	var door: Vector3 = landmarks.pub.door
	_festival.global_position = door
	for k in 14:
		var a := TAU * k / 14.0
		var l := OmniLight3D.new()
		l.light_color = Color.from_hsv(k / 14.0, 0.7, 1.0)
		l.omni_range = 6.0
		l.light_energy = 2.0
		l.position = Vector3(cos(a) * 9.0, 3.0, sin(a) * 9.0)
		_festival.add_child(l)
		Placeables.box(_festival, Vector3(0.3, 0.3, 0.3), l.position, l.light_color)
	var r := Radio.new()
	r.max_distance = 80.0
	r.unit_size = 12.0
	_festival.add_child(r)
	r.next_station()
	for k in 5:
		var n := Npc.new("", {shirt = Color.from_hsv(randf(), 0.6, 0.8), hat = "hunter" if k % 2 == 0 else "cap"})
		_festival.add_child(n)
		n.position = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	hud.show_dialog("Das Fest!", "Ganz Saint Leonard feiert beim Gasthaus Pirtscher. Der Inspektor gibt auf, das Gasthaus bleibt offen. Prost!", [["Prost!", func(): pass]])


# ------------------------------------------------------------------ Konsum

func use_item(id: String) -> void:
	var it := Items.info(id)
	if not GameState.has(id):
		hud.toast("Keine %s mehr" % it.name)
		return
	var kind: String = {drink = "drink", smoke = "smoke", food = "eat"}.get(it.kind, "")
	var effect := func():
		var msg := ""
		match it.kind:
			"drink": msg = GameState.drink(id)
			"smoke": msg = GameState.smoke()
			"food": msg = GameState.eat(id)
		if not msg.is_empty():
			hud.toast(msg, 2.5)
		if id == "beer" and randf() < 0.45:
			get_tree().create_timer(1.4).timeout.connect(func():
				Sfx.play_3d(player, Sfx.burp(), 2.0, randf_range(0.85, 1.1))
				GameState.make_noise(player.global_position, 35.0, "burp")
				Net.fx("burp", player.global_position)
				hud.toast("*Rülps*", 1.2))
		# zu viel: Ohnmacht
		if GameState.promille() >= 3.0 and player.passed_out <= 0.0:
			_pass_out("Zu viel Schnaps! Du bist umgekippt.")
	if seat == "" and rig.first_person and kind != "":
		if not player.hand.play_action(kind, effect):
			hud.toast("Gerade beschäftigt", 1.0)
	else:
		player.hand.action = kind
		effect.call()
		get_tree().create_timer(2.0).timeout.connect(func(): player.hand.action = "")


func _pass_out(text: String) -> void:
	if seat != "":
		exit_vehicle()
	hud.toast(text, 4.0)
	player.pass_out(25.0)
	var tw := create_tween()
	tw.tween_method(func(v): hud.set_fade(v), 0.0, 0.85, 2.0)
	tw.tween_interval(20.0)
	tw.tween_method(func(v): hud.set_fade(v), 0.85, 0.0, 3.0)
	GameState.bac = minf(GameState.bac, 0.2)


# ------------------------------------------------------------------ Aufstellen

func start_placing(id: String) -> void:
	_placing = id
	_ghost_rot = 0.0
	_ghost = Placeables.model(id)
	add_child(_ghost)
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m:
			m = m.duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.6
			m.next_pass = null
			(mi as MeshInstance3D).material_override = m
		for sb in mi.find_children("*", "StaticBody3D", true, false):
			sb.queue_free()
	hud.toast("[Maus links] aufstellen   [Mausrad] drehen   [Maus rechts / Esc] abbrechen", 5.0)


func _stop_placing() -> void:
	_placing = ""
	if _ghost:
		_ghost.queue_free()
	_ghost = null


func _placing_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: _ghost_rot += 0.2
			MOUSE_BUTTON_WHEEL_DOWN: _ghost_rot -= 0.2
			MOUSE_BUTTON_RIGHT: _stop_placing()
			MOUSE_BUTTON_LEFT: _confirm_place()


func _ghost_transform() -> Transform3D:
	var ray := rig.aim_ray()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(ray[0], ray[0] + ray[1] * 7.0, 1)
	var hit := space.intersect_ray(q)
	var pos: Vector3
	var basis := Basis(Vector3.UP, rig.yaw + PI + _ghost_rot)
	if hit:
		pos = hit.position
		if Placeables.is_wall_item(_placing) and absf(hit.normal.y) < 0.4:
			pos += hit.normal * 0.04
			basis = Basis.looking_at(-hit.normal, Vector3.UP)
			pos.y = maxf(pos.y, player.global_position.y + 1.2)
	else:
		pos = ray[0] + ray[1] * 5.0
		pos.y = world.height_at(pos.x, pos.z)
	return Transform3D(basis, pos)


func _confirm_place() -> void:
	var xf := _ghost_transform()
	var err := Placeables.check(_placing, xf.origin, self)
	if not err.is_empty():
		hud.toast(err, 3.0)
		return
	if not GameState.take(_placing):
		_stop_placing()
		return
	var data := {}
	if _placing in ["frame", "frame_big"] and not GameState.photos.is_empty():
		data.photo = GameState.photos[-1]
	var e := {uid = GameState.new_uid(), type = _placing, pos = [xf.origin.x, xf.origin.y, xf.origin.z],
		rot = xf.basis.get_euler().y, wall = Placeables.is_wall_item(_placing), owner = GameState.player_name, data = data}
	if e.wall:
		var q := xf.basis.get_rotation_quaternion()
		e.quat = [q.x, q.y, q.z, q.w]
	Net.request_place(e)
	missions.event("placed", {type = _placing})
	hud.toast("%s aufgestellt" % Items.display(_placing))
	var id := _placing
	_stop_placing()
	if GameState.has(id):
		start_placing(id)


func pick_up_placed(entry: Dictionary) -> void:
	GameState.give(entry.type)
	Net.request_remove(int(entry.uid))


func placed_changed(entry: Dictionary) -> void:
	Net.update_placed(entry)


## Aufgestellte Dinge und Häuser mit GameState abgleichen
func _sync_world() -> void:
	var seen := {}
	for e in GameState.placed:
		var uid := int(e.uid)
		seen[uid] = true
		if not placed_nodes.has(uid):
			placed_nodes[uid] = _spawn_placed(e)
	for uid in placed_nodes.keys():
		if not seen.has(uid):
			var n: Node3D = placed_nodes[uid]
			if is_instance_valid(n):
				interactions.remove_node(n)
				n.queue_free()
			placed_nodes.erase(uid)
	if landmarks:
		for pl in landmarks.plots:
			var has_house := house_nodes.has(pl.idx)
			if has_house != GameState.houses.has(str(pl.idx)) or (not has_house and pl.node.get_child_count() == 0):
				refresh_plot(pl)
	# eigenes Haus merken (Mehrspieler)
	for k in GameState.houses:
		if GameState.houses[k].owner == GameState.player_name:
			GameState.house = int(k)


func _spawn_placed(e: Dictionary) -> Node3D:
	var n := Placeables.model(e.type)
	n.set_meta("uid", int(e.uid))
	add_child(n)
	var pos := Vector3(e.pos[0], e.pos[1], e.pos[2])
	if e.get("wall", false) and e.has("quat"):
		n.global_transform = Transform3D(Basis(Quaternion(e.quat[0], e.quat[1], e.quat[2], e.quat[3])), pos)
	else:
		n.global_position = pos
		n.rotation.y = float(e.rot)
	var entry := e
	match e.type:
		"still":
			interactions.add(Vector3(0, 1, 0), 3.0, "Brennkessel", func(): Menus.still(self, entry), null, n)
		"stand":
			interactions.add(Vector3(0, 0.5, -1.4), 2.5, "Hochstand besteigen", func():
				player.on_stand = n
				player.crouched = false, null, n)
		"campfire":
			var fire := _fire_fx()
			n.add_child(fire)
			interactions.add(Vector3.ZERO, 2.5, func(): return "Wildfleisch grillen (%d roh)" % GameState.count("meat"), func():
				if GameState.take("meat"):
					GameState.give("meat_cooked")
					hud.toast("Fleisch gegrillt")
				else:
					hud.toast("Kein rohes Wildfleisch"), null, n)
		"trailcam":
			var cam_timer := Timer.new()
			cam_timer.wait_time = 2.0
			cam_timer.autostart = true
			n.add_child(cam_timer)
			var seen := {}
			cam_timer.timeout.connect(func(): _trailcam_check(n, seen))
			interactions.add(Vector3(0, 1, 0), 2.0, "Wildkamera abbauen", func(): pick_up_placed(entry), null, n)
		"frame", "frame_big":
			_show_photo(n, e)
	if Items.info(e.type).kind == "furniture" and e.owner == GameState.player_name:
		interactions.add(Vector3(0, 0.5, 0), 1.6, "%s einpacken" % Items.display(e.type), func(): pick_up_placed(entry), null, n)
		interactions.add(Vector3(0, 0.8, 0), 1.6, "%s verschieben" % Items.display(e.type), func():
			pick_up_placed(entry)
			start_placing(entry.type), null, n)
	if e.type == "chest" and e.owner == GameState.player_name:
		if not e.data.has("items"):
			e.data.items = {}
		interactions.add(Vector3(0, 0.6, 0.3), 1.6, "Truhe öffnen", func(): ChestMenu.open(self, "Truhe", entry.data.items, func(): placed_changed(entry)), null, n)
	if e.type in ["frame", "frame_big"] and e.owner == GameState.player_name and GameState.photos.size() > 1:
		interactions.add(Vector3(0, 0, 0.2), 1.6, "Anderes Foto", func(): _next_photo(entry, n), null, n)
	return n


## Foto im Bilderrahmen anzeigen (klein oder groß)
func _show_photo(n: Node3D, e: Dictionary) -> void:
	for c in n.get_children():
		if c.has_meta("photo"):
			c.queue_free()
	if not e.data.has("photo"):
		return
	var img := Image.load_from_file(e.data.photo)
	if img == null:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.52, 0.37) if e.type == "frame" else Vector2(1.0, 0.7)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = m
	q.position.z = 0.03
	q.set_meta("photo", true)
	n.add_child(q)


## Nächstes eigenes Foto in den Rahmen
func _next_photo(entry: Dictionary, n: Node3D) -> void:
	var list: Array = GameState.photos
	if list.is_empty():
		return
	var i: int = list.find(entry.data.get("photo", ""))
	entry.data.photo = list[(i + 1) % list.size()]
	_show_photo(n, entry)
	placed_changed(entry)


func _fire_fx() -> Node3D:
	var root := Node3D.new()
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.9
	p.position.y = 0.2
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.7
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.2, 1.0))
	grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.draw_pass_1 = q
	root.add_child(p)
	var l := OmniLight3D.new()
	l.position.y = 0.6
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = 10.0
	l.light_energy = 2.0
	root.add_child(l)
	var s := AudioStreamPlayer3D.new()
	s.stream = Sfx.fire()
	s.autoplay = true
	s.unit_size = 3.0
	s.volume_db = -6.0
	root.add_child(s)
	return root


func _trailcam_check(cam: Node3D, seen: Dictionary) -> void:
	for a in spawner.animals.values():
		if not is_instance_valid(a):
			continue
		if a.global_position.distance_to(cam.global_position) < 30.0 and not seen.has(a.net_id):
			seen[a.net_id] = true
			var n: String = Animal.SPECIES[a.species].name
			if a.species == "deer" and a.male:
				n = "Rehbock"
			Phone.trailcam_log.append("%s  %s bei Kamera %d" % [GameState.clock_text(), n, int(cam.get_meta("uid")) % 100])
			if Phone.trailcam_log.size() > 50:
				Phone.trailcam_log.pop_front()
			if a.species in ["legend", "bear"]:
				GameState.notify("Wildkamera", "%s gesichtet!" % n)


func still_explode(entry: Dictionary) -> void:
	var uid := int(entry.uid)
	var n: Node3D = placed_nodes.get(uid)
	var pos := Vector3(entry.pos[0], entry.pos[1], entry.pos[2])
	Net.fx("boom", pos)
	var boom := Node3D.new()
	add_child(boom)
	boom.global_position = pos
	Sfx.play_3d(boom, Sfx.explosion(), 10.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.6, 0.2)
	flash.omni_range = 30.0
	flash.light_energy = 8.0
	boom.add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 1.5)
	# Rauchsäule, die man weit sieht
	var smoke := GPUParticles3D.new()
	smoke.amount = 60
	smoke.lifetime = 12.0
	smoke.visibility_aabb = AABB(Vector3(-20, 0, -20), Vector3(40, 120, 40))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0.3, 0.2, 0)
	pm.scale_min = 3.0
	pm.scale_max = 7.0
	pm.color = Color(0.2, 0.2, 0.22, 0.7)
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	smoke.draw_pass_1 = q
	boom.add_child(smoke)
	get_tree().create_timer(180.0).timeout.connect(boom.queue_free)
	GameState.make_noise(pos, 1200.0, "shot")
	if player.global_position.distance_to(pos) < 8.0:
		GameState.damage(45.0)
		rig.shake(2.0)
		player.model.soot(90.0)
		player.knockdown(2.5, "Rußgesicht!")
	if is_instance_valid(n):
		interactions.remove_node(n)
	Net.request_remove(uid)
	hud.toast("BUMM! Der Kessel ist explodiert. Die Rauchsäule lockt die Polizei an!", 5.0)
	police.dispatch(pos, "Rauchsäule im Wald")


# ------------------------------------------------------------------ Schießen

func _on_shot(from: Vector3, dir: Vector3) -> void:
	Net.fx("shot", from)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 700.0, 1 | 4 | 8 | 16)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	var impact_pt: Vector3 = hit.position if hit else from + dir * 200.0
	var r_noise: float = player.hand.current_noise_radius()
	Animal.notify_gunshot(get_tree(), from, impact_pt, r_noise, r_noise, player)
	_spawn_tracer(from + dir * 0.8 - Vector3(0, 0.08, 0), impact_pt, Color(0.314, 1.0, 0.314) if player.hand.slot == "plasma_blaster" else Color(1.0, 0.878, 0.333))
	# Schüsse im Ort rufen die Polizei
	if landmarks.near_village(Vector2(from.x, from.z)) and randf() < 0.5:
		police.dispatch(from, "Schüsse im Ortsgebiet")
	if not hit:
		return
	var col: Object = hit.collider
	_impact(hit.position, hit.normal)
	if player.hand.slot == "bazooka":
		_bazooka_blast(hit.position)
		return
	if col is Animal:
		var a := col as Animal
		var dmg := player.hand.current_damage()
		hud.hitmarker()
		if player.hand.slot == "plasma_blaster":
			a.levitate(4.5)
		if Net.is_client():
			Net.hit_animal(a.net_id, dmg, hit.position, dir)
		else:
			a.hit(dmg, hit.position, dir, player)
			if a.is_dead():
				hud.hitmarker(true)
				hud.toast("Waidmannsheil! %s erlegt" % Animal.SPECIES[a.species].name, 2.5)
	elif col is PoliceCar:
		GameState.police_heat += 2.0
		hud.toast("Du hast auf die Polizei geschossen!", 3.0)
	elif col is Carcass:
		(col as RigidBody3D).apply_impulse(dir * 40.0, hit.position - (col as Node3D).global_position)


func _bazooka_blast(pos: Vector3) -> void:
	Sfx.play_3d(self, Sfx.explosion(), 6.0, 0.85)
	if rig:
		rig.shake(1.8)
	# Feuerball & Rauch-GPUParticles3D (One-Shot mit sauberem Cleanup)
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.85
	p.one_shot = true
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, 2.5, 0)
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.533, 0.067)  # #FF8811
	s.material = fm
	p.process_material = pm
	p.draw_pass_1 = s
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

	# Druckwellen-Kugel (expandierendes Glow-Mesh)
	var wave := MeshInstance3D.new()
	var ws := SphereMesh.new()
	ws.radius = 1.0
	ws.height = 2.0
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(1.0, 0.65, 0.2, 0.65)
	ws.material = wm
	wave.mesh = ws
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wave)
	wave.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wave, "scale", Vector3.ONE * 7.5, 0.35)
	tw.tween_property(wm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(wave.queue_free)

	for n in get_tree().get_nodes_in_group("animal"):
		if n is Animal and (n as Node3D).global_position.distance_to(pos) < 7.5:
			var a := n as Animal
			var d := (a.global_position - pos).normalized()
			if not Net.is_client():
				a.die(d, true)
	for n in get_tree().get_nodes_in_group("carcass"):
		if n is RigidBody3D and (n as Node3D).global_position.distance_to(pos) < 8.0:
			var rb := n as RigidBody3D
			rb.apply_central_impulse((rb.global_position - pos).normalized() * 350.0 + Vector3.UP * 180.0)


func _spawn_tracer(from: Vector3, to: Vector3, col: Color) -> void:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return
	var len := minf(dist, 28.0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, len)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var dir := (to - from).normalized()
	mi.global_position = from + dir * (len * 0.5)
	mi.look_at(to, Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func _impact(pos: Vector3, normal: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal
	pm.spread = 35.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.scale_min = 0.1
	pm.scale_max = 0.25
	pm.color = Color(0.45, 0.38, 0.3)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _on_animal_died(a: Animal, c: Carcass) -> void:
	if a.species == "legend":
		GameState.notify("Wirt Sepp", "Der Riesenhirsch! Nimm ihn aus und bring mir das Geweih.")
	if Net.is_server():
		Net.animal_killed_on_server(a.net_id, Vector3.ZERO)
	c.net_id = a.net_id


func take_photo() -> void:
	hud.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/foto_%d.png" % Time.get_unix_time_from_system()
	img.save_png(path)
	GameState.photos.append(path)
	Sfx.play_2d(self, Sfx.shutter(), -2.0)
	hud.toast("Foto gespeichert (Fotorahmen im Bauhaus)")


# ------------------------------------------------------------------ Ablauf

func _process(delta: float) -> void:
	if not started or Net.is_dedicated() or get_tree().paused:
		return
	_dropzone_t += delta
	if _dropzone_t >= 0.2:
		_process_butcher_dropzones(_dropzone_t)
		_dropzone_t = 0.0
	# Sicherheitsnetz: niemand fällt durch die Welt
	if seat == "":
		var pg := world.height_at(player.global_position.x, player.global_position.z)
		if player.global_position.y < pg - 4.0:
			player.global_position.y = pg + 1.0
	if is_instance_valid(car):
		var cg := world.height_at(car.global_position.x, car.global_position.z)
		if car.global_position.y < cg - 4.0:
			car.place_at(car.global_position, car.global_basis.z)
	# Gesundheit
	if GameState.health <= 0.0 and player.passed_out <= 0.0:
		GameState.health = 35.0
		GameState.add_money(-mini(150, maxi(GameState.money, 0)))
		_pass_out("Schwer verletzt! Der Notarzt kostet $150.")
	if _placing != "" and _ghost:
		_ghost.global_transform = _ghost_transform()
		var ok := Placeables.check(_placing, _ghost.global_position, self).is_empty()
		hud.set_prompt("Aufstellen: %s%s" % [Items.display(_placing), "" if ok else "  (hier nicht erlaubt)"])
	else:
		hud.set_prompt(_update_interaction() if player.passed_out <= 0.0 else "")
	_process_harvest(delta)

	var focus: Node3D = seat_truck if seat != "" else player
	var pos2 := Vector2(focus.global_position.x, focus.global_position.z)
	var head: Vector3 = seat_truck.global_basis.z if seat != "" else player.facing
	for m in [hud.minimap, hud.big_map]:
		m.player_pos = pos2
		m.heading = Vector2(head.x, head.z)
	hud.minimap.center = pos2
	_place_timer -= delta
	if _place_timer <= 0.0:
		var other_m := _other_markers()
		var gps_ok := _gps_allowed()
		for m in [hud.minimap, hud.big_map]:
			m.others = other_m
			m.show_route = gps_ok
		_place_timer = 0.4
		_update_place(pos2)
	hud.update_status()
	hud.set_view(rig.first_person, player.hand.aiming, player.hand.slot, seat != "")
	if seat == "driver":
		hud.set_speed(car.speed_kmh(), GameState.truck.fuel, GameState.truck.damage, WorldBuilder.TIER_NAMES[car.surface.tier] + (" (matschig)" if GameState.wetness > 0.4 and car.surface.tier != 1 and car.surface.tier != 2 else ""))
		if GameState.truck.fuel <= 0.0:
			hud.set_alert("Tank leer! Reservekanister oder Pannenhilfe (Handy)")
		elif car.broken:
			hud.set_alert("Motorschaden! Werkstatt oder Pannenhilfe (Handy)")
	if waypoint != Vector2.INF and pos2.distance_to(waypoint) < 15.0:
		set_waypoint(Vector2.INF)
		hud.toast("Ziel erreicht")


## Im Auto mit Beifahrer sieht nur der Beifahrer das Navi (Rallye-Ansage)
func _gps_allowed() -> bool:
	if seat != "driver":
		return true
	for id in remote_players:
		var rp: RemotePlayer = remote_players[id]
		if rp.seat_owner == Net.my_id() and rp.seat == "passenger":
			return false
	return true


func _other_markers() -> Array:
	var out := []
	for id in remote_players:
		var rp: RemotePlayer = remote_players[id]
		out.append([Vector2(rp.global_position.x, rp.global_position.z), rp.player_name])
	var lp := spawner.legend_pos()
	if lp != Vector3.INF and GameState.story.get("talked", false):
		out.append([Vector2(lp.x, lp.z) + Vector2(60, -40), "Riesenhirsch gesichtet?"])
	return out


func _update_place(p: Vector2) -> void:
	var poi := world.nearest_poi(p)
	var road := world.road_info(p, 15.0)
	var place := world.nearest_place(p)
	var title: String = place.name
	if title in ["Riegersdorf", "Sankt Leonhard bei Siebenbrünn"]:
		title = "Saint Leonard (%s)" % ("Riegersdorf" if title == "Riegersdorf" else "St. Leonhard")
	if p.distance_to(landmarks.city_center) < 700.0:
		title = "Die Stadt (Fürnitz)"
	if hall and Vector2(hall.global_position.x, hall.global_position.z).distance_to(p) < 30.0:
		title = "Feuerwehrhaus Korpitsch"
	var sub := ""
	if poi.dist < 45.0:
		title = poi.name
		sub = place.name
	if road.tier != 0:
		var rn: String = road.name if not road.name.is_empty() else WorldBuilder.TIER_NAMES[road.tier]
		if rn != sub and rn != title:
			sub = rn if sub.is_empty() else "%s, %s" % [rn, sub]
	elif landmarks.in_mountains(p):
		sub = "Südberge (Bären!)"
	var to_border := world.border_distance(p)
	if to_border < 60.0:
		sub = "Achtung: Grenze der Spielwelt"
	hud.set_place(title, sub, to_border < 60.0)


# ------------------------------------------------------------------ Mehrspieler

func send_net_state() -> void:
	if not started or not player:
		return
	var flags := 0
	if seat != "":
		flags |= 1
	if player.crouched:
		flags |= 2
	if player.hand.aiming:
		flags |= 4
	if player.passed_out > 0.0:
		flags |= 8
	var owner_id := 0
	if seat_truck == car and seat != "":
		owner_id = Net.my_id()
	else:
		for id in remote_trucks:
			if remote_trucks[id] == seat_truck:
				owner_id = id
	var pos: Vector3 = seat_truck.global_transform * Truck.SEATS.get(seat, Vector3.ZERO) if seat != "" else player.global_position
	Net.pstate.rpc(pos, rig.yaw if rig.first_person else atan2(player.facing.x, player.facing.z), rig.pitch, flags, owner_id, seat)
	var cargo := []
	for n in car.cargo:
		cargo.append(n.species if n is Carcass else str(n.get_meta("kind", "crate")))
	var look := {paint = GameState.truck.paint, up = GameState.truck.upgrades.keys(), lights = car.lights_on, cargo = cargo}
	if trailer:
		var tcargo := []
		for n in trailer.cargo:
			tcargo.append(n.species if n is Carcass else str(n.get_meta("kind", "crate")))
		look.trailer = [trailer.global_transform, tcargo, trailer.strapped]
	Net.vstate.rpc(car.global_transform, car.linear_velocity, look)


## Eigene Polizeiautos an die anderen (sie sehen Streifen und Verfolgungen)
func send_police_state() -> void:
	if not police:
		return
	var cars := []
	for c in police.patrols:
		if is_instance_valid(c) and cars.size() < 4:
			cars.append([c.global_transform, c.siren_on])
	if police.checkpoint_car and is_instance_valid(police.checkpoint_car):
		cars.append([police.checkpoint_car.global_transform, police.checkpoint_car.siren_on])
	Net.police_state(cars)


## Polizeiautos eines anderen Spielers anzeigen
func on_remote_police(id: int, cars: Array) -> void:
	var list: Array = remote_police.get(id, [])
	while list.size() < cars.size():
		var c := PoliceCar.new()
		c.world = world
		c.puppet = true
		c.mode = PoliceCar.Mode.PARKED
		add_child(c)
		c.remove_from_group("police")
		list.append(c)
	while list.size() > cars.size():
		list.pop_back().queue_free()
	for i in cars.size():
		var c: PoliceCar = list[i]
		var xf: Transform3D = cars[i][0]
		c.puppet_to(xf)
		c.set_siren(bool(cars[i][1]))
	remote_police[id] = list


## Schuss, Hupe, Explosion, Rülpser eines anderen Spielers
func on_fx(kind: String, pos: Vector3) -> void:
	net_stats[kind] = net_stats.get(kind, 0) + 1
	if not started:
		return
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	match kind:
		"shot":
			Sfx.play_3d(n, Sfx.gunshot(), 4.0, randf_range(0.95, 1.05))
			Animal.notify_gunshot(get_tree(), pos, pos, 100.0, 100.0, null)
			var flash := OmniLight3D.new()
			flash.light_color = Color(1.0, 0.8, 0.4)
			flash.omni_range = 6.0
			flash.light_energy = 4.0
			n.add_child(flash)
			create_tween().tween_property(flash, "light_energy", 0.0, 0.1)
		"horn":
			Sfx.play_3d(n, Sfx.horn(), 2.0)
		"burp":
			Sfx.play_3d(n, Sfx.burp(), 2.0)
		"boom":
			Sfx.play_3d(n, Sfx.explosion(), 10.0)
			var light := OmniLight3D.new()
			light.light_color = Color(1, 0.6, 0.2)
			light.omni_range = 30.0
			light.light_energy = 8.0
			n.add_child(light)
			create_tween().tween_property(light, "light_energy", 0.0, 1.5)
			if player.global_position.distance_to(pos) < 8.0:
				GameState.damage(30.0)
				player.knockdown(2.0, "BUMM!")
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


## Mitspieler hat sich umgezogen
func on_peer_outfit(id: int) -> void:
	if remote_players.has(id):
		(remote_players[id] as RemotePlayer).set_outfit(Net.peers[id].outfit)


func on_remote_player(id: int, pos: Vector3, yaw: float, pitch: float, flags: int, owner_id: int, s: String) -> void:
	if not remote_players.has(id):
		var info: Dictionary = Net.peers.get(id, {name = "Spieler %d" % id, outfit = {}})
		var rp := RemotePlayer.new()
		add_child(rp)
		rp.setup(id, info.name, info.outfit)
		rp.global_position = pos
		remote_players[id] = rp
		Animal.threats.append(rp)
		spawner.players.append(rp)
	var r: RemotePlayer = remote_players[id]
	r.apply_state(pos, yaw, pitch, flags, owner_id, s)
	# Sitzplätze im eigenen Pickup belegen
	if car:
		for k in car.occupants.keys():
			if car.occupants[k] == r.player_name:
				car.occupants.erase(k)
		if owner_id == Net.my_id() and not s.is_empty():
			car.occupants[s] = r.player_name


func on_remote_truck(id: int, xf: Transform3D, vel: Vector3, look: Dictionary) -> void:
	if not remote_trucks.has(id):
		var t := Truck.new()
		t.world = world
		t.owner_name = Net.peers.get(id, {name = "?"}).name
		t.puppet = true
		t.add_to_group("vehicle")
		add_child(t)
		remote_trucks[id] = t
		t.set_meta("look", "")
	var tr: Truck = remote_trucks[id]
	tr.puppet_to(xf)
	tr.set_meta("vel", vel)
	var key := str(look)
	if tr.get_meta("look", "") != key:
		tr.set_meta("look", key)
		# fremden Pickup nach dessen Umbauten aussehen lassen (kurz eigene Werte tauschen)
		var mine: Dictionary = GameState.truck.duplicate(true)
		GameState.truck.paint = look.get("paint", 0)
		GameState.truck.upgrades = {}
		for u in look.get("up", []):
			GameState.truck.upgrades[u] = true
		tr.rebuild()
		GameState.truck = mine
	tr.set_lights(look.get("lights", false))
	_remote_trailer(id, look.get("trailer", []))
	var cargo_key := str(look.get("cargo", []))
	if tr.get_meta("cargo", "") != cargo_key:
		tr.set_meta("cargo", cargo_key)
		tr.show_remote_cargo(look.get("cargo", []))


## Anhänger eines anderen Spielers anzeigen
func _remote_trailer(id: int, info: Array) -> void:
	if info.is_empty():
		if remote_trailers.has(id):
			remote_trailers[id].queue_free()
			remote_trailers.erase(id)
		return
	if not remote_trailers.has(id):
		var t := Trailer.new()
		t.puppet = true
		t.world = world
		add_child(t)
		remote_trailers[id] = t
	var tr: Trailer = remote_trailers[id]
	tr.puppet_to(info[0])
	if tr.get_meta("cargo", "") != str(info[1]):
		tr.set_meta("cargo", str(info[1]))
		tr.show_remote_cargo(info[1])
	if tr.strapped != bool(info[2]):
		tr.set_strapped(bool(info[2]))


func _on_player_left(id: int) -> void:
	if remote_trailers.has(id):
		remote_trailers[id].queue_free()
		remote_trailers.erase(id)
	if remote_players.has(id):
		Animal.threats.erase(remote_players[id])
		spawner.players.erase(remote_players[id])
		remote_players[id].queue_free()
		remote_players.erase(id)
	if remote_police.has(id):
		for c in remote_police[id]:
			c.queue_free()
		remote_police.erase(id)
	if remote_trucks.has(id):
		if seat_truck == remote_trucks[id]:
			exit_vehicle()
		remote_trucks[id].queue_free()
		remote_trucks.erase(id)


func on_animal_states(data: PackedFloat32Array) -> void:
	for k in range(0, data.size(), 6):
		var a = spawner.animals.get(int(data[k]))
		if is_instance_valid(a) and a.remote:
			var target := Vector3(data[k + 1], data[k + 2], data[k + 3])
			a.global_position = a.global_position.lerp(target, 0.5) if a.global_position.distance_to(target) < 8.0 else target
			a.rotation.y = data[k + 4]
			a.velocity = Vector3(0, 0, data[k + 5])


func on_remote_animal_died(id: int, dir: Vector3) -> void:
	var a = spawner.animals.get(id)
	if is_instance_valid(a) and a.remote:
		spawner.animals.erase(id)
		a.die(dir if dir != Vector3.ZERO else Vector3.FORWARD)


func on_carcass_gone(id: int) -> void:
	for c in get_tree().get_nodes_in_group("carcass"):
		if c is Carcass and c.net_id == id:
			c.sold = true
			c.remove_from_group("carcass")
			if player and player.carrying == c:
				player.carrying = null
			if not c.get_parent() is Truck:
				c.queue_free()


func _exit_tree() -> void:
	Animal.threats.clear()


func on_voice(id: int, samples: PackedFloat32Array, radio: bool) -> void:
	net_stats["voice"] = net_stats.get("voice", 0) + 1
	if not remote_players.has(id):
		return
	var rp: RemotePlayer = remote_players[id]
	var muffled := (rp.flags & 1) != 0 and seat_truck == null or (seat != "" and (rp.flags & 1) == 0)
	rp.push_voice(samples, radio, muffled)
