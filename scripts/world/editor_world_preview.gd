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
	var packed := ResourceLoader.load(baked_scene_path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	if inst == null:
		return
	inst.name = "_BakedWorldPreview"
	# Wichtig: owner bleibt null, damit die tausenden Baked-Nodes nicht in main.tscn landen.
	add_child(inst)
	_preview_instance = inst
