class_name EngineSound
extends AudioStreamPlayer3D
## Motorgeräusch in Echtzeit: Drehzahl aus Tempo und simulierten Gängen,
## dazu Reifen- und Fahrtwindrauschen, das mit dem Tempo lauter wird.

const RATE := 22050.0
const GEARS := [0.0, 22.0, 42.0, 65.0, 90.0, 999.0]  # km/h, ab denen hochgeschaltet wird

var speed_kmh := 0.0
var throttle := 0.0
var running := false

var _rpm := 800.0
var _phase := 0.0
var _phase2 := 0.0
var _lp := 0.0
var _noise_lp := 0.0
var _vol := 0.0
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	unit_size = 10.0
	max_db = 3.0
	volume_db = -4.0
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	var v := absf(speed_kmh)
	var gear := 1
	while gear < GEARS.size() - 1 and v > GEARS[gear]:
		gear += 1
	var lo: float = GEARS[gear - 1]
	var hi: float = minf(GEARS[gear], 130.0)
	var frac := clampf((v - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var target := 850.0 + frac * 3600.0 + throttle * 500.0 if running else 0.0
	if v < 3.0 and running:
		target = 850.0 + throttle * 1400.0
	_rpm = lerpf(_rpm, target, 1.0 - exp(-delta * 8.0))
	var target_vol := (0.35 + 0.45 * absf(throttle)) if running else 0.0
	_vol = lerpf(_vol, target_vol, 1.0 - exp(-delta * 5.0))
	_fill()


func _fill() -> void:
	if not _playback:
		return
	var frames := _playback.get_frames_available()
	var f := _rpm / 60.0 * 2.0  # Vierzylinder: zwei Zündungen pro Umdrehung
	var road := clampf(absf(speed_kmh) / 120.0, 0.0, 1.0)
	for i in frames:
		_phase = fmod(_phase + f / RATE, 1.0)
		_phase2 = fmod(_phase2 + f * 0.5 / RATE, 1.0)
		var saw := _phase * 2.0 - 1.0
		var pulse := 1.0 if _phase2 < 0.3 else -0.4
		var raw := saw * 0.6 + pulse * 0.4
		_lp += (raw - _lp) * 0.18  # Tiefpass macht es weicher
		_noise_lp += (_rng.randf_range(-1.0, 1.0) - _noise_lp) * 0.12
		var s := _lp * _vol + _noise_lp * road * 0.45
		_playback.push_frame(Vector2(s, s))
