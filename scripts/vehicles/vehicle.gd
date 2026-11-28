@tool
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

var _steer := 0.0
var _steer_buffer: Array = []  # verzögerte Lenkung bei Alkohol
var _surface_t := 0.0
var _bump_t := 0.0
var _last_vel := Vector3.ZERO
var _engine: EngineSound
var _dust: GPUParticles3D
var _splash: GPUParticles3D
var _headlights: Array[SpotLight3D] = []
var _base_friction := 2.8
var grip_mult := 1.0  # Umbauten (Geländereifen)
## Fahrzeug eines anderen Spielers: Lage kommt übers Netz, keine eigene Physik
var puppet := false
var offroad_mult := 1.0
var parking_brake := true
var _animal_hit_cd := {}  # instance_id -> Cooldown in Sekunden


func _ready() -> void:
	if Engine.is_editor_hint():
		return
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
	_dust = _make_vehicle_particles(Color(0.769, 0.675, 0.525, 0.55), 16, 0.65, 0.55)
	_dust.position = Vector3(0, 0.25, -1.2)
	add_child(_dust)
	_splash = _make_vehicle_particles(Color(1.0, 1.0, 1.0, 0.75), 14, 0.45, 0.35)
	_splash.position = Vector3(0, 0.2, 0.0)
	add_child(_splash)


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
	elif parking_brake and (_wheels_on_ground() >= 2 or not driving):
		var hvel := Vector2(state.linear_velocity.x, state.linear_velocity.z).length()
		if hvel < 0.6:
			state.linear_velocity.x = 0.0
			state.linear_velocity.z = 0.0
			if state.linear_velocity.y > 0.0:
				state.linear_velocity.y = 0.0
			state.angular_velocity *= 0.2
		elif hvel < 1.5:
			state.linear_velocity.x *= 0.75
			state.linear_velocity.z *= 0.75
			state.angular_velocity *= 0.7


## Netz-Fahrzeug weich auf die gemeldete Lage ziehen
func puppet_to(xf: Transform3D) -> void:
	var cur := global_transform
	var target := cur.interpolate_with(xf, 0.5) if cur.origin.distance_to(xf.origin) < 12.0 else xf
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target)
	global_transform = target


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
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
	if throttle > 0.0:
		if v < -2.0:
			brk = max_brake
		else:
			force = throttle * max_engine_force * power * clampf(1.0 - v / top_speed_kmh, 0.0, 1.0)
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
	var wants_drive := driving and absf(throttle) >= 0.05 and not handbrake and not (broken and throttle > 0.0)
	if wants_drive:
		parking_brake = false
		if sleeping:
			sleeping = false
	elif not driving or (absf(throttle) < 0.05 and linear_velocity.length() < 1.2):
		parking_brake = true
	if parking_brake:
		brk = max_brake * 2.5
		force = 0.0
	engine_force = force
	brake = brk
	_engine.running = driving and not broken
	_engine.throttle = throttle
	_engine.speed_kmh = v
	_on_drive(delta, throttle, v)

	var speed_t := clampf(absf(v) / 110.0, 0.0, 1.0)
	var steer_limit := max_steer * lerpf(1.0, 0.16, pow(speed_t, 1.3))
	var target_steer := steer_in * steer_limit
	var fast_return := absf(steer_in) < 0.05 or (steer_in * _steer < 0.0)
	var steer_rate := 6.5 if fast_return else 4.2
	_steer = move_toward(_steer, target_steer, delta * steer_rate)
	steering = _steer

	_surface_t -= delta
	if _surface_t <= 0.0 and world:
		_surface_t = 0.2
		_update_surface()
	# Staub- & Wasser-VFX auf Schotter/Gelände/Wasser
	var spd := absf(v)
	var on_ground := _wheels_on_ground() >= 2
	var in_water: bool = surface.kind == "water"
	var dusty: bool = on_ground and spd > 12.0 and not in_water and (surface.tier == 0 or surface.tier >= WorldBuilder.TIER_DIRT)
	if _dust:
		_dust.emitting = dusty
	if _splash:
		_splash.emitting = on_ground and spd > 6.0 and in_water
	# Holpern auf Schotter, Gelände und Bergpfaden
	if surface.tier == 0 or surface.tier >= WorldBuilder.TIER_DIRT:
		_bump_t -= delta
		if _bump_t <= 0.0 and spd > 15.0 and _wheels_on_ground() >= 2:
			_bump_t = randf_range(0.15, 0.5)
			var strength := (spd - 15.0) * (1.8 if surface.tier == WorldBuilder.TIER_EXTREME else 1.0) * mass * 0.012
			var at := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-1.5, 1.5))
			apply_impulse(global_basis.y * strength * randf_range(0.3, 1.0), global_basis * at)
			_on_bump(spd)
	# Aufprall erkennen
	var dv := (linear_velocity - _last_vel).length()
	if dv > 9.0 and _last_vel.length() > 8.0:
		_on_crash(dv)
	_last_vel = linear_velocity
	_check_animal_hits(delta)


func _check_animal_hits(delta: float) -> void:
	for k in _animal_hit_cd.keys():
		_animal_hit_cd[k] -= delta
		if _animal_hit_cd[k] <= 0.0:
			_animal_hit_cd.erase(k)
	var vel_xz := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var impact_kmh := vel_xz.length() * 3.6
	if impact_kmh < 4.0:
		return
	var dir := vel_xz.normalized()
	for body in get_colliding_bodies():
		if body is Animal and not (body as Animal).is_dead():
			var aid := body.get_instance_id()
			if _animal_hit_cd.has(aid):
				continue
			_animal_hit_cd[aid] = 0.35
			if Net.is_client():
				Net.vehicle_hit_animal((body as Animal).net_id, impact_kmh, dir)
			else:
				(body as Animal).hit_by_vehicle(impact_kmh, dir, self)


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


func _make_vehicle_particles(col: Color, cnt: int, life: float, radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = cnt
	p.lifetime = life
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.85, 0.1, 0.8)
	pm.direction = Vector3(0, 0.6, -1.0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -2.5, 0)
	p.process_material = pm
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 1.4
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	s.material = m
	p.draw_pass_1 = s
	return p


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


func flip_upright(fallback_pos := Vector3.INF, fallback_yaw := 0.0) -> void:
	respawn_safe(fallback_pos, fallback_yaw)


## Richtet das Fahrzeug sicher auf, nullt Geschwindigkeiten und setzt es bodengenau (bei Out-of-Bounds auf den Heimat-Parkplatz)
func respawn_safe(fallback_pos := Vector3.INF, fallback_yaw := 0.0) -> void:
	if puppet or Net.is_client():
		return
	_flip_cd = 5.0
	var f := global_basis.z
	f.y = 0.0
	var yaw := atan2(f.x, f.z) if f.length() >= 0.1 else fallback_yaw
	var target_pos := global_position
	var fb_pos := fallback_pos if fallback_pos.is_finite() else Vector3(1170.0, 0.0, 10.0)
	if world:
		var p2 := Vector2(target_pos.x, target_pos.z)
		if not world.inside_border(p2):
			target_pos = fb_pos
			yaw = fallback_yaw
		else:
			var ri := world.road_info(p2, 45.0)
			if ri.tier != 0:
				target_pos = Vector3(ri.pos.x, target_pos.y, ri.pos.y)
		global_transform = world.find_safe_spawn_transform(target_pos, yaw, fb_pos, fallback_yaw, 1.25, [get_rid()])
	else:
		global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(target_pos.x, target_pos.y + 1.25, target_pos.z))
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_vel = Vector3.ZERO
	parking_brake = not driving
	_animal_hit_cd.clear()
	reset_physics_interpolation()


func place_at(pos: Vector3, forward: Vector3) -> void:
	var f := Vector3(forward.x, 0.0, forward.z)
	var yaw := atan2(f.x, f.z) if f.length() > 0.05 else 0.0
	if world:
		global_transform = world.find_safe_spawn_transform(pos, yaw, pos, yaw, 1.2, [get_rid()])
	else:
		global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_vel = Vector3.ZERO
	parking_brake = not driving
	_animal_hit_cd.clear()
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
