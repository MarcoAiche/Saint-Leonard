class_name CameraRig
extends Node3D
## Third-Person-Kamera: folgt einem Ziel, Maus dreht die Kamera, Mausrad zoomt.
## Im Auto schwenkt sie nach kurzer Zeit ohne Mausbewegung automatisch hinter das Auto.

@export var sensitivity := 0.0025
var target: Node3D
var height := 1.6
var distance := 5.0
var follow_behind := false
var yaw := 0.0
var pitch := -0.3

var arm: SpringArm3D
var camera: Camera3D
var _idle := 10.0


func _ready() -> void:
	# Die Kamera bewegt sich pro Bild selbst, nicht im Physiktakt
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arm = SpringArm3D.new()
	arm.collision_mask = 1  # nur Welt, nicht Figur oder Auto
	arm.margin = 0.3
	var s := SphereShape3D.new()
	s.radius = 0.25
	arm.shape = s
	arm.spring_length = distance
	add_child(arm)
	camera = Camera3D.new()
	camera.far = 6000.0
	camera.fov = 70.0
	arm.add_child(camera)
	camera.make_current()


func set_target(t: Node3D, h: float, d: float, behind: bool) -> void:
	target = t
	height = h
	distance = d
	follow_behind = behind
	if t:
		global_position = t.global_position + Vector3.UP * h


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.3, 0.35)
		_idle = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - 0.7, 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + 0.7, 16.0)


func _process(delta: float) -> void:
	if not target:
		return
	# Interpolierte Lage verwenden, sonst ruckelt das Bild zwischen den Physikschritten
	var xf := target.get_global_transform_interpolated()
	var goal := xf.origin + Vector3.UP * height
	global_position = global_position.lerp(goal, 1.0 - exp(-delta * 25.0))
	_idle += delta
	if follow_behind and target is RigidBody3D:
		var f: Vector3 = xf.basis.z
		var speed: float = (target as RigidBody3D).linear_velocity.length()
		if _idle > 1.2 and speed > 2.0:
			var want := atan2(-f.x, -f.z)
			yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * 2.5))
			pitch = lerpf(pitch, -0.22, 1.0 - exp(-delta * 1.5))
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = lerpf(arm.spring_length, distance, 1.0 - exp(-delta * 6.0))


## Blickrichtung der Kamera auf dem Boden (für die Laufrichtung der Figur)
func ground_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))
