class_name Car
extends VehicleBody3D
## Fahrbares Auto. Vorne ist +Z (so erwartet es VehicleBody3D).
## W/S Gas und Bremse/Rückwärts, A/D lenken, Leertaste Handbremse, R aufstellen, H hupen.

@export var body_color := Color(0.18, 0.48, 0.88)
@export var max_engine_force := 6000.0
@export var max_brake := 45.0
@export var max_steer := 0.55
@export var top_speed_kmh := 130.0
@export var reverse_speed_kmh := 25.0

var driving := false
var wheels: Array[VehicleWheel3D] = []
var _steer := 0.0
var _horn: AudioStreamPlayer3D
var _engine: EngineSound


func _ready() -> void:
	mass = 1250.0
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0.1)
	angular_damp = 0.8
	_build()


func speed_kmh() -> float:
	return linear_velocity.dot(global_basis.z) * 3.6


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if driving:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")

	var v := speed_kmh()
	var force := 0.0
	var brk := 0.0
	if throttle > 0.0:
		if v < -2.0:
			brk = max_brake
		else:
			force = throttle * max_engine_force * clampf(1.0 - v / top_speed_kmh, 0.0, 1.0)
	elif throttle < 0.0:
		if v > 2.0:
			brk = max_brake * -throttle
		else:
			force = throttle * max_engine_force * 0.6 * clampf(1.0 + v / reverse_speed_kmh, 0.0, 1.0)
	else:
		brk = 1.5 if driving else 12.0  # rollen lassen bzw. geparkt
	if handbrake:
		brk = max_brake * 1.5
		force = 0.0
	engine_force = force
	brake = brk
	_engine.running = driving
	_engine.throttle = throttle
	_engine.speed_kmh = v

	# Bei hoher Geschwindigkeit weniger einlenken, damit es nicht überschlägt
	var steer_limit := max_steer * lerpf(1.0, 0.3, clampf(absf(v) / 90.0, 0.0, 1.0))
	_steer = move_toward(_steer, steer_in * steer_limit, delta * 2.2)
	steering = _steer

	if driving and Input.is_action_just_pressed("reset_vehicle"):
		flip_upright()
	if driving and Input.is_action_just_pressed("horn") and _horn:
		_horn.play()


func flip_upright() -> void:
	var f := global_basis.z
	f.y = 0
	if f.length() < 0.1:
		f = Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(-f.normalized(), Vector3.UP), global_position + Vector3.UP * 1.5)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()


# ------------------------------------------------------------------ Aufbau

func _box(size: Vector3, pos: Vector3, color: Color, outline := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(color, outline, 0.03)
	mi.position = pos
	add_child(mi)
	return mi


func _build() -> void:
	# Kollision: Unterbau + Kabine
	for c in [[Vector3(1.8, 0.7, 4.1), Vector3(0, 0.05, 0)], [Vector3(1.55, 0.6, 2.1), Vector3(0, 0.7, -0.25)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = c[0]
		cs.shape = bs
		cs.position = c[1]
		add_child(cs)

	# Karosserie im Spielzeugauto-Stil
	_box(Vector3(1.8, 0.62, 4.1), Vector3(0, 0.05, 0), body_color)
	_box(Vector3(1.6, 0.62, 2.1), Vector3(0, 0.66, -0.25), body_color.lightened(0.05))
	var glass := Color(0.55, 0.78, 0.95)
	_box(Vector3(1.62, 0.42, 1.4), Vector3(0, 0.68, -0.25), glass, false)  # Seitenfenster
	_box(Vector3(1.4, 0.42, 2.12), Vector3(0, 0.68, -0.25), glass, false)  # Front- und Heckscheibe
	_box(Vector3(1.84, 0.14, 4.16), Vector3(0, -0.2, 0), Color(0.22, 0.22, 0.25))  # Stoßleiste
	for x in [-0.6, 0.6]:
		_box(Vector3(0.36, 0.18, 0.06), Vector3(x, 0.15, 2.06), Color(1.0, 0.95, 0.6), false)  # Scheinwerfer
		_box(Vector3(0.36, 0.16, 0.06), Vector3(x, 0.15, -2.06), Color(0.9, 0.12, 0.1), false)  # Rücklicht
	_box(Vector3(0.5, 0.16, 0.04), Vector3(0, -0.05, 2.08), Color(0.95, 0.95, 0.9), false)  # Nummerntafel

	# Räder
	var tire := CylinderMesh.new()
	tire.top_radius = 0.36
	tire.bottom_radius = 0.36
	tire.height = 0.26
	tire.radial_segments = 14
	var hub := CylinderMesh.new()
	hub.top_radius = 0.18
	hub.bottom_radius = 0.18
	hub.height = 0.28
	hub.radial_segments = 10
	for pos in [Vector3(0.82, -0.05, 1.3), Vector3(-0.82, -0.05, 1.3), Vector3(0.82, -0.05, -1.3), Vector3(-0.82, -0.05, -1.3)]:
		var w := VehicleWheel3D.new()
		w.position = pos
		w.use_as_steering = pos.z > 0
		w.use_as_traction = true
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.25
		w.suspension_travel = 0.22
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 15000.0
		w.damping_compression = 1.9
		w.damping_relaxation = 2.4
		w.wheel_friction_slip = 2.6
		w.wheel_roll_influence = 0.12
		add_child(w)
		for part in [[tire, Color(0.14, 0.14, 0.16)], [hub, Color(0.85, 0.85, 0.88)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = part[0]
			mi.rotation.z = PI / 2
			mi.material_override = Toon.solid(part[1], part[0] == tire, 0.02)
			w.add_child(mi)
		wheels.append(w)

	_horn = AudioStreamPlayer3D.new()
	_horn.stream = Sfx.horn()
	_horn.unit_size = 12.0
	add_child(_horn)
	_engine = EngineSound.new()
	add_child(_engine)
