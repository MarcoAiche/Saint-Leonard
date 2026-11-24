extends Node
## Sprachchat (Autoload "Voice"): [B] gedrückt halten zum Sprechen, [J] Mikrofon stumm.
##  - Nähe: Stimme kommt von der Figur und wird mit Abstand leiser, in Autos und Häusern dumpfer.
##  - Funk: Gruppenkanal über die ganze Karte (Einstellung im Handy), klingt wie ein Funkgerät.
## Übertragung: 16 kHz, 8-bit µ-law (ca. 16 KB/s pro Sprecher), nur im Mehrspieler-Modus.

const RATE := 16000.0
const CHUNK := 320  # 20 ms

var muted := false
var radio_on := false

var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _buf := PackedFloat32Array()
var _ratio := 3.0
var _talking := false
var _started := false


func _ready() -> void:
	_setup_buses()


func _setup_buses() -> void:
	# Mikrofon-Bus (stumm geschaltet, nur zum Abgreifen)
	if AudioServer.get_bus_index("Mic") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Mic")
		AudioServer.set_bus_mute(i, true)
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(i, _capture)
	# Dumpfe Stimmen (im Auto / Haus)
	if AudioServer.get_bus_index("VoiceMuffled") < 0:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "VoiceMuffled")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(j, lp)
	# Funkgerät
	if AudioServer.get_bus_index("Funk") < 0:
		AudioServer.add_bus()
		var k := AudioServer.bus_count - 1
		AudioServer.set_bus_name(k, "Funk")
		var bp := AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1600.0
		AudioServer.add_bus_effect(k, bp)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_CLIP
		dist.drive = 0.3
		AudioServer.add_bus_effect(k, dist)


func _start_mic() -> void:
	if _started:
		return
	_started = true
	if DisplayServer.get_name() == "headless":
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		push_warning("Sprachchat: audio/driver/enable_input ist aus")
		return
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Mic"
	add_child(_mic)
	_mic.play()
	_ratio = AudioServer.get_mix_rate() / RATE


func is_talking() -> bool:
	return _talking


func _process(_delta: float) -> void:
	if not Net.connected_ok() or Net.is_dedicated():
		return
	_start_mic()
	if not _capture or not _mic:
		return
	_talking = Input.is_action_pressed("voice") and not muted
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var data := _capture.get_buffer(frames)
	if not _talking:
		return
	# auf 16 kHz herunterrechnen (Mittelwert)
	var acc := 0.0
	var n := 0
	var pos := 0.0
	for f in data:
		acc += (f.x + f.y) * 0.5
		n += 1
		pos += 1.0
		if pos >= _ratio:
			pos -= _ratio
			_buf.append(acc / n)
			acc = 0.0
			n = 0
	while _buf.size() >= CHUNK:
		var bytes := PackedByteArray()
		bytes.resize(CHUNK)
		for i in CHUNK:
			bytes[i] = _mulaw_encode(_buf[i])
		_buf = _buf.slice(CHUNK)
		_voice.rpc(bytes, radio_on)


@rpc("any_peer", "unreliable_ordered", "call_remote", 2)
func _voice(bytes: PackedByteArray, radio: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if Net.game:
		var samples := PackedFloat32Array()
		samples.resize(bytes.size())
		for i in bytes.size():
			samples[i] = _mulaw_decode(bytes[i])
		Net.game.on_voice(id, samples, radio and radio_on)


static func _mulaw_encode(x: float) -> int:
	var s := clampf(x, -1.0, 1.0)
	var mag := log(1.0 + 255.0 * absf(s)) / log(256.0)
	var v := int(mag * 127.0)
	return (v | 128) if s < 0.0 else v


static func _mulaw_decode(b: int) -> float:
	var neg := (b & 128) != 0
	var mag := float(b & 127) / 127.0
	var v := (pow(256.0, mag) - 1.0) / 255.0
	return -v if neg else v
