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


## Gewehrschuss: lauter Knall mit Nachhall
static func gunshot() -> AudioStreamWAV:
	if _cache.has("shot"):
		return _cache["shot"]
	var n := int(RATE * 1.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1, 1)
		lp += (noise - lp) * 0.5
		lp2 += (noise - lp2) * 0.03
		var crack := lp * exp(-t * 60.0) * 1.4
		var boom := sin(TAU * 55.0 * t * (1.0 - t * 0.3)) * exp(-t * 9.0) * 0.8
		var tail := lp2 * 3.0 * exp(-t * 3.0) * minf(1.0, t * 30.0)
		s[i] = crack + boom + tail * 0.6
	_cache["shot"] = _wav(s)
	return _cache["shot"]


## Repetieren / Nachladen
static func reload_sound() -> AudioStreamWAV:
	if _cache.has("reload"):
		return _cache["reload"]
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.18, 0.42]:
			var u: float = t - c
			if u >= 0.0:
				v += rng.randf_range(-1, 1) * exp(-u * 120.0) * 0.8 + sin(TAU * 2400.0 * u) * exp(-u * 90.0) * 0.3
		s[i] = v
	_cache["reload"] = _wav(s)
	return _cache["reload"]


## Husten
static func cough() -> AudioStreamWAV:
	if _cache.has("cough"):
		return _cache["cough"]
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.15
		var env := 0.0
		for c in [0.0, 0.3, 0.55]:
			var u: float = t - c
			if u >= 0.0:
				env += exp(-u * 14.0) * minf(1.0, u * 200.0)
		s[i] = (lp * 1.8 + sin(TAU * 180.0 * t) * 0.3) * env
	_cache["cough"] = _wav(s)
	return _cache["cough"]


## Explosion (Brennkessel)
static func explosion() -> AudioStreamWAV:
	if _cache.has("boom"):
		return _cache["boom"]
	var n := int(RATE * 2.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.06
		s[i] = (lp * 4.0 + sin(TAU * 38.0 * t) * 0.8) * exp(-t * 2.2) * minf(1.0, t * 200.0)
	_cache["boom"] = _wav(s)
	return _cache["boom"]


## Polizeisirene (österreichisches Tatütata) als Schleife
static func siren() -> AudioStreamWAV:
	if _cache.has("siren"):
		return _cache["siren"]
	var dur := 2.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 440.0 if t < 1.0 else 587.0
		phase += TAU * f / RATE
		s[i] = (sin(phase) + 0.3 * sin(phase * 3.0)) * 0.3
	_cache["siren"] = _wav(s, true)
	return _cache["siren"]


## Tiergeräusche: Reh (Schrecken / Bellen), Wildschwein (Grunzen), Bär (Brüllen)
static func animal_call(kind: String) -> AudioStreamWAV:
	var key := "call_" + kind
	if _cache.has(key):
		return _cache[key]
	var dur := {deer = 0.5, boar = 0.7, bear = 1.4, rabbit = 0.2}.get(kind, 0.5) as float
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		lp += (rng.randf_range(-1, 1) - lp) * (0.3 if kind == "deer" else 0.08)
		var v := 0.0
		match kind:
			"deer":
				phase += TAU * lerpf(900.0, 500.0, u) / RATE
				v = (sin(phase) * 0.4 + lp * 0.6) * sin(PI * u)
			"boar":
				phase += TAU * (90.0 + 30.0 * sin(t * 40.0)) / RATE
				v = (sign(sin(phase)) * 0.3 + lp * 1.2) * sin(PI * u) * (0.6 + 0.4 * sin(t * 25.0))
			"bear":
				phase += TAU * lerpf(120.0, 80.0, u) / RATE
				v = (sin(phase) * 0.5 + sign(sin(phase * 2.01)) * 0.2 + lp * 1.5) * sin(PI * u)
			_:
				v = lp * sin(PI * u)
		s[i] = v * 0.8
	_cache[key] = _wav(s)
	return _cache[key]


## Regen als Schleife
static func rain() -> AudioStreamWAV:
	if _cache.has("rain"):
		return _cache["rain"]
	var dur := 4.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1, 1) - lp) * 0.4
		s[i] = lp * 0.5 + (rng.randf_range(-1, 1) * 0.8 if rng.randf() < 0.002 else 0.0)
	_cache["rain"] = _wav(s, true)
	return _cache["rain"]


## Kurzer Ton für Nachrichten am Handy
static func ping() -> AudioStreamWAV:
	if _cache.has("ping"):
		return _cache["ping"]
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1320.0 if t < 0.12 else 1760.0
		s[i] = sin(TAU * f * t) * 0.35 * exp(-fmod(t, 0.12) * 18.0)
	_cache["ping"] = _wav(s)
	return _cache["ping"]


## Feuer knistern (Schleife)
static func fire() -> AudioStreamWAV:
	if _cache.has("fire"):
		return _cache["fire"]
	var dur := 3.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lp := 0.0
	for i in n:
		lp += (rng.randf_range(-1, 1) - lp) * 0.05
		var crack := rng.randf_range(-1, 1) * 0.9 if rng.randf() < 0.0015 else 0.0
		s[i] = lp * 0.6 + crack
	_cache["fire"] = _wav(s, true)
	return _cache["fire"]


## Kamera-Auslöser
static func shutter() -> AudioStreamWAV:
	if _cache.has("shutter"):
		return _cache["shutter"]
	var n := int(RATE * 0.15)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in n:
		var t := float(i) / RATE
		var v := rng.randf_range(-1, 1) * exp(-t * 90.0)
		if t > 0.07:
			v += rng.randf_range(-1, 1) * exp(-(t - 0.07) * 90.0)
		s[i] = v * 0.6
	_cache["shutter"] = _wav(s)
	return _cache["shutter"]


## Schluck (Trinken)
static func gulp() -> AudioStreamWAV:
	if _cache.has("gulp"):
		return _cache["gulp"]
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.1
		var v := 0.0
		for c in [0.0, 0.32, 0.6]:
			var u: float = t - c
			if u >= 0.0 and u < 0.25:
				v += (sin(TAU * lerpf(180.0, 90.0, u * 4.0) * u) * 0.6 + lp) * sin(PI * u * 4.0)
		s[i] = v * 0.7
	_cache["gulp"] = _wav(s)
	return _cache["gulp"]


## Walzen drehen (Spielautomat)
static func slot_spin() -> AudioStreamWAV:
	if _cache.has("slot"):
		return _cache["slot"]
	var n := int(RATE * 1.9)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var rate := 18.0 if t < 0.8 else (12.0 if t < 1.3 else 8.0)
		var u := fmod(t * rate, 1.0)
		s[i] = sin(TAU * 1800.0 * t) * exp(-u * 40.0) * 0.35
		for stop in [0.8, 1.3, 1.8]:
			var d: float = t - stop
			if d >= 0.0 and d < 0.08:
				s[i] += sin(TAU * 220.0 * d) * exp(-d * 50.0) * 0.6
	_cache["slot"] = _wav(s)
	return _cache["slot"]


## Gewinn-Melodie (big = Jackpot)
static func jingle(big := false) -> AudioStreamWAV:
	var key := "jingle_%s" % big
	if _cache.has(key):
		return _cache[key]
	var notes := [523.25, 659.25, 783.99, 1046.5] if not big else [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5]
	var nl := 0.11
	var n := int(RATE * (notes.size() * nl + 0.4))
	var s := PackedFloat32Array()
	s.resize(n)
	for k in notes.size():
		var i0 := int(k * nl * RATE)
		var len := int((nl + 0.3) * RATE)
		for j in len:
			if i0 + j >= n:
				break
			var t := float(j) / RATE
			s[i0 + j] += (sin(TAU * notes[k] * t) + 0.3 * sin(TAU * notes[k] * 2.0 * t)) * 0.25 * exp(-t * 6.0)
	_cache[key] = _wav(s)
	return _cache[key]


## Jetons klackern
static func chips() -> AudioStreamWAV:
	if _cache.has("chips"):
		return _cache["chips"]
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for c in [0.0, 0.05, 0.11, 0.16]:
			var u: float = t - c
			if u >= 0.0:
				v += (sin(TAU * 3200.0 * u) * 0.5 + rng.randf_range(-0.3, 0.3)) * exp(-u * 160.0)
		s[i] = v * 0.6
	_cache["chips"] = _wav(s)
	return _cache["chips"]


## Roulettekugel
static func roulette_ball() -> AudioStreamWAV:
	if _cache.has("ball"):
		return _cache["ball"]
	var dur := 4.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var lp := 0.0
	var next_tick := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.3
		var v := lp * 0.15 * (1.0 - t / dur)
		if t > 2.5 and t >= next_tick:
			next_tick = t + lerpf(0.05, 0.3, (t - 2.5) / 1.5)
		var d := t - (next_tick - 0.0)
		if t > 2.5:
			v += sin(TAU * 2500.0 * t) * exp(-absf(fmod(t, 0.12)) * 120.0) * 0.2
		s[i] = v
	_cache["ball"] = _wav(s)
	return _cache["ball"]


## Schluckauf
static func hiccup() -> AudioStreamWAV:
	if _cache.has("hic"):
		return _cache["hic"]
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * lerpf(500.0, 900.0, t * 4.0) * t) * exp(-t * 18.0) * 0.6
	_cache["hic"] = _wav(s)
	return _cache["hic"]


## Plumps (Hinfallen)
static func thump() -> AudioStreamWAV:
	if _cache.has("thump"):
		return _cache["thump"]
	var n := int(RATE * 0.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.05
		s[i] = (sin(TAU * 70.0 * t) * 0.8 + lp * 2.0) * exp(-t * 14.0)
	_cache["thump"] = _wav(s)
	return _cache["thump"]


## Rülpser
static func burp() -> AudioStreamWAV:
	if _cache.has("burp"):
		return _cache["burp"]
	var n := int(RATE * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (95.0 + 25.0 * sin(t * 30.0)) / RATE
		var buzz: float = signf(sin(phase)) * 0.4 + sin(phase) * 0.3 + rng.randf_range(-0.2, 0.2)
		s[i] = buzz * sin(PI * t / 0.7) * 0.7
	_cache["burp"] = _wav(s)
	return _cache["burp"]
