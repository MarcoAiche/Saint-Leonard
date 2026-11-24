class_name Vehicle
extends VehicleBody3D
## Gemeinsame Fahrphysik für Pickup und Polizeiauto. Vorne ist +Z.
## Untergrund (Straßenklasse, Nässe) bestimmt die Haftung; Schotter und Gelände sind holprig.
## Eingaben kommen vom Spieler (player_input) oder von der KI (ai_throttle, ai_steer ...).

@export var max_engine_force := 6500.0
@export var max_brake := 50.0
@export var max_steer := 0.55
@export var top_speed_kmh := 140.0
@export var reverse_speed_kmh := 25.0

var world: WorldBuilder
var driving := false  # sitzt jemand am Steuer (Spieler oder KI)
var player_input := false
var ai_throttle := 0.0
var ai_steer := 0.0
var ai_handbrake := false
var wheels: Array[VehicleWheel3D] = []
var surface := {tier = 0, kind = ""}
var broken := false
var lights_on := false
var last_crash_t := 999.0

var _steer := 0.0
var _steer_buffer: Array = []  # verzögerte Lenkung bei Alkohol
var _surface_t := 0.0
var _bump_t := 0.0
var _last_vel := Vector3.ZERO
var _engine: EngineSound
var _headlights: Array[SpotLight3D] = []
var _base_friction := 2.8
var grip_mult := 1.0  # Umbauten (Geländereifen)
## Fahrzeug eines anderen Spielers: Lage kommt übers Netz, keine eigene Physik
var puppet := false
var offroad_mult := 1.0


func _ready() -> void:
	if puppet:
		custom_integrator = true  # Godot bewegt es nicht selbst
		gravity_scale = 0.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	angular_damp = 0.8
	contact_monitor = true
	max_contacts_reported = 4
	_engine = EngineSound.new()
	add_child(_engine)


func speed_kmh() -> float:
	return linear_velocity.dot(global_basis.z) * 3.6


func _add_wheel(pos: Vector3, radius: float, steer: bool, tire_c: Color, rim_c: Color, width := 0.28) -> VehicleWheel3D:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = steer
	w.use_as_traction = true
	w.wheel_radius = radius
	w.wheel_rest_length = 0.28
	w.suspension_travel = 0.25
	w.suspension_stiffness = 40.0
	w.suspension_max_force = 18000.0
	w.damping_compression = 2.0
	w.damping_relaxation = 2.5
	w.wheel_friction_slip = _base_friction
	w.wheel_roll_influence = 0.1
	add_child(w)
	var tire := CylinderMesh.new()
	tire.top_radius = radius
	tire.bottom_radius = radius
	tire.height = width
	tire.radial_segments = 16
	var hub := CylinderMesh.new()
	hub.top_radius = radius * 0.5
	hub.bottom_radius = radius * 0.5
	hub.height = width + 0.02
	hub.radial_segments = 10
	for part in [[tire, tire_c], [hub, rim_c]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.rotation.z = PI / 2
		mi.material_override = Toon.solid(part[1], part[0] == tire, 0.015)
		w.add_child(mi)
	wheels.append(w)
	return w


func _add_headlights(z: float, y: float, x: float) -> void:
	for sx in [-x, x]:
		var l := SpotLight3D.new()
		l.position = Vector3(sx, y, z)
		l.rotation.y = PI  # SpotLight leuchtet nach -Z
		l.rotation.x = -0.06
		l.spot_range = 60.0
		l.spot_angle = 32.0
		l.light_energy = 4.0
		l.light_color = Color(1.0, 0.95, 0.82)
		l.visible = false
		add_child(l)
		_headlights.append(l)


func set_lights(on: bool) -> void:
	lights_on = on
	for l in _headlights:
		l.visible = on


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if puppet:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


## Netz-Fahrzeug weich auf die gemeldete Lage ziehen
func puppet_to(xf: Transform3D) -> void:
	var cur := global_transform
	var target := cur.interpolate_with(xf, 0.5) if cur.origin.distance_to(xf.origin) < 12.0 else xf
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target)
	global_transform = target


func _physics_process(delta: float) -> void:
	if puppet:
		engine_force = 0.0
		brake = 0.0
		return
	_flip_cd = maxf(0.0, _flip_cd - delta)
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if driving and player_input:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")
		# Alkohol: Lenkung reagiert verzögert und zittert
		var drunk := GameState.drunkness()
		if drunk > 0.0:
			_steer_buffer.append(steer_in)
			var lag := int(drunk * 40.0)
			if _steer_buffer.size() > lag:
				steer_in = _steer_buffer.pop_front()
			else:
				steer_in = 0.0
			steer_in += sin(Time.get_ticks_msec() * 0.0013) * drunk * 0.25
		else:
			_steer_buffer.clear()
	elif driving:
		throttle = ai_throttle
		steer_in = ai_steer
		handbrake = ai_handbrake
	if broken:
		throttle = minf(throttle, 0.0) if speed_kmh() > 1.0 else 0.0

	var v := speed_kmh()
	var power := _power_factor()
	var force := 0.0
	var brk := 0.0
	var effective_top := minf(top_speed_kmh, _surface_cap())
	if throttle > 0.0:
		if v < -2.0:
			brk = max_brake
		else:
			force = throttle * max_engine_force * power * clampf(1.0 - v / effective_top, 0.0, 1.0)
	elif throttle < 0.0:
		if v > 2.0:
			brk = max_brake * -throttle
		else:
			force = throttle * max_engine_force * 0.6 * power * clampf(1.0 + v / reverse_speed_kmh, 0.0, 1.0)
	else:
		brk = 1.5 if driving else 14.0
	if handbrake:
		brk = max_brake * 1.5
		force = 0.0
	engine_force = force
	brake = brk
	_engine.running = driving and not broken
	_engine.throttle = throttle
	_engine.speed_kmh = v
	_on_drive(delta, throttle, v)

	var steer_limit := max_steer * lerpf(1.0, 0.3, clampf(absf(v) / 90.0, 0.0, 1.0))
	_steer = move_toward(_steer, steer_in * steer_limit, delta * 2.2)
	steering = _steer

	_surface_t -= delta
	if _surface_t <= 0.0 and world:
		_surface_t = 0.2
		_update_surface()
	# Holpern auf Schotter, Gelände und Bergpfaden
	if surface.tier == 0 or surface.tier >= WorldBuilder.TIER_DIRT:
		_bump_t -= delta
		var spd := absf(v)
		if _bump_t <= 0.0 and spd > 15.0 and _wheels_on_ground() >= 2:
			_bump_t = randf_range(0.15, 0.5)
			var strength := (spd - 15.0) * (1.8 if surface.tier == WorldBuilder.TIER_EXTREME else 1.0) * mass * 0.012
			var at := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-1.5, 1.5))
			apply_impulse(global_basis.y * strength * randf_range(0.3, 1.0), global_basis * at)
			_on_bump(spd)
	# Aufprall erkennen
	last_crash_t += delta
	var dv := (linear_velocity - _last_vel).length()
	if dv > 9.0 and _last_vel.length() > 8.0:
		last_crash_t = 0.0
		_on_crash(dv)
	_last_vel = linear_velocity


func _surface_cap() -> float:
	return 150.0 if (surface.tier == WorldBuilder.TIER_MAIN or surface.tier == WorldBuilder.TIER_VILLAGE) else 20.0


func _wheels_on_ground() -> int:
	var n := 0
	for w in wheels:
		if w.is_in_contact():
			n += 1
	return n


func _update_surface() -> void:
	var p := Vector2(global_position.x, global_position.z)
	var info := world.road_info(p, 1.5)
	surface = {tier = info.tier, kind = info.kind}
	var wet := GameState.wetness
	var f := 2.8
	match info.tier:
		WorldBuilder.TIER_MAIN, WorldBuilder.TIER_VILLAGE:
			f = 2.8 * (1.0 - 0.15 * wet)
		WorldBuilder.TIER_DIRT:
			f = 2.3 * (1.0 - 0.35 * wet) * offroad_mult
		WorldBuilder.TIER_EXTREME:
			f = 1.25 * (1.0 - 0.45 * wet) * offroad_mult * offroad_mult
		_:
			var kind := world.kind_at(p.x, p.y)
			f = (1.7 if kind == "forest" else 2.0) * (1.0 - 0.5 * wet) * offroad_mult
	f *= grip_mult
	for w in wheels:
		w.wheel_friction_slip = f


## 0..1: Motorleistung (Schaden, leerer Tank)
func _power_factor() -> float:
	return 1.0


func _on_drive(_delta: float, _throttle: float, _v: float) -> void:
	pass


func _on_bump(_speed: float) -> void:
	pass


func _on_crash(_dv: float) -> void:
	pass


var _flip_cd := 0.0


## Aufstellen: nur wenn das Auto umgekippt oder festgefahren ist, mit Wartezeit, direkt auf den Boden
func can_flip() -> String:
	if _flip_cd > 0.0:
		return "Aufstellen geht erst wieder in %d s" % ceili(_flip_cd)
	if global_basis.y.y > 0.75 and absf(speed_kmh()) > 3.0:
		return "Das Auto steht ja"
	return ""


func flip_upright() -> void:
	_flip_cd = 5.0
	var f := global_basis.z
	f.y = 0
	if f.length() < 0.1:
		f = Vector3.BACK
	var p := global_position
	if world:
		p.y = world.height_at(p.x, p.z) + 1.3
	global_transform = Transform3D(Basis.looking_at(-f.normalized(), Vector3.UP), p)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()


func place_at(pos: Vector3, forward: Vector3) -> void:
	var y := world.height_at(pos.x, pos.z) + 1.2 if world else pos.y
	global_transform = Transform3D(Basis.looking_at(-forward.normalized(), Vector3.UP), Vector3(pos.x, y, pos.z))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_vel = Vector3.ZERO
	reset_physics_interpolation()


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, outline := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(color, outline, 0.02)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	add_child(cs)
