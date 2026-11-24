class_name Player
extends CharacterBody3D
## Spielfigur: läuft relativ zur Kamera, Shift rennt, Leertaste springt.
## Das Modell ist aus einfachen Formen gebaut (Cartoon-Stil) und hat eine kleine Laufanimation.

@export var walk_speed := 4.5
@export var run_speed := 9.0
@export var jump_velocity := 5.5
@export var shirt_color := Color(0.85, 0.22, 0.20)
@export var pants_color := Color(0.20, 0.30, 0.55)
@export var skin_color := Color(0.98, 0.80, 0.66)
@export var hat_color := Color(0.15, 0.45, 0.30)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rig: CameraRig
var input_enabled := true
var facing := Vector3.BACK  # Blickrichtung des Modells (Welt)

var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _walk_phase := 0.0
var _step_sound: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_build_model()
	_step_sound = AudioStreamPlayer3D.new()
	_step_sound.stream = Sfx.footstep()
	_step_sound.volume_db = -6.0
	_step_sound.unit_size = 4.0
	add_child(_step_sound)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := camera_rig.ground_forward() if camera_rig else Vector3.FORWARD
	var right := Vector3(-fwd.z, 0, fwd.x)
	var dir := (right * input.x - fwd * input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := 14.0 if is_on_floor() else 3.0
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-accel * delta))

	if input_enabled and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()
	_animate(delta, dir)


func _animate(delta: float, dir: Vector3) -> void:
	if dir.length() > 0.05:
		facing = dir.normalized()
		var want := atan2(facing.x, facing.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, want, 1.0 - exp(-12.0 * delta))
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var swing := 0.0
	if is_on_floor() and hspeed > 0.3:
		var before := sin(_walk_phase)
		_walk_phase += delta * (4.0 + hspeed * 1.3)
		swing = sin(_walk_phase) * clampf(hspeed / 6.0, 0.25, 0.9)
		if signf(before) != signf(sin(_walk_phase)):
			_step_sound.pitch_scale = randf_range(0.85, 1.15)
			_step_sound.play()
	elif not is_on_floor():
		swing = 0.5
	else:
		_walk_phase = 0.0
	_legs[0].rotation.x = lerpf(_legs[0].rotation.x, swing, 0.3)
	_legs[1].rotation.x = lerpf(_legs[1].rotation.x, -swing, 0.3)
	_arms[0].rotation.x = lerpf(_arms[0].rotation.x, -swing * 0.8, 0.3)
	_arms[1].rotation.x = lerpf(_arms[1].rotation.x, swing * 0.8, 0.3)
	_model.position.y = absf(sin(_walk_phase)) * 0.06 if hspeed > 0.3 else 0.0


# ------------------------------------------------------------------ Modell (schaut nach +Z)

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(color, outline, 0.02)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Modell"
	add_child(_model)

	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 0.95
	_part(_model, body, shirt_color, Vector3(0, 1.15, 0))

	var head := SphereMesh.new()
	head.radius = 0.27
	head.height = 0.52
	_part(_model, head, skin_color, Vector3(0, 1.82, 0))

	var nose := SphereMesh.new()
	nose.radius = 0.06
	nose.height = 0.12
	_part(_model, nose, skin_color.darkened(0.1), Vector3(0, 1.79, 0.26), false)

	var eye := SphereMesh.new()
	eye.radius = 0.045
	eye.height = 0.09
	for x in [-0.1, 0.1]:
		_part(_model, eye, Color(0.08, 0.08, 0.1), Vector3(x, 1.88, 0.23), false)

	# Kappe mit Schirm
	var cap := CylinderMesh.new()
	cap.top_radius = 0.24
	cap.bottom_radius = 0.29
	cap.height = 0.16
	_part(_model, cap, hat_color, Vector3(0, 2.04, 0))
	var brim := BoxMesh.new()
	brim.size = Vector3(0.36, 0.04, 0.22)
	_part(_model, brim, hat_color.darkened(0.15), Vector3(0, 1.98, 0.3))

	var leg := BoxMesh.new()
	leg.size = Vector3(0.18, 0.72, 0.2)
	var shoe := BoxMesh.new()
	shoe.size = Vector3(0.2, 0.12, 0.3)
	for x in [-0.14, 0.14]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.78, 0)
		_model.add_child(hip)
		_part(hip, leg, pants_color, Vector3(0, -0.36, 0))
		_part(hip, shoe, Color(0.25, 0.18, 0.14), Vector3(0, -0.72, 0.05))
		_legs.append(hip)

	var arm := BoxMesh.new()
	arm.size = Vector3(0.14, 0.62, 0.16)
	var hand := SphereMesh.new()
	hand.radius = 0.09
	hand.height = 0.18
	for x in [-0.38, 0.38]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(x, 1.5, 0)
		_model.add_child(shoulder)
		_part(shoulder, arm, shirt_color, Vector3(0, -0.3, 0))
		_part(shoulder, hand, skin_color, Vector3(0, -0.64, 0))
		_arms.append(shoulder)
