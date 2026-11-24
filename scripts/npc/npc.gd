class_name Npc
extends Node3D
## Einfache Figur, die irgendwo steht (Verkäufer, Wirt, Polizist, Gestrandete).
## Dreht sich zur Spielfigur, wenn sie in der Nähe ist, und wippt leicht.

var model: CharacterModel
var display_name := ""
var look_at_player := true
var _t := 0.0
var _label: Label3D


func _init(npc_name := "", outfit := {}) -> void:
	display_name = npc_name
	model = CharacterModel.new(outfit)


func _ready() -> void:
	add_child(model)
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


func _process(delta: float) -> void:
	_t += delta
	model.animate(delta, 0.0)
	model.position.y = sin(_t * 1.7) * 0.01
	if look_at_player:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(global_position) < 12.0:
			var d := cam.global_position - global_position
			var want := atan2(d.x, d.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-delta * 3.0))
