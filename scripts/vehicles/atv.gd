class_name ATV
extends Vehicle
## Wendiges Green 4x4 ATV / Quad Bike am Camp Hub (#2D5A27 / #1E2022).

const SEATS := {driver = Vector3(0.0, 0.72, -0.05)}

var _body: Node3D
var seat_marker: Marker3D
var _rider: CharacterModel = null


func _ready() -> void:
	super._ready()
	mass = 420.0
	center_of_mass = Vector3(0, -0.25, 0.0)
	max_engine_force = 3200.0
	top_speed_kmh = 95.0
	max_steer = 0.65
	_base_friction = 3.2
	_body = Node3D.new()
	_body.name = "ATVBody"
	add_child(_body)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 0.65, 1.95)
	col.shape = box
	col.position = Vector3(0, 0.45, 0)
	add_child(col)

	var vis := AssetLoader.load_model("res://assets/models/vehicles/atv_4x4.glb", 1.3, func() -> Node3D:
		var fb := Node3D.new()
		var green := Color(0.176, 0.353, 0.153)  # #2D5A27
		var dark := Color(0.118, 0.125, 0.133)   # #1E2022
		_box(fb, Vector3(0.95, 0.32, 1.75), Vector3(0, 0.42, 0), green)
		_box(fb, Vector3(0.45, 0.18, 0.85), Vector3(0, 0.65, -0.15), dark)
		_box(fb, Vector3(0.75, 0.08, 0.35), Vector3(0, 0.62, 0.65), dark)
		_box(fb, Vector3(0.70, 0.06, 0.06), Vector3(0, 0.92, 0.45), dark)
		_box(fb, Vector3(0.08, 0.32, 0.08), Vector3(0, 0.75, 0.45), dark)
		return fb
	)
	_body.add_child(vis)

	for p in [Vector3(0.58, 0.15, 0.65), Vector3(-0.58, 0.15, 0.65), Vector3(0.58, 0.15, -0.65), Vector3(-0.58, 0.15, -0.65)]:
		var w := _add_wheel(p, 0.32, p.z > 0, Color(0.118, 0.125, 0.133), Color(0.45, 0.48, 0.50), 0.24)
		w.wheel_rest_length = 0.22
		w.suspension_travel = 0.20
		w.suspension_stiffness = 48.0

	seat_marker = Marker3D.new()
	seat_marker.name = "SeatMarker"
	seat_marker.position = SEATS.driver
	add_child(seat_marker)


func set_rider(on: bool, outfit := {}) -> void:
	if _rider:
		_rider.queue_free()
		_rider = null
	if on and seat_marker:
		_rider = CharacterModel.new(outfit, 1)
		_rider.position = Vector3(0, -0.52, -0.08)
		_rider.rotation.x = 0.24  # leicht nach vorne gelehnt Richtung Lenker
		seat_marker.add_child(_rider)
		_rider.animate(0.016, 0.0, true, true, true)


func seat_pos(_s := "driver") -> Vector3:
	return SEATS.driver
