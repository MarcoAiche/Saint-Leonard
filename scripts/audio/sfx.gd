class_name Sfx
extends RefCounted
## Alle Geräusche werden im Code erzeugt (keine Audiodateien nötig).

const RATE := 22050
static var _cache := {}


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Kurzer Schritt: gefiltertes Rauschen mit schnellem Abklingen
static func footstep() -> AudioStreamWAV:
	if _cache.has("step"):
		return _cache["step"]
	var n := int(RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / n
		lp += (rng.randf_range(-1, 1) - lp) * 0.25
		s[i] = lp * 1.6 * exp(-t * 6.0) * minf(1.0, t * 60.0)
	_cache["step"] = _wav(s)
	return _cache["step"]


## Autotür: dumpfer Schlag
static func door() -> AudioStreamWAV:
	if _cache.has("door"):
		return _cache["door"]
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		s[i] = (lp * 3.0 + sin(TAU * 70.0 * t) * 0.5) * exp(-t * 22.0)
	_cache["door"] = _wav(s)
	return _cache["door"]


## Hupe: zwei Rechtecktöne
static func horn() -> AudioStreamWAV:
	if _cache.has("horn"):
		return _cache["horn"]
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := (1.0 if fmod(t * 392.0, 1.0) < 0.5 else -1.0) + (1.0 if fmod(t * 494.0, 1.0) < 0.5 else -1.0)
		s[i] = v * 0.22 * minf(1.0, minf(t * 40.0, (0.45 - t) * 30.0))
	_cache["horn"] = _wav(s)
	return _cache["horn"]


## Klick für Knöpfe
static func click() -> AudioStreamWAV:
	if _cache.has("click"):
		return _cache["click"]
	var n := int(RATE * 0.05)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * (900.0 - t * 6000.0) * t) * 0.4 * exp(-t * 80.0)
	_cache["click"] = _wav(s)
	return _cache["click"]


## Umgebung: Wind und Vogelgezwitscher als 12-Sekunden-Schleife
static func ambience() -> AudioStreamWAV:
	if _cache.has("amb"):
		return _cache["amb"]
	var dur := 12.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		# Wind schwillt sanft an und ab (Periode passt in die Schleife)
		var gust := 0.55 + 0.45 * sin(TAU * t / dur * 2.0) * sin(TAU * t / dur * 3.0 + 1.0)
		s[i] = lp2 * 2.2 * gust
	# Vögel: kurze Pfiffe mit Tonhöhenbogen
	for k in 26:
		var start := rng.randf_range(0.0, dur - 0.6)
		var base := rng.randf_range(2600.0, 4200.0)
		var notes := rng.randi_range(2, 5)
		var note_len := rng.randf_range(0.06, 0.12)
		var vol := rng.randf_range(0.06, 0.16)
		var phase := 0.0
		for nidx in notes:
			var f0 := base * rng.randf_range(0.85, 1.2)
			var f1 := f0 * rng.randf_range(0.7, 1.4)
			var i0 := int((start + nidx * note_len * 1.5) * RATE)
			var len := int(note_len * RATE)
			for j in len:
				if i0 + j >= n:
					break
				var u := float(j) / len
				phase += TAU * lerpf(f0, f1, u) / RATE
				s[i0 + j] += sin(phase) * vol * sin(PI * u)
	_cache["amb"] = _wav(s, true)
	return _cache["amb"]


static func play_2d(parent: Node, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func play_3d(parent: Node3D, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
