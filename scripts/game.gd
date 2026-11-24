class_name Game
extends Node3D
## Hauptszene: setzt Spielfigur, Auto, Kamera und GUI zusammen und regelt Ein-/Aussteigen.

const SPAWN_POI := "Gasthaus Pirtscher"
const ENTER_DISTANCE := 3.8

@onready var world: WorldBuilder = $World

var player: Player
var car: Car
var rig: CameraRig
var hud: Hud
var driving := false
var _place_timer := 0.0


func _ready() -> void:
	Controls.setup()
	# Die Hauptszene muss Esc auch in der Pause hören, alles darunter pausiert normal
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE

	# Start vor dem Gasthaus auf der Straße, das Auto parkt ein Stück weiter
	var gasthaus := world.poi_position(SPAWN_POI)
	var road := world.nearest_road(gasthaus, ["residential", "unclassified", "tertiary", "primary", "service"])
	var side := Vector2(-road.dir.y, road.dir.x)
	if side.dot(gasthaus - road.pos) < 0:
		side = -side  # Seite zum Gasthaus

	player = Player.new()
	player.name = "Spieler"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var pp: Vector2 = road.pos + side * 1.5
	player.global_position = Vector3(pp.x, world.height_at(pp.x, pp.y) + 0.5, pp.y)
	player.reset_physics_interpolation()

	car = Car.new()
	car.name = "Auto"
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(car)
	var cp: Vector2 = road.pos + road.dir * 7.0 - side * 1.2
	place_car(Vector3(cp.x, 0, cp.y), Vector3(road.dir.x, 0, road.dir.y))

	rig = CameraRig.new()
	rig.name = "Kamera"
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)
	player.camera_rig = rig
	var look: Vector2 = (cp - pp).normalized()  # Richtung Auto schauen
	rig.yaw = atan2(-look.x, -look.y)
	rig.set_target(player, 1.6, 5.0, false)

	hud = Hud.new()
	add_child(hud)
	hud.minimap.setup(world)
	hud.big_map.setup(world, true)
	hud.resume_requested.connect(func(): set_paused(false))
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.toast("Willkommen in Riegersdorf!", 4.0)

	# Umgebungsgeräusch: Wind und Vögel
	var amb := AudioStreamPlayer.new()
	amb.stream = Sfx.ambience()
	amb.volume_db = -13.0
	amb.autoplay = true
	add_child(amb)

	if not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func place_car(pos: Vector3, forward: Vector3) -> void:
	var y := world.height_at(pos.x, pos.z) + 1.0
	car.global_transform = Transform3D(Basis.looking_at(-forward.normalized(), Vector3.UP), Vector3(pos.x, y, pos.z))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
	elif get_tree().paused:
		return
	elif event.is_action_pressed("interact"):
		if driving:
			exit_car()
		elif player.global_position.distance_to(car.global_position) < ENTER_DISTANCE:
			enter_car()
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("map"):
		hud.toggle_map()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)
	if not DebugTools.active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func enter_car() -> void:
	driving = true
	player.visible = false
	player.input_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	player.global_position = car.global_position + Vector3.DOWN * 50.0  # aus dem Weg
	car.driving = true
	Sfx.play_3d(car, Sfx.door(), -2.0)
	rig.set_target(car, 1.7, 8.5, true)
	hud.set_driving(true)


func exit_car() -> void:
	if absf(car.speed_kmh()) > 15.0:
		hud.toast("Zuerst langsamer werden!", 1.5)
		return
	driving = false
	car.driving = false
	var p := car.global_position + car.global_basis.x * 2.0  # links aussteigen
	player.global_position = Vector3(p.x, maxf(world.height_at(p.x, p.z), car.global_position.y - 0.5) + 0.3, p.z)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	Sfx.play_3d(car, Sfx.door(), -2.0, 1.1)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.collision_layer = 2
	player.input_enabled = true
	player.visible = true
	rig.set_target(player, 1.6, 5.0, false)
	hud.set_driving(false)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# Sicherheitsnetz: niemand fällt durch die Welt
	for body: Node3D in [player, car]:
		var g := world.height_at(body.global_position.x, body.global_position.z)
		if body.global_position.y < g - 4.0 and not (body == player and driving):
			if body == car:
				place_car(car.global_position, car.global_basis.z)
			else:
				body.global_position.y = g + 1.0

	var focus: Node3D = car if driving else player
	var pos2 := Vector2(focus.global_position.x, focus.global_position.z)
	var head: Vector3 = car.global_basis.z if driving else player.facing
	hud.minimap.center = pos2
	hud.minimap.player_pos = pos2
	hud.minimap.heading = Vector2(head.x, head.z)
	hud.big_map.player_pos = pos2
	hud.big_map.heading = Vector2(head.x, head.z)

	if driving:
		hud.set_speed(car.speed_kmh())
		hud.set_prompt("[F] Aussteigen")
	elif player.global_position.distance_to(car.global_position) < ENTER_DISTANCE:
		hud.set_prompt("[F] Einsteigen")
	else:
		hud.set_prompt("")

	_place_timer -= delta
	if _place_timer <= 0.0:
		_place_timer = 0.4
		_update_place(pos2)


func _update_place(p: Vector2) -> void:
	var poi := world.nearest_poi(p)
	var road := world.nearest_road(p, [], 30.0)
	var place := world.nearest_place(p)
	var title: String = place.name
	var sub := ""
	if poi.dist < 45.0:
		title = poi.name
		sub = place.name
	if road.dist < 15.0 and not road.name.is_empty() and road.name != title:
		sub = road.name if sub.is_empty() else "%s, %s" % [road.name, sub]
	var to_border := world.border_distance(p)
	if to_border < 60.0:
		sub = "Achtung: Grenze der Spielwelt"
	hud.set_place(title, sub, to_border < 60.0)