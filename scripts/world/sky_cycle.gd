class_name SkyCycle
extends Node
## Tag und Nacht, Nebel und Regen. Bewegt die Sonne nach GameState.time, färbt Himmel und Licht,
## macht morgens Nebel und lässt es regnen (Regen macht Wege matschig, siehe GameState.wetness).

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var _rain: GPUParticles3D
var _rain_sound: AudioStreamPlayer
var _fog := 0.0004
var _cloud := 0.0


func setup(s: DirectionalLight3D, e: Environment) -> void:
	sun = s
	env = e
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	# Mischung aus Cartoon und semi-realistisch
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = false  # machte fleckige Schatten auf großen Flächen
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_height_density = 0.0
	env.adjustment_saturation = 1.05
	_rain = _make_rain()
	add_child(_rain)
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.rain()
	_rain_sound.volume_db = -80.0
	add_child(_rain_sound)
	_rain_sound.play()


func _process(delta: float) -> void:
	if not sun:
		return
	var t := GameState.time
	# Sonnenstand: Aufgang 6 Uhr, Untergang 20 Uhr
	var day_frac := (t - 6.0) / 14.0
	var elev := sin(clampf(day_frac, 0.0, 1.0) * PI) * 62.0
	var azim := lerpf(-100.0, 100.0, clampf(day_frac, 0.0, 1.0))
	var daylight := clampf(sin(clampf(day_frac, -0.05, 1.05) * PI) * 3.0, 0.0, 1.0) if day_frac > -0.05 and day_frac < 1.05 else 0.0
	var night := 1.0 - daylight
	if daylight > 0.01:
		sun.rotation_degrees = Vector3(-maxf(elev, 3.0), azim + 180.0, 0)
	else:
		sun.rotation_degrees = Vector3(-35.0, 30.0, 0)  # Mondlicht
	var weather := GameState.weather
	var cloud_target := 0.0
	match weather:
		"cloudy": cloud_target = 0.5
		"rain": cloud_target = 0.85
		"fog": cloud_target = 0.35
	_cloud = move_toward(_cloud, cloud_target, delta * 0.15)
	var low_sun := clampf(1.0 - elev / 25.0, 0.0, 1.0) * daylight
	var sun_col := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.35), low_sun)
	sun.light_color = sun_col.lerp(Color(0.55, 0.65, 0.9), night)
	sun.light_energy = lerpf(0.12, 1.25, daylight) * (1.0 - _cloud * 0.55)
	sun.shadow_enabled = daylight > 0.05
	var top_day := Color(0.30, 0.52, 0.85).lerp(Color(0.55, 0.58, 0.62), _cloud)
	var hor_day := Color(0.72, 0.82, 0.92).lerp(Color(0.70, 0.72, 0.74), _cloud).lerp(Color(1.0, 0.70, 0.45), low_sun * 0.7)
	var top_night := Color(0.02, 0.03, 0.08)
	var hor_night := Color(0.06, 0.08, 0.14)
	sky_mat.sky_top_color = top_night.lerp(top_day, daylight)
	sky_mat.sky_horizon_color = hor_night.lerp(hor_day, daylight)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.18) * lerpf(0.15, 1.0, daylight)
	env.ambient_light_energy = lerpf(0.12, 0.55, daylight) * (1.0 - _cloud * 0.3)
	env.ambient_light_color = Color(0.75, 0.82, 0.95).lerp(Color(0.35, 0.4, 0.6), night)
	# Nebel: dicht bei Nebelwetter (Wild sieht schlechter), etwas bei Regen
	var fog_target := 0.00025
	match weather:
		"fog": fog_target = 0.0035
		"rain": fog_target = 0.0014
		"cloudy": fog_target = 0.0004
	if night > 0.5:
		fog_target = maxf(fog_target, 0.0008)
	_fog = lerpf(_fog, fog_target, 1.0 - exp(-delta * 0.3))
	env.fog_density = _fog
	env.fog_light_color = sky_mat.sky_horizon_color.lerp(Color(0.8, 0.82, 0.84), 0.4 if weather == "fog" else 0.0)
	env.fog_light_energy = lerpf(0.15, 1.0, daylight)
	# Regen folgt der Kamera
	var raining := weather == "rain"
	_rain.emitting = raining
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain.global_position = cam.global_position + Vector3.UP * 12.0
	_rain_sound.volume_db = lerpf(_rain_sound.volume_db, -8.0 if raining else -80.0, 1.0 - exp(-delta * 0.8))


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 3000
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1, 30)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.45)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = m
	p.draw_pass_1 = q
	p.emitting = false
	return p
