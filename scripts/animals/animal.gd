class_name Animal
extends CharacterBody3D
## Wildtier mit einfacher KI: äsen, umherziehen, sichern, flüchten. Wildschwein und Bär greifen an,
## wenn man sie verfehlt oder ihnen zu nahe kommt. Hört Geräusche (GameState.noise_made) und sieht
## Spieler (schlechter bei Nebel, Nacht, geduckt oder vom Hochstand aus). Beim Tod wird ein
## Kadaver (Physik) erzeugt, der umfällt und getragen, verladen oder ausgenommen werden kann.

signal died(animal: Animal, carcass: Node3D)

enum State { GRAZE, WANDER, ALERT, FLEE, CHARGE, DEAD }

const SPECIES := {
	deer = {name = "Reh", hp = 70.0, walk = 1.6, run = 12.0, sight = 75.0, hear = 1.0, size = 1.0, aggressive = false,
		body = Color(0.55, 0.36, 0.20), belly = Color(0.86, 0.78, 0.66), loot = {meat = 2, hide = 1}, male_loot = {antlers = 1}},
	legend = {name = "Riesenhirsch", hp = 220.0, walk = 1.8, run = 13.0, sight = 110.0, hear = 1.4, size = 1.45, aggressive = false,
		body = Color(0.45, 0.28, 0.15), belly = Color(0.82, 0.72, 0.58), loot = {meat = 4, hide = 2, legend_antlers = 1}, male_loot = {}},
	boar = {name = "Wildschwein", hp = 110.0, walk = 1.2, run = 9.5, sight = 40.0, hear = 1.1, size = 0.9, aggressive = true, damage = 22.0,
		body = Color(0.28, 0.22, 0.18), belly = Color(0.38, 0.30, 0.25), loot = {meat = 2, hide = 1}, male_loot = {tusks = 1}},
	rabbit = {name = "Hase", hp = 20.0, walk = 1.0, run = 9.0, sight = 35.0, hear = 1.3, size = 0.35, aggressive = false,
		body = Color(0.14, 0.14, 0.14), belly = Color(0.95, 0.95, 0.95), loot = {meat = 1}, male_loot = {}},
	mutant_rabbit = {name = "Mutanten-Hase", hp = 140.0, walk = 2.0, run = 13.0, sight = 55.0, hear = 1.4, size = 1.15, aggressive = true, damage = 18.0,
		body = Color(0.16, 0.16, 0.16), belly = Color(0.92, 0.92, 0.92), loot = {meat = 3}, male_loot = {}},
	bear = {name = "Braunbär", hp = 420.0, walk = 1.4, run = 10.5, sight = 60.0, hear = 0.9, size = 1.5, aggressive = true, damage = 45.0,
		body = Color(0.431, 0.259, 0.125), belly = Color(0.49, 0.32, 0.19), loot = {meat = 5, hide = 2}, male_loot = {}},
	bigfoot = {name = "Bigfoot", hp = 850.0, walk = 2.4, run = 12.5, sight = 65.0, hear = 1.1, size = 2.2, aggressive = true, damage = 35.0,
		body = Color(0.431, 0.259, 0.125), belly = Color(0.847, 0.729, 0.573), loot = {meat = 6, hide = 3}, male_loot = {}},
	fox = {name = "Fuchs", hp = 40.0, walk = 1.8, run = 13.5, sight = 65.0, hear = 1.2, size = 0.7, aggressive = false,
		body = Color(0.75, 0.32, 0.12), belly = Color(0.92, 0.88, 0.82), loot = {meat = 1, hide = 1}, male_loot = {}},
}

static var threats: Array[Node3D] = []  # Spieler und Fahrzeuge, die Tiere bemerken können

var species := "deer"
var info: Dictionary
var male := false
var hp := 70.0
var state := State.GRAZE
var net_id := 0
var world: WorldBuilder
var landmarks: Landmarks
var remote := false  # im Mehrspieler: Position kommt vom Server

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _target := Vector3.ZERO
var _threat_pos := Vector3.ZERO
var _threat: Node3D = null
var _timer := 0.0
var _think := 0.0
var _attack_cd := 0.0
var _model: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _glb_root: Node3D
var _anim: AnimationPlayer
var _phase := 0.0
var _call: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _bleed := 0.0  # Lebenspunkte pro Sekunde (angeschossen)
var _blood_t := 0.0
var _levitate_t := 0.0
var _wound_count := 0
var _pupils: Array[Node3D] = []
var _x_eyes: Array[Node3D] = []
static var blood_mat: StandardMaterial3D


func setup(sp: String, w: WorldBuilder, lm: Landmarks, seed_v: int) -> void:
	species = sp
	info = SPECIES[sp]
	world = w
	landmarks = lm
	_rng.seed = seed_v
	male = sp == "legend" or _rng.randf() < 0.45
	hp = info.hp


func _ready() -> void:
	add_to_group("animal")
	collision_layer = 8
	collision_mask = 1
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.8
	var s: float = info.size
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.0, 1.5) * s
	cs.shape = box
	cs.position.y = 0.75 * s
	add_child(cs)
	_build_model()
	_call = AudioStreamPlayer3D.new()
	_call.stream = Sfx.animal_call("deer" if species in ["legend", "fox"] else species)
	_call.unit_size = 10.0
	_call.max_distance = 250.0
	add_child(_call)
	GameState.noise_made.connect(_on_noise)
	_pick_wander()
	state = State.GRAZE
	_timer = _rng.randf_range(3.0, 10.0)


# ------------------------------------------------------------------ Modell

func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(c, true, 0.012)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	_head = Node3D.new()
	_model.add_child(_head)
	var glb_path := ""
	var target_h := 1.25
	match species:
		"deer":
			glb_path = "res://assets/animals/stag.glb" if male else "res://assets/animals/deer.glb"
			target_h = 1.60 if male else 1.30
		"legend":
			glb_path = "res://assets/animals/stag.glb"
			target_h = 2.10
		"fox":
			glb_path = "res://assets/animals/fox.glb"
			target_h = 0.72
		"bear":
			glb_path = "res://assets/models/animals/grizzly_bear.glb" if ResourceLoader.exists("res://assets/models/animals/grizzly_bear.glb") else "res://assets/animals/bear.glb"
			target_h = 2.10
		"boar":
			glb_path = "res://assets/models/animals/boar.glb"
			target_h = 0.95
		"rabbit":
			glb_path = "res://assets/models/animals/rabbit.glb"
			target_h = 0.42
		"mutant_rabbit":
			glb_path = "res://assets/models/animals/mutant_rabbit.glb"
			target_h = 1.50
		"bigfoot":
			glb_path = "res://assets/models/animals/bigfoot.glb"
			target_h = 3.20
	if not glb_path.is_empty() and ResourceLoader.exists(glb_path):
		_glb_root = AssetLoader.load_model(glb_path, target_h, func() -> Node3D: return Node3D.new(), false)
		_model.add_child(_glb_root)
		_anim = AssetLoader.get_animation_player(_glb_root)
		return
	_glb_root = null
	_anim = null
	_model.scale = Vector3.ONE * info.size
	var bc: Color = info.body
	var lc: Color = info.belly
	var leg_h := 0.75
	var body_y := 1.0
	var body_len := 1.2
	match species:
		"rabbit":
			leg_h = 0.5
			body_y = 0.75
			body_len = 1.0
		"boar":
			leg_h = 0.5
			body_y = 0.85
			body_len = 1.35
		"bear":
			leg_h = 0.6
			body_y = 1.0
			body_len = 1.4
	var body := CapsuleMesh.new()
	body.radius = 0.32 if species != "bear" else 0.45
	body.height = body_len
	_part(_model, body, bc, Vector3(0, body_y, 0), Vector3(PI / 2, 0, 0))
	var belly := CapsuleMesh.new()
	belly.radius = 0.25
	belly.height = body_len * 0.8
	_part(_model, belly, lc, Vector3(0, body_y - 0.12, 0), Vector3(PI / 2, 0, 0))
	# Beine
	var leg := BoxMesh.new()
	leg.size = Vector3(0.1, leg_h, 0.1) if species == "deer" or species == "legend" else Vector3(0.16, leg_h, 0.16)
	for p in [Vector3(-0.18, 0, 0.42), Vector3(0.18, 0, 0.42), Vector3(-0.18, 0, -0.42), Vector3(0.18, 0, -0.42)]:
		var hip := Node3D.new()
		hip.position = Vector3(p.x, body_y - 0.15, p.z * body_len / 1.2)
		_model.add_child(hip)
		_part(hip, leg, bc.darkened(0.2), Vector3(0, -leg_h * 0.5, 0))
		_legs.append(hip)
	# Kopf
	_head = Node3D.new()
	var neck_up := 0.35 if species in ["deer", "legend"] else 0.0
	_head.position = Vector3(0, body_y + neck_up, body_len * 0.5 + (0.05 if neck_up > 0.0 else -0.05))
	_model.add_child(_head)
	var neck := CapsuleMesh.new()
	neck.radius = 0.13
	neck.height = 0.6
	if species in ["deer", "legend"]:
		_part(_head, neck, bc, Vector3(0, -0.15, -0.05), Vector3(0.5, 0, 0))
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.36
	var head_mesh := _part(_head, hm, bc, Vector3(0, 0.12, 0.12))
	head_mesh.scale = Vector3(0.9, 0.9, 1.4)
	var snout := SphereMesh.new()
	snout.radius = 0.09
	snout.height = 0.16
	_part(_head, snout, Color(0.15, 0.12, 0.1) if species != "boar" else Color(0.75, 0.55, 0.5), Vector3(0, 0.08, 0.38))
	var eye_white := SphereMesh.new()
	eye_white.radius = 0.068
	eye_white.height = 0.136
	var eye_pupil := SphereMesh.new()
	eye_pupil.radius = 0.036
	eye_pupil.height = 0.072
	var x_bar := BoxMesh.new()
	x_bar.size = Vector3(0.085, 0.018, 0.02)
	_pupils.clear()
	_x_eyes.clear()
	for x in [-0.13, 0.13]:
		_part(_head, eye_white, Color(1, 1, 1) if species != "mutant_rabbit" else Color(1.0, 0.125, 0.125), Vector3(x, 0.2, 0.22))
		var p_node := _part(_head, eye_pupil, Color(0.06, 0.06, 0.06), Vector3(x, 0.2, 0.265))
		_pupils.append(p_node)
		var x_holder := Node3D.new()
		x_holder.position = Vector3(x, 0.2, 0.275)
		x_holder.visible = false
		_head.add_child(x_holder)
		_part(x_holder, x_bar, Color(0.06, 0.06, 0.06), Vector3.ZERO, Vector3(0, 0, PI * 0.25))
		_part(x_holder, x_bar, Color(0.06, 0.06, 0.06), Vector3.ZERO, Vector3(0, 0, -PI * 0.25))
		_x_eyes.append(x_holder)
	var ear := BoxMesh.new()
	ear.size = Vector3(0.06, 0.22, 0.1) if species != "rabbit" else Vector3(0.07, 0.5, 0.12)
	for x in [-0.13, 0.13]:
		_part(_head, ear, bc.darkened(0.1), Vector3(x, 0.38 if species == "rabbit" else 0.3, 0.02), Vector3(0, 0, x * 3.0))
	if male and species in ["deer", "legend"]:
		var tine := BoxMesh.new()
		tine.size = Vector3(0.04, 0.45, 0.04)
		var antler_c := Color(0.85, 0.78, 0.62)
		var tines := 4 if species == "deer" else 8
		for side in [-1, 1]:
			_part(_head, tine, antler_c, Vector3(0.12 * side, 0.5, 0.0), Vector3(0, 0, -0.5 * side))
			for k in tines:
				var y := 0.45 + k * 0.12
				_part(_head, tine, antler_c, Vector3((0.22 + k * 0.05) * side, y, 0.05), Vector3(0.4, 0, -0.9 * side)).scale = Vector3(1, 0.6, 1)
	if species == "boar" and male:
		var tusk := BoxMesh.new()
		tusk.size = Vector3(0.03, 0.12, 0.03)
		for x in [-0.08, 0.08]:
			_part(_head, tusk, Color(0.95, 0.93, 0.85), Vector3(x, 0.08, 0.42), Vector3(0.6, 0, 0))
	var tail := SphereMesh.new()
	tail.radius = 0.08
	tail.height = 0.16
	_part(_model, tail, Color(1, 1, 1) if species in ["deer", "legend", "rabbit"] else bc, Vector3(0, body_y + 0.05, -body_len * 0.55))


# ------------------------------------------------------------------ KI

## Lokales Schuss- & Fluchtsystem: nur Tiere innerhalb shooter_radius um Schütze ODER impact_radius um Treffer reagieren
static func notify_gunshot(tree: SceneTree, shooter_pos: Vector3, impact_pos: Vector3, shooter_radius := 100.0, impact_radius := 100.0, shooter: Node3D = null) -> void:
	if tree == null:
		return
	for n in tree.get_nodes_in_group("animal"):
		if not (n is Animal):
			continue
		var a := n as Animal
		if a.state == State.DEAD or a.remote:
			continue
		var hear: float = float(a.info.get("hear", 1.0))
		var d_shoot := a.global_position.distance_to(shooter_pos)
		var d_impact := a.global_position.distance_to(impact_pos)
		if d_shoot > shooter_radius * hear and d_impact > impact_radius * hear:
			continue
		var threat_pt := shooter_pos if d_shoot <= d_impact else impact_pos
		if a.info.get("aggressive", false):
			a.state = State.CHARGE
			a._threat = shooter if is_instance_valid(shooter) else a._closest_player()
			a._threat_pos = shooter_pos
			a._timer = 16.0
			a._call.play()
		else:
			a.state = State.FLEE
			a._threat_pos = threat_pt
			a._threat = null
			a._timer = a._rng.randf_range(12.0, 20.0)
			a._call.play()


func _on_noise(pos: Vector3, radius: float, kind: String) -> void:
	if state == State.DEAD or remote or kind == "shot":
		return
	var d := pos.distance_to(global_position)
	var r: float = radius * info.hear
	if d > r:
		return
	if d < r * 0.4 or state == State.ALERT:
		_startle(pos, null)
	else:
		_alert(pos)


func _alert(pos: Vector3) -> void:
	if state in [State.FLEE, State.CHARGE]:
		return
	state = State.ALERT
	_threat_pos = pos
	_timer = _rng.randf_range(2.0, 4.0)
	if _rng.randf() < 0.4:
		_call.play()


func _startle(pos: Vector3, who: Node3D) -> void:
	_threat_pos = pos
	_threat = who
	if info.aggressive and pos.distance_to(global_position) < (45.0 if species == "bear" else 28.0) and _closest_player() != null:
		state = State.CHARGE
		_threat = _closest_player()
		_timer = 14.0
	else:
		state = State.FLEE
		_timer = _rng.randf_range(12.0, 20.0)
	_call.play()


func _closest_player() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for t in threats:
		if is_instance_valid(t) and t.is_in_group("player_body") and t.visible:
			var d := t.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = t
	return best


func _sees(t: Node3D) -> bool:
	var d := t.global_position.distance_to(global_position)
	var sight: float = info.sight
	if GameState.weather == "fog":
		sight *= 0.45
	elif GameState.weather == "rain":
		sight *= 0.7
	if GameState.is_night():
		sight *= 0.4
	if t is Player:
		var p := t as Player
		if p.crouched:
			sight *= 0.45
		if p.on_stand:
			sight *= 0.25
		if p.is_busy():
			sight *= 0.5
	if d > sight:
		return false
	# Tiere sehen nach vorne besser
	var to := (t.global_position - global_position).normalized()
	var fwd := global_basis.z
	if fwd.dot(to) < -0.3 and d > sight * 0.4:
		return false
	return true


func _pick_wander() -> void:
	for i in 12:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(15.0, 60.0)
		var p := Vector2(global_position.x, global_position.z) + Vector2(cos(a), sin(a)) * d
		if _good_spot(p):
			_target = Vector3(p.x, 0, p.y)
			return
	_target = global_position


func _good_spot(p: Vector2) -> bool:
	if world.border_distance(p) < 40.0:
		return false
	if world.kind_at(p.x, p.y) == "water":
		return false
	if landmarks and landmarks.near_village(p) and species != "rabbit":
		return false
	if species in ["bear", "bigfoot"] and landmarks and not landmarks.in_mountains(p):
		return false
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if remote:
		_animate(delta, velocity.length())
		return
	if _levitate_t > 0.0:
		_levitate_t -= delta
		velocity = Vector3(0.0, sin(_phase * 2.0) * 0.6 + 0.3, 0.0)
		_model.rotation.z = lerpf(_model.rotation.z, PI, 1.0 - exp(-delta * 5.0))
		move_and_slide()
		if _levitate_t <= 0.0:
			_model.rotation.z = 0.0
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	# angeschossen: blutet und hinterlässt eine Spur
	if _bleed > 0.0:
		hp -= _bleed * delta
		_blood_t -= delta
		if _blood_t <= 0.0:
			_blood_t = 0.35
			_drop_blood()
		if hp <= 0.0:
			die(global_basis.z)
			return
	_think -= delta
	_timer -= delta
	_attack_cd -= delta
	if _think <= 0.0:
		_think = 0.25
		_think_step()

	var speed := 0.0
	var goal := global_position
	match state:
		State.GRAZE, State.ALERT:
			speed = 0.0
		State.WANDER:
			speed = info.walk
			goal = _target
			if Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 2.0:
				state = State.GRAZE
				_timer = _rng.randf_range(4.0, 14.0)
		State.FLEE:
			speed = info.run
			var away := global_position - _threat_pos
			away.y = 0
			goal = global_position + away.normalized() * 10.0
		State.CHARGE:
			speed = info.run * 1.05
			if is_instance_valid(_threat):
				goal = _threat.global_position
				var d := goal.distance_to(global_position)
				if d < 2.2 and _attack_cd <= 0.0:
					_attack_cd = 1.4
					_call.play()
					if _threat.has_method("take_hit"):
						_threat.take_hit(info.damage, global_position)
					elif _threat is Player:
						var pl := _threat as Player
						GameState.damage(info.damage)
						var push := (pl.global_position - global_position)
						push.y = 0.0
						push = push.normalized() if push.length() > 0.01 else global_basis.z
						if species == "bigfoot":
							pl.knockdown(2.8, "Bigfoot wirft dich!", Vector3(push.x * 9.0, 18.0, push.z * 9.0))
						elif species == "boar":
							pl.knockdown(1.6, "Vom Wildschwein umgerannt!", Vector3(push.x * 7.5, 3.2, push.z * 7.5))
						elif species == "bear" or _rng.randf() < 0.5:
							pl.knockdown(1.6, "Umgerannt!", Vector3(push.x * 5.0, 2.5, push.z * 5.0))
				if d < 1.6:
					speed = 0.0
	var dir := goal - global_position
	dir.y = 0
	# Grenze und Wasser meiden
	var p2 := Vector2(global_position.x, global_position.z)
	if world.border_distance(p2) < 35.0:
		var inward := (world.border[0] - p2)
		var c := Vector2.ZERO
		for b in world.border:
			c += b / world.border.size()
		inward = (c - p2).normalized()
		dir = dir.normalized() + Vector3(inward.x, 0, inward.y) * 2.0
	if dir.length() > 0.1 and speed > 0.0:
		dir = dir.normalized()
		var want := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-delta * (8.0 if state != State.WANDER else 3.0)))
		var f := global_basis.z
		velocity.x = lerpf(velocity.x, f.x * speed, 1.0 - exp(-delta * 5.0))
		velocity.z = lerpf(velocity.z, f.z * speed, 1.0 - exp(-delta * 5.0))
	else:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-delta * 6.0))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-delta * 6.0))
	if state == State.ALERT:
		var to := _threat_pos - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 3.0))
	move_and_slide()
	if world:
		var gy := world.height_at(global_position.x, global_position.z)
		if global_position.y < gy:
			global_position.y = gy
			if velocity.y < 0.0:
				velocity.y = 0.0
	# Bei Wänden/Klippen wenden
	if is_on_wall() and state == State.WANDER:
		_pick_wander()
	_animate(delta, Vector2(velocity.x, velocity.z).length())


func _think_step() -> void:
	# Spieler sehen
	for t in threats:
		if not is_instance_valid(t) or not t.visible:
			continue
		if state in [State.GRAZE, State.WANDER, State.ALERT] and _sees(t):
			var d := t.global_position.distance_to(global_position)
			if state == State.ALERT or d < info.sight * 0.45:
				_startle(t.global_position, t)
			else:
				_alert(t.global_position)
			break
	match state:
		State.GRAZE:
			if _timer <= 0.0:
				_pick_wander()
				state = State.WANDER
		State.ALERT:
			if _timer <= 0.0:
				state = State.GRAZE
				_timer = _rng.randf_range(2.0, 6.0)
		State.FLEE:
			if _timer <= 0.0:
				state = State.WANDER
				_pick_wander()
		State.CHARGE:
			if _timer <= 0.0 or not is_instance_valid(_threat) or not _threat.visible:
				state = State.FLEE
				_threat_pos = _threat.global_position if is_instance_valid(_threat) else global_position
				_timer = 8.0


func _play_anim(keywords: Array[String]) -> void:
	if _anim == null:
		return
	var anims := _anim.get_animation_list()
	for kw in keywords:
		for anim_name in anims:
			if str(anim_name).to_lower().contains(kw):
				if _anim.current_animation != anim_name:
					_anim.play(anim_name, 0.2)
				return


func _animate(delta: float, speed: float) -> void:
	if speed > 0.2:
		_phase += delta * (3.0 + speed * 1.2)
	if _glb_root:
		if _anim:
			if state == State.DEAD:
				_play_anim(["death", "die"])
			elif state == State.CHARGE and _attack_cd > 0.8:
				_play_anim(["attack", "bite", "leap", "run", "gallop"])
			elif speed > 5.0:
				_play_anim(["run", "gallop", "walk"])
			elif speed > 0.2:
				_play_anim(["walk", "run"])
			elif state == State.GRAZE and _timer > 1.0:
				_play_anim(["eat", "idle"])
			else:
				_play_anim(["idle"])
		elif speed > 0.2:
			_glb_root.position.y = absf(sin(_phase)) * 0.05
		return
	var a := sin(_phase) * clampf(speed / 6.0, 0.0, 0.8)
	for i in _legs.size():
		_legs[i].rotation.x = a * (1.0 if i % 3 == 0 else -1.0)
	var head_down := 0.7 if state == State.GRAZE and _timer > 1.0 else (-0.15 if state == State.ALERT else 0.0)
	_head.rotation.x = lerpf(_head.rotation.x, head_down, 1.0 - exp(-delta * 3.0))


# ------------------------------------------------------------------ Treffer und Tod

## Treffer durch eine Kugel. Kopf und Blatt (vorne) zählen mehr.
func hit(dmg: float, point: Vector3, dir: Vector3, shooter: Node3D = null) -> void:
	if state == State.DEAD:
		return
	var local := to_local(point)
	var s: float = info.size
	var mult := 1.0
	if local.z > 0.55 * s and local.y > 1.1 * s:
		mult = 3.0  # Kopf
	elif local.z > 0.1 * s:
		mult = 1.6  # Blatt
	elif local.z < -0.4 * s:
		mult = 0.6
	hp -= dmg * mult
	_spawn_blood_spray(point, dir)
	_add_wound_spot(point)
	if hp <= 0.0:
		die(dir)
	else:
		if species == "rabbit":
			_transform_to_mutant(shooter)
		# angeschossen: verliert Blut und bricht nach einiger Zeit zusammen
		_bleed += maxf(dmg * mult * 0.12, 4.0)
		if info.get("aggressive", false):
			state = State.CHARGE
			_threat = shooter if is_instance_valid(shooter) else _closest_player()
			_threat_pos = point - dir * 30.0
			_timer = 16.0
		else:
			_startle(point - dir * 30.0, shooter)
		for i in 4:
			_drop_blood()


func _spawn_blood_spray(point: Vector3, dir: Vector3) -> void:
	if not is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = (-dir + Vector3.UP * 0.4).normalized()
	pm.spread = 42.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -12.0, 0)
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.11
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.659, 0.063, 0.063)  # #A81010
	m.roughness = 0.25
	s.material = m
	p.process_material = pm
	p.draw_pass_1 = s
	get_parent().add_child(p)
	p.global_position = point
	p.emitting = true
	get_tree().create_timer(1.1).timeout.connect(p.queue_free)


func _add_wound_spot(point: Vector3) -> void:
	if _wound_count >= 5 or _model == null:
		return
	_wound_count += 1
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.03
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = Toon.solid(Color(0.690, 0.094, 0.094), false)  # #B01818
	mi.position = _model.to_local(point)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(mi)


func levitate(seconds: float) -> void:
	if state == State.DEAD:
		return
	_levitate_t = maxf(_levitate_t, seconds)
	velocity.y = 3.5
	if is_inside_tree():
		var p := GPUParticles3D.new()
		p.amount = 18
		p.lifetime = 0.9
		p.one_shot = true
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.9
		pm.direction = Vector3.UP
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.6
		pm.gravity = Vector3.ZERO
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.12
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.314, 1.0, 0.314)  # #50FF50
		s.material = m
		p.process_material = pm
		p.draw_pass_1 = s
		add_child(p)
		p.position = Vector3(0, 0.8, 0)
		p.emitting = true
		get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _transform_to_mutant(shooter: Node3D) -> void:
	species = "mutant_rabbit"
	info = SPECIES.mutant_rabbit
	hp = info.hp
	if _model:
		_model.queue_free()
	_legs.clear()
	_build_model()
	state = State.CHARGE
	_threat = shooter if is_instance_valid(shooter) else _closest_player()
	_timer = 18.0
	_call.play()
	if is_inside_tree():
		velocity.y = 6.8  # ~2.5m Sprungattacke beim Mutieren


func _drop_blood() -> void:
	if blood_mat == null:
		blood_mat = StandardMaterial3D.new()
		blood_mat.albedo_color = Color(0.45, 0.02, 0.02)
		blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q := MeshInstance3D.new()
	var m := PlaneMesh.new()
	var r := _rng.randf_range(0.12, 0.3)
	m.size = Vector2(r, r * _rng.randf_range(0.6, 1.4))
	q.mesh = m
	q.material_override = blood_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(q)
	var p := global_position + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
	q.global_position = Vector3(p.x, world.height_at(p.x, p.z) + 0.06, p.z)
	q.rotation.y = _rng.randf() * TAU
	q.add_to_group("blood")
	get_tree().create_timer(240.0).timeout.connect(q.queue_free)


func is_dead() -> bool:
	return state == State.DEAD


func die(dir: Vector3, launch := false) -> Node3D:
	if state == State.DEAD:
		return null
	state = State.DEAD
	for p_node in _pupils:
		if is_instance_valid(p_node):
			p_node.visible = false
	for x_node in _x_eyes:
		if is_instance_valid(x_node):
			x_node.visible = true
	var c := Carcass.new()
	c.species = species
	c.male = male
	c.net_id = net_id
	c.world = world
	get_parent().add_child(c)
	c.global_transform = global_transform
	c.take_model(_model)
	var d_xz := Vector3(dir.x, 0.0, dir.z)
	d_xz = d_xz.normalized() if d_xz.length() > 0.01 else global_basis.z
	if launch:
		c.linear_velocity = d_xz * 7.5 + Vector3.UP * 12.0
		c.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
	else:
		# Realistisches Taumeln / seitliches Umkippen am Boden ohne Hochschleudern
		c.linear_velocity = d_xz * randf_range(3.0, 5.5) + Vector3.UP * randf_range(0.9, 1.6)
		c.angular_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5), randf_range(4.0, 6.5))
	match species:
		"deer", "legend": GameState.stats.deer += 1
		"boar": GameState.stats.boar += 1
		"rabbit": GameState.stats.rabbit += 1
		"bear": GameState.stats.bear += 1
	died.emit(self, c)
	queue_free()
	return c


## Gegner für das Wildschwein: getroffen werden
func take_hit(_dmg: float, _from: Vector3) -> void:
	pass
