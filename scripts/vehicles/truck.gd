class_name Truck
extends Vehicle
## 4x4-Pickup der Spieler. Umbauten aus der Werkstatt (GameState.truck.upgrades) ändern Aussehen
## und Fahrverhalten: Geländereifen (Matsch), Höherlegung, Rammschutz, Dachscheinwerfer, Dachträger,
## Sportauspuff, Seilwinde, Unterfahrschutz, Lackierung.
## Ladefläche: bis zu 4 Dinge (Wild, Kisten, Schnapsflaschen). Ohne Spanngurte fällt bei Holperfahrt etwas herunter.
## Sprit und Schaden; L Licht, K Radio, T Seilwinde, H Hupe, R aufstellen.

signal cargo_lost(node: Node3D)

const TANK := 70.0
const HITCH := Vector3(0, 0.1, -2.95)  # Anhängerkupplung (lokal, hinten)
const BED_SLOTS := [Vector3(-0.45, 0.55, -1.25), Vector3(0.45, 0.55, -1.25), Vector3(-0.45, 0.55, -2.0), Vector3(0.45, 0.55, -2.0)]
const SEATS := {driver = Vector3(0.42, 0.75, 0.25), passenger = Vector3(-0.42, 0.75, 0.25), bed_l = Vector3(-0.5, 0.9, -1.6), bed_r = Vector3(0.5, 0.9, -1.6)}

var owner_name := ""
var cargo: Array[Node3D] = []
var occupants := {}  # Sitz -> Spielername (Mehrspieler)
var winching := false
var winch_anchor := Vector3.INF

var _body: Node3D
var _horn: AudioStreamPlayer3D
var _radio: Radio
var _spots: Array[SpotLight3D] = []
var _cable: MeshInstance3D
var _dist_acc := 0.0
var _last_pos := Vector3.ZERO
var _smoke: GPUParticles3D


func _ready() -> void:
	super._ready()
	mass = 1900.0
	center_of_mass = Vector3(0, -0.35, 0.2)
	max_engine_force = 7500.0
	top_speed_kmh = 135.0
	_body = Node3D.new()
	_body.name = "Karosserie"
	add_child(_body)
	_shape(Vector3(1.9, 0.7, 5.0), Vector3(0, 0.15, -0.3))
	_shape(Vector3(1.75, 0.75, 1.9), Vector3(0, 0.85, 0.35))
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = Sfx.horn()
	_horn.unit_size = 14.0
	add_child(_horn)
	_radio = Radio.new()
	_radio.position = Vector3(0, 1.0, 0.4)
	add_child(_radio)
	_cable = MeshInstance3D.new()
	_cable.mesh = ImmediateMesh.new()
	_cable.material_override = Toon.solid(Color(0.1, 0.1, 0.1), false)
	_cable.top_level = true
	add_child(_cable)
	_smoke = _make_smoke()
	add_child(_smoke)
	rebuild()
	_last_pos = global_position


## Aussehen und Fahrwerk nach den aktuellen Umbauten neu aufbauen
func rebuild() -> void:
	var up: Dictionary = GameState.truck.upgrades
	for c in _body.get_children():
		c.queue_free()
	for w in wheels:
		w.queue_free()
	wheels.clear()
	for s in _spots:
		s.queue_free()
	_spots.clear()
	for l in _headlights:
		l.queue_free()
	_headlights.clear()

	var paint: Color = Items.PAINTS[int(GameState.truck.paint) % Items.PAINTS.size()][1]
	var lift := 0.22 if up.has("lift") else 0.0
	var mud := up.has("mud_tires")
	_body.position.y = lift
	var dark := Color(0.14, 0.14, 0.15)
	var glass := Color(0.45, 0.6, 0.7)
	if ResourceLoader.exists("res://assets/models/vehicles/pickup_4x4.glb"):
		var glb_truck := AssetLoader.load_model("res://assets/models/vehicles/pickup_4x4.glb", 2.1, func() -> Node3D: return Node3D.new())
		glb_truck.position.y = -0.35
		_body.add_child(glb_truck)
	else:
		# Unterbau und Motorhaube
		_box(_body, Vector3(1.9, 0.55, 5.0), Vector3(0, 0.12, -0.3), paint)
		_box(_body, Vector3(1.86, 0.25, 1.5), Vector3(0, 0.5, 1.45), paint.lightened(0.04))  # Haube
		_box(_body, Vector3(1.94, 0.16, 5.08), Vector3(0, -0.18, -0.3), dark)  # Schweller
		# Kabine (Ebene 3: in der Ego-Ansicht im Auto ausgeblendet, damit man hinaussieht)
		for cab in [_box(_body, Vector3(1.8, 0.8, 1.9), Vector3(0, 0.88, 0.35), paint),
				_box(_body, Vector3(1.82, 0.5, 1.4), Vector3(0, 0.98, 0.35), glass, false),
				_box(_body, Vector3(1.6, 0.5, 1.92), Vector3(0, 0.98, 0.35), glass, false),
				_box(_body, Vector3(1.84, 0.08, 1.96), Vector3(0, 1.3, 0.35), paint.darkened(0.1))]:
			cab.layers = 4
		# Armaturenbrett und Lenkrad (nur innen zu sehen)
		_box(_body, Vector3(1.6, 0.25, 0.3), Vector3(0, 0.62, 1.1), dark)
		var wheel_ring := _box(_body, Vector3(0.38, 0.38, 0.04), Vector3(0.42, 0.82, 0.85), dark)
		wheel_ring.rotation.x = -0.5
		# Ladefläche mit Bordwänden
		_box(_body, Vector3(1.8, 0.1, 2.2), Vector3(0, 0.45, -1.65), dark)
		for sx in [-0.88, 0.88]:
			_box(_body, Vector3(0.08, 0.45, 2.2), Vector3(sx, 0.68, -1.65), paint)
		_box(_body, Vector3(1.8, 0.45, 0.08), Vector3(0, 0.68, -2.75), paint)  # Heckklappe
		_box(_body, Vector3(1.8, 0.45, 0.08), Vector3(0, 0.68, -0.55), paint)
		# Kühlergrill, Lichter, Nummer
		_box(_body, Vector3(1.4, 0.32, 0.06), Vector3(0, 0.38, 2.22), dark)
		for x in [-0.68, 0.68]:
			_box(_body, Vector3(0.32, 0.18, 0.06), Vector3(x, 0.45, 2.22), Color(1.0, 0.95, 0.7), false)
			_box(_body, Vector3(0.2, 0.25, 0.06), Vector3(x, 0.5, -2.8), Color(0.9, 0.12, 0.1), false)
		_box(_body, Vector3(0.5, 0.14, 0.04), Vector3(0, 0.05, 2.24), Color(0.95, 0.95, 0.9), false)
		_box(_body, Vector3(0.5, 0.14, 0.04), Vector3(0, 0.2, -2.82), Color(0.95, 0.95, 0.9), false)
	if up.has("bullbar"):
		for x in [-0.6, 0.6]:
			_box(_body, Vector3(0.08, 0.7, 0.08), Vector3(x, 0.3, 2.45), dark)
		_box(_body, Vector3(1.5, 0.08, 0.08), Vector3(0, 0.62, 2.45), dark)
		_box(_body, Vector3(1.5, 0.08, 0.08), Vector3(0, 0.1, 2.48), dark)
	if up.has("winch"):
		_box(_body, Vector3(0.6, 0.25, 0.25), Vector3(0, 0.0, 2.35), Color(0.2, 0.2, 0.2))
		_box(_body, Vector3(0.1, 0.1, 0.12), Vector3(0, 0.0, 2.52), Color(0.85, 0.7, 0.1), false)
	if up.has("roof_rack"):
		_box(_body, Vector3(1.6, 0.06, 1.6), Vector3(0, 1.45, 0.3), dark)
		for x in [-0.78, 0.78]:
			_box(_body, Vector3(0.05, 0.15, 1.6), Vector3(x, 1.4, 0.3), dark)
		_box(_body, Vector3(0.8, 0.3, 0.6), Vector3(0.3, 1.63, 0.1), Color(0.3, 0.4, 0.25))  # Kiste
	if up.has("spotlights"):
		_box(_body, Vector3(1.5, 0.12, 0.12), Vector3(0, 1.42, 1.15), dark)
		for x in [-0.6, -0.2, 0.2, 0.6]:
			_box(_body, Vector3(0.24, 0.2, 0.1), Vector3(x, 1.52, 1.18), Color(1, 1, 0.85), false)
			var s := SpotLight3D.new()
			s.position = Vector3(x, 1.52 + lift, 1.25)
			s.rotation.y = PI
			s.rotation.x = -0.12
			s.spot_range = 110.0
			s.spot_angle = 22.0
			s.light_energy = 6.0
			s.visible = false
			add_child(s)
			_spots.append(s)
	if up.has("exhaust"):
		for x in [-0.5, 0.5]:
			var pipe := _box(_body, Vector3(0.12, 0.12, 0.3), Vector3(x, -0.12, -2.9), Color(0.7, 0.7, 0.72))
			pipe.rotation.x = 0.1
	if up.has("armor"):
		_box(_body, Vector3(1.6, 0.06, 3.2), Vector3(0, -0.26, 0.2), Color(0.5, 0.5, 0.52))

	# Räder (Geländereifen sind größer und grobstollig)
	var r := 0.48 if mud else 0.42
	var tire_c := Color(0.1, 0.1, 0.11) if mud else Color(0.14, 0.14, 0.16)
	for p in [Vector3(0.9, -0.05, 1.55), Vector3(-0.9, -0.05, 1.55), Vector3(0.9, -0.05, -1.75), Vector3(-0.9, -0.05, -1.75)]:
		var w := _add_wheel(p + Vector3(0, lift * 0.3, 0), r, p.z > 0, tire_c, Color(0.75, 0.75, 0.78), 0.36 if mud else 0.28)
		w.wheel_rest_length = 0.3 + lift * 0.6
		w.suspension_travel = 0.28 + lift * 0.6
		w.suspension_stiffness = 36.0 if up.has("lift") else 42.0
		if mud:
			# Stollen andeuten
			for k in 8:
				var a := TAU * k / 8.0
				var lug := _box(w, Vector3(0.38, 0.06, 0.1), Vector3(0, cos(a) * r, sin(a) * r), Color(0.08, 0.08, 0.08), false)
				lug.rotation.x = -a
	_add_headlights(2.3, 0.45 + lift, 0.68)
	# Anhängerkupplung
	_box(_body, Vector3(0.12, 0.12, 0.35), Vector3(0, -0.05, -2.95), Color(0.15, 0.15, 0.16))
	var ball := _box(_body, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.08, -3.05), Color(0.6, 0.6, 0.62))
	ball.name = "Kupplungskugel"
	set_lights(lights_on)
	grip_mult = 1.0
	offroad_mult = 1.45 if mud else 1.0
	if up.has("lift"):
		offroad_mult *= 1.12
	_engine.volume_db = 4.0 if up.has("exhaust") else 0.0


func set_lights(on: bool) -> void:
	super.set_lights(on)
	for s in _spots:
		s.visible = on


func _power_factor() -> float:
	var dmg: float = GameState.truck.damage if is_mine() else 0.0
	if is_mine() and GameState.truck.fuel <= 0.0:
		return 0.0
	return clampf(1.0 - maxf(dmg - 50.0, 0.0) / 60.0, 0.15, 1.0)


func is_mine() -> bool:
	return owner_name.is_empty() or owner_name == GameState.player_name


func _on_drive(delta: float, throttle: float, _v: float) -> void:
	if not is_mine():
		return
	# Sprit: ca. 2,5 l pro km plus Leerlauf (verkürzt, damit Tanken eine Rolle spielt)
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if driving and moved < 5.0:
		GameState.truck.fuel = maxf(0.0, GameState.truck.fuel - moved * 0.0025 - delta * 0.004 * absf(throttle))
	broken = GameState.truck.damage >= 100.0
	_smoke.emitting = GameState.truck.damage > 60.0
	_process_winch(delta)
	_check_cargo()


func _on_bump(speed: float) -> void:
	if not is_mine():
		return
	var up: Dictionary = GameState.truck.upgrades
	var protect := 0.35 if up.has("armor") else 1.0
	if up.has("lift"):
		protect *= 0.7
	# nur wer im Gelände richtig rast, ruiniert das Auto (ca. 1 % pro 10 s bei 80 km/h)
	if speed > 60.0:
		GameState.truck.damage = minf(100.0, GameState.truck.damage + (speed - 60.0) * 0.0015 * protect)
	# Ladung kann herunterfallen
	if speed > 35.0 and not strapped and not cargo.is_empty() and randf() < (speed - 35.0) * 0.006:
		_drop_cargo(cargo.back(), true)


func _on_crash(dv: float) -> void:
	if not is_mine():
		return
	var protect := 0.5 if GameState.truck.upgrades.has("bullbar") else 1.0
	GameState.truck.damage = minf(100.0, GameState.truck.damage + (dv - 8.0) * 1.5 * protect)


func honk() -> void:
	_horn.play()
	GameState.make_noise(global_position, 250.0, "horn")


func next_station() -> String:
	return _radio.next_station()


# ------------------------------------------------------------------ Ladefläche

func has_space() -> bool:
	return cargo.size() < BED_SLOTS.size()


## Ladung mit Spanngurten sichern (gelbe Gurte über der Ladefläche)
var strapped := false
var _strap_node: Node3D


func set_strapped(on: bool) -> void:
	strapped = on
	if _strap_node == null:
		_strap_node = Node3D.new()
		add_child(_strap_node)
		for z in [-1.25, -2.0]:
			_box(_strap_node, Vector3(1.84, 0.03, 0.08), Vector3(0, 1.05, z), Color(0.98, 0.78, 0.1), false)
	_strap_node.position.y = _body.position.y
	_strap_node.visible = on


func load_cargo(n: Node3D) -> bool:
	if not has_space():
		return false
	if n is Carcass:
		(n as Carcass).set_carried(true)
	if n.get_parent():
		n.get_parent().remove_child(n)
	add_child(n)
	n.position = BED_SLOTS[cargo.size()] + Vector3(0, _body.position.y, 0)
	n.rotation = Vector3(0, PI / 2, 0)
	if n is Carcass:
		n.scale = Vector3.ONE * clampf(1.0 / Animal.SPECIES[n.species].size, 0.5, 1.0)
	cargo.append(n)
	return true


func unload_last() -> Node3D:
	if cargo.is_empty():
		return null
	var n: Node3D = cargo.pop_back()
	return n


func _drop_cargo(n: Node3D, thrown: bool) -> void:
	cargo.erase(n)
	var xf := n.global_transform
	var root := get_parent()
	remove_child(n)
	root.add_child(n)
	n.global_transform = xf
	n.scale = Vector3.ONE
	if n is Carcass:
		(n as Carcass).set_carried(false)
		if thrown:
			(n as RigidBody3D).linear_velocity = linear_velocity * 0.7 + Vector3.UP * 3.0
	cargo_lost.emit(n)


func _check_cargo() -> void:
	# Ladung ohne Gurte rutscht bei starkem Kippen herunter
	if not cargo.is_empty() and global_basis.y.y < 0.5 and not strapped:
		_drop_cargo(cargo.back(), true)


func cargo_has(kind: String) -> bool:
	for n in cargo:
		if n.get_meta("kind", "") == kind:
			return true
	return false


# ------------------------------------------------------------------ Seilwinde

func toggle_winch() -> String:
	if not GameState.truck.upgrades.has("winch"):
		return "Keine Seilwinde eingebaut (Werkstatt)"
	if winching:
		winching = false
		(_cable.mesh as ImmediateMesh).clear_surfaces()
		return "Seilwinde gelöst"
	var front := global_transform * Vector3(0, 0, 2.5)
	var best := Vector3.INF
	var bd := 35.0
	for t in world.trees_near(Vector2(front.x, front.z), 35.0):
		var p := Vector3(t.x, world.height_at(t.x, t.y) + 1.0, t.y)
		var d := p.distance_to(front)
		# bevorzugt Bäume vor dem Auto
		var ahead := (p - global_position).normalized().dot(global_basis.z)
		d -= ahead * 8.0
		if d < bd:
			bd = d
			best = p
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v != self and v.global_position.distance_to(front) < 30.0:
			best = v.global_position + Vector3.UP * 0.5
	if best == Vector3.INF:
		return "Kein Baum oder Fahrzeug in Reichweite (35 m)"
	winch_anchor = best
	winching = true
	return "Seilwinde eingehakt: W gedrückt halten zum Ziehen"


func _process_winch(_delta: float) -> void:
	var im := _cable.mesh as ImmediateMesh
	if not winching:
		return
	var hook := global_transform * Vector3(0, 0.1 + _body.position.y, 2.5)
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(hook)
	im.surface_add_vertex(winch_anchor)
	im.surface_end()
	var to := winch_anchor - hook
	if to.length() < 4.0:
		winching = false
		im.clear_surfaces()
		return
	if driving and player_input and Input.is_action_pressed("move_forward"):
		apply_force(to.normalized() * 26000.0, hook - global_position)


func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.5
	p.position = Vector3(0, 0.8, 1.6)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color = Color(0.3, 0.3, 0.32, 0.6)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	return p


## Ladung eines fremden Pickups andeuten (Mehrspieler): Wild, Kisten, Flaschen
func show_remote_cargo(list: Array) -> void:
	for c in get_children():
		if c.has_meta("remote_cargo"):
			c.queue_free()
	for i in mini(list.size(), BED_SLOTS.size()):
		var kind: String = str(list[i])
		var n: Node3D
		if Animal.SPECIES.has(kind):
			n = Node3D.new()
			var sz: float = Animal.SPECIES[kind].size
			_box(n, Vector3(0.5, 0.45, 1.1) * clampf(sz, 0.4, 1.0), Vector3(0, 0.25, 0), Animal.SPECIES[kind].body)
		else:
			n = Placeables.model("moonshine" if kind == "moonshine" else "crate")
		n.set_meta("remote_cargo", true)
		n.position = BED_SLOTS[i] + Vector3(0, _body.position.y - 0.1, 0)
		n.rotation.y = PI / 2
		add_child(n)
