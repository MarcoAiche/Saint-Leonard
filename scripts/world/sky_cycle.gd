class_name SkyCycle
extends Node
## Tag und Nacht, Nebel und Regen. Bewegt die Sonne nach GameState.time, färbt Himmel und Licht,
## macht morgens Nebel und lässt es regnen (Regen macht Wege matschig, siehe GameState.wetness).

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var _rain: GPUParticles3D
var _clouds: MultiMeshInstance3D
var _rain_sound: AudioStreamPlayer
var _fog := 0.0
var _fog_col := Color(0.545098, 0.784314, 1.0)
var _cloud := 0.0


func setup(s: DirectionalLight3D, e: Environment) -> void:
	sun = s
	env = e
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	# Sauberes Stylized Low-Poly Licht ohne Standard-Dauernebel
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = false  # machte fleckige Schatten auf großen Flächen
	env.glow_enabled = false
	env.fog_enabled = false
	env.fog_height_density = 0.0
	env.adjustment_saturation = 1.12
	_clouds = _make_clouds()
	add_child(_clouds)
	_rain = _make_rain()
	add_child(_rain)
	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.rain()
	_rain_sound.bus = &"Ambience" if AudioServer.get_bus_index(&"Ambience") >= 0 else &"Master"
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
	var top_day := Color(0.231373, 0.556863, 0.952941).lerp(Color(0.55, 0.58, 0.62), _cloud)
	var hor_day := Color(0.545098, 0.784314, 1.0).lerp(Color(0.70, 0.72, 0.74), _cloud).lerp(Color(1.0, 0.70, 0.45), low_sun * 0.7)
	var top_night := Color(0.02, 0.03, 0.08)
	var hor_night := Color(0.06, 0.08, 0.14)
	sky_mat.sky_top_color = top_night.lerp(top_day, daylight)
	sky_mat.sky_horizon_color = hor_night.lerp(hor_day, daylight)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.18) * lerpf(0.15, 1.0, daylight)
	env.ambient_light_energy = lerpf(0.12, 0.55, daylight) * (1.0 - _cloud * 0.3)
	env.ambient_light_color = Color(0.75, 0.82, 0.95).lerp(Color(0.35, 0.4, 0.6), night)

	var cam := get_viewport().get_camera_3d()
	var in_swamp := false
	var world := get_parent().get_node_or_null("World")
	if cam and world and world.has_method("is_swamp"):
		in_swamp = world.is_swamp(Vector2(cam.global_position.x, cam.global_position.z))

	# Dezenter Fern-Nebel für ferne Berge (0-420m klar, 420-1850m sanfter Dunst, ~58% max), Sumpf bleibt lokal dicht (#5A6D4A)
	var use_exp := in_swamp or weather == "fog" or weather == "rain"
	if use_exp:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		var fog_target := 0.0014 if weather == "rain" else 0.0035
		var fog_col := sky_mat.sky_horizon_color.lerp(Color(0.8, 0.82, 0.84), 0.4 if weather == "fog" else 0.0)
		if in_swamp:
			fog_target = 0.011
			fog_col = Color(0.353, 0.427, 0.290)  # #5A6D4A olive-green swamp mist
		_fog = lerpf(_fog, fog_target, 1.0 - exp(-delta * 1.4))
		_fog_col = _fog_col.lerp(fog_col, 1.0 - exp(-delta * 1.6))
		env.fog_enabled = true
		env.fog_density = _fog
		env.fog_light_color = _fog_col
		env.fog_aerial_perspective = 0.5
		env.fog_sky_affect = 0.0
	else:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		var depth_density := 0.58 if daylight > 0.2 else 0.65
		var depth_col := sky_mat.sky_horizon_color.lerp(Color(0.68, 0.82, 0.96), 0.25 * daylight)
		_fog = lerpf(_fog, depth_density, 1.0 - exp(-delta * 1.4))
		_fog_col = _fog_col.lerp(depth_col, 1.0 - exp(-delta * 1.6))
		env.fog_enabled = true
		env.fog_depth_begin = 420.0
		env.fog_depth_end = 1850.0
		env.fog_depth_curve = 1.1
		env.fog_density = _fog
		env.fog_aerial_perspective = 0.75
		env.fog_light_color = _fog_col
		env.fog_sky_affect = 0.0
	env.fog_light_energy = lerpf(0.18, 1.0, daylight)

	# Regen & Wolken folgen der Kamera
	var raining := weather == "rain"
	_rain.emitting = raining
	if cam:
		_rain.global_position = cam.global_position + Vector3.UP * 12.0
		_clouds.global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z)
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


func _make_clouds() -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 0.95
	box.material = mat
	mm.mesh = box
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var clusters := 18
	var puffs_per := 3
	mm.instance_count = clusters * puffs_per
	var idx := 0
	for c in clusters:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(160.0, 950.0)
		var base := Vector3(cos(ang) * dist, rng.randf_range(145.0, 220.0), sin(ang) * dist)
		var yaw := rng.randf() * TAU
		for k in puffs_per:
			var off := Vector3((k - 1) * rng.randf_range(14.0, 22.0), rng.randf_range(-2.0, 4.0), rng.randf_range(-8.0, 8.0))
			var sc := Vector3(rng.randf_range(26.0, 44.0), rng.randf_range(8.0, 14.0), rng.randf_range(18.0, 30.0))
			var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(sc), base + off)
			mm.set_instance_transform(idx, xf)
			mm.set_instance_color(idx, Color(1.0, 1.0, 1.0) if k == 1 else Color(0.784, 0.867, 0.949))  # #FFFFFF / #C8DDF2
			idx += 1
	mmi.multimesh = mm
	return mmi
