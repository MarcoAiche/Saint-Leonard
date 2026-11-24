extends Node
## Entwickler-Helfer (Autoload). Nur aktiv mit Startparametern nach "--":
##   --player=x,z           Spielfigur dorthin setzen
##   --drive                ins Auto einsteigen
##   --hold=aktion:sek,...  Tasten (Input-Aktionen) nacheinander gedrückt halten
##   --cam=yaw,pitch        Kamerawinkel in Grad
##   --wait=sek             vor dem Bild warten
##   --shot=pfad.png        Bild speichern und beenden

var active := false
var args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	active = not args.is_empty()


func _ready() -> void:
	if not active:
		return
	for i in 5:
		await get_tree().process_frame
	var game := get_tree().current_scene as Game
	if game == null:
		return
	await get_tree().create_timer(0.5).timeout
	if args.has("player"):
		var v := _floats(args.player)
		game.player.global_position = Vector3(v[0], game.world.height_at(v[0], v[1]) + 0.5, v[1])
		await get_tree().create_timer(0.5).timeout
	if args.has("drive"):
		game.player.global_position = game.car.global_position + game.car.global_basis.x * 2.0
		await get_tree().physics_frame
		game.enter_car()
	if args.has("cam"):
		var v := _floats(args.cam)
		game.rig.yaw = deg_to_rad(v[0])
		game.rig.pitch = deg_to_rad(v[1])
	if args.has("dist"):
		game.rig.distance = float(args.dist)
		game.rig.arm.spring_length = game.rig.distance
	if args.has("map"):
		game.hud.toggle_map()
	if args.has("hold"):
		for item in args.hold.split(","):
			var parts: PackedStringArray = item.split(":")
			Input.action_press(parts[0])
			await get_tree().create_timer(float(parts[1])).timeout
			Input.action_release(parts[0])
	if args.has("wait"):
		await get_tree().create_timer(float(args.wait)).timeout
	_report(game)
	if args.has("shot"):
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("Screenshot gespeichert: ", args.shot)
	get_tree().quit()


func _report(game: Game) -> void:
	var p := game.player.global_position
	var c := game.car.global_position
	print("Spieler %s, Boden %.2f, am Boden: %s" % [p, game.world.height_at(p.x, p.z), game.player.is_on_floor()])
	print("Auto %s, Boden %.2f, %.1f km/h, faehrt: %s, aufrecht: %.2f" % [c, game.world.height_at(c.x, c.z), game.car.speed_kmh(), game.driving, game.car.global_basis.y.y])


static func _floats(s: String) -> Array:
	return Array(s.split(",")).map(func(x): return float(x))
