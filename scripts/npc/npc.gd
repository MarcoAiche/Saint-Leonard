class_name Npc
extends Node3D
## Einfache Figur, die irgendwo steht (Verkäufer, Wirt, Polizist, Gestrandete).
## Dreht sich zur Spielfigur, wenn sie in der Nähe ist, und wippt leicht.

var model: CharacterModel
var display_name := ""
var look_at_player := true
var important := false
var hp := 100.0
var alive := true
var _t := 0.0
var _label: Label3D
var _bubble: Label3D
var _say_cd := 0.0
var _say_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(npc_name := "", outfit := {}) -> void:
	display_name = npc_name
	model = CharacterModel.new(outfit)


## Sprechblase über dem Kopf
func say(text: String, seconds := 4.0) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.position.y = 2.95
		_bubble.font_size = 34
		_bubble.pixel_size = 0.006
		_bubble.outline_size = 14
		_bubble.modulate = Color(0.1, 0.08, 0.08)
		_bubble.outline_modulate = Color(1, 1, 1)
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.width = 380
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_bubble)
	_bubble.text = text
	_say_t = seconds
	model.set_expression(["happy", "surprised", "happy", "neutral"][_rng.randi() % 4])


func _ready() -> void:
	_rng.randomize()
	_say_cd = _rng.randf_range(1.0, 6.0)
	add_child(model)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.85
	cs.shape = cap
	cs.position.y = 0.95
	body.add_child(cs)
	body.set_meta("npc", self)
	add_child(body)
	if not display_name.is_empty():
		_label = Label3D.new()
		_label.text = display_name
		_label.position.y = 2.55
		_label.font_size = 40
		_label.pixel_size = 0.006
		_label.outline_size = 10
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.visibility_range_end = 30.0
		add_child(_label)


func take_hit(dmg: float, hit_pos: Vector3) -> bool:
	if not alive:
		return false
	var headshot := (hit_pos.y - global_position.y) > 1.35
	hp = 0.0 if headshot else maxf(0.0, hp - clampf(dmg * 0.22, 12.0, 34.0))
	model.set_expression("pain")
	if hp <= 0.0:
		alive = false
		model.set_lying(true)
		if _label:
			_label.visible = false
		return true
	return false


func _process(delta: float) -> void:
	if not alive:
		model.animate(delta, 0.0)
		return
	_t += delta
	_say_cd -= delta
	_say_t -= delta
	if _bubble:
		_bubble.visible = _say_t > 0.0
	var cam0 := get_viewport().get_camera_3d()
	if cam0 and _say_cd <= 0.0 and cam0.global_position.distance_to(global_position) < 7.0:
		say(NpcLines.pick(display_name, _rng))
		_say_cd = _rng.randf_range(14.0, 26.0)
	model.animate(delta, 0.0)
	model.position.y = sin(_t * 1.7) * 0.01
	if look_at_player:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(global_position) < 12.0:
			var d := cam.global_position - global_position
			var want := atan2(d.x, d.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-delta * 3.0))
