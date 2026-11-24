class_name Radio
extends AudioStreamPlayer3D
## Autoradio (Taste K schaltet weiter). Echte Online-Sender kommen aus radio-browser.info
## (freie Radio-Datenbank, österreichische MP3-Sender zuerst), dazu zwei im Code erzeugte Sender
## und "Eigene Musik" (.ogg/.mp3/.wav aus Dokumente/Saint Leonard/Musik). Außerhalb des Autos leise hörbar.
## Online-Streams werden in Stücken von einigen Sekunden geladen und nacheinander abgespielt.

const GENERATED := ["Radio Kärnten (generiert)", "Alpen Rock (generiert)"]
const RATE := 22050.0
const MUSIC_DIR_NAME := "Saint Leonard/Musik"
const API_HOSTS := ["de1.api.radio-browser.info", "fi1.api.radio-browser.info", "de2.api.radio-browser.info"]
const UA := "SaintLeonardGame/1.0"
const CHUNK_SECONDS := 5.0

static var online: Array = []  # [{name, url, bitrate}]
static var _fetching := false

var station := 0  # 0 = aus, dann online..., dann generiert, dann eigene Musik
var station_name := "Aus"
var _gen: AudioStreamGenerator
var _pb: AudioStreamGeneratorPlayback
var _sample_in_beat := 0
var _beat := 0
var _melody_phase := 0.0
var _bass_phase := 0.0
var _chord_phase := [0.0, 0.0, 0.0]
var _note := 0
var _rng := RandomNumberGenerator.new()
var _files: Array = []
var _file_idx := 0
# Online-Stream
var _http: HTTPClient
var _stream_url := ""
var _redirects := 0
var _buf := PackedByteArray()
var _queue: Array[AudioStreamMP3] = []
var _second: AudioStreamPlayer3D
var _active: AudioStreamPlayer3D
var _chunk_bytes := 80000
var _requested := false


func _ready() -> void:
	unit_size = 3.0
	max_distance = 45.0
	volume_db = -6.0
	_rng.seed = 99
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = RATE
	_gen.buffer_length = 0.3
	_second = AudioStreamPlayer3D.new()
	_second.unit_size = unit_size
	_second.max_distance = max_distance
	_second.volume_db = volume_db
	add_child(_second)
	finished.connect(_on_chunk_done)
	_second.finished.connect(_on_chunk_done)
	_fetch_stations()


func _total() -> int:
	return 1 + online.size() + GENERATED.size() + 1


## Nächster Sender; gibt den Namen für die Anzeige zurück
func next_station() -> String:
	station = (station + 1) % _total()
	_stop_all()
	if station == 0:
		station_name = "Aus"
		return "Radio aus"
	var k := station - 1
	if k < online.size():
		var s: Dictionary = online[k]
		station_name = s.name
		_start_stream(s.url, int(s.get("bitrate", 128)))
		return "Radio: %s (wird geladen ...)" % s.name
	k -= online.size()
	if k < GENERATED.size():
		station_name = GENERATED[k]
		stream = _gen
		play()
		_pb = get_stream_playback()
		_beat = 0
		var hint := "" if not online.is_empty() else ("  (Online-Sender werden geladen)" if _fetching else "  (keine Online-Sender, kein Internet?)")
		return "Radio: %s%s" % [station_name, hint]
	_files = _music_files()
	if _files.is_empty():
		station_name = "Aus"
		station = 0
		return "Keine eigene Musik: Dateien nach Dokumente/%s legen" % MUSIC_DIR_NAME
	station_name = "Eigene Musik"
	_play_file()
	return "Eigene Musik: %s" % str(_files[(_file_idx - 1) % _files.size()]).get_file()


func _stop_all() -> void:
	stop()
	_second.stop()
	_http = null
	_buf.clear()
	_queue.clear()
	_active = null
	_pb = null


# ------------------------------------------------------------------ Senderliste

func _fetch_stations() -> void:
	if _fetching or not online.is_empty():
		return
	_fetching = true
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var hosts := API_HOSTS.duplicate()
	var try_next := func(self_ref: Callable) -> void:
		if hosts.is_empty():
			_fetching = false
			req.queue_free()
			return
		var host: String = hosts.pop_front()
		var url := "https://%s/json/stations/search?countrycode=AT&codec=MP3&hidebroken=true&order=clickcount&reverse=true&limit=40" % host
		if req.request(url, ["User-Agent: " + UA]) != OK:
			self_ref.call(self_ref)
	req.request_completed.connect(func(result, code, _h, body):
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			try_next.call(try_next)
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_ARRAY:
			var list := []
			var seen := {}
			for st in data:
				var n: String = str(st.get("name", "")).strip_edges()
				var u: String = str(st.get("url_resolved", st.get("url", "")))
				if n.is_empty() or u.is_empty() or seen.has(n.to_lower()) or u.ends_with(".m3u") or u.ends_with(".pls"):
					continue
				seen[n.to_lower()] = true
				list.append({name = n, url = u, bitrate = int(st.get("bitrate", 128))})
			# Kärntner Sender nach vorne
			list.sort_custom(func(a, b): return _score(a.name) > _score(b.name))
			online = list.slice(0, 15)
		_fetching = false
		req.queue_free())
	try_next.call(try_next)


static func _score(n: String) -> int:
	var l := n.to_lower()
	if "kärnten" in l or "karnten" in l or "carinthia" in l:
		return 3
	if "ö3" in l or "antenne" in l or "kronehit" in l or "88.6" in l:
		return 2
	return 0


# ------------------------------------------------------------------ Online-Stream

func _start_stream(url: String, bitrate: int) -> void:
	_stream_url = url
	_redirects = 0
	_chunk_bytes = int(maxf(bitrate, 64) * 1000.0 / 8.0 * CHUNK_SECONDS)
	_connect(url)


func _connect(url: String) -> void:
	_http = HTTPClient.new()
	_requested = false
	_buf.clear()
	var tls := url.begins_with("https://")
	var rest := url.substr(8 if tls else 7)
	var slash := rest.find("/")
	var hostport := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var host := hostport
	var port := 443 if tls else 80
	if ":" in hostport:
		host = hostport.get_slice(":", 0)
		port = int(hostport.get_slice(":", 1))
	var err := _http.connect_to_host(host, port, TLSOptions.client() if tls else null)
	if err != OK:
		_fail("Sender nicht erreichbar")
		return
	_http.set_meta("path", path)


func _fail(text: String) -> void:
	_http = null
	GameState.notify("Radio", "%s: %s" % [station_name, text])


func _poll_stream() -> void:
	if _http == null:
		return
	_http.poll()
	var st := _http.get_status()
	match st:
		HTTPClient.STATUS_CONNECTED:
			if not _requested:
				_requested = true
				_http.request(HTTPClient.METHOD_GET, _http.get_meta("path"), ["User-Agent: " + UA, "Accept: */*"])
		HTTPClient.STATUS_BODY:
			if _http.has_response() and _http.get_response_code() in [301, 302, 303, 307, 308]:
				var h := _http.get_response_headers_as_dictionary()
				var loc: String = h.get("Location", h.get("location", ""))
				_redirects += 1
				if loc.is_empty() or _redirects > 4:
					_fail("Weiterleitung fehlgeschlagen")
				else:
					_connect(loc)
				return
			if _http.get_response_code() >= 400:
				_fail("Fehler %d" % _http.get_response_code())
				return
			for i in 8:
				var chunk := _http.read_response_body_chunk()
				if chunk.is_empty():
					break
				_buf.append_array(chunk)
			if _buf.size() >= _chunk_bytes:
				var mp3 := AudioStreamMP3.new()
				mp3.data = _buf
				_buf = PackedByteArray()
				_queue.append(mp3)
				if _active == null or not _active.playing:
					_on_chunk_done()
		HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_fail("keine Verbindung")
		HTTPClient.STATUS_DISCONNECTED:
			if _requested:
				_connect(_stream_url)  # Stream abgebrochen: neu verbinden


func _on_chunk_done() -> void:
	if station == 0 or _queue.is_empty():
		if _active and not _active.playing:
			_active = null
		return
	var next: AudioStreamPlayer3D = _second if _active == self else self
	next.stream = _queue.pop_front()
	next.play()
	_active = next


# ------------------------------------------------------------------ eigene Musik

static func music_dir() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join(MUSIC_DIR_NAME)


func _music_files() -> Array:
	var out := []
	var dir := DirAccess.open(music_dir())
	if dir == null:
		DirAccess.make_dir_recursive_absolute(music_dir())
		return out
	for f in dir.get_files():
		if f.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			out.append(music_dir().path_join(f))
	return out


func _play_file() -> void:
	var path: String = _files[_file_idx % _files.size()]
	var s: AudioStream = null
	match path.get_extension().to_lower():
		"ogg": s = AudioStreamOggVorbis.load_from_file(path)
		"mp3": s = AudioStreamMP3.load_from_file(path)
		"wav": s = AudioStreamWAV.load_from_file(path)
	if s:
		stream = s
		play()
	_file_idx += 1


func _is_own_music() -> bool:
	return station == _total() - 1 and station != 0


func _is_generated() -> bool:
	var k := station - 1 - online.size()
	return station != 0 and k >= 0 and k < GENERATED.size()


func _process(_delta: float) -> void:
	var vol := linear_to_db(maxf(float(Settings.get_v("radio_volume")), 0.001)) - 4.0
	volume_db = vol
	_second.volume_db = vol
	_poll_stream()
	if _is_own_music() and not playing and not _files.is_empty():
		_play_file()
	if _is_generated() and _pb:
		var frames := _pb.get_frames_available()
		for i in frames:
			var v := _sample()
			_pb.push_frame(Vector2(v, v))


# ------------------------------------------------------------------ erzeugte Musik

const SCALE := [0, 2, 4, 5, 7, 9, 11, 12]
const PROG := [0, 5, 7, 0]  # I IV V I


func _freq(semi: int, base := 261.63) -> float:
	return base * pow(2.0, semi / 12.0)


func _sample() -> float:
	var folk := station - 1 - online.size() == 0
	var bpm := 128.0 if folk else 140.0
	var spb := int(RATE * 60.0 / bpm / 2.0)
	_sample_in_beat += 1
	if _sample_in_beat >= spb:
		_sample_in_beat = 0
		_beat += 1
		if _rng.randf() < 0.7:
			var step: int = SCALE[_rng.randi() % SCALE.size()]
			_note = step + (12 if _rng.randf() < 0.3 else 0)
	var bar := (_beat / 8) % PROG.size()
	var root: int = PROG[bar]
	var u := float(_sample_in_beat) / spb
	var env := exp(-u * 4.0)
	var v := 0.0
	if folk:
		var bass_note := root - 12 if (_beat % 2) == 0 else root - 5
		_bass_phase += TAU * _freq(bass_note, 130.81) / RATE
		v += (1.0 if sin(_bass_phase) > 0.0 else -1.0) * 0.18 * env * float(_beat % 2 == 0)
		if _beat % 2 == 1:
			for k in 3:
				_chord_phase[k] += TAU * _freq(root + [0, 4, 7][k]) / RATE
				v += sin(_chord_phase[k]) * 0.07 * env + sin(_chord_phase[k] * 2.0) * 0.03 * env
		_melody_phase += TAU * _freq(_note + root, 523.25) / RATE
		v += (sin(_melody_phase) * 0.6 + sin(_melody_phase * 3.0) * 0.2) * 0.12 * (0.6 + 0.4 * exp(-u * 2.0))
	else:
		for k in 2:
			_chord_phase[k] += TAU * _freq(root + [0, 7][k], 110.0) / RATE
			v += clampf(sin(_chord_phase[k]) * 4.0, -1.0, 1.0) * 0.09
		_bass_phase += TAU * _freq(root - 12, 110.0) / RATE
		v += sin(_bass_phase) * 0.15
		if _beat % 4 == 0:
			v += sin(TAU * 60.0 * u * 0.3) * exp(-u * 10.0) * 0.5
		elif _beat % 4 == 2:
			v += _rng.randf_range(-1, 1) * exp(-u * 12.0) * 0.3
		v += _rng.randf_range(-1, 1) * exp(-u * 40.0) * 0.06
	return clampf(v, -1.0, 1.0)
