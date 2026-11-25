class_name CharacterModel
extends Node3D
## Figur aus einfachen Formen (schaut nach +Z). Wird für Spieler, Mitspieler und NPCs verwendet.
## Leicht übertriebene Proportionen und große Augen für den witzigen Look.

var outfit := {}
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var head: Node3D
var body_mesh: MeshInstance3D
var _phase := 0.0
var _lying := 0.0
var _target_lying := 0.0
var render_layer := 1
var expression := "neutral"  # neutral, happy, angry, drunk, surprised, pain, focus
var _brows: Array[MeshInstance3D] = []
var _mouth: Array[MeshInstance3D] = []  # links, Mitte, rechts
var _eyes: Array[MeshInstance3D] = []
var _cheeks: Array[MeshInstance3D] = []
var _nose: MeshInstance3D
var _soot := 0.0
var _glb_root: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_bone_idx := -1
var _aiming_glb := false
var hand_anchor: Node3D
var _held_node: Node3D
var _held_slot := ""
## Kleidung am 3D-Modell: folgt Kopf- und Rumpfknochen (relativ zur Ruhelage)
var _acc := {}  # Knochenname -> [Anker-Node, Knochenindex, Ruhelage (Modellraum)]
const PALETTE_SHADER := preload("res://scripts/player/char_palette.gdshader")


const REDNECK_PRESETS := {
	"overalls": {
		shirt = Color(0.910, 0.706, 0.604), pants = Color(0.290, 0.439, 0.722),
		skin = Color(0.910, 0.706, 0.604), hat = "floppy", hat_color = Color(0.420, 0.306, 0.208),
		gut_belly = 0.55, forehead = 0.45,
	},
	"mullet": {
		shirt = Color(0.941, 0.941, 0.925), pants = Color(0.290, 0.349, 0.204),
		skin = Color(0.94, 0.76, 0.62), hat = "none", hat_color = Color(0.133, 0.110, 0.094),
		gut_belly = 0.65, forehead = 0.60,
	},
	"female": {
		shirt = Color(0.471, 0.722, 0.847), pants = Color(0.306, 0.369, 0.220),
		skin = Color(0.96, 0.79, 0.66), hat = "cap", hat_color = Color(0.784, 0.157, 0.157),
		gut_belly = 0.20, forehead = 0.40,
	},
	"blue_tank": {
		shirt = Color(0.431, 0.557, 0.659), pants = Color(0.165, 0.235, 0.345),
		skin = Color(0.94, 0.76, 0.62), hat = "none", hat_color = Color(0.22, 0.30, 0.18),
		gut_belly = 0.40, forehead = 0.50,
	},
}

func _init(o := {}, layer := 1) -> void:
	outfit = {
		shirt = Color(0.35, 0.42, 0.25), pants = Color(0.30, 0.26, 0.20), skin = Color(0.98, 0.80, 0.66),
		hat = "cap", hat_color = Color(0.22, 0.30, 0.18), jacket = false, uniform = false,
		gut_belly = 0.35, forehead = 0.50,
	}
	outfit.merge(o, true)
	render_layer = layer


func _ready() -> void:
	process_priority = 10
	_build()


func _process(_delta: float) -> void:
	if _glb_root and _skeleton and is_inside_tree():
		_update_acc()
	if _glb_root and _skeleton and _hand_bone_idx >= 0 and is_inside_tree():
		if _aiming_glb:
			var rest_q := _skeleton.get_bone_rest(_hand_bone_idx).basis.get_rotation_quaternion()
			_skeleton.set_bone_pose_rotation(_hand_bone_idx, rest_q * Quaternion(Vector3.RIGHT, -PI * 0.45))
		var xf := global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone_idx)
		hand_anchor.position = xf.origin + (Vector3(0, 0.18, 0.18) if _aiming_glb else Vector3.ZERO)
		hand_anchor.basis = Basis.IDENTITY if _aiming_glb else Basis(Vector3.RIGHT, deg_to_rad(40))


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, outline := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(color, outline, 0.015)
	mi.position = pos
	mi.layers = render_layer
	parent.add_child(mi)
	return mi


func _build() -> void:
	if not outfit.get("uniform", false) and ResourceLoader.exists("res://assets/models/characters/redneck_player.glb"):
		var glb_wrap := AssetLoader.load_model("res://assets/models/characters/redneck_player.glb", 1.8, func() -> Node3D: return Node3D.new(), false, render_layer)
		_glb_root = glb_wrap
		add_child(_glb_root)
		_anim = AssetLoader.get_animation_player(_glb_root)
		hand_anchor = Node3D.new()
		hand_anchor.name = "HandAnchor"
		_glb_root.add_child(hand_anchor)
		return
	var gender_str := str(outfit.get("gender", ""))
	if outfit.get("use_glb", false) and gender_str in ["male", "female"] and not outfit.get("uniform", false):
		var path := "res://assets/characters/female.glb" if gender_str == "female" else "res://assets/characters/male.glb"
		var scene := load(path) as PackedScene
		if scene:
			_build_glb(scene)
			return
	var shirt: Color = outfit.shirt
	var skin: Color = outfit.skin
	# Spielerfigur mit Kleiderschrank (Outfit): Hüte, Brillen, Bärte, Jacken kommen aus Outfit
	var dressed: bool = outfit.has("top") and not outfit.get("uniform", false)
	var o: Dictionary = Outfit.normalize(outfit) if dressed else {}
	if outfit.uniform:
		shirt = Color(0.20, 0.30, 0.50)
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 0.95
	body_mesh = _part(self, body, shirt, Vector3(0, 1.15, 0))
	var gut := float(outfit.get("gut_belly", 0.35))
	body_mesh.scale = Vector3(1.0 + gut * 0.28, 1.0, 1.0 + gut * 0.48)
	body_mesh.position.z = gut * 0.05
	if not dressed and str(outfit.get("preset", "")) == "overalls":
		var bib := BoxMesh.new()
		bib.size = Vector3(0.40, 0.46, 0.14)
		_part(self, bib, outfit.pants, Vector3(0, 1.05, 0.20 + gut * 0.09))
		var strap := BoxMesh.new()
		strap.size = Vector3(0.08, 0.38, 0.08)
		_part(self, strap, outfit.pants, Vector3(-0.14, 1.38, 0.18 + gut * 0.05))
	if outfit.jacket and not dressed:
		var jk := CapsuleMesh.new()
		jk.radius = 0.32
		jk.height = 0.8
		_part(self, jk, Color(0.45, 0.30, 0.18), Vector3(0, 1.2, 0))
	if outfit.uniform:
		var vest := BoxMesh.new()
		vest.size = Vector3(0.5, 0.45, 0.06)
		_part(self, vest, Color(0.95, 0.85, 0.15), Vector3(0, 1.25, 0.28), false)

	head = Node3D.new()
	head.position = Vector3(0, 1.82, 0)
	add_child(head)
	var hm := SphereMesh.new()
	hm.radius = 0.28
	hm.height = 0.54
	_part(head, hm, skin, Vector3.ZERO)
	var fh := float(outfit.get("forehead", 0.50))
	head.scale = Vector3(1.12, 1.06 + fh * 0.24, 1.12)  # etwas größerer Kopf + Forehead-Slider
	var nose := SphereMesh.new()
	nose.radius = 0.075
	nose.height = 0.14
	_nose = _part(head, nose, skin.darkened(0.12), Vector3(0, -0.04, 0.27), false)
	_nose.material_override = _nose.material_override.duplicate()
	var cheek := SphereMesh.new()
	cheek.radius = 0.06
	cheek.height = 0.03
	for x in [-0.17, 0.17]:
		var ch := _part(head, cheek, Color(0.95, 0.35, 0.35), Vector3(x, -0.06, 0.21), false)
		ch.rotation.x = PI / 2
		ch.visible = false
		_cheeks.append(ch)
	var brow := BoxMesh.new()
	brow.size = Vector3(0.11, 0.025, 0.03)
	for x in [-0.1, 0.1]:
		_brows.append(_part(head, brow, Color(0.25, 0.18, 0.12), Vector3(x, 0.17, 0.25), false))
	var mpart := BoxMesh.new()
	mpart.size = Vector3(0.06, 0.022, 0.03)
	for x in [-0.055, 0.0, 0.055]:
		_mouth.append(_part(head, mpart, Color(0.35, 0.1, 0.1), Vector3(x, -0.17, 0.235), false))
	var eye := SphereMesh.new()
	eye.radius = 0.06
	eye.height = 0.12
	var pupil := SphereMesh.new()
	pupil.radius = 0.03
	pupil.height = 0.06
	for x in [-0.1, 0.1]:
		_eyes.append(_part(head, eye, Color(1, 1, 1), Vector3(x, 0.06, 0.22), false))
		_part(head, pupil, Color(0.06, 0.06, 0.08), Vector3(x, 0.06, 0.28), false)
	if not dressed:
		var moustache := BoxMesh.new()
		moustache.size = Vector3(0.2, 0.04, 0.04)
		_part(head, moustache, Color(0.35, 0.25, 0.15), Vector3(0, -0.12, 0.25), false)

	var hc: Color = outfit.hat_color
	if not dressed and outfit.get("glasses", false) is bool and outfit.get("glasses", false):
		var sh := BoxMesh.new()
		sh.size = Vector3(0.30, 0.07, 0.06)
		_part(head, sh, Color(0.078, 0.078, 0.078), Vector3(0, 0.06, 0.27))  # #141414 Sunglasses
	match "" if dressed else str(outfit.hat):
		"floppy":
			var fbrim := CylinderMesh.new()
			fbrim.top_radius = 0.45
			fbrim.bottom_radius = 0.48
			fbrim.height = 0.04
			_part(head, fbrim, hc, Vector3(0, 0.21, 0))
			var fcrown := CylinderMesh.new()
			fcrown.top_radius = 0.19
			fcrown.bottom_radius = 0.26
			fcrown.height = 0.22
			_part(head, fcrown, hc.darkened(0.08), Vector3(0, 0.33, 0))
		"cap":
			var cap := CylinderMesh.new()
			cap.top_radius = 0.25
			cap.bottom_radius = 0.30
			cap.height = 0.16
			_part(head, cap, hc, Vector3(0, 0.22, 0))
			var brim := BoxMesh.new()
			brim.size = Vector3(0.36, 0.04, 0.22)
			_part(head, brim, hc.darkened(0.15), Vector3(0, 0.16, 0.3))
		"hunter", "hunter_gams":
			# Steirer- bzw. Jägerhut mit Hutband und Gamsbart
			var brim := CylinderMesh.new()
			brim.top_radius = 0.42
			brim.bottom_radius = 0.42
			brim.height = 0.04
			_part(head, brim, Color(0.24, 0.30, 0.20), Vector3(0, 0.2, 0))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.17
			crown.bottom_radius = 0.25
			crown.height = 0.26
			_part(head, crown, Color(0.26, 0.33, 0.22), Vector3(0, 0.34, 0))
			var band := CylinderMesh.new()
			band.top_radius = 0.235
			band.bottom_radius = 0.25
			band.height = 0.06
			_part(head, band, Color(0.35, 0.22, 0.12), Vector3(0, 0.25, 0), false)
			var feather := BoxMesh.new()
			feather.size = Vector3(0.03, 0.32, 0.06)
			var f := _part(head, feather, Color(0.18, 0.40, 0.20), Vector3(-0.22, 0.42, -0.05), false)
			f.rotation.z = 0.4
			if outfit.hat == "hunter_gams":
				var gams := SphereMesh.new()
				gams.radius = 0.09
				gams.height = 0.3
				var g := _part(head, gams, Color(0.42, 0.36, 0.30), Vector3(0.0, 0.52, -0.2), false)
				g.rotation.x = -0.3
		"police":
			var pc := CylinderMesh.new()
			pc.top_radius = 0.3
			pc.bottom_radius = 0.27
			pc.height = 0.14
			_part(head, pc, Color(0.12, 0.16, 0.28), Vector3(0, 0.24, 0))
			var pb := BoxMesh.new()
			pb.size = Vector3(0.34, 0.03, 0.2)
			_part(head, pb, Color(0.05, 0.05, 0.08), Vector3(0, 0.17, 0.28))

	if dressed:
		_dress_primitive(o, gut)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.18, 0.72, 0.2)
	var shoe := BoxMesh.new()
	shoe.size = Vector3(0.2, 0.12, 0.3)
	var pants: Color = Color(0.15, 0.18, 0.28) if outfit.uniform else (Outfit.pants_color(o) if dressed else outfit.pants)
	var shoe_c: Color = o.shoes if dressed else Color(0.22, 0.16, 0.12)
	for x in [-0.14, 0.14]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.78, 0)
		add_child(hip)
		_part(hip, leg, pants, Vector3(0, -0.36, 0))
		_part(hip, shoe, shoe_c, Vector3(0, -0.72, 0.05))
		legs.append(hip)

	var arm := BoxMesh.new()
	arm.size = Vector3(0.14, 0.62, 0.16)
	var hand := SphereMesh.new()
	hand.radius = 0.09
	hand.height = 0.18
	for x in [-0.38, 0.38]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(x, 1.5, 0)
		add_child(shoulder)
		var sleeve = Outfit.sleeve_color(o) if dressed else null
		var arm_c: Color = sleeve if sleeve != null else (shirt if not outfit.jacket or dressed else Color(0.45, 0.30, 0.18))
		_part(shoulder, arm, arm_c, Vector3(0, -0.3, 0))
		_part(shoulder, hand, skin, Vector3(0, -0.64, 0))
		arms.append(shoulder)
	if arms.size() >= 2:
		hand_anchor = Node3D.new()
		hand_anchor.position = Vector3(0, -0.64, 0.06)
		arms[1].add_child(hand_anchor)


## Kleidung auf Simons Figur: Kopfteile sitzen im (skalierten) Kopf, Rumpfteile werden auf den
## Rumpf (Kapsel, Bauch-Regler) gestreckt. Outfit rechnet in Maßen eines 0,54-m-Kopfes und eines
## 0,34 x 0,30 m großen Rumpfes, daher die Umrechnung.
func _dress_primitive(o: Dictionary, gut: float) -> void:
	var hh := Node3D.new()
	hh.name = "Kleidung_Kopf"
	hh.position = Vector3(0, -0.275, -0.02)
	head.add_child(hh)
	Outfit.build_head(hh, o, false, render_layer, Outfit.SPHERE_FIT)
	var bh := Node3D.new()
	bh.name = "Kleidung_Rumpf"
	var sx := 1.78 * (1.0 + gut * 0.28)
	var sz := 1.78 * (1.0 + gut * 0.48)
	bh.scale = Vector3(sx, 3.15, sz)
	bh.position = Vector3(0, 0.675, gut * 0.05 - 0.02 * sz)
	add_child(bh)
	Outfit.build_body(bh, o, false, render_layer)


func _build_glb(scene: PackedScene) -> void:
	_glb_root = scene.instantiate() as Node3D
	add_child(_glb_root)
	var min_y := INF
	var max_y := -INF
	for mi in _glb_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		mesh_inst.layers = render_layer
		if mesh_inst.mesh:
			var a := mesh_inst.mesh.get_aabb()
			var xf := _glb_root.global_transform.affine_inverse() * mesh_inst.global_transform
			for corner_i in 8:
				var c := xf * a.get_endpoint(corner_i)
				min_y = minf(min_y, c.y)
				max_y = maxf(max_y, c.y)
	var h := max_y - min_y
	if h > 0.001 and is_finite(h):
		var s := 1.82 / h
		_glb_root.scale = Vector3.ONE * s
		_glb_root.position.y = -min_y * s - 0.38
	for ap in _glb_root.find_children("*", "AnimationPlayer", true, false):
		_anim = ap as AnimationPlayer
		break
	for sk in _glb_root.find_children("*", "Skeleton3D", true, false):
		var s3 := sk as Skeleton3D
		var idx := s3.find_bone("Hand.R")
		if idx >= 0:
			_skeleton = s3
			_hand_bone_idx = idx
			hand_anchor = Node3D.new()
			add_child(hand_anchor)
			break
	head = Node3D.new()
	head.position = Vector3(0, 1.08, 0)
	add_child(head)
	_dress_glb()


## Farben (Haut, Oberteil, Hose, Haare, Schuhe) und Kleidungsteile für das 3D-Modell
func _dress_glb() -> void:
	var o := Outfit.normalize(outfit)
	var female := str(o.get("gender", "male")) == "female"
	for mi in _glb_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.name != "Cube_003" or mesh_inst.mesh == null:
			continue
		var old := mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D
		var m := ShaderMaterial.new()
		m.shader = PALETTE_SHADER
		if old and old.albedo_texture:
			m.set_shader_parameter("atlas", old.albedo_texture)
		m.set_shader_parameter("col_skin", o.skin)
		m.set_shader_parameter("col_shirt", o.shirt)
		m.set_shader_parameter("col_pants", Color(0.42, 0.28, 0.16) if o.legs == "lederhose" else (Color(0.3, 0.3, 0.28) if o.legs == "work_pants" else o.pants))
		m.set_shader_parameter("col_hair", o.hair_color)
		m.set_shader_parameter("col_shoes", o.shoes)
		m.set_shader_parameter("cell_hair", 7 if female else -1)
		m.set_shader_parameter("cell_shoes", 1)
		# Hose: unterer Teil des Rumpfes (Höhe im Modellraum -> Meshraum)
		var to_mesh := (global_transform.affine_inverse() * mesh_inst.global_transform).affine_inverse() if is_inside_tree() else (_glb_root.transform * _rel_xf(mesh_inst)).affine_inverse()
		m.set_shader_parameter("pants_y", (to_mesh * Vector3(0, 0.5 if female else 0.58, 0)).y)
		mesh_inst.material_override = m
	if _skeleton == null:
		return
	for bone in ["Head", "Body"]:
		var idx := _skeleton.find_bone(bone)
		if idx < 0:
			continue
		var anchor := Node3D.new()
		anchor.name = "Kleidung_" + bone
		add_child(anchor)
		var holder := Node3D.new()
		anchor.add_child(holder)
		if bone == "Head":
			Outfit.build_head(holder, o, female, render_layer)
		else:
			Outfit.build_body(holder, o, female, render_layer)
		var rest := _bone_model_xf(_skeleton.get_bone_global_rest(idx))
		_acc[bone] = [anchor, idx, rest]
	_update_acc()


## Transform eines Knotens relativ zum GLB-Wurzelknoten (vor dem Einfügen in den Baum)
func _rel_xf(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != _glb_root:
		xf = (cur as Node3D).transform * xf if cur is Node3D else xf
		cur = cur.get_parent()
	return xf


## Knochen-Transform (Skelettraum) -> Modellraum dieser Figur
func _bone_model_xf(pose: Transform3D) -> Transform3D:
	return _glb_root.transform * _rel_xf(_skeleton) * pose


func _update_acc() -> void:
	for bone in _acc:
		var e: Array = _acc[bone]
		var cur := _bone_model_xf(_skeleton.get_bone_global_pose(e[1]))
		var rest: Transform3D = e[2]
		(e[0] as Node3D).transform = Transform3D((cur.basis * rest.basis.inverse()).orthonormalized(), cur.origin)


## Hält ein Item/eine Waffe direkt an der rechten Hand (3rd-Person, NPCs, Mitspieler)
func set_held_item(slot: String) -> void:
	if slot == _held_slot or hand_anchor == null:
		return
	_held_slot = slot
	if is_instance_valid(_held_node):
		_held_node.queue_free()
		_held_node = null
	if slot == "" or slot == "none":
		return
	var root := Node3D.new()
	hand_anchor.add_child(root)
	_held_node = root
	var glb_map := {
		"pistol": ["res://assets/weapons/pistol.glb", 0.055, Vector3(0, PI, 0)],
		"assault_rifle": ["res://assets/weapons/assault_rifle.glb", 0.14, Vector3(0, PI, 0)],
		"sniper": ["res://assets/weapons/sniper_rifle.glb", 0.075, Vector3(0, -PI * 0.5, 0)],
	}
	if glb_map.has(slot):
		var cfg: Array = glb_map[slot]
		var sc := load(cfg[0]) as PackedScene
		if sc:
			var inst := sc.instantiate() as Node3D
			inst.scale = Vector3.ONE * float(cfg[1])
			inst.rotation = cfg[2]
			inst.position = Vector3(0, 0.02, 0.06)
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).layers = render_layer
			root.add_child(inst)
			return
	var mesh := BoxMesh.new()
	var col := Color(0.25, 0.25, 0.28)
	if slot in ["beer", "moonshine"]:
		mesh.size = Vector3(0.08, 0.22, 0.08)
		col = Color(0.25, 0.45, 0.18) if slot == "beer" else Color(0.85, 0.85, 0.75)
	else:
		mesh.size = Vector3(0.10, 0.08, 0.18)
		col = Color(0.18, 0.20, 0.22)
	_part(root, mesh, col, Vector3(0, 0, 0.12), false)


## speed in m/s; aiming hebt die Arme
func animate(delta: float, speed: float, on_floor := true, aiming := false, sitting := false, to_mouth := false, reloading := false) -> float:
	if _glb_root:
		var step_sign := 0.0
		if speed > 0.3 and on_floor and not sitting:
			var before := sin(_phase)
			_phase += delta * (4.0 + speed * 1.3)
			if signf(before) != signf(sin(_phase)):
				step_sign = 1.0
		if _anim:
			var want := "Armature|Idle"
			if not on_floor:
				want = "Armature|Jump"
			elif speed > 5.0:
				want = "Armature|Sprint"
			elif speed > 0.3:
				want = "Armature|Walk"
			if _anim.has_animation(want) and _anim.current_animation != want:
				_anim.play(want, 0.15)
		_lying = lerpf(_lying, _target_lying, 1.0 - exp(-delta * 4.0))
		rotation.x = -_lying * PI * 0.5
		position.y = _lying * 0.3
		_aiming_glb = aiming
		return step_sign
	var swing := 0.0
	var step_sign := 0.0
	if sitting:
		for l in legs:
			l.rotation.x = lerpf(l.rotation.x, -1.5, 0.3)
		for a in arms:
			a.rotation.x = lerpf(a.rotation.x, -0.6, 0.3)
		_update_face(delta)
		return 0.0
	if on_floor and speed > 0.3:
		var before := sin(_phase)
		_phase += delta * (4.0 + speed * 1.3)
		swing = sin(_phase) * clampf(speed / 6.0, 0.25, 0.9)
		if signf(before) != signf(sin(_phase)):
			step_sign = 1.0
	elif not on_floor:
		swing = 0.5
	else:
		_phase = 0.0
	legs[0].rotation.x = lerpf(legs[0].rotation.x, swing, 0.3)
	legs[1].rotation.x = lerpf(legs[1].rotation.x, -swing, 0.3)
	if to_mouth:
		# rechte Hand zum Mund (Rauchen, Trinken, Essen)
		arms[1].rotation.x = lerpf(arms[1].rotation.x, -2.4, 0.15)
		arms[1].rotation.z = lerpf(arms[1].rotation.z, 0.5, 0.15)
		arms[0].rotation.x = lerpf(arms[0].rotation.x, -swing * 0.8, 0.3)
	elif reloading:
		arms[0].rotation.x = lerpf(arms[0].rotation.x, -0.9 + sin(Time.get_ticks_msec() * 0.012) * 0.25, 0.3)
		arms[1].rotation.x = lerpf(arms[1].rotation.x, -1.1, 0.3)
	elif aiming:
		arms[0].rotation.x = lerpf(arms[0].rotation.x, -1.45, 0.3)
		arms[1].rotation.x = lerpf(arms[1].rotation.x, -1.3, 0.3)
	else:
		arms[0].rotation.x = lerpf(arms[0].rotation.x, -swing * 0.8, 0.3)
		arms[1].rotation.x = lerpf(arms[1].rotation.x, swing * 0.8, 0.3)
	if not to_mouth:
		arms[1].rotation.z = lerpf(arms[1].rotation.z, 0.0, 0.2)
	_update_face(delta)
	var bob := absf(sin(_phase)) * 0.06 if speed > 0.3 else 0.0
	_lying = lerpf(_lying, _target_lying, 1.0 - exp(-delta * 4.0))
	rotation.x = -_lying * PI * 0.5
	position.y = bob + _lying * 0.3
	return step_sign


## Gesichtsausdruck (Augenbrauen, Mund, Wangen, Nase)
func set_expression(e: String) -> void:
	expression = e


## Ruß im Gesicht (nach einer Explosion)
func soot(seconds: float) -> void:
	_soot = seconds


func _update_face(delta: float) -> void:
	if _mouth.is_empty():
		return
	var brow_y := 0.17
	var brow_rot := 0.0
	var smile := 0.0
	var open := 1.0
	var lids := 1.0
	match expression:
		"happy":
			smile = 1.0
			brow_y = 0.19
		"angry":
			brow_rot = 0.45
			brow_y = 0.155
			smile = -0.8
		"drunk":
			smile = 0.6
			lids = 0.45
			brow_y = 0.19
			brow_rot = -0.25
		"surprised":
			brow_y = 0.21
			open = 2.6
			lids = 1.25
		"pain":
			brow_rot = -0.5
			smile = -1.0
			lids = 0.6
		"focus":
			brow_rot = 0.25
			lids = 0.7
	var k := 1.0 - exp(-delta * 10.0)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_brows[i].position.y = lerpf(_brows[i].position.y, brow_y, k)
		_brows[i].rotation.z = lerp_angle(_brows[i].rotation.z, brow_rot * -side, k)
		_eyes[i].scale.y = lerpf(_eyes[i].scale.y, lids, k)
	_mouth[0].position.y = lerpf(_mouth[0].position.y, -0.17 + smile * 0.025, k)
	_mouth[2].position.y = lerpf(_mouth[2].position.y, -0.17 + smile * 0.025, k)
	_mouth[0].rotation.z = lerpf(_mouth[0].rotation.z, smile * 0.5, k)
	_mouth[2].rotation.z = lerpf(_mouth[2].rotation.z, -smile * 0.5, k)
	_mouth[1].scale.y = lerpf(_mouth[1].scale.y, open, k)
	var drunk := expression == "drunk"
	for c in _cheeks:
		c.visible = drunk
	var skin: Color = outfit.skin
	var nose_c := skin.darkened(0.12).lerp(Color(0.9, 0.25, 0.25), 0.8 if drunk else 0.0)
	if _soot > 0.0:
		_soot -= delta
		nose_c = Color(0.15, 0.13, 0.12)
	(_nose.material_override as StandardMaterial3D).albedo_color = nose_c


## Ohnmacht / Ragdoll-Ersatz: Figur kippt um
func set_lying(on: bool) -> void:
	_target_lying = 1.0 if on else 0.0
