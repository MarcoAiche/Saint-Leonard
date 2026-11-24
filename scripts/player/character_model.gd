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


func _init(o := {}, layer := 1) -> void:
	outfit = {
		shirt = Color(0.35, 0.42, 0.25), pants = Color(0.30, 0.26, 0.20), skin = Color(0.98, 0.80, 0.66),
		hat = "cap", hat_color = Color(0.22, 0.30, 0.18), jacket = false, uniform = false,
	}
	outfit.merge(o, true)
	render_layer = layer


func _ready() -> void:
	_build()


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.solid(color, outline, 0.015)
	mi.position = pos
	mi.layers = render_layer
	parent.add_child(mi)
	return mi


func _build() -> void:
	var shirt: Color = outfit.shirt
	var skin: Color = outfit.skin
	if outfit.uniform:
		shirt = Color(0.20, 0.30, 0.50)
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 0.95
	body_mesh = _part(self, body, shirt, Vector3(0, 1.15, 0))
	if outfit.jacket:
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
	head.scale = Vector3.ONE * 1.12  # etwas größerer Kopf: witziger
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
	var moustache := BoxMesh.new()
	moustache.size = Vector3(0.2, 0.04, 0.04)
	_part(head, moustache, Color(0.35, 0.25, 0.15), Vector3(0, -0.12, 0.25), false)

	var hc: Color = outfit.hat_color
	match str(outfit.hat):
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

	var leg := BoxMesh.new()
	leg.size = Vector3(0.18, 0.72, 0.2)
	var shoe := BoxMesh.new()
	shoe.size = Vector3(0.2, 0.12, 0.3)
	var pants: Color = Color(0.15, 0.18, 0.28) if outfit.uniform else outfit.pants
	for x in [-0.14, 0.14]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.78, 0)
		add_child(hip)
		_part(hip, leg, pants, Vector3(0, -0.36, 0))
		_part(hip, shoe, Color(0.22, 0.16, 0.12), Vector3(0, -0.72, 0.05))
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
		_part(shoulder, arm, shirt if not outfit.jacket else Color(0.45, 0.30, 0.18), Vector3(0, -0.3, 0))
		_part(shoulder, hand, skin, Vector3(0, -0.64, 0))
		arms.append(shoulder)


## speed in m/s; aiming hebt die Arme
func animate(delta: float, speed: float, on_floor := true, aiming := false, sitting := false, to_mouth := false, reloading := false) -> float:
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
