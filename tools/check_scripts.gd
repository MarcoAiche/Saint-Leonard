extends SceneTree
## Lädt alle Skripte einzeln und zeigt Fehler (Aufruf: godot --headless --script tools/check_scripts.gd)

func _init() -> void:
	var files := []
	_collect("res://scripts", files)
	for f in files:
		var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or (s is GDScript and not (s as GDScript).can_instantiate() and not f.ends_with("_builder.gd")):
			print("FEHLER: ", f)
	quit()


func _collect(dir: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
