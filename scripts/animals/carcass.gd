class_name Carcass
extends RigidBody3D
## Erlegtes Tier. Fällt per Physik um (statt Ragdoll), kann getragen, auf den Pickup geladen
## oder mit dem Messer ausgenommen werden (gibt Fleisch, Fell, Geweih ...).

var species := "deer"
var male := false
var net_id := 0
var carried := false
var model: Node3D


func _ready() -> void:
	add_to_group("carcass")
	collision_layer = 16
	collision_mask = 1 | 4 | 16
	var info: Dictionary = Animal.SPECIES[species]
	mass = 60.0 * info.size * info.size
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 1.4) * info.size
	cs.shape = box
	cs.position.y = 0.8 * info.size
	add_child(cs)
	angular_damp = 1.5
	linear_damp = 0.3


func take_model(m: Node3D) -> void:
	model = m
	m.get_parent().remove_child(m)
	add_child(m)
	m.position = Vector3.ZERO


func display_name() -> String:
	var n: String = Animal.SPECIES[species].name
	if species == "deer" and male:
		n = "Rehbock"
	return n


## Beute beim Ausnehmen
func loot() -> Dictionary:
	var info: Dictionary = Animal.SPECIES[species]
	var out: Dictionary = info.loot.duplicate()
	if male:
		for k in info.male_loot:
			out[k] = out.get(k, 0) + info.male_loot[k]
	return out


## Wert beim Verkauf des ganzen Tiers bei der Fleischerei
func sell_value() -> int:
	var v := 0
	var l := loot()
	for id in l:
		var s: Dictionary = Items.info(id).get("sell", {})
		v += int(s.get("butcher", 30)) * int(l[id])
	return int(v * 0.85)


func set_carried(on: bool) -> void:
	carried = on
	freeze = on
	collision_layer = 0 if on else 16
	collision_mask = 0 if on else (1 | 4 | 16)
