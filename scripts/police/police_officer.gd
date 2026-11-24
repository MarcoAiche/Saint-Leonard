class_name PoliceOfficer
extends CharacterBody3D
## Abgesessener Polizist: verfolgt den Spieler zu Fuß (etwas langsamer als Sprint),
## wehrt sich mit Pistole (70 %) oder Maschinengewehr (30 %) inkl. Schieß-Animation,
## Kopfschuss sofort tödlich, Körpertreffer 3-9 Schüsse.

const GRAVITY := 24.0
const WALK_SPEED := 5.4
const SHOOT_RANGE := 45.0

var game: Node
var manager: Node
var car: Node3D
var target: Node3D
var hostile := false
var alive := true
var shots_left := 5
var weapon_kind := "pistol"
var model: CharacterModel
var _rng := RandomNumberGenerator.new()
var _shoot_t := 0.8
var _burst_left := 0
var _recoil_t := 0.0
var _muzzle_light: OmniLight3D


func setup(g: Node, mgr: Node, parent_car: Node3D, is_hostile := false) -> void:
	game = g
	manager = mgr
	car = parent_car
	hostile = is_hostile
	_rng.randomize()
	shots_left = _rng.randi_range(3, 9)
	weapon_kind = "pistol" if _rng.randf() < 0.70 else "mg"
	collision_layer = 16
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = CharacterModel.new({uniform = true, hat = "police"})
	add_child(model)
	_build_weapon_mesh()
	add_to_group("police_officer")


func _build_weapon_mesh() -> void:
	if not model or model.arms.size() < 2:
		return
	var hand: Node3D = model.arms[1]
	var holder := Node3D.new()
	holder.position = Vector3(0.0, -0.62, 0.06)
	hand.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15)
	mat.metallic = 0.6
	mat.roughness = 0.4
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	if weapon_kind == "mg":
		box.size = Vector3(0.07, 0.11, 0.58)
		body.position = Vector3(0, -0.02, 0.20)
		var mag := MeshInstance3D.new()
		var mbox := BoxMesh.new()
		mbox.size = Vector3(0.05, 0.18, 0.07)
		mag.mesh = mbox
		mag.material_override = mat
		mag.position = Vector3(0, -0.12, 0.14)
		holder.add_child(mag)
	else:
		box.size = Vector3(0.05, 0.09, 0.24)
		body.position = Vector3(0, -0.01, 0.10)
	body.mesh = box
	body.material_override = mat
	holder.add_child(body)
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.78, 0.35)
	_muzzle_light.omni_range = 6.0
	_muzzle_light.light_energy = 0.0
	_muzzle_light.position = Vector3(0, -0.01, 0.52 if weapon_kind == "mg" else 0.24)
	holder.add_child(_muzzle_light)


func take_hit(_dmg: float, hit_pos: Vector3) -> bool:
	if not alive:
		return false
	hostile = true
	var headshot := (hit_pos.y - global_position.y) > 1.35
	if headshot:
		shots_left = 0
	else:
		shots_left -= 1
	if shots_left <= 0:
		_die()
		return true
	return false


func _die() -> void:
	alive = false
	collision_layer = 0
	collision_mask = 0
	rotation.x = PI * 0.5
	if manager and manager.has_method("on_officer_killed"):
		manager.on_officer_killed(self)
	get_tree().create_timer(10.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not alive or get_tree().paused:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var spd := 0.0
	if is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 2.2:
			var dir := to.normalized()
			velocity.x = dir.x * WALK_SPEED
			velocity.z = dir.z * WALK_SPEED
			spd = WALK_SPEED
			rotation.y = atan2(dir.x, dir.z)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		if hostile and d < SHOOT_RANGE:
			_shoot_t -= delta
			if _shoot_t <= 0.0:
				_fire_at_target()
				if weapon_kind == "mg":
					if _burst_left <= 0:
						_burst_left = _rng.randi_range(2, 4)
						_shoot_t = 0.16
					else:
						_burst_left -= 1
						_shoot_t = 0.16 if _burst_left > 0 else _rng.randf_range(0.9, 1.3)
				else:
					_shoot_t = _rng.randf_range(0.9, 1.3)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if model:
		model.animate(delta, spd, true, hostile, false, false, false)
		if _recoil_t > 0.0:
			_recoil_t = maxf(0.0, _recoil_t - delta)
			if model.arms.size() >= 2:
				model.arms[1].rotation.x -= _recoil_t * 2.2
	if _muzzle_light and _muzzle_light.light_energy > 0.0:
		_muzzle_light.light_energy = maxf(0.0, _muzzle_light.light_energy - delta * 30.0)


func _fire_at_target() -> void:
	if not is_instance_valid(game) or not is_instance_valid(target):
		return
	Sfx.play_3d(self, Sfx.gunshot(), 6.0)
	_recoil_t = 0.14
	if _muzzle_light:
		_muzzle_light.light_energy = 3.5
	var from := global_position + Vector3(0, 1.5, 0)
	var aim := target.global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, aim, 1 | 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit or hit.collider == target:
		var acc := 0.35 if weapon_kind == "mg" else 0.45
		var dmg := 11.0 if weapon_kind == "mg" else 16.0
		if _rng.randf() < acc:
			game.set("last_damage_source", "police")
			GameState.damage(dmg)
			if game.get("rig") and game.rig.has_method("shake"):
				game.rig.shake(0.5)
