class_name WeaponHand
extends Node3D
## Was die Spielfigur in der Hand hat: Repetierbüchse (1), Fernglas (2) oder nichts (3).
## Rechte Maustaste: zielen (Zielfernrohr / Fernglas), linke: schießen, R: nachladen, L: Taschenlampe.
## Hängt an der Kamera (Ego-Perspektive). Animationen: Waffenwechsel, Schuss mit Repetieren,
## Nachladen (Gewehr kippen, Kammer auf, Patronen rein), Rauchen, Trinken und Essen.

signal fired(from: Vector3, dir: Vector3)

const SCOPE_FOV := {base = 18.0, scope8 = 9.0}
const BINO_FOV := 14.0
const RELOAD_TIME := 2.4
const FIRE_DELAY := 1.1  # Repetieren
const RIFLE_POS := Vector3(0.24, -0.27, -0.62)
const ACTION_LEN := {smoke = 4.5, drink = 2.6, eat = 2.2}
const WEAPONS := {
	pistol = {name = "Pistole", auto = false, delay = 0.22, mag = 12, dmg = 55.0, recoil = 0.025, spread = 0.004, scope = false, zoom_fov = 54.0, reload = 1.5, bolt = false, noise = 75.0, pos = Vector3(0.22, -0.22, -0.48)},
	shotgun = {name = "Schrotflinte", auto = false, delay = 0.75, mag = 6, dmg = 145.0, recoil = 0.075, spread = 0.022, scope = false, zoom_fov = 56.0, reload = 2.1, bolt = false, noise = 100.0, pos = Vector3(0.24, -0.25, -0.56)},
	bolt_action = {name = "Jagdgewehr", auto = false, delay = 1.0, mag = 5, dmg = 160.0, recoil = 0.06, spread = 0.001, scope = false, zoom_fov = 44.0, reload = 2.2, bolt = true, noise = 100.0, pos = Vector3(0.24, -0.26, -0.60)},
	assault_rifle = {name = "AK-47", auto = true, delay = 0.11, mag = 30, dmg = 65.0, recoil = 0.028, spread = 0.005, scope = false, zoom_fov = 50.0, reload = 2.0, bolt = false, noise = 100.0, pos = Vector3(0.24, -0.25, -0.58)},
	lmg = {name = "LMG", auto = true, delay = 0.085, mag = 60, dmg = 60.0, recoil = 0.032, spread = 0.007, scope = false, zoom_fov = 52.0, reload = 2.8, bolt = false, noise = 115.0, pos = Vector3(0.25, -0.27, -0.60)},
	sniper = {name = "Scharfschützengewehr", auto = false, delay = 1.4, mag = 5, dmg = 220.0, recoil = 0.09, spread = 0.0004, scope = true, zoom_fov = 8.0, reload = 2.6, bolt = true, noise = 130.0, pos = Vector3(0.25, -0.27, -0.64)},
	bazooka = {name = "Bazooka", auto = false, delay = 1.8, mag = 1, dmg = 420.0, recoil = 0.14, spread = 0.002, scope = false, zoom_fov = 58.0, reload = 2.8, bolt = false, noise = 160.0, pos = Vector3(0.28, -0.24, -0.55)},
	plasma_blaster = {name = "Alien Plasma Blaster", auto = false, delay = 0.35, mag = 15, dmg = 45.0, recoil = 0.015, spread = 0.002, scope = false, zoom_fov = 55.0, reload = 1.6, bolt = false, noise = 55.0, pos = Vector3(0.22, -0.22, -0.48)},
}

var rig: CameraRig
var player: Node3D
var slot := "sniper"  # pistol, assault_rifle, sniper, binoculars, none
var aiming := false
var flashlight_on := false
var action := ""  # smoke, drink, eat (gerade läuft eine Animation)
var _mags := {pistol = 12, shotgun = 6, bolt_action = 5, assault_rifle = 30, lmg = 60, sniper = 5, bazooka = 1, plasma_blaster = 15}
var _action_t := 0.0
var _action_cb: Callable
var _action_done := false
var _cool := 0.0
var _reload := 0.0
var _swap := 0.0
var _shoot_lock_t := 0.35
var _last_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _require_fire_release := false


func _ready() -> void:
	_shoot_lock_t = 0.35
	_last_mouse_mode = Input.mouse_mode
	_require_fire_release = Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
var _rifle: Node3D
var _weapon_nodes := {}  # id -> Node3D
var _bolt: Node3D
var _cig: Node3D
var _bottle: Node3D
var _bottle_body: MeshInstance3D
var _food: Node3D
var _light: SpotLight3D
var _flash: OmniLight3D
var _muzzle_star: Node3D
var _flash_t := 0.0
var _sway_t := 0.0
var _kick := 0.0
var _puff: GPUParticles3D


func setup(r: CameraRig, p: Node3D) -> void:
	rig = r
	player = p
	_weapon_nodes = {
		pistol = _load_glb("res://assets/weapons/pistol.glb", Vector3.ONE * 0.075, Vector3.ZERO, WEAPONS.pistol.pos),
		shotgun = _load_asset_weapon("res://assets/models/weapons/shotgun.glb", 0.22, WEAPONS.shotgun.pos, Color(0.45, 0.27, 0.14), Color(0.18, 0.19, 0.21)),
		bolt_action = _load_asset_weapon("res://assets/models/weapons/bolt_action.glb", 0.24, WEAPONS.bolt_action.pos, Color(0.722, 0.455, 0.231), Color(0.408, 0.439, 0.478)),
		assault_rifle = _load_glb("res://assets/weapons/assault_rifle.glb", Vector3.ONE * 0.18, Vector3.ZERO, WEAPONS.assault_rifle.pos),
		lmg = _load_asset_weapon("res://assets/models/weapons/lmg.glb", 0.28, WEAPONS.lmg.pos, Color(0.369, 0.400, 0.439), Color(0.22, 0.22, 0.24)),
		sniper = _load_glb("res://assets/weapons/sniper_rifle.glb", Vector3.ONE * 0.095, Vector3(0, PI * 0.5, 0), WEAPONS.sniper.pos),
		bazooka = _load_asset_weapon("res://assets/models/weapons/bazooka.glb", 0.32, WEAPONS.bazooka.pos, Color(0.333, 0.420, 0.220), Color(0.898, 0.627, 0.125)),
		plasma_blaster = _load_asset_weapon("res://assets/models/weapons/plasma_blaster.glb", 0.24, WEAPONS.plasma_blaster.pos, Color(0.831, 0.847, 0.784), Color(0.314, 1.0, 0.314)),
	}
	_cig = _build_cigarette()
	add_child(_cig)
	_bottle = _build_bottle()
	add_child(_bottle)
	_food = Node3D.new()
	_model_box(_food, Vector3(0.12, 0.06, 0.08), Vector3.ZERO, Color(0.85, 0.65, 0.35))
	_model_box(_food, Vector3(0.11, 0.025, 0.07), Vector3(0, 0.0, 0), Color(0.75, 0.3, 0.25))
	add_child(_food)
	_puff = _make_puff()
	_puff.position = Vector3(0, -0.05, -0.25)
	add_child(_puff)
	_light = SpotLight3D.new()
	_light.spot_range = 45.0
	_light.spot_angle = 24.0
	_light.light_energy = 3.0
	_light.light_color = Color(1.0, 0.95, 0.85)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_flash = OmniLight3D.new()
	_flash.omni_range = 8.0
	_flash.light_color = Color(1.0, 0.8, 0.4)
	_flash.light_energy = 0.0
	_flash.position = Vector3(0.22, -0.1, -1.4)
	add_child(_flash)
	_muzzle_star = _make_muzzle_star()
	_muzzle_star.visible = false
	add_child(_muzzle_star)
	_update_visual()


func _model_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = Toon.solid(color, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, color: Color, along_z := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	if along_z:
		mi.rotation.x = PI / 2
	mi.material_override = Toon.solid(color, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_rifle() -> Node3D:
	var r := Node3D.new()
	var wood := Color(0.45, 0.27, 0.14)
	var metal := Color(0.16, 0.16, 0.18)
	_model_box(r, Vector3(0.07, 0.11, 0.55), Vector3(0, -0.02, 0.12), wood)  # Schaft
	_model_box(r, Vector3(0.06, 0.15, 0.22), Vector3(0, -0.06, 0.42), wood)  # Kolben
	_cyl(r, 0.018, 0.75, Vector3(0, 0.03, -0.45), metal)  # Lauf
	_model_box(r, Vector3(0.06, 0.06, 0.2), Vector3(0, 0.03, 0.0), metal)  # System
	_cyl(r, 0.028, 0.32, Vector3(0, 0.11, -0.02), metal)  # Zielfernrohr
	_cyl(r, 0.036, 0.06, Vector3(0, 0.11, -0.19), metal)
	_cyl(r, 0.034, 0.05, Vector3(0, 0.11, 0.15), metal)
	_model_box(r, Vector3(0.05, 0.06, 0.06), Vector3(0, -0.06, -0.02), metal)  # Magazin
	# Kammer mit Stängel (bewegt sich beim Repetieren)
	_bolt = Node3D.new()
	_bolt.position = Vector3(0.035, 0.03, 0.06)
	r.add_child(_bolt)
	_model_box(_bolt, Vector3(0.015, 0.015, 0.06), Vector3(0.02, 0, 0), metal)
	var knob := SphereMesh.new()
	knob.radius = 0.014
	knob.height = 0.028
	var k := MeshInstance3D.new()
	k.mesh = knob
	k.position = Vector3(0.035, -0.01, 0)
	k.material_override = Toon.solid(metal, false)
	_bolt.add_child(k)
	return r


func _build_binoculars() -> Node3D:
	var b := Node3D.new()
	for x in [-0.045, 0.045]:
		_cyl(b, 0.032, 0.14, Vector3(x, 0, 0), Color(0.18, 0.22, 0.18))
	_model_box(b, Vector3(0.05, 0.03, 0.06), Vector3(0, 0.0, 0.0), Color(0.1, 0.1, 0.1))
	return b


func _build_cigarette() -> Node3D:
	var c := Node3D.new()
	_cyl(c, 0.006, 0.07, Vector3(0, 0, -0.035), Color(0.96, 0.96, 0.94))
	_cyl(c, 0.0065, 0.02, Vector3(0, 0, 0.0), Color(0.85, 0.6, 0.3))  # Filter
	var tip := _cyl(c, 0.0066, 0.006, Vector3(0, 0, -0.072), Color(1.0, 0.35, 0.05))
	var m := tip.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.0)
	m.emission_energy_multiplier = 3.0
	c.scale = Vector3.ONE * 0.8
	return c


func _build_bottle() -> Node3D:
	var b := Node3D.new()
	b.scale = Vector3.ONE * 0.75
	_bottle_body = _cyl(b, 0.035, 0.18, Vector3.ZERO, Color(0.25, 0.45, 0.2), false)
	_cyl(b, 0.014, 0.07, Vector3(0, 0.12, 0), Color(0.25, 0.45, 0.2), false)
	_model_box(b, Vector3(0.072, 0.07, 0.01), Vector3(0, 0.0, -0.035), Color(0.95, 0.9, 0.7))  # Etikett
	return b


func _make_puff() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.7
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.4, -1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.25, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var grad := Gradient.new()
	grad.set_color(0, Color(0.9, 0.9, 0.92, 0.5))
	grad.set_color(1, Color(0.9, 0.9, 0.92, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	return p


static func is_weapon(s: String) -> bool:
	return WEAPONS.has(s)


static func has_scope(s: String) -> bool:
	return bool(WEAPONS.get(s, {}).get("scope", false))


func current_damage() -> float:
	return float(WEAPONS.get(slot, {}).get("dmg", 120.0))


func current_noise_radius() -> float:
	return float(WEAPONS.get(slot, {}).get("noise", 100.0))


func _load_asset_weapon(path: String, target_h: float, pos: Vector3, c1: Color, c2: Color) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	var model := AssetLoader.load_model(path, target_h, func() -> Node3D:
		var fb := Node3D.new()
		_model_box(fb, Vector3(0.07, 0.10, 0.55), Vector3(0, -0.02, 0.08), c1)
		_cyl(fb, 0.025, 0.75, Vector3(0, 0.04, -0.35), c2)
		return fb
	)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(model)
	add_child(holder)
	return holder


func _load_glb(path: String, scl: Vector3, rot: Vector3, pos: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	var res = load(path)
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate() as Node3D
		inst.scale = scl
		inst.rotation = rot
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(inst)
	add_child(holder)
	return holder


# ------------------------------------------------------------------ Steuerung

## Gibt eine Meldung zurück, wenn der Wechsel nicht geht
func select(s: String) -> String:
	if is_weapon(s) and not GameState.has(s):
		return "Nicht im Besitz (Waffengeschäft)"
	if s == slot:
		return ""
	if is_weapon(slot):
		_mags[slot] = GameState.loaded
	slot = s
	if is_weapon(s):
		GameState.loaded = int(_mags.get(s, WEAPONS[s].mag))
		GameState.inventory_changed.emit()
	aiming = false
	_reload = 0.0
	_swap = 1.0
	_update_visual()
	Sfx.play_3d(player, Sfx.click(), -12.0, 0.8)
	return ""


func toggle_flashlight() -> void:
	if not GameState.has("flashlight"):
		return
	flashlight_on = not flashlight_on
	_light.visible = flashlight_on
	Sfx.play_3d(player, Sfx.click(), -10.0)


func _update_visual() -> void:
	var fp := rig.first_person
	var busy := action != ""
	for wid in _weapon_nodes:
		var n: Node3D = _weapon_nodes[wid]
		n.visible = slot == wid and fp and not (aiming and has_scope(wid)) and not busy
	_cig.visible = fp and action == "smoke"
	_bottle.visible = fp and action == "drink"
	_food.visible = fp and action == "eat"


func reloading() -> bool:
	return _reload > 0.0


func try_reload() -> void:
	if not is_weapon(slot) or _reload > 0.0 or action != "" or not GameState.has("ammo"):
		return
	var cap: int = WEAPONS[slot].mag
	if GameState.loaded >= cap:
		return
	_reload = float(WEAPONS[slot].reload)
	aiming = false
	Sfx.play_3d(player, Sfx.reload_sound(), -4.0)
	get_tree().create_timer(1.0).timeout.connect(_rack_sound)


## Rauchen, Trinken, Essen: Animation abspielen, Wirkung (cb) zur Hälfte
func play_action(kind: String, cb: Callable) -> bool:
	if action != "" or _reload > 0.0:
		return false
	action = kind
	_action_t = 0.0
	_action_cb = cb
	_action_done = false
	aiming = false
	if kind == "drink":
		var colors := {beer = Color(0.35, 0.22, 0.08), schnaps = Color(0.85, 0.9, 0.92), moonshine = Color(0.9, 0.95, 0.97)}
		(_bottle_body.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.45, 0.2)
		for k in colors:
			if GameState.has(k):
				(_bottle_body.material_override as StandardMaterial3D).albedo_color = colors[k]
				break
	_update_visual()
	return true


## Zielwackeln: ruhiger bei Zigarette, Hocken, Hochstand; stärker bei Alkohol und nach dem Rennen
func sway_amount(crouched: bool, on_stand: bool) -> float:
	var s := 0.010
	if crouched:
		s *= 0.55
	if on_stand:
		s *= 0.45
	if GameState.smoke_time > 0.0:
		s *= 0.4
	s *= 1.0 + GameState.drunkness() * 3.0
	return s


## Kurve 0 -> 1 -> 0 für "zum Mund führen"
static func _raise(t: float, up: float, hold: float, down: float) -> float:
	if t < up:
		return smoothstep(0.0, 1.0, t / up)
	if t < up + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - up - hold) / down)


func lock_shoot(dur := 0.22) -> void:
	_shoot_lock_t = maxf(_shoot_lock_t, dur)


func process_hand(delta: float, input_on: bool, crouched: bool, on_stand: bool) -> void:
	_cool = maxf(0.0, _cool - delta)
	_shoot_lock_t = maxf(0.0, _shoot_lock_t - delta)
	var cur_mm := Input.mouse_mode
	if cur_mm == Input.MOUSE_MODE_CAPTURED and _last_mouse_mode != Input.MOUSE_MODE_CAPTURED:
		lock_shoot(0.25)
		_require_fire_release = true
	_last_mouse_mode = cur_mm
	if _require_fire_release and not Input.is_action_pressed("fire") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_require_fire_release = false
	_flash_t = maxf(0.0, _flash_t - delta)
	_flash.light_energy = _flash_t * 40.0
	if _muzzle_star:
		_muzzle_star.visible = _flash_t > 0.0 and rig.first_person and not (aiming and has_scope(slot))
		if _muzzle_star.visible:
			_muzzle_star.position = Vector3(0.22, -0.15, -1.05)
			_muzzle_star.rotation.z += delta * 24.0
	_swap = move_toward(_swap, 0.0, delta * 3.0)
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0:
			var cap: int = int(WEAPONS.get(slot, {}).get("mag", GameState.MAG_SIZE))
			var need := cap - GameState.loaded
			var have := mini(need, GameState.count("ammo"))
			GameState.take("ammo", have)
			GameState.loaded += have
			if is_weapon(slot):
				_mags[slot] = GameState.loaded
			GameState.inventory_changed.emit()
	_process_action(delta)
	var want_aim := input_on and Input.is_action_pressed("aim") and slot != "none" and _reload <= 0.0 and action == ""
	if want_aim != aiming:
		aiming = want_aim
	var fov := rig.base_fov
	if aiming:
		if slot == "sniper" and GameState.has("scope8"):
			fov = SCOPE_FOV.scope8
		elif is_weapon(slot):
			fov = float(WEAPONS[slot].zoom_fov)
	rig.fov_target = fov
	_update_visual()
	# Waffe bewegt sich
	_sway_t += delta
	var sw := sway_amount(crouched, on_stand)
	_kick = move_toward(_kick, 0.0, delta * 3.0)
	var swap_off := Vector3(0, -0.35, 0.1) * _swap
	if is_weapon(slot) and _weapon_nodes.has(slot):
		var wn: Node3D = _weapon_nodes[slot]
		if wn.visible:
			var w: Dictionary = WEAPONS[slot]
			var bob := Vector3(sin(_sway_t * 1.3) * sw * 2.0, sin(_sway_t * 2.1) * sw * 1.5, _kick * 0.12)
			var rot := Vector3(_kick * 0.25, 0, 0)
			var pos: Vector3 = w.pos + bob + swap_off
			var bolt_back := 0.0
			var rlen := float(w.reload)
			if _reload > 0.0:
				var t := rlen - _reload
				var tilt := _raise(t, 0.3, rlen - 0.7, 0.4)
				pos += Vector3(-0.08, -0.06, 0.12) * tilt
				rot += Vector3(0.25, 0.35, 0.75) * tilt
				if slot == "rifle" and t > 0.4 and t < rlen - 0.5:
					bolt_back = 1.0
					pos.y += sin(t * 14.0) * 0.006 * tilt
			elif slot == "rifle" and _cool > float(w.delay) - 0.75:
				var c := float(w.delay) - _cool
				bolt_back = _raise(c - 0.35, 0.12, 0.08, 0.15) if c > 0.35 else 0.0
				rot.z += bolt_back * 0.15
			if slot == "rifle":
				_bolt.position = Vector3(0.035, 0.03, 0.06 + bolt_back * 0.08)
				_bolt.rotation.z = -bolt_back * 1.2
			wn.position = pos
			wn.rotation = rot
	var want_fire := false
	if input_on and not _is_ui_busy() and _shoot_lock_t <= 0.0 and not _require_fire_release and is_weapon(slot) and action == "" and _swap < 0.2:
		want_fire = Input.is_action_pressed("fire") if bool(WEAPONS[slot].auto) else Input.is_action_just_pressed("fire")
	if want_fire:
		_fire()


func _process_action(delta: float) -> void:
	if action == "":
		return
	_action_t += delta
	var len: float = ACTION_LEN[action]
	var t := _action_t
	match action:
		"smoke":
			# zweimal ziehen
			var k := maxf(_raise(t, 0.5, 0.8, 0.5), _raise(t - 2.3, 0.4, 0.7, 0.5) if t > 2.3 else 0.0)
			_cig.position = Vector3(0.16, -0.24, -0.38).lerp(Vector3(0.04, -0.075, -0.2), k)
			_cig.rotation = Vector3(-0.25, 0.7 - k * 0.2, 0)
			if (t > 1.55 and t - delta <= 1.55) or (t > 3.45 and t - delta <= 3.45):
				_puff.restart()
				_puff.emitting = true
		"drink":
			var k := _raise(t, 0.6, 1.3, 0.6)
			_bottle.position = Vector3(0.18, -0.32, -0.45).lerp(Vector3(0.03, -0.17, -0.3), k)
			_bottle.rotation = Vector3(-1.6 * k, 0, 0.15)
			if t > 1.0 and t - delta <= 1.0:
				Sfx.play_3d(player, Sfx.gulp(), -4.0)
		"eat":
			var k := _raise(t, 0.5, 1.1, 0.5)
			_food.position = Vector3(0.12, -0.28, -0.35).lerp(Vector3(0.0, -0.1, -0.16), k)
			_food.rotation = Vector3(0, 0.5, 0)
	if not _action_done and t >= len * 0.5:
		_action_done = true
		if _action_cb.is_valid():
			_action_cb.call()
	if t >= len:
		action = ""


func _is_ui_busy() -> bool:
	if get_tree().paused:
		return true
	var game_node := get_tree().current_scene
	if game_node == null:
		return false
	if not str(game_node.get("_placing")).is_empty():
		return true
	var hud_node = game_node.get("hud")
	return hud_node != null and bool(hud_node.menus_open())


func _fire() -> void:
	if _cool > 0.0 or _reload > 0.0 or _shoot_lock_t > 0.0 or _require_fire_release or _is_ui_busy() or not is_weapon(slot):
		return
	if GameState.loaded <= 0:
		Sfx.play_3d(player, Sfx.click(), -2.0, 0.6)
		if GameState.has("ammo"):
			try_reload()
		return
	var w: Dictionary = WEAPONS[slot]
	GameState.loaded -= 1
	_mags[slot] = GameState.loaded
	GameState.inventory_changed.emit()
	_cool = float(w.delay)
	_flash_t = 0.06
	_kick = 1.0
	var ray := rig.aim_ray()
	var spread := float(w.spread) * (0.35 if aiming else 1.5)
	var dir: Vector3 = (ray[1] + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread).normalized()
	rig.add_recoil(float(w.recoil) * (1.2 if aiming else 0.9))
	rig.shake(0.35 if slot == "assault_rifle" else 0.6)
	var pitch := 1.15 if slot == "pistol" else (1.05 if slot in ["assault_rifle", "lmg"] else (0.92 if slot == "sniper" else randf_range(0.95, 1.05)))
	Sfx.play_3d_distance(player, Sfx.gunshot_weapon(slot), Sfx.gunshot_distant(), 4.0, pitch)
	GameState.make_noise(player.global_position, 900.0, "shot")
	fired.emit(ray[0], dir)
	if bool(w.bolt):
		get_tree().create_timer(0.45).timeout.connect(_rack_sound)


func _rack_sound() -> void:
	if is_instance_valid(player):
		Sfx.play_3d(player, Sfx.reload_sound(), -10.0, 1.3)


func _make_muzzle_star() -> Node3D:
	var n := Node3D.new()
	var m_outer := StandardMaterial3D.new()
	m_outer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_outer.albedo_color = Color(1.0, 0.467, 0.067)  # #FF7711
	m_outer.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m_inner := StandardMaterial3D.new()
	m_inner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_inner.albedo_color = Color(1.0, 0.878, 0.333)  # #FFE055
	m_inner.cull_mode = BaseMaterial3D.CULL_DISABLED
	for rot_z in [0.0, PI * 0.25, PI * 0.5, PI * 0.75]:
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.28)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.rotation.z = rot_z
		mi.material_override = m_outer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	var core := SphereMesh.new()
	core.radius = 0.045
	core.height = 0.09
	var cmi := MeshInstance3D.new()
	cmi.mesh = core
	cmi.material_override = m_inner
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cmi)
	return n
