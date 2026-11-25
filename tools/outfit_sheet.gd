extends Node3D
## Entwickler-Werkzeug: rendert Figuren in verschiedenen Outfits nebeneinander.
## godot --path . --resolution 1800x700 res://tools/outfit_sheet.tscn -- --out=pfad.png
var looks := [
	{},
	{gender = "female", top = "hoodie", shirt = Color(0.78, 0.18, 0.14), hat = "beanie", glasses = "sunglasses", back = "backpack"},
	{hair = "side", beard = "full", top = "hi_vis", hat = "work_helmet", legs = "work_pants", shirt = Color(0.92, 0.9, 0.85)},
	{gender = "female", top = "trachten", hat = "hunter_gams", legs = "lederhose", hair_color = Color(0.85, 0.68, 0.4)},
	{hair = "long", beard = "goatee", top = "jacket", hat = "none", glasses = "glasses", pants = Color(0.2, 0.26, 0.42)},
	{top = "fur_coat", hat = "fur_cap", back = "fur_pack", beard = "full", hair_color = Color(0.62, 0.62, 0.62)},
	{top = "leather_vest", legs = "lederhose", hat = "cap", hat_color = Color(0.55, 0.15, 0.12), skin = Color(0.6, 0.4, 0.27)},
	{gender = "female", top = "work_jacket", hat = "cap", skin = Color(0.42, 0.28, 0.19), hair_color = Color(0.12, 0.1, 0.09)},
]
func _ready():
	var out := OS.get_environment("TEMP") + "/outfits.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.58)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.5
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 25, 0)
	root.add_child(l)
	var models := []
	for k in looks.size():
		var o: Dictionary = Outfit.DEFAULT.duplicate()
		o.merge(looks[k], true)
		var m := CharacterModel.new(o)
		root.add_child(m)
		m.position = Vector3((k - looks.size() * 0.5 + 0.5) * 0.85, 0, 0)
		m.rotation.y = 0.35 if k % 2 == 0 else -0.35
		models.append(m)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	cam.look_at_from_position(Vector3(0, 1.3, 8.0), Vector3(0, 0.8, 0))
	for i in 30:
		for m in models:
			m.animate(0.016, 0.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("gespeichert: ", out)
	get_tree().quit()
