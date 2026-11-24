class_name Player
extends CharacterBody3D
## Spielfigur. Standard ist die Ego-Perspektive (V schaltet auf Third Person).
## WASD laufen, Shift rennen (kostet Ausdauer), C ducken (leiser), Leertaste springen.
## Trägt Gewehr, Fernglas und Taschenlampe (WeaponHand) und kann erlegtes Wild tragen.

signal shot(from: Vector3, dir: Vector3)

@export var walk_speed := 4.2
@export var run_speed := 8.0
@export var crouch_speed := 2.0
@export var jump_velocity := 5.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rig: CameraRig
var input_enabled := true
var facing := Vector3.BACK
var crouched := false
var on_stand: Node3D = null  # Hochstand, auf dem man sitzt
var carrying: Node3D = null  # getragenes Wild
var passed_out := 0.0  # Sekunden bis zum Aufwachen
var hand: WeaponHand
var model: CharacterModel

var _step_sound: AudioStreamPlayer3D
var _drift := Vector3.ZERO
var _noise_t := 0.0
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	_col.shape = cap
	_col.position.y = 0.9
	add_child(_col)
	model = CharacterModel.new(GameState.outfit, 2)
	model.name = "Modell"
	add_child(model)
	_step_sound = AudioStreamPlayer3D.new()
	_step_sound.stream = Sfx.footstep()
	_step_sound.volume_db = -6.0
	_step_sound.unit_size = 4.0
	add_child(_step_sound)


func attach_camera(rig: CameraRig) -> void:
	camera_rig = rig
	hand = WeaponHand.new()
	hand.name = "Hand"
	rig.hand.add_child(hand)
	hand.setup(rig, self)
	hand.fired.connect(func(f, d): shot.emit(f, d))
	if not GameState.has("rifle"):
		hand.select("none")


func rebuild_model() -> void:
	model.queue_free()
	model = CharacterModel.new(GameState.outfit, 2)
	add_child(model)


func is_busy() -> bool:
	return passed_out > 0.0 or not input_enabled


func _physics_process(delta: float) -> void:
	if passed_out > 0.0:
		passed_out -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		model.animate(delta, 0.0)
		if passed_out <= 0.0:
			model.set_lying(false)
			input_enabled = true
		return
	if on_stand:
		velocity = Vector3.ZERO
		global_position = on_stand.global_transform * Vector3(0, 3.6, 0)
		_hand_and_model(delta, Vector3.ZERO)
		return

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
	# Betrunken: man läuft nicht ganz geradeaus
	var drunk := GameState.drunkness()
	if drunk > 0.0 and dir.length() > 0.1:
		_drift = _drift.lerp(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), delta * 0.8)
		dir = (dir + _drift * drunk * 0.6).normalized() * dir.length()

	var sprint := Input.is_action_pressed("sprint") and input_enabled and GameState.stamina > 5.0 and not crouched and carrying == null
	var speed := run_speed if sprint else walk_speed
	if crouched:
		speed = crouch_speed
	if carrying:
		speed *= 0.6
	if hand and hand.aiming:
		speed *= 0.5
	if sprint and dir.length() > 0.1:
		GameState.stamina = maxf(0.0, GameState.stamina - delta * 14.0)
	var accel := 14.0 if is_on_floor() else 3.0
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-accel * delta))

	if input_enabled and is_on_floor() and Input.is_action_just_pressed("jump") and not crouched:
		velocity.y = jump_velocity

	move_and_slide()

	# Geräusche fürs Wild: Laufen ist leise, Rennen laut, Ducken fast lautlos
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_noise_t -= delta
	if hspeed > 0.5 and _noise_t <= 0.0:
		_noise_t = 0.5
		var r := 6.0 if crouched else (35.0 if sprint else 16.0)
		GameState.make_noise(global_position, r, "step")
	# Husten vom Rauchen
	if GameState.smoke_time > 0.0 and GameState.cough_timer <= 0.0:
		GameState.cough_timer = randf_range(10.0, 30.0)
		Sfx.play_3d(self, Sfx.cough(), 0.0, randf_range(0.9, 1.1))
		GameState.make_noise(global_position, 80.0, "cough")
		if camera_rig:
			camera_rig.shake(0.4)
	_hand_and_model(delta, dir)


func _hand_and_model(delta: float, dir: Vector3) -> void:
	var fp := camera_rig and camera_rig.first_person
	var aiming := hand and hand.aiming
	if fp or aiming or on_stand:
		facing = camera_rig.ground_forward()
	elif dir.length() > 0.05:
		facing = dir.normalized()
	var want := atan2(facing.x, facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, want, 1.0 - exp(-12.0 * delta))
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if model.animate(delta, hspeed, is_on_floor(), aiming or (hand and hand.slot == "rifle" and fp), on_stand != null, hand and hand.action != "", hand and hand.reloading()) > 0.0:
		_step_sound.pitch_scale = randf_range(0.85, 1.15)
		_step_sound.volume_db = -14.0 if crouched else -6.0
		_step_sound.play()
	model.scale.y = lerpf(model.scale.y, 0.72 if crouched else 1.0, 0.2)
	if camera_rig and camera_rig.target == self:
		camera_rig.height = lerpf(camera_rig.height, 1.15 if crouched else 1.65, 0.15)
	if hand:
		hand.process_hand(delta, input_enabled and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DebugTools.active), crouched, on_stand != null)
	if carrying:
		carrying.global_position = global_position + Vector3.UP * 1.35 - facing * 0.3
		carrying.global_rotation = Vector3(0, atan2(facing.x, facing.z) + PI / 2, 0)


func toggle_crouch() -> void:
	crouched = not crouched


## Ohnmacht (zu viel Schnaps oder schwer verletzt)
func pass_out(seconds: float) -> void:
	passed_out = seconds
	input_enabled = false
	crouched = false
	model.set_lying(true)
	if camera_rig and camera_rig.first_person:
		camera_rig.toggle_view()
