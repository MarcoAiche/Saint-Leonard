class_name Trailer
extends VehicleBody3D
## Pickup-Anhänger (Bauhaus, 1.500 €): zwei Räder, Deichsel mit Kupplung, Ladefläche für 4 Dinge.
## Wird an der Anhängerkupplung des Pickups eingehängt (PinJoint3D, frei drehbar wie eine Kugelkupplung).
## Ladung ohne Spanngurte rutscht bei schneller Fahrt über Schotter oder Gelände herunter;
## festgezurrt (Spanngurte im Rucksack) bleibt sie drauf, man sieht dann gelbe Gurte.
## Vorne ist +Z (zur Deichsel).

signal cargo_lost(node: Node3D)

const SLOTS := [Vector3(-0.45, 0.62, 0.55), Vector3(0.45, 0.62, 0.55), Vector3(-0.45, 0.62, -0.45), Vector3(0.45, 0.62, -0.45)]
const HITCH := Vector3(0, 0.45, 2.45)  # Kupplungskopf (lokal)

var world: WorldBuilder
var cargo: Array[Node3D] = []
var strapped := false
var towed_by: Node3D = null
var puppet := false  # Anhänger eines anderen Spielers: Lage kommt übers Netz

var _joint: PinJoint3D
var _straps: Node3D
var _bump_t := 0.0
var _color := Color(0.30, 0.32, 0.36)


func _ready() -> void:
	add_to_group("trailer")
	if puppet:
		custom_integrator = true
		gravity_scale = 0.0
	mass = 420.0
	collision_layer = 4
	collision_mask = 1 | 4 | 8 | 16
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.1, 0.2)
	angular_damp = 1.0
	_build()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if puppet:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO


func _box(size: Vector3, pos: Vector3, col: Color, parent: Node3D = self) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = Toon.solid(col, true, 0.015)
	parent.add_child(mi)
	return mi


func _build() -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 0.5, 2.4)
	cs.shape = bs
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)
	var dark := Color(0.12, 0.12, 0.13)
	_box(Vector3(1.8, 0.12, 2.4), Vector3(0, 0.45, 0), Color(0.45, 0.33, 0.2))  # Holzboden
	for x in [-0.9, 0.9]:
		_box(Vector3(0.06, 0.4, 2.4), Vector3(x, 0.7, 0), _color)
	for z in [-1.2, 1.2]:
		_box(Vector3(1.8, 0.4, 0.06), Vector3(0, 0.7, z), _color)
	_box(Vector3(0.12, 0.12, 1.3), Vector3(0, 0.38, 1.8), dark)  # Deichsel
	_box(Vector3(0.18, 0.12, 0.18), Vector3(0, 0.42, 2.45), Color(0.6, 0.6, 0.62))  # Kupplungskopf
	_box(Vector3(1.9, 0.05, 0.5), Vector3(0, 0.55, -0.1), dark)  # Kotflügel
	for x in [-0.5, 0.5]:
		_box(Vector3(0.25, 0.12, 0.05), Vector3(x, 0.55, -1.23), Color(0.9, 0.1, 0.1))  # Rücklichter
	var plate := _box(Vector3(0.45, 0.12, 0.03), Vector3(0, 0.38, -1.24), Color(0.95, 0.95, 0.9))
	plate.material_override = Toon.solid(Color(0.95, 0.95, 0.9), false)
	for x in [0.98, -0.98]:
		var w := VehicleWheel3D.new()
		w.position = Vector3(x, 0.3, -0.1)
		w.wheel_radius = 0.36
		w.wheel_rest_length = 0.2
		w.suspension_travel = 0.18
		w.suspension_stiffness = 45.0
		w.suspension_max_force = 9000.0
		w.damping_compression = 2.2
		w.damping_relaxation = 2.6
		w.wheel_friction_slip = 2.4
		add_child(w)
		var tire := CylinderMesh.new()
		tire.top_radius = 0.36
		tire.bottom_radius = 0.36
		tire.height = 0.24
		var mi := MeshInstance3D.new()
		mi.mesh = tire
		mi.rotation.z = PI / 2
		mi.material_override = Toon.solid(dark, true, 0.015)
		w.add_child(mi)
	_straps = Node3D.new()
	add_child(_straps)
	for z in [-0.7, 0.0, 0.7]:
		_box(Vector3(1.86, 0.03, 0.08), Vector3(0, 1.0, z), Color(0.98, 0.78, 0.1), _straps)
	_straps.visible = false


func _physics_process(_delta: float) -> void:
	if puppet:
		return
	brake = 0.0 if towed_by else 6.0  # abgestellt: Feststellbremse
	_check_cargo(_delta)


# ------------------------------------------------------------------ Kuppeln

## Weltposition des Kupplungskopfs
func hitch_point() -> Vector3:
	return global_transform * HITCH


## An die Kupplung eines Pickups hängen: Anhänger wird sauber dahinter ausgerichtet
func couple(truck: Node3D) -> void:
	if towed_by:
		return
	var tb: Vector3 = truck.global_basis.z
	tb.y = 0
	tb = tb.normalized()
	var ball: Vector3 = truck.global_transform * Truck.HITCH
	var origin := ball - tb * HITCH.z
	origin.y = ball.y - HITCH.y
	global_transform = Transform3D(Basis.looking_at(-tb, Vector3.UP), origin)
	linear_velocity = truck.linear_velocity if truck is RigidBody3D else Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	_joint = PinJoint3D.new()
	_joint.name = "Kupplung"
	get_parent().add_child(_joint)
	_joint.global_position = ball
	_joint.node_a = truck.get_path()
	_joint.node_b = get_path()
	towed_by = truck


func uncouple() -> void:
	if is_instance_valid(_joint):
		_joint.queue_free()
	_joint = null
	towed_by = null


## Pickup steht so, dass man einkuppeln kann?
func can_couple(truck: Node3D) -> bool:
	return not towed_by and (truck.global_transform * Truck.HITCH).distance_to(hitch_point()) < 4.0


# ------------------------------------------------------------------ Ladung

func has_space() -> bool:
	return cargo.size() < SLOTS.size()


func load_cargo(n: Node3D) -> bool:
	if not has_space():
		return false
	if n is Carcass:
		(n as Carcass).set_carried(true)
	if n.get_parent():
		n.get_parent().remove_child(n)
	add_child(n)
	n.position = SLOTS[cargo.size()]
	n.rotation = Vector3(0, PI / 2, 0)
	if n is Carcass:
		n.scale = Vector3.ONE * clampf(1.0 / Animal.SPECIES[n.species].size, 0.5, 1.0)
	cargo.append(n)
	return true


func unload_last() -> Node3D:
	if cargo.is_empty():
		return null
	return cargo.pop_back()


func set_strapped(on: bool) -> void:
	strapped = on
	_straps.visible = on


func _drop_cargo(n: Node3D) -> void:
	cargo.erase(n)
	var xf := n.global_transform
	remove_child(n)
	get_parent().add_child(n)
	n.global_transform = xf
	n.scale = Vector3.ONE
	if n is Carcass:
		(n as Carcass).set_carried(false)
		(n as RigidBody3D).linear_velocity = linear_velocity * 0.7 + Vector3.UP * 3.0
	cargo_lost.emit(n)


var _last_vel := Vector3.ZERO


## Ungesicherte Ladung fällt NUR bei extremen G-Kräften, Crash, starkem Drift oder Überschlag herunter
func _check_cargo(delta: float) -> void:
	if cargo.is_empty() or strapped:
		_last_vel = linear_velocity
		return
	if global_basis.y.y < 0.45:
		_drop_cargo(cargo.back())
		_last_vel = linear_velocity
		return
	var g_accel := (linear_velocity - _last_vel).length() / maxf(delta, 0.005)
	_last_vel = linear_velocity
	var spd := linear_velocity.length() * 3.6
	if g_accel > 28.0 or (spd > 65.0 and angular_velocity.length() > 3.2):
		_drop_cargo(cargo.back())


## Ladung eines fremden Anhängers andeuten (Mehrspieler)
func show_remote_cargo(list: Array) -> void:
	for c in get_children():
		if c.has_meta("remote_cargo"):
			c.queue_free()
	for i in mini(list.size(), SLOTS.size()):
		var kind: String = str(list[i])
		var n := Node3D.new()
		if Animal.SPECIES.has(kind):
			_box(Vector3(0.5, 0.45, 1.1) * clampf(Animal.SPECIES[kind].size, 0.4, 1.0), Vector3(0, 0.25, 0), Animal.SPECIES[kind].body, n)
		else:
			n = Placeables.model("moonshine" if kind == "moonshine" else "crate")
		n.set_meta("remote_cargo", true)
		n.position = SLOTS[i]
		n.rotation.y = PI / 2
		add_child(n)


func puppet_to(xf: Transform3D) -> void:
	var target := global_transform.interpolate_with(xf, 0.5) if global_transform.origin.distance_to(xf.origin) < 12.0 else xf
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target)
	global_transform = target
