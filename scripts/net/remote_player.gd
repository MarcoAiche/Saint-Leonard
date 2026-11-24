class_name RemotePlayer
extends Node3D
## Mitspieler aus Sicht der anderen: Figur mit Namen, weich nachgeführte Position, Stimme (Nähe).

var peer_id := 0
var player_name := ""
var model: CharacterModel
var flags := 0
var seat_owner := 0
var seat := ""
var voice: AudioStreamPlayer3D
var radio_voice: AudioStreamPlayer
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _speed := 0.0
var _label: Label3D
var _pb: AudioStreamGeneratorPlayback
var _rpb: AudioStreamGeneratorPlayback


func setup(id: int, pname: String, outfit: Dictionary) -> void:
	peer_id = id
	player_name = pname
	model = CharacterModel.new(GameState._colors_in(outfit))
	add_child(model)
	add_to_group("player_body")
	add_to_group("remote_player")
	_label = Label3D.new()
	_label.text = pname
	_label.position.y = 2.6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 42
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.modulate = Color(1, 0.95, 0.5)
	add_child(_label)
	voice = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 16000.0
	gen.buffer_length = 0.5
	voice.stream = gen
	voice.unit_size = 6.0
	voice.max_distance = 45.0
	voice.position.y = 1.7
	add_child(voice)
	voice.play()
	_pb = voice.get_stream_playback()
	radio_voice = AudioStreamPlayer.new()
	var gen2 := AudioStreamGenerator.new()
	gen2.mix_rate = 16000.0
	gen2.buffer_length = 0.5
	radio_voice.stream = gen2
	radio_voice.bus = "Funk"
	radio_voice.volume_db = -4.0
	add_child(radio_voice)
	radio_voice.play()
	_rpb = radio_voice.get_stream_playback()


func apply_state(pos: Vector3, yaw: float, _pitch: float, f: int, owner_id: int, s: String) -> void:
	_speed = pos.distance_to(_target_pos) * Net.SEND_RATE
	_target_pos = pos
	_target_yaw = yaw
	flags = f
	seat_owner = owner_id
	seat = s
	model.set_lying(f & 8 != 0)
	visible = (f & 1) == 0 or seat.begins_with("bed")


func push_voice(samples: PackedFloat32Array, radio: bool, muffled: bool) -> void:
	var pb := _rpb if radio else _pb
	voice.bus = "VoiceMuffled" if muffled else "Master"
	if pb == null:
		return
	for s in samples:
		if pb.can_push_buffer(1):
			pb.push_frame(Vector2(s, s))


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, 1.0 - exp(-delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-delta * 12.0))
	model.animate(delta, _speed if (flags & 1) == 0 else 0.0, true, flags & 4 != 0, seat != "")
	model.scale.y = 0.72 if flags & 2 else 1.0


## Angriff durch Tiere wird an den Spieler weitergegeben
func take_hit(dmg: float, _from: Vector3) -> void:
	Net.hurt_player(peer_id, dmg)
