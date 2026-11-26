@tool
class_name ShopStation
extends Node3D
## Editor-sichtbare Shop-, Tankstellen-, Werkstatt- und Camp-Hub-Station unter WorldOverlays/Shops.
## Im Editor (@tool) werden nur visuelle Meshes/Schilder ohne .owner aufgebaut (keine Physik/KI/Speicher-Duplikate).

const SHOP_SIGNS := {
	"bauhaus": ["BAUHAUS", Color(0.85, 0.10, 0.10)],
	"super": ["SUPERMARKT", Color(0.95, 0.75, 0.10)],
	"gun": ["WAFFEN & JAGD", Color(0.20, 0.35, 0.20)],
	"butcher": ["FLEISCHEREI", Color(0.70, 0.15, 0.15)],
	"police": ["POLIZEI", Color(0.15, 0.30, 0.65)],
}

@export_enum("gas", "garage", "bauhaus", "super", "gun", "butcher", "police", "gaston", "weapon_shack", "camper_rv", "campfire", "wildlife_office", "caravan") var station_type := "gas":
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
		"bauhaus", "super", "gun", "butcher", "police":
			_build_city_shop(vis, station_type)
		"gaston":
			_build_gaston(vis)
		"weapon_shack":
			_build_weapon_shack(vis)
		"camper_rv":
			_build_camper_rv(vis)
		"campfire":
			_build_campfire(vis)
		"wildlife_office":
			_build_wildlife_office(vis)
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
	_box(vis, Vector3(16, 0.6, 9), Vector3(0, 5.2, 0), Color(0.95, 0.95, 0.95))
	_box(vis, Vector3(16.2, 0.4, 9.2), Vector3(0, 5.6, 0), Color(0.95, 0.75, 0.1))
	for k in [-1, 1]:
		_box(vis, Vector3(0.4, 5.2, 0.4), Vector3(0, 2.6, 6.5 * k), Color(0.8, 0.8, 0.8), true)
	for k in [-1, 1]:
		var pz: float = 4.0 * float(k)
		_box(vis, Vector3(0.9, 1.8, 0.6), Vector3(0, 0.9, pz), Color(0.9, 0.2, 0.15), true)
		_box(vis, Vector3(0.7, 0.4, 0.62), Vector3(0, 1.4, pz), Color(0.2, 0.2, 0.22))
	# Shop-Gebäude (-X = +side)
	_box(vis, Vector3(9, 3.4, 6), Vector3(-9.0, 1.5, 0), Color(0.92, 0.90, 0.85), true)
	_sign(vis, "TANKSTELLE", Color(0.10, 0.45, 0.25), Vector3(-5.9, 3.8, 0), PI * 0.5, 7.0)


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


func _build_gaston(vis: Node3D) -> void:
	_foundation_skirt(vis, 6.2, 3.2, Color(0.48, 0.46, 0.42))
	var truck_vis := AssetLoader.load_model("res://assets/models/landmarks/gaston_food_truck.glb", 3.6, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(5.6, 2.4, 2.5), Vector3(0, 1.55, 0), Color(0.937, 0.910, 0.847), true)
		_box(fb, Vector3(5.7, 0.55, 2.56), Vector3(0, 0.65, 0), Color(0.722, 0.157, 0.157), true)
		_box(fb, Vector3(1.6, 1.7, 2.4), Vector3(3.4, 1.2, 0), Color(0.937, 0.910, 0.847), true)
		_box(fb, Vector3(3.2, 0.18, 1.1), Vector3(0.2, 2.35, 1.75), Color(0.722, 0.157, 0.157))
		_box(fb, Vector3(2.0, 0.9, 0.28), Vector3(0.0, 3.2, 0), Color(0.784, 0.220, 0.220))
		_box(fb, Vector3(0.45, 0.45, 0.34), Vector3(1.1, 3.2, 0), Color(0.941, 0.929, 0.902))
		for wx in [-1.8, 2.6]:
			for wz in [-1.2, 1.2]:
				_box(fb, Vector3(0.75, 0.75, 0.32), Vector3(wx, 0.38, wz), Color(0.165, 0.173, 0.188))
		return fb
	)
	vis.add_child(truck_vis)
	_sign(vis, "GASTON BUTCHER", Color(0.722, 0.157, 0.157), Vector3(0, 3.9, 1.3), 0.0, 4.4)


func _build_weapon_shack(vis: Node3D) -> void:
	_foundation_skirt(vis, 5.4, 4.2, Color(0.38, 0.32, 0.26))
	var shack_vis := AssetLoader.load_model("res://assets/models/landmarks/weapon_shack.glb", 3.4, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(5.0, 3.0, 0.3), Vector3(0, 1.5, -1.7), Color(0.431, 0.294, 0.184), true)
		for sx in [-2.35, 2.35]:
			_box(fb, Vector3(0.3, 3.0, 3.4), Vector3(sx, 1.5, 0), Color(0.431, 0.294, 0.184), true)
		_box(fb, Vector3(5.6, 0.28, 4.2), Vector3(0, 3.2, 0), Color(0.361, 0.239, 0.133), true)
		_box(fb, Vector3(4.2, 1.0, 0.9), Vector3(0, 0.5, 1.35), Color(0.549, 0.384, 0.220), true)
		_box(fb, Vector3(0.9, 0.55, 0.6), Vector3(-1.1, 1.28, 1.35), Color(0.306, 0.408, 0.220))
		_box(fb, Vector3(0.8, 0.50, 0.55), Vector3(0.9, 1.25, 1.35), Color(0.659, 0.157, 0.157))
		_box(fb, Vector3(0.75, 1.0, 0.75), Vector3(2.9, 0.5, 1.1), Color(0.549, 0.384, 0.220), true)
		return fb
	)
	vis.add_child(shack_vis)
	_sign(vis, "WEAPON SHACK", Color(0.306, 0.408, 0.220), Vector3(0, 3.9, 1.9), 0.0, 4.4)


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


func _build_wildlife_office(vis: Node3D) -> void:
	_foundation_skirt(vis, 6.4, 3.0, Color(0.55, 0.57, 0.60))
	var wfo_vis := AssetLoader.load_model("res://assets/models/landmarks/wildlife_office_07.glb", 3.2, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(6.0, 2.4, 2.5), Vector3(0, 1.5, 0), Color(0.863, 0.886, 0.910), true)
		for kx in [-2.2, 2.2]:
			var cone := _box(fb, Vector3(0.32, 0.65, 0.32), Vector3(kx, 0.32, 1.6), Color(1.0, 0.416, 0.102))
			_box(cone, Vector3(0.28, 0.16, 0.33), Vector3(0, 0.08, 0), Color(1, 1, 1))
		return fb
	)
	vis.add_child(wfo_vis)
	_sign(vis, "DEPT. OF WILDLIFE / FIELD OFFICE 07", Color(0.22, 0.28, 0.35), Vector3(0, 3.1, 1.32), 0.0, 5.4)


func _build_caravan(vis: Node3D) -> void:
	var caravan := AssetLoader.load_model("res://assets/models/landmarks/caravan_big.glb", 10.0, func() -> Node3D:
		var fb := Node3D.new()
		_box(fb, Vector3(20.0, 10.0, 10.0), Vector3(0, 5.0, 0), Color(0.75, 0.72, 0.65), true)
		return fb
	)
	vis.add_child(caravan)
