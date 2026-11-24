class_name CameraRig
extends Node3D
## Kamera: Ego-Perspektive (Standard zu Fuß) oder Third Person (Taste V, im Auto Standard).
## Maus dreht, Mausrad zoomt (Third Person). Alkohol lässt das Bild schwanken, Schüsse geben Rückstoß.

@export var sensitivity := 0.0025
var target: Node3D
var height := 1.6
var distance := 5.0
var follow_behind := false
var first_person := true
var yaw := 0.0
var pitch := -0.1
var fov_target := 72.0
var base_fov := 72.0

var arm: SpringArm3D
var camera: Camera3D
var hand: Node3D  # hier hängen Gewehr und Fernglas in der Ego-Perspektive
var _idle := 10.0
var _recoil := 0.0
var _t := 0.0
var _shake := 0.0
var _fp_height := 1.65
var seat_offset := Vector3(0.45, 1.25, 0.1)  # Sitzplatz im Fahrzeug (lokal), für die Ego-Perspektive


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	var s := SphereShape3D.new()
	s.radius = 0.25
	arm.shape = s
	arm.spring_length = distance
	add_child(arm)
	camera = Camera3D.new()
	camera.far = 6000.0
	camera.near = 0.05
	camera.fov = base_fov
	arm.add_child(camera)
	camera.make_current()
	hand = Node3D.new()
	hand.name = "Hand"
	camera.add_child(hand)
	_apply_layers()


func set_target(t: Node3D, h: float, d: float, behind: bool, fp := false) -> void:
	target = t
	height = h
	distance = d
	follow_behind = behind
	first_person = fp
	_fp_height = h
	_apply_layers()
	if t:
		global_position = t.global_position + Vector3.UP * h


func toggle_view() -> void:
	first_person = not first_person
	_apply_layers()


## In der Ego-Perspektive die eigene Figur (Ebene 2) nicht zeigen
func _apply_layers() -> void:
	if camera:
		var mask := 0xFFFFF
		if first_person:
			mask &= ~2
			if target is RigidBody3D:
				mask &= ~4  # Fahrzeugkabine
		camera.cull_mask = mask


func add_recoil(amount: float) -> void:
	_recoil += amount


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := sensitivity * float(Settings.get_v("sensitivity")) * camera.fov / base_fov
		var dy: float = event.relative.y * (-1.0 if Settings.get_v("invert_y") else 1.0)
		yaw -= event.relative.x * k
		pitch = clampf(pitch - dy * k, -1.45, 1.35 if first_person else 0.35)
		_idle = 0.0
	elif event is InputEventMouseButton and event.pressed and not first_person:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - 0.7, 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + 0.7, 16.0)


func _process(delta: float) -> void:
	if not target:
		return
	_t += delta
	var xf := target.get_global_transform_interpolated()
	var in_vehicle := target is RigidBody3D
	var goal := xf * seat_offset if in_vehicle and first_person else xf.origin + Vector3.UP * height
	if first_person:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-delta * 25.0))
	_idle += delta
	if follow_behind and target is RigidBody3D and not first_person:
		var f: Vector3 = xf.basis.z
		var speed: float = (target as RigidBody3D).linear_velocity.length()
		if _idle > 1.2 and speed > 2.0:
			var want := atan2(-f.x, -f.z)
			yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * 2.5))
			pitch = lerpf(pitch, -0.22, 1.0 - exp(-delta * 1.5))

	# Rückstoß klingt ab
	pitch = minf(pitch + _recoil * delta * 12.0, 1.35)
	_recoil = move_toward(_recoil, 0.0, delta * 1.2)
	_recoil *= exp(-delta * 10.0)

	# Schwanken bei Alkohol
	var drunk := GameState.drunkness()
	var sway_yaw := sin(_t * 0.7) * 0.05 * drunk + sin(_t * 1.9) * 0.015 * drunk
	var sway_pitch := sin(_t * 1.1 + 1.0) * 0.03 * drunk
	var roll := sin(_t * 0.6) * 0.09 * drunk
	_shake = move_toward(_shake, 0.0, delta * 2.0)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.02
	if in_vehicle and first_person:
		# im Fahrzeug: Blick relativ zum Fahrzeug (yaw 0 = nach vorne)
		var vb := xf.basis.orthonormalized() * Basis(Vector3.UP, PI)
		global_basis = vb * Basis.from_euler(Vector3(pitch + sway_pitch + sh.y, yaw + sway_yaw + sh.x, roll))
	else:
		rotation = Vector3(pitch + sway_pitch + sh.y, yaw + sway_yaw + sh.x, roll)
	arm.spring_length = 0.0 if first_person else lerpf(arm.spring_length, distance, 1.0 - exp(-delta * 6.0))
	base_fov = float(Settings.get_v("fov"))
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-delta * 14.0))


## Blickrichtung der Kamera auf dem Boden (für die Laufrichtung der Figur)
func ground_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func aim_ray() -> Array:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	return [from, dir]
