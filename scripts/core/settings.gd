class_name Settings
extends RefCounted
## Einstellungen (gespeichert in user://settings.cfg): Maus, Sichtfeld, Lautstärken, Bild und Grafik.

const PATH := "user://settings.cfg"

static var values := {
	sensitivity = 1.0,
	invert_y = false,
	fov = 72.0,
	volume = 0.8,
	sfx_volume = 0.85,
	ambience_volume = 0.8,
	voice_volume = 0.9,
	radio_volume = 0.8,
	fullscreen = false,
	vsync = true,
	render_scale = 0.85,
	shadows = 2,  # 0 aus, 1 niedrig, 2 hoch
	view_distance = 1.0,
}
static var _loaded := false


static func get_v(key: String):
	if not _loaded:
		load_settings()
	return values[key]


static func load_settings() -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in values:
			values[k] = cfg.get_value("settings", k, values[k])


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


static func set_v(key: String, v) -> void:
	values[key] = v
	save_settings()
	apply()


## Wirkt sofort auf Fenster, Ton und Grafik
static func apply(tree: SceneTree = null) -> void:
	if not _loaded:
		load_settings()
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	_ensure_audio_buses()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(values.volume), 0.001)))
	for pair in [["SFX", "sfx_volume"], ["Ambience", "ambience_volume"], ["Voice", "voice_volume"], ["VoiceMuffled", "voice_volume"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(float(values.get(pair[1], 0.8)), 0.001)))
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree:
		var vp := tree.root
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if float(values.render_scale) < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = float(values.render_scale)
		var main := tree.current_scene
		if main and main.has_node("Sun"):
			var sun: DirectionalLight3D = main.get_node("Sun")
			var sh := int(values.shadows)
			sun.shadow_enabled = sh > 0
			sun.directional_shadow_max_distance = 100.0 if sh == 1 else 155.0
		RenderingServer.directional_shadow_atlas_set_size(1024 if int(values.shadows) == 1 else 2048, true)
		if main and main.has_node("World"):
			_apply_view_distance(main.get_node("World"), float(values.view_distance))


static func _ensure_audio_buses() -> void:
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.3
		AudioServer.add_bus_effect(0, lim)
	for bus_name in ["SFX", "Ambience", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


static func _apply_view_distance(node: Node, f: float) -> void:
	for c in node.find_children("*", "MultiMeshInstance3D", true, false):
		var gi := c as GeometryInstance3D
		var nm := c.name
		if nm.begins_with("B_") or nm.begins_with("TP") or nm.begins_with("TD") or nm.begins_with("TS") or nm.begins_with("RK"):
			gi.visibility_range_end = 1050.0 * f
		else:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.visibility_range_end = 90.0 * f
