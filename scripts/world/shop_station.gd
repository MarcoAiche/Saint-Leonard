@tool
class_name ShopStation
extends Node3D
## Editor-sichtbare Shop-, Tankstellen-, Werkstatt- und Camp-Hub-Station unter WorldOverlays/Shops.
## Im Editor (@tool) werden nur visuelle Meshes/Schilder ohne .owner aufgebaut (keine Physik/KI/Speicher-Duplikate).

const BUTCHER_TRUCK_PATH := "res://assets/shops/Sushi Truck by Quaternius - OgrROxABGT.glb"
const GUN_TRUCK_PATH := "res://assets/shops/M939 Truck by J-Toastie - y8lBpvMlim.glb"
const GAS_STATION_PATH := "res://assets/shops/Gas Station by Alex Safayan - 7rUkCX-AIR2.glb"
const GAS_STATION_SCALE := 6.2758265
const GAS_ASPHALT_Y := 3.8704
const SHOP_SIGNS := {
	"bauhaus": ["BAUHAUS", Color(0.85, 0.10, 0.10)],
	"super": ["SUPERMARKT", Color(0.95, 0.75, 0.10)],
	"gun": ["WAFFEN & JAGD", Color(0.20, 0.35, 0.20)],
	"butcher": ["FLEISCHEREI", Color(0.70, 0.15, 0.15)],
	"police": ["POLIZEI", Color(0.15, 0.30, 0.65)],
}

@export_enum("gas", "garage", "bauhaus", "super", "gun", "butcher", "police", "gaston", "weapon_shack", "camper_rv", "campfire", "caravan") var station_type := "gas":
	set(v):
		station_type = v
		if is_inside_tree() and Engine.is_editor_hint():
			rebuild_visuals()

@export var build_hall := true:
	set(v):
		build_hall = v
		if is_inside_tree() and Engine.is_editor_hint():
			rebuild_visuals()


func _ready() -> void:
	rebuild_visuals()


func rebuild_visuals() -> void:
	var old := get_node_or_null("_Preview")
	if old:
		remove_child(old)
		old.queue_free()
	var vis := Node3D.new()
	vis.name = "_Preview"
	add_child(vis)

	match station_type:
		"gas":
			_build_gas(vis)
		"garage":
			_build_garage(vis)
		"bauhaus", "super", "police":
			_build_city_shop(vis, station_type)
		"gun":
			_build_gun_truck(vis, "WAFFEN & JAGD", Color(0.20, 0.35, 0.20))
		"butcher":
			_build_butcher_truck(vis, "FLEISCHEREI", Color(0.70, 0.15, 0.15), -PI * 0.5, Vector3(0.0, 0.0, 4.6))
		"gaston":
			_build_butcher_truck(vis, "GASTON BUTCHER", Color(0.722, 0.157, 0.157), 0.0, Vector3(4.6, 0.0, 0.0))
		"weapon_shack":
			_build_gun_truck(vis, "WEAPON SHACK", Color(0.306, 0.408, 0.220))
		"camper_rv":
			_build_camper_rv(vis)
		"campfire":
			_build_campfire(vis)
		"caravan":
			_build_caravan(vis)


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, collide := false, yaw := 0.0) -> MeshInstance3D:
	var mi := Placeables.box(parent, size, pos, col, Vector3(0, yaw, 0), collide and not Engine.is_editor_hint())
	return mi


func _sign(parent: Node3D, text: String, color: Color, pos: Vector3, yaw: float, width := 7.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	_box(holder, Vector3(width, 1.4, 0.2), Vector3.ZERO, color)
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = minf(0.012, width * 0.88 / (text.length() * 96.0 * 0.62))
	l.outline_size = 0
	l.modulate = Color.WHITE
	l.position = Vector3(0, 0, 0.12)
	l.double_sided = false
	holder.add_child(l)


func _foundation_skirt(parent: Node3D, w: float, d: float, col: Color) -> void:
	_box(parent, Vector3(w, 1.4, d), Vector3(0, -0.65, 0), col, true)


func _build_gas(vis: Node3D) -> void:
	if ResourceLoader.exists(GAS_STATION_PATH):
		var sc := ResourceLoader.load(GAS_STATION_PATH) as PackedScene
		if sc != null:
			var inst := sc.instantiate() as Node3D
			if inst != null:
				inst.scale = Vector3.ONE * GAS_STATION_SCALE
				vis.add_child(inst)
				if not Engine.is_editor_hint():
					_add_per_mesh_trimesh_collision(inst)
				return
	_box(vis, Vector3(16, 0.6, 9), Vector3(0, 5.2, 0), Color(0.95, 0.95, 0.95))


func _add_per_mesh_trimesh_collision(root_node: Node) -> void:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				mi.create_trimesh_collision()
				for ch in mi.get_children():
					if ch is StaticBody3D:
						var sb := ch as StaticBody3D
						sb.collision_layer = 1
						sb.collision_mask = 0
		for c in n.get_children():
			stack.append(c)


func _build_garage(vis: Node3D) -> void:
	_box(vis, Vector3(12, 0.3, 12), Vector3(0, -0.15, 0), Color(0.6, 0.6, 0.6), true)
	_box(vis, Vector3(12, 5, 0.4), Vector3(0, 2.2, -6.0), Color(0.75, 0.72, 0.68), true)
	for s in [-1, 1]:
		_box(vis, Vector3(0.4, 5, 12), Vector3(6.0 * s, 2.2, 0), Color(0.75, 0.72, 0.68), true)
	_box(vis, Vector3(12.6, 0.4, 12.6), Vector3(0, 4.9, 0), Color(0.35, 0.35, 0.38), true)
	_sign(vis, "WERKSTATT", Color(0.2, 0.2, 0.25), Vector3(0, 5.5, 6.2), 0.0, 7.0)


func _build_city_shop(vis: Node3D, id: String) -> void:
	if build_hall:
		_box(vis, Vector3(18, 6, 14), Vector3(0, 2.8, 0), Color(0.85, 0.85, 0.82), true)
	var sign_info: Array = SHOP_SIGNS.get(id, ["SHOP", Color(0.4, 0.4, 0.4)])
	_sign(vis, sign_info[0], sign_info[1], Vector3(0, 6.9, 9.4), 0.0, 8.0)


func _add_solid_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	sb.add_child(cs)
	parent.add_child(sb)


func _build_butcher_truck(vis: Node3D, sign_text: String, sign_col: Color, truck_yaw: float, drop_local: Vector3) -> void:
	var holder := Node3D.new()
	holder.rotation.y = truck_yaw
	vis.add_child(holder)
	if ResourceLoader.exists(BUTCHER_TRUCK_PATH):
		var sc := ResourceLoader.load(BUTCHER_TRUCK_PATH) as PackedScene
		if sc != null:
			var inst := sc.instantiate() as Node3D
			if inst != null:
				holder.add_child(inst)
	else:
		_box(holder, Vector3(4.6, 3.0, 7.6), Vector3(0.2, 1.5, 0), Color(0.937, 0.910, 0.847))
	_add_solid_box(holder, Vector3(4.6, 3.2, 7.6), Vector3(0.2, 1.6, 0.0))
	_sign(holder, sign_text, sign_col, Vector3(2.8, 5.2, 0.0), PI * 0.5, 4.8)
	_build_butcher_dropzone_visual(vis, drop_local)


func _build_butcher_dropzone_visual(vis: Node3D, local_pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "ButcherDropZone"
	holder.position = local_pos + Vector3(0, 0.05, 0)
	vis.add_child(holder)

	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = 1.5
	fill_mesh.bottom_radius = 1.5
	fill_mesh.height = 0.03
	fill_mesh.radial_segments = 32
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = Color(0.851, 0.169, 0.169, 0.36)
	var fill_mi := MeshInstance3D.new()
	fill_mi.mesh = fill_mesh
	fill_mi.material_override = fill_mat
	fill_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(fill_mi)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.38
	ring_mesh.outer_radius = 1.52
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.851, 0.169, 0.169, 1.0)
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring_mesh
	ring_mi.position.y = 0.02
	ring_mi.material_override = ring_mat
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring_mi)

	var lbl := Label3D.new()
	lbl.text = "WILD HIER ABLEGEN"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 48
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.92, 0.88)
	lbl.position = Vector3(0, 0.65, 0)
	holder.add_child(lbl)

	holder.set_meta("ring", ring_mi)
	holder.set_meta("fill", fill_mi)


func _build_gun_truck(vis: Node3D, sign_text: String, sign_col: Color) -> void:
	var holder := Node3D.new()
	vis.add_child(holder)
	if ResourceLoader.exists(GUN_TRUCK_PATH):
		var sc := ResourceLoader.load(GUN_TRUCK_PATH) as PackedScene
		if sc != null:
			var inst := sc.instantiate() as Node3D
			if inst != null:
				inst.scale = Vector3(2.1692882, 2.0415616, 1.1095659)
				holder.add_child(inst)
	else:
		_box(holder, Vector3(15.7, 5.6, 3.0), Vector3(1.1, 2.8, 0), Color(0.306, 0.353, 0.220))
	_add_solid_box(holder, Vector3(15.7, 5.6, 3.0), Vector3(1.1, 2.8, 0.0))
	_sign(holder, sign_text, sign_col, Vector3(1.1, 6.2, 1.65), 0.0, 5.4)


func _build_camper_rv(vis: Node3D) -> void:
	_foundation_skirt(vis, 6.2, 2.8, Color(0.45, 0.45, 0.44))
	var rv_vis := AssetLoader.load_model("res://assets/models/landmarks/camper_rv.glb", 2.9, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(5.8, 2.3, 2.4), Vector3(0, 1.55, 0), Color(0.918, 0.925, 0.910), true)
		_box(fb, Vector3(5.85, 0.55, 2.44), Vector3(0, 0.95, 0), Color(0.298, 0.651, 0.659))
		for wx in [-1.6, 1.6]:
			for wz in [-1.15, 1.15]:
				_box(fb, Vector3(0.7, 0.7, 0.28), Vector3(wx, 0.35, wz), Color(0.14, 0.14, 0.16))
		return fb
	)
	vis.add_child(rv_vis)


func _build_campfire(vis: Node3D) -> void:
	var cf_vis := AssetLoader.load_model("res://assets/models/props/campfire.glb", 0.6, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(1.2, 0.25, 1.2), Vector3(0, 0.1, 0), Color(0.478, 0.510, 0.549), true)
		_box(fb, Vector3(0.45, 0.65, 0.45), Vector3(0, 0.45, 0), Color(1.0, 0.467, 0.067))
		return fb
	)
	vis.add_child(cf_vis)
	var fl := OmniLight3D.new()
	fl.position = Vector3(0, 0.6, 0)
	fl.light_color = Color(0.910, 0.416, 0.125)
	fl.light_energy = 1.8
	fl.omni_range = 10.0
	vis.add_child(fl)
	var chair := AssetLoader.load_model("res://assets/models/props/rocking_chair.glb", 1.1, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(0.7, 0.12, 0.7), Vector3(0, 0.48, 0), Color(0.549, 0.369, 0.204), true)
		_box(fb, Vector3(0.7, 0.75, 0.12), Vector3(0, 0.9, -0.3), Color(0.549, 0.369, 0.204), true)
		_box(fb, Vector3(0.1, 0.12, 1.0), Vector3(-0.3, 0.08, 0), Color(0.361, 0.239, 0.133))
		_box(fb, Vector3(0.1, 0.12, 1.0), Vector3(0.3, 0.08, 0), Color(0.361, 0.239, 0.133))
		return fb
	)
	chair.name = "RockingChair"
	chair.position = Vector3(1.6, 0, 0)
	vis.add_child(chair)


func _build_caravan(vis: Node3D) -> void:
	var caravan := AssetLoader.load_model("res://assets/models/landmarks/caravan_big.glb", 10.0, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(20.0, 10.0, 10.0), Vector3(0, 5.0, 0), Color(0.75, 0.72, 0.65), true)
		return fb
	)
	vis.add_child(caravan)
