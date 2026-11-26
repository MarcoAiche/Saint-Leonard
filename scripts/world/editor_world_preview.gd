@tool
class_name EditorWorldPreview
extends Node3D
## Zeigt res://data/world_baked.scn ausschließlich im Godot-Editor als Vorschau an.
## Setzt niemals .owner auf edited_scene_root, damit keine Baked-Nodes in main.tscn
## gespeichert werden. Zur Laufzeit entfernt sich der Node selbst.

@export var show_editor_preview: bool = true:
	set(value):
		if show_editor_preview == value:
			return
		show_editor_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_preview()

@export var reload_preview: bool = false:
	set(value):
		if not value:
			reload_preview = false
			return
		reload_preview = false
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_preview()

@export var editor_show_distant_trees_and_rocks: bool = true:
	set(value):
		if editor_show_distant_trees_and_rocks == value:
			return
		editor_show_distant_trees_and_rocks = value
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_preview()

@export_file("*.scn", "*.tscn") var baked_scene_path: String = "res://data/world_baked.scn"

var _preview_instance: Node = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_refresh_preview()


func _exit_tree() -> void:
	_clear_preview()


func _clear_preview() -> void:
	if _preview_instance != null and is_instance_valid(_preview_instance):
		if _preview_instance.get_parent() == self:
			remove_child(_preview_instance)
		_preview_instance.queue_free()
	_preview_instance = null
	var leftover := get_node_or_null("_BakedWorldPreview")
	if leftover != null:
		remove_child(leftover)
		leftover.queue_free()


func _refresh_preview() -> void:
	_clear_preview()
	if not Engine.is_editor_hint() or not show_editor_preview:
		return
	if baked_scene_path.is_empty() or not ResourceLoader.exists(baked_scene_path):
		return
	var packed := ResourceLoader.load(baked_scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	if inst == null:
		return
	inst.name = "_BakedWorldPreview"
	# Wichtig: owner bleibt null, damit die tausenden Baked-Nodes nicht in main.tscn landen.
	add_child(inst)
	if editor_show_distant_trees_and_rocks:
		_disable_tree_rock_culling(inst)
	_preview_instance = inst


func _disable_tree_rock_culling(root_node: Node) -> void:
	for grp_name in ["Baeume", "Foliage"]:
		var grp := root_node.get_node_or_null(grp_name)
		if grp == null:
			continue
		for c in grp.get_children():
			if c is MultiMeshInstance3D:
				var mmi := c as MultiMeshInstance3D
				if grp_name == "Baeume" or mmi.name.begins_with("T") or mmi.name.begins_with("RK"):
					mmi.visibility_range_end = 0.0
