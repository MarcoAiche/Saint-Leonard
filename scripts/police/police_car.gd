class_name PoliceCar
extends Vehicle
## Streifenwagen (weiß mit blauem Streifen, Blaulicht). Fährt eine Route ab, verfolgt Verdächtige
## oder steht an der Kontrolle. Die Fahrlogik ist bewusst einfach: Zielpunkt anpeilen, Tempo halten.

enum Mode { PATROL, PURSUE, PARKED, GOTO }

var mode := Mode.PATROL
var route := PackedVector2Array()
var route_i := 0
var cruise_kmh := 55.0
var target: Node3D = null
var goto_pos := Vector3.ZERO
var siren_on := false
var stuck_t := 0.0

var _siren: AudioStreamPlayer3D
var _lights: Array[OmniLight3D] = []
var _blink := 0.0
var _officer: CharacterModel


func _ready() -> void:
	super._ready()
	mass = 1500.0
	center_of_mass = Vector3(0, -0.35, 0.1)
	max_engine_force = 7000.0
	top_speed_kmh = 150.0
	_build()
	driving = true
	player_input = false
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = Sfx.siren()
	_siren.unit_size = 25.0
	_siren.max_distance = 600.0
	_siren.volume_db = -2.0
	add_child(_siren)
	add_to_group("police")
	add_to_group("vehicle")


func _build() -> void:
	var white := Color(0.95, 0.95, 0.95)
	var blue := Color(0.15, 0.30, 0.65)
	var glass := Color(0.4, 0.55, 0.65)
	_shape(Vector3(1.8, 0.7, 4.4), Vector3(0, 0.1, 0))
	_shape(Vector3(1.6, 0.6, 2.2), Vector3(0, 0.75, -0.2))
	_box(self, Vector3(1.8, 0.62, 4.4), Vector3(0, 0.1, 0), white)
	_box(self, Vector3(1.82, 0.16, 4.42), Vector3(0, 0.12, 0), blue, false)  # Streifen
	_box(self, Vector3(1.6, 0.6, 2.2), Vector3(0, 0.72, -0.2), white)
	_box(self, Vector3(1.62, 0.4, 1.5), Vector3(0, 0.74, -0.2), glass, false)
	_box(self, Vector3(1.4, 0.4, 2.22), Vector3(0, 0.74, -0.2), glass, false)
	_box(self, Vector3(1.84, 0.14, 4.46), Vector3(0, -0.2, 0), Color(0.2, 0.2, 0.22))
	_box(self, Vector3(1.0, 0.12, 0.35), Vector3(0, 1.08, -0.1), Color(0.1, 0.1, 0.12))
	for x in [-0.32, 0.32]:
		_box(self, Vector3(0.3, 0.12, 0.3), Vector3(x, 1.16, -0.1), Color(0.2, 0.4, 1.0), false)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 1.3, -0.1)
		l.light_color = Color(0.2, 0.4, 1.0)
		l.omni_range = 14.0
		l.light_energy = 0.0
		add_child(l)
		_lights.append(l)
	var lbl := Label3D.new()
	lbl.text = "POLIZEI"
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.modulate = blue
	lbl.outline_size = 0
	for side in [-1, 1]:
		var l2 := lbl.duplicate() as Label3D
		l2.position = Vector3(0.92 * side, 0.3, 0.3)
		l2.rotation.y = PI / 2 * side
		add_child(l2)
	lbl.free()
	for p in [Vector3(0.82, -0.05, 1.35), Vector3(-0.82, -0.05, 1.35), Vector3(0.82, -0.05, -1.35), Vector3(-0.82, -0.05, -1.35)]:
		_add_wheel(p, 0.38, p.z > 0, Color(0.13, 0.13, 0.15), Color(0.8, 0.8, 0.82))
	_add_headlights(2.22, 0.18, 0.62)
	_officer = CharacterModel.new({uniform = true, hat = "police"})
	_officer.position = Vector3(0.42, 0.1, 0.0)
	_officer.scale = Vector3.ONE * 0.8
	add_child(_officer)
	_officer.animate(0.1, 0.0, true, false, true)


func set_siren(on: bool) -> void:
	if on == siren_on:
		return
	siren_on = on
	if on:
		_siren.play()
	else:
		_siren.stop()


func _process(delta: float) -> void:
	_blink += delta
	for i in _lights.size():
		_lights[i].light_energy = (3.0 if fmod(_blink * 3.0 + i * 0.5, 1.0) < 0.5 else 0.0) if siren_on else 0.0
	set_lights(GameState.is_night() or GameState.weather == "fog")
	if _officer:
		_officer.animate(delta, 0.0, true, false, true)


func _physics_process(delta: float) -> void:
	_drive_ai(delta)
	super._physics_process(delta)


func _drive_ai(delta: float) -> void:
	var p := Vector2(global_position.x, global_position.z)
	var aim := p
	var want_kmh := 0.0
	match mode:
		Mode.PARKED:
			ai_throttle = 0.0
			ai_steer = 0.0
			ai_handbrake = true
			return
		Mode.PATROL:
			if route.size() < 2:
				ai_throttle = 0.0
				ai_handbrake = true
				return
			while route_i < route.size() - 1 and route[route_i].distance_to(p) < 9.0:
				route_i += 1
			# etwas vorausschauen
			var look := route_i
			var acc := 0.0
			while look < route.size() - 1 and acc < 10.0:
				acc += route[look].distance_to(route[look + 1])
				look += 1
			aim = route[look]
			want_kmh = cruise_kmh
			if route_i >= route.size() - 1 and route[-1].distance_to(p) < 10.0:
				route = route.slice(0, 0)  # neue Route anfordern
		Mode.PURSUE:
			if not is_instance_valid(target):
				mode = Mode.PATROL
				return
			var tv: Vector3 = target.linear_velocity if target is RigidBody3D else Vector3.ZERO
			var tp := target.global_position + tv * 0.6
			aim = Vector2(tp.x, tp.z)
			var d := aim.distance_to(p)
			want_kmh = clampf(d * 2.5, 20.0, 145.0)
			if d < 9.0:
				want_kmh = minf(want_kmh, absf(target.linear_velocity.length() * 3.6) + 5.0) if target is RigidBody3D else 10.0
		Mode.GOTO:
			aim = Vector2(goto_pos.x, goto_pos.z)
			want_kmh = 80.0
			if aim.distance_to(p) < 12.0:
				want_kmh = 0.0
	ai_handbrake = false
	var local := global_transform.affine_inverse() * Vector3(aim.x, global_position.y, aim.y)
	var ang := atan2(local.x, local.z)
	ai_steer = clampf(ang * 1.8, -1.0, 1.0)
	var v := speed_kmh()
	if absf(ang) > 1.2 and v > 25.0:
		want_kmh = minf(want_kmh, 25.0)
	if want_kmh <= 0.1:
		ai_throttle = -1.0 if v > 2.0 else 0.0
		ai_handbrake = v < 2.0
	else:
		ai_throttle = clampf((want_kmh - v) / 15.0, -1.0, 1.0)
	# Festgefahren: zurücksetzen
	if absf(v) < 2.0 and want_kmh > 5.0:
		stuck_t += delta
		if stuck_t > 4.0:
			ai_throttle = -1.0
			ai_steer = -ai_steer
			if stuck_t > 6.5:
				stuck_t = 0.0
				if global_basis.y.y < 0.6:
					flip_upright()
	else:
		stuck_t = 0.0
